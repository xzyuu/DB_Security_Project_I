-- ==========================================
-- Created Roles using user SYSTEM
-- ==========================================
CREATE ROLE ROLE_PATIENT;
CREATE ROLE ROLE_DOCTOR;
CREATE ROLE ROLE_NURSE;
CREATE ROLE ROLE_LAB_TECH;
CREATE ROLE ROLE_RECEPTIONIST;
CREATE ROLE ROLE_BILLING;
CREATE ROLE ROLE_PHARMACIST;


-- ===================================================
-- Created Accounts using user SYSTEM
-- Assign Roles to account using user SYSTEM
--  GRANT session creation using user SYSTEM
-- ===================================================

-- ==============================
-- ROLE_PATIENT (15 accounts)
-- ==============================
BEGIN
 FOR i IN 1..15 LOOP

 EXECUTE IMMEDIATE
 'CREATE USER USER_PATIENT' || i ||
 ' IDENTIFIED BY "USERPATIENT' || i || '"';

 EXECUTE IMMEDIATE
 'GRANT CREATE SESSION TO USER_PATIENT' || i;

 EXECUTE IMMEDIATE
 'GRANT ROLE_PATIENT TO USER_PATIENT' || i;

 EXECUTE IMMEDIATE
 'ALTER USER USER_PATIENT' || i ||
 ' DEFAULT ROLE ROLE_PATIENT';

 END LOOP;
 END;
 /

-- ==============================
-- ROLE_DOCTOR (6 accounts)
-- ==============================
BEGIN
    FOR i IN 1..6 LOOP

        EXECUTE IMMEDIATE
            'CREATE USER USER_DOCTOR' || i ||
            ' IDENTIFIED BY "USERDOCTOR' || i || '"';

        EXECUTE IMMEDIATE
            'GRANT CREATE SESSION TO USER_DOCTOR' || i;

        EXECUTE IMMEDIATE
            'GRANT ROLE_DOCTOR TO USER_DOCTOR' || i;

        EXECUTE IMMEDIATE
            'ALTER USER USER_DOCTOR' || i ||
            ' DEFAULT ROLE ROLE_DOCTOR';

    END LOOP;
END;
/

-- ==============================
-- ROLE_NURSE (6 accounts)
-- ==============================
BEGIN
    FOR i IN 1..6 LOOP

        EXECUTE IMMEDIATE
            'CREATE USER USER_NURSE' || i ||
            ' IDENTIFIED BY "USERNURSE' || i || '"';

        EXECUTE IMMEDIATE
            'GRANT CREATE SESSION TO USER_NURSE' || i;

        EXECUTE IMMEDIATE
            'GRANT ROLE_NURSE TO USER_NURSE' || i;

        EXECUTE IMMEDIATE
            'ALTER USER USER_NURSE' || i ||
            ' DEFAULT ROLE ROLE_NURSE';

    END LOOP;
END;
/

-- ==============================
-- ROLE_LAB_TECH (4 accounts)
-- ==============================
BEGIN
    FOR i IN 1..4 LOOP

        EXECUTE IMMEDIATE
            'CREATE USER USER_LAB_TECH' || i ||
            ' IDENTIFIED BY "USERLABTECH' || i || '"';

        EXECUTE IMMEDIATE
            'GRANT CREATE SESSION TO USER_LAB_TECH' || i;

        EXECUTE IMMEDIATE
            'GRANT ROLE_LAB_TECH TO USER_LAB_TECH' || i;

        EXECUTE IMMEDIATE
            'ALTER USER USER_LAB_TECH' || i ||
            ' DEFAULT ROLE ROLE_LAB_TECH';

    END LOOP;
END;
/

-- ==============================
-- ROLE_RECEPTIONIST (2 accounts)
-- ==============================
BEGIN
    FOR i IN 1..2 LOOP

        EXECUTE IMMEDIATE
            'CREATE USER USER_RECEPTIONIST' || i ||
            ' IDENTIFIED BY "USERRECEPTIONIST' || i || '"';

        EXECUTE IMMEDIATE
            'GRANT CREATE SESSION TO USER_RECEPTIONIST' || i;

        EXECUTE IMMEDIATE
            'GRANT ROLE_RECEPTIONIST TO USER_RECEPTIONIST' || i;

        EXECUTE IMMEDIATE
            'ALTER USER USER_RECEPTIONIST' || i ||
            ' DEFAULT ROLE ROLE_RECEPTIONIST';

    END LOOP;
END;
/

-- ==============================
-- ROLE_BILLING (2 accounts)
-- ==============================
BEGIN
    FOR i IN 1..2 LOOP

        EXECUTE IMMEDIATE
            'CREATE USER USER_BILLING' || i ||
            ' IDENTIFIED BY "USERBILLING' || i || '"';

        EXECUTE IMMEDIATE
            'GRANT CREATE SESSION TO USER_BILLING' || i;

        EXECUTE IMMEDIATE
            'GRANT ROLE_BILLING TO USER_BILLING' || i;

        EXECUTE IMMEDIATE
            'ALTER USER USER_BILLING' || i ||
            ' DEFAULT ROLE ROLE_BILLING';

    END LOOP;
END;
/

-- ==============================
-- ROLE_PHARMACIST (2 accounts)
-- ==============================
BEGIN
    FOR i IN 1..2 LOOP

        EXECUTE IMMEDIATE
            'CREATE USER USER_PHARMACIST' || i ||
            ' IDENTIFIED BY "USERPHARMACIST' || i || '"';

        EXECUTE IMMEDIATE
            'GRANT CREATE SESSION TO USER_PHARMACIST' || i;

        EXECUTE IMMEDIATE
            'GRANT ROLE_PHARMACIST TO USER_PHARMACIST' || i;

        EXECUTE IMMEDIATE
            'ALTER USER USER_PHARMACIST' || i ||
            ' DEFAULT ROLE ROLE_PHARMACIST';

    END LOOP;
END;
/


-- ==========================================
-- Check table level privilege
-- ==========================================
SELECT grantee, table_name, LISTAGG(privilege, ', ')
WITHIN GROUP (ORDER BY privilege) AS privileges
FROM user_tab_privs_made
WHERE grantee LIKE 'ROLE_%'
GROUP BY grantee, table_name
ORDER BY grantee, table_name;


-- ==========================================
-- Check column level privilege
-- ==========================================
SELECT grantee, table_name, column_name, privilege, grantable
FROM user_col_privs_made
WHERE grantee LIKE 'ROLE_%'
ORDER BY grantee, table_name, column_name, privilege;

