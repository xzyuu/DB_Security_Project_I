
SET SQLBLANKLINES ON
SET DEFINE OFF

-- ============================================================================
-- 1. PATIENT - INSERT / UPDATE FUNCTIONS
-- ============================================================================

-- INSERT - FN_PATIENT_INSERT

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_PATIENT_INSERT(v_schema IN VARCHAR2, v_obj IN VARCHAR2)
RETURN VARCHAR2 AS
    condition VARCHAR2 (200);
BEGIN
    IF (SYS_CONTEXT('USERENV', 'SESSION_USER') = 'PROJ_ONE') THEN
        condition := '';
    ELSIF (SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_RECEPTIONIST') THEN
        condition := 'REGEXP_LIKE(oracle_username, ''^USER_PATIENT[1-9][0-9]*$'')';
    ELSE
        condition := '1 = 0';
    END IF;
    RETURN condition;
END fn_patient_insert;
/

SHOW ERRORS FUNCTION PROJ_ONE.FN_PATIENT_INSERT

-- Attach FN_PATIENT_INSERT: POL_PATIENT_INSERT
BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'PATIENT',
        policy_name     => 'POL_PATIENT_INSERT',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_PATIENT_INSERT',
        statement_types => 'INSERT',
        update_check    => TRUE,
        enable          => TRUE,
        policy_type     => DBMS_RLS.DYNAMIC,
        long_predicate  => FALSE
    );
END;
/


-- UPDATE - FN_PATIENT_UPDATE

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_PATIENT_UPDATE
(p_schema IN VARCHAR2, p_object IN VARCHAR2)
RETURN VARCHAR2 AS
  v_role VARCHAR2(128);
BEGIN
  IF upper(sys_context('USERENV','SESSION_USER')) = 'PROJ_ONE' THEN
    RETURN '1=1';
  END IF;
  v_role := upper(sys_context('HOSPITAL_CTX','APP_ROLE'));
  IF v_role = 'ROLE_RECEPTIONIST' THEN
    RETURN '1=1';   -- any patient row; the column grants still limit it to NAME, DOB, PHONE
  END IF;
  RETURN '1=0';     -- everyone else: no updates
END;
/

SHOW ERRORS FUNCTION PROJ_ONE.FN_PATIENT_UPDATE

-- Attach FN_PATIENT_UPDATE: POL_PATIENT_UPDATE
BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'PATIENT',
        policy_name     => 'POL_PATIENT_UPDATE',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_PATIENT_UPDATE',
        statement_types => 'UPDATE',
        update_check    => TRUE,
        enable          => TRUE,
        policy_type     => DBMS_RLS.DYNAMIC,
        long_predicate  => FALSE
    );
END;
/


-- ============================================================================
-- 2. BILL - INSERT / UPDATE FUNCTIONS
-- ============================================================================

-- INSERT - FN_BILL_INS

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_BILL_INS (v_schema IN VARCHAR2, v_obj IN VARCHAR2)
RETURN VARCHAR2 AS
    condition VARCHAR2 (300);
BEGIN
    IF (SYS_CONTEXT('USERENV', 'SESSION_USER') = 'PROJ_ONE') THEN
        condition := '';
    ELSIF (SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_BILLING') THEN
        condition := '';
    ELSE
        condition := '1 = 0';
    END IF;
    RETURN condition;
END fn_bill_ins;
/

SHOW ERRORS FUNCTION PROJ_ONE.FN_BILL_INS

-- Attach FN_BILL_INS: POL_BILL_INSERT_MATCH_ADMIT
BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'BILL',
        policy_name     => 'POL_BILL_INSERT_MATCH_ADMIT',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_BILL_INS',
        statement_types => 'INSERT',
        update_check    => TRUE,
        enable          => TRUE,
        policy_type     => DBMS_RLS.DYNAMIC,
        long_predicate  => FALSE
    );
END;
/


-- UPDATE - FN_BILL_UPD

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_BILL_UPD
  (p_schema IN VARCHAR2, p_object IN VARCHAR2) RETURN VARCHAR2
