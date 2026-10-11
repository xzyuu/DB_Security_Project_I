-- ============================================================================
-- 1. PATIENT - POL_PATIENT_SELECT
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_patient_access
(
    v_schema IN VARCHAR2,
    v_obj    IN VARCHAR2
)
RETURN VARCHAR2
AS
    condition VARCHAR2(4000);

    v_assigned VARCHAR2(1000) :=
        'SELECT ca.patient_id
         FROM PROJ_ONE.CARE_ASSIGNMENT ca
         WHERE ca.doctor_id = SYS_CONTEXT(''HOSPITAL_CTX'', ''DOCTOR_ID'')
           AND UPPER(ca.status) = ''ACTIVE''
           AND ca.start_date <= SYSDATE
           AND (ca.end_date IS NULL OR ca.end_date >= SYSDATE)';

    v_dept VARCHAR2(1000) :=
        'SELECT a.patient_id
         FROM PROJ_ONE.ADMISSION a,
              PROJ_ONE.ROOM r,
              PROJ_ONE.WARD w
         WHERE r.room_id = a.room_id
           AND w.ward_id = r.ward_id
           AND w.department_id = SYS_CONTEXT(''HOSPITAL_CTX'', ''DEPARTMENT_ID'')
           AND UPPER(a.status) = ''ADMITTED''
           AND a.admit_date <= SYSDATE
           AND (a.discharge_date IS NULL OR a.discharge_date >= SYSDATE)';

    v_ward VARCHAR2(1000) :=
        'SELECT a.patient_id
         FROM PROJ_ONE.ADMISSION a,
              PROJ_ONE.ROOM r,
              PROJ_ONE.NURSE_WARD_ASSIGNMENT nwa
         WHERE r.room_id = a.room_id
           AND nwa.ward_id = r.ward_id
           AND nwa.nurse_id = SYS_CONTEXT(''HOSPITAL_CTX'', ''STAFF_ID'')
           AND UPPER(a.status) = ''ADMITTED''
           AND nwa.start_date <= SYSDATE
           AND (nwa.end_date IS NULL OR nwa.end_date >= SYSDATE)';

BEGIN
    IF (
        SYS_CONTEXT('HOSPITAL_CTX', 'INITIALIZING') = 'Y'
        OR SYS_CONTEXT('USERENV', 'SESSION_USER') = 'PROJ_ONE'
        OR SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_RECEPTIONIST'
    ) THEN
        condition := '';

    ELSIF SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_PATIENT' THEN
        condition :=
            'patient_id = SYS_CONTEXT(''HOSPITAL_CTX'', ''PATIENT_ID'')';

    ELSIF (
        SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_DOCTOR'
        AND SYS_CONTEXT('HOSPITAL_CTX', 'IS_DEPARTMENT_HEAD') = '1'
    ) THEN
        condition :=
            'patient_id IN (' || v_assigned || ')
             OR patient_id IN (' || v_dept || ')';

    ELSIF SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_DOCTOR' THEN
        condition :=
            'patient_id IN (' || v_assigned || ')';

    ELSIF SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_NURSE' THEN
        condition :=
            'patient_id IN (' || v_ward || ')';

    ELSIF SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_LAB_TECH' THEN
        condition :=
            'patient_id IN (
                SELECT lo.patient_id
                FROM PROJ_ONE.LAB_ORDER lo
                WHERE lo.department_id =
                    SYS_CONTEXT(''HOSPITAL_CTX'', ''DEPARTMENT_ID'')
            )';

    ELSIF SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_BILLING' THEN
        condition :=
            'patient_id IN (
                SELECT b.patient_id
                FROM PROJ_ONE.BILL b
            )';

    ELSIF SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_PHARMACIST' THEN
        condition :=
            'patient_id IN (
                SELECT p.patient_id
                FROM PROJ_ONE.PRESCRIPTION p
                WHERE p.status = ''Pending''
            )';

    ELSE
        condition := '1 = 0';
    END IF;

    RETURN condition;
END fn_patient_access;
/

BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'PATIENT',
        policy_name     => 'POL_PATIENT_SELECT',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_PATIENT_ACCESS',
        statement_types => 'SELECT',
        policy_type     => DBMS_RLS.DYNAMIC
    );
END;
/

