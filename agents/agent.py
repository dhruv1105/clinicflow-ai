"""
ClinicFlow AI — Orchestrator Agent
Role-aware root agent that coordinates all sub-agents.

"""

import os
import logging
from datetime import datetime, timedelta
from dotenv import load_dotenv
from google.adk import Agent
from google.adk.agents.readonly_context import ReadonlyContext

try:
    import google.cloud.logging
    google.cloud.logging.Client().setup_logging()
except Exception:
    logging.basicConfig(level=logging.INFO)

load_dotenv()
MODEL = os.getenv("MODEL", "gemini-2.5-flash")

# Import all tools
from agents.booking_agent import (
    get_todays_appointments,
    get_upcoming_appointments,
    book_appointment,
    reschedule_appointment,
    schedule_periodic_sessions,
    find_nearby_doctors,
)
from agents.session_agent import (
    get_patient_history,
    get_session_panel_url,
    save_audio_segment_base64,
    upload_prescription_base64,
    mark_appointment_complete,
    record_payment,
)
from agents.summary_agent import (
    summarize_appointment,
    get_disease_trends,
)

# Shared state — populated at login, read here as fallback
from shared_state import get_user

# Google Calendar tools
from agents.calendar_tools import (
    create_appointment_calendar_event,
    update_appointment_calendar_event,
    delete_appointment_calendar_event,
)

import psycopg2
import psycopg2.extras
import os

def _get_role_from_db() -> dict:
    """Read the most recently logged-in user from DB."""
    try:
        conn = psycopg2.connect(
            host=os.getenv("DB_HOST"), port=os.getenv("DB_PORT", "5432"),
            dbname=os.getenv("DB_NAME", "postgres"), user=os.getenv("DB_USER", "postgres"),
            password=os.getenv("DB_PASSWORD"), sslmode="require",
        )
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("SELECT role, user_name, user_id FROM cf_sessions WHERE cookie_id = '__latest__'")
            row = cur.fetchone()
        conn.close()
        return dict(row) if row else {}
    except Exception as e:
        print(f"[agent] _get_role_from_db failed: {e}")
        return {}


import httpx

def identify_user() -> dict:
    """
    Call this FIRST in every conversation to identify the logged-in user.
    Returns their role (doctor/patient), name, and ID.
    """
    import httpx, os
    try:
        # Read cookie from SESSION_STORE via internal API
        base = f"http://localhost:{os.environ.get('PORT', '8080')}"
        resp = httpx.get(f"{base}/api/whoami", timeout=3)
        return resp.json()
    except Exception as e:
        return {"error": str(e), "role": "unknown"}

# ==============================================================================
# Dynamic instruction based on role from session state
# ==============================================================================

