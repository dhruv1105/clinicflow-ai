"""
ClinicFlow AI — Google Calendar Tools
Creates/updates/deletes calendar events when appointments are booked or rescheduled.
Uses OAuth2 token stored in calendar_token.json (run auth flow once to generate it).
"""

import os
import json
from datetime import datetime, timedelta
from pathlib import Path
import psycopg2
import psycopg2.extras
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

TOKEN_PATH       = Path(__file__).parent.parent / "calendar_token.json"
CREDENTIALS_PATH = Path(__file__).parent.parent / "calendar_credentials.json"
SCOPES           = ["https://www.googleapis.com/auth/calendar"]


def _db():
    return psycopg2.connect(**DB_CONFIG)


def _get_calendar_service():
    """Build and return an authenticated Google Calendar service."""
    from google.oauth2.credentials import Credentials
    from google.auth.transport.requests import Request
    from googleapiclient.discovery import build

    if not TOKEN_PATH.exists():
        return None, "calendar_token.json not found. Run the OAuth setup script first."

    creds = Credentials.from_authorized_user_file(str(TOKEN_PATH), SCOPES)

    # Refresh if expired
    if creds and creds.expired and creds.refresh_token:
        try:
            creds.refresh(Request())
            with open(TOKEN_PATH, "w") as f:
                f.write(creds.to_json())
        except Exception as e:
            return None, f"Token refresh failed: {e}"

    try:
        service = build("calendar", "v3", credentials=creds)
        return service, None
    except Exception as e:
        return None, f"Calendar service build failed: {e}"