AS
BEGIN
  IF UPPER(SYS_CONTEXT('USERENV', 'SESSION_USER')) = 'PROJ_ONE' THEN RETURN '1=1'; END IF;
  IF UPPER(SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE')) = 'ROLE_BILLING' THEN
    RETURN q'[status <> 'Paid']';
  END IF;
  RETURN '1=0';
END;
/

SHOW ERRORS FUNCTION PROJ_ONE.FN_BILL_UPD

-- Attach FN_BILL_UPD: POL_BILL_EDIT_UNPAID_ONLY
BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'BILL',
        policy_name     => 'POL_BILL_EDIT_UNPAID_ONLY',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_BILL_UPD',
        statement_types => 'UPDATE',
        update_check    => FALSE,
        enable          => TRUE,
        policy_type     => DBMS_RLS.DYNAMIC,
        long_predicate  => FALSE
    );
END;
/


-- ============================================================================
-- 3. APPOINTMENT - INSERT / UPDATE FUNCTIONS
-- ============================================================================

-- INSERT - FN_APPOINTMENT_INS

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_APPOINTMENT_INS
  (p_schema IN VARCHAR2, p_object IN VARCHAR2) RETURN VARCHAR2
AS
BEGIN
  IF UPPER(SYS_CONTEXT('USERENV', 'SESSION_USER')) = 'PROJ_ONE' THEN RETURN '1=1'; END IF;
  IF UPPER(SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE')) = 'ROLE_RECEPTIONIST' THEN
    RETURN q'[status = 'Scheduled']';
  END IF;
  RETURN '1=0';
END;
/

SHOW ERRORS FUNCTION PROJ_ONE.FN_APPOINTMENT_INS

-- Attach FN_APPOINTMENT_INS: POL_APPT_INSERT_SCHEDULED_ONLY
BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'APPOINTMENT',
        policy_name     => 'POL_APPT_INSERT_SCHEDULED_ONLY',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_APPOINTMENT_INS',
        statement_types => 'INSERT',
        update_check    => TRUE,
        enable          => TRUE,
        policy_type     => DBMS_RLS.DYNAMIC,
        long_predicate  => FALSE
    );
END;
/


-- UPDATE / DELETE - FN_APPOINTMENT_UPD

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_APPOINTMENT_UPD
  (p_schema IN VARCHAR2, p_object IN VARCHAR2) RETURN VARCHAR2
AS
BEGIN
  IF UPPER(SYS_CONTEXT('USERENV', 'SESSION_USER')) = 'PROJ_ONE' THEN RETURN '1=1'; END IF;
  IF UPPER(SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE')) = 'ROLE_RECEPTIONIST' THEN
    RETURN q'[status = 'Scheduled']';
  END IF;
  RETURN '1=0';
END;
/

SHOW ERRORS FUNCTION PROJ_ONE.FN_APPOINTMENT_UPD

-- Attach FN_APPOINTMENT_UPD: POL_APPT_EDIT_SCHEDULED_ONLY
BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'APPOINTMENT',
        policy_name     => 'POL_APPT_EDIT_SCHEDULED_ONLY',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_APPOINTMENT_UPD',
        statement_types => 'UPDATE,DELETE',
        update_check    => FALSE,
        enable          => TRUE,
        policy_type     => DBMS_RLS.DYNAMIC,
        long_predicate  => FALSE
    );
END;
/


-- ============================================================================
-- 4. PRESCRIPTION - INSERT / UPDATE FUNCTIONS
-- ============================================================================

-- INSERT - FN_PRESCRIPTION_INSERT

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_PRESCRIPTION_INSERT
(
    p_schema IN VARCHAR2,
    p_object IN VARCHAR2
)
RETURN VARCHAR2
AS
    v_role VARCHAR2(128);
BEGIN
    -- Schema owner: full access.
    IF UPPER(SYS_CONTEXT('USERENV', 'SESSION_USER')) = 'PROJ_ONE' THEN
        RETURN '1 = 1';
    END IF;

    v_role := UPPER(SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE'));

    IF v_role = 'ROLE_DOCTOR' THEN
        RETURN '
            doctor_id =
                TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'', ''DOCTOR_ID''))
            AND (appointment_id, patient_id) IN
            (
                SELECT a.appointment_id, a.patient_id
                FROM PROJ_ONE.APPOINTMENT a
                WHERE a.doctor_id =
                      TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'', ''DOCTOR_ID''))
            )';
    ELSE
        RETURN '1 = 0';
    END IF;
END;
/

SHOW ERRORS FUNCTION PROJ_ONE.FN_PRESCRIPTION_INSERT

