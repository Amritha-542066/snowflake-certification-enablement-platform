/*
===============================================================================
Script: 02_seed_user_identity_demo_data.sql
Project: Snowflake Certification Enablement Platform

Purpose:
Loads the controlled demo personas used to test the Native App home page,
role-based actions, Pod restrictions and negative user scenarios.

Executed by:
native-app/app/setup.sql

Execution order:
Runs after 01_create_user_identity_model.sql.

Demo personas:
- Studio Lead: Anupama Gangadhar
- Thiyagarajan Pod: Amritha
- Durga Pod: Nitheesh
- Kani Pod: Deekshita
- Bhaskaran Pod: Balaji
- Inactive employee: Priya Raman
- Active employee without a Pod: Karthik Iyer
- Pod Lead without active members: Meera Nair
- Unregistered user: Aarav Menon

Important:
Aarav Menon is intentionally not inserted into CORE.EMPLOYEES. This allows the
application to test the unregistered-user experience.

Rerun behaviour:
MERGE statements update existing demo rows or insert them when missing.
They do not create duplicate records.
===============================================================================
*/


/*
-------------------------------------------------------------------------------
Seed the platform roles.

These are business roles used by the application. They are different from
Snowflake account roles such as ACCOUNTADMIN.
-------------------------------------------------------------------------------
*/
MERGE INTO CORE.APP_ROLES AS TARGET
USING
(
    SELECT
        COLUMN1::VARCHAR AS ROLE_CODE,
        COLUMN2::VARCHAR AS ROLE_NAME,
        COLUMN3::VARCHAR AS ROLE_DESCRIPTION,
        COLUMN4::BOOLEAN AS ACTIVE_FLAG
    FROM VALUES
        (
            'STUDIO_LEAD',
            'Studio Lead',
            'Reviews Pod Lead self-nominations and approved fallback requests.',
            TRUE
        ),
        (
            'POD_LEAD',
            'Pod Lead',
            'Nominates active members of their own Pod and approves member self-nominations.',
            TRUE
        ),
        (
            'POD_MEMBER',
            'Pod Member',
            'May request a certification for themselves.',
            TRUE
        )
) AS SOURCE
ON TARGET.ROLE_CODE = SOURCE.ROLE_CODE

WHEN MATCHED THEN
    UPDATE SET
        TARGET.ROLE_NAME = SOURCE.ROLE_NAME,
        TARGET.ROLE_DESCRIPTION = SOURCE.ROLE_DESCRIPTION,
        TARGET.ACTIVE_FLAG = SOURCE.ACTIVE_FLAG

WHEN NOT MATCHED THEN
    INSERT
    (
        ROLE_CODE,
        ROLE_NAME,
        ROLE_DESCRIPTION,
        ACTIVE_FLAG
    )
    VALUES
    (
        SOURCE.ROLE_CODE,
        SOURCE.ROLE_NAME,
        SOURCE.ROLE_DESCRIPTION,
        SOURCE.ACTIVE_FLAG
    );


