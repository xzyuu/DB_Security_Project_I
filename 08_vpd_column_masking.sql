-- ============================================================================
-- Column-Level VPD Masking Policies
-- ============================================================================


-- ============================================================================
-- 1. MEDICAL_RECORD - CLINICAL_NOTES
-- ============================================================================

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_MEDICAL_NOTES_MASK
(
    p_schema IN VARCHAR2,
    p_object IN VARCHAR2
)
RETURN VARCHAR2
AS
BEGIN
    IF UPPER(SYS_CONTEXT('USERENV', 'SESSION_USER')) = 'PROJ_ONE' THEN
        RETURN '1=1';
    END IF;

    IF UPPER(SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE')) = 'ROLE_DOCTOR' THEN
        RETURN '1=1';
    END IF;

    RETURN '1=0';
END;
/

BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema         => 'PROJ_ONE',
        object_name           => 'MEDICAL_RECORD',
        policy_name           => 'POL_MEDICAL_NOTES_MASK',
        function_schema       => 'PROJ_ONE',
        policy_function       => 'FN_MEDICAL_NOTES_MASK',
        statement_types       => 'SELECT',
        sec_relevant_cols     => 'CLINICAL_NOTES',
        sec_relevant_cols_opt => DBMS_RLS.ALL_ROWS
    );
END;
/


-- ============================================================================
-- 2. LAB_RESULT - RESULT_VALUE
-- ============================================================================

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_LAB_RESULT_MASK
(
    p_schema IN VARCHAR2,
    p_object IN VARCHAR2
)
RETURN VARCHAR2
AS
    v_role VARCHAR2(128);
BEGIN
    IF UPPER(SYS_CONTEXT('USERENV', 'SESSION_USER')) = 'PROJ_ONE' THEN
        RETURN '1=1';
    END IF;

    v_role := UPPER(SYS_CONTEXT('HOSPITAL_CTX', 'APP_ROLE'));

    IF v_role IN ('ROLE_DOCTOR', 'ROLE_LAB_TECH', 'ROLE_PATIENT') THEN
        RETURN '1=1';
    ELSIF v_role = 'ROLE_NURSE' THEN
        RETURN 'released_flag = ''1''';
    ELSE
        RETURN '1=0';
    END IF;
END;
/

BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema         => 'PROJ_ONE',
        object_name           => 'LAB_RESULT',
        policy_name           => 'POL_LAB_RESULT_MASK',
        function_schema       => 'PROJ_ONE',
        policy_function       => 'FN_LAB_RESULT_MASK',
        statement_types       => 'SELECT',
        sec_relevant_cols     => 'RESULT_VALUE',
        sec_relevant_cols_opt => DBMS_RLS.ALL_ROWS
    );
END;
/


-- ============================================================================
-- 3. STAFF - ORACLE_USERNAME
-- ============================================================================

CREATE OR REPLACE FUNCTION PROJ_ONE.FN_STAFF_USERNAME_MASK
(
    p_schema IN VARCHAR2,
    p_object IN VARCHAR2
)
RETURN VARCHAR2
AS
BEGIN
    IF UPPER(SYS_CONTEXT('USERENV', 'SESSION_USER')) = 'PROJ_ONE'
       OR SYS_CONTEXT('HOSPITAL_CTX', 'INITIALIZING') = 'Y' THEN
        RETURN '1=1';
    END IF;

    RETURN q'[
        STAFF_ID = TO_NUMBER(SYS_CONTEXT('HOSPITAL_CTX', 'STAFF_ID'))
    ]';
END;
/

BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema         => 'PROJ_ONE',
        object_name           => 'STAFF',
        policy_name           => 'POL_STAFF_USERNAME_MASK',
        function_schema       => 'PROJ_ONE',
        policy_function       => 'FN_STAFF_USERNAME_MASK',
        statement_types       => 'SELECT',
        sec_relevant_cols     => 'ORACLE_USERNAME',
        sec_relevant_cols_opt => DBMS_RLS.ALL_ROWS
    );
END;
/