-- Attach FN_PRESCRIPTION_INSERT: POL_PRESCRIPTION_INSERT
BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'PRESCRIPTION',
        policy_name     => 'POL_PRESCRIPTION_INSERT',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_PRESCRIPTION_INSERT',
        statement_types => 'INSERT',
        update_check    => TRUE,
        enable          => TRUE,
        policy_type     => DBMS_RLS.DYNAMIC,
        long_predicate  => FALSE
    );
END;
/


-- UPDATE - FN_PRESCRIPTION_UPDATE

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_PRESCRIPTION_UPDATE
(
    p_schema IN VARCHAR2,
    p_object IN VARCHAR2
)
RETURN VARCHAR2
AS
    v_role VARCHAR2(128);
BEGIN
    -- Schema owner: full access.
    IF UPPER(SYS_CONTEXT('USERENV', 'SESSION_USER')) = 'PROJ_ONE' THEN
        RETURN '1 = 1';
    END IF;

    v_role := UPPER(SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE'));

    -- Doctor: update own prescriptions only while they
    -- have not been dispensed or cancelled.
    IF v_role = 'ROLE_DOCTOR' THEN
        RETURN '
            doctor_id =
                TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'', ''DOCTOR_ID''))
            AND UPPER(status) NOT IN (''DISPENSED'', ''CANCELLED'')';

    -- Pharmacist: update a Pending prescription only after
    -- completing a dispensing record belonging to themselves.
    ELSIF v_role = 'ROLE_PHARMACIST' THEN
        RETURN '
            UPPER(status) = ''PENDING''
            AND prescription_id IN
            (
                SELECT d.prescription_id
                FROM PROJ_ONE.DISPENSING d
                WHERE d.pharmacist_id =
                      TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'', ''PHARMACIST_ID''))
                  AND UPPER(d.status) = ''DISPENSED''
            )';

    -- Patients, nurses and other roles: no updates.
    ELSE
        RETURN '1 = 0';
    END IF;
END;
/

SHOW ERRORS FUNCTION PROJ_ONE.FN_PRESCRIPTION_UPDATE

-- Attach FN_PRESCRIPTION_UPDATE: POL_PRESCRIPTION_UPDATE
BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'PRESCRIPTION',
        policy_name     => 'POL_PRESCRIPTION_UPDATE',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_PRESCRIPTION_UPDATE',
        statement_types => 'UPDATE',
        update_check    => FALSE,
        enable          => TRUE,
        policy_type     => DBMS_RLS.DYNAMIC,
        long_predicate  => FALSE
    );
END;
/


-- ============================================================================
-- 5. DISPENSING - INSERT / UPDATE FUNCTIONS
-- ============================================================================

-- INSERT - FN_DISPENSING_INSERT

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_DISPENSING_INSERT
(
    p_schema IN VARCHAR2,
    p_object IN VARCHAR2
)
RETURN VARCHAR2
AS
    v_role VARCHAR2(128);
BEGIN
    -- Schema owner: full access.
    IF UPPER(SYS_CONTEXT('USERENV', 'SESSION_USER')) = 'PROJ_ONE' THEN
        RETURN '1 = 1';
    END IF;

    v_role := UPPER(SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE'));

    IF v_role = 'ROLE_PHARMACIST' THEN
        RETURN '
            pharmacist_id =
                TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'', ''PHARMACIST_ID''))
	AND prescription_id IN (
		SELECT p.prescription_id
		FROM PROJ_ONE.PRESCRIPTION p
		WHERE UPPER(p.status) = ''PENDING'')';
    ELSE
        RETURN '1 = 0';
    END IF;
END;
/

SHOW ERRORS FUNCTION PROJ_ONE.FN_DISPENSING_INSERT

-- Attach FN_DISPENSING_INSERT: POL_DISPENSING_INSERT
BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'DISPENSING',
        policy_name     => 'POL_DISPENSING_INSERT',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_DISPENSING_INSERT',
        statement_types => 'INSERT',
        update_check    => TRUE,
        enable          => TRUE,
        policy_type     => DBMS_RLS.DYNAMIC,
        long_predicate  => FALSE
    );
END;
/


-- UPDATE - FN_DISPENSING_UPDATE

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_DISPENSING_UPDATE
(
    p_schema IN VARCHAR2,
    p_object IN VARCHAR2
)
RETURN VARCHAR2
AS
    v_role VARCHAR2(128);
