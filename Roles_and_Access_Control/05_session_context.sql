-- ============================================================================================
-- Create the context and designates the package allowed to populate it
-- ============================================================================================
GRANT CREATE PROCEDURE TO PROJ_ONE;
CREATE OR REPLACE CONTEXT HOSPITAL_CTX
USING PROJ_ONE.HOSPITAL_CTX_PKG;


-- ============================================================================================
-- Creating the Initializer
-- ============================================================================================
CREATE OR REPLACE PACKAGE PROJ_ONE.HOSPITAL_CTX_PKG
AUTHID DEFINER
AS
    PROCEDURE INIT_SESSION;
END HOSPITAL_CTX_PKG;
/

CREATE OR REPLACE PACKAGE BODY PROJ_ONE.HOSPITAL_CTX_PKG
AS
    PROCEDURE INIT_SESSION
    IS
        v_username          VARCHAR2(128);
        v_app_role          VARCHAR2(128);
        v_role_count        PLS_INTEGER := 0;
        v_entity_type       VARCHAR2(7);
        v_entity_id         NUMBER;
        v_patient_id        NUMBER;
        v_staff_id          NUMBER;
        v_doctor_id         NUMBER;
        v_pharmacist_id     NUMBER;
        v_department_id     NUMBER;
        v_doctor_department NUMBER;
        v_is_head           NUMBER := 0;

        PROCEDURE CHECK_ROLE(p_role_name VARCHAR2)
        IS
        BEGIN
            IF DBMS_SESSION.SESSION_IS_ROLE_ENABLED(p_role_name) THEN
                v_role_count := v_role_count + 1;
                v_app_role := p_role_name;
            END IF;
        END CHECK_ROLE;

    BEGIN
        DBMS_SESSION.CLEAR_CONTEXT('HOSPITAL_CTX', NULL, NULL);
        DBMS_SESSION.SET_CONTEXT('HOSPITAL_CTX','INITIALIZING','Y');
        v_username := SYS_CONTEXT('USERENV', 'SESSION_USER');
        CHECK_ROLE('ROLE_PATIENT');
        CHECK_ROLE('ROLE_DOCTOR');
        CHECK_ROLE('ROLE_NURSE');
        CHECK_ROLE('ROLE_LAB_TECH');
        CHECK_ROLE('ROLE_RECEPTIONIST');
        CHECK_ROLE('ROLE_BILLING');
        CHECK_ROLE('ROLE_PHARMACIST');

        IF v_role_count <> 1 THEN
            RAISE_APPLICATION_ERROR(
                -20001,
                'Exactly one supported project role must be enabled.'
            );
        END IF;

        SELECT entity_type, entity_id, department_id
        INTO v_entity_type, v_entity_id, v_department_id
        FROM (
            SELECT
                'PATIENT' AS entity_type,
                patient_id AS entity_id,
                CAST(NULL AS NUMBER) AS department_id
            FROM PROJ_ONE.PATIENT
            WHERE UPPER(TRIM(oracle_username)) = v_username

            UNION ALL

            SELECT
                'STAFF' AS entity_type,
                staff_id AS entity_id,
                department_id
            FROM PROJ_ONE.STAFF
            WHERE UPPER(TRIM(oracle_username)) = v_username
        );

        IF v_app_role = 'ROLE_PATIENT' THEN

            IF v_entity_type <> 'PATIENT' THEN
                RAISE_APPLICATION_ERROR(
                    -20002,
                    'A patient account must map to a PATIENT record.'
                );
            END IF;

            v_patient_id := v_entity_id;

        ELSE
            IF v_entity_type <> 'STAFF' THEN
                RAISE_APPLICATION_ERROR(
                    -20003,
                    'A staff account must map to a STAFF record.'
                );
            END IF;

            v_staff_id := v_entity_id;

            IF v_department_id IS NULL THEN
                RAISE_APPLICATION_ERROR(
                    -20007,
                    'The staff member has no department.'
                );
            END IF;

            IF v_app_role = 'ROLE_DOCTOR' THEN

                SELECT
                    doctor_id,
                    department_id,
                    is_department_head
                INTO
                    v_doctor_id,
                    v_doctor_department,
                    v_is_head
                FROM PROJ_ONE.DOCTOR
                WHERE staff_id = v_staff_id;

                IF v_doctor_department IS NULL
                   OR v_doctor_department <> v_department_id THEN
                    RAISE_APPLICATION_ERROR(
                        -20004,
                        'The doctor and staff departments do not match.'
                    );
                END IF;

                IF v_is_head IS NULL
                   OR v_is_head NOT IN (0, 1) THEN
                    RAISE_APPLICATION_ERROR(
                        -20008,
                        'IS_DEPARTMENT_HEAD must be 0 or 1.'
                    );
                END IF;

            ELSIF v_app_role = 'ROLE_PHARMACIST' THEN

                SELECT pharmacist_id
                INTO v_pharmacist_id
                FROM PROJ_ONE.PHARMACIST
                WHERE staff_id = v_staff_id;

            END IF;
        END IF;

        DBMS_SESSION.SET_CONTEXT(
            'HOSPITAL_CTX', 'PATIENT_ID', TO_CHAR(v_patient_id)
        );

        DBMS_SESSION.SET_CONTEXT(
            'HOSPITAL_CTX', 'STAFF_ID', TO_CHAR(v_staff_id)
        );

        DBMS_SESSION.SET_CONTEXT(
            'HOSPITAL_CTX', 'DOCTOR_ID', TO_CHAR(v_doctor_id)
        );

        DBMS_SESSION.SET_CONTEXT(
            'HOSPITAL_CTX', 'PHARMACIST_ID', TO_CHAR(v_pharmacist_id)
        );

        DBMS_SESSION.SET_CONTEXT(
            'HOSPITAL_CTX', 'DEPARTMENT_ID', TO_CHAR(v_department_id)
        );

        DBMS_SESSION.SET_CONTEXT(
            'HOSPITAL_CTX', 'IS_DEPARTMENT_HEAD', TO_CHAR(v_is_head)
        );

        DBMS_SESSION.SET_CONTEXT(
            'HOSPITAL_CTX', 'APP_ROLE', v_app_role
        );

      DBMS_SESSION.SET_CONTEXT(
        'HOSPITAL_CTX','INITIALIZING','N'
        );

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_SESSION.CLEAR_CONTEXT('HOSPITAL_CTX', NULL, NULL);
            RAISE_APPLICATION_ERROR(
                -20005,
                'Missing patient, staff, doctor or pharmacist mapping.'
            );

        WHEN TOO_MANY_ROWS THEN
            DBMS_SESSION.CLEAR_CONTEXT('HOSPITAL_CTX', NULL, NULL);
            RAISE_APPLICATION_ERROR(
                -20006,
                'Duplicate patient, staff, doctor or pharmacist mapping.'
            );

        WHEN OTHERS THEN
            DBMS_SESSION.CLEAR_CONTEXT('HOSPITAL_CTX', NULL, NULL);
            RAISE;
    END INIT_SESSION;