-- ============================================================================
-- 2. BILL - POL_BILL_READ_OWN_OR_BILLING
-- ============================================================================

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_BILL_ACCESS
(
    p_schema IN VARCHAR2,
    p_object IN VARCHAR2
)
RETURN VARCHAR2
AS
    v_role VARCHAR2(128) :=
        UPPER(SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE'));
BEGIN
    IF UPPER(SYS_CONTEXT('USERENV', 'SESSION_USER')) = 'PROJ_ONE' THEN
        RETURN '1=1';
    END IF;

    CASE v_role
        WHEN 'ROLE_PATIENT' THEN
            RETURN q'[patient_id = TO_NUMBER(SYS_CONTEXT('HOSPITAL_CTX','PATIENT_ID'))]';

        WHEN 'ROLE_BILLING' THEN
            RETURN '1=1';

        ELSE
            RETURN '1=0';
    END CASE;
END;
/

BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'BILL',
        policy_name     => 'POL_BILL_READ_OWN_OR_BILLING',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_BILL_ACCESS',
        statement_types => 'SELECT',
        policy_type     => DBMS_RLS.DYNAMIC
    );
END;
/

-- ============================================================================
-- 3. APPOINTMENT - POL_APPT_READ_OWN_OR_RECEPTION
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_appointment_access
(
    v_schema IN VARCHAR2,
    v_obj    IN VARCHAR2
)
RETURN VARCHAR2
AS
    condition VARCHAR2(200);
BEGIN
    IF (SYS_CONTEXT('USERENV', 'SESSION_USER') = 'PROJ_ONE')
       OR (SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_RECEPTIONIST') THEN
        condition := '';

    ELSIF (SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_PATIENT') THEN
        condition := 'patient_id = SYS_CONTEXT(''HOSPITAL_CTX'', ''PATIENT_ID'')';

    ELSIF (SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_DOCTOR') THEN
        condition := 'doctor_id = SYS_CONTEXT( ''HOSPITAL_CTX'', ''DOCTOR_ID'')';

    ELSIF (SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_BILLING') THEN
        condition := 'status = ''Completed''';

    ELSE
        condition := '1 = 0';
    END IF;

    RETURN condition;
END fn_appointment_access;
/

BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'APPOINTMENT',
        policy_name     => 'POL_APPT_READ_OWN_OR_RECEPTION',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_APPOINTMENT_ACCESS',
        statement_types => 'SELECT',
        policy_type     => DBMS_RLS.DYNAMIC
    );
END;
/

-- ============================================================================
-- 4. PRESCRIPTION - POL_PRESCRIPTION_SELECT
-- ============================================================================

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_PRESCRIPTION_ACCESS
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

    -- Patient: own prescriptions.
    IF v_role = 'ROLE_PATIENT' THEN
        RETURN '
            patient_id =
                TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'', ''PATIENT_ID''))';

    -- Doctor: prescriptions created by this doctor.
    ELSIF v_role = 'ROLE_DOCTOR' THEN
        RETURN '
            doctor_id =
                TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'', ''DOCTOR_ID''))';

    -- Nurse: Pending prescriptions for patients admitted
    -- to a ward currently assigned to this nurse.
    ELSIF v_role = 'ROLE_NURSE' THEN
        RETURN '
            UPPER(status) IN (''PENDING'', ''DISPENSED'')
            AND patient_id IN
            (
                SELECT a.patient_id
                FROM PROJ_ONE.ADMISSION a
                JOIN PROJ_ONE.ROOM r
                    ON r.room_id = a.room_id
                JOIN PROJ_ONE.NURSE_WARD_ASSIGNMENT nwa
                    ON nwa.ward_id = r.ward_id
                WHERE nwa.nurse_id =
                    TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'', ''STAFF_ID''))
                  AND UPPER(a.status) = ''ADMITTED''
                  AND nwa.start_date <= SYSDATE
                  AND (nwa.end_date IS NULL OR nwa.end_date >= SYSDATE)
            )';

    -- Pharmacist: all Pending prescriptions.
    ELSIF v_role = 'ROLE_PHARMACIST' THEN
        RETURN 'UPPER(status) = ''PENDING''';

    -- Missing or unauthorized role: no rows.
    ELSE
        RETURN '1 = 0';
    END IF;
END;
/

BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'PRESCRIPTION',
        policy_name     => 'POL_PRESCRIPTION_SELECT',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_PRESCRIPTION_ACCESS',
        statement_types => 'SELECT',
        policy_type     => DBMS_RLS.DYNAMIC
    );
END;
/

-- ============================================================================
-- 5. DISPENSING - POL_DISPENSING_SELECT
-- ============================================================================

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_DISPENSING_ACCESS
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

    -- Patient: dispensing linked to own prescriptions.
    IF v_role = 'ROLE_PATIENT' THEN
        RETURN '
            prescription_id IN
            (
                SELECT pr.prescription_id
                FROM PROJ_ONE.PRESCRIPTION pr
                WHERE pr.patient_id =
                    TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'', ''PATIENT_ID''))
            )';

    -- Nurse: dispensing linked to prescriptions for patients
    -- currently admitted to an assigned ward.
    ELSIF v_role = 'ROLE_NURSE' THEN
        RETURN '
            prescription_id IN
            (
                SELECT pr.prescription_id
                FROM PROJ_ONE.PRESCRIPTION pr
                WHERE pr.patient_id IN
                (
                    SELECT a.patient_id
                    FROM PROJ_ONE.ADMISSION a
                    JOIN PROJ_ONE.ROOM r
                        ON r.room_id = a.room_id
                    JOIN PROJ_ONE.NURSE_WARD_ASSIGNMENT nwa
                        ON nwa.ward_id = r.ward_id
                    WHERE nwa.nurse_id =
                        TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'', ''STAFF_ID''))
                      AND UPPER(a.status) = ''ADMITTED''
                      AND nwa.start_date <= SYSDATE
                      AND (nwa.end_date IS NULL OR nwa.end_date >= SYSDATE)
                )
            )';

    -- Pharmacist: own dispensing records.
    ELSIF v_role = 'ROLE_PHARMACIST' THEN
        RETURN '
            pharmacist_id =
                TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'', ''PHARMACIST_ID''))';

    -- Other or missing roles: no rows.
    ELSE
        RETURN '1 = 0';
    END IF;
END;
/

BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'DISPENSING',
        policy_name     => 'POL_DISPENSING_SELECT',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_DISPENSING_ACCESS',
        statement_types => 'SELECT',
        policy_type     => DBMS_RLS.DYNAMIC
    );
END;
/

-- ============================================================================
-- 6. ADMISSION - POL_ADMISSION_SELECT
-- ============================================================================

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_ADMISSION_SELECT
(
    v_schema IN VARCHAR2,
    v_obj    IN VARCHAR2
)
RETURN VARCHAR2
AS
    condition VARCHAR2(4000);

    v_current VARCHAR2(1000) :=
        'status = ''Admitted''
         AND admit_date <= SYSDATE
         AND (discharge_date IS NULL OR discharge_date >= SYSDATE)';

    v_assigned VARCHAR2(1000) :=
        'SELECT ca.patient_id
         FROM PROJ_ONE.CARE_ASSIGNMENT ca
         WHERE ca.doctor_id = SYS_CONTEXT(''HOSPITAL_CTX'', ''DOCTOR_ID'')
           AND UPPER(ca.status) = ''ACTIVE''
           AND ca.start_date <= SYSDATE
           AND (ca.end_date IS NULL OR ca.end_date >= SYSDATE)';

    v_dept_rooms VARCHAR2(1000) :=
        'SELECT r.room_id
         FROM PROJ_ONE.ROOM r,
              PROJ_ONE.WARD w
         WHERE w.ward_id = r.ward_id
           AND w.department_id = SYS_CONTEXT(''HOSPITAL_CTX'', ''DEPARTMENT_ID'')';

    v_my_rooms VARCHAR2(1000) :=
        'SELECT r.room_id
         FROM PROJ_ONE.ROOM r,
              PROJ_ONE.NURSE_WARD_ASSIGNMENT nwa
         WHERE nwa.ward_id = r.ward_id
           AND nwa.nurse_id = SYS_CONTEXT(''HOSPITAL_CTX'', ''STAFF_ID'')
           AND nwa.start_date <= SYSDATE
           AND (nwa.end_date IS NULL OR nwa.end_date >= SYSDATE)';

