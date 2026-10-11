SET DEFINE OFF
SET SERVEROUTPUT ON

-- Each case is run in its own session, logged in as the account named in its 'Test data' line.
-- Cases that modify data end with ROLLBACK; nothing is committed.

-- ---------------------------------------------------------------------
-- TC-001 | Patient | SELECT | Positive
-- Precondition: Patient with own profile, appointment and admission records.
-- Steps: SELECT own profile, appointments, admission and ward/room data.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_PATIENT1 (PATIENT_ID=21).
-- ---------------------------------------------------------------------
-- expect: 1 row (PATIENT_ID = 21 only)
select * from proj_one.patient;
-- expect: only rows with PATIENT_ID = 21
select * from proj_one.appointment;
-- expect: only rows with PATIENT_ID = 21 (includes ROOM_ID)
select * from proj_one.admission;

-- ---------------------------------------------------------------------
-- TC-002 | Patient | SELECT | Negative
-- Precondition: Patient A logged in; Patient B has records.
-- Steps: SELECT Patient B's profile, appointments, admission and ward/room data.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_PATIENT1 (PATIENT_ID=21); other patient PATIENT_ID=22.
-- Syntax fix: Original had stray ';' after the FROM line, which splits the WHERE clause into a separate (invalid) statement; removed.
-- ---------------------------------------------------------------------
-- expect: no rows
select * from proj_one.patient
where patient_id = 22;

select * from proj_one.appointment
where patient_id = 22;

select * from proj_one.admission
where patient_id = 22;

-- ---------------------------------------------------------------------
-- TC-003 | Patient | SELECT | Positive
-- Precondition: Patient with own prescription, appointment and medication records.
-- Steps: SELECT own prescriptions, dispensing records and bills.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_PATIENT1 (PATIENT_ID=21): PRESCRIPTION_ID 1, 16, 24; DISPENSE_ID 1, 16; BILL_ID 1, 2.
-- ---------------------------------------------------------------------
-- expect: only PATIENT_ID = 21 rows
select * from proj_one.Prescription;

-- expect: only dispensing of the patient's own prescriptions (rx 1, 16)
select * from proj_one.dispensing;

-- expect: only PATIENT_ID = 21 rows
select * from proj_one.bill;

-- ---------------------------------------------------------------------
-- TC-004 | Patient | SELECT | Negative
-- Precondition: Patient A logged in; Patient B has prescriptions and bills.
-- Steps: SELECT Patient B's prescriptions, dispensing records and bills.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_PATIENT1 (PATIENT_ID=21); other patient PATIENT_ID=22 (PRESCRIPTION_ID 2, 17).
-- Syntax fix: Original 'where patient_id = 22' on DISPENSING raises ORA-00904 (DISPENSING has no PATIENT_ID column); filtered by the patient's prescription IDs instead.
-- ---------------------------------------------------------------------
-- expect: no rows
select * from proj_one.Prescription
where patient_id = 22;

-- expect: no rows
select * from proj_one.dispensing
where prescription_id in (2, 17);

-- expect: no rows
select * from proj_one.bill
where patient_id = 22;

-- ---------------------------------------------------------------------
-- TC-005 | Patient | SELECT | Positive
-- Precondition: Patient with own lab order, a released result and a medical record.
-- Steps: SELECT own lab orders (permitted columns), released results and diagnosis.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_PATIENT1 (PATIENT_ID=21): LAB_ORDER 1, 16; LAB_RESULT 1 (released), 16 (not released).
-- Fix: added the diagnosis query (Steps mention diagnosis, original SQL did not select it).
-- ---------------------------------------------------------------------
-- expect: only PATIENT_ID = 21 orders
select * from proj_one.lab_order;

-- expect: only released results (RELEASED_FLAG = 1)
select * from proj_one.lab_result;

-- expect: own records only
select diagnosis from proj_one.medical_record;

-- ---------------------------------------------------------------------
-- TC-006 | Patient | SELECT | Negative
-- Precondition: Patient A logged in; Patient B has lab and diagnosis records.
-- Steps: SELECT Patient B's lab orders, lab results and diagnosis.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_PATIENT1 (PATIENT_ID=21); other patient PATIENT_ID=22 (LAB_ORDER 2, 17; LAB_RESULT 2, 17).
-- Syntax fix: Original 'lab_result where patient_id = 22' raises ORA-00904 (LAB_RESULT has no PATIENT_ID column); filtered by ORDER_ID instead. Added the diagnosis query.
-- ---------------------------------------------------------------------
-- expect: no rows
select *
from proj_one.Lab_Order
where patient_id = 22;

-- expect: no rows
select * from proj_one.lab_result
where order_id in (2, 17);

-- expect: no rows
select diagnosis from proj_one.medical_record
where patient_id = 22;

-- ---------------------------------------------------------------------
-- TC-007 | Patient | SELECT | Negative
-- Precondition: Patient has a lab result with status NOT released.
-- Steps: SELECT own unreleased lab result.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_PATIENT1 (PATIENT_ID=21); LAB_RESULT.RESULT_ID=16 (ORDER_ID=16, RELEASED_FLAG=0).
-- ---------------------------------------------------------------------
-- expect: no rows
select * from proj_one.lab_result where order_id = 16;