/*
-------------------------------------------------------------------------------
Seed the employee personas.

SNOWFLAKE_USERNAME is the value matched against st.user.user_name.

AMRITHAK matches the current trial-account login.
The other usernames are controlled demo identifiers for later role testing.
-------------------------------------------------------------------------------
*/
MERGE INTO CORE.EMPLOYEES AS TARGET
USING
(
    SELECT
        COLUMN1::VARCHAR AS EMPLOYEE_ID,
        COLUMN2::VARCHAR AS SNOWFLAKE_USERNAME,
        COLUMN3::VARCHAR AS EMPLOYEE_NAME,
        COLUMN4::VARCHAR AS EMAIL_ADDRESS,
        COLUMN5::VARCHAR AS DESIGNATION,
        COLUMN6::BOOLEAN AS ACTIVE_FLAG
    FROM VALUES
        (
            'EMP001',
            'ANUPAMAG',
            'Anupama Gangadhar',
            'anupama.gangadhar@example.com',
            'Studio Lead',
            TRUE
        ),
        (
            'EMP002',
            'THIYAGARAJAN',
            'Thiyagarajan Chokalingam',
            'thiyagarajan.chokalingam@example.com',
            'Pod Lead',
            TRUE
        ),
        (
            'EMP003',
            'DURGA',
            'Durga',
            'durga@example.com',
            'Pod Lead',
            TRUE
        ),
        (
            'EMP004',
            'KANI',
            'Kani',
            'kani@example.com',
            'Pod Lead',
            TRUE
        ),
        (
            'EMP005',
            'BHASKARAN',
            'Bhaskaran',
            'bhaskaran@example.com',
            'Pod Lead',
            TRUE
        ),
        (
            'EMP006',
            'AMRITHAK',
            'Amritha Kalyanasundaram Ganesh',
            'amritha.kg@example.com',
            'Practitioner',
            TRUE
        ),
        (
            'EMP007',
            'NITHEESH',
            'Nitheesh',
            'nitheesh@example.com',
            'Practitioner',
            TRUE
        ),
        (
            'EMP008',
            'DEEKSHITA',
            'Deekshita',
            'deekshita@example.com',
            'Practitioner',
            TRUE
        ),
        (
            'EMP009',
            'BALAJI',
            'Balaji',
            'balaji@example.com',
            'Practitioner',
            TRUE
        ),
        (
            'EMP010',
            'PRIYARAMAN',
            'Priya Raman',
            'priya.raman@example.com',
            'Practitioner',
            FALSE
        ),
        (
            'EMP011',
            'KARTHIKIYER',
            'Karthik Iyer',
            'karthik.iyer@example.com',
            'Practitioner',
            TRUE
        ),
        (
            'EMP012',
            'MEERANAIR',
            'Meera Nair',
            'meera.nair@example.com',
            'Pod Lead',
            TRUE
        )
) AS SOURCE
ON TARGET.EMPLOYEE_ID = SOURCE.EMPLOYEE_ID

WHEN MATCHED THEN
    UPDATE SET
        TARGET.SNOWFLAKE_USERNAME = SOURCE.SNOWFLAKE_USERNAME,
        TARGET.EMPLOYEE_NAME = SOURCE.EMPLOYEE_NAME,
        TARGET.EMAIL_ADDRESS = SOURCE.EMAIL_ADDRESS,
        TARGET.DESIGNATION = SOURCE.DESIGNATION,
        TARGET.ACTIVE_FLAG = SOURCE.ACTIVE_FLAG,
        TARGET.UPDATED_AT = CURRENT_TIMESTAMP()

WHEN NOT MATCHED THEN
    INSERT
    (
        EMPLOYEE_ID,
        SNOWFLAKE_USERNAME,
        EMPLOYEE_NAME,
        EMAIL_ADDRESS,
        DESIGNATION,
        ACTIVE_FLAG
    )
    VALUES
    (
        SOURCE.EMPLOYEE_ID,
        SOURCE.SNOWFLAKE_USERNAME,
        SOURCE.EMPLOYEE_NAME,
        SOURCE.EMAIL_ADDRESS,
        SOURCE.DESIGNATION,
        SOURCE.ACTIVE_FLAG
    );


/*
-------------------------------------------------------------------------------
Assign each registered employee their platform role.

Priya keeps a role assignment but remains inaccessible because her employee
record is inactive.
-------------------------------------------------------------------------------
*/
MERGE INTO CORE.EMPLOYEE_ROLE_ASSIGNMENTS AS TARGET
USING
(
    SELECT
        COLUMN1::VARCHAR AS EMPLOYEE_ID,
        COLUMN2::VARCHAR AS ROLE_CODE,
        COLUMN3::BOOLEAN AS ACTIVE_FLAG
    FROM VALUES
        ('EMP001', 'STUDIO_LEAD', TRUE),
        ('EMP002', 'POD_LEAD', TRUE),
        ('EMP003', 'POD_LEAD', TRUE),
        ('EMP004', 'POD_LEAD', TRUE),
        ('EMP005', 'POD_LEAD', TRUE),
        ('EMP006', 'POD_MEMBER', TRUE),
        ('EMP007', 'POD_MEMBER', TRUE),
        ('EMP008', 'POD_MEMBER', TRUE),
        ('EMP009', 'POD_MEMBER', TRUE),
        ('EMP010', 'POD_MEMBER', TRUE),
        ('EMP011', 'POD_MEMBER', TRUE),
        ('EMP012', 'POD_LEAD', TRUE)
) AS SOURCE
ON  TARGET.EMPLOYEE_ID = SOURCE.EMPLOYEE_ID
AND TARGET.ROLE_CODE = SOURCE.ROLE_CODE

