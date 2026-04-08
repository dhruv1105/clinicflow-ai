"""
ClinicFlow AI — Booking Agent Tools
Handles: appointment booking, rescheduling, availability, periodic sessions
"""

import os
import psycopg2
import psycopg2.extras
from decimal import Decimal
from datetime import datetime, timedelta, date
from dotenv import load_dotenv
from typing import Optional

load_dotenv()

DB_CONFIG = {
    "host":     os.getenv("DB_HOST"),
    "port":     os.getenv("DB_PORT", "5432"),
    "dbname":   os.getenv("DB_NAME", "postgres"),
    "user":     os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD"),
    "sslmode":  "require",
}

def _db():
    return psycopg2.connect(**DB_CONFIG)

def _s(val):
    if isinstance(val, Decimal): return float(val)
    if isinstance(val, (date, datetime)): return str(val)
    return val

def _rows(cur):
    return [{k: _s(v) for k, v in dict(r).items()} for r in cur.fetchall()]


def get_todays_appointments(doctor_id: Optional[int] = 1) -> Optional[dict]:
    """
    Get all appointments scheduled for today for the doctor.

    Args:
        doctor_id: Doctor's ID (default 1)

    Returns:
        dict with list of today's appointments with patient details.
    """
    sql = """
        SELECT a.appointment_id, a.scheduled_at, a.duration_mins,
               a.status, a.reason, a.appointment_type,
               a.is_periodic, a.session_number, a.total_sessions,
               p.name AS patient_name, p.age, p.phone,
               p.chronic_conditions, p.allergies
        FROM appointments a
        JOIN patients p ON a.patient_id = p.patient_id
        WHERE a.doctor_id = %s
          AND DATE(a.scheduled_at) = CURRENT_DATE
          AND a.status != 'cancelled'
        ORDER BY a.scheduled_at
    """
    conn = _db()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql, (doctor_id,))
            appts = _rows(cur)
        return {"appointments": appts, "count": len(appts), "date": str(date.today())}
    finally:
        conn.close()


def get_upcoming_appointments(patient_id: Optional[int] = None, doctor_id: Optional[int] = None, days: Optional[int] = 7) -> Optional[dict]:
    """
    Get upcoming appointments for a patient or doctor.

    Args:
        patient_id: Patient ID (use for patient role)
        doctor_id: Doctor ID (use for doctor role)
        days: How many days ahead to look (default 7)

    Returns:
        dict with upcoming appointments.
    """
    conditions = ["a.status = 'scheduled'", "a.scheduled_at >= NOW()"]
    params = []
    if patient_id:
        conditions.append("a.patient_id = %s")
        params.append(patient_id)
    if doctor_id:
        conditions.append("a.doctor_id = %s")
        params.append(doctor_id)
    conditions.append("a.scheduled_at <= NOW() + INTERVAL '%s days'" % days)

    sql = f"""
        SELECT a.appointment_id, a.scheduled_at, a.duration_mins,
               a.status, a.reason, a.appointment_type,
               a.is_periodic, a.session_number, a.total_sessions,
               p.name AS patient_name, p.phone,
               d.name AS doctor_name
        FROM appointments a
        JOIN patients p ON a.patient_id = p.patient_id
        JOIN doctors d ON a.doctor_id = d.doctor_id
        WHERE {' AND '.join(conditions)}
        ORDER BY a.scheduled_at
        LIMIT 20
    """
    conn = _db()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql, params)
            appts = _rows(cur)
        return {"appointments": appts, "count": len(appts)}
    finally:
        conn.close()


def book_appointment(patient_id: Optional[int], doctor_id: Optional[int], preferred_datetime: Optional[str],
                     reason: Optional[str] = "", duration_mins: Optional[int] = 30) -> Optional[dict]:
    """
    Book a new appointment. Auto-approves if slot is available.

    Args:
        patient_id: Patient's ID
        doctor_id: Doctor's ID (default 1)
        preferred_datetime: Preferred datetime in 'YYYY-MM-DD HH:MM' format
        reason: Chief complaint or reason for visit
        duration_mins: Appointment duration in minutes (default 30)

    Returns:
        dict with booking confirmation or alternative slots if unavailable.
    """
    try:
        scheduled_at = datetime.strptime(preferred_datetime, "%Y-%m-%d %H:%M")
    except ValueError:
        return {"error": "Invalid datetime format. Use YYYY-MM-DD HH:MM"}

    # Check for conflicts
    conn = _db()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT COUNT(*) FROM appointments
                WHERE doctor_id = %s
                  AND status = 'scheduled'
                  AND scheduled_at < %s + INTERVAL '%s minutes'
                  AND scheduled_at + (duration_mins || ' minutes')::INTERVAL > %s
            """, (doctor_id, scheduled_at, duration_mins, scheduled_at))
            conflict_count = cur.fetchone()[0]

        if conflict_count > 0:
            # Find next 3 available slots
            alternatives = _find_available_slots(doctor_id, scheduled_at, 3)
            return {
                "status": "conflict",
                "message": "Requested slot is not available.",
                "alternative_slots": alternatives,
            }

        # Book it — auto-approve
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                INSERT INTO appointments
                    (patient_id, doctor_id, appointment_type, scheduled_at,
                     duration_mins, status, reason)
                VALUES (%s, %s, 'doctor', %s, %s, 'scheduled', %s)
                RETURNING appointment_id, scheduled_at, status
            """, (patient_id, doctor_id, scheduled_at, duration_mins, reason))
            appt = dict(cur.fetchone())
            conn.commit()

        return {
            "status": "confirmed",
            "appointment_id": appt["appointment_id"],
            "scheduled_at": str(appt["scheduled_at"]),
            "message": f"Appointment confirmed for {scheduled_at.strftime('%A, %d %B at %I:%M %p')}",
        }
    finally:
        conn.close()