-- ---------------------------------------------------------------------
-- TC-008 | Doctor | SELECT | Positive
-- Precondition: Doctor with an active assignment to Patient X (admitted).
-- Steps: SELECT Patient X's basic info and current admission/room.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_DOCTOR1 (DOCTOR_ID=1); active assignment to PATIENT_ID=21 (ADMISSION_ID=2, ROOM_ID=1).
-- ---------------------------------------------------------------------
-- expect: 1 row
select * from proj_one.patient
where patient_ID = 21;

-- expect: current admission of patient 21
select * from proj_one.admission
where patient_ID = 21;

-- expect: 1 row
select * from proj_one.room where room_id = 1;

-- ---------------------------------------------------------------------
-- TC-009 | Doctor | SELECT | Negative
-- Precondition: Doctor has no active assignment (or assignment ended) for Patient Y.
-- Steps: SELECT Patient Y's basic info and admission.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_DOCTOR2 (DOCTOR_ID=2, not a department head). PATIENT_ID=23: never assigned to doctor 2. PATIENT_ID=21: assignment to doctor 2 is 'Transferred'.
-- Data fix: Original used patient 22, which is assigned to doctor 2, and USER_DOCTOR1 is a department head (extra privilege); switched to non-head USER_DOCTOR2 and patients without an active assignment.
-- ---------------------------------------------------------------------
-- expect: no rows
select * from proj_one.patient
where patient_ID = 23;

select * from proj_one.admission
where patient_ID = 23;

-- assignment 'Transferred' (expect no rows)
select * from proj_one.patient
where patient_ID = 21;

-- ---------------------------------------------------------------------
-- TC-010 | Doctor | SELECT | Positive
-- Precondition: Doctor owns an appointment and a prescription.
-- Steps: SELECT own appointments and own prescriptions.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_DOCTOR1 (DOCTOR_ID=1).
-- ---------------------------------------------------------------------
-- expect: only DOCTOR_ID = 1 rows
select * from proj_one.Prescription;
select * from proj_one.Appointment;

-- ---------------------------------------------------------------------
-- TC-011 | Doctor | SELECT | Negative
-- Precondition: Another doctor owns appointments/prescriptions.
-- Steps: SELECT the other doctor's appointments and prescriptions.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_DOCTOR1 (DOCTOR_ID=1); other doctor DOCTOR_ID=2.
-- ---------------------------------------------------------------------
-- expect: no rows
select * from proj_one.Prescription
where doctor_id = 2;
select * from proj_one.Appointment
where doctor_id = 2;

-- ---------------------------------------------------------------------
-- TC-012 | Doctor | SELECT | Positive
-- Precondition: Assigned patient has a lab order and a released result.
-- Steps: SELECT the lab order and the released result.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_DOCTOR1 (DOCTOR_ID=1); LAB_ORDER 7, 13, 16, 22; released LAB_RESULT 13.
-- ---------------------------------------------------------------------
-- expect: rows for this doctor's orders
select order_id, test_type from proj_one.lab_order;
-- expect: only released results (RELEASED_FLAG = 1)
select result_id, result_value from proj_one.lab_result;

-- ---------------------------------------------------------------------
-- TC-013 | Doctor | SELECT | Negative
-- Precondition: (a) Assigned patient's result is unreleased; (b) unassigned patient has lab data.
-- Steps: SELECT (a) the unreleased result and (b) the unassigned patient's lab orders/results.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Source test data (descriptive, not SQL): USER_DOCTOR1 (DOCTOR_ID=1). Assigned PATIENT_ID=27: unreleased LAB_RESULT.RESULT_ID=7 (ORDER_ID=7, RELEASED_FLAG=0). Unassigned PATIENT_ID=22: LAB_ORDER.ORDER_ID=2 and LAB_RESULT.RESULT_ID=2.
-- Queries below were DERIVED from those IDs.
-- Syntax fix: Original 'lab_result where patient_id = 22' raises ORA-00904 (LAB_RESULT has no PATIENT_ID column); filtered by RESULT_ID only.
-- ---------------------------------------------------------------------
-- (a) Assigned patient, unreleased result (expect no rows)
select * from proj_one.lab_result where result_id = 7;
-- (b) Unassigned patient's lab data (expect no rows)
select * from proj_one.lab_order where patient_id = 22 and order_id = 2;
select * from proj_one.lab_result where result_id = 2;

-- ---------------------------------------------------------------------
-- TC-014 | Doctor | INSERT | Positive
-- Precondition: Active assignment to Patient X; appointment belongs to this doctor and Patient X.
-- Steps: INSERT a medical record, a lab order, and a prescription referencing that appointment.
-- Expected: Access is GRANTED; all three rows are inserted.
-- Test data: USER_DOCTOR1 (DOCTOR_ID=1); PATIENT_ID=21; APPOINTMENT_ID=16 (doctor 1, patient 21).
-- Data fix: Original prescription row was (16, 26, 6) - another patient and doctor; corrected to (16, 21, 1) to match the precondition.
-- ---------------------------------------------------------------------
-- expect: 1 row created (x3)
insert into proj_one.medical_record (patient_id,author_doctor_id,visit_date)
values (21,1,to_date('2026-10-10','YYYY-MM-DD'));