WHEN MATCHED THEN
    UPDATE SET
        TARGET.ACTIVE_FLAG = SOURCE.ACTIVE_FLAG

WHEN NOT MATCHED THEN
    INSERT
    (
        EMPLOYEE_ID,
        ROLE_CODE,
        ACTIVE_FLAG
    )
    VALUES
    (
        SOURCE.EMPLOYEE_ID,
        SOURCE.ROLE_CODE,
        SOURCE.ACTIVE_FLAG
    );


/*
-------------------------------------------------------------------------------
Seed the Pods and their responsible Pod Leads.

Meera's Pod is created without an active membership row. This supports the
negative test for a Pod Lead who currently has no active members.
-------------------------------------------------------------------------------
*/
MERGE INTO CORE.PODS AS TARGET
USING
(
    SELECT
        COLUMN1::VARCHAR AS POD_ID,
        COLUMN2::VARCHAR AS POD_NAME,
        COLUMN3::VARCHAR AS POD_LEAD_EMPLOYEE_ID,
        COLUMN4::BOOLEAN AS ACTIVE_FLAG
    FROM VALUES
        ('POD001', 'Thiyagarajan Pod', 'EMP002', TRUE),
        ('POD002', 'Durga Pod', 'EMP003', TRUE),
        ('POD003', 'Kani Pod', 'EMP004', TRUE),
        ('POD004', 'Bhaskaran Pod', 'EMP005', TRUE),
        ('POD005', 'Meera Pod', 'EMP012', TRUE)
) AS SOURCE
ON TARGET.POD_ID = SOURCE.POD_ID

WHEN MATCHED THEN
    UPDATE SET
        TARGET.POD_NAME = SOURCE.POD_NAME,
        TARGET.POD_LEAD_EMPLOYEE_ID =
            SOURCE.POD_LEAD_EMPLOYEE_ID,
        TARGET.ACTIVE_FLAG = SOURCE.ACTIVE_FLAG,
        TARGET.UPDATED_AT = CURRENT_TIMESTAMP()

WHEN NOT MATCHED THEN
    INSERT
    (
        POD_ID,
        POD_NAME,
        POD_LEAD_EMPLOYEE_ID,
        ACTIVE_FLAG
    )
    VALUES
    (
        SOURCE.POD_ID,
        SOURCE.POD_NAME,
        SOURCE.POD_LEAD_EMPLOYEE_ID,
        SOURCE.ACTIVE_FLAG
    );


/*
-------------------------------------------------------------------------------
Seed active Pod memberships.

Business mappings:
- Amritha belongs to Thiyagarajan's Pod.
- Nitheesh belongs to Durga's Pod.
- Deekshita belongs to Kani's Pod.
- Balaji belongs to Bhaskaran's Pod.

Priya has an inactive historical membership.
Karthik has no membership.
Meera's Pod has no member.
-------------------------------------------------------------------------------
*/
MERGE INTO CORE.POD_MEMBERSHIPS AS TARGET
USING
(
    SELECT
        COLUMN1::VARCHAR AS POD_ID,
        COLUMN2::VARCHAR AS EMPLOYEE_ID,
        COLUMN3::DATE AS JOINED_DATE,
        COLUMN4::BOOLEAN AS ACTIVE_FLAG
    FROM VALUES
        ('POD001', 'EMP006', DATE '2026-01-01', TRUE),
        ('POD002', 'EMP007', DATE '2026-01-01', TRUE),
        ('POD003', 'EMP008', DATE '2026-01-01', TRUE),
        ('POD004', 'EMP009', DATE '2026-01-01', TRUE),
        ('POD001', 'EMP010', DATE '2026-01-01', FALSE)
) AS SOURCE
ON  TARGET.POD_ID = SOURCE.POD_ID
AND TARGET.EMPLOYEE_ID = SOURCE.EMPLOYEE_ID

WHEN MATCHED THEN
    UPDATE SET
        TARGET.JOINED_DATE = SOURCE.JOINED_DATE,
        TARGET.ACTIVE_FLAG = SOURCE.ACTIVE_FLAG

WHEN NOT MATCHED THEN
    INSERT
    (
        POD_ID,
        EMPLOYEE_ID,
        JOINED_DATE,
        ACTIVE_FLAG
    )
    VALUES
    (
        SOURCE.POD_ID,
        SOURCE.EMPLOYEE_ID,
        SOURCE.JOINED_DATE,
        SOURCE.ACTIVE_FLAG
    );