-- =========================================================
-- Create role-based audit policy
-- =========================================================
CREATE AUDIT POLICY HOSPITAL_ROLE_AUDIT ACTIONS ALL ONLY TOPLEVEL;


-- =========================================================
-- Enable audit policy for Roles
-- =========================================================
AUDIT POLICY HOSPITAL_ROLE_AUDIT
BY USERS WITH GRANTED ROLES ROLE_PATIENT, ROLE_DOCTOR, ROLE_NURSE, ROLE_LAB_TECH, ROLE_RECEPTIONIST, ROLE_BILLING, ROLE_PHARMACIST;


-- =========================================================
-- Add more user context to the audit policy’s logging
-- =========================================================
AUDIT CONTEXT NAMESPACE HOSPITAL_CTX ATTRIBUTES APP_ROLE, PATIENT_ID, STAFF_ID, DOCTOR_ID, PHARMACIST_ID, DEPARTMENT_ID, IS_DEPARTMENT_HEAD;


-- =========================================================
-- Create user-based audit policy
-- =========================================================
CREATE AUDIT POLICY HOSPITAL_OWNER_AUDIT ACTIONS ALL ONLY TOPLEVEL;


-- =========================================================
-- Enable audit policy for user PROJ_ONE
-- =========================================================
AUDIT POLICY HOSPITAL_OWNER_AUDIT BY PROJ_ONE;


-- =========================================================
-- Check for active policy
-- =========================================================
SELECT POLICY_NAME, ENABLED_OPTION, ENTITY_NAME, ENTITY_TYPE, SUCCESS, FAILURE
FROM AUDIT_UNIFIED_ENABLED_POLICIES
WHERE POLICY_NAME = 'HOSPITAL_ROLE_AUDIT';

SELECT POLICY_NAME, ENABLED_OPTION, ENTITY_NAME, ENTITY_TYPE, SUCCESS, FAILURE
FROM AUDIT_UNIFIED_ENABLED_POLICIES
WHERE POLICY_NAME = 'HOSPITAL_OWNER_AUDIT';


-- =========================================================
-- View the audit logs
-- =========================================================
SELECT EVENT_TIMESTAMP, DBUSERNAME, ACTION_NAME, OBJECT_SCHEMA, OBJECT_NAME,
       CASE WHEN RETURN_CODE = 0 THEN 'SUCCESS' ELSE 'FAILED' END AS RESULT,
       RETURN_CODE, SQL_TEXT, APPLICATION_CONTEXTS, UNIFIED_AUDIT_POLICIES
FROM UNIFIED_AUDIT_TRAIL
WHERE (
    INSTR(UNIFIED_AUDIT_POLICIES, 'HOSPITAL_ROLE_AUDIT') > 0
    OR INSTR(UNIFIED_AUDIT_POLICIES, 'HOSPITAL_OWNER_AUDIT') > 0
)
AND OBJECT_NAME <> 'ALL_IDENTIFIERS'
AND OBJECT_NAME <> 'DUAL'
AND OBJECT_NAME <> 'CLOUD'
AND OBJECT_NAME NOT LIKE '%$%'
AND OBJECT_NAME NOT LIKE 'USER!_%' ESCAPE '!'
AND OBJECT_NAME NOT LIKE 'DBMS!_%' ESCAPE '!'
AND OBJECT_NAME NOT LIKE 'DBA!_%' ESCAPE '!'
AND OBJECT_NAME NOT LIKE 'ALL!_%' ESCAPE '!'
AND OBJECT_NAME NOT LIKE 'NLS!_%' ESCAPE '!'
AND OBJECT_NAME NOT LIKE 'DATABASE!_%' ESCAPE '!'
AND OBJECT_NAME IS NOT NULL
AND UPPER(DBUSERNAME) NOT LIKE '%SYSTEM%'
ORDER BY EVENT_TIMESTAMP DESC;