insert into proj_one.lab_order (patient_id, doctor_id,department_id,test_type)
values (21,1,24,'3rd sputum culture');

insert into proj_one.prescription (appointment_id, patient_id, doctor_id, medication)
values (16, 21, 1,'Anarex 250mg capsules');

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-015 | Doctor | INSERT | Negative
-- Precondition: Doctor has no active assignment for Patient Y.
-- Steps: INSERT a medical record and a lab order for Patient Y.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_DOCTOR6 (DOCTOR_ID=6) has no active assignment to PATIENT_ID=21 (assigned to doctor 1).
-- ---------------------------------------------------------------------
-- expect: ORA-28115 (policy with check option violation)
insert into proj_one.medical_record (patient_id,author_doctor_id,visit_date)
values (21,6,to_date('2026-10-10','YYYY-MM-DD'));

-- expect: ORA-28115
insert into proj_one.lab_order (patient_id, doctor_id,department_id,test_type)
values (21,6,24,'3rd sputum culture');

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-016 | Doctor | INSERT | Negative
-- Precondition: Appointment belongs to another doctor, or to a different patient.
-- Steps: INSERT a prescription referencing that appointment.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_DOCTOR6 (DOCTOR_ID=6). APPOINTMENT_ID=16 belongs to doctor 1 / patient 21. APPOINTMENT_ID=21 belongs to doctor 6 / patient 26.
-- Fix: added the 'appointment of another doctor' probe (16); the original statement (21) covers 'different patient'.
-- ---------------------------------------------------------------------
-- (a) appointment of another doctor (expect ORA-28115)
insert into proj_one.prescription (appointment_id, patient_id, doctor_id, medication)
values (16, 21, 6,'Anarex 250mg capsules');

-- (b) own appointment, different patient (expect ORA-28115)
insert into proj_one.prescription (appointment_id, patient_id, doctor_id, medication)
values (21, 21, 6,'Anarex 250mg capsules');

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-017 | Doctor | UPDATE | Positive
-- Precondition: Own prescription with status Pending.
-- Steps: UPDATE medication, dosage and status.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_DOCTOR1 (DOCTOR_ID=1); PRESCRIPTION_ID=24 (Pending, patient 21).
-- Data fix: Original used PRESCRIPTION_ID=245, which does not exist (0 rows); changed to 24.
-- ---------------------------------------------------------------------
-- expect: 1 row updated
update proj_one.prescription
set medication = 'Anarex 250 mg tablets',
 dosage = 'Take 2-4 tablets orally every 8 hours as needed for 3 days, maximum 12 tablets in 24 hours.'
where prescription_id = 24;

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-018 | Doctor | UPDATE | Negative
-- Precondition: Own prescription that is Dispensed or Cancelled; another doctor's Pending prescription.
-- Steps: UPDATE medication/dosage/status on each.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_DOCTOR1 (DOCTOR_ID=1). PRESCRIPTION_ID=16: own, Dispensed. PRESCRIPTION_ID=23: doctor 2's, Pending.
-- Syntax fix: Original: 'where prescription_id = 242, doctor_id = 6;' is invalid SQL; changed ',' to 'and'.
-- Data fix: PRESCRIPTION_ID=242 does not exist (the statement could never match); replaced with doctor 2's Pending prescription 23.
-- ---------------------------------------------------------------------
-- (a) own, Dispensed (expect 0 rows updated)
update proj_one.prescription
set status = 'Pending'
where prescription_id = 16;

-- (b) another doctor's Pending prescription (expect 0 rows updated)
update proj_one.prescription
set medication = 'Anarex 200 mg tablets',
 dosage = 'Take 2-4 tablets orally every 8 hours as needed for 3 days, maximum 12 tablets in 24 hours.'
where prescription_id = 23
 and doctor_id = 2;

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-019 | Doctor | SELECT | Positive (extra privilege)
-- Precondition: Doctor flagged Department Head; same-department patient with no assignment.
-- Steps: SELECT that patient's records.
-- Expected: Access is GRANTED because of the Department Head designation.
-- Test data: USER_DOCTOR1 (DOCTOR_ID=1, DEPARTMENT_ID=1, IS_DEPARTMENT_HEAD=1). Same-department, unassigned PATIENT_ID=28; current ADMISSION_ID=10, MEDICAL_RECORD.RECORD_ID=8, LAB_ORDER.ORDER_ID=8, LAB_RESULT.RESULT_ID=8 (released).
-- ---------------------------------------------------------------------
-- expect: 1 row each
select * from proj_one.admission where admission_id = 10;
select * from proj_one.patient where patient_id = 28;
select * from proj_one.medical_record where record_id = 8;
select * from proj_one.lab_order where order_id = 8;
select * from proj_one.lab_result where result_id = 8;

