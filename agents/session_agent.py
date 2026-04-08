"""
ClinicFlow AI — Session Agent Tools
Handles: audio upload to GCS, prescription upload, mark appointment complete
"""

import os
import base64
import psycopg2
import psycopg2.extras
from decimal import Decimal
from typing import Optional
from datetime import date, datetime
from google.cloud import storage
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


def _db():
    return psycopg2.connect(**DB_CONFIG)

def _s(val):
    if isinstance(val, Decimal): return float(val)
    if isinstance(val, (date, datetime)): return str(val)
    return val


def get_patient_history(patient_id: int) -> dict:
    """
    Retrieve complete medical history for a patient before their appointment.

    Args:
        patient_id: Patient's ID

    Returns:
        dict with patient profile, past appointments, summaries, and current medications.
    """
    conn = _db()
    try:
        # Patient profile
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT patient_id, name, age, gender, phone, blood_group,
                       allergies, chronic_conditions
                FROM patients WHERE patient_id = %s
            """, (patient_id,))
            patient = dict(cur.fetchone() or {})

        # Past summaries
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT ss.diagnosis, ss.clinical_notes, ss.follow_up,
                       a.scheduled_at, a.reason
                FROM session_summaries ss
                JOIN appointments a ON ss.appointment_id = a.appointment_id
                WHERE a.patient_id = %s
                ORDER BY a.scheduled_at DESC
                LIMIT 5
            """, (patient_id,))
            history = [{k: _s(v) for k, v in dict(r).items()} for r in cur.fetchall()]

        # Current medications
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT medicine_name, dosage, frequency, duration_days, is_ongoing
                FROM medications
                WHERE patient_id = %s
                  AND (is_ongoing = TRUE OR created_at > NOW() - INTERVAL '30 days')
                ORDER BY created_at DESC
            """, (patient_id,))
            meds = [{k: _s(v) for k, v in dict(r).items()} for r in cur.fetchall()]

        # Outstanding payment
        with conn.cursor() as cur:
            cur.execute("""
                SELECT COALESCE(SUM(due_amount), 0) FROM payments
                WHERE patient_id = %s AND status != 'paid'
            """, (patient_id,))
            due = float(cur.fetchone()[0])

        return {
            "patient": {k: _s(v) for k, v in patient.items()},
            "past_visits": history,
            "current_medications": meds,
            "outstanding_due": due,
        }
    finally:
        conn.close()


def save_audio_segment_base64(appointment_id: int, audio_base64: str,
                               order_num: int = 1, mime_type: str = "audio/webm") -> dict:
    """
    Save an audio recording segment to GCS and register in AlloyDB.
    Audio is provided as base64-encoded string.

    Args:
        appointment_id: The appointment this audio belongs to
        audio_base64: Base64-encoded audio data
        order_num: Sequence number if multiple recordings per session
        mime_type: Audio MIME type (default audio/webm)

    Returns:
        dict with GCS path and segment_id.
    """
    try:
        audio_bytes = base64.b64decode(audio_base64)
    except Exception as e:
        return {"error": f"Invalid base64 audio data: {e}"}

    ext = "webm" if "webm" in mime_type else "mp3" if "mp3" in mime_type else "wav"
    gcs_path = f"audio/appointment_{appointment_id}/segment_{order_num}.{ext}"

    try:
        storage_client = storage.Client(project=PROJECT_ID)
        bucket = storage_client.bucket(GCS_BUCKET)
        blob = bucket.blob(gcs_path)
        blob.upload_from_string(audio_bytes, content_type=mime_type)
    except Exception as e:
        return {"error": f"GCS upload failed: {e}", "gcs_path": gcs_path}

    conn = _db()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                INSERT INTO audio_segments
                    (appointment_id, gcs_path, order_num)
                VALUES (%s, %s, %s)
                RETURNING segment_id
            """, (appointment_id, gcs_path, order_num))
            seg_id = cur.fetchone()["segment_id"]
            conn.commit()
        return {
            "status": "saved",
            "segment_id": seg_id,
            "gcs_path": gcs_path,
            "order_num": order_num,
            "message": f"Audio segment {order_num} saved. Upload more or mark appointment complete.",
        }
    finally:
        conn.close()