BEGIN
    IF (SYS_CONTEXT('USERENV', 'SESSION_USER') = 'PROJ_ONE')
       OR (SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') IN
           ('ROLE_RECEPTIONIST', 'ROLE_BILLING')) THEN
        condition := '';

    ELSIF (SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_PATIENT') THEN
        condition :=
            'patient_id = SYS_CONTEXT(''HOSPITAL_CTX'', ''PATIENT_ID'')';

    ELSIF (
        SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_DOCTOR'
        AND SYS_CONTEXT('HOSPITAL_CTX', 'IS_DEPARTMENT_HEAD') = '1'
    ) THEN
        condition :=
            '(' || v_current || ' ) AND
             (patient_id IN (' || v_assigned || ')
              OR room_id IN (' || v_dept_rooms || '))';

    ELSIF (SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_DOCTOR') THEN
        condition :=
            '( ' || v_current || ')
             AND patient_id IN (' || v_assigned || ')';

    ELSIF (SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_NURSE') THEN
        condition :=
            '(' || v_current || ')
             AND room_id IN (' || v_my_rooms || ')';

    ELSE
        condition := '1 = 0';
    END IF;

    RETURN condition;
END fn_admission_select;
/

BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'ADMISSION',
        policy_name     => 'POL_ADMISSION_SELECT',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_ADMISSION_SELECT',
        statement_types => 'SELECT',
        policy_type     => DBMS_RLS.DYNAMIC
    );
END;
/


-- ============================================================================
-- 7. MEDICAL_RECORD - POL_MEDICAL_RECORD_SELECT
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_medical_record_access
(
    v_schema IN VARCHAR2,
    v_obj    IN VARCHAR2
)
RETURN VARCHAR2
AS
    condition VARCHAR2(4000);

    v_assigned VARCHAR2(1000) :=
        'SELECT ca.patient_id
         FROM PROJ_ONE.CARE_ASSIGNMENT ca
         WHERE ca.doctor_id = SYS_CONTEXT(''HOSPITAL_CTX'', ''DOCTOR_ID'')
           AND UPPER(ca.status) = ''ACTIVE''
           AND ca.start_date <= SYSDATE
           AND (ca.end_date IS NULL OR ca.end_date >= SYSDATE)';

    v_dept VARCHAR2(1000) :=
        'SELECT a.patient_id
         FROM PROJ_ONE.ADMISSION a,
              PROJ_ONE.ROOM r,
              PROJ_ONE.WARD w
         WHERE r.room_id = a.room_id
           AND w.ward_id = r.ward_id
           AND w.department_id = SYS_CONTEXT(''HOSPITAL_CTX'', ''DEPARTMENT_ID'')
           AND UPPER(a.status) = ''ADMITTED''
           AND a.admit_date <= SYSDATE
           AND (a.discharge_date IS NULL OR a.discharge_date >= SYSDATE)';

    v_ward VARCHAR2(1000) :=
        'SELECT a.patient_id
         FROM PROJ_ONE.ADMISSION a,
              PROJ_ONE.ROOM r,
              PROJ_ONE.NURSE_WARD_ASSIGNMENT nwa
         WHERE r.room_id = a.room_id
           AND nwa.ward_id = r.ward_id
           AND nwa.nurse_id = SYS_CONTEXT(''HOSPITAL_CTX'', ''STAFF_ID'')
           AND UPPER(a.status) = ''ADMITTED''
           AND nwa.start_date <= SYSDATE
           AND (nwa.end_date IS NULL OR nwa.end_date >= SYSDATE)';

BEGIN
    IF (SYS_CONTEXT('USERENV', 'SESSION_USER') = 'PROJ_ONE') THEN
        condition := '';

    ELSIF (SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_PATIENT') THEN
        condition :=
            'patient_id = SYS_CONTEXT(''HOSPITAL_CTX'', ''PATIENT_ID'')';

    ELSIF (
        SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_DOCTOR'
        AND SYS_CONTEXT('HOSPITAL_CTX', 'IS_DEPARTMENT_HEAD') = '1'
    ) THEN
        condition :=
            'patient_id IN (' || v_assigned || ')
             OR patient_id IN (' || v_dept || ')';

    ELSIF (SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_DOCTOR') THEN
        condition :=
            'patient_id IN (' || v_assigned || ')';

    ELSIF (SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') = 'ROLE_NURSE') THEN
        condition :=
            'patient_id IN (' || v_ward || ')';

    ELSE
        condition := '1 = 0';
    END IF;

    RETURN condition;
END fn_medical_record_access;
/

BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'MEDICAL_RECORD',
        policy_name     => 'POL_MEDICAL_RECORD_SELECT',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_MEDICAL_RECORD_ACCESS',
        statement_types => 'SELECT',
        policy_type     => DBMS_RLS.DYNAMIC
    );
END;
/

-- ============================================================================
-- 8. LAB_ORDER - POL_LAB_ORDER_SELECT
-- ============================================================================

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_LAB_ORDER_ACCESS
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

    /*
     * No select privilege on LAB_ORDER.
     */
    IF v_role = 'ROLE_PATIENT' THEN
        RETURN 'patient_id = TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'',''PATIENT_ID''))';

    ELSIF v_role = 'ROLE_DOCTOR' THEN
        RETURN q'[
            doctor_id = TO_NUMBER(
                SYS_CONTEXT('HOSPITAL_CTX','DOCTOR_ID')
            )
            OR (
                SYS_CONTEXT('HOSPITAL_CTX','IS_DEPARTMENT_HEAD') = '1'
                AND patient_id IN (
                    SELECT a.patient_id
                    FROM PROJ_ONE.ADMISSION a
                    JOIN PROJ_ONE.ROOM r
                        ON r.room_id = a.room_id
                    JOIN PROJ_ONE.WARD w
                        ON w.ward_id = r.ward_id
                    WHERE w.department_id = TO_NUMBER(
                        SYS_CONTEXT('HOSPITAL_CTX','DEPARTMENT_ID')
                    )
                    AND UPPER(a.status) = 'ADMITTED'
                    AND a.admit_date <= SYSDATE
                    AND (
                        a.discharge_date IS NULL
                        OR a.discharge_date >= SYSDATE
                    )
                )
            )
        ]';

    ELSIF v_role = 'ROLE_NURSE' THEN
        RETURN 'patient_id IN (
            SELECT a.patient_id
            FROM PROJ_ONE.ADMISSION a
            JOIN PROJ_ONE.ROOM r
                ON r.room_id = a.room_id
            JOIN PROJ_ONE.NURSE_WARD_ASSIGNMENT nwa
                ON nwa.ward_id = r.ward_id
            WHERE nwa.nurse_id =
                TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'',''STAFF_ID''))
              AND UPPER(a.status) = ''ADMITTED''
              AND nwa.start_date <= SYSDATE
              AND (nwa.end_date IS NULL OR nwa.end_date >= SYSDATE)
        )';

    ELSIF v_role = 'ROLE_LAB_TECH' THEN
        RETURN 'department_id = TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'',''DEPARTMENT_ID''))';

    ELSE
        RETURN '1 = 0';
    END IF;