BEGIN
    IF UPPER(SYS_CONTEXT('USERENV', 'SESSION_USER')) = 'PROJ_ONE' THEN
        RETURN '1 = 1';
    END IF;

    v_role := UPPER(SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE'));

    IF v_role = 'ROLE_PHARMACIST' THEN
        RETURN '
            pharmacist_id =
                TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'', ''PHARMACIST_ID''))';
    ELSE
        RETURN '1 = 0';
    END IF;
END;
/

SHOW ERRORS FUNCTION PROJ_ONE.FN_DISPENSING_UPDATE

-- Attach FN_DISPENSING_UPDATE: POL_DISPENSING_UPDATE
BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'DISPENSING',
        policy_name     => 'POL_DISPENSING_UPDATE',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_DISPENSING_UPDATE',
        statement_types => 'UPDATE',
        update_check    => TRUE,
        enable          => TRUE,
        policy_type     => DBMS_RLS.DYNAMIC,
        long_predicate  => FALSE
    );
END;
/


-- ============================================================================
-- 6. ADMISSION - INSERT / UPDATE FUNCTIONS
-- ============================================================================

-- One function is attached to both INSERT and UPDATE in production.

-- INSERT / UPDATE - FN_ADMISSION_WRITE

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_ADMISSION_WRITE
(p_schema IN VARCHAR2, p_object IN VARCHAR2)
RETURN VARCHAR2
AUTHID DEFINER
AS
BEGIN
  IF SYS_CONTEXT('USERENV','SESSION_USER')='PROJ_ONE'
     OR SYS_CONTEXT('HOSPITAL_CTX','INITIALIZING')='Y' THEN
    RETURN '1=1';
  ELSIF SYS_CONTEXT('HOSPITAL_CTX','APP_ROLE')='ROLE_RECEPTIONIST' THEN
    RETURN '1=1';
  ELSE
    RETURN '1=0';
  END IF;
END;
/

SHOW ERRORS FUNCTION PROJ_ONE.FN_ADMISSION_WRITE

-- Attach FN_ADMISSION_WRITE: POL_ADMISSION_WRITE
BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'ADMISSION',
        policy_name     => 'POL_ADMISSION_WRITE',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_ADMISSION_WRITE',
        statement_types => 'INSERT,UPDATE',
        update_check    => TRUE,
        enable          => TRUE,
        policy_type     => DBMS_RLS.DYNAMIC,
        long_predicate  => FALSE
    );
END;
/


-- ============================================================================
-- 7. MEDICAL_RECORD - INSERT / UPDATE FUNCTIONS
-- ============================================================================

-- INSERT - FN_MEDICAL_RECORD_INSERT

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_MEDICAL_RECORD_INSERT
(
    p_schema IN VARCHAR2,
    p_object IN VARCHAR2
)
RETURN VARCHAR2
AS
    v_role VARCHAR2(128);
BEGIN

    IF UPPER(SYS_CONTEXT('USERENV','SESSION_USER')) = 'PROJ_ONE' THEN
        RETURN '1 = 1';
    END IF;

    v_role := UPPER( SYS_CONTEXT( 'HOSPITAL_CTX', 'APP_ROLE'));

    IF v_role = 'ROLE_DOCTOR' THEN

        RETURN '
            author_doctor_id = TO_NUMBER( SYS_CONTEXT( ''HOSPITAL_CTX'',''DOCTOR_ID''))
            AND patient_id IN
            (
                SELECT ca.patient_id
                FROM PROJ_ONE.CARE_ASSIGNMENT ca
                WHERE ca.doctor_id = TO_NUMBER( SYS_CONTEXT( ''HOSPITAL_CTX'',''DOCTOR_ID''))
                  AND UPPER(ca.status) = ''ACTIVE''
                  AND ca.start_date <= SYSDATE
                  AND ( ca.end_date IS NULL OR ca.end_date >= SYSDATE )
            )';

    ELSE
        RETURN '1 = 0';
    END IF;
END;
/

SHOW ERRORS FUNCTION PROJ_ONE.FN_MEDICAL_RECORD_INSERT