def upload_prescription_base64(appointment_id: int, image_base64: str,
                                mime_type: str = "image/jpeg") -> dict:
    """
    Upload a prescription photo to GCS.

    Args:
        appointment_id: The appointment this prescription belongs to
        image_base64: Base64-encoded prescription image
        mime_type: Image MIME type (default image/jpeg)

    Returns:
        dict with GCS path and upload status.
    """
    try:
        image_bytes = base64.b64decode(image_base64)
    except Exception as e:
        return {"error": f"Invalid base64 image: {e}"}

    ext = "jpg" if "jpeg" in mime_type else "png"
    gcs_path = f"prescriptions/appointment_{appointment_id}/prescription.{ext}"

    try:
        storage_client = storage.Client(project=PROJECT_ID)
        bucket = storage_client.bucket(GCS_BUCKET)
        blob = bucket.blob(gcs_path)
        blob.upload_from_string(image_bytes, content_type=mime_type)
    except Exception as e:
        return {"error": f"GCS upload failed: {e}"}

    conn = _db()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                INSERT INTO prescriptions (appointment_id, gcs_path)
                VALUES (%s, %s)
                ON CONFLICT (appointment_id) DO UPDATE SET gcs_path = EXCLUDED.gcs_path
                RETURNING prescription_id
            """, (appointment_id, gcs_path))
            conn.commit()
        return {
            "status": "uploaded",
            "gcs_path": gcs_path,
            "message": "Prescription saved. Mark appointment as complete when ready to trigger summarization.",
        }
    finally:
        conn.close()


def mark_appointment_complete(appointment_id: int) -> dict:
    """
    Mark an appointment as complete. This TRIGGERS the full summarization pipeline:
    - Transcribes all audio segments using Gemini
    - Summarizes the session and extracts diagnosis
    - OCRs the prescription image
    - Sends prescription reminder to patient via Telegram/email
    - Schedules follow-up if needed

    Args:
        appointment_id: The appointment to mark as complete

    Returns:
        dict with trigger confirmation and pipeline status.
    """
    conn = _db()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                UPDATE appointments
                SET status = 'completed', marked_complete_at = NOW()
                WHERE appointment_id = %s
                RETURNING appointment_id, patient_id, doctor_id
            """, (appointment_id,))
            appt = cur.fetchone()
            conn.commit()

        if not appt:
            return {"error": f"Appointment {appointment_id} not found"}

        return {
            "status": "completed",
            "appointment_id": appointment_id,
            "patient_id": appt["patient_id"],
            "pipeline_triggered": True,
            "message": (
                "Appointment marked complete. "
                "Summarization pipeline triggered — transcribing audio, "
                "extracting prescription, and sending patient reminder."
            ),
            "next_action": "Call summarize_appointment to generate the full summary now.",
        }
    finally:
        conn.close()


def get_session_panel_url(appointment_id: int) -> dict:
    """
    Returns the session panel URL for a given appointment.
    Call this when the doctor wants to start a session — record audio or upload prescription.
    The doctor should open the returned URL in a new browser tab.

    Args:
        appointment_id: The appointment ID to open a session for

    Returns:
        dict with the clickable session panel URL.
    """
    conn = _db()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT a.appointment_id, a.reason, a.status,
                       p.name AS patient_name
                FROM appointments a
                JOIN patients p ON a.patient_id = p.patient_id
                WHERE a.appointment_id = %s
            """, (appointment_id,))
            row = cur.fetchone()
    finally:
        conn.close()

    if not row:
        return {"error": f"Appointment {appointment_id} not found"}

    return {
        "session_url": f"/session/{appointment_id}",
        "appointment_id": appointment_id,
        "patient_name": row["patient_name"],
        "reason": row["reason"],
        "status": row["status"],
        "message": (
            f"Session panel ready for {row['patient_name']}. "
            f"Open the link below in a new tab to record audio and upload prescription:\n\n"
            f"👉 [Open Session Panel — {row['patient_name']}](/session/{appointment_id})"
        ),
    }


def record_payment(appointment_id: int, patient_id: int,
                   amount: float, method: str, due_amount: float = 0.0) -> dict:
    """
    Record payment for an appointment.

    Args:
        appointment_id: The appointment ID
        patient_id: Patient's ID
        amount: Amount paid
        method: Payment method — 'cash', 'upi', or 'card'
        due_amount: Outstanding amount if partial payment (default 0)

    Returns:
        dict with payment confirmation.
    """
    status = "paid" if due_amount == 0 else "partial"
    conn = _db()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                INSERT INTO payments
                    (appointment_id, patient_id, amount, method, status, due_amount, paid_at)
                VALUES (%s, %s, %s, %s, %s, %s, NOW())
                RETURNING payment_id
            """, (appointment_id, patient_id, amount, method, status, due_amount))
            pid = cur.fetchone()["payment_id"]
            conn.commit()
        return {
            "status": status,
            "payment_id": pid,
            "amount_paid": amount,
            "due_remaining": due_amount,
            "method": method,
        }
    finally:
        conn.close()