-- ---------------------------------------------------------------------
-- TC-020 | Doctor | SELECT | Negative (boundary)
-- Precondition: Department Head doctor; patient in a different department, no assignment.
-- Steps: SELECT that patient's records.
-- Expected: Access is DENIED; privilege does not extend beyond own department.
-- Test data: USER_DOCTOR1 (DOCTOR_ID=1, DEPARTMENT_ID=1, IS_DEPARTMENT_HEAD=1). Other-department, unassigned PATIENT_ID=24; current ADMISSION_ID=5 (DEPARTMENT_ID=21), MEDICAL_RECORD.RECORD_ID=4, LAB_ORDER.ORDER_ID=4, LAB_RESULT.RESULT_ID=4.
-- ---------------------------------------------------------------------
-- expect: no rows
select * from proj_one.admission where admission_id = 5;
select * from proj_one.patient where patient_id = 24;
select * from proj_one.medical_record where record_id = 4;
select * from proj_one.lab_order where order_id = 4;
select * from proj_one.lab_result where result_id = 4;

-- ---------------------------------------------------------------------
-- TC-021 | Nurse | SELECT | Positive
-- Precondition: Nurse actively assigned to Ward W; Patient X currently admitted there.
-- Steps: SELECT Patient X's basic info and admission/room.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_NURSE1 (STAFF_ID=27, active WARD_ID=1 assignment); PATIENT_ID=21, current ADMISSION_ID=2 (Admitted), ROOM_ID=1 in WARD_ID=1.
-- ---------------------------------------------------------------------
-- expect: 1 row each
select * from proj_one.patient where patient_id = 21;
select * from proj_one.admission where admission_id = 2;
select * from proj_one.room where room_id = 1;

-- ---------------------------------------------------------------------
-- TC-022 | Nurse | SELECT | Negative
-- Precondition: Patient admitted to a ward the nurse is not assigned to, or already discharged.
-- Steps: SELECT basic info and admission/room for that patient.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_NURSE1 (WARD_ID=1). Other-ward PATIENT_ID=28, current ADMISSION_ID=10 (Admitted, ROOM_ID=6 in WARD_ID=2). Discharged PATIENT_ID=27, ADMISSION_ID=8 (WARD_ID=1, Discharged).
-- ---------------------------------------------------------------------
-- (a) other ward (expect no rows)
select * from proj_one.patient where patient_id = 28;
select * from proj_one.admission where admission_id = 10;
-- (b) assigned ward but already discharged (expect no rows)
select * from proj_one.patient where patient_id = 27;
select * from proj_one.admission where admission_id = 8;

-- ---------------------------------------------------------------------
-- TC-023 | Nurse | SELECT | Positive
-- Precondition: Admitted patient in assigned ward with clinical record, lab order, released result.
-- Steps: SELECT the clinical record, lab order and released result.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_NURSE1 (active WARD_ID=1); PATIENT_ID=21, ADMISSION_ID=2, MEDICAL_RECORD.RECORD_ID=16, LAB_ORDER.ORDER_ID=1, LAB_RESULT.RESULT_ID=1 (RELEASED_FLAG=1).
-- ---------------------------------------------------------------------
-- expect: 1 row each
select * from proj_one.medical_record where record_id = 16;
select * from proj_one.lab_order where order_id = 1;
select * from proj_one.lab_result where result_id = 1;

-- ---------------------------------------------------------------------
-- TC-024 | Nurse | SELECT | Negative
-- Precondition: Patient in another ward; or unreleased result for ward patient.
-- Steps: SELECT clinical records and lab results.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_NURSE1 (WARD_ID=1); other-ward PATIENT_ID=28, MEDICAL_RECORD.RECORD_ID=8, LAB_ORDER.ORDER_ID=8, LAB_RESULT.RESULT_ID=8; assigned-ward PATIENT_ID=21, ORDER_ID=16, RESULT_ID=16 (RELEASED_FLAG=0).
-- ---------------------------------------------------------------------
-- (a) other-ward patient (expect no rows)
select * from proj_one.medical_record where record_id = 8;
select * from proj_one.lab_order where order_id = 8;
select * from proj_one.lab_result where result_id = 8;
-- (b) assigned ward, unreleased result (expect no rows)
select * from proj_one.lab_result where result_id = 16;

-- ---------------------------------------------------------------------
-- TC-025 | Nurse | SELECT | Positive
-- Precondition: Admitted patient in assigned ward with an active prescription and dispensing record.
-- Steps: SELECT the prescription and dispensing record.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_NURSE1 (active WARD_ID=1); assigned-ward PATIENT_ID=21: PRESCRIPTION_ID=24 (Pending), PRESCRIPTION_ID=1 (Dispensed), DISPENSING_ID=1 (rx 1).
-- ---------------------------------------------------------------------
-- expect: 1 row each
select * from proj_one.prescription where prescription_id = 24;
select * from proj_one.prescription where prescription_id = 1;
select * from proj_one.dispensing where dispense_id = 1;