-- Attach FN_MEDICAL_RECORD_INSERT: POL_MEDICAL_RECORD_INSERT
BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'MEDICAL_RECORD',
        policy_name     => 'POL_MEDICAL_RECORD_INSERT',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_MEDICAL_RECORD_INSERT',
        statement_types => 'INSERT',
        update_check    => TRUE,
        enable          => TRUE,
        policy_type     => DBMS_RLS.DYNAMIC,
        long_predicate  => FALSE
    );
END;
/


-- UPDATE - FN_MEDICAL_RECORD_UPDATE

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_MEDICAL_RECORD_UPDATE (v_schema IN VARCHAR2, v_obj IN VARCHAR2)
RETURN VARCHAR2 AS
    condition VARCHAR2 (2000);
    v_assigned VARCHAR2 (1000) :=
        'SELECT ca.patient_id FROM PROJ_ONE.CARE_ASSIGNMENT ca
          WHERE ca.doctor_id = SYS_CONTEXT(''HOSPITAL_CTX'', ''DOCTOR_ID'')
            AND UPPER(ca.status) = ''ACTIVE'' AND ca.start_date <= SYSDATE AND ( ca.end_date IS NULL OR ca.end_date >= SYSDATE )';
BEGIN
    IF (SYS_CONTEXT('USERENV', 'SESSION_USER') = 'PROJ_ONE') THEN
        condition := '';
    ELSIF (SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_DOCTOR') THEN
        condition := 'author_doctor_id = SYS_CONTEXT(''HOSPITAL_CTX'', ''DOCTOR_ID'') AND patient_id IN ('||v_assigned ||')';
    ELSE
        condition := '1 = 0';
    END IF;
    RETURN condition;
END fn_medical_record_update;
/

SHOW ERRORS FUNCTION PROJ_ONE.FN_MEDICAL_RECORD_UPDATE

-- Attach FN_MEDICAL_RECORD_UPDATE: POL_MEDICAL_RECORD_UPDATE
BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'MEDICAL_RECORD',
        policy_name     => 'POL_MEDICAL_RECORD_UPDATE',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_MEDICAL_RECORD_UPDATE',
        statement_types => 'UPDATE',
        update_check    => TRUE,
        enable          => TRUE,
        policy_type     => DBMS_RLS.DYNAMIC,
        long_predicate  => FALSE
    );
END;
/


-- ============================================================================
-- 8. LAB_ORDER - INSERT / UPDATE FUNCTIONS
-- ============================================================================

-- INSERT - FN_LAB_ORDER_INSERT

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_LAB_ORDER_INSERT
(
    p_schema IN VARCHAR2,
    p_object IN VARCHAR2
)
RETURN VARCHAR2
AS
    v_role VARCHAR2(128);
BEGIN
    IF UPPER(SYS_CONTEXT('USERENV','SESSION_USER')) = 'PROJ_ONE' THEN
        RETURN '1 = 1';
    END IF;

    v_role := UPPER(SYS_CONTEXT('HOSPITAL_CTX','APP_ROLE'));

    IF v_role = 'ROLE_DOCTOR' THEN
        RETURN '
            -- Ensure the lab order is created by the logged in doctor
            doctor_id = TO_NUMBER( SYS_CONTEXT(''HOSPITAL_CTX'', ''DOCTOR_ID''))
            AND patient_id IN
            (
                SELECT ca.patient_id
                FROM PROJ_ONE.CARE_ASSIGNMENT ca
                WHERE ca.doctor_id =
                TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'', ''DOCTOR_ID''))
                  AND UPPER(ca.status) = ''ACTIVE''
                  AND ca.start_date <= SYSDATE
                  AND (ca.end_date IS NULL OR ca.end_date >= SYSDATE)
            )';
    ELSE
        RETURN '1 = 0';
    END IF;
END;
/

SHOW ERRORS FUNCTION PROJ_ONE.FN_LAB_ORDER_INSERT

-- Attach FN_LAB_ORDER_INSERT: POL_LAB_ORDER_INSERT
BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'LAB_ORDER',
        policy_name     => 'POL_LAB_ORDER_INSERT',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_LAB_ORDER_INSERT',
        statement_types => 'INSERT',
        update_check    => TRUE,
        enable          => TRUE,
        policy_type     => DBMS_RLS.DYNAMIC,
        long_predicate  => FALSE
    );
END;
/


-- UPDATE - FN_LAB_ORDER_UPDATE

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_LAB_ORDER_UPDATE
(
    p_schema IN VARCHAR2,
    p_object IN VARCHAR2
)
RETURN VARCHAR2
AS
    v_role VARCHAR2(128);