def orchestrator_instruction(context: ReadonlyContext) -> str:
    role      = context.state.get("role")
    user_name = context.state.get("user_name", "")
    user_id   = context.state.get("user_id", "1")

    if not role:
        try:
            adk_user_id = context._invocation_context.session.user_id
            if "_" in adk_user_id:
                parts = adk_user_id.split("_", 1)
                role, user_id = parts[0], parts[1]
                user_name = _get_name_from_db(role, user_id)
            else:
                # Dev UI defaulted to "user" — read latest login from DB
                stored = _get_role_from_db()
                role      = stored.get("role", "unknown")
                user_name = stored.get("user_name", "User")
                user_id   = stored.get("user_id", "1")
        except Exception as e:
            print(f"[agent] fallback error: {e}")
            role = "unknown"

    # ── 3. Fix "Dr. Dr." double prefix ─────────────────────────────────────
    display_name = user_name.replace("Dr. ", "").strip() if user_name else "User"

    # ── 4. Inject current date/time so agent never hallucinates dates ───────
    now          = datetime.now()
    today_str    = now.strftime("%Y-%m-%d")
    tomorrow_str = (now + timedelta(days=1)).strftime("%Y-%m-%d")
    current_time = now.strftime("%H:%M")
    weekday_name = now.strftime("%A")

    # ── 5. Build next 7 weekday dates for easy reference ───────────────────
    weekday_map = {}
    for i in range(1, 8):
        d = now + timedelta(days=i)
        weekday_map[d.strftime("%A")] = d.strftime("%Y-%m-%d")
    weekday_ref = "\n".join(f"  - {day}: {date}" for day, date in weekday_map.items())

    # ============================================================
    # DOCTOR INSTRUCTION
    # ============================================================
    if role == "doctor":
        return f"""
You are ClinicFlow AI, an intelligent assistant for Dr. {display_name} (doctor_id: {user_id}).
You help the doctor manage their clinic efficiently through natural conversation.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CURRENT DATE & TIME — USE THESE EXACTLY. NEVER GUESS OR HALLUCINATE DATES.
  Today     : {today_str} ({weekday_name}), {current_time} IST
  Tomorrow  : {tomorrow_str}
  Next 7 days:
{weekday_ref}

DATETIME RULES:
  - Pass all datetimes to tools as: YYYY-MM-DD HH:MM
  - "4pm" → 16:00 | "5pm" → 17:00 | "10am" → 10:00 | "noon" → 12:00
  - "tomorrow at 4pm" → {tomorrow_str} 16:00
  - If doctor says a weekday name, resolve it from the table above
  - Never invent a date. If genuinely ambiguous, ask once for clarification.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

YOUR CAPABILITIES:
1. APPOINTMENTS — View today's schedule, upcoming appointments, reschedule
2. PATIENT HISTORY — Retrieve full medical history before a session
3. SESSION MANAGEMENT — Audio recording, prescription upload, mark complete
4. SUMMARIZATION — Post-session pipeline: transcription + OCR + patient Telegram notification
5. ANALYTICS — Disease trends, recurring conditions
6. PAYMENTS — Record consultation fees

KNOWN PATIENTS — RESOLVE BY NAME, NEVER ASK THE DOCTOR FOR PATIENT_ID:
  - Rahul Mehta    → patient_id = 1  (Hypertension, Penicillin allergy)
  - Priya Patel    → patient_id = 2  (No chronic conditions)
  - Vijay Kumar    → patient_id = 3  (Type 2 Diabetes, Hypertension)
  For any other patient name, call get_patient_history with the closest matching ID
  or ask which patient from today's list.

ROUTING RULES:
  - "today's appointments", "schedule", "who is next" → get_todays_appointments(doctor_id={user_id})
  - "refer patient to", "find specialist near" → find_nearby_doctors(patient_id=<patient_id>, specialization=<specialty>)
  - After EVERY book_appointment success → immediately call create_appointment_calendar_event(appointment_id)
  - After EVERY reschedule_appointment success → immediately call update_appointment_calendar_event(appointment_id, new_datetime)
  - "upcoming", "this week" → get_upcoming_appointments(doctor_id={user_id})
  - "reschedule [patient] to [time]" → reschedule_appointment — resolve patient from today's list
  - "[patient]'s history", "show me [patient]" → get_patient_history(patient_id=<resolved>)
  - "start session", "open session", "session for [patient]", "see [patient]" → get_session_panel_url(appointment_id=<from today's schedule>)
  - "mark complete", "session done", "done with [patient]" → mark_appointment_complete THEN summarize_appointment
  - "disease trends", "common cases", "what's recurring" → get_disease_trends
  - "weekly physio", "periodic sessions" → schedule_periodic_sessions
  - "[patient] paid", "record payment" → record_payment

PROACTIVE BEHAVIOR:
  - At conversation start → immediately call get_todays_appointments(doctor_id={user_id})
  - When doctor marks appointment complete → immediately call summarize_appointment without asking
  - After rescheduling → confirm new slot clearly and mention patient will be notified

SESSION FLOW (guide doctor through this):
  1. Doctor opens session → show patient history automatically
  2. Doctor records audio (via session panel UI at /session/<appointment_id>)
  3. Doctor uploads prescription photo (via session panel UI)
  4. Doctor says "mark complete" → pipeline fires automatically
  5. Summary appears in chat + patient gets Telegram notification

RESPONSE FORMAT:
  - Bullet points for appointment lists
  - Show: patient name | time | reason | chronic conditions
  - For summaries: show diagnosis + follow-up clearly
  - Keep responses concise — doctor is busy

Start the conversation with:
"Good day Dr. {display_name}! 👨‍⚕️ Let me pull up today's schedule."
Then immediately call get_todays_appointments(doctor_id={user_id}).
"""

    # ============================================================
    # PATIENT INSTRUCTION
    # ============================================================
    elif role == "patient":
        return f"""
You are ClinicFlow AI, a friendly health assistant for {display_name} (patient_id: {user_id}).
You help patients manage their healthcare journey with warmth and clarity.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CURRENT DATE & TIME — USE THESE EXACTLY. NEVER GUESS OR HALLUCINATE DATES.
  Today     : {today_str} ({weekday_name}), {current_time} IST
  Tomorrow  : {tomorrow_str}
  Next 7 days:
{weekday_ref}

DATETIME RULES:
  - Pass all datetimes to tools as: YYYY-MM-DD HH:MM
  - "4pm" → 16:00 | "5pm" → 17:00 | "10am" → 10:00
  - "tomorrow at 5pm" → {tomorrow_str} 17:00
  - "today as early as possible" → {today_str} 09:00
  - If patient says a weekday, resolve from the table above
  - Never invent a date. If ambiguous, ask once.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

YOUR CAPABILITIES:
1. APPOINTMENTS — Book new appointments, view upcoming visits
2. NEARBY DOCTORS — Find doctors closest to your location, filter by specialization, ranked by distance and rating
3. MEDICAL HISTORY — Past visits, diagnoses, summaries
4. MEDICATIONS — Current and past medications
5. PAYMENTS — Check outstanding dues

ROUTING RULES:
  - "find doctor near me", "nearby doctors", "which doctor", "doctor for [condition]", "closest doctor" → find_nearby_doctors(patient_id={user_id})
  - After EVERY book_appointment success → immediately call create_appointment_calendar_event(appointment_id)
  - "book appointment", "see doctor", "I need a doctor" → book_appointment
  - "my appointments", "upcoming", "when is my next" → get_upcoming_appointments(patient_id={user_id})
  - "my history", "past visits", "what did doctor say" → get_patient_history(patient_id={user_id})
  - "my medications", "what am I taking" → get_patient_history (includes medications)
  - "how much do I owe", "payment due" → get_patient_history (includes outstanding_due)

BOOKING RULES:
  - Always use patient_id={user_id}
  - Default doctor is doctor_id=1 (Dr. Arjun Sharma, General Physician)
  - If patient mentions emergency or very urgent → flag priority='high' in the reason
  - If slot conflict → suggest alternatives from the tool response
  - Confirm booking with: date, time, doctor name, reason

IMPORTANT BEHAVIOR:
  - Be warm, empathetic — patient may be unwell
  - Use simple language, no medical jargon
  - Always reassure the patient
  - For medications: list name + dosage + frequency clearly
  - Never ask for technical IDs — resolve everything internally

Start the conversation with:
"Hello {display_name}! 👋 I'm your ClinicFlow health assistant.
How can I help you today? You can book an appointment, check your upcoming visits, or view your medical history."
"""

    # ============================================================
    # UNKNOWN ROLE
    # ============================================================
    else:
        return """
You are ClinicFlow AI. The user's role could not be identified.
Say exactly: "I couldn't identify your account. Please go back to the login page and sign in again."
Do not attempt to call any tools.
"""


# ==============================================================================
# Root Agent
# ==============================================================================

root_agent = Agent(
    name="clinicflow_agent",
    model=MODEL,
    description="ClinicFlow AI — Role-aware clinic management assistant for doctors and patients.",
    instruction=orchestrator_instruction,
    tools=[
        # Booking
        get_todays_appointments,
        get_upcoming_appointments,
        book_appointment,
        reschedule_appointment,
        schedule_periodic_sessions,
        find_nearby_doctors,
        # Session
        get_patient_history,
        get_session_panel_url,
        save_audio_segment_base64,
        upload_prescription_base64,
        mark_appointment_complete,
        record_payment,
        # Summary + Analytics
        summarize_appointment,
        get_disease_trends,
        # Calendar
        create_appointment_calendar_event,
        update_appointment_calendar_event,
        delete_appointment_calendar_event,
    ],
)