END HOSPITAL_CTX_PKG;
/


-- ============================================================================================
-- Grant execution permission, allowing user accounts to call "INIT_SESSION"
-- ============================================================================================
GRANT EXECUTE ON PROJ_ONE.HOSPITAL_CTX_PKG TO
ROLE_PATIENT,
ROLE_DOCTOR,
ROLE_NURSE,
ROLE_LAB_TECH,
ROLE_RECEPTIONIST,
ROLE_BILLING,
ROLE_PHARMACIST;


-- ============================================================================================
-- Grant SYSTEM package execution permission (since package was created by PROJ_ONE
-- This allows us to automate the initialization for the user accounts created by SYSTEM
-- ============================================================================================
GRANT EXECUTE ON PROJ_ONE.HOSPITAL_CTX_PKG TO SYSTEM;


-- ============================================================================================
-- Create the trigger to allow for automatic initialization when accounts login
-- ============================================================================================
CREATE OR REPLACE TRIGGER SYSTEM.TRG_HOSPITAL_CTX_LOGON
AFTER LOGON ON DATABASE
DISABLE
DECLARE
    v_username VARCHAR2(128);
BEGIN
    v_username := SYS_CONTEXT('USERENV', 'SESSION_USER');

    IF REGEXP_LIKE(
        v_username,
        '^USER_(PATIENT|DOCTOR|NURSE|LAB_TECH|RECEPTIONIST|BILLING|PHARMACIST)[1-9][0-9]*$',
        'c'
    ) THEN
        PROJ_ONE.HOSPITAL_CTX_PKG.INIT_SESSION;
    END IF;
END;
/
ALTER TRIGGER SYSTEM.TRG_HOSPITAL_CTX_LOGON ENABLE;


-- ============================================================================================
-- Checking the Session Context Attributes
-- ============================================================================================
SELECT
SYS_CONTEXT('USERENV', 'SESSION_USER') AS LOGIN_USER,
SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE') AS APP_ROLE,
SYS_CONTEXT('HOSPITAL_CTX', 'PATIENT_ID') AS PATIENT_ID,
SYS_CONTEXT('HOSPITAL_CTX', 'STAFF_ID') AS STAFF_ID,
SYS_CONTEXT('HOSPITAL_CTX', 'DOCTOR_ID') AS DOCTOR_ID,
SYS_CONTEXT('HOSPITAL_CTX', 'PHARMACIST_ID') AS PHARMACIST_ID,
SYS_CONTEXT('HOSPITAL_CTX', 'DEPARTMENT_ID') AS DEPARTMENT_ID,
SYS_CONTEXT('HOSPITAL_CTX', 'IS_DEPARTMENT_HEAD') AS IS_DEPARTMENT_HEAD
FROM DUAL;