-- ---------------------------------------------------------------------
-- TC-026 | Nurse | SELECT | Negative
-- Precondition: Patient in another ward; or cancelled prescription in assigned ward.
-- Steps: SELECT prescriptions and dispensing records.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_NURSE1 (WARD_ID=1); other-ward PATIENT_ID=28: PRESCRIPTION_ID=23 (Pending), DISPENSING_ID=8 (rx 8). No cancelled prescription exists in the assigned ward in the seed data.
-- ---------------------------------------------------------------------
-- expect: no rows
select * from proj_one.prescription where prescription_id = 23;
select * from proj_one.dispensing where dispense_id = 8;

-- ---------------------------------------------------------------------
-- TC-027 | Laboratory Technician | SELECT | Positive
-- Precondition: Order assigned to the tech's department with a linked result.
-- Steps: SELECT the order, its result and the patient identity fields.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_LAB_TECH1 (STAFF_ID=33, DEPARTMENT_ID=23); LAB_ORDER.ORDER_ID=1, LAB_RESULT.RESULT_ID=1, PATIENT_ID=21.
-- ---------------------------------------------------------------------
-- expect: 1 row each
select * from proj_one.lab_order where order_id = 1;
select * from proj_one.lab_result where result_id = 1;
select patient_id, name from proj_one.patient where patient_id = 21;

-- ---------------------------------------------------------------------
-- TC-028 | Laboratory Technician | SELECT | Negative
-- Precondition: Order assigned to a different department; patient has other (non-identity) data.
-- Steps: SELECT that order/result/patient identity; SELECT non-identity patient data.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_LAB_TECH1 (DEPARTMENT_ID=23); other-dept ORDER_ID=2, RESULT_ID=2 (DEPARTMENT_ID=24); PATIENT_ID=30 (only has department-24 orders); MEDICAL_RECORD.RECORD_ID=2 as non-identity data.
-- Data fix: Original probed PATIENT_ID=22, who also has a department-23 order (ORDER_ID=17); PATIENT_ID=30 only has other-department orders.
-- ---------------------------------------------------------------------
-- expect: no rows
select * from proj_one.lab_order where order_id = 2;
select * from proj_one.lab_result where result_id = 2;
select * from proj_one.patient where patient_id = 30;
-- expect: no rows or ORA-00942 (no privilege on MEDICAL_RECORD)
select * from proj_one.medical_record where record_id = 2;

-- ---------------------------------------------------------------------
-- TC-029 | Laboratory Technician | INSERT | Positive
-- Precondition: Order assigned to tech's department.
-- Steps: INSERT a lab result for the order.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_LAB_TECH1 (DEPARTMENT_ID=23); own-dept ORDER_ID=21 (PATIENT_ID=26), no existing result.
-- ---------------------------------------------------------------------
-- expect: 1 row created
insert into proj_one.lab_result (order_id, result_value, result_date, status, released_flag)
values (21, 'TC029 test', sysdate, 'Pending', 0);

-- expect: 1 row
select * from proj_one.lab_result where order_id = 21;

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-030 | Laboratory Technician | INSERT | Negative
-- Precondition: Order assigned to a different department.
-- Steps: INSERT a lab result for that order.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_LAB_TECH1 (DEPARTMENT_ID=23); other-dept ORDER_ID=22 (PATIENT_ID=27, DEPARTMENT_ID=24), no existing result.
-- ---------------------------------------------------------------------
-- expect: ORA-28115 (policy with check option violation)
insert into proj_one.lab_result (order_id, result_value, result_date, status, released_flag)
values (22, 'TC030 test', sysdate, 'Pending', 0);

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-031 | Laboratory Technician | UPDATE | Positive
-- Precondition: Unreleased result and an order, both in tech's department.
-- Steps: UPDATE the result value, date and status; UPDATE the order status.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_LAB_TECH1 (DEPARTMENT_ID=23); unreleased RESULT_ID=19 (Pending) linked to own-dept ORDER_ID=19 (InProgress).
-- ---------------------------------------------------------------------
-- expect: 1 row updated
update proj_one.lab_result
set result_value = 'TC031 value', result_date = sysdate, status = 'Final'
where result_id = 19;

-- expect: 1 row updated
update proj_one.lab_order
set status = 'Completed'
where order_id = 19;

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-032 | Laboratory Technician | UPDATE | Negative
-- Precondition: Released result; or order/result from another department.
-- Steps: UPDATE the result and the order.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_LAB_TECH1 (DEPARTMENT_ID=23); released RESULT_ID=1 (own dept), other-dept ORDER_ID=2 and RESULT_ID=2 (DEPARTMENT_ID=24).
-- ---------------------------------------------------------------------
-- (a) released result (expect 0 rows updated)
update proj_one.lab_result
set result_value = 'TC032 x'
where result_id = 1;

-- (b) other department (expect 0 rows updated)
update proj_one.lab_result
set result_value = 'TC032 x'
where result_id = 2;

