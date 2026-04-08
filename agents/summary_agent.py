"""
ClinicFlow AI — Summary Agent Tools
Handles: audio transcription, session summarization, prescription OCR, notifications
Triggered after doctor marks appointment complete.
"""

import os
import base64
import httpx
import psycopg2
import psycopg2.extras
from decimal import Decimal
from datetime import date, datetime
from google.cloud import storage
from google import genai
from google.genai import types
from dotenv import load_dotenv

load_dotenv()

DB_CONFIG = {
    "host":     os.getenv("DB_HOST"),
    "port":     os.getenv("DB_PORT", "5432"),
    "dbname":   os.getenv("DB_NAME", "postgres"),
    "user":     os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD"),
    "sslmode":  "require",
}

GCS_BUCKET = os.getenv("GCS_BUCKET", "clinicflow-media")
PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT")
LOCATION   = os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1")
MODEL      = os.getenv("MODEL", "gemini-2.5-flash")

TELEGRAM_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
SENDER_EMAIL   = os.getenv("SENDER_EMAIL", "")

# Gemini client (Vertex AI)
gemini_client = genai.Client(vertexai=True, project=PROJECT_ID, location=LOCATION)

def _db(): return psycopg2.connect(**DB_CONFIG)
def _s(val):
    if isinstance(val, Decimal): return float(val)
    if isinstance(val, (date, datetime)): return str(val)
    return val