def reschedule_appointment(appointment_id: Optional[int], new_datetime: Optional[str],
                           reason: Optional[str] = "Doctor unavailable") -> Optional[dict]:
    """
    Reschedule an existing appointment to a new time.

    Args:
        appointment_id: The appointment ID to reschedule
        new_datetime: New datetime in 'YYYY-MM-DD HH:MM' format
        reason: Reason for rescheduling

    Returns:
        dict with reschedule confirmation.
    """
    try:
        new_dt = datetime.strptime(new_datetime, "%Y-%m-%d %H:%M")
    except ValueError:
        return {"error": "Invalid datetime format. Use YYYY-MM-DD HH:MM"}

    conn = _db()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("""
                UPDATE appointments
                SET scheduled_at = %s, status = 'rescheduled'
                WHERE appointment_id = %s
                RETURNING appointment_id, scheduled_at, patient_id
            """, (new_dt, appointment_id))
            row = cur.fetchone()
            conn.commit()

        if not row:
            return {"error": f"Appointment {appointment_id} not found"}

        return {
            "status": "rescheduled",
            "appointment_id": appointment_id,
            "new_datetime": str(new_dt),
            "message": f"Appointment rescheduled to {new_dt.strftime('%A, %d %B at %I:%M %p')}",
            "patient_id": row["patient_id"],
        }
    finally:
        conn.close()


def schedule_periodic_sessions(patient_id: Optional[int], doctor_id: Optional[int],
                                start_datetime: Optional[str], period_days: Optional[int],
                                total_sessions: Optional[int], reason: Optional[str],
                                assign_nurse_alternating: Optional[bool] = False) -> Optional[dict]:
    """
    Schedule a series of periodic appointments (e.g. weekly physiotherapy).
    Optionally assigns alternate sessions to nurse.

    Args:
        patient_id: Patient ID
        doctor_id: Doctor ID
        start_datetime: First session datetime 'YYYY-MM-DD HH:MM'
        period_days: Days between sessions (e.g. 7 for weekly)
        total_sessions: Total number of sessions
        reason: Purpose of periodic sessions
        assign_nurse_alternating: If True, alternate sessions assigned to nurse

    Returns:
        dict with all created appointment IDs and schedule.
    """
    try:
        start_dt = datetime.strptime(start_datetime, "%Y-%m-%d %H:%M")
    except ValueError:
        return {"error": "Invalid datetime format. Use YYYY-MM-DD HH:MM"}

    conn = _db()
    created = []
    try:
        for i in range(total_sessions):
            session_dt = start_dt + timedelta(days=period_days * i)
            appt_type = "doctor"
            nurse_id = None

            if assign_nurse_alternating and i % 2 == 1:
                appt_type = "nurse"
                nurse_id = 1

            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute("""
                    INSERT INTO appointments
                        (patient_id, doctor_id, nurse_id, appointment_type,
                         scheduled_at, status, reason, is_periodic,
                         period_days, total_sessions, session_number)
                    VALUES (%s, %s, %s, %s, %s, 'scheduled', %s, TRUE, %s, %s, %s)
                    RETURNING appointment_id, scheduled_at, appointment_type
                """, (patient_id, doctor_id, nurse_id, appt_type,
                      session_dt, reason, period_days, total_sessions, i + 1))
                row = dict(cur.fetchone())
                conn.commit()
                created.append({
                    "session": i + 1,
                    "appointment_id": row["appointment_id"],
                    "scheduled_at": str(row["scheduled_at"]),
                    "type": row["appointment_type"],
                })

        return {
            "status": "scheduled",
            "total_sessions": total_sessions,
            "period_days": period_days,
            "appointments": created,
            "message": f"{total_sessions} sessions scheduled every {period_days} days.",
        }
    finally:
        conn.close()