update proj_one.lab_order
set status = 'Cancelled'
where order_id = 2;

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-033 | Receptionist | MANAGE | Positive
-- Precondition: Appointment with status Scheduled.
-- Steps: SELECT, INSERT, UPDATE a Scheduled appointment.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_RECEPTIONIST1; existing Scheduled APPOINTMENT_ID=27 (PATIENT_ID=21). Inserts a temporary Scheduled appointment for PATIENT_ID=21, DOCTOR_ID=1 at SYSDATE+7.
-- ---------------------------------------------------------------------
-- expect: 1 row
select * from proj_one.appointment where appointment_id = 27;

-- expect: 1 row created
insert into proj_one.appointment (patient_id, doctor_id, scheduled_at, status)
values (21, 1, systimestamp + interval '7' day, 'Scheduled');

-- expect: 1 row
select * from proj_one.appointment
where patient_id = 21 and doctor_id = 1 and status = 'Scheduled'
  and scheduled_at > systimestamp + interval '6' day;

-- expect: 1 row updated
update proj_one.appointment
set scheduled_at = scheduled_at + interval '1' day
where appointment_id = 27;

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-034 | Receptionist | MANAGE | Negative
-- Precondition: Appointment with status Completed or Cancelled.
-- Steps: UPDATE that appointment.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_RECEPTIONIST1; Completed APPOINTMENT_ID=1 (PATIENT_ID=21, DOCTOR_ID=2); Cancelled APPOINTMENT_ID=33.
-- ---------------------------------------------------------------------
-- expect: 0 rows updated
update proj_one.appointment
set scheduled_at = scheduled_at + interval '1' day
where appointment_id = 1;

-- expect: 0 rows updated
update proj_one.appointment
set scheduled_at = scheduled_at + interval '1' day
where appointment_id = 33;

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-035 | Receptionist | SELECT | Positive
-- Precondition: Existing patient, doctor, ward and room.
-- Steps: SELECT the permitted patient fields, doctor name/specialization, ward/room availability.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_RECEPTIONIST1; PATIENT_ID=21; DOCTOR_ID=1 / STAFF_ID=21; WARD_ID=1 / ROOM_ID=2 (Available).
-- ---------------------------------------------------------------------
-- expect: 1 row each
select patient_id, name, dob, phone from proj_one.patient where patient_id = 21;
select * from proj_one.doctor where doctor_id = 1;
select staff_id, name from proj_one.staff where staff_id = 21;
select * from proj_one.ward where ward_id = 1;
select * from proj_one.room where room_id = 2;

-- ---------------------------------------------------------------------
-- TC-036 | Receptionist | SELECT | Negative
-- Precondition: Patient with clinical and billing data.
-- Steps: SELECT medical records, prescriptions, bills and clinical notes.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_RECEPTIONIST1; PATIENT_ID=21, MEDICAL_RECORD.RECORD_ID=1 (clinical notes), PRESCRIPTION_ID=1, BILL_ID=1.
-- ---------------------------------------------------------------------
-- expect: ORA-00942 or no rows
select * from proj_one.medical_record where record_id = 1;
select * from proj_one.prescription where prescription_id = 1;
select * from proj_one.bill where bill_id = 1;

-- ---------------------------------------------------------------------
-- TC-037 | Receptionist | INSERT | Positive
-- Precondition: Valid new patient details; available room.
-- Steps: INSERT a patient profile and an admission record.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_RECEPTIONIST1; new PATIENT NAME='TC037 Batch', ORACLE_USERNAME='USER_PATIENT999'; linked ADMISSION to ROOM_ID=2 (Available), STATUS='Admitted'.
-- Note: FN_PATIENT_INSERT only accepts ORACLE_USERNAME matching ^USER_PATIENT[1-9][0-9]*$ for receptionists.
-- ---------------------------------------------------------------------
-- expect: 1 row created
insert into proj_one.patient (name, dob, phone, oracle_username)
values ('TC037 Batch', date '1999-01-01', '90000037', 'USER_PATIENT999');

-- expect: 1 row created
insert into proj_one.admission (patient_id, room_id, admit_date, status)
select patient_id, 2, sysdate, 'Admitted'
from proj_one.patient where oracle_username = 'USER_PATIENT999';

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-038 | Receptionist | INSERT | Negative
-- Precondition: Receptionist logged in.
-- Steps: INSERT a medical record, a prescription and a bill.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_RECEPTIONIST1; valid references: PATIENT_ID=21, DOCTOR_ID=2, APPOINTMENT_ID=1, ADMISSION_ID=2.
-- ---------------------------------------------------------------------
-- expect: ORA-00942 (no privilege) for each
insert into proj_one.medical_record (patient_id, author_doctor_id, visit_date)
values (21, 2, sysdate);

insert into proj_one.prescription (appointment_id, patient_id, doctor_id, medication)
values (1, 21, 2, 'TC038');

insert into proj_one.bill (patient_id, admission_id, amount, status)
values (21, 2, 10, 'Open');

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-039 | Receptionist | UPDATE | Positive
-- Precondition: Existing patient.
-- Steps: UPDATE name, date of birth and phone number.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_RECEPTIONIST1; existing PATIENT_ID=21.
-- ---------------------------------------------------------------------
-- expect: 1 row updated
update proj_one.patient
set name = 'TC039 Temporary', dob = date '1999-01-01', phone = '90000039'
where patient_id = 21;

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-040 | Receptionist | UPDATE | Negative
-- Precondition: Existing patient.
-- Steps: UPDATE a column outside name/DOB/phone (e.g. department, diagnosis link).
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_RECEPTIONIST1; existing PATIENT_ID=21.
-- ---------------------------------------------------------------------
-- expect: ORA-41900 (missing UPDATE privilege on the column)
update proj_one.patient
set oracle_username = 'TC040_BLOCKED'
where patient_id = 21;

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-041 | Receptionist | UPDATE | Positive
-- Precondition: Active admission and its room.
-- Steps: UPDATE admission status/discharge date and the room status.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_RECEPTIONIST1; PATIENT_ID=22, ROOM_ID=2. Creates a temporary admission, then Available -> Occupied, Admitted -> Discharged, Occupied -> Available.
-- ---------------------------------------------------------------------
-- expect: 1 row created
insert into proj_one.admission (patient_id, room_id, admit_date, status)
values (22, 2, sysdate, 'Admitted');

-- expect: 1 row updated
update proj_one.room set status = 'Occupied' where room_id = 2;

-- expect: 1 row updated
update proj_one.admission
set status = 'Discharged', discharge_date = sysdate
where patient_id = 22 and room_id = 2 and status = 'Admitted';

-- expect: 1 row updated
update proj_one.room set status = 'Available' where room_id = 2;

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-042 | Receptionist | UPDATE | Negative
-- Precondition: Receptionist logged in.
-- Steps: UPDATE a ward definition or a non-status room column.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_RECEPTIONIST1; WARD_ID=1, ROOM_ID=2.
-- ---------------------------------------------------------------------
-- expect: ORA-41900 (missing UPDATE privilege)
update proj_one.ward set name = 'TC042 x' where ward_id = 1;
update proj_one.room set room_type = 'TC042 x' where room_id = 2;

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-043 | Billing Officer | SELECT | Positive
-- Precondition: Bill linked to an admission.
-- Steps: SELECT the bill, bill status, patient name, admission dates and status.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_BILLING1; BILL_ID=1 (Paid) linked to ADMISSION_ID=1 and PATIENT_ID=21.
-- ---------------------------------------------------------------------
-- expect: 1 row each
select * from proj_one.bill where bill_id = 1;
select * from proj_one.admission where admission_id = 1;
select patient_id, name from proj_one.patient where patient_id = 21;

-- ---------------------------------------------------------------------
-- TC-044 | Billing Officer | SELECT | Negative
-- Precondition: Patient with clinical data.
-- Steps: SELECT clinical notes, prescriptions and lab results.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_BILLING1; MEDICAL_RECORD.RECORD_ID=1 (clinical_notes), PRESCRIPTION_ID=1, LAB_RESULT.RESULT_ID=1.
-- ---------------------------------------------------------------------
-- expect: ORA-00942 or no rows
select clinical_notes from proj_one.medical_record where record_id = 1;
select * from proj_one.prescription where prescription_id = 1;
select * from proj_one.lab_result where result_id = 1;

-- ---------------------------------------------------------------------
-- TC-045 | Billing Officer | INSERT / UPDATE | Positive
-- Precondition: Valid admission; existing bill.
-- Steps: INSERT a bill; UPDATE its amount and status.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_BILLING1; PATIENT_ID=21, ADMISSION_ID=2. Inserts a temporary bill (amount 50, Open), then updates amount to 55 and status to Overdue.
-- ---------------------------------------------------------------------
-- expect: 1 row created
insert into proj_one.bill (patient_id, admission_id, amount, status)
values (21, 2, 50, 'Open');

-- expect: 1 row updated
update proj_one.bill
set amount = 55, status = 'Overdue'
where patient_id = 21 and admission_id = 2 and amount = 50;

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-046 | Billing Officer | INSERT / UPDATE | Negative
-- Precondition: Billing officer logged in.
-- Steps: UPDATE a non-amount/status bill column; UPDATE a patient or admission row.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_BILLING1; BILL_ID=2, PATIENT_ID=21, ADMISSION_ID=2.
-- ---------------------------------------------------------------------
-- expect: ORA-41900 (missing UPDATE privilege) for each
update proj_one.bill set patient_id = 22 where bill_id = 2;
update proj_one.patient set name = 'TC046 x' where patient_id = 21;
update proj_one.admission set status = 'Discharged' where admission_id = 2;

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-047 | Pharmacist | SELECT | Positive
-- Precondition: Prescription with status Pending.
-- Steps: SELECT the prescription and the patient identity fields.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_PHARMACIST1; Pending PRESCRIPTION_ID=24 linked to PATIENT_ID=21.
-- ---------------------------------------------------------------------
-- expect: 1 row each
select * from proj_one.prescription where prescription_id = 24;
select patient_id, name from proj_one.patient where patient_id = 21;

-- ---------------------------------------------------------------------
-- TC-048 | Pharmacist | SELECT | Negative
-- Precondition: Prescription Dispensed or Cancelled; patient has clinical notes.
-- Steps: SELECT those prescriptions and clinical notes.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_PHARMACIST1; Dispensed PRESCRIPTION_ID=1, Cancelled PRESCRIPTION_ID=17, MEDICAL_RECORD.RECORD_ID=1 clinical_notes.
-- ---------------------------------------------------------------------
-- expect: no rows
select * from proj_one.prescription where prescription_id = 1;
select * from proj_one.prescription where prescription_id = 17;
-- expect: ORA-00942 or no rows
select clinical_notes from proj_one.medical_record where record_id = 1;

-- ---------------------------------------------------------------------
-- TC-049 | Pharmacist | SELECT | Positive
-- Precondition: Dispensing record created by this pharmacist.
-- Steps: SELECT own dispensing record.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_PHARMACIST1 (PHARMACIST_ID=1); own DISPENSE_ID=2.
-- ---------------------------------------------------------------------
-- expect: 1 row
select * from proj_one.dispensing where dispense_id = 2;

-- ---------------------------------------------------------------------
-- TC-050 | Pharmacist | SELECT | Negative
-- Precondition: Dispensing record created by another pharmacist.
-- Steps: SELECT that dispensing record.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_PHARMACIST1 (PHARMACIST_ID=1); other pharmacist 2 owns DISPENSE_ID=1.
-- ---------------------------------------------------------------------
-- expect: no rows
select * from proj_one.dispensing where dispense_id = 1;

-- ---------------------------------------------------------------------
-- TC-051 | Pharmacist | INSERT | Positive
-- Precondition: Pending prescription.
-- Steps: INSERT a dispensing record.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_PHARMACIST1 (PHARMACIST_ID=1); Pending PRESCRIPTION_ID=24.
-- ---------------------------------------------------------------------
-- expect: 1 row created
insert into proj_one.dispensing (prescription_id, pharmacist_id, dispense_date, status, medication_quantity)
values (24, 1, sysdate, 'Dispensed', 991);

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-052 | Pharmacist | INSERT | Negative
-- Precondition: Prescription Cancelled or already Dispensed.
-- Steps: INSERT a dispensing record.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_PHARMACIST1 (PHARMACIST_ID=1); Cancelled PRESCRIPTION_ID=17 and already Dispensed PRESCRIPTION_ID=1.
-- ---------------------------------------------------------------------
-- (a) Cancelled prescription (expect ORA-28115)
insert into proj_one.dispensing (prescription_id, pharmacist_id, dispense_date, status, medication_quantity)
values (17, 1, sysdate, 'Dispensed', 992);

-- (b) already Dispensed prescription (expect ORA-28115)
insert into proj_one.dispensing (prescription_id, pharmacist_id, dispense_date, status, medication_quantity)
values (1, 1, sysdate, 'Dispensed', 993);

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-053 | Pharmacist | UPDATE | Positive
-- Precondition: Own dispensing record; its prescription.
-- Steps: UPDATE dispensing status and prescription status.
-- Expected: Access is GRANTED; only the data permitted by the rule is returned/affected.
-- Test data: USER_PHARMACIST1 (PHARMACIST_ID=1); Pending PRESCRIPTION_ID=24. Inserts a temporary own dispensing record, then updates DISPENSING.STATUS and PRESCRIPTION.STATUS.
-- ---------------------------------------------------------------------
-- expect: 1 row created
insert into proj_one.dispensing (prescription_id, pharmacist_id, dispense_date, status, medication_quantity)
values (24, 1, sysdate, 'Dispensed', 994);

-- expect: 1 row updated
update proj_one.dispensing
set status = 'Dispensed'
where prescription_id = 24 and pharmacist_id = 1 and medication_quantity = 994;

-- expect: 1 row updated
update proj_one.prescription
set status = 'Dispensed'
where prescription_id = 24;

ROLLBACK;

-- ---------------------------------------------------------------------
-- TC-054 | Pharmacist | UPDATE | Negative
-- Precondition: Another pharmacist's dispensing record; own prescription.
-- Steps: UPDATE that record; UPDATE medication/dosage on the prescription.
-- Expected: Access is DENIED (default-deny); the operation fails or returns zero rows.
-- Test data: USER_PHARMACIST1 (PHARMACIST_ID=1); other pharmacist 2 owns DISPENSE_ID=1; own DISPENSE_ID=2 links PRESCRIPTION_ID=2.
-- ---------------------------------------------------------------------
-- (a) other pharmacist's record (expect 0 rows updated)
update proj_one.dispensing set status = 'Cancelled' where dispense_id = 1;

-- (b) prescription medication/dosage (expect ORA-41900, missing UPDATE privilege)
update proj_one.prescription set medication = 'TC054 x', dosage = 'x' where prescription_id = 2;

ROLLBACK;
