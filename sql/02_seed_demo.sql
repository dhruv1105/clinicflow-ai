-- ============================================================
-- ClinicFlow AI — Demo Seed Data
-- Run AFTER 01_schema.sql
-- ============================================================

-- Demo Doctor
INSERT INTO doctors (name, specialization, email, phone, available_days, slot_duration_mins)
VALUES ('Dr. Arjun Sharma', 'General Physician', 'doctor@clinicflow.demo', '+91-9800000001', 'Mon,Tue,Wed,Thu,Fri', 30)
ON CONFLICT DO NOTHING;

-- Demo Patients
INSERT INTO patients (name, age, gender, phone, email, telegram_chat_id, blood_group, allergies, chronic_conditions)
VALUES
('Rahul Mehta', 34, 'Male', '+91-9900000001', 'patient@clinicflow.demo', '123456789',
 'B+', 'Penicillin', 'Hypertension'),
('Priya Patel', 28, 'Female', '+91-9900000002', 'priya@test.com', '987654321',
 'O+', 'None', 'None'),
('Vijay Kumar', 52, 'Male', '+91-9900000003', 'vijay@test.com', NULL,
 'A+', 'Sulfa drugs', 'Type 2 Diabetes, Hypertension')
ON CONFLICT DO NOTHING;

-- Demo User Accounts (password: 'demo1234' — bcrypt hash)
-- $2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBpj2lXBl0mIO6 = bcrypt('demo1234')
INSERT INTO user_accounts (email, password_hash, role, linked_id)
VALUES
('doctor@clinicflow.demo', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBpj2lXBl0mIO6', 'doctor', 1),
('patient@clinicflow.demo', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBpj2lXBl0mIO6', 'patient', 1)
ON CONFLICT DO NOTHING;

-- Demo Appointments (past + upcoming)
INSERT INTO appointments (patient_id, doctor_id, appointment_type, scheduled_at, duration_mins, status, reason, summary_generated)
VALUES
-- Past completed appointment with summary
(1, 1, 'doctor', NOW() - INTERVAL '7 days', 30, 'completed', 'Chest pain and breathlessness', TRUE),
-- Past appointment
(2, 1, 'doctor', NOW() - INTERVAL '3 days', 30, 'completed', 'Fever and cold for 4 days', TRUE),
-- Today appointment
(1, 1, 'doctor', NOW() + INTERVAL '2 hours', 30, 'scheduled', 'Follow-up for hypertension', FALSE),
-- Tomorrow appointment
(3, 1, 'doctor', NOW() + INTERVAL '1 day', 30, 'scheduled', 'Diabetes check-up', FALSE),
-- Periodic physiotherapy (nurse sessions)
(1, 1, 'nurse', NOW() + INTERVAL '2 days', 45, 'scheduled', 'Physiotherapy session 1', FALSE),
(1, 1, 'nurse', NOW() + INTERVAL '9 days', 45, 'scheduled', 'Physiotherapy session 2', FALSE);

-- Demo Session Summaries for past appointments
INSERT INTO session_summaries (appointment_id, full_transcript, diagnosis, clinical_notes, follow_up)
VALUES
(1,
 'Doctor: How are you feeling today Rahul? Patient: I have been having chest pain on the left side for 2 days and feeling short of breath when climbing stairs. Doctor: Let me check your blood pressure. It reads 150 over 95 which is high. Any stress at work? Patient: Yes quite a lot lately. Doctor: I am going to prescribe medication for blood pressure and refer you for an ECG.',
 'Hypertension with possible cardiac involvement - requires ECG',
 'BP: 150/95 mmHg. Heart sounds normal. No murmurs. Patient reports work stress.',
 'ECG within 3 days. Follow up in 1 week. Avoid salt and stress.'),
(2,
 'Doctor: Priya what brings you in today? Patient: I have had fever of 101 and runny nose for 4 days. Doctor: Let me examine. Throat looks slightly red. Mild viral infection. No bacterial signs. Patient: Do I need antibiotics? Doctor: No, this is viral. Rest and fluids. I will prescribe paracetamol and antihistamine.',
 'Acute viral upper respiratory tract infection',
 'Temp: 101F. Throat mildly congested. No tonsillar exudate. Lungs clear.',
 'Rest for 3 days. Paracetamol 500mg if temp above 100. Return if fever persists beyond 7 days.');

-- Demo Medications
INSERT INTO medications (appointment_id, patient_id, medicine_name, dosage, frequency, duration_days, is_ongoing)
VALUES
(1, 1, 'Amlodipine', '5mg', 'Once daily morning', 30, TRUE),
(1, 1, 'Aspirin', '75mg', 'Once daily after food', 30, TRUE),
(2, 2, 'Paracetamol', '500mg', 'Twice daily if fever', 5, FALSE),
(2, 2, 'Cetirizine', '10mg', 'Once at night', 5, FALSE);

-- Demo Payments
INSERT INTO payments (appointment_id, patient_id, amount, method, status, due_amount)
VALUES
(1, 1, 500.00, 'upi', 'paid', 0),
(2, 2, 300.00, 'cash', 'paid', 0),
(3, 1, 500.00, NULL, 'pending', 500.00);

-- Generate patient history vectors
UPDATE patients
SET history_vector = embedding('text-embedding-005',
    name || ' ' || COALESCE(chronic_conditions, '') || ' ' || COALESCE(allergies, '') || ' age ' || age::text
)::vector
WHERE history_vector IS NULL;

-- Generate summary vectors
UPDATE session_summaries
SET summary_vector = embedding('text-embedding-005',
    COALESCE(diagnosis, '') || ' ' || COALESCE(clinical_notes, '') || ' ' || COALESCE(follow_up, '')
)::vector
WHERE summary_vector IS NULL;