END;
/

BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'LAB_ORDER',
        policy_name     => 'POL_LAB_ORDER_SELECT',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_LAB_ORDER_ACCESS',
        statement_types => 'SELECT',
        policy_type     => DBMS_RLS.DYNAMIC
    );
END;
/

-- ============================================================================
-- 9. LAB_RESULT - POL_LAB_RESULT_SELECT
-- ============================================================================

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_LAB_RESULT_ACCESS
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

    IF v_role = 'ROLE_PATIENT' THEN
        RETURN 'released_flag = ''1''
            AND order_id IN (
                SELECT lo.order_id
                FROM PROJ_ONE.LAB_ORDER lo
                WHERE lo.patient_id =
                    TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'', ''PATIENT_ID''))
            )';

    ELSIF v_role = 'ROLE_DOCTOR' THEN
        RETURN 'released_flag = ''1'' AND order_id IN (
            SELECT lo.order_id
            FROM PROJ_ONE.LAB_ORDER lo
            WHERE lo.doctor_id =
                TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'', ''DOCTOR_ID''))
               OR (
                   SYS_CONTEXT(''HOSPITAL_CTX'', ''IS_DEPARTMENT_HEAD'') = ''1''
                   AND lo.patient_id IN (
                       SELECT a.patient_id
                       FROM PROJ_ONE.ADMISSION a
                       JOIN PROJ_ONE.ROOM r
                           ON r.room_id = a.room_id
                       JOIN PROJ_ONE.WARD w
                           ON w.ward_id = r.ward_id
                       WHERE w.department_id =
                           TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'', ''DEPARTMENT_ID''))
                         AND UPPER(a.status) = ''ADMITTED''
                         AND a.admit_date <= SYSDATE
                         AND (
                             a.discharge_date IS NULL
                             OR a.discharge_date >= SYSDATE
                         )
                   )
               )
        )';

    ELSIF v_role = 'ROLE_NURSE' THEN
        RETURN 'released_flag = ''1'' AND order_id IN (
            SELECT lo.order_id
            FROM PROJ_ONE.LAB_ORDER lo
            WHERE lo.patient_id IN (
                SELECT a.patient_id
                FROM PROJ_ONE.ADMISSION a
                JOIN PROJ_ONE.ROOM r
                    ON r.room_id = a.room_id
                JOIN PROJ_ONE.NURSE_WARD_ASSIGNMENT nwa
                    ON nwa.ward_id = r.ward_id
                WHERE nwa.nurse_id =
                    TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'', ''STAFF_ID''))
                  AND UPPER(a.status) = ''ADMITTED''
                  AND nwa.start_date <= SYSDATE
                  AND (
                      nwa.end_date IS NULL
                      OR nwa.end_date >= SYSDATE
                  )
            )
        )';

    ELSIF v_role = 'ROLE_LAB_TECH' THEN
        RETURN 'order_id IN (
            SELECT lo.order_id
            FROM PROJ_ONE.LAB_ORDER lo
            WHERE lo.department_id =
                TO_NUMBER(SYS_CONTEXT(''HOSPITAL_CTX'', ''DEPARTMENT_ID''))
        )';

    ELSE
        RETURN '1 = 0';
    END IF;
