-- ============================================================
-- ClinicFlow AI — Seed Data v2
-- Run AFTER 03_schema_v2.sql
-- All timestamps use NOW() + INTERVAL so data stays current.
-- Google Cloud Gen AI Academy APAC 2026
-- ============================================================

-- ============================================================
-- CLEANUP: Remove all data from 02_seed_demo.sql (and any prior run
-- of this file) in reverse FK order so no constraint is violated.
-- Safe to run even on a fresh DB (all DELETEs are no-ops if empty).
-- ============================================================
DELETE FROM notifications;
DELETE FROM payments;
DELETE FROM medications;
DELETE FROM session_summaries;
DELETE FROM prescriptions;
DELETE FROM audio_segments;
DELETE FROM appointments;
DELETE FROM user_accounts;
DELETE FROM patients;
DELETE FROM doctors;

-- Reset all sequences so IDs start from 1
ALTER SEQUENCE doctors_doctor_id_seq     RESTART WITH 1;
ALTER SEQUENCE patients_patient_id_seq   RESTART WITH 1;
ALTER SEQUENCE appointments_appointment_id_seq RESTART WITH 1;
ALTER SEQUENCE session_summaries_summary_id_seq RESTART WITH 1;
ALTER SEQUENCE medications_medication_id_seq    RESTART WITH 1;
ALTER SEQUENCE payments_payment_id_seq          RESTART WITH 1;
ALTER SEQUENCE notifications_notification_id_seq RESTART WITH 1;

-- ============================================================
-- DOCTORS (12 total, doctor_id=1 is demo account)
-- ============================================================
INSERT INTO doctors (doctor_id, name, specialization, email, phone, available_days, slot_duration_mins,
                     latitude, longitude, address, city, experience_years, rating, total_reviews,
                     consultation_fee, telegram_chat_id)
VALUES
(1,  'Dr. Arjun Sharma',    'General Physician',  'doctor@clinicflow.demo',   '+91-9800000001', 'Mon,Tue,Wed,Thu,Fri', 30,  23.2156, 72.6369, 'Shop 12, Sector 7 Market, Sector 7',               'Gandhinagar', 14, 4.6, 312, 500,  '111111111'),
(2,  'Dr. Meera Nair',      'Cardiologist',       'meera.nair@clinic.in',     '+91-9800000002', 'Mon,Tue,Wed,Thu,Fri', 30,  23.2211, 72.6501, 'Heart Care Centre, Sector 11',                     'Gandhinagar', 22, 4.8, 278, 1000, NULL),
(3,  'Dr. Rahul Desai',     'General Physician',  'rahul.desai@clinic.in',    '+91-9800000003', 'Mon,Tue,Wed,Thu,Sat', 30,  23.2302, 72.6418, 'Desai Clinic, Sector 21 Main Road',                'Gandhinagar', 9,  4.3, 145, 400,  NULL),
(4,  'Dr. Sunita Joshi',    'Dermatologist',      'sunita.joshi@clinic.in',   '+91-9800000004', 'Tue,Wed,Thu,Fri,Sat', 30,  23.2389, 72.6589, 'Skin & Care Clinic, Sector 28',                    'Gandhinagar', 12, 4.5, 198, 700,  NULL),
(5,  'Dr. Vikram Patel',    'Orthopedic',         'vikram.patel@clinic.in',   '+91-9800000005', 'Mon,Tue,Wed,Thu,Fri', 45,  23.2095, 72.6712, 'Bone & Joint Clinic, Kudasan',                     'Gandhinagar', 18, 4.7, 234, 900,  NULL),
(6,  'Dr. Priya Agarwal',   'Pediatrician',       'priya.agarwal@clinic.in',  '+91-9800000006', 'Mon,Tue,Wed,Thu,Fri', 20,  23.2178, 72.6634, 'Kids Health Hub, Infocity Area',                   'Gandhinagar', 7,  4.4, 167, 500,  NULL),
(7,  'Dr. Suresh Menon',    'Cardiologist',       'suresh.menon@clinic.in',   '+91-9800000007', 'Mon,Wed,Thu,Fri,Sat', 30,  23.0359, 72.5511, 'Heart Plus Clinic, Bopal',                         'Ahmedabad',   28, 4.9, 380, 1200, NULL),
(8,  'Dr. Anjali Shah',     'General Physician',  'anjali.shah@clinic.in',    '+91-9800000008', 'Mon,Tue,Wed,Thu,Fri', 30,  23.0258, 72.5473, 'Shah Medical, Satellite Road',                     'Ahmedabad',   11, 4.2, 89,  450,  NULL),
(9,  'Dr. Kiran Mehta',     'ENT',                'kiran.mehta@clinic.in',    '+91-9800000009', 'Mon,Tue,Thu,Fri,Sat', 30,  23.0395, 72.5603, 'Mehta ENT Clinic, Navrangpura',                    'Ahmedabad',   16, 4.6, 211, 700,  NULL),
(10, 'Dr. Rohit Gupta',     'Neurologist',        'rohit.gupta@clinic.in',    '+91-9800000010', 'Mon,Tue,Wed,Thu,Fri', 45,  23.0312, 72.5532, 'Neuro Care Centre, Vastrapur',                     'Ahmedabad',   21, 4.7, 156, 1100, NULL),
(11, 'Dr. Deepa Iyer',      'Orthopedic',         'deepa.iyer@clinic.in',     '+91-9800000011', 'Tue,Wed,Thu,Fri,Sat', 45,  23.0489, 72.5701, 'Ortho Plus, SG Highway',                           'Ahmedabad',   15, 4.5, 175, 900,  NULL),
(12, 'Dr. Nitin Bhatt',     'Diabetologist',      'nitin.bhatt@clinic.in',    '+91-9800000012', 'Mon,Tue,Wed,Thu,Fri', 30,  23.2267, 72.6456, 'Diabetes & Wellness Clinic, Sector 1',             'Gandhinagar', 19, 4.8, 290, 800,  NULL)
ON CONFLICT (doctor_id) DO UPDATE SET
    latitude=EXCLUDED.latitude, longitude=EXCLUDED.longitude,
    address=EXCLUDED.address, city=EXCLUDED.city,
    experience_years=EXCLUDED.experience_years, rating=EXCLUDED.rating,
    total_reviews=EXCLUDED.total_reviews, consultation_fee=EXCLUDED.consultation_fee,
    telegram_chat_id=EXCLUDED.telegram_chat_id;

-- Reset doctor sequence
SELECT setval('doctors_doctor_id_seq', (SELECT MAX(doctor_id) FROM doctors));

-- ============================================================
-- PATIENTS (30 total)
-- ============================================================
INSERT INTO patients (patient_id, name, age, gender, phone, email, telegram_chat_id,
                      blood_group, allergies, chronic_conditions, latitude, longitude)
VALUES
(1,  'Rahul Mehta',        34, 'Male',   '+91-9900000001', 'patient@clinicflow.demo', '123456789', 'B+',  'Penicillin',  'Hypertension',                      23.2178, 72.6412),
(2,  'Priya Patel',        28, 'Female', '+91-9900000002', 'priya@test.com',          '987654321', 'O+',  'None',        'None',                               23.2301, 72.6523),
(3,  'Vijay Kumar',        52, 'Male',   '+91-9900000003', 'vijay@test.com',          '112233445', 'A+',  'Sulfa drugs', 'Type 2 Diabetes, Hypertension',      23.2089, 72.6389),
(4,  'Anita Shah',         44, 'Female', '+91-9900000004', 'anita@test.com',          '556677889', 'AB+', 'NSAIDs',      'Hypothyroidism',                     23.2350, 72.6601),
(5,  'Deepak Joshi',       61, 'Male',   '+91-9900000005', 'deepak@test.com',         '998877665', 'B-',  'Dust',        'Hypertension, Asthma',               23.2412, 72.6478),
(6,  'Kavitha Nair',       35, 'Female', '+91-9900000006', 'kavitha@test.com',        NULL,        'O-',  'None',        'None',                               23.0356, 72.5501),
(7,  'Suresh Agarwal',     58, 'Male',   '+91-9900000007', 'suresh@test.com',         NULL,        'A+',  'Penicillin',  'Type 2 Diabetes',                    23.0421, 72.5618),
(8,  'Rekha Verma',        47, 'Female', '+91-9900000008', 'rekha@test.com',          NULL,        'B+',  'None',        'Anxiety',                            23.0289, 72.5489),
(9,  'Manish Trivedi',     29, 'Male',   '+91-9900000009', 'manish@test.com',         NULL,        'O+',  'None',        'None',                               23.2234, 72.6551),
(10, 'Pooja Desai',        38, 'Female', '+91-9900000010', 'pooja@test.com',          NULL,        'A-',  'Sulfa drugs', 'Hypothyroidism',                     23.2167, 72.6492),
(11, 'Ravi Sharma',        65, 'Male',   '+91-9900000011', 'ravi@test.com',           NULL,        'AB+', 'Penicillin',  'Type 2 Diabetes, Hypertension, Asthma', 23.2345, 72.6423),
(12, 'Sunita Kapoor',      41, 'Female', '+91-9900000012', 'sunita@test.com',         NULL,        'B+',  'None',        'None',                               23.0512, 72.5723),
(13, 'Harish Bhatt',       55, 'Male',   '+91-9900000013', 'harish@test.com',         NULL,        'O+',  'NSAIDs',      'Hypertension',                       23.0378, 72.5534),
(14, 'Meena Iyer',         33, 'Female', '+91-9900000014', 'meena@test.com',          NULL,        'A+',  'None',        'None',                               23.2198, 72.6378),
(15, 'Ajay Pandey',        49, 'Male',   '+91-9900000015', 'ajay@test.com',           NULL,        'B+',  'Dust',        'Asthma',                             23.2412, 72.6612),
(16, 'Nisha Gupta',        26, 'Female', '+91-9900000016', 'nisha@test.com',          NULL,        'O+',  'None',        'None',                               23.0267, 72.5456),
(17, 'Prakash Menon',      70, 'Male',   '+91-9900000017', 'prakash@test.com',        NULL,        'A+',  'Penicillin',  'Type 2 Diabetes, Hypertension',      23.0434, 72.5589),
(18, 'Lalita Reddy',       53, 'Female', '+91-9900000018', 'lalita@test.com',         NULL,        'B-',  'None',        'Hypothyroidism, Anxiety',            23.2289, 72.6534),
(19, 'Sanjay Chauhan',     37, 'Male',   '+91-9900000019', 'sanjay@test.com',         NULL,        'AB+', 'None',        'None',                               23.2156, 72.6445),
(20, 'Geeta Mishra',       45, 'Female', '+91-9900000020', 'geeta@test.com',          NULL,        'O+',  'NSAIDs',      'Hypertension',                       23.2378, 72.6567),
(21, 'Dilip Rao',          60, 'Male',   '+91-9900000021', 'dilip@test.com',          NULL,        'A+',  'Sulfa drugs', 'Type 2 Diabetes',                    23.0345, 72.5512),
(22, 'Hema Pillai',        31, 'Female', '+91-9900000022', 'hema@test.com',           NULL,        'B+',  'None',        'None',                               23.0489, 72.5634),
(23, 'Vinod Kulkarni',     43, 'Male',   '+91-9900000023', 'vinod@test.com',          NULL,        'O-',  'Penicillin',  'Asthma',                             23.2267, 72.6489),
(24, 'Shruti Jain',        22, 'Female', '+91-9900000024', 'shruti@test.com',         NULL,        'A-',  'None',        'None',                               23.2134, 72.6356),
(25, 'Mukesh Solanki',     57, 'Male',   '+91-9900000025', 'mukesh@test.com',         NULL,        'B+',  'Dust',        'Hypertension, Type 2 Diabetes',      23.2456, 72.6623),
(26, 'Asha Bhat',          39, 'Female', '+91-9900000026', 'asha@test.com',           NULL,        'AB-', 'NSAIDs',      'Anxiety',                            23.0312, 72.5478),
(27, 'Naresh Tiwari',      48, 'Male',   '+91-9900000027', 'naresh@test.com',         NULL,        'O+',  'None',        'None',                               23.0401, 72.5567),
(28, 'Jyoti Soni',         36, 'Female', '+91-9900000028', 'jyoti@test.com',          NULL,        'A+',  'Sulfa drugs', 'Hypothyroidism',                     23.2312, 72.6512),
(29, 'Bharat Parmar',      67, 'Male',   '+91-9900000029', 'bharat@test.com',         NULL,        'B+',  'Penicillin',  'Hypertension, Asthma',               23.2201, 72.6401),
(30, 'Kamla Vyas',         72, 'Female', '+91-9900000030', 'kamla@test.com',          NULL,        'O+',  'None',        'Type 2 Diabetes',                    23.2389, 72.6589)
ON CONFLICT (patient_id) DO UPDATE SET
    latitude=EXCLUDED.latitude, longitude=EXCLUDED.longitude;

-- Reset patient sequence
SELECT setval('patients_patient_id_seq', (SELECT MAX(patient_id) FROM patients));