def summarize_appointment(appointment_id: int) -> dict:
    """
    Full summarization pipeline for a completed appointment:
    1. Fetches all audio segments from GCS
    2. Transcribes each using Gemini multimodal
    3. Generates clinical summary with diagnosis
    4. OCRs prescription if available
    5. Extracts medications
    6. Stores everything in AlloyDB
    7. Sends patient notification

    Args:
        appointment_id: The completed appointment to summarize

    Returns:
        dict with full summary, diagnosis, and notification status.
    """
    conn = _db()
    try:
        # Get appointment info
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT a.*, p.name AS patient_name, p.email AS patient_email,
                       p.telegram_chat_id
                FROM appointments a
                JOIN patients p ON a.patient_id = p.patient_id
                WHERE a.appointment_id = %s
            """, (appointment_id,))
            appt = dict(cur.fetchone() or {})

        if not appt:
            return {"error": f"Appointment {appointment_id} not found"}

        # Fetch audio segments from DB
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT segment_id, gcs_path, order_num
                FROM audio_segments
                WHERE appointment_id = %s
                ORDER BY order_num
            """, (appointment_id,))
            segments = [dict(r) for r in cur.fetchall()]

        # Transcribe each audio segment
        transcriptions = []
        storage_client = storage.Client(project=PROJECT_ID)
        bucket = storage_client.bucket(GCS_BUCKET)

        for seg in segments:
            try:
                blob = bucket.blob(seg["gcs_path"])
                audio_bytes = blob.download_as_bytes()
                audio_b64 = base64.b64encode(audio_bytes).decode()

                # Determine mime type from path
                mime = "audio/webm" if "webm" in seg["gcs_path"] else "audio/mpeg"

                response = gemini_client.models.generate_content(
                    model=MODEL,
                    contents=[
                        types.Part.from_bytes(data=audio_bytes, mime_type=mime),
                        "Transcribe this doctor-patient medical conversation verbatim. "
                        "Label speakers as 'Doctor:' and 'Patient:'. "
                        "Preserve all medical terms exactly."
                    ]
                )
                transcript = response.text.strip()
                transcriptions.append(f"[Segment {seg['order_num']}]\n{transcript}")

                # Update DB with transcription
                with conn.cursor() as cur:
                    cur.execute("UPDATE audio_segments SET transcription = %s WHERE segment_id = %s",
                                (transcript, seg["segment_id"]))
                    conn.commit()
            except Exception as e:
                transcriptions.append(f"[Segment {seg['order_num']}] Transcription failed: {e}")

        full_transcript = "\n\n".join(transcriptions) if transcriptions else "No audio recorded."

        # Generate clinical summary
        summary_prompt = f"""
You are a medical AI assistant. Based on this doctor-patient conversation transcript,
extract a structured clinical summary.

TRANSCRIPT:
{full_transcript}

Return a JSON object with these exact keys:
{{
  "diagnosis": "Primary diagnosis in 1-2 sentences",
  "clinical_notes": "Key clinical observations, vitals mentioned, examination findings",
  "follow_up": "Follow-up instructions and timeline",
  "medications_mentioned": ["list of medicines mentioned if any"]
}}
Only return valid JSON, nothing else.
"""
        try:
            sum_resp = gemini_client.models.generate_content(model=MODEL, contents=summary_prompt)
            import json, re
            json_text = re.sub(r"```json|```", "", sum_resp.text).strip()
            summary_data = json.loads(json_text)
        except Exception:
            summary_data = {
                "diagnosis": "See transcript for details",
                "clinical_notes": "Auto-extraction failed. See full transcript.",
                "follow_up": "Refer to doctor notes.",
                "medications_mentioned": []
            }

        # OCR prescription if exists
        prescription_text = ""
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("SELECT gcs_path FROM prescriptions WHERE appointment_id = %s", (appointment_id,))
            rx = cur.fetchone()

        if rx:
            try:
                blob = bucket.blob(rx["gcs_path"])
                img_bytes = blob.download_as_bytes()
                rx_resp = gemini_client.models.generate_content(
                    model=MODEL,
                    contents=[
                        types.Part.from_bytes(data=img_bytes, mime_type="image/jpeg"),
                        "Extract all text from this prescription image. "
                        "List each medicine with its dosage and frequency clearly."
                    ]
                )
                prescription_text = rx_resp.text.strip()
                with conn.cursor() as cur:
                    cur.execute("UPDATE prescriptions SET extracted_text = %s WHERE appointment_id = %s",
                                (prescription_text, appointment_id))
                    conn.commit()
            except Exception as e:
                prescription_text = f"Prescription OCR failed: {e}"

        # Save summary to DB
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO session_summaries
                    (appointment_id, full_transcript, diagnosis, clinical_notes, follow_up)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT DO NOTHING
            """, (appointment_id, full_transcript,
                  summary_data.get("diagnosis"), summary_data.get("clinical_notes"),
                  summary_data.get("follow_up")))

            # Update appointment
            cur.execute("UPDATE appointments SET summary_generated = TRUE WHERE appointment_id = %s",
                        (appointment_id,))
            conn.commit()

        # Generate summary vector
        with conn.cursor() as cur:
            cur.execute("""
                UPDATE session_summaries
                SET summary_vector = embedding('text-embedding-005',
                    COALESCE(diagnosis,'') || ' ' || COALESCE(clinical_notes,''))::vector
                WHERE appointment_id = %s
            """, (appointment_id,))
            conn.commit()

        # Send patient notification
        notif_status = _send_patient_notification(
            appt.get("patient_id"),
            appt.get("telegram_chat_id"),
            appt.get("patient_email"),
            appt.get("patient_name"),
            prescription_text,
            summary_data.get("diagnosis", ""),
            summary_data.get("clinical_notes", ""),
            summary_data.get("follow_up", ""),
            summary_data.get("medications_mentioned", []),
        )

        return {
            "status": "completed",
            "appointment_id": appointment_id,
            "diagnosis": summary_data.get("diagnosis"),
            "clinical_notes": summary_data.get("clinical_notes"),
            "follow_up": summary_data.get("follow_up"),
            "prescription_extracted": bool(prescription_text),
            "audio_segments_processed": len(segments),
            "notification_sent": notif_status,
        }
    finally:
        conn.close()


def _send_patient_notification(patient_id, telegram_chat_id, email,
                                patient_name, prescription_text, diagnosis,
                                clinical_notes="", follow_up="",
                                medications_mentioned=None) -> dict:
    """Send Telegram/email notification to patient."""
    if medications_mentioned is None:
        medications_mentioned = []

    msg = (
        f"🏥 *ClinicFlow AI — Visit Summary*\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"👤 *Patient:* {patient_name}\n\n"
        f"🔬 *Diagnosis:*\n{diagnosis}\n\n"
    )
    if clinical_notes:
        msg += f"📋 *Clinical Notes:*\n{clinical_notes}\n\n"
    if medications_mentioned:
        meds_str = "\n".join(f"  • {m}" for m in medications_mentioned)
        msg += f"💊 *Medications Prescribed:*\n{meds_str}\n\n"
    if prescription_text:
        msg += f"📄 *Prescription Details:*\n{prescription_text[:600]}\n\n"
    if follow_up:
        msg += f"📅 *Follow-up Instructions:*\n{follow_up}\n\n"
    msg += "━━━━━━━━━━━━━━━━━━━━━━━\n"
    msg += "_ClinicFlow AI — Your health, our priority. Stay healthy! 🌿_"

    results = {}

    # Telegram
    if telegram_chat_id and TELEGRAM_TOKEN:
        try:
            resp = httpx.post(
                f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage",
                json={"chat_id": telegram_chat_id, "text": msg, "parse_mode": "Markdown"},
                timeout=10,
            )
            results["telegram"] = "sent" if resp.status_code == 200 else f"failed: {resp.text}"
        except Exception as e:
            results["telegram"] = f"error: {e}"
    else:
        results["telegram"] = "skipped (no chat_id or token)"

    # Log notification
    if patient_id:
        try:
            conn = _db()
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO notifications (patient_id, channel, message, status)
                    VALUES (%s, 'telegram', %s, %s)
                """, (patient_id, msg[:1000], results.get("telegram", "skipped")))
                conn.commit()
            conn.close()
        except Exception:
            pass

    return results