END;
/

BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'LAB_RESULT',
        policy_name     => 'POL_LAB_RESULT_SELECT',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_LAB_RESULT_ACCESS',
        statement_types => 'SELECT',
        policy_type     => DBMS_RLS.DYNAMIC
    );
END;
/

-- ============================================================================
-- 10. STAFF - POL_STAFF_ACCESS
-- ============================================================================

CREATE OR REPLACE FUNCTION FN_STAFF_ACCESS
(
    p_schema IN VARCHAR2,
    p_object IN VARCHAR2
)
RETURN VARCHAR2
AUTHID DEFINER
AS
    v_role VARCHAR2(128);
BEGIN
    IF UPPER(SYS_CONTEXT('USERENV', 'SESSION_USER')) = 'PROJ_ONE' THEN
        RETURN '1=1';
    END IF;

    IF SYS_CONTEXT('HOSPITAL_CTX', 'INITIALIZING') = 'Y' THEN
        RETURN '1=1';
    END IF;

    v_role := UPPER(SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE'));

    IF v_role = 'ROLE_RECEPTIONIST' THEN
        RETURN q'[
            (
                (
                    STAFF_ID = TO_NUMBER(SYS_CONTEXT('HOSPITAL_CTX', 'STAFF_ID'))
                    AND ORACLE_USERNAME = SYS_CONTEXT('USERENV', 'SESSION_USER')
                )
                OR STAFF_ID IN (
                    SELECT d.STAFF_ID
                    FROM PROJ_ONE.DOCTOR d
                )
            )
        ]';
    END IF;

    IF v_role IN (
        'ROLE_DOCTOR',
        'ROLE_NURSE',
        'ROLE_LAB_TECH',
        'ROLE_RECEPTIONIST',
        'ROLE_BILLING',
        'ROLE_PHARMACIST'
    ) THEN
        RETURN q'[
            STAFF_ID = TO_NUMBER(SYS_CONTEXT('HOSPITAL_CTX', 'STAFF_ID'))
            AND ORACLE_USERNAME = SYS_CONTEXT('USERENV', 'SESSION_USER')
        ]';
    END IF;

    RETURN '1=0';
END;
/

BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'PROJ_ONE',
        object_name     => 'STAFF',
        policy_name     => 'POL_STAFF_ACCESS',
        function_schema => 'PROJ_ONE',
        policy_function => 'FN_STAFF_ACCESS',
        statement_types => 'SELECT',
        policy_type     => DBMS_RLS.DYNAMIC
    );
END;
/