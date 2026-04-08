-- ============================================================
-- ClinicFlow AI — Schema v2 Migration
-- Run AFTER 01_schema.sql (adds new columns to existing tables)
-- Google Cloud Gen AI Academy APAC 2026
-- ============================================================

-- ============================================================
-- doctors table — new columns
-- ============================================================
ALTER TABLE doctors
    ADD COLUMN IF NOT EXISTS latitude          FLOAT,
    ADD COLUMN IF NOT EXISTS longitude         FLOAT,
    ADD COLUMN IF NOT EXISTS address           TEXT,
    ADD COLUMN IF NOT EXISTS city              TEXT,
    ADD COLUMN IF NOT EXISTS experience_years  INT,
    ADD COLUMN IF NOT EXISTS rating            DECIMAL(3,2),
    ADD COLUMN IF NOT EXISTS total_reviews     INT,
    ADD COLUMN IF NOT EXISTS consultation_fee  INT,
    ADD COLUMN IF NOT EXISTS telegram_chat_id  TEXT;

-- ============================================================
-- patients table — new columns
-- ============================================================
ALTER TABLE patients
    ADD COLUMN IF NOT EXISTS latitude   FLOAT,
    ADD COLUMN IF NOT EXISTS longitude  FLOAT;

-- ============================================================
-- appointments table — new columns
-- ============================================================
ALTER TABLE appointments
    ADD COLUMN IF NOT EXISTS priority           TEXT DEFAULT 'normal',
    ADD COLUMN IF NOT EXISTS calendar_event_id  TEXT,
    ADD COLUMN IF NOT EXISTS patient_rating     INT,
    ADD COLUMN IF NOT EXISTS patient_review     TEXT;

-- ============================================================
-- notifications table — ensure columns exist (no change needed)
-- Already has: notification_id, patient_id, channel, message, status, sent_at
-- ============================================================

-- ============================================================
-- Indexes for new geo + priority columns
-- ============================================================
CREATE INDEX IF NOT EXISTS doctors_city_idx
    ON doctors (city);

CREATE INDEX IF NOT EXISTS doctors_specialization_idx
    ON doctors (specialization);

CREATE INDEX IF NOT EXISTS appointments_priority_idx
    ON appointments (priority);

CREATE INDEX IF NOT EXISTS appointments_status_idx
    ON appointments (status);