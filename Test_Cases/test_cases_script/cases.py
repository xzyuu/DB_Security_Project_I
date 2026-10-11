"""VPD test cases transcribed from 'Project 1 Test Cases.xlsx' (TC-001 .. TC-054).

Each case runs in ONE session as the given user and is always rolled back.
Expectation codes
  select steps : ROWS>0 | ROWS=0 | NONE (0 rows OR access denied)
  dml steps    : OK (>=1 row affected) | BLOCKED (0 rows affected OR check-option/privilege error)
`fixtures` are COUNT queries run as the schema owner (PROJ_ONE, VPD-exempt) that must
return >= 1, so a negative test cannot pass just because the seed row is missing.
`sheet` is the Pass/Fail recorded in the spreadsheet (for drift reporting).
"""

P = "proj_one."

PATIENT1 = "USER_PATIENT1"
DOCTOR1, DOCTOR2, DOCTOR6 = "USER_DOCTOR1", "USER_DOCTOR2", "USER_DOCTOR6"
NURSE1 = "USER_NURSE1"
LAB1 = "USER_LAB_TECH1"
RECEP1 = "USER_RECEPTIONIST1"
BILL1 = "USER_BILLING1"
PHARM1 = "USER_PHARMACIST1"


def sel(sql, exp):
    return {"kind": "select", "sql": sql, "exp": exp}


def dml(sql, exp):
    return {"kind": "dml", "sql": sql, "exp": exp}


def tc(cid, role, op, typ, req, user, steps, fixtures=(), sheet=None, note=""):
    return dict(id=cid, role=role, op=op, type=typ, req=req, user=user,
                steps=steps, fixtures=list(fixtures), sheet=sheet, note=note)


def c(table, where=""):
    return f"select count(*) from {P}{table} " + (f"where {where}" if where else "")