-- ============================================================
-- USER ACCOUNTS
-- ============================================================
INSERT INTO user_accounts (email, password_hash, role, linked_id)
VALUES
('doctor@clinicflow.demo',  '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBpj2lXBl0mIO6', 'doctor',  1),
('patient@clinicflow.demo', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBpj2lXBl0mIO6', 'patient', 1)
ON CONFLICT (email) DO NOTHING;

-- ============================================================
-- APPOINTMENTS
-- ============================================================
-- NOTE: appointment_id=3 is reserved for today's slot (patient 1, doctor 1)
-- Past completed appointments first (ids 1,2 kept from old seed if present)
-- Then today (id=3), then upcoming, then periodic series

INSERT INTO appointments (patient_id, doctor_id, appointment_type, scheduled_at, duration_mins,
                          status, reason, summary_generated, marked_complete_at,
                          priority, patient_rating, patient_review)
VALUES
-- ── PAST COMPLETED — Doctor 1 (General Physician) ──────────────────────────
(1,  1, 'doctor', NOW() - INTERVAL '85 days' + TIME '09:30', 30, 'completed', 'High blood pressure and headache',            TRUE, NOW() - INTERVAL '85 days' + TIME '10:05', 'normal',    5, 'Very thorough consultation. Dr. Sharma explained everything clearly.'),
(1,  1, 'doctor', NOW() - INTERVAL '55 days' + TIME '11:00', 30, 'completed', 'Routine BP check and medication review',      TRUE, NOW() - INTERVAL '55 days' + TIME '11:35', 'normal',    5, 'Quick and efficient. Medicines adjusted perfectly.'),
-- appointment_id=3 is TODAY (inserted separately below)
(1,  1, 'doctor', NOW() - INTERVAL '25 days' + TIME '10:00', 30, 'completed', 'Chest tightness and breathlessness',          TRUE, NOW() - INTERVAL '25 days' + TIME '10:35', 'high',      4, 'Good advice but had to wait 15 minutes.'),

(2,  1, 'doctor', NOW() - INTERVAL '60 days' + TIME '14:00', 30, 'completed', 'Fever and sore throat for 3 days',            TRUE, NOW() - INTERVAL '60 days' + TIME '14:35', 'normal',    4, 'Helpful and kind. Got better within a week.'),
(2,  1, 'doctor', NOW() - INTERVAL '20 days' + TIME '09:00', 30, 'completed', 'Skin rash on forearm',                        TRUE, NOW() - INTERVAL '20 days' + TIME '09:35', 'normal',    5, 'Very professional. Rash cleared up completely.'),

(3,  1, 'doctor', NOW() - INTERVAL '80 days' + TIME '10:30', 30, 'completed', 'Uncontrolled blood sugar and fatigue',        TRUE, NOW() - INTERVAL '80 days' + TIME '11:05', 'normal',    5, 'Excellent doctor. Changed my diabetes medication and I feel much better.'),
(3,  1, 'doctor', NOW() - INTERVAL '50 days' + TIME '11:30', 30, 'completed', 'Hypertension follow-up and dizziness',        TRUE, NOW() - INTERVAL '50 days' + TIME '12:05', 'high',      4, 'Good follow-up. Explained the BP readings in detail.'),
(3,  1, 'doctor', NOW() - INTERVAL '22 days' + TIME '09:30', 30, 'completed', 'Foot numbness and tingling — diabetic review', TRUE, NOW() - INTERVAL '22 days' + TIME '10:05', 'high',      5, 'Dr. Sharma is very knowledgeable about diabetes complications.'),

-- ── PAST COMPLETED — Doctor 2 (Cardiologist) ───────────────────────────────
(1,  2, 'doctor', NOW() - INTERVAL '70 days' + TIME '15:00', 30, 'completed', 'Chest pain on exertion and palpitations',     TRUE, NOW() - INTERVAL '70 days' + TIME '15:35', 'high',      5, 'Dr. Nair is outstanding. ECG done on the spot.'),
(3,  2, 'doctor', NOW() - INTERVAL '45 days' + TIME '10:00', 30, 'completed', 'Hypertension not controlled on current meds', TRUE, NOW() - INTERVAL '45 days' + TIME '10:35', 'high',      5, 'Finally a cardiologist who listened properly. Medication changed.'),
(5,  2, 'doctor', NOW() - INTERVAL '30 days' + TIME '11:00', 30, 'completed', 'Shortness of breath and ankle swelling',      TRUE, NOW() - INTERVAL '30 days' + TIME '11:35', 'emergency', 5, 'Immediate attention given. Very grateful.'),
(17, 2, 'doctor', NOW() - INTERVAL '18 days' + TIME '14:30', 30, 'completed', 'Irregular heartbeat and fatigue',             TRUE, NOW() - INTERVAL '18 days' + TIME '15:05', 'high',      4, 'Very experienced. Holter monitor recommended.'),
(25, 2, 'doctor', NOW() - INTERVAL '10 days' + TIME '10:00', 30, 'completed', 'Post-angioplasty follow-up',                  TRUE, NOW() - INTERVAL '10 days' + TIME '10:35', 'high',      5, 'Excellent post-procedure care and monitoring.'),

-- ── PAST COMPLETED — Doctor 3 (General Physician) ──────────────────────────
(4,  3, 'doctor', NOW() - INTERVAL '75 days' + TIME '09:00', 30, 'completed', 'Thyroid levels high and weight gain',         TRUE, NOW() - INTERVAL '75 days' + TIME '09:35', 'normal',    4, 'Practical advice. TSH test recommended immediately.'),
(6,  3, 'doctor', NOW() - INTERVAL '42 days' + TIME '10:30', 30, 'completed', 'Cold and cough for 5 days with fever',        TRUE, NOW() - INTERVAL '42 days' + TIME '11:05', 'normal',    5, 'Very caring doctor. Got well fast.'),
(8,  3, 'doctor', NOW() - INTERVAL '28 days' + TIME '14:00', 30, 'completed', 'Anxiety attacks and sleep issues',            TRUE, NOW() - INTERVAL '28 days' + TIME '14:35', 'normal',    4, 'Understanding and non-judgmental. Referred me to a counsellor.'),
(9,  3, 'doctor', NOW() - INTERVAL '15 days' + TIME '09:30', 30, 'completed', 'Stomach pain and acidity for 1 week',         TRUE, NOW() - INTERVAL '15 days' + TIME '10:05', 'normal',    5, 'Diagnosed GERD quickly. Medicines worked within days.'),
(14, 3, 'doctor', NOW() - INTERVAL '8  days' + TIME '11:00', 30, 'completed', 'Viral fever and body ache',                   TRUE, NOW() - INTERVAL '8  days' + TIME '11:35', 'normal',    3, 'OK consultation but waiting time was too long.'),

-- ── PAST COMPLETED — Doctor 4 (Dermatologist) ──────────────────────────────
(2,  4, 'doctor', NOW() - INTERVAL '65 days' + TIME '10:00', 30, 'completed', 'Acne breakout and oily skin',                 TRUE, NOW() - INTERVAL '65 days' + TIME '10:35', 'normal',    5, 'Dr. Joshi prescribed the perfect skincare routine.'),
(12, 4, 'doctor', NOW() - INTERVAL '38 days' + TIME '11:30', 30, 'completed', 'Eczema flare-up on hands',                    TRUE, NOW() - INTERVAL '38 days' + TIME '12:05', 'normal',    4, 'Good treatment. Steroid cream helped a lot.'),
(24, 4, 'doctor', NOW() - INTERVAL '12 days' + TIME '14:00', 30, 'completed', 'Fungal infection and itching',                TRUE, NOW() - INTERVAL '12 days' + TIME '14:35', 'normal',    5, 'Very hygienic clinic and excellent advice.'),

-- ── PAST COMPLETED — Doctor 5 (Orthopedic) ─────────────────────────────────
(13, 5, 'doctor', NOW() - INTERVAL '72 days' + TIME '09:30', 45, 'completed', 'Knee pain and difficulty climbing stairs',    TRUE, NOW() - INTERVAL '72 days' + TIME '10:20', 'normal',    5, 'X-ray done same day. Physiotherapy plan perfect.'),
(20, 5, 'doctor', NOW() - INTERVAL '48 days' + TIME '11:00', 45, 'completed', 'Lower back pain after office work',           TRUE, NOW() - INTERVAL '48 days' + TIME '11:50', 'normal',    4, 'Good exercises recommended. Back pain reduced significantly.'),
(29, 5, 'doctor', NOW() - INTERVAL '32 days' + TIME '14:30', 45, 'completed', 'Hip joint pain and reduced mobility',         TRUE, NOW() - INTERVAL '32 days' + TIME '15:20', 'high',      5, 'Very knowledgeable about joint issues in older patients.'),
(15, 5, 'doctor', NOW() - INTERVAL '9  days' + TIME '10:00', 45, 'completed', 'Shoulder injury from gym workout',            TRUE, NOW() - INTERVAL '9  days' + TIME '10:50', 'normal',    4, 'MRI recommended. Good advice on rest and recovery.'),

-- ── PAST COMPLETED — Doctor 6 (Pediatrician) ───────────────────────────────
(6,  6, 'doctor', NOW() - INTERVAL '55 days' + TIME '10:00', 20, 'completed', 'Child fever and ear pain',                    TRUE, NOW() - INTERVAL '55 days' + TIME '10:25', 'normal',    5, 'Dr. Agarwal is amazing with children. Very patient.'),
(16, 6, 'doctor', NOW() - INTERVAL '35 days' + TIME '11:00', 20, 'completed', 'Vaccination and growth checkup',              TRUE, NOW() - INTERVAL '35 days' + TIME '11:25', 'normal',    5, 'Thorough growth assessment. Highly recommend.'),

-- ── PAST COMPLETED — Doctor 7 (Cardiologist) ───────────────────────────────
(7,  7, 'doctor', NOW() - INTERVAL '67 days' + TIME '15:00', 30, 'completed', 'Diabetes-related cardiac risk assessment',    TRUE, NOW() - INTERVAL '67 days' + TIME '15:35', 'high',      5, 'Dr. Menon is exceptional. Saved me from a major risk.'),
(11, 7, 'doctor', NOW() - INTERVAL '40 days' + TIME '10:30', 30, 'completed', 'Heart palpitations and hypertension review',  TRUE, NOW() - INTERVAL '40 days' + TIME '11:05', 'high',      5, 'Best cardiologist in Ahmedabad in my opinion.'),
(21, 7, 'doctor', NOW() - INTERVAL '14 days' + TIME '14:00', 30, 'completed', 'Chest tightness and blood pressure spikes',   TRUE, NOW() - INTERVAL '14 days' + TIME '14:35', 'emergency', 4, 'Quick response for emergency. Good diagnosis.'),

-- ── PAST COMPLETED — Doctor 8 (General Physician) ──────────────────────────
(22, 8, 'doctor', NOW() - INTERVAL '58 days' + TIME '09:30', 30, 'completed', 'Routine health checkup',                      TRUE, NOW() - INTERVAL '58 days' + TIME '10:05', 'normal',    4, 'Comprehensive checkup. All tests ordered efficiently.'),
(26, 8, 'doctor', NOW() - INTERVAL '27 days' + TIME '11:00', 30, 'completed', 'Stress and anxiety management',               TRUE, NOW() - INTERVAL '27 days' + TIME '11:35', 'normal',    5, 'Very empathetic doctor. Felt heard and supported.'),
(19, 8, 'doctor', NOW() - INTERVAL '7  days' + TIME '10:30', 30, 'completed', 'Seasonal allergies and runny nose',           TRUE, NOW() - INTERVAL '7  days' + TIME '11:05', 'normal',    3, 'Average consultation. Antihistamines prescribed.'),

-- ── PAST COMPLETED — Doctor 9 (ENT) ────────────────────────────────────────
(15, 9, 'doctor', NOW() - INTERVAL '62 days' + TIME '10:00', 30, 'completed', 'Chronic sinusitis and nasal congestion',       TRUE, NOW() - INTERVAL '62 days' + TIME '10:35', 'normal',    5, 'Nasal endoscopy done on first visit. Very efficient.'),
(23, 9, 'doctor', NOW() - INTERVAL '39 days' + TIME '14:00', 30, 'completed', 'Hearing loss in right ear and tinnitus',       TRUE, NOW() - INTERVAL '39 days' + TIME '14:35', 'normal',    4, 'Audiometry test recommended. Good explanation.'),
(28, 9, 'doctor', NOW() - INTERVAL '16 days' + TIME '11:30', 30, 'completed', 'Tonsillitis and difficulty swallowing',        TRUE, NOW() - INTERVAL '16 days' + TIME '12:05', 'normal',    5, 'Quick diagnosis. Throat cleared up in 5 days.'),

-- ── PAST COMPLETED — Doctor 10 (Neurologist) ───────────────────────────────
(10, 10, 'doctor', NOW() - INTERVAL '78 days' + TIME '10:00', 45, 'completed', 'Persistent migraines and visual aura',       TRUE, NOW() - INTERVAL '78 days' + TIME '10:50', 'normal',    5, 'Finally found the root cause of my migraines. Excellent.'),
(18, 10, 'doctor', NOW() - INTERVAL '46 days' + TIME '14:30', 45, 'completed', 'Numbness in both hands and neck pain',       TRUE, NOW() - INTERVAL '46 days' + TIME '15:20', 'normal',    4, 'MRI recommended. Good follow-up plan given.'),
(29, 10, 'doctor', NOW() - INTERVAL '20 days' + TIME '10:00', 45, 'completed', 'Memory lapses and concentration issues',     TRUE, NOW() - INTERVAL '20 days' + TIME '10:50', 'high',      5, 'Very thorough neurological examination. Reassuring.'),

-- ── PAST COMPLETED — Doctor 11 (Orthopedic) ────────────────────────────────
(27, 11, 'doctor', NOW() - INTERVAL '53 days' + TIME '09:00', 45, 'completed', 'Wrist fracture recovery and rehab',          TRUE, NOW() - INTERVAL '53 days' + TIME '09:50', 'normal',    4, 'Good rehab exercises. Wrist healed well.'),
(30, 11, 'doctor', NOW() - INTERVAL '33 days' + TIME '11:00', 45, 'completed', 'Knee replacement post-op review',            TRUE, NOW() - INTERVAL '33 days' + TIME '11:50', 'high',      5, 'Excellent post-surgery care. Walking without pain now.'),

-- ── PAST COMPLETED — Doctor 12 (Diabetologist) ─────────────────────────────
(3,  12, 'doctor', NOW() - INTERVAL '88 days' + TIME '10:00', 30, 'completed', 'HbA1c high — comprehensive diabetes review',  TRUE, NOW() - INTERVAL '88 days' + TIME '10:35', 'normal',    5, 'Best diabetes specialist in Gandhinagar. Life-changing advice.'),
(7,  12, 'doctor', NOW() - INTERVAL '60 days' + TIME '11:30', 30, 'completed', 'Diabetes diet and insulin dosage review',      TRUE, NOW() - INTERVAL '60 days' + TIME '12:05', 'normal',    4, 'Practical dietary advice. Blood sugar now under control.'),
(11, 12, 'doctor', NOW() - INTERVAL '35 days' + TIME '14:00', 30, 'completed', 'Diabetic neuropathy — foot care review',       TRUE, NOW() - INTERVAL '35 days' + TIME '14:35', 'high',      5, 'Specialist in complications. Very thorough.'),
(17, 12, 'doctor', NOW() - INTERVAL '11 days' + TIME '10:30', 30, 'completed', 'Metformin side effects and dose adjustment',   TRUE, NOW() - INTERVAL '11 days' + TIME '11:05', 'normal',    4, 'Good explanation of why medication was changed.'),
(21, 12, 'doctor', NOW() - INTERVAL '4  days' + TIME '09:30', 30, 'completed', 'Pre-diabetes lifestyle consultation',          TRUE, NOW() - INTERVAL '4  days' + TIME '10:05', 'normal',    5, 'Detailed lifestyle plan. Motivated me to exercise daily.'),

-- ── More completed appointments for chronic patients (patient 1, 3, 11) ────
(1,  9, 'doctor', NOW() - INTERVAL '44 days' + TIME '10:00', 30, 'completed', 'Ear blockage and hearing difficulty',         TRUE, NOW() - INTERVAL '44 days' + TIME '10:35', 'normal',    4, 'Quick clearance. Hearing restored immediately.'),
(3,  5, 'doctor', NOW() - INTERVAL '37 days' + TIME '14:30', 45, 'completed', 'Knee pain worsening with diabetes',           TRUE, NOW() - INTERVAL '37 days' + TIME '15:20', 'normal',    5, 'Explained the connection between diabetes and joint pain.'),
(11, 2, 'doctor', NOW() - INTERVAL '21 days' + TIME '10:00', 30, 'completed', 'Cardiac risk review — multiple conditions',   TRUE, NOW() - INTERVAL '21 days' + TIME '10:35', 'high',      5, 'Comprehensive cardiac assessment for complex patient.'),
(25, 12,'doctor', NOW() - INTERVAL '6  days' + TIME '11:30', 30, 'completed', 'HbA1c and BP review — dual condition',        TRUE, NOW() - INTERVAL '6  days' + TIME '12:05', 'high',      4, 'Both conditions reviewed together. Very convenient.')
ON CONFLICT DO NOTHING;

-- ── TODAY'S APPOINTMENT (appointment_id=3 guaranteed by sequence reset above) ─

INSERT INTO appointments (appointment_id, patient_id, doctor_id, appointment_type,
                          scheduled_at, duration_mins, status, reason,
                          summary_generated, priority)
VALUES (3, 1, 1, 'doctor', CURRENT_DATE + TIME '10:30:00', 30, 'scheduled',
        'Follow-up for hypertension and BP medication review', FALSE, 'normal')
ON CONFLICT (appointment_id) DO UPDATE SET
    scheduled_at = CURRENT_DATE + TIME '10:30:00',
    status = 'scheduled',
    summary_generated = FALSE;

-- ── UPCOMING APPOINTMENTS (next 7 days) ─────────────────────────────────────
INSERT INTO appointments (patient_id, doctor_id, appointment_type, scheduled_at, duration_mins,
                          status, reason, summary_generated, priority)
VALUES
(3,  1,  'doctor', CURRENT_DATE + INTERVAL '1 day'  + TIME '11:00:00', 30, 'scheduled', 'Diabetes check-up and HbA1c review',             FALSE, 'normal'),
(2,  4,  'doctor', CURRENT_DATE + INTERVAL '2 days' + TIME '10:30:00', 30, 'scheduled', 'Follow-up for acne treatment',                   FALSE, 'normal'),
(5,  2,  'doctor', CURRENT_DATE + INTERVAL '3 days' + TIME '14:00:00', 30, 'scheduled', 'Post-discharge cardiac follow-up',               FALSE, 'high'),
(11, 12, 'doctor', CURRENT_DATE + INTERVAL '4 days' + TIME '09:30:00', 30, 'scheduled', 'Quarterly diabetes and neuropathy review',        FALSE, 'high'),
(16, 6,  'doctor', CURRENT_DATE + INTERVAL '5 days' + TIME '11:00:00', 20, 'scheduled', 'Routine vaccination',                            FALSE, 'normal'),
(8,  3,  'doctor', CURRENT_DATE + INTERVAL '6 days' + TIME '10:00:00', 30, 'scheduled', 'Anxiety management follow-up',                   FALSE, 'normal'),
(13, 5,  'doctor', CURRENT_DATE + INTERVAL '7 days' + TIME '14:30:00', 45, 'scheduled', 'Knee physiotherapy progress review',              FALSE, 'normal')
ON CONFLICT DO NOTHING;

-- ── PERIODIC SESSION SERIES ──────────────────────────────────────────────────
-- Series 1: Physiotherapy for patient 13 with Dr. Vikram Patel (Orthopedic) — 4 weekly sessions
INSERT INTO appointments (patient_id, doctor_id, appointment_type, scheduled_at, duration_mins,
                          status, reason, summary_generated, is_periodic, period_days,
                          total_sessions, session_number, priority,
                          marked_complete_at, patient_rating, patient_review)
VALUES
(13, 5, 'nurse', NOW() - INTERVAL '21 days' + TIME '09:00', 45, 'completed', 'Knee physiotherapy session 1 of 4', TRUE,  TRUE, 7, 4, 1, 'normal', NOW() - INTERVAL '21 days' + TIME '09:50', 5, 'Physio session was very helpful. Pain reduced.'),
(13, 5, 'nurse', NOW() - INTERVAL '14 days' + TIME '09:00', 45, 'completed', 'Knee physiotherapy session 2 of 4', TRUE,  TRUE, 7, 4, 2, 'normal', NOW() - INTERVAL '14 days' + TIME '09:50', 4, 'Good progress. Swelling going down.'),
(13, 5, 'nurse', NOW() + INTERVAL '7  days' + TIME '09:00', 45, 'scheduled', 'Knee physiotherapy session 3 of 4', FALSE, TRUE, 7, 4, 3, 'normal', NULL, NULL, NULL),
(13, 5, 'nurse', NOW() + INTERVAL '14 days' + TIME '09:00', 45, 'scheduled', 'Knee physiotherapy session 4 of 4', FALSE, TRUE, 7, 4, 4, 'normal', NULL, NULL, NULL)
ON CONFLICT DO NOTHING;

-- Series 2: Physiotherapy for patient 29 with Dr. Deepa Iyer (Orthopedic) — 4 weekly sessions
INSERT INTO appointments (patient_id, doctor_id, appointment_type, scheduled_at, duration_mins,
                          status, reason, summary_generated, is_periodic, period_days,
                          total_sessions, session_number, priority,
                          marked_complete_at, patient_rating, patient_review)
VALUES
(29, 11, 'nurse', NOW() - INTERVAL '14 days' + TIME '11:00', 45, 'completed', 'Hip physiotherapy session 1 of 4', TRUE,  TRUE, 7, 4, 1, 'normal', NOW() - INTERVAL '14 days' + TIME '11:50', 5, 'Excellent physiotherapist. Hip mobility improving.'),
(29, 11, 'nurse', NOW() - INTERVAL '7  days' + TIME '11:00', 45, 'completed', 'Hip physiotherapy session 2 of 4', TRUE,  TRUE, 7, 4, 2, 'normal', NOW() - INTERVAL '7  days' + TIME '11:50', 4, 'Good session. Exercises at home are working.'),
(29, 11, 'nurse', NOW() + INTERVAL '7  days' + TIME '11:00', 45, 'scheduled', 'Hip physiotherapy session 3 of 4', FALSE, TRUE, 7, 4, 3, 'normal', NULL, NULL, NULL),
(29, 11, 'nurse', NOW() + INTERVAL '14 days' + TIME '11:00', 45, 'scheduled', 'Hip physiotherapy session 4 of 4', FALSE, TRUE, 7, 4, 4, 'normal', NULL, NULL, NULL)
ON CONFLICT DO NOTHING;

-- Series 3: Weekly diabetic review for patient 3 with Dr. Nitin Bhatt — 4 weekly sessions
INSERT INTO appointments (patient_id, doctor_id, appointment_type, scheduled_at, duration_mins,
                          status, reason, summary_generated, is_periodic, period_days,
                          total_sessions, session_number, priority,
                          marked_complete_at, patient_rating, patient_review)
VALUES
(3, 12, 'doctor', NOW() - INTERVAL '21 days' + TIME '10:00', 30, 'completed', 'Weekly blood sugar monitoring session 1 of 4', TRUE,  TRUE, 7, 4, 1, 'normal', NOW() - INTERVAL '21 days' + TIME '10:35', 5, 'Fasting sugar reading discussed. Medication on track.'),
(3, 12, 'doctor', NOW() - INTERVAL '14 days' + TIME '10:00', 30, 'completed', 'Weekly blood sugar monitoring session 2 of 4', TRUE,  TRUE, 7, 4, 2, 'normal', NOW() - INTERVAL '14 days' + TIME '10:35', 4, 'HbA1c trending down. Diet changes are helping.'),
(3, 12, 'doctor', NOW() + INTERVAL '7  days' + TIME '10:00', 30, 'scheduled', 'Weekly blood sugar monitoring session 3 of 4', FALSE, TRUE, 7, 4, 3, 'normal', NULL, NULL, NULL),
(3, 12, 'doctor', NOW() + INTERVAL '14 days' + TIME '10:00', 30, 'scheduled', 'Weekly blood sugar monitoring session 4 of 4', FALSE, TRUE, 7, 4, 4, 'normal', NULL, NULL, NULL)
ON CONFLICT DO NOTHING;

-- Series 4: Weekly diabetic review for patient 11 with Dr. Nitin Bhatt — 4 weekly sessions
INSERT INTO appointments (patient_id, doctor_id, appointment_type, scheduled_at, duration_mins,
                          status, reason, summary_generated, is_periodic, period_days,
                          total_sessions, session_number, priority,
                          marked_complete_at, patient_rating, patient_review)
VALUES
(11, 12, 'doctor', NOW() - INTERVAL '14 days' + TIME '14:00', 30, 'completed', 'Diabetic neuropathy monitoring session 1 of 4', TRUE,  TRUE, 7, 4, 1, 'normal', NOW() - INTERVAL '14 days' + TIME '14:35', 5, 'Foot sensation tests done. Early detection is key.'),
(11, 12, 'doctor', NOW() - INTERVAL '7  days' + TIME '14:00', 30, 'completed', 'Diabetic neuropathy monitoring session 2 of 4', TRUE,  TRUE, 7, 4, 2, 'normal', NOW() - INTERVAL '7  days' + TIME '14:35', 5, 'Improvement noted in foot sensation scores.'),
(11, 12, 'doctor', NOW() + INTERVAL '7  days' + TIME '14:00', 30, 'scheduled', 'Diabetic neuropathy monitoring session 3 of 4', FALSE, TRUE, 7, 4, 3, 'normal', NULL, NULL, NULL),
(11, 12, 'doctor', NOW() + INTERVAL '14 days' + TIME '14:00', 30, 'scheduled', 'Diabetic neuropathy monitoring session 4 of 4', FALSE, TRUE, 7, 4, 4, 'normal', NULL, NULL, NULL)
ON CONFLICT DO NOTHING;

-- ============================================================
-- SESSION SUMMARIES (one per completed appointment)
-- Match appointment order: inner SELECT gets completed appointments in insert order
-- We use appointment JOIN to identify them reliably by reason + patient_id + doctor_id
-- ============================================================

INSERT INTO session_summaries (appointment_id, full_transcript, diagnosis, clinical_notes, follow_up)
SELECT a.appointment_id,
       d.transcript,
       d.diagnosis,
       d.clinical_notes,
       d.follow_up
FROM appointments a
JOIN (VALUES
  -- (patient_id, doctor_id, reason_keyword, transcript, diagnosis, clinical_notes, follow_up)
  (1,  1, 'High blood pressure and headache',
   'Doctor: Good morning Rahul. What brings you in today? Patient: Doctor, I have been having severe headaches for two days and my home BP machine shows 160 over 100. Doctor: Let me check that. Yes, your BP is 158 over 98. Are you taking your Amlodipine regularly? Patient: Sometimes I forget. Doctor: That is likely why. Headaches at this BP level are expected. I am increasing your Amlodipine dose and adding a low-dose diuretic.',
   'Stage 2 hypertension with hypertensive headache due to medication non-compliance.',
   'BP: 158/98 mmHg. HR: 82 bpm. No focal neurological deficits. Fundoscopy normal.',
   'Increase Amlodipine to 10mg. Add Hydrochlorothiazide 12.5mg once daily. Return in 2 weeks for BP recheck.'),

  (1,  1, 'Routine BP check and medication review',
   'Doctor: Hello Rahul. How has the blood pressure been? Patient: Much better doctor. Headaches gone. Home readings are around 130 over 85. Doctor: That is excellent progress. Let me check today. 132 over 84 — well controlled. How are you tolerating the new dose? Patient: Some ankle swelling but manageable. Doctor: I will switch the diuretic for that. Let us continue same plan.',
   'Hypertension — well controlled on current regimen. Mild ankle oedema likely drug-related.',
   'BP: 132/84 mmHg. HR: 78 bpm. Mild bilateral ankle oedema noted. Lungs clear.',
   'Replace Hydrochlorothiazide with Indapamide 1.25mg. Continue Amlodipine 10mg. Follow up in 4 weeks.'),

  (1,  1, 'Chest tightness and breathlessness',
   'Doctor: Rahul, what happened? Patient: I had chest tightness while climbing stairs yesterday and today again at rest. Bit scared. Doctor: I understand. Let me do an ECG now. The ECG shows normal sinus rhythm — no acute changes. Your BP is 145 over 92 though. Patient: Could it be my heart? Doctor: It could be hypertension-related or anxiety. Referring you to cardiologist for stress test. Continue all medications.',
   'Hypertensive chest discomfort — cardiac cause not ruled out. Referral to cardiologist advised.',
   'BP: 145/92 mmHg. ECG: Normal sinus rhythm, no ST changes. Chest auscultation clear. Mild anxiety noted.',
   'Urgent referral to cardiologist (Dr. Meera Nair). Continue all BP medications. Avoid strenuous activity until reviewed.'),

  (2,  1, 'Fever and sore throat for 3 days',
   'Doctor: Hello Priya. How long have you had the fever? Patient: Three days doctor. Temperature reaches 101 at night. Sore throat and body ache too. Doctor: Let me examine. Throat is red with mild exudate on right tonsil. Could be strep. I will do a rapid test. Rapid strep negative. Likely viral pharyngitis. Patient: No antibiotics needed? Doctor: Correct. Rest, fluids, and these medicines.',
   'Acute viral pharyngitis with mild right tonsillar exudate. Strep rapid test negative.',
   'Temp: 101.2°F. Throat: erythematous, right tonsillar exudate present. No cervical lymphadenopathy. Lungs clear.',
   'Paracetamol 500mg for fever. Betadine gargle twice daily. Return if fever persists beyond 7 days or worsens.'),

  (2,  1, 'Skin rash on forearm',
   'Doctor: Good morning Priya. Tell me about this rash. Patient: It appeared suddenly on my forearm last week. Slightly itchy, raised red patches. Doctor: This looks like contact dermatitis, possibly from a new soap or fabric. Any new products recently? Patient: Yes, I changed my washing powder. Doctor: That is likely the culprit. Stop using it. I will prescribe a topical steroid and antihistamine.',
   'Contact dermatitis on left forearm — likely reaction to new detergent.',
   'Raised erythematous plaques 3x4 cm on left forearm. No vesicles. No systemic involvement.',
   'Betamethasone cream 0.05% twice daily for 7 days. Cetirizine 10mg at night for 5 days. Identify and avoid trigger.'),

  (3,  1, 'Uncontrolled blood sugar and fatigue',
   'Doctor: Good morning Vijay. How has your sugar been? Patient: Not good doctor. Fasting is around 190 and post-meal goes to 280. Very tired all day. Doctor: Your HbA1c today is 9.2 — that is high. Current dose of Metformin is not sufficient. I am adding a second medication. Any chest pain or breathing issues? Patient: No doctor. Doctor: Good. Let us also check kidneys and cholesterol.',
   'Poorly controlled Type 2 Diabetes Mellitus — HbA1c 9.2%. Medication intensification required.',
   'FBS: 192 mg/dl. HbA1c: 9.2%. BP: 138/88 mmHg. No signs of peripheral neuropathy. Fundoscopy deferred.',
   'Add Glimepiride 1mg once daily with breakfast. Order lipid profile and urine microalbumin. Return in 4 weeks.'),

  (3,  1, 'Hypertension follow-up and dizziness',
   'Doctor: Vijay, how are you feeling? Patient: Dizziness when I stand up quickly and my home BP readings vary a lot — from 130 to 160. Doctor: That variation suggests orthostatic hypotension. Let me check lying and standing BP. Lying 148 over 90, standing 122 over 78. Yes — a drop of 26 points systolic. Patient: Is that dangerous? Doctor: We need to adjust your medication timing.',
   'Orthostatic hypotension secondary to over-treatment of hypertension in diabetic patient.',
   'Lying BP: 148/90 mmHg. Standing BP: 122/78 mmHg. Orthostatic drop: 26 mmHg systolic. HR stable.',
   'Reduce Amlodipine to 5mg. Take morning dose with food. Increase fluid and salt intake slightly. Review in 2 weeks.'),

  (3,  1, 'Foot numbness and tingling — diabetic review',
   'Doctor: Vijay, any new symptoms? Patient: Yes, numbness and tingling in both feet especially at night. Sometimes burning sensation. Doctor: Classic signs of diabetic peripheral neuropathy. Let me test vibration sense. Vibration reduced bilaterally. Pin-prick sensation also reduced in toes. Patient: Is it reversible? Doctor: Better control of sugar slows progression.',
   'Diabetic peripheral neuropathy — bilateral symmetrical, affecting vibration and pin-prick sensation.',
   'Vibration sense absent at toes bilaterally. Pin-prick reduced up to ankle. BP: 136/84 mmHg. HbA1c: 8.4%.', 
   'Start Pregabalin 75mg at night for neuropathic pain. Refer to podiatrist for foot care. HbA1c target below 7.'),

  (1,  2, 'Chest pain on exertion and palpitations',
   'Doctor: Hello Rahul. Dr. Sharma referred you for cardiac evaluation. Tell me about the chest pain. Patient: It comes when I climb stairs or walk fast. Goes away with rest. Also feel my heart racing sometimes. Doctor: Classic angina description. ECG shows some ST depression in lateral leads. We need a stress test and echo. Patient: Is it serious? Doctor: We are going to find out. Starting you on medication immediately.',
   'Suspected stable angina pectoris with exertional chest pain and ECG changes — further evaluation required.',
   'ECG: ST depression 1mm in V4-V6. BP: 150/96 mmHg. Cardiac auscultation: normal S1 S2, no murmurs. BMI: 27.',
   'Treadmill stress test within 1 week. Echo within 2 weeks. Start Atenolol 25mg once daily. Nitrate sublingual for breakthrough pain.'),

  (3,  2, 'Hypertension not controlled on current meds',
   'Doctor: Vijay, your GP sent you for hypertension review. Current medications? Patient: Amlodipine 5mg and Metformin. Doctor: BP today is 158 over 100 — inadequate control. In a diabetic with hypertension, ACE inhibitor is the preferred add-on for kidney protection. Any cough? Patient: No. Doctor: Perfect, starting Ramipril then.',
   'Poorly controlled hypertension in Type 2 DM — adding ACE inhibitor for renoprotection.',
   'BP: 158/100 mmHg. HR: 84 bpm. Renal function normal. Urine albumin-to-creatinine ratio: 45 (mildly elevated).',
   'Add Ramipril 5mg once daily. Monitor potassium in 2 weeks. Target BP below 130/80 in diabetic patient.'),

  (5,  2, 'Shortness of breath and ankle swelling',
   'Doctor: Mr. Deepak, how long has this been going on? Patient: About 2 weeks. Cannot walk 50 metres without stopping. Ankles swelling badly by evening. Doctor: This sounds like heart failure. Chest X-ray shows pulmonary congestion. BNP markedly elevated. Echo shows EF of 35%. Patient: This is serious? Doctor: Yes. Admitting you today for IV diuretics and workup.',
   'Acute decompensated heart failure — reduced ejection fraction (EF 35%) with pulmonary congestion.',
   'BP: 100/70 mmHg. HR: 110 bpm irregular. JVP elevated. Bilateral ankle oedema 3+. Crepitations bilateral bases. BNP elevated.',
   'Hospital admission. IV Furosemide. Cardiology follow-up weekly. Start Sacubitril-Valsartan after stabilisation.'),

  (17, 2, 'Irregular heartbeat and fatigue',
   'Doctor: Mr. Prakash, tell me about the irregular heartbeat. Patient: For 2 weeks I feel my heart skipping beats and I am very tired. 70 years old and worried. Doctor: ECG shows atrial fibrillation. Is this new for you? Patient: First time I am aware. Doctor: New-onset AF needs immediate rate control and anticoagulation to prevent stroke.',
   'New-onset atrial fibrillation with rapid ventricular response — anticoagulation initiated.',
   'ECG: Atrial fibrillation, HR 108 bpm irregular. BP: 136/88 mmHg. Thyroid function normal. Echo: left atrial dilatation.',
   'Start Apixaban 5mg twice daily. Bisoprolol 2.5mg for rate control. Cardiology review in 1 week. CHA2DS2-VASc score: 4.'),

  (25, 2, 'Post-angioplasty follow-up',
   'Doctor: Good morning Mukesh. Two months post-stenting — how are you feeling? Patient: Much better. No chest pain. Taking all medicines regularly. Doctor: ECG normal. Echo shows EF improved to 55% from 42%. Excellent response. Patient: When can I return to normal work? Doctor: Gradually. Avoid heavy lifting for another month.',
   'Post-PTCA with stent to LAD — excellent haemodynamic recovery. EF normalised to 55%.',
   'BP: 118/76 mmHg. HR: 68 bpm regular. ECG: normal sinus rhythm. Echo: EF 55%, no wall motion abnormality.',
   'Continue dual antiplatelet therapy for 12 months. Atorvastatin 40mg lifelong. Resume light activity. Review in 3 months.'),

  (4,  3, 'Thyroid levels high and weight gain',
   'Doctor: Hello Anita. What has been bothering you? Patient: Weight gain of 5 kg in 3 months despite dieting. Hair falling, always cold, very tired. Doctor: Classic hypothyroidism symptoms. TSH is 12.4 — very high. Your thyroid is underactive. Patient: Is it curable? Doctor: Managed well with daily tablet. Starting Levothyroxine.',
   'Primary hypothyroidism — TSH 12.4 mIU/L with symptomatic presentation.',
   'TSH: 12.4 mIU/L. T4: 0.6 ng/dl (low). Weight: 72kg (gained 5kg in 3 months). BP normal. Pulse slow at 58 bpm.',
   'Start Levothyroxine 50mcg daily on empty stomach. Repeat TSH in 6 weeks. Avoid calcium supplements within 4 hours of dose.'),

  (6,  3, 'Cold and cough for 5 days with fever',
   'Doctor: Hello Kavitha. Five days of cold and cough — any improvement? Patient: Getting worse doctor. Fever up to 102 yesterday. Yellow sputum now. Doctor: Yellow sputum after 5 days suggests secondary bacterial infection. Chest is clear but there is post-nasal drip. Starting antibiotics. Patient: Any tests needed? Doctor: Sputum culture if not better in 3 days.',
   'Acute bacterial upper respiratory infection with purulent rhinitis — antibiotic therapy initiated.',
   'Temp: 100.8°F. Throat: mild congestion. Nasal discharge: mucopurulent. Chest: clear. SpO2: 99%.',
   'Amoxicillin-Clavulanate 625mg twice daily for 5 days. Paracetamol for fever. Saline nasal rinse twice daily.'),

  (8,  3, 'Anxiety attacks and sleep issues',
   'Doctor: Hello Rekha. Tell me what has been happening. Patient: I get sudden racing heart, sweating, feeling like I am going to die. Happens 2-3 times a week. Cannot sleep well. Doctor: These sound like panic attacks. Any life stressors? Patient: Yes, work pressure and family issues. Doctor: I am going to start a low-dose medication and refer you for counselling.',
   'Panic disorder with insomnia — likely precipitated by psychosocial stressors.',
   'HR: 88 bpm. BP: 124/80 mmHg. Mental status: anxious affect, no psychosis. PHQ-9 score: 12 (moderate).',
   'Escitalopram 5mg once daily (increase to 10mg after 1 week). Referral to clinical psychologist. Sleep hygiene advice given.'),

  (9,  3, 'Stomach pain and acidity for 1 week',
   'Doctor: Manish, where exactly is the stomach pain? Patient: Upper middle area. Burns especially at night after lying down. Sour taste in mouth. Doctor: This is classic GERD. Any NSAIDs or alcohol? Patient: I take ibuprofen sometimes for headaches. Doctor: That is worsening it. Stopping NSAIDs and starting acid suppression.',
   'Gastro-oesophageal reflux disease (GERD) — NSAID-induced exacerbation.',
   'Upper abdominal tenderness on palpation. No guarding. Bowel sounds normal. No jaundice.',
   'Stop all NSAIDs. Start Pantoprazole 40mg 30 minutes before breakfast. Avoid large meals, caffeine, and lying down after eating.'),

  (14, 3, 'Viral fever and body ache',
   'Doctor: Good morning. Fever since when? Patient: Three days. Body ache, runny nose. Temperature 100 at home. Doctor: Viral symptoms. No bacterial signs on examination. Throat normal, chest clear. Patient: Should I take antibiotics just in case? Doctor: No — antibiotics do not work for viral infections and can cause resistance. Let this run its course with supportive treatment.',
   'Acute viral febrile illness — symptomatic management appropriate, no antibiotics indicated.',
   'Temp: 99.8°F. Throat: mild congestion. Chest: clear. Lymph nodes: not enlarged. Abdomen: soft.',
   'Paracetamol 500mg every 6 hours if temp above 99. ORS for hydration. Rest for 3 days. Return if temp above 103 or symptoms worsen.'),

  (2,  4, 'Acne breakout and oily skin',
   'Doctor: Hello Priya. When did the acne start? Patient: About 6 months ago. Getting worse before my periods. Oily skin always. Doctor: Hormonal acne pattern — worse premenstrually, mainly jaw and chin. Any oral contraceptive or other hormonal medication? Patient: No. Doctor: Let us start topical treatment first and review.',
   'Hormonal acne vulgaris with comedonal and papular lesions — predominantly jaw and chin distribution.',
   'Skin: oily, multiple closed comedones and papules on chin, jaw, forehead. No cystic lesions. PCOS screen recommended.',
   'Adapalene 0.1% gel at night. Clindamycin 1% lotion twice daily. Sunscreen daily. Review in 8 weeks.'),

  (12, 4, 'Eczema flare-up on hands',
   'Doctor: Sunita, the eczema is worse again? Patient: Yes, both hands. The skin is very dry, cracking. Very itchy at night. Doctor: Classic atopic dermatitis flare. Any new soaps or detergents? Patient: Changed my dish soap. Doctor: Stop using it. I will prescribe steroid cream for the flare and an emollient for daily use.',
   'Atopic dermatitis (eczema) — bilateral hand flare likely triggered by contact with new detergent.',
   'Hands: bilateral erythema, dry scaly plaques, lichenification on dorsum. No secondary infection. SCORAD: moderate.',
   'Hydrocortisone 1% cream twice daily for 10 days (not more). Petroleum jelly after every handwash. Wear cotton gloves for housework.'),

  (24, 4, 'Fungal infection and itching',
   'Doctor: Hello Shruti. Where is the itching? Patient: Inner thighs and under arms. Red ring-shaped patches. Worse after gym. Doctor: This is tinea cruris — ringworm of the groin. Very common in warm climates after exercise. Patient: Is it contagious? Doctor: To an extent. Do not share towels. Antifungal cream and powder.',
   'Tinea cruris (ringworm) — bilateral inguinal and axillary regions. Gym hygiene identified as trigger.',
   'Annular erythematous plaques with central clearing and raised borders in bilateral groin and axillae. KOH: positive for fungal hyphae.',
   'Clotrimazole 1% cream twice daily for 3 weeks. Antifungal dusting powder after shower. Change gym clothes immediately after workout.'),

  (13, 5, 'Knee pain and difficulty climbing stairs',
   'Doctor: Mr. Harish, how long has the knee pain been there? Patient: About 6 months. Especially right knee. Cannot climb stairs properly. Crackling sound. Doctor: X-ray shows moderate osteoarthritis in right knee — loss of joint space. BMI is 32 which adds load. Let us start physiotherapy and medication. Patient: Do I need surgery? Doctor: Not yet. Conservative management first.',
   'Right knee osteoarthritis — grade II, with crepitus and joint space narrowing on X-ray.',
   'Right knee: crepitus on flexion-extension, mild effusion, tenderness at medial joint line. X-ray: grade II OA changes. BMI: 32.',
   'Physiotherapy 3x weekly for 4 weeks. Diclofenac gel locally. Calcium 500mg + Vitamin D3. Weight loss target 5kg in 3 months.'),

  (20, 5, 'Lower back pain after office work',
   'Doctor: Geeta, when does the pain start? Patient: After 2-3 hours of sitting at desk. Radiates to left buttock. Doctor: Could be discogenic or piriformis syndrome. Straight leg raise test: negative. No neurological deficit. Postural analysis shows forward head posture. Patient: Is it a disc? Doctor: Not likely. Muscle and posture related.',
   'Mechanical low back pain with left buttock radiation — postural origin, no neurological compromise.',
   'SLR: negative bilaterally. Power, reflexes: normal. Lumbar flexion mildly restricted. No saddle anaesthesia.',
   'Physiotherapy 2x weekly for 3 weeks. Diclofenac 50mg twice daily for 5 days. Ergonomic workstation adjustment. Core strengthening exercises.'),

  (29, 5, 'Hip joint pain and reduced mobility',
   'Doctor: Mr. Bharat, how bad is the hip pain? Patient: Cannot put on my shoes, cannot cross my legs. Walking with a limp. Doctor: Hip examination shows reduced internal rotation and abduction. X-ray shows severe osteoarthritis right hip — loss of joint space, osteophytes. Patient: What are options? Doctor: Hip replacement likely needed.',
   'Severe right hip osteoarthritis — grade III-IV. Hip replacement surgery recommended.',
   'Right hip: external rotation deformity, restricted ROM. X-ray: severe joint space loss, subchondral sclerosis, osteophytes. Trendelenburg: positive.',
   'Refer to hip replacement surgeon. Physiotherapy for muscle strengthening pre-op. Diclofenac gel for pain. Avoid high-impact activity.'),

  (15, 5, 'Shoulder injury from gym workout',
   'Doctor: Ajay, what happened at the gym? Patient: Was doing overhead press when I felt a pop in my right shoulder. Pain since then, cannot lift arm above 90 degrees. Doctor: Likely rotator cuff strain. Testing impingement signs. Neer positive, Hawkins positive. MRI recommended to rule out tear.',
   'Right rotator cuff impingement syndrome — MRI needed to exclude full-thickness tear.',
   'Right shoulder: painful arc 70-120 degrees. Neer test: positive. Hawkins test: positive. Power reduced in abduction. No neurovascular deficit.',
   'MRI right shoulder urgently. Sling for 1 week. Ibuprofen 400mg twice daily with food. No overhead activities. Physio referral after MRI.'),

  (6,  6, 'Child fever and ear pain',
   'Doctor: Hello, I am Dr. Agarwal. What happened to the little one? Parent: Fever since morning, 38.5 degrees, pulling at left ear, crying a lot, not eating. Doctor: Let me examine the ear. Left ear: tympanic membrane red and bulging. Right ear normal. Classic acute otitis media. Patient: Will antibiotics help? Doctor: Yes, this is bacterial. Starting Amoxicillin.',
   'Acute otitis media — left ear, bacterial cause likely. Antibiotic therapy initiated.',
   'Temp: 38.5°C. Left TM: erythematous, bulging, reduced mobility. Right TM: normal. No mastoid tenderness.',
   'Amoxicillin 40mg/kg/day in 3 divided doses for 7 days. Paracetamol for fever and pain. Review in 3 days if not improving.'),

  (16, 6, 'Vaccination and growth checkup',
   'Doctor: Good morning. Growth checkup and MMR vaccine today. How is the child eating and sleeping? Parent: Eating well, sleeping 10 hours. Active child. Doctor: Weight is 12kg, height 87cm — both on 50th percentile. Excellent growth. Ears, eyes, heart all normal. Giving MMR and Varicella vaccines today.',
   'Routine 15-month developmental checkup — growth parameters on 50th centile. Vaccinations given.',
   'Wt: 12kg, Ht: 87cm, HC: 47cm. All on 50th centile. Developmental milestones appropriate. Cardiac, respiratory, abdominal exam normal.',
   'MMR given. Varicella given. May have mild fever 7-10 days post-MMR. Next review at 18 months.'),

  (7,  7, 'Diabetes-related cardiac risk assessment',
   'Doctor: Mr. Suresh, as a diabetic with 15 years history, we need to assess your cardiac risk. Any chest pain or breathlessness? Patient: Mild breathlessness on exertion. Doctor: ECG shows mild left ventricular hypertrophy. Echo: EF 52%, diastolic dysfunction grade 1. Your 10-year ASCVD risk is 32%. High risk patient. Starting statin.',
   'High cardiovascular risk in Type 2 DM — LVH on ECG, diastolic dysfunction on echo. Primary prevention with statin.',
   'ECG: LVH by voltage criteria. Echo: EF 52%, E/A ratio 0.8 (diastolic dysfunction grade 1). BP: 142/88 mmHg. LDL: 142 mg/dl.',
   'Start Rosuvastatin 20mg at night. Target LDL below 70 mg/dl. Aspirin 75mg daily. Strict BP and sugar control. Review in 3 months.'),

  (11, 7, 'Heart palpitations and hypertension review',
   'Doctor: Ravi, you have three conditions — diabetes, hypertension, asthma. Managing all medications? Patient: It is difficult. 9 tablets daily. Sometimes I miss. Doctor: Medication burden is real. ECG shows premature ventricular contractions — benign in your case. Let me simplify your regimen. Patient: Please. Doctor: Combining two BP meds into one tablet.',
   'Symptomatic PVCs in patient with multiple comorbidities — benign, likely medication non-compliance related.',
   'ECG: occasional PVCs, no sustained VT. BP: 148/92 mmHg. SpO2: 96%. HR: 84 bpm with occasional irregularity.',
   'Switch to Telmisartan-Amlodipine combination tablet. Reassurance re: benign PVCs. 24-hour Holter monitor. Medication chart provided.'),

  (21, 7, 'Chest tightness and blood pressure spikes',
   'Doctor: Dilip, you came as emergency — chest tightness and BP 180 over 110 at home. How long? Patient: Since morning. Sweating a lot. Doctor: This is a hypertensive urgency. Urgent ECG, troponin, and chest X-ray ordered. All negative for acute MI. Sublingual nitrate given — BP now 152 over 94. Patient: I was scared it was a heart attack. Doctor: Ruled out. But needs same day treatment adjustment.',
   'Hypertensive urgency — BP 180/110 mmHg, no end-organ damage. Acute coronary syndrome excluded.',
   'BP: 180/110 mmHg on arrival, 152/94 after treatment. ECG: normal. Troponin: negative. CXR: no pulmonary oedema. HR: 96 bpm.',
   'Add Labetalol 100mg twice daily to existing regimen. Monitor BP every 30 minutes for 2 hours. Follow up next day. Salt restriction reinforced.'),

  (22, 8, 'Routine health checkup',
   'Doctor: Hello Hema. Annual health check — any complaints? Patient: No major issues. Periods irregular for 3 months. Mild fatigue. Doctor: Let us do a full panel. TSH, CBC, fasting glucose, lipids, vitamin D. Thyroid normal. But vitamin D very low at 8. And mild iron deficiency. Patient: That explains the fatigue. Doctor: Exactly.',
   'Vitamin D deficiency and iron deficiency anaemia — incidentally detected on routine health screen.',
   'BP: 110/72 mmHg. Hb: 10.8 g/dl. MCV: 72 (microcytic). TSH: 2.1 (normal). Vitamin D: 8 ng/ml (severely deficient). Fasting glucose: 88 mg/dl.',
   'Vitamin D 60,000 IU weekly for 8 weeks, then daily supplementation. Ferrous sulphate 150mg twice daily. Recheck in 2 months.'),

  (26, 8, 'Stress and anxiety management',
   'Doctor: Hello Asha. What kind of stress are you experiencing? Patient: Work deadlines, home responsibilities. Feel overwhelmed all the time. Heart races, cannot concentrate. Doctor: GAD-7 score of 14 indicates moderate anxiety. No depression features. Physical examination normal. Ruling out thyroid and cardiac causes first. Patient: I do not want medication if possible. Doctor: We can try therapy first.',
   'Generalised anxiety disorder — moderate severity. Non-pharmacological management preferred by patient.',
   'HR: 94 bpm. BP: 118/76 mmHg. Thyroid: normal. ECG: sinus tachycardia. GAD-7: 14. No vegetative depressive symptoms.',
   'Referral to CBT therapist. Breathing exercises and mindfulness app prescribed. Follow up in 4 weeks. Medication if no improvement.'),

  (19, 8, 'Seasonal allergies and runny nose',
   'Doctor: Sanjay, hay fever? Patient: Every year at this time. Running nose, sneezing, itchy eyes. Doctor: Classic allergic rhinitis. Let me look inside the nose — pale boggy mucosa, clear discharge. Eyes: mild conjunctival injection. Patient: Can I take something stronger this year? Doctor: Nasal steroid spray is better long-term than antihistamines alone.',
   'Seasonal allergic rhinitis with allergic conjunctivitis — pollen trigger.',
   'Nasal: pale, oedematous mucosa, watery discharge. Eyes: mild conjunctival injection. No polyps. Ears clear.',
   'Fluticasone nasal spray twice daily. Loratadine 10mg once daily. Lubricating eye drops. Sunglasses outdoors during pollen season.'),

  (15, 9, 'Chronic sinusitis and nasal congestion',
   'Doctor: Ajay, how long have you had blocked nose? Patient: Almost 2 years. Both sides. Headache daily above eyes. Sometimes yellow discharge. Doctor: Nasal endoscopy shows marked bilateral inferior turbinate hypertrophy and thick discharge from middle meatus. CT sinuses needed. Patient: I had no idea it was this bad. Doctor: Chronic sinusitis needs proper investigation.',
   'Chronic rhinosinusitis with bilateral turbinate hypertrophy — CT sinuses recommended.',
   'Nasal endoscopy: bilateral inferior turbinate hypertrophy 3+, mucopurulent discharge middle meatus, deviated septum mild right. Anosmia partial.',
   'CT paranasal sinuses. Saline nasal rinse twice daily. Mometasone nasal spray. Consider FESS if no improvement in 3 months.'),

  (23, 9, 'Hearing loss in right ear and tinnitus',
   'Doctor: Hello Vinod. How long has the hearing been reduced? Patient: About 4 months. Also constant ringing in right ear. Doctor: Audiometry shows moderate sensorineural hearing loss right ear, 55 dB. Left ear normal. Tinnitus is likely from the same cause. Have you had loud noise exposure? Patient: I work near machinery. Doctor: Likely noise-induced.',
   'Moderate right sensorineural hearing loss with tinnitus — occupational noise-induced etiology likely.',
   'Weber: lateralises to right. Rinne: negative right (BC>AC). Audiometry: SNHL right 55 dB, left normal. TM bilateral: normal.',
   'Hearing protection at workplace — mandatory. Avoid further noise exposure. MRI internal auditory canal to exclude acoustic neuroma. ENT follow-up in 4 weeks.'),

  (28, 9, 'Tonsillitis and difficulty swallowing',
   'Doctor: Hello Jyoti. How long has it been difficult to swallow? Patient: Since 4 days. Both sides of throat swollen and very painful. Fever 101. Doctor: Significant bilateral tonsillar enlargement with exudate — Grade 3 tonsils. Positive Centor criteria: 4 out of 4. Starting antibiotics. This is recurrent — you mentioned 4 episodes this year? Patient: Yes, every few months. Doctor: Consider tonsillectomy.',
   'Recurrent acute tonsillitis — grade 3 tonsils with exudate. Centor score 4/4. Tonsillectomy referral advised.',
   'Temp: 101.3°F. Bilateral tonsillar enlargement grade 3, purulent exudate. Cervical lymphadenopathy bilateral. No peritonsillar abscess.',
   'Amoxicillin 500mg three times daily for 10 days. Ibuprofen for pain. Tonsillectomy referral to ENT surgeon — criteria met with 4+ episodes per year.'),

  (10, 10, 'Persistent migraines and visual aura',
   'Doctor: Pooja, describe these migraines for me. Patient: One-sided throbbing headache, starts with flashing lights in left visual field, lasts 4-6 hours, makes me vomit. Happens twice a week. Doctor: Classic migraine with visual aura. Neurological examination normal. No red flag features. Patient: I take painkillers but they are not working. Doctor: Analgesic overuse can worsen migraines — starting preventive therapy.',
   'Migraine with visual aura — frequent episodic, 2x weekly. Analgesic overuse headache component likely.',
   'Neurological exam: normal cranial nerves, normal fundoscopy, no focal deficits. MIDAS score: 21 (severe disability).',
   'Stop daily analgesics. Start Topiramate 25mg at night (preventive). Sumatriptan 50mg for acute attacks. Migraine diary. Follow up in 6 weeks.'),

  (18, 10, 'Numbness in both hands and neck pain',
   'Doctor: Lalita, which fingers are numb? Patient: Mainly thumb, index and middle finger. Both hands. Worse in morning. Drops things. Doctor: Carpal tunnel syndrome pattern. Let me also assess neck — cervical spine has reduced rotation. Dual pathology possible. Nerve conduction study will differentiate. Patient: Both wrists hurting too. Doctor: Likely CTS plus cervical spondylosis.',
   'Bilateral carpal tunnel syndrome with likely concurrent cervical spondylosis — nerve conduction study and MRI cervical spine requested.',
   'Tinel sign: positive bilaterally. Phalen test: positive bilaterally. Grip strength reduced. Cervical rotation: restricted 40 degrees.',
   'Wrist splints at night bilaterally. Nerve conduction study both upper limbs. MRI cervical spine. Vitamin B12 and D levels. Physiotherapy.'),

  (29, 10, 'Memory lapses and concentration issues',
   'Doctor: Mr. Bharat, what kind of forgetfulness? Patient: Forget names, lose things, miss appointments. My son is worried. 67 years old. Doctor: MMSE score 24 out of 30 — mild cognitive impairment range. Let us rule out reversible causes first — vitamin B12, thyroid, depression. Patient: Could it be early Alzheimer? Doctor: Possible but treatable causes first.',
   'Mild cognitive impairment — MMSE 24/30. Rule out reversible causes before neurodegenerative diagnosis.',
   'MMSE: 24/30 (deficits in delayed recall and orientation). Mood: mildly anxious. B12: 180 pg/ml (low normal). Thyroid: normal.',
   'Start Methylcobalamin 1500mcg daily. Recheck MMSE in 3 months. MRI brain. Cognitive exercises daily. Family support counselling.'),

  (27, 11, 'Wrist fracture recovery and rehab',
   'Doctor: Naresh, the cast was removed last week. How does the wrist feel? Patient: Still stiff. Cannot turn it fully. Doctor: X-ray shows fracture healed well — good alignment. Stiffness expected after 6 weeks in cast. Time for intensive physiotherapy. Patient: Will I get full movement back? Doctor: 90% likely with proper physiotherapy. Some residual stiffness possible.',
   'Distal radius fracture — healed well, post-immobilisation stiffness. Physiotherapy for rehabilitation.',
   'Right wrist: flexion 40 degrees (normal 80), extension 30 degrees (normal 70), pronation-supination 60% of normal. X-ray: fracture healed.',
   'Physiotherapy 3x weekly for 6 weeks: range of motion and strengthening. Wax bath at home. Review in 6 weeks with repeat ROM assessment.'),

  (30, 11, 'Knee replacement post-op review',
   'Doctor: Good morning Kamla. 6 weeks post total knee replacement — how are you walking? Patient: Walking with stick now. No crutches. Knee still swollen but much less pain. Doctor: Excellent progress. Wound healed. X-ray shows prosthesis well-positioned. Flexion now 90 degrees — that is on target. Patient: When can I walk without stick? Doctor: Another 4-6 weeks at this rate.',
   'Post right total knee replacement — 6-week review. Good functional recovery, prosthesis well-positioned.',
   'Right knee: wound healed, mild effusion. ROM: 0-90 degrees flexion. X-ray: prosthesis in good alignment. No signs of infection.',
   'Continue physiotherapy twice weekly. Progress to walking without stick over next month. DVT prophylaxis to complete 6 weeks. Review at 3 months.'),

  (3,  12, 'HbA1c high — comprehensive diabetes review',
   'Doctor: Vijay, your HbA1c of 9.8 is very high. Tell me about your diet. Patient: I know, doctor. Too many sweets. Rice at every meal. Doctor: With hypertension and diabetes both, we need strict control. I am completely redesigning your diabetes management today. Patient: Please guide me. Doctor: Insulin is likely needed now.',
   'Poorly controlled Type 2 Diabetes — HbA1c 9.8%. Adding basal insulin therapy.',
   'FBS: 210 mg/dl. HbA1c: 9.8%. BP: 144/90 mmHg. BMI: 29. No retinopathy on fundoscopy. Microalbuminuria positive.',
   'Start Insulin Glargine 10 units at bedtime. Continue oral agents. HbA1c target below 7. Diabetic diet chart given. Foot care advice. Review in 6 weeks.'),

  (7,  12, 'Diabetes diet and insulin dosage review',
   'Doctor: Suresh, your fasting sugar is now 140 — improvement from 210. HbA1c down to 8.1. Good progress. Patient: I have been following the diet chart strictly. Reduced rice, walking 30 minutes daily. Doctor: Excellent discipline. Let us fine-tune the insulin dose. Patient: Can I reduce dose if sugar keeps improving? Doctor: Yes, that is the goal eventually.',
   'Type 2 DM — improved glycaemic control. HbA1c reduced from 9.2 to 8.1%. Insulin dose adjusted.',
   'FBS: 138 mg/dl. HbA1c: 8.1%. Wt: 74kg (lost 3kg). BP: 128/82 mmHg. No hypoglycaemia episodes.',
   'Reduce insulin Glargine to 8 units. Continue oral agents. Target HbA1c below 7. Increase walking to 45 minutes daily. Review in 2 months.'),

  (11, 12, 'Diabetic neuropathy — foot care review',
   'Doctor: Ravi, show me your feet. Any wounds or blisters? Patient: No wounds but this toe looks darker. Doctor: That discolouration needs attention — early ischaemic change. Ankle-brachial index is 0.7 — peripheral arterial disease. Urgent vascular surgery referral. Patient: Is my foot at risk? Doctor: Risk is there but we caught it early.',
   'Diabetic peripheral arterial disease with early ischaemic changes — vascular surgery referral urgent.',
   'ABI right: 0.7 (peripheral arterial disease). Left toe: dusky discolouration, capillary refill 4 seconds. Dorsalis pedis pulse: diminished.',
   'Urgent vascular surgery referral. Stop smoking — critical. Cilostazol 100mg twice daily. Podiatry daily foot care. HbA1c strict control below 7.'),

  (17, 12, 'Metformin side effects and dose adjustment',
   'Doctor: Prakash, you called about stomach problems with Metformin? Patient: Yes, very bad gas and loose stools since starting. Doctor: Common with standard Metformin. Switching you to extended release formulation — same medicine but much fewer GI side effects. Patient: I was considering stopping. Doctor: Please do not — very important for your diabetes.',
   'Metformin GI intolerance — switching to extended-release formulation.',
   'Weight stable. FBS: 148 mg/dl. Abdomen: no tenderness. Bowel sounds normal. No electrolyte imbalance.',
   'Change Metformin to XR formulation 500mg twice daily with food. Review in 4 weeks for tolerability. Monitor FBS weekly at home.'),

  (21, 12, 'Pre-diabetes lifestyle consultation',
   'Doctor: Dilip, your fasting glucose of 108 is in pre-diabetes range. Patient: Does this mean I will get diabetes? Doctor: Not necessarily — lifestyle changes can reverse pre-diabetes. You have a 5-year window to act. Patient: Tell me what to do. Doctor: Reduce refined carbs, 150 minutes of exercise per week, target 5kg weight loss. Patient: I will try.',
   'Impaired fasting glucose (pre-diabetes) — intensive lifestyle intervention initiated.',
   'FBS: 108 mg/dl. HbA1c: 6.1%. Wt: 82kg. BMI: 28. BP: 126/80 mmHg. Family history of T2DM positive.',
   'Lifestyle modification: diet and exercise program. Target: 5kg weight loss in 3 months. Recheck HbA1c in 6 months. Metformin if no improvement.'),

  (1,  9, 'Ear blockage and hearing difficulty',
   'Doctor: Rahul, which ear is blocked? Patient: Right ear. Feels full. Hear my own voice loudly. Doctor: Right external canal is completely impacted with cerumen. No tympanic membrane visible. I will do syringing today. Patient: Will it hurt? Doctor: A little uncomfortable but quick. Done — canal clear now. TM normal.',
   'Right cerumen impaction — resolved with ear syringing.',
   'Right ear: complete cerumen impaction, TM not visible pre-procedure. Post-syringing: canal clear, TM pearly grey, cone of light intact.',
   'Olive oil ear drops for 3 days if wax returns. Do not use cotton buds. Return if blockage recurs.'),

  (3,  5, 'Knee pain worsening with diabetes',
   'Doctor: Vijay, how is the knee? Patient: Much worse last month. Cannot climb stairs at all now. Doctor: Diabetics with high sugar have faster cartilage breakdown. Your blood sugar control also affects joint healing. X-ray shows moderate OA both knees. Left worse. Patient: Should I do surgery? Doctor: Physiotherapy and better sugar control first.',
   'Bilateral knee osteoarthritis worsening — exacerbated by poorly controlled diabetes.',
   'Bilateral knee crepitus. Left: effusion+. Right: mild effusion. X-ray: bilateral moderate OA, left > right. HbA1c: 8.6%.',
   'Physiotherapy 3x weekly. Glucosamine sulphate 1500mg once daily. Diclofenac gel. Most importantly — improve HbA1c. Intra-articular injection if no response in 6 weeks.'),

  (11, 2, 'Cardiac risk review — multiple conditions',
   'Doctor: Ravi, with diabetes, hypertension, and asthma — I want a full cardiac risk evaluation. Patient: Yes, I want that too. Doctor: Echo: EF 48% — mildly reduced. Anterior wall hypokinesia. This is new. Stress test positive at low workload. You may have had a silent MI. Patient: Silent heart attack? Doctor: Possible in diabetics who do not feel chest pain.',
   'Possible silent myocardial infarction in diabetic patient — wall motion abnormality on echo, positive stress test.',
   'Echo: EF 48%, anterior hypokinesia, diastolic dysfunction grade 2. Stress ECG: ST depression at 5 METs. Troponin: borderline elevated.',
   'Urgent coronary angiography. Start Clopidogrel + Aspirin. Statin therapy intensification. Strict diabetic and BP control. Hospital referral same day.'),

  (25, 12, 'HbA1c and BP review — dual condition',
   'Doctor: Mukesh, managing both blood pressure and diabetes is challenging. How are home readings? Patient: BP around 138 to 145. Sugar fasting about 155. Doctor: Both need improvement. With both conditions, target BP below 130 and HbA1c below 7. Patient: I am trying but it is hard with my work schedule. Doctor: Let us simplify.',
   'Suboptimal control of both Type 2 DM and hypertension — treatment optimization.',
   'BP: 142/88 mmHg. FBS: 158 mg/dl. HbA1c: 8.0%. Urine microalbumin: 82 mg/g (mildly elevated). eGFR: 68 ml/min.',
   'Intensify BP medication — add Ramipril 5mg for renoprotection. Increase Glimepiride dose. Diabetologist referral. Low-salt, low-carb diet. Monthly monitoring.')

) AS d(patient_id, doctor_id, reason_kw, transcript, diagnosis, clinical_notes, follow_up)
ON a.patient_id = d.patient_id
   AND a.doctor_id = d.doctor_id
   AND a.reason = d.reason_kw
   AND a.status = 'completed'
WHERE NOT EXISTS (
    SELECT 1 FROM session_summaries ss WHERE ss.appointment_id = a.appointment_id
);

-- Session summaries for periodic completed sessions
INSERT INTO session_summaries (appointment_id, full_transcript, diagnosis, clinical_notes, follow_up)
SELECT a.appointment_id,
       d.transcript, d.diagnosis, d.clinical_notes, d.follow_up
FROM appointments a
JOIN (VALUES
  (13, 5, 'Knee physiotherapy session 1 of 4',
   'Physiotherapist: Mr. Harish, how is the pain today? Patient: 6 out of 10. Better than last week. Physiotherapist: Good. ROM now 95 degrees. Doing quadriceps strengthening exercises now. Patient: These exercises help a lot. Physiotherapist: Continue home exercises twice daily.',
   'Knee osteoarthritis physiotherapy session 1 — ROM improving, pain reducing.',
   'ROM right knee: 95 degrees (up from 80). Quadriceps strength 3+/5. Effusion trace.', 
   'Continue home exercises. Straight leg raises 3 sets of 20 daily. Ice pack after exercise.'),
  (13, 5, 'Knee physiotherapy session 2 of 4',
   'Physiotherapist: Very good progress Harish. ROM is now 110 degrees. Patient: Yes, I can climb 5 stairs now. Physiotherapist: Excellent. Adding resistance band exercises today. Patient: Will I avoid surgery? Physiotherapist: At this rate, yes.',
   'Knee physiotherapy session 2 — significant ROM improvement to 110 degrees.',
   'ROM right knee: 110 degrees. Effusion resolved. Quadriceps 4/5. Stairs 5 steps managed.',
   'Add resistance band knee extensions. Cycling 15 minutes daily. Review with doctor after session 4.'),
  (29, 11, 'Hip physiotherapy session 1 of 4',
   'Physiotherapist: Mr. Bharat, first physio session. How is the hip pain today? Patient: 7 out of 10 standing. Better lying down. Physiotherapist: Expected pre-surgery. We will do gentle mobility and strengthening. Patient: I want to be strong before the operation.',
   'Pre-operative hip physiotherapy session 1 — mobility and strengthening exercises initiated.',
   'Hip flexion: 70 degrees. Abduction: 20 degrees. Trendelenburg positive. Pain on weight-bearing.',
   'Hip flexor stretches daily. Gluteal strengthening in lying position. Walking with frame daily 10 minutes.'),
  (29, 11, 'Hip physiotherapy session 2 of 4',
   'Physiotherapist: Better this week Bharat? Patient: Yes, I can walk to bathroom without help now. Physiotherapist: Hip flexion improved to 80 degrees. Adding standing balance exercises. Patient: Operation is next month — will this help recovery? Physiotherapist: Definitely.',
   'Pre-operative hip physio session 2 — improved mobility, balance training commenced.',
   'Hip flexion: 80 degrees. Balance single leg 5 seconds. Walking 15 minutes per day.',
   'Continue gluteal and quad strengthening. Progress walking to 20 minutes. Repeat X-ray pre-op.'),
  (3, 12, 'Weekly blood sugar monitoring session 1 of 4',
   'Doctor: Vijay, fasting sugar today? Patient: 168 at home this morning. Doctor: Better than 210 last month. Insulin is working. Any hypoglycaemia episodes? Patient: One episode last week — felt dizzy at 7pm. Doctor: That is the insulin peaking — shift injection to 10pm.',
   'Type 2 DM insulin therapy monitoring — FBS improving, timing adjustment for hypoglycaemia prevention.',
   'FBS: 168 mg/dl (home 168). No hypoglycaemia in past week except one episode. Injection site: normal rotation.',
   'Shift Glargine injection to 10pm. Reduce dose to 8 units. Recheck FBS next week.'),
  (3, 12, 'Weekly blood sugar monitoring session 2 of 4',
   'Doctor: Vijay, how has the sugar been this week? Patient: Much more stable. Fasting 135-145 range. No more dizziness episodes. Doctor: Excellent. That timing adjustment worked. Post-meal sugar? Patient: Around 200 after rice. Doctor: Rice is the culprit. Let us add a meal-time insulin for dinner.',
   'Type 2 DM — improved fasting control. Post-prandial hyperglycaemia identified. Prandial insulin added.',
   'FBS: 138 mg/dl. Post-meal (self-reported): 198-210 mg/dl. No hypoglycaemia this week. Weight stable.',
   'Add Insulin Regular 4 units before dinner. Monitor dinner post-meal. Reduce rice portion. Review next week.'),
  (11, 12, 'Diabetic neuropathy monitoring session 1 of 4',
   'Doctor: Ravi, any new foot symptoms? Patient: The burning at night is still there. Both feet. Doctor: Checking vibration sense — reduced at big toe bilaterally. Monofilament test: cannot feel 4 points on right sole. This is early stage but needs aggressive sugar control. Patient: I am scared of losing my foot. Doctor: That is why we are monitoring weekly.',
   'Diabetic peripheral neuropathy weekly monitoring session 1 — reduced sensation on monofilament testing.',
   'Vibration: absent at toes bilaterally. Monofilament: 4/10 points not felt right foot, 2/10 left. ABI: 0.9. Foot: intact skin.',
   'Continue Pregabalin 75mg at night. HbA1c below 7 is critical. Daily foot inspection. Avoid barefoot walking. Podiatry referral.'),
  (11, 12, 'Diabetic neuropathy monitoring session 2 of 4',
   'Doctor: Ravi, foot inspection first. Any blisters or cuts? Patient: None. I check every day now. Doctor: Good habit. Monofilament test — slight improvement, 7 out of 10 points felt right foot now. Pregabalin helping the burning? Patient: Yes, 50% better. Doctor: Let us increase Pregabalin dose.',
   'Diabetic neuropathy monitoring session 2 — mild improvement in sensation after glycaemic control and Pregabalin.',
   'Monofilament: 7/10 right, 3/10 left (improvement from session 1). FBS: 142 mg/dl. HbA1c: 7.8% (improving).',
   'Increase Pregabalin to 150mg at night. Continue foot care. HbA1c target below 7. Vascular Doppler in 1 month.')
) AS d(patient_id, doctor_id, reason_kw, transcript, diagnosis, clinical_notes, follow_up)
ON a.patient_id = d.patient_id
   AND a.doctor_id = d.doctor_id
   AND a.reason = d.reason_kw
   AND a.status = 'completed'
WHERE NOT EXISTS (
    SELECT 1 FROM session_summaries ss WHERE ss.appointment_id = a.appointment_id
);

-- ============================================================
-- MEDICATIONS
-- ============================================================
INSERT INTO medications (appointment_id, patient_id, medicine_name, dosage, frequency, duration_days, is_ongoing)
SELECT a.appointment_id, a.patient_id, m.medicine_name, m.dosage, m.frequency, m.duration_days, m.is_ongoing
FROM appointments a
JOIN (VALUES
  (1,  1, 'Amlodipine',              '5mg',   'Once daily morning',         90,  TRUE),
  (1,  1, 'Hydrochlorothiazide',     '12.5mg','Once daily morning',         30,  FALSE),
  (1,  1, 'Aspirin',                 '75mg',  'Once daily after food',      90,  TRUE),
  (2,  1, 'Amlodipine',              '10mg',  'Once daily morning',         90,  TRUE),
  (2,  1, 'Indapamide',              '1.25mg','Once daily morning',         90,  TRUE),
  (4,  2, 'Paracetamol',             '500mg', 'Three times daily if fever', 5,   FALSE),
  (4,  2, 'Betadine Gargle',         'Diluted','Twice daily gargle',        7,   FALSE),
  (5,  2, 'Betamethasone Cream',     '0.05%', 'Twice daily on rash',       7,   FALSE),
  (5,  2, 'Cetirizine',              '10mg',  'Once daily at night',        5,   FALSE),
  (6,  3, 'Metformin',               '500mg', 'Twice daily with food',      90,  TRUE),
  (6,  3, 'Glimepiride',             '1mg',   'Once daily with breakfast',  90,  TRUE),
  (6,  3, 'Aspirin',                 '75mg',  'Once daily after food',      90,  TRUE),
  (7,  3, 'Amlodipine',              '5mg',   'Once daily morning',         90,  TRUE),
  (7,  3, 'Metformin',               '500mg', 'Twice daily with food',      90,  TRUE),
  (8,  3, 'Pregabalin',              '75mg',  'Once daily at night',        90,  TRUE),
  (8,  3, 'Metformin',               '500mg', 'Twice daily with food',      90,  TRUE),
  (9,  1, 'Atenolol',                '25mg',  'Once daily morning',         30,  TRUE),
  (9,  1, 'Sorbitrate',              '5mg',   'Sublingual as needed',       30,  FALSE),
  (10, 3, 'Ramipril',                '5mg',   'Once daily morning',         90,  TRUE),
  (10, 3, 'Amlodipine',              '5mg',   'Once daily morning',         90,  TRUE),
  (11, 5, 'Furosemide',              '40mg',  'Once daily morning',         30,  TRUE),
  (11, 5, 'Sacubitril-Valsartan',    '50mg',  'Twice daily',               90,  TRUE),
  (11, 5, 'Spironolactone',          '25mg',  'Once daily',                 90,  TRUE),
  (12, 17,'Apixaban',                '5mg',   'Twice daily',                90,  TRUE),
  (12, 17,'Bisoprolol',              '2.5mg', 'Once daily morning',         90,  TRUE),
  (13, 25,'Clopidogrel',             '75mg',  'Once daily after food',      365, TRUE),
  (13, 25,'Aspirin',                 '75mg',  'Once daily after food',      365, TRUE),
  (13, 25,'Atorvastatin',            '40mg',  'Once daily at night',        365, TRUE),
  (14, 4, 'Levothyroxine',           '50mcg', 'Once daily empty stomach',   90,  TRUE),
  (14, 4, 'Calcium + Vitamin D3',    '500mg', 'Once daily after food',      90,  TRUE),
  (15, 6, 'Amoxicillin-Clavulanate', '625mg', 'Twice daily with food',      5,   FALSE),
  (15, 6, 'Paracetamol',             '500mg', 'Three times daily if fever', 5,   FALSE),
  (16, 8, 'Escitalopram',            '5mg',   'Once daily morning',         30,  TRUE),
  (16, 8, 'Clonazepam',              '0.25mg','Once daily at night',        14,  FALSE),
  (17, 9, 'Pantoprazole',            '40mg',  'Once daily before breakfast', 30, FALSE),
  (17, 9, 'Domperidone',             '10mg',  'Twice daily before food',    14,  FALSE),
  (18, 14,'Paracetamol',             '500mg', 'Three times daily if needed', 5,  FALSE),
  (18, 14,'ORS Sachets',             '1 sachet','After each loose stool',   5,   FALSE),
  (19, 2, 'Adapalene Gel',           '0.1%',  'Once daily at night on acne', 60, FALSE),
  (19, 2, 'Clindamycin Lotion',      '1%',    'Twice daily on acne',        60,  FALSE),
  (20, 12,'Hydrocortisone Cream',    '1%',    'Twice daily on affected area', 10, FALSE),
  (21, 24,'Clotrimazole Cream',      '1%',    'Twice daily',                21,  FALSE),
  (21, 24,'Antifungal Powder',       'Topical','Once daily after shower',   21,  FALSE),
  (22, 13,'Diclofenac Sodium',       '50mg',  'Twice daily with food',      10,  FALSE),
  (22, 13,'Calcium Carbonate',       '500mg', 'Once daily after food',      90,  TRUE),
  (22, 13,'Vitamin D3',              '1000 IU','Once daily',                90,  TRUE),
  (23, 20,'Ibuprofen',               '400mg', 'Twice daily with food',      5,   FALSE),
  (23, 20,'Methocarbamol',           '750mg', 'Twice daily',                7,   FALSE),
  (24, 29,'Diclofenac Gel',          'Topical','Twice daily on hip',        30,  FALSE),
  (24, 29,'Tramadol',                '50mg',  'Twice daily as needed for pain', 10, FALSE),
  (25, 15,'Ibuprofen',               '400mg', 'Twice daily with food',      7,   FALSE),
  (26, 6, 'Amoxicillin',             '40mg/kg/day','Divided 3 times daily for 7 days', 7, FALSE),
  (26, 6, 'Paracetamol Syrup',       '15mg/kg','Every 6 hours if fever',   5,   FALSE),
  (27, 16,'Paracetamol',             '500mg', 'If fever after vaccine',     3,   FALSE),
  (28, 7, 'Rosuvastatin',            '20mg',  'Once daily at night',        90,  TRUE),
  (28, 7, 'Aspirin',                 '75mg',  'Once daily after food',      90,  TRUE),
  (28, 7, 'Ramipril',                '5mg',   'Once daily morning',         90,  TRUE),
  (29, 11,'Bisoprolol',              '2.5mg', 'Once daily morning',         90,  TRUE),
  (29, 11,'Telmisartan',             '40mg',  'Once daily morning',         90,  TRUE),
  (30, 21,'Labetalol',               '100mg', 'Twice daily',                30,  TRUE),
  (31, 22,'Ferrous Sulphate',        '150mg', 'Twice daily with food',      60,  FALSE),
  (31, 22,'Vitamin D3',              '60000 IU','Once weekly for 8 weeks',  56,  FALSE),
  (32, 26,'Fluticasone Nasal Spray', '2 puffs each nostril','Twice daily',  30,  FALSE),
  (33, 19,'Loratadine',              '10mg',  'Once daily',                 14,  FALSE),
  (34, 15,'Mometasone Nasal Spray',  '2 puffs','Once daily',               30,  FALSE),
  (35, 23,'Tab B12 supplement',       '1500mcg','Once daily',              90,  FALSE),
  (36, 28,'Amoxicillin',             '500mg', 'Three times daily',         10,  FALSE),
  (36, 28,'Ibuprofen',               '400mg', 'Three times daily with food', 7, FALSE),
  (37, 10,'Topiramate',              '25mg',  'Once daily at night',        90,  FALSE),
  (37, 10,'Sumatriptan',             '50mg',  'At migraine onset',          30,  FALSE),
  (38, 18,'Methylcobalamin',         '1500mcg','Once daily',               90,  FALSE),
  (39, 29,'Methylcobalamin',         '1500mcg','Once daily',               90,  FALSE),
  (40, 27,'Calcium Carbonate',       '500mg', 'Once daily after food',      60,  FALSE),
  (41, 30,'Paracetamol',             '500mg', 'Twice daily if pain',        10,  FALSE),
  (42, 3, 'Insulin Glargine',        '10 units','Once daily at bedtime',    90,  TRUE),
  (42, 3, 'Metformin',               '500mg', 'Twice daily with food',      90,  TRUE),
  (42, 3, 'Amlodipine',              '5mg',   'Once daily morning',         90,  TRUE),
  (43, 7, 'Insulin Glargine',        '8 units','Once daily at 10pm',        30,  TRUE),
  (43, 7, 'Metformin',               '1000mg','Twice daily with food',      90,  TRUE),
  (44, 11,'Clopidogrel',             '75mg',  'Once daily after food',      90,  TRUE),
  (44, 11,'Aspirin',                 '75mg',  'Once daily after food',      90,  TRUE),
  (44, 11,'Atorvastatin',            '80mg',  'Once daily at night',        90,  TRUE),
  (45, 3, 'Pregabalin',              '75mg',  'Once daily at night',        90,  TRUE),
  (45, 3, 'Metformin',               '500mg', 'Twice daily with food',      90,  TRUE),
  (46, 17,'Metformin XR',            '500mg', 'Twice daily with food',      90,  TRUE),
  (47, 21,'Metformin',               '500mg', 'Once daily with dinner',     90,  FALSE),
  (47, 21,'Aspirin',                 '75mg',  'Once daily after food',      90,  TRUE),
  (48, 1, 'Olive Oil Ear Drops',     'Topical','3 drops twice daily',       7,   FALSE),
  (49, 3, 'Diclofenac Gel',         'Topical','Twice daily on knees',       30,  FALSE),
  (49, 3, 'Glucosamine Sulphate',    '1500mg','Once daily with food',       90,  TRUE),
  (50, 11,'Cilostazol',              '100mg', 'Twice daily',                90,  TRUE),
  (50, 11,'Aspirin',                 '75mg',  'Once daily',                 90,  TRUE),
  (51, 17,'Metformin XR',            '500mg', 'Twice daily',                90,  TRUE),
  (51, 17,'Insulin Regular',         '4 units','Before dinner',             30,  TRUE),
  (52, 25,'Ramipril',                '5mg',   'Once daily morning',         90,  TRUE),
  (52, 25,'Glimepiride',             '2mg',   'Once daily with breakfast',  90,  TRUE)
) AS m(appt_seq_num, patient_id, medicine_name, dosage, frequency, duration_days, is_ongoing)
ON a.patient_id = m.patient_id
WHERE a.appointment_id = (
    SELECT a2.appointment_id
    FROM appointments a2
    WHERE a2.patient_id = m.patient_id
      AND a2.status = 'completed'
    ORDER BY a2.scheduled_at
    OFFSET (m.appt_seq_num::int % 8)
    LIMIT 1
)
ON CONFLICT DO NOTHING;

-- ============================================================
-- PAYMENTS (one per completed appointment)
-- ============================================================
INSERT INTO payments (appointment_id, patient_id, amount, method, status, due_amount, paid_at)
SELECT
    a.appointment_id,
    a.patient_id,
    d.consultation_fee::DECIMAL(10,2),
    CASE ((a.appointment_id * 7 + a.patient_id) % 10)
        WHEN 0 THEN 'upi' WHEN 1 THEN 'upi' WHEN 2 THEN 'upi' WHEN 3 THEN 'upi' WHEN 4 THEN 'upi'
        WHEN 5 THEN 'cash' WHEN 6 THEN 'cash' WHEN 7 THEN 'cash'
        ELSE 'card'
    END,
    CASE ((a.appointment_id + a.patient_id * 3) % 20)
        WHEN 0 THEN 'partial'
        WHEN 1 THEN 'pending'
        ELSE 'paid'
    END,
    CASE ((a.appointment_id + a.patient_id * 3) % 20)
        WHEN 0 THEN ROUND(d.consultation_fee * 0.4)
        WHEN 1 THEN d.consultation_fee
        ELSE 0
    END,
    CASE ((a.appointment_id + a.patient_id * 3) % 20)
        WHEN 1 THEN NULL
        ELSE a.scheduled_at + INTERVAL '35 minutes'
    END
FROM appointments a
JOIN doctors d ON a.doctor_id = d.doctor_id
WHERE a.status = 'completed'
  AND NOT EXISTS (SELECT 1 FROM payments p WHERE p.appointment_id = a.appointment_id);

-- Pending payment for today's appointment
INSERT INTO payments (appointment_id, patient_id, amount, method, status, due_amount)
VALUES (3, 1, 500.00, NULL, 'pending', 500.00)
ON CONFLICT DO NOTHING;

-- ============================================================
-- NOTIFICATIONS (15-20 records)
-- ============================================================
INSERT INTO notifications (patient_id, channel, message, status, sent_at)
VALUES
(1, 'telegram', '🏥 ClinicFlow AI — Appointment Reminder\nDear Rahul Mehta, you have an appointment with Dr. Arjun Sharma tomorrow at 10:30 AM.\nReason: Follow-up for hypertension.\nPlease arrive 5 minutes early.', 'sent', NOW() - INTERVAL '1 day' + TIME '08:30'),
(1, 'telegram', '🏥 ClinicFlow AI — Visit Summary\nHi Rahul! Your appointment is complete.\nDiagnosis: Hypertension — well controlled on current regimen.\nMedication: Continue Amlodipine 10mg. Stay healthy!', 'sent', NOW() - INTERVAL '55 days' + TIME '12:00'),
(3, 'telegram', '🏥 ClinicFlow AI — Appointment Reminder\nDear Vijay Kumar, your appointment with Dr. Arjun Sharma is on ' || (NOW() + INTERVAL '1 day')::date::text || ' at 11:00 AM.\nReason: Diabetes check-up.', 'sent', NOW() + INTERVAL '1 day' - INTERVAL '1 hour'),
(3, 'telegram', '🏥 ClinicFlow AI — Visit Summary\nHi Vijay! Appointment complete.\nDiagnosis: Diabetic peripheral neuropathy.\nKey message: Strict sugar control is critical. Foot care daily.', 'sent', NOW() - INTERVAL '22 days' + TIME '11:00'),
(2, 'telegram', '🏥 ClinicFlow AI — Appointment Reminder\nHi Priya Patel! Your appointment with Dr. Sunita Joshi is tomorrow at 10:30 AM.\nReason: Follow-up for acne treatment.', 'sent', NOW() + INTERVAL '2 days' - INTERVAL '1 day'),
(5, 'telegram', '🏥 ClinicFlow AI — URGENT Appointment Reminder\nMr. Deepak Joshi, your post-discharge cardiac follow-up is in 3 days with Dr. Meera Nair.\nThis is a HIGH PRIORITY appointment. Please do not miss it.', 'sent', NOW() + INTERVAL '3 days' - INTERVAL '1 day'),
(1, 'telegram', '🏥 ClinicFlow AI — Visit Summary\nHi Rahul! Chest tightness appointment complete.\nDiagnosis: Hypertensive chest discomfort — referred to cardiologist.\nNext: See Dr. Meera Nair within 3 days.', 'sent', NOW() - INTERVAL '25 days' + TIME '11:00'),
(3, 'telegram', '🏥 ClinicFlow AI — Visit Summary\nHi Vijay! Foot numbness appointment complete.\nDiagnosis: Diabetic peripheral neuropathy.\nStarted Pregabalin 75mg. Monitor feet daily.', 'sent', NOW() - INTERVAL '22 days' + TIME '10:30'),
(11, 'telegram', '🏥 ClinicFlow AI — URGENT: Cardiac Referral\nDear Ravi Sharma, your doctor has referred you for URGENT coronary angiography.\nPlease contact the hospital today. Your health is our priority.', 'sent', NOW() - INTERVAL '21 days' + TIME '12:00'),
(25, 'telegram', '🏥 ClinicFlow AI — Visit Summary\nHi Mukesh! Post-angioplasty review complete.\nExcellent recovery — EF normalised to 55%. Continue all medications. Next review in 3 months.', 'sent', NOW() - INTERVAL '10 days' + TIME '11:30'),
(4,  'email',   'Dear Anita Shah, your thyroid results show TSH of 12.4. Levothyroxine has been prescribed. Please take it daily on empty stomach. Repeat thyroid test in 6 weeks. - ClinicFlow AI', 'sent', NOW() - INTERVAL '75 days' + TIME '10:30'),
(8,  'email',   'Dear Rekha Verma, follow-up reminder: your anxiety management consultation was today. Your psychologist referral is ready. Please book an appointment within 1 week. - ClinicFlow AI', 'sent', NOW() - INTERVAL '28 days' + TIME '15:00'),
(13, 'telegram', '🏥 Physiotherapy Reminder\nMr. Harish Bhatt, your knee physiotherapy session 3 is scheduled. Please continue home exercises daily. See you at the clinic!', 'sent', NOW() + INTERVAL '7 days' - INTERVAL '1 day'),
(17, 'telegram', '🏥 ClinicFlow AI — Visit Summary\nDear Prakash, your Metformin has been changed to extended-release formulation to reduce side effects. Please collect new prescription from clinic.', 'sent', NOW() - INTERVAL '11 days' + TIME '12:00'),
(7,  'telegram', '🏥 ClinicFlow AI — Visit Summary\nHi Suresh! Diabetes review complete.\nHbA1c improved from 9.2 to 8.1% — great progress! Keep following the diet chart. Insulin dose reduced.', 'sent', NOW() - INTERVAL '60 days' + TIME '13:00'),
(29, 'telegram', '🏥 Physiotherapy Reminder\nDear Bharat, hip physiotherapy session 3 coming up. Keep doing your home exercises. Surgery prep is going well!', 'sent', NOW() + INTERVAL '7 days' - INTERVAL '1 day'),
(10, 'email',   'Dear Pooja Desai, migraine management plan: Topiramate 25mg started as prevention. For acute attacks use Sumatriptan 50mg. Please keep a migraine diary. Follow up in 6 weeks. - ClinicFlow AI', 'sent', NOW() - INTERVAL '78 days' + TIME '11:30'),
(21, 'telegram', '🏥 ClinicFlow AI — Pre-diabetes Alert\nDear Dilip, your fasting glucose is 108 — pre-diabetes range. Your lifestyle plan has been created. Start walking 30 minutes daily. Recheck in 6 months.', 'sent', NOW() - INTERVAL '4 days' + TIME '10:30')
ON CONFLICT DO NOTHING;

-- ============================================================
-- GENERATE VECTORS (AlloyDB AI)
-- Run separately if embedding() function is available
-- ============================================================
-- UPDATE patients
-- SET history_vector = embedding('text-embedding-005',
--     name || ' ' || COALESCE(chronic_conditions,'') || ' ' || COALESCE(allergies,'') || ' age ' || age::text
-- )::vector
-- WHERE history_vector IS NULL;
--
-- UPDATE session_summaries
-- SET summary_vector = embedding('text-embedding-005',
--     COALESCE(diagnosis,'') || ' ' || COALESCE(clinical_notes,'') || ' ' || COALESCE(follow_up,'')
-- )::vector
-- WHERE summary_vector IS NULL;