def get_disease_trends(days: int = 7) -> dict:
    """
    Analyze the most common diagnoses across all appointments in the past N days.
    Uses AlloyDB AI vector search to find semantically similar conditions.

    Args:
        days: Number of days to analyze (default 7)

    Returns:
        dict with top diagnoses, patient count, and trend insights.
    """
    conn = _db()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT ss.diagnosis, ss.clinical_notes,
                       a.scheduled_at, p.age, p.gender
                FROM session_summaries ss
                JOIN appointments a ON ss.appointment_id = a.appointment_id
                JOIN patients p ON a.patient_id = p.patient_id
                WHERE a.scheduled_at >= NOW() - INTERVAL '%s days'
                  AND ss.diagnosis IS NOT NULL
                ORDER BY a.scheduled_at DESC
            """ % days)
            summaries = [dict(r) for r in cur.fetchall()]

        if not summaries:
            return {"message": "No completed appointments in this period", "days": days}

        # Ask Gemini to analyze trends
        diagnoses_text = "\n".join([
            f"- Patient {r['age']}y {r['gender']}: {r['diagnosis']}"
            for r in summaries
        ])

        trend_prompt = f"""
Analyze these medical diagnoses from the past {days} days and provide:
1. Top 3 most common conditions (with count)
2. Age/gender patterns if any
3. Any concerning trends to flag
4. Recommendations for the clinic

Diagnoses:
{diagnoses_text}

Be concise and clinical.
"""
        try:
            resp = gemini_client.models.generate_content(model=MODEL, contents=trend_prompt)
            analysis = resp.text.strip()
        except Exception as e:
            analysis = f"Analysis failed: {e}"

        return {
            "days": days,
            "total_cases": len(summaries),
            "ai_analysis": analysis,
            "raw_diagnoses": [_s(r.get("diagnosis")) for r in summaries],
        }
    finally:
        conn.close()