def create_appointment_calendar_event(appointment_id: int) -> dict:
    """
    Create a Google Calendar event for a booked appointment.
    Sends invite to both doctor and patient email.
    Stores the calendar event_id in DB for future updates.

    Args:
        appointment_id: The appointment to create a calendar event for

    Returns:
        dict with calendar event link and status.
    """
    # Fetch appointment + doctor + patient details
    conn = _db()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT
                    a.appointment_id, a.scheduled_at, a.duration_mins,
                    a.reason, a.priority, a.calendar_event_id,
                    p.name  AS patient_name,  p.email AS patient_email,
                    p.chronic_conditions,     p.allergies,
                    d.name  AS doctor_name,   d.email AS doctor_email,
                    d.address, d.city
                FROM appointments a
                JOIN patients p ON a.patient_id = p.patient_id
                JOIN doctors  d ON a.doctor_id  = d.doctor_id
                WHERE a.appointment_id = %s
            """, (appointment_id,))
            appt = dict(cur.fetchone() or {})
    finally:
        conn.close()

    if not appt:
        return {"error": f"Appointment {appointment_id} not found"}

    service, err = _get_calendar_service()
    if err:
        return {"error": err, "calendar": "skipped"}

    # Build event
    start_dt = appt["scheduled_at"]
    if isinstance(start_dt, str):
        start_dt = datetime.fromisoformat(start_dt)
    end_dt = start_dt + timedelta(minutes=int(appt["duration_mins"] or 30))

    priority_label = "🔴 HIGH PRIORITY — " if appt.get("priority") == "high" else ""
    title = f"{priority_label}ClinicFlow: {appt['patient_name']} with {appt['doctor_name']}"

    description = (
        f"📋 Reason: {appt.get('reason', 'Consultation')}\n"
        f"👤 Patient: {appt['patient_name']}\n"
        f"🩺 Doctor: {appt['doctor_name']}\n"
    )
    if appt.get("chronic_conditions") and appt["chronic_conditions"] != "None":
        description += f"⚕️ Chronic Conditions: {appt['chronic_conditions']}\n"
    if appt.get("allergies") and appt["allergies"] != "None":
        description += f"⚠️ Allergies: {appt['allergies']}\n"
    description += f"\n📍 Location: {appt.get('address', '')}, {appt.get('city', '')}"
    description += "\n\n_Managed by ClinicFlow AI_"

    attendees = []
    if appt.get("doctor_email"):
        attendees.append({"email": appt["doctor_email"]})
    if appt.get("patient_email"):
        attendees.append({"email": appt["patient_email"]})

    event = {
        "summary": title,
        "description": description,
        "location": f"{appt.get('address', '')}, {appt.get('city', '')}",
        "start": {
            "dateTime": start_dt.isoformat(),
            "timeZone": "Asia/Kolkata",
        },
        "end": {
            "dateTime": end_dt.isoformat(),
            "timeZone": "Asia/Kolkata",
        },
        "attendees": attendees,
        "reminders": {
            "useDefault": False,
            "overrides": [
                {"method": "popup",  "minutes": 60},
                {"method": "email",  "minutes": 60},
                {"method": "popup",  "minutes": 10},
            ],
        },
        "colorId": "11" if appt.get("priority") == "high" else "7",  # red vs teal
    }

    try:
        created = service.events().insert(
            calendarId="primary",
            body=event,
            sendUpdates="all",   # sends email invites to attendees
        ).execute()

        event_id   = created.get("id")
        event_link = created.get("htmlLink")

        # Store event_id in DB
        conn = _db()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE appointments SET calendar_event_id = %s WHERE appointment_id = %s",
                    (event_id, appointment_id)
                )
                conn.commit()
        finally:
            conn.close()

        return {
            "status":       "created",
            "event_id":     event_id,
            "event_link":   event_link,
            "title":        title,
            "start":        start_dt.strftime("%A, %d %B at %I:%M %p"),
            "attendees":    [a["email"] for a in attendees],
            "message":      f"📅 Calendar event created. Invite sent to {appt['patient_name']} and {appt['doctor_name']}.",
        }
    except Exception as e:
        return {"error": f"Calendar event creation failed: {e}"}


def update_appointment_calendar_event(appointment_id: int, new_datetime: str) -> dict:
    """
    Update an existing Google Calendar event when appointment is rescheduled.

    Args:
        appointment_id: The appointment whose calendar event should be updated
        new_datetime: New datetime in 'YYYY-MM-DD HH:MM' format

    Returns:
        dict with update status and new event link.
    """
    conn = _db()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                SELECT a.calendar_event_id, a.duration_mins,
                       p.name AS patient_name, d.name AS doctor_name
                FROM appointments a
                JOIN patients p ON a.patient_id = p.patient_id
                JOIN doctors  d ON a.doctor_id  = d.doctor_id
                WHERE a.appointment_id = %s
            """, (appointment_id,))
            appt = dict(cur.fetchone() or {})
    finally:
        conn.close()

    if not appt:
        return {"error": f"Appointment {appointment_id} not found"}

    event_id = appt.get("calendar_event_id")
    if not event_id:
        # No existing event — create one instead
        return create_appointment_calendar_event(appointment_id)

    service, err = _get_calendar_service()
    if err:
        return {"error": err, "calendar": "skipped"}

    try:
        new_dt  = datetime.strptime(new_datetime, "%Y-%m-%d %H:%M")
        end_dt  = new_dt + timedelta(minutes=int(appt["duration_mins"] or 30))

        # Fetch existing event to patch it
        existing = service.events().get(calendarId="primary", eventId=event_id).execute()
        existing["start"] = {"dateTime": new_dt.isoformat(),  "timeZone": "Asia/Kolkata"}
        existing["end"]   = {"dateTime": end_dt.isoformat(),  "timeZone": "Asia/Kolkata"}
        existing["summary"] = f"[RESCHEDULED] {existing.get('summary', 'ClinicFlow Appointment')}"

        updated = service.events().update(
            calendarId="primary",
            eventId=event_id,
            body=existing,
            sendUpdates="all",
        ).execute()

        return {
            "status":     "updated",
            "event_id":   event_id,
            "event_link": updated.get("htmlLink"),
            "new_time":   new_dt.strftime("%A, %d %B at %I:%M %p"),
            "message":    f"📅 Calendar event updated. {appt['patient_name']} and {appt['doctor_name']} notified of new time.",
        }
    except Exception as e:
        return {"error": f"Calendar event update failed: {e}"}


def delete_appointment_calendar_event(appointment_id: int) -> dict:
    """
    Delete a Google Calendar event when appointment is cancelled.

    Args:
        appointment_id: The appointment whose calendar event should be deleted

    Returns:
        dict with deletion status.
    """
    conn = _db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT calendar_event_id FROM appointments WHERE appointment_id = %s",
                (appointment_id,)
            )
            row = cur.fetchone()
    finally:
        conn.close()

    if not row or not row[0]:
        return {"status": "skipped", "message": "No calendar event linked to this appointment."}

    event_id = row[0]
    service, err = _get_calendar_service()
    if err:
        return {"error": err}

    try:
        service.events().delete(
            calendarId="primary",
            eventId=event_id,
            sendUpdates="all",
        ).execute()
        return {"status": "deleted", "event_id": event_id}
    except Exception as e:
        return {"error": f"Calendar event deletion failed: {e}"}