-- ============================================================
-- ClinicFlow AI — AlloyDB Schema
-- Google Cloud Gen AI Academy APAC 2026 Hackathon
-- ============================================================

-- STEP 1: Extensions
CREATE EXTENSION IF NOT EXISTS google_ml_integration CASCADE;
CREATE EXTENSION IF NOT EXISTS vector;
GRANT EXECUTE ON FUNCTION embedding TO postgres;

-- STEP 2: Patients
CREATE TABLE IF NOT EXISTS patients (
    patient_id      SERIAL PRIMARY KEY,
    name            TEXT NOT NULL,
    age             INT,
    gender          TEXT,
    phone           TEXT,
    email           TEXT,
    telegram_chat_id TEXT,                    -- for Telegram notifications
    blood_group     TEXT,
    allergies       TEXT,
    chronic_conditions TEXT,
    created_at      TIMESTAMP DEFAULT NOW(),
    history_vector  VECTOR(768)               -- semantic search on medical history
);

-- STEP 3: Doctors
CREATE TABLE IF NOT EXISTS doctors (
    doctor_id       SERIAL PRIMARY KEY,
    name            TEXT NOT NULL,
    specialization  TEXT,
    email           TEXT,
    phone           TEXT,
    available_days  TEXT DEFAULT 'Mon,Tue,Wed,Thu,Fri',
    slot_duration_mins INT DEFAULT 30,
    created_at      TIMESTAMP DEFAULT NOW()
);

-- STEP 4: Appointments
CREATE TABLE IF NOT EXISTS appointments (
    appointment_id  SERIAL PRIMARY KEY,
    patient_id      INT REFERENCES patients(patient_id),
    doctor_id       INT REFERENCES doctors(doctor_id),
    nurse_id        INT,                       -- NULL if doctor visit
    appointment_type TEXT DEFAULT 'doctor',   -- doctor / nurse
    scheduled_at    TIMESTAMP NOT NULL,
    duration_mins   INT DEFAULT 30,
    status          TEXT DEFAULT 'scheduled', -- scheduled/completed/cancelled/rescheduled
    reason          TEXT,                      -- chief complaint
    -- Periodic session fields
    is_periodic     BOOLEAN DEFAULT FALSE,
    period_days     INT,                       -- e.g. 7 for weekly
    total_sessions  INT,                       -- total periodic sessions
    session_number  INT DEFAULT 1,             -- current session number
    parent_appointment_id INT,                 -- links to original appointment
    -- Completion fields
    marked_complete_at TIMESTAMP,
    summary_generated  BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMP DEFAULT NOW()
);

-- STEP 5: Audio Segments (multiple per appointment)
CREATE TABLE IF NOT EXISTS audio_segments (
    segment_id      SERIAL PRIMARY KEY,
    appointment_id  INT REFERENCES appointments(appointment_id),
    gcs_path        TEXT NOT NULL,             -- GCS bucket path
    order_num       INT DEFAULT 1,             -- sequence of recording
    transcription   TEXT,                      -- filled after processing
    duration_secs   INT,
    uploaded_at     TIMESTAMP DEFAULT NOW()
);

-- STEP 6: Prescriptions
CREATE TABLE IF NOT EXISTS prescriptions (
    prescription_id SERIAL PRIMARY KEY,
    appointment_id  INT REFERENCES appointments(appointment_id),
    gcs_path        TEXT NOT NULL,             -- prescription image in GCS
    extracted_text  TEXT,                      -- OCR result from Gemini
    reminder_sent   BOOLEAN DEFAULT FALSE,
    uploaded_at     TIMESTAMP DEFAULT NOW()
);

-- STEP 7: Session Summaries (generated post-completion)
CREATE TABLE IF NOT EXISTS session_summaries (
    summary_id      SERIAL PRIMARY KEY,
    appointment_id  INT REFERENCES appointments(appointment_id),
    full_transcript TEXT,                      -- joined transcriptions
    diagnosis       TEXT,                      -- extracted diagnosis
    clinical_notes  TEXT,                      -- doctor observations
    follow_up       TEXT,                      -- follow-up instructions
    summary_vector  VECTOR(768),               -- semantic search on summaries
    generated_at    TIMESTAMP DEFAULT NOW()
);

-- STEP 8: Medications (extracted from prescription)
CREATE TABLE IF NOT EXISTS medications (
    medication_id   SERIAL PRIMARY KEY,
    appointment_id  INT REFERENCES appointments(appointment_id),
    patient_id      INT REFERENCES patients(patient_id),
    medicine_name   TEXT NOT NULL,
    dosage          TEXT,
    frequency       TEXT,
    duration_days   INT,
    is_ongoing      BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMP DEFAULT NOW()
);

-- STEP 9: Payments
CREATE TABLE IF NOT EXISTS payments (
    payment_id      SERIAL PRIMARY KEY,
    appointment_id  INT REFERENCES appointments(appointment_id),
    patient_id      INT REFERENCES patients(patient_id),
    amount          DECIMAL(10,2),
    method          TEXT,                      -- cash / upi / card
    status          TEXT DEFAULT 'pending',    -- pending / paid / partial
    due_amount      DECIMAL(10,2) DEFAULT 0,
    notes           TEXT,
    paid_at         TIMESTAMP,
    created_at      TIMESTAMP DEFAULT NOW()
);

-- STEP 10: Notifications log
CREATE TABLE IF NOT EXISTS notifications (
    notification_id SERIAL PRIMARY KEY,
    patient_id      INT REFERENCES patients(patient_id),
    channel         TEXT,                      -- telegram / email
    message         TEXT,
    status          TEXT DEFAULT 'sent',
    sent_at         TIMESTAMP DEFAULT NOW()
);

-- STEP 11: User accounts (simple auth)
CREATE TABLE IF NOT EXISTS user_accounts (
    user_id         SERIAL PRIMARY KEY,
    email           TEXT UNIQUE NOT NULL,
    password_hash   TEXT NOT NULL,             -- bcrypt hash
    role            TEXT NOT NULL,             -- patient / doctor
    linked_id       INT,                       -- patient_id or doctor_id
    created_at      TIMESTAMP DEFAULT NOW()
);

-- STEP 12: Vector indexes
CREATE INDEX IF NOT EXISTS patients_history_idx
    ON patients USING ivfflat (history_vector vector_cosine_ops)
    WITH (lists = 5);

CREATE INDEX IF NOT EXISTS summaries_vector_idx
    ON session_summaries USING ivfflat (summary_vector vector_cosine_ops)
    WITH (lists = 5);