def _find_available_slots(doctor_id: Optional[int], from_dt: Optional[datetime], count: Optional[int] = 3) -> Optional[list]:
    """Find next available appointment slots."""
    conn = _db()
    slots = []
    check_dt = from_dt + timedelta(hours=1)
    max_attempts = 20

    try:
        for _ in range(max_attempts):
            if len(slots) >= count:
                break
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT COUNT(*) FROM appointments
                    WHERE doctor_id = %s AND status = 'scheduled'
                      AND scheduled_at = %s
                """, (doctor_id, check_dt))
                if cur.fetchone()[0] == 0:
                    if 9 <= check_dt.hour <= 18:
                        slots.append(check_dt.strftime("%Y-%m-%d %H:%M"))
            check_dt += timedelta(minutes=30)
    finally:
        conn.close()
    return slots


def find_nearby_doctors(
    patient_id: Optional[int],
    specialization: Optional[str] = None,
    radius_km: Optional[float] = 15,
    limit: Optional[int] = 5,
) -> Optional[dict]:
    """
    Find doctors nearest to the patient's registered location.
    Ranks by distance first, then by rating descending.
    Optionally filter by specialization.

    Args:
        patient_id: Patient's ID (location is fetched from DB automatically)
        specialization: Optional filter e.g. 'Cardiologist', 'General Physician'
        radius_km: Search radius in kilometres (default 15)
        limit: Max number of doctors to return (default 5)

    Returns:
        dict with ranked list of nearby doctors including distance, rating,
        experience, consultation fee, and next available slot hint.
    """
    conn = _db()
    try:
        # Get patient's location
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(
                "SELECT name, latitude, longitude FROM patients WHERE patient_id = %s",
                (patient_id,)
            )
            patient = cur.fetchone()

        if not patient or not patient["latitude"]:
            return {"error": "Patient location not available in records."}

        plat = float(patient["latitude"])
        plng = float(patient["longitude"])

        # Haversine distance in SQL — works on standard PostgreSQL / AlloyDB
        spec_filter = "AND LOWER(d.specialization) = LOWER(%(spec)s)" if specialization else ""

        sql = f"""
            SELECT *
            FROM (
                SELECT
                    d.doctor_id,
                    d.name,
                    d.specialization,
                    d.address,
                    d.city,
                    d.experience_years,
                    d.rating,
                    d.total_reviews,
                    d.consultation_fee,
                    d.available_days,
                    ROUND(
                        (6371 * acos(
                            LEAST(1.0, GREATEST(-1.0,
                                cos(radians(%(plat)s)) * cos(radians(d.latitude))
                                * cos(radians(d.longitude) - radians(%(plng)s))
                                + sin(radians(%(plat)s)) * sin(radians(d.latitude))
                            ))
                        ))::numeric, 2
                    ) AS distance_km
                FROM doctors d
                WHERE d.latitude IS NOT NULL
                  AND d.longitude IS NOT NULL
                  {spec_filter}
            ) sub
            WHERE sub.distance_km <= %(radius)s
            ORDER BY sub.distance_km ASC, sub.rating DESC
            LIMIT %(limit)s
        """

        params = {
            "plat": plat, "plng": plng,
            "radius": radius_km, "limit": limit,
        }
        if specialization:
            params["spec"] = specialization

        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql, params)
            doctors = [dict(r) for r in cur.fetchall()]

        if not doctors:
            # Widen search automatically if nothing found
            return {
                "message": f"No {'` + specialization + `' if specialization else 'doctors'} found within {radius_km}km. Try increasing radius or a different specialization.",
                "patient_location": f"{plat}, {plng}",
                "doctors": [],
            }

        # Serialise Decimal/date fields
        result = []
        for d in doctors:
            result.append({
                "doctor_id":        d["doctor_id"],
                "name":             d["name"],
                "specialization":   d["specialization"],
                "address":          d["address"],
                "city":             d["city"],
                "experience_years": d["experience_years"],
                "rating":           float(d["rating"]) if d["rating"] else None,
                "total_reviews":    d["total_reviews"],
                "consultation_fee": d["consultation_fee"],
                "available_days":   d["available_days"],
                "distance_km":      float(d["distance_km"]),
            })

        return {
            "patient_name":    patient["name"],
            "search_radius_km": radius_km,
            "specialization_filter": specialization or "Any",
            "total_found":     len(result),
            "doctors":         result,
            "tip": "To book with any of these doctors, just say 'Book appointment with Dr. [Name]'.",
        }
    finally:
        conn.close()