CASES = [
    # ------------------------------------------------------------------ Patient
    tc("TC-001", "Patient", "SELECT", "Positive", "Own profile/appointments/admission/room", PATIENT1, [
        sel(f"select * from {P}patient", "ROWS>0"),
        sel(f"select * from {P}patient where patient_id <> 21", "ROWS=0"),
        sel(f"select * from {P}appointment", "ROWS>0"),
        sel(f"select * from {P}appointment where patient_id <> 21", "ROWS=0"),
        sel(f"select * from {P}admission", "ROWS>0"),
        sel(f"select * from {P}admission where patient_id <> 21", "ROWS=0"),
    ], sheet="PASS", note="Patient reaches room via ADMISSION.ROOM_ID; no direct ROOM grant by design, so ROOM is not tested."),
    tc("TC-002", "Patient", "SELECT", "Negative", "Other patients' data", PATIENT1, [
        sel(f"select * from {P}patient where patient_id = 22", "NONE"),
        sel(f"select * from {P}appointment where patient_id = 22", "NONE"),
        sel(f"select * from {P}admission where patient_id = 22", "NONE"),
    ], fixtures=[c("appointment", "patient_id=22"), c("admission", "patient_id=22")], sheet="PASS"),
    tc("TC-003", "Patient", "SELECT", "Positive", "Own prescriptions/dispensing/bills", PATIENT1, [
        sel(f"select * from {P}prescription", "ROWS>0"),
        sel(f"select * from {P}prescription where patient_id <> 21", "ROWS=0"),
        sel(f"select * from {P}dispensing", "ROWS>0"),
        sel(f"select * from {P}dispensing where prescription_id not in (1,16,24)", "ROWS=0"),
        sel(f"select * from {P}bill", "ROWS>0"),
        sel(f"select * from {P}bill where patient_id <> 21", "ROWS=0"),
    ], sheet="PASS"),
    tc("TC-004", "Patient", "SELECT", "Negative", "Other patients' prescriptions/dispensing/bills", PATIENT1, [
        sel(f"select * from {P}prescription where patient_id = 22", "NONE"),
        sel(f"select * from {P}dispensing where prescription_id in (2,17)", "NONE"),
        sel(f"select * from {P}bill where patient_id = 22", "NONE"),
    ], fixtures=[c("prescription", "patient_id=22"), c("dispensing", "prescription_id in (2,17)"),
                 c("bill", "patient_id=22")], sheet="PASS"),
    tc("TC-005", "Patient", "SELECT", "Positive", "Own lab orders, released results, diagnosis", PATIENT1, [
        sel(f"select * from {P}lab_order", "ROWS>0"),
        sel(f"select * from {P}lab_order where patient_id <> 21", "ROWS=0"),
        sel(f"select * from {P}lab_result where result_id = 1", "ROWS>0"),
        sel(f"select diagnosis from {P}medical_record", "ROWS>0"),
        sel(f"select diagnosis from {P}medical_record where patient_id <> 21", "ROWS=0"),
    ], sheet="PASS"),
    tc("TC-006", "Patient", "SELECT", "Negative", "Other patients' lab/diagnosis", PATIENT1, [
        sel(f"select * from {P}lab_order where patient_id = 22", "NONE"),
        sel(f"select * from {P}lab_result where order_id in (2,17)", "NONE"),
        sel(f"select * from {P}medical_record where patient_id = 22", "NONE"),
    ], fixtures=[c("lab_order", "patient_id=22"), c("lab_result", "order_id in (2,17)"),
                 c("medical_record", "patient_id=22")], sheet="PASS"),
    tc("TC-007", "Patient", "SELECT", "Negative", "Unreleased own lab result hidden", PATIENT1, [
        sel(f"select * from {P}lab_result where order_id = 16", "NONE"),
    ], fixtures=[c("lab_result", "order_id=16 and released_flag=0")], sheet="PASS"),

    # ------------------------------------------------------------------- Doctor
    tc("TC-008", "Doctor", "SELECT", "Positive", "Active-assignment patient + admission/room", DOCTOR1, [
        sel(f"select * from {P}patient where patient_id = 21", "ROWS>0"),
        sel(f"select * from {P}admission where patient_id = 21", "ROWS>0"),
        sel(f"select * from {P}room where room_id = 1", "ROWS>0"),
    ], fixtures=[c("care_assignment", "doctor_id=1 and patient_id=21 and status='Active'")], sheet="PASS"),
    tc("TC-009", "Doctor", "SELECT", "Negative", "No active assignment (never / ended / transferred)", DOCTOR2, [
        sel(f"select * from {P}patient where patient_id = 23", "NONE"),
        sel(f"select * from {P}admission where patient_id = 23", "NONE"),
        sel(f"select * from {P}patient where patient_id = 21", "NONE"),
    ], fixtures=[c("patient", "patient_id=23"), c("admission", "patient_id=23"),
                 c("care_assignment", "doctor_id=2 and patient_id=21 and status='Transferred'")],
       sheet="PASS", note="Sheet used DOCTOR1 (a dept head) with patient 22; switched to non-head DOCTOR2."),
    tc("TC-010", "Doctor", "SELECT", "Positive", "Own appointments/prescriptions", DOCTOR1, [
        sel(f"select * from {P}prescription", "ROWS>0"),
        sel(f"select * from {P}prescription where doctor_id <> 1", "ROWS=0"),
        sel(f"select * from {P}appointment", "ROWS>0"),
        sel(f"select * from {P}appointment where doctor_id <> 1", "ROWS=0"),
    ], sheet="PASS"),
    tc("TC-011", "Doctor", "SELECT", "Negative", "Another doctor's appointments/prescriptions", DOCTOR1, [
        sel(f"select * from {P}prescription where doctor_id = 2", "NONE"),
        sel(f"select * from {P}appointment where doctor_id = 2", "NONE"),
    ], fixtures=[c("prescription", "doctor_id=2"), c("appointment", "doctor_id=2")], sheet="PASS"),
    tc("TC-012", "Doctor", "SELECT", "Positive", "Own lab orders + released results", DOCTOR1, [
        sel(f"select order_id, test_type from {P}lab_order where doctor_id = 1", "ROWS>0"),
        sel(f"select result_id, result_value from {P}lab_result where result_id = 13", "ROWS>0"),
    ], fixtures=[c("lab_result", "result_id=13 and released_flag=1")], sheet="PASS"),
    tc("TC-013", "Doctor", "SELECT", "Negative", "Unreleased result / unassigned patient lab data", DOCTOR1, [
        sel(f"select * from {P}lab_result where result_id = 7", "NONE"),
        sel(f"select * from {P}lab_order where order_id = 2", "NONE"),
        sel(f"select * from {P}lab_result where result_id = 2", "NONE"),
    ], fixtures=[c("lab_result", "result_id=7 and released_flag=0"), c("lab_order", "order_id=2")], sheet="FAIL"),
    tc("TC-014", "Doctor", "INSERT", "Positive", "Insert medical record, lab order, prescription (assigned patient)", DOCTOR1, [
        dml(f"insert into {P}medical_record (patient_id, author_doctor_id, visit_date) values (21, 1, sysdate)", "OK"),
        dml(f"insert into {P}lab_order (patient_id, doctor_id, department_id, test_type) values (21, 1, 24, 'TC014 culture')", "OK"),
        dml(f"insert into {P}prescription (appointment_id, patient_id, doctor_id, medication) values (16, 21, 1, 'TC014 med')", "OK"),
    ], sheet="PASS", note="Sheet's prescription row (16,26,6) contradicted its own description; corrected to (16,21,1)."),
    tc("TC-015", "Doctor", "INSERT", "Negative", "Insert for patient without active assignment", DOCTOR6, [
        dml(f"insert into {P}medical_record (patient_id, author_doctor_id, visit_date) values (21, 6, sysdate)", "BLOCKED"),
        dml(f"insert into {P}lab_order (patient_id, doctor_id, department_id, test_type) values (21, 6, 24, 'TC015 culture')", "BLOCKED"),
    ], sheet="PASS"),
    tc("TC-016", "Doctor", "INSERT", "Negative", "Prescription must reference own appointment for that patient", DOCTOR6, [
        dml(f"insert into {P}prescription (appointment_id, patient_id, doctor_id, medication) values (16, 21, 6, 'TC016 med')", "BLOCKED"),
        dml(f"insert into {P}prescription (appointment_id, patient_id, doctor_id, medication) values (21, 21, 6, 'TC016 med')", "BLOCKED"),
    ], fixtures=[c("appointment", "appointment_id=16 and doctor_id=1 and patient_id=21"),
                 c("appointment", "appointment_id=21 and doctor_id=6 and patient_id=26")], sheet="PASS",
       note="Step 1: appointment of another doctor/patient; step 2: own appointment but different patient."),
    tc("TC-017", "Doctor", "UPDATE", "Positive", "Update own Pending prescription", DOCTOR1, [
        dml(f"update {P}prescription set medication = 'TC017 med', dosage = 'TC017 dosage' where prescription_id = 24", "OK"),
    ], fixtures=[c("prescription", "prescription_id=24 and doctor_id=1 and status='Pending'")], sheet="PASS",
       note="Sheet referenced prescription_id=245 (typo); 24 is DOCTOR1's Pending prescription."),
    tc("TC-018", "Doctor", "UPDATE", "Negative", "Dispensed Rx / other doctor's Rx / other columns", DOCTOR1, [
        dml(f"update {P}prescription set status = 'Pending' where prescription_id = 16", "BLOCKED"),
        dml(f"update {P}prescription set medication = 'TC018 x' where prescription_id = 23", "BLOCKED"),
        dml(f"update {P}prescription set patient_id = 22 where prescription_id = 24", "BLOCKED"),
    ], fixtures=[c("prescription", "prescription_id=16 and doctor_id=1 and status='Dispensed'"),
                 c("prescription", "prescription_id=23 and doctor_id=2")], sheet="PASS",
       note="Sheet SQL was invalid (', doctor_id = 6'); rewritten as three separate probes."),
    tc("TC-019", "Doctor", "SELECT", "Positive", "Department head: same-department unassigned patient", DOCTOR1, [
        sel(f"select * from {P}admission where admission_id = 10", "ROWS>0"),
        sel(f"select * from {P}patient where patient_id = 28", "ROWS>0"),
        sel(f"select * from {P}medical_record where record_id = 8", "ROWS>0"),
        sel(f"select * from {P}lab_order where order_id = 8", "ROWS>0"),
        sel(f"select * from {P}lab_result where result_id = 8", "ROWS>0"),
    ], fixtures=[c("admission", "admission_id=10 and patient_id=28 and status='Admitted'"),
                 c("lab_result", "result_id=8 and released_flag=1")], sheet="FAIL"),
    tc("TC-020", "Doctor", "SELECT", "Negative", "Department head limited to own department", DOCTOR1, [
        sel(f"select * from {P}admission where admission_id = 5", "NONE"),
        sel(f"select * from {P}patient where patient_id = 24", "NONE"),
        sel(f"select * from {P}medical_record where record_id = 4", "NONE"),
        sel(f"select * from {P}lab_order where order_id = 4", "NONE"),
        sel(f"select * from {P}lab_result where result_id = 4", "NONE"),
    ], fixtures=[c("admission", "admission_id=5"), c("lab_result", "result_id=4")], sheet="PASS"),

    # -------------------------------------------------------------------- Nurse
    tc("TC-021", "Nurse", "SELECT", "Positive", "Patients admitted to assigned ward", NURSE1, [
        sel(f"select * from {P}patient where patient_id = 21", "ROWS>0"),
        sel(f"select * from {P}admission where admission_id = 2", "ROWS>0"),
        sel(f"select * from {P}room where room_id = 1", "ROWS>0"),
    ], sheet="PASS"),
    tc("TC-022", "Nurse", "SELECT", "Negative", "Other ward / discharged patient", NURSE1, [
        sel(f"select * from {P}patient where patient_id = 28", "NONE"),
        sel(f"select * from {P}admission where admission_id = 10", "NONE"),
        sel(f"select * from {P}patient where patient_id = 27", "NONE"),
        sel(f"select * from {P}admission where admission_id = 8", "NONE"),
    ], fixtures=[c("admission", "admission_id=10"), c("admission", "admission_id=8 and status='Discharged'")],
       sheet="PASS", note="Added discharged-patient probe (p27, ward 1, Discharged)."),
    tc("TC-023", "Nurse", "SELECT", "Positive", "Clinical record, lab order, released result in assigned ward", NURSE1, [
        sel(f"select * from {P}medical_record where record_id = 16", "ROWS>0"),
        sel(f"select * from {P}lab_order where order_id = 1", "ROWS>0"),
        sel(f"select * from {P}lab_result where result_id = 1", "ROWS>0"),
    ], sheet="PASS"),
    tc("TC-024", "Nurse", "SELECT", "Negative", "Other ward patient / unreleased result", NURSE1, [
        sel(f"select * from {P}medical_record where record_id = 8", "NONE"),
        sel(f"select * from {P}lab_order where order_id = 8", "NONE"),
        sel(f"select * from {P}lab_result where result_id = 8", "NONE"),
        sel(f"select * from {P}lab_result where result_id = 16", "NONE"),
    ], fixtures=[c("lab_result", "result_id=16 and released_flag=0"), c("lab_result", "result_id=8")], sheet="FAIL"),
    tc("TC-025", "Nurse", "SELECT", "Positive", "Prescriptions + dispensing of ward patients", NURSE1, [
        sel(f"select * from {P}prescription where prescription_id = 24", "ROWS>0"),
        sel(f"select * from {P}prescription where prescription_id = 1", "ROWS>0"),
        sel(f"select * from {P}dispensing where dispense_id = 1", "ROWS>0"),
    ], sheet="PASS"),
    tc("TC-026", "Nurse", "SELECT", "Negative", "Other-ward prescriptions/dispensing", NURSE1, [
        sel(f"select * from {P}prescription where prescription_id = 23", "NONE"),
        sel(f"select * from {P}dispensing where dispense_id = 8", "NONE"),
    ], fixtures=[c("prescription", "prescription_id=23"), c("dispensing", "dispense_id=8")], sheet="PASS"),

    # ----------------------------------------------------------------- Lab tech
    tc("TC-027", "Lab Technician", "SELECT", "Positive", "Own-dept orders/results + patient identity", LAB1, [
        sel(f"select * from {P}lab_order where order_id = 1", "ROWS>0"),
        sel(f"select * from {P}lab_result where result_id = 1", "ROWS>0"),
        sel(f"select patient_id, name from {P}patient where patient_id = 21", "ROWS>0"),
    ], sheet="FAIL"),
    tc("TC-028", "Lab Technician", "SELECT", "Negative", "Other-dept order/result; non-identity data", LAB1, [
        sel(f"select * from {P}lab_order where order_id = 2", "NONE"),
        sel(f"select * from {P}lab_result where result_id = 2", "NONE"),
        sel(f"select * from {P}patient where patient_id = 30", "NONE"),
        sel(f"select * from {P}medical_record where record_id = 2", "NONE"),
    ], fixtures=[c("lab_order", "order_id=2 and department_id=24"),
                 c("lab_order", "patient_id=30 and department_id=24")], sheet="PASS",
       note="Sheet used patient 22, who also has a dept-23 order (17); switched to patient 30 (dept-24 orders only)."),
    tc("TC-029", "Lab Technician", "INSERT", "Positive", "Insert result for own-dept order", LAB1, [
        dml(f"insert into {P}lab_result (order_id, result_value, result_date, status, released_flag) values (21, 'TC029 test', sysdate, 'Pending', 0)", "OK"),
    ], fixtures=[c("lab_order", "order_id=21 and department_id=23")], sheet="PASS"),
    tc("TC-030", "Lab Technician", "INSERT", "Negative", "Insert result for other-dept order", LAB1, [
        dml(f"insert into {P}lab_result (order_id, result_value, result_date, status, released_flag) values (22, 'TC030 test', sysdate, 'Pending', 0)", "BLOCKED"),
    ], fixtures=[c("lab_order", "order_id=22 and department_id=24")], sheet="PASS"),
    tc("TC-031", "Lab Technician", "UPDATE", "Positive", "Update unreleased result + order status (own dept)", LAB1, [
        dml(f"update {P}lab_result set result_value = 'TC031 value', result_date = sysdate, status = 'Final' where result_id = 19", "OK"),
        dml(f"update {P}lab_order set status = 'Completed' where order_id = 19", "OK"),
    ], fixtures=[c("lab_result", "result_id=19 and released_flag=0"), c("lab_order", "order_id=19 and department_id=23")], sheet="FAIL"),
    tc("TC-032", "Lab Technician", "UPDATE", "Negative", "Released result / other-dept order+result", LAB1, [
        dml(f"update {P}lab_result set result_value = 'TC032 x' where result_id = 1", "BLOCKED"),
        dml(f"update {P}lab_result set result_value = 'TC032 x' where result_id = 2", "BLOCKED"),
        dml(f"update {P}lab_order set status = 'Cancelled' where order_id = 2", "BLOCKED"),
    ], fixtures=[c("lab_result", "result_id=1 and released_flag=1"), c("lab_order", "order_id=2 and department_id=24")], sheet="FAIL"),

    # ------------------------------------------------------------- Receptionist
    tc("TC-033", "Receptionist", "MANAGE", "Positive", "Manage Scheduled appointments", RECEP1, [
        sel(f"select * from {P}appointment where appointment_id = 27", "ROWS>0"),
        dml(f"insert into {P}appointment (patient_id, doctor_id, scheduled_at, status) values (21, 1, systimestamp + interval '7' day, 'Scheduled')", "OK"),
        sel(f"select * from {P}appointment where patient_id = 21 and doctor_id = 1 and scheduled_at > systimestamp + interval '6' day and status = 'Scheduled'", "ROWS>0"),
        dml(f"update {P}appointment set scheduled_at = scheduled_at + interval '1' day where appointment_id = 27", "OK"),
    ], fixtures=[c("appointment", "appointment_id=27 and status='Scheduled'")], sheet="PASS"),
    tc("TC-034", "Receptionist", "UPDATE", "Negative", "Update non-Scheduled appointment", RECEP1, [
        dml(f"update {P}appointment set scheduled_at = scheduled_at + interval '1' day where appointment_id = 1", "BLOCKED"),
        dml(f"update {P}appointment set scheduled_at = scheduled_at + interval '1' day where appointment_id = 33", "BLOCKED"),
    ], fixtures=[c("appointment", "appointment_id=1 and status='Completed'"),
                 c("appointment", "appointment_id=33 and status='Cancelled'")], sheet="PASS"),
    tc("TC-035", "Receptionist", "SELECT", "Positive", "Patient info, doctors, wards/rooms", RECEP1, [
        sel(f"select patient_id, name, dob, phone from {P}patient where patient_id = 21", "ROWS>0"),
        sel(f"select * from {P}doctor where doctor_id = 1", "ROWS>0"),
        sel(f"select staff_id, name from {P}staff where staff_id = 21", "ROWS>0"),
        sel(f"select * from {P}ward where ward_id = 1", "ROWS>0"),
        sel(f"select * from {P}room where room_id = 2", "ROWS>0"),
    ], sheet="FAIL"),
    tc("TC-036", "Receptionist", "SELECT", "Negative", "Medical records / prescriptions / bills", RECEP1, [
        sel(f"select * from {P}medical_record where record_id = 1", "NONE"),
        sel(f"select * from {P}prescription where prescription_id = 1", "NONE"),
        sel(f"select * from {P}bill where bill_id = 1", "NONE"),
    ], sheet="PASS"),
    tc("TC-037", "Receptionist", "INSERT", "Positive", "Insert patient + admission", RECEP1, [
        dml(f"insert into {P}patient (name, dob, phone, oracle_username) values ('TC037 Batch', date '1999-01-01', '90000037', 'USER_PATIENT999')", "OK"),
        dml(f"insert into {P}admission (patient_id, room_id, admit_date, status) select patient_id, 2, sysdate, 'Admitted' from {P}patient where oracle_username = 'USER_PATIENT999'", "OK"),
    ], sheet="PASS", note="FN_PATIENT_INSERT now requires oracle_username to match ^USER_PATIENT[1-9][0-9]*$; sheet's TC037_B3_TEMP would be rejected."),
    tc("TC-038", "Receptionist", "INSERT", "Negative", "Insert medical record / prescription / bill", RECEP1, [
        dml(f"insert into {P}medical_record (patient_id, author_doctor_id, visit_date) values (21, 2, sysdate)", "BLOCKED"),
        dml(f"insert into {P}prescription (appointment_id, patient_id, doctor_id, medication) values (1, 21, 2, 'TC038')", "BLOCKED"),
        dml(f"insert into {P}bill (patient_id, admission_id, amount, status) values (21, 2, 10, 'Open')", "BLOCKED"),
    ], sheet="PASS"),
    tc("TC-039", "Receptionist", "UPDATE", "Positive", "Update patient name/DOB/phone", RECEP1, [
        dml(f"update {P}patient set name = 'TC039 Temporary', dob = date '1999-01-01', phone = '90000039' where patient_id = 21", "OK"),
    ], sheet="PASS"),
    tc("TC-040", "Receptionist", "UPDATE", "Negative", "Update other patient columns", RECEP1, [
        dml(f"update {P}patient set oracle_username = 'TC040_BLOCKED' where patient_id = 21", "BLOCKED"),
    ], sheet="PASS"),
    tc("TC-041", "Receptionist", "UPDATE", "Positive", "Admission discharge flow + room status", RECEP1, [
        dml(f"insert into {P}admission (patient_id, room_id, admit_date, status) values (22, 2, sysdate, 'Admitted')", "OK"),
        dml(f"update {P}room set status = 'Occupied' where room_id = 2", "OK"),
        dml(f"update {P}admission set status = 'Discharged', discharge_date = sysdate where patient_id = 22 and room_id = 2 and status = 'Admitted'", "OK"),
        dml(f"update {P}room set status = 'Available' where room_id = 2", "OK"),
    ], sheet="PASS"),
    tc("TC-042", "Receptionist", "UPDATE", "Negative", "Update ward definition / non-status room column", RECEP1, [
        dml(f"update {P}ward set name = 'TC042 x' where ward_id = 1", "BLOCKED"),
        dml(f"update {P}room set room_type = 'TC042 x' where room_id = 2", "BLOCKED"),
    ], sheet="PASS"),

    # ------------------------------------------------------------------ Billing
    tc("TC-043", "Billing Officer", "SELECT", "Positive", "Bills + linked patient name/admission", BILL1, [
        sel(f"select * from {P}bill where bill_id = 1", "ROWS>0"),
        sel(f"select * from {P}admission where admission_id = 1", "ROWS>0"),
        sel(f"select patient_id, name from {P}patient where patient_id = 21", "ROWS>0"),
    ], sheet="FAIL"),
    tc("TC-044", "Billing Officer", "SELECT", "Negative", "Clinical notes / prescriptions / lab results", BILL1, [
        sel(f"select clinical_notes from {P}medical_record where record_id = 1", "NONE"),
        sel(f"select * from {P}prescription where prescription_id = 1", "NONE"),
        sel(f"select * from {P}lab_result where result_id = 1", "NONE"),
    ], sheet="PASS"),
    tc("TC-045", "Billing Officer", "INSERT/UPDATE", "Positive", "Insert bill; update amount/status", BILL1, [
        dml(f"insert into {P}bill (patient_id, admission_id, amount, status) values (21, 2, 50, 'Open')", "OK"),
        dml(f"update {P}bill set amount = 55, status = 'Overdue' where patient_id = 21 and admission_id = 2 and amount = 50", "OK"),
    ], sheet="PASS"),
    tc("TC-046", "Billing Officer", "UPDATE", "Negative", "Out-of-scope columns/tables", BILL1, [
        dml(f"update {P}bill set patient_id = 22 where bill_id = 2", "BLOCKED"),
        dml(f"update {P}patient set name = 'TC046 x' where patient_id = 21", "BLOCKED"),
        dml(f"update {P}admission set status = 'Discharged' where admission_id = 2", "BLOCKED"),
    ], sheet="PASS"),

    # --------------------------------------------------------------- Pharmacist
    tc("TC-047", "Pharmacist", "SELECT", "Positive", "Pending prescription + patient identity", PHARM1, [
        sel(f"select * from {P}prescription where prescription_id = 24", "ROWS>0"),
        sel(f"select patient_id, name from {P}patient where patient_id = 21", "ROWS>0"),
    ], fixtures=[c("prescription", "prescription_id=24 and status='Pending'")], sheet="FAIL"),
    tc("TC-048", "Pharmacist", "SELECT", "Negative", "Dispensed/Cancelled prescription; clinical notes", PHARM1, [
        sel(f"select * from {P}prescription where prescription_id = 1", "NONE"),
        sel(f"select * from {P}prescription where prescription_id = 17", "NONE"),
        sel(f"select clinical_notes from {P}medical_record where record_id = 1", "NONE"),
    ], fixtures=[c("prescription", "prescription_id=1 and status='Dispensed'"),
                 c("prescription", "prescription_id=17 and status='Cancelled'")], sheet="PASS"),
    tc("TC-049", "Pharmacist", "SELECT", "Positive", "Own dispensing record", PHARM1, [
        sel(f"select * from {P}dispensing where dispense_id = 2", "ROWS>0"),
    ], fixtures=[c("dispensing", "dispense_id=2 and pharmacist_id=1")], sheet="PASS"),
    tc("TC-050", "Pharmacist", "SELECT", "Negative", "Another pharmacist's dispensing record", PHARM1, [
        sel(f"select * from {P}dispensing where dispense_id = 1", "NONE"),
    ], fixtures=[c("dispensing", "dispense_id=1 and pharmacist_id=2")], sheet="PASS"),
    tc("TC-051", "Pharmacist", "INSERT", "Positive", "Dispense a Pending prescription", PHARM1, [
        dml(f"insert into {P}dispensing (prescription_id, pharmacist_id, dispense_date, status, medication_quantity) values (24, 1, sysdate, 'Dispensed', 991)", "OK"),
    ], fixtures=[c("prescription", "prescription_id=24 and status='Pending'")], sheet="PASS"),
    tc("TC-052", "Pharmacist", "INSERT", "Negative", "Dispense Cancelled / already Dispensed prescription", PHARM1, [
        dml(f"insert into {P}dispensing (prescription_id, pharmacist_id, dispense_date, status, medication_quantity) values (17, 1, sysdate, 'Dispensed', 992)", "BLOCKED"),
        dml(f"insert into {P}dispensing (prescription_id, pharmacist_id, dispense_date, status, medication_quantity) values (1, 1, sysdate, 'Dispensed', 993)", "BLOCKED"),
    ], fixtures=[c("prescription", "prescription_id=17 and status='Cancelled'"),
                 c("prescription", "prescription_id=1 and status='Dispensed'")], sheet="FAIL"),
    tc("TC-053", "Pharmacist", "UPDATE", "Positive", "Update own dispensing + prescription status", PHARM1, [
        dml(f"insert into {P}dispensing (prescription_id, pharmacist_id, dispense_date, status, medication_quantity) values (24, 1, sysdate, 'Dispensed', 994)", "OK"),
        dml(f"update {P}dispensing set status = 'Dispensed' where prescription_id = 24 and pharmacist_id = 1 and medication_quantity = 994", "OK"),
        dml(f"update {P}prescription set status = 'Dispensed' where prescription_id = 24", "OK"),
    ], sheet="PASS"),
    tc("TC-054", "Pharmacist", "UPDATE", "Negative", "Other pharmacist's record / prescription columns", PHARM1, [
        dml(f"update {P}dispensing set status = 'Cancelled' where dispense_id = 1", "BLOCKED"),
        dml(f"update {P}prescription set medication = 'TC054 x', dosage = 'x' where prescription_id = 2", "BLOCKED"),
    ], fixtures=[c("dispensing", "dispense_id=1 and pharmacist_id=2"), c("prescription", "prescription_id=2")], sheet="PASS"),
]
