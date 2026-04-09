-- ============================================================
-- FIX 1: Add user accounts for all 30 patients + 12 doctors
-- Password for all: demo1234
-- ============================================================

-- You must first generate a real hash in Cloud Shell:
-- python3 -c "import bcrypt; print(bcrypt.hashpw(b'demo1234', bcrypt.gensalt()).decode())"
-- Then replace HASH_HERE below with that output

DO $$
DECLARE
    h TEXT := '$2b$12$gDVRtdRpCTSH79E5mXw6YOlrpySMVQAVmV54rbp6f1h8cHbmrFUP.';  -- paste your bcrypt hash here
BEGIN

-- Doctors (doctor_id 2-12, skip 1 which already exists)
INSERT INTO user_accounts (email, password_hash, role, linked_id) VALUES
('meera.nair@clinic.in',    h, 'doctor', 2),
('rahul.desai@clinic.in',   h, 'doctor', 3),
('sunita.joshi@clinic.in',  h, 'doctor', 4),
('vikram.patel@clinic.in',  h, 'doctor', 5),
('priya.agarwal@clinic.in', h, 'doctor', 6),
('suresh.menon@clinic.in',  h, 'doctor', 7),
('anjali.shah@clinic.in',   h, 'doctor', 8),
('kiran.mehta@clinic.in',   h, 'doctor', 9),
('rohit.gupta@clinic.in',   h, 'doctor', 10),
('deepa.iyer@clinic.in',    h, 'doctor', 11),
('nitin.bhatt@clinic.in',   h, 'doctor', 12)
ON CONFLICT (email) DO NOTHING;

-- Patients (patient_id 2-30, skip 1 which already exists)
INSERT INTO user_accounts (email, password_hash, role, linked_id) VALUES
('priya@test.com',   h, 'patient', 2),
('vijay@test.com',   h, 'patient', 3),
('anita@test.com',   h, 'patient', 4),
('deepak@test.com',  h, 'patient', 5),
('kavitha@test.com', h, 'patient', 6),
('suresh@test.com',  h, 'patient', 7),
('rekha@test.com',   h, 'patient', 8),
('manish@test.com',  h, 'patient', 9),
('pooja@test.com',   h, 'patient', 10),
('ravi@test.com',    h, 'patient', 11),
('sunita@test.com',  h, 'patient', 12),
('harish@test.com',  h, 'patient', 13),
('meena@test.com',   h, 'patient', 14),
('ajay@test.com',    h, 'patient', 15),
('nisha@test.com',   h, 'patient', 16),
('prakash@test.com', h, 'patient', 17),
('lalita@test.com',  h, 'patient', 18),
('sanjay@test.com',  h, 'patient', 19),
('geeta@test.com',   h, 'patient', 20),
('dilip@test.com',   h, 'patient', 21),
('hema@test.com',    h, 'patient', 22),
('vinod@test.com',   h, 'patient', 23),
('shruti@test.com',  h, 'patient', 24),
('mukesh@test.com',  h, 'patient', 25),
('asha@test.com',    h, 'patient', 26),
('naresh@test.com',  h, 'patient', 27),
('jyoti@test.com',   h, 'patient', 28),
('bharat@test.com',  h, 'patient', 29),
('kamla@test.com',   h, 'patient', 30)
ON CONFLICT (email) DO NOTHING;

END $$;

-- ============================================================
-- FIX 2: Point all phone numbers and emails to your real ones
-- Alternating between your two Gmail accounts for variety
-- ============================================================

UPDATE patients SET
    phone = '+91-9328843423',
    email = CASE WHEN patient_id % 2 = 0
                 THEN 'dsindha170@gmail.com'
                 ELSE 'dhruvsindha1105@gmail.com'
            END;

UPDATE doctors SET
    phone = '+91-9328843423',
    email = CASE WHEN doctor_id = 1 THEN 'doctor@clinicflow.demo'  -- keep demo login working
                 WHEN doctor_id % 2 = 0 THEN 'dsindha170@gmail.com'
                 ELSE 'dhruvsindha1105@gmail.com'
            END;

-- ============================================================
-- FIX 3: Set YOUR real Telegram chat ID on all patients/doctors
-- so every notification actually reaches you during testing.
-- Get your chat ID by messaging @userinfobot on Telegram.
-- ============================================================

UPDATE patients SET telegram_chat_id = '952879560';
UPDATE doctors  SET telegram_chat_id = '952879560';