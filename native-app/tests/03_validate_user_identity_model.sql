/*
===============================================================================
Worksheet: 03_Validate_User_Identity_Model.sql
Project: Snowflake Certification Enablement Platform

Purpose:
Validates the physical user-identity model after the Native App has been
upgraded.

Execution order:
Run after:
1. 01_Create_User_Identity_Model.sql
2. 02_Seed_User_Identity_Demo_Data.sql

Required role:
CERT_ENABLEMENT_APP_DEVELOPER

Required warehouse:
WH_CERT_ENABLEMENT_DEV_XS

Expected result:
All summary and negative-scenario checks should return PASS.

Important:
This script does not create, update or delete data. It only reads and validates
the objects created inside CERT_ENABLEMENT_NATIVE_APP.
===============================================================================
*/


-- Use the development role that has been granted the APP_USER application role.
USE ROLE CERT_ENABLEMENT_APP_DEVELOPER;


-- Use the development warehouse for validation queries.
USE WAREHOUSE WH_CERT_ENABLEMENT_DEV_XS;


/*
-------------------------------------------------------------------------------
Validation 1: Confirm the expected number of foundational records.

Expected:
12 employees
3 platform roles
5 Pods
4 active Pod memberships
-------------------------------------------------------------------------------
*/
SELECT
    'Employee count' AS TEST_NAME,
    IFF(COUNT(*) = 12, 'PASS', 'FAIL') AS TEST_STATUS,
    COUNT(*) AS ACTUAL_VALUE,
    12 AS EXPECTED_VALUE
FROM CERT_ENABLEMENT_NATIVE_APP.CORE.EMPLOYEES

UNION ALL

SELECT
    'Platform role count',
    IFF(COUNT(*) = 3, 'PASS', 'FAIL'),
    COUNT(*),
    3
FROM CERT_ENABLEMENT_NATIVE_APP.CORE.APP_ROLES

UNION ALL

SELECT
    'Pod count',
    IFF(COUNT(*) = 5, 'PASS', 'FAIL'),
    COUNT(*),
    5
FROM CERT_ENABLEMENT_NATIVE_APP.CORE.PODS

UNION ALL

SELECT
    'Active Pod membership count',
    IFF(COUNT(*) = 4, 'PASS', 'FAIL'),
    COUNT(*),
    4
FROM CERT_ENABLEMENT_NATIVE_APP.CORE.POD_MEMBERSHIPS
WHERE ACTIVE_FLAG = TRUE

ORDER BY TEST_NAME;


/*
-------------------------------------------------------------------------------
Validation 2: Confirm Amritha's complete identity context.

Expected:
Employee name: Amritha Kalyanasundaram Ganesh
Role: POD_MEMBER
Pod: Thiyagarajan Pod
Pod Lead: Thiyagarajan Chokalingam
-------------------------------------------------------------------------------
*/
SELECT
    SNOWFLAKE_USERNAME,
    EMPLOYEE_NAME,
    DESIGNATION,
    ROLE_CODE,
    ROLE_NAME,
    POD_ID,
    POD_NAME,
    POD_LEAD_EMPLOYEE_ID,
    POD_LEAD_NAME,
    EMPLOYEE_ACTIVE_FLAG
FROM CERT_ENABLEMENT_NATIVE_APP.APP_SCHEMA.VW_USER_CONTEXT
WHERE UPPER(SNOWFLAKE_USERNAME) = 'AMRITHAK';


/*
-------------------------------------------------------------------------------
Validation 3: Confirm the own-Pod nomination restriction.

This query asks:
Which active Pod members is Bhaskaran allowed to nominate?

Expected:
Only Balaji should be returned.
-------------------------------------------------------------------------------
*/
SELECT
    POD_LEAD.EMPLOYEE_NAME AS POD_LEAD_NAME,
    POD.POD_NAME,
    MEMBER.EMPLOYEE_ID AS ELIGIBLE_MEMBER_ID,
    MEMBER.EMPLOYEE_NAME AS ELIGIBLE_MEMBER_NAME
FROM CERT_ENABLEMENT_NATIVE_APP.CORE.PODS POD

INNER JOIN CERT_ENABLEMENT_NATIVE_APP.CORE.EMPLOYEES POD_LEAD
    ON POD.POD_LEAD_EMPLOYEE_ID = POD_LEAD.EMPLOYEE_ID

INNER JOIN CERT_ENABLEMENT_NATIVE_APP.CORE.POD_MEMBERSHIPS MEMBERSHIP
    ON POD.POD_ID = MEMBERSHIP.POD_ID
   AND MEMBERSHIP.ACTIVE_FLAG = TRUE

INNER JOIN CERT_ENABLEMENT_NATIVE_APP.CORE.EMPLOYEES MEMBER
    ON MEMBERSHIP.EMPLOYEE_ID = MEMBER.EMPLOYEE_ID
   AND MEMBER.ACTIVE_FLAG = TRUE

WHERE UPPER(POD_LEAD.SNOWFLAKE_USERNAME) = 'BHASKARAN'
  AND POD.ACTIVE_FLAG = TRUE

ORDER BY MEMBER.EMPLOYEE_NAME;


/*
-------------------------------------------------------------------------------
Validation 4: Confirm the negative test personas.

Expected:
- Aarav Menon is not registered.
- Priya Raman is inactive.
- Karthik Iyer has no active Pod membership.
- Meera Nair leads a Pod with no active members.
-------------------------------------------------------------------------------
*/
SELECT
    'Unregistered user - Aarav Menon' AS TEST_NAME,
    IFF(COUNT(*) = 0, 'PASS', 'FAIL') AS TEST_STATUS
FROM CERT_ENABLEMENT_NATIVE_APP.CORE.EMPLOYEES
WHERE UPPER(SNOWFLAKE_USERNAME) = 'AARAVMENON'

UNION ALL

SELECT
    'Inactive employee - Priya Raman',
    IFF(
        COUNT_IF(ACTIVE_FLAG = FALSE) = 1,
        'PASS',
        'FAIL'
    )
FROM CERT_ENABLEMENT_NATIVE_APP.CORE.EMPLOYEES
WHERE UPPER(SNOWFLAKE_USERNAME) = 'PRIYARAMAN'

UNION ALL

SELECT
    'Employee without Pod - Karthik Iyer',
    IFF(
        (
            SELECT COUNT(*)
            FROM CERT_ENABLEMENT_NATIVE_APP.CORE.POD_MEMBERSHIPS PM
            INNER JOIN CERT_ENABLEMENT_NATIVE_APP.CORE.EMPLOYEES E
                ON PM.EMPLOYEE_ID = E.EMPLOYEE_ID
            WHERE UPPER(E.SNOWFLAKE_USERNAME) = 'KARTHIKIYER'
              AND PM.ACTIVE_FLAG = TRUE
        ) = 0,
        'PASS',
        'FAIL'
    )

UNION ALL

SELECT
    'Pod Lead without active members - Meera Nair',
    IFF(
        (
            SELECT COUNT(*)
            FROM CERT_ENABLEMENT_NATIVE_APP.CORE.PODS P
            INNER JOIN CERT_ENABLEMENT_NATIVE_APP.CORE.EMPLOYEES LEAD
                ON P.POD_LEAD_EMPLOYEE_ID = LEAD.EMPLOYEE_ID
            INNER JOIN CERT_ENABLEMENT_NATIVE_APP.CORE.POD_MEMBERSHIPS PM
                ON P.POD_ID = PM.POD_ID
               AND PM.ACTIVE_FLAG = TRUE
            WHERE UPPER(LEAD.SNOWFLAKE_USERNAME) = 'MEERANAIR'
              AND P.ACTIVE_FLAG = TRUE
        ) = 0,
        'PASS',
        'FAIL'
    )

ORDER BY TEST_NAME;