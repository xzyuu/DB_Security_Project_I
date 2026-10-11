-- =====================================================================
-- Sample dummy data — keep it small but rich enough to demonstrate
-- every policy branch (own-patient access, dept access, sensitive
-- category blocking, billing-only access, etc.)
-- =====================================================================

INSERT INTO departments VALUES (1, 'Cardiology');
INSERT INTO departments VALUES (2, 'Psychiatry');
INSERT INTO departments VALUES (3, 'General Medicine');
INSERT INTO departments VALUES (4, 'Billing Office');

-- Staff: mix of roles across departments
INSERT INTO staff VALUES (101, 'dr_tan',    'Dr. Tan Wei Ming',  'DOCTOR',  1, DATE '2015-03-01');
INSERT INTO staff VALUES (102, 'dr_lim',    'Dr. Lim Hui Ying',  'DOCTOR',  2, DATE '2018-06-15');
INSERT INTO staff VALUES (103, 'nurse_ong', 'Ong Bee Choo',      'NURSE',   1, DATE '2020-01-10');
INSERT INTO staff VALUES (104, 'nurse_koh', 'Koh Siew Ling',     'NURSE',   3, DATE '2019-11-20');
INSERT INTO staff VALUES (105, 'admin_ng',  'Ng Kok Wai',        'ADMIN',   3, DATE '2012-05-05');
INSERT INTO staff VALUES (106, 'bill_teo',  'Teo Ai Lin',        'BILLING', 4, DATE '2021-02-01');
INSERT INTO staff VALUES (107, 'lab_goh',   'Goh Meng Hui',      'LABTECH', 3, DATE '2017-08-30');

-- Patients
INSERT INTO patients VALUES (201, 'pat_wong', 'Wong Zi Xuan',  DATE '1985-04-12', 'GENERAL', 101, DATE '2026-08-20');
INSERT INTO patients VALUES (202, 'pat_lee',  'Lee Jun Jie',   DATE '1990-09-23', 'PSYCH',   102, DATE '2026-08-22');
INSERT INTO patients VALUES (203, 'pat_ho',   'Ho Xin Yi',     DATE '1978-01-05', 'GENERAL', 101, DATE '2026-08-25');
INSERT INTO patients VALUES (204, 'pat_sim',  'Sim Wei Jian',  DATE '2002-11-30', 'ICU',     101, DATE '2026-08-27');

-- Care team assignments
INSERT INTO care_team VALUES (201, 101, 'ATTENDING');
INSERT INTO care_team VALUES (201, 103, 'NURSE_ON_DUTY');
INSERT INTO care_team VALUES (202, 102, 'ATTENDING');
INSERT INTO care_team VALUES (203, 101, 'ATTENDING');
INSERT INTO care_team VALUES (203, 104, 'NURSE_ON_DUTY');
INSERT INTO care_team VALUES (204, 101, 'ATTENDING');

-- Appointments
INSERT INTO appointments VALUES (301, 201, 101, DATE '2026-09-05', 'SCHEDULED');
INSERT INTO appointments VALUES (302, 202, 102, DATE '2026-09-06', 'SCHEDULED');
INSERT INTO appointments VALUES (303, 203, 101, DATE '2026-09-07', 'COMPLETED');

-- Lab results (mix of routine and sensitive categories)
INSERT INTO lab_results VALUES (401, 201, 101, 'Lipid Panel',      'ROUTINE',    '180 mg/dL',  DATE '2026-08-21');
INSERT INTO lab_results VALUES (402, 202, 102, 'Toxicology Screen','PSYCH',      'Negative',   DATE '2026-08-23');
INSERT INTO lab_results VALUES (403, 203, 101, 'HIV Antibody',     'INFECTIOUS', 'Negative',   DATE '2026-08-26');
INSERT INTO lab_results VALUES (404, 204, 101, 'Genetic Panel',    'GENETIC',    'Pending',    DATE '2026-08-28');

-- Bills
INSERT INTO bills VALUES (501, 201, 1200.00, 'UNPAID', DATE '2026-08-21');
INSERT INTO bills VALUES (502, 202,  800.00, 'PAID',   DATE '2026-08-23');
INSERT INTO bills VALUES (503, 203, 1500.00, 'UNPAID', DATE '2026-08-26');

-- Clinical notes (general vs sensitive)
INSERT INTO clinical_notes VALUES (601, 201, 101, 'Patient stable, continue current medication.', 'GENERAL', DATE '2026-08-21');
INSERT INTO clinical_notes VALUES (602, 202, 102, 'Patient reports improved mood, adjust dosage.',  'PSYCH',   DATE '2026-08-23');
INSERT INTO clinical_notes VALUES (603, 204, 101, 'History of substance use disclosed by family.',  'SUBSTANCE_ABUSE', DATE '2026-08-28');

COMMIT;