BEGIN

    IF UPPER(SYS_CONTEXT('USERENV','SESSION_USER')) = 'PROJ_ONE' THEN
        RETURN '1 = 1';
    END IF;

    v_role := UPPER(SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE' ));

    IF v_role = 'ROLE_LAB_TECH' THEN
        RETURN 'department_id = TO_NUMBER( SYS_CONTEXT( ''HOSPITAL_CTX'', ''DEPARTMENT_ID'' ))';
    ELSE
        RETURN '1 = 0';
    END IF;
END;
/

SHOW ERRORS FUNCTION PROJ_ONE.FN_LAB_ORDER_UPDATE

-- Attach FN_LAB_ORDER_UPDATE: POL_LAB_ORDER_UPDATE
BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'LAB_ORDER',
        policy_name     => 'POL_LAB_ORDER_UPDATE',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_LAB_ORDER_UPDATE',
        statement_types => 'UPDATE',
        update_check    => TRUE,
        enable          => TRUE,
        policy_type     => DBMS_RLS.DYNAMIC,
        long_predicate  => FALSE
    );
END;
/


-- ============================================================================
-- 9. LAB_RESULT - INSERT / UPDATE FUNCTIONS
-- ============================================================================

-- INSERT - FN_LAB_RESULT_INSERT

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_LAB_RESULT_INSERT
(
    p_schema IN VARCHAR2,
    p_object IN VARCHAR2
)
RETURN VARCHAR2
AS
    v_role VARCHAR2(128);
BEGIN
    IF UPPER(SYS_CONTEXT('USERENV','SESSION_USER')) = 'PROJ_ONE' THEN
        RETURN '1 = 1';
    END IF;

    v_role := UPPER(SYS_CONTEXT('HOSPITAL_CTX','APP_ROLE'));

    IF v_role = 'ROLE_LAB_TECH' THEN
        RETURN 'order_id IN (
            SELECT lo.order_id
            FROM PROJ_ONE.LAB_ORDER lo
            WHERE lo.department_id = TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'',''DEPARTMENT_ID''))
        )';
    ELSE
        RETURN '1 = 0';
    END IF;
END;
/

SHOW ERRORS FUNCTION PROJ_ONE.FN_LAB_RESULT_INSERT

-- Attach FN_LAB_RESULT_INSERT: POL_LAB_RESULT_INSERT
BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'LAB_RESULT',
        policy_name     => 'POL_LAB_RESULT_INSERT',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_LAB_RESULT_INSERT',
        statement_types => 'INSERT',
        update_check    => TRUE,
        enable          => TRUE,
        policy_type     => DBMS_RLS.DYNAMIC,
        long_predicate  => FALSE
    );
END;
/


-- UPDATE - FN_LAB_RESULT_UPDATE

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_LAB_RESULT_UPDATE
(
    p_schema IN VARCHAR2,
    p_object IN VARCHAR2
)
RETURN VARCHAR2
AS
    v_role VARCHAR2(128);
BEGIN
    IF UPPER(SYS_CONTEXT('USERENV','SESSION_USER')) = 'PROJ_ONE' THEN
        RETURN '1 = 1';
    END IF;

    v_role := UPPER(SYS_CONTEXT('HOSPITAL_CTX','APP_ROLE'));

    IF v_role = 'ROLE_LAB_TECH' THEN
        RETURN 'released_flag = ''0'' and order_id IN (
            SELECT lo.order_id
            FROM PROJ_ONE.LAB_ORDER lo
            WHERE lo.department_id = TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'',''DEPARTMENT_ID''))
        )';
    ELSE
        RETURN '1 = 0';
    END IF;
END;
/

SHOW ERRORS FUNCTION PROJ_ONE.FN_LAB_RESULT_UPDATE

-- Attach FN_LAB_RESULT_UPDATE: POL_LAB_RESULT_UPDATE
BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'LAB_RESULT',
        policy_name     => 'POL_LAB_RESULT_UPDATE',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_LAB_RESULT_UPDATE',
        statement_types => 'UPDATE',
        update_check    => TRUE,
        enable          => TRUE,
        policy_type     => DBMS_RLS.DYNAMIC,
        long_predicate  => FALSE
    );
END;
/


