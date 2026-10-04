/*==============================================================================
  Snowflake Certification Enablement Platform
  Pod Nomination, Dynamic Plan and Reminder Tests

  Purpose:
  - Validate the unified Pod Lead nomination workflow.
  - Validate internally generated identifiers.
  - Validate dynamic learner schedules.
  - Validate incremental updates without duplicate records or lost progress.
  - Validate learner and Pod Lead reminder simulation.

  Note:
  - These verification queries do not send real emails.
  - The weekly reminder Task should remain suspended after testing.
==============================================================================*/


USE ROLE ACCOUNTADMIN;

USE WAREHOUSE WH_CERT_ENABLEMENT_DEV_XS;

USE DATABASE DB_CERT_ENABLEMENT_DEV;


/*==============================================================================
  TEST 1: APPROVED POD AND POD LEAD CONFIGURATION

  Expected:
  - Snowflake Data Engineering Pod exists.
  - Durga Rajaneesh Maturu is stored as the active Pod Lead.
==============================================================================*/

SELECT
    POD_ID,
    POD_NAME,
    POD_LEAD_EMPLOYEE_ID,
    POD_LEAD_NAME,
    POD_LEAD_EMAIL,
    ACTIVE_FLAG,

    IFF(
        POD_NAME = 'Snowflake Data Engineering'
        AND POD_LEAD_NAME = 'Durga Rajaneesh Maturu'
        AND ACTIVE_FLAG = TRUE,
        'PASS',
        'FAIL'
    ) AS TEST_STATUS

FROM CORE.PODS

WHERE POD_NAME = 'Snowflake Data Engineering';


/*==============================================================================
  TEST 2: LATEST UNIFIED NOMINATION PIPELINE RUN

  Expected latest successful test result:
  - Two records received.
  - Two records accepted.
  - Zero records rejected.
==============================================================================*/

SELECT
    PIPELINE_NAME,
    RUN_STATUS,
    RECORDS_RECEIVED,
    RECORDS_ACCEPTED,
    RECORDS_REJECTED,
    RUN_MESSAGE,
    STARTED_AT,
    COMPLETED_AT,

    IFF(
        RUN_STATUS = 'SUCCESS'
        AND RECORDS_RECEIVED = RECORDS_ACCEPTED
        AND RECORDS_REJECTED = 0,
        'PASS',
        'FAIL'
    ) AS TEST_STATUS

FROM CONTROL.CSV_PIPELINE_RUN_LOG

WHERE PIPELINE_NAME = 'CERTIFICATION_NOMINATION'

QUALIFY ROW_NUMBER() OVER (
    ORDER BY STARTED_AT DESC
) = 1;


/*==============================================================================
  TEST 3: DYNAMIC LEARNER PLANS

  Expected:
  - Each learner has 31 assigned topics.
  - PLAN_TYPE is DYNAMIC.
  - Plan start matches the enrollment date.
  - Plan end matches the Pod Lead's target completion date.
==============================================================================*/

SELECT
    L.EMPLOYEE_ID,
    L.LEARNER_NAME,
    P.POD_NAME,
    P.POD_LEAD_NAME,
    C.CERTIFICATION_NAME,
    E.ENROLLED_DATE,
    E.TARGET_COMPLETION_DATE,
    E.TARGET_EXAM_DATE,
    E.PLAN_TYPE,
    COUNT(LTP.TOPIC_ID) AS ASSIGNED_TOPICS,
    MIN(LTP.PLANNED_WEEK_NUMBER) AS FIRST_WEEK,
    MAX(LTP.PLANNED_WEEK_NUMBER) AS LAST_WEEK,
    MIN(LTP.PLANNED_START_DATE) AS PLAN_START_DATE,
    MAX(LTP.PLANNED_END_DATE) AS PLAN_END_DATE,

    IFF(
        E.PLAN_TYPE = 'DYNAMIC'
        AND COUNT(LTP.TOPIC_ID) = 31
        AND MIN(LTP.PLANNED_START_DATE) = E.ENROLLED_DATE
        AND MAX(LTP.PLANNED_END_DATE) = E.TARGET_COMPLETION_DATE,
        'PASS',
        'FAIL'
    ) AS TEST_STATUS

FROM CORE.LEARNERS L

JOIN CORE.ENROLLMENTS E
    ON L.LEARNER_ID = E.LEARNER_ID

JOIN CORE.PODS P
    ON E.POD_ID = P.POD_ID

JOIN CORE.CERTIFICATIONS C
    ON E.CERTIFICATION_ID = C.CERTIFICATION_ID

JOIN CORE.LEARNER_TOPIC_PLAN LTP
    ON E.ENROLLMENT_ID = LTP.ENROLLMENT_ID

WHERE L.EMPLOYEE_ID IN (
    'EMP_DEMO_101',
    'EMP_DEMO_102',
    'EMP_TEST_103'
)

GROUP BY
    L.EMPLOYEE_ID,
    L.LEARNER_NAME,
    P.POD_NAME,
    P.POD_LEAD_NAME,
    C.CERTIFICATION_NAME,
    E.ENROLLED_DATE,
    E.TARGET_COMPLETION_DATE,
    E.TARGET_EXAM_DATE,
    E.PLAN_TYPE

ORDER BY L.EMPLOYEE_ID;


/*==============================================================================
  TEST 4A: NO DUPLICATE LEARNER RECORDS

  Expected:
  - One learner record for each company employee ID.
==============================================================================*/

SELECT
    EMPLOYEE_ID,
    COUNT(*) AS LEARNER_RECORDS,

    IFF(
        COUNT(*) = 1,
        'PASS',
        'FAIL'
    ) AS TEST_STATUS

FROM CORE.LEARNERS

WHERE EMPLOYEE_ID IN (
    'EMP_DEMO_101',
    'EMP_DEMO_102',
    'EMP_TEST_103'
)

GROUP BY EMPLOYEE_ID

ORDER BY EMPLOYEE_ID;


/*==============================================================================
  TEST 4B: NO DUPLICATE ENROLLMENTS

  Expected:
  - One enrollment per employee and certification.
==============================================================================*/

SELECT
    L.EMPLOYEE_ID,
    E.CERTIFICATION_ID,
    COUNT(*) AS ENROLLMENT_RECORDS,

    IFF(
        COUNT(*) = 1,
        'PASS',
        'FAIL'
    ) AS TEST_STATUS

FROM CORE.LEARNERS L

JOIN CORE.ENROLLMENTS E
    ON L.LEARNER_ID = E.LEARNER_ID

WHERE L.EMPLOYEE_ID IN (
    'EMP_DEMO_101',
    'EMP_DEMO_102',
    'EMP_TEST_103'
)

GROUP BY
    L.EMPLOYEE_ID,
    E.CERTIFICATION_ID

ORDER BY L.EMPLOYEE_ID;


/*==============================================================================
  TEST 5: INTERNAL IDENTIFIERS

  Expected:
  - Technical identifiers are present in CORE.
  - Users do not need to supply these identifiers in the nomination CSV.
==============================================================================*/

SELECT
    L.EMPLOYEE_ID,
    L.LEARNER_ID,
    E.NOMINATION_ID,
    E.ENROLLMENT_ID,
    E.POD_ID,
    E.CERTIFICATION_ID,

    IFF(
        L.LEARNER_ID LIKE 'LRN_%'
        AND E.NOMINATION_ID LIKE 'NOM_%'
        AND E.ENROLLMENT_ID LIKE 'ENR_%'
        AND E.POD_ID IS NOT NULL
        AND E.CERTIFICATION_ID IS NOT NULL,
        'PASS',
        'FAIL'
    ) AS TEST_STATUS

FROM CORE.LEARNERS L

JOIN CORE.ENROLLMENTS E
    ON L.LEARNER_ID = E.LEARNER_ID

WHERE L.EMPLOYEE_ID IN (
    'EMP_DEMO_101',
    'EMP_DEMO_102',
    'EMP_TEST_103'
)

ORDER BY L.EMPLOYEE_ID;


/*==============================================================================
  TEST 6: AUTOMATIC EXAM DATE

  Expected:
  - Target exam date is seven days after target completion date.
==============================================================================*/

SELECT
    L.EMPLOYEE_ID,
    E.TARGET_COMPLETION_DATE,
    E.TARGET_EXAM_DATE,
    DATEDIFF(
        'DAY',
        E.TARGET_COMPLETION_DATE,
        E.TARGET_EXAM_DATE
    ) AS DAYS_BETWEEN_COMPLETION_AND_EXAM,

    IFF(
        DATEDIFF(
            'DAY',
            E.TARGET_COMPLETION_DATE,
            E.TARGET_EXAM_DATE
        ) = 7,
        'PASS',
        'FAIL'
    ) AS TEST_STATUS

FROM CORE.LEARNERS L

JOIN CORE.ENROLLMENTS E
    ON L.LEARNER_ID = E.LEARNER_ID

WHERE L.EMPLOYEE_ID IN (
    'EMP_DEMO_101',
    'EMP_DEMO_102',
    'EMP_TEST_103'
)

ORDER BY L.EMPLOYEE_ID;


/*==============================================================================
  TEST 7: INCREMENTAL UPDATE AND PROGRESS PRESERVATION

  Test learner:
  - EMP_TEST_103

  Expected:
  - Original enrollment and plan start date remain 30 September 2026.
  - Updated completion date is 29 December 2026.
  - All 31 topics remain assigned.
  - D01_T01 remains IN_PROGRESS at 25 percent and 0.50 hours.
==============================================================================*/

WITH TARGET AS (
    SELECT
        L.EMPLOYEE_ID,
        E.ENROLLMENT_ID,
        E.ENROLLED_DATE,
        E.TARGET_COMPLETION_DATE,
        E.TARGET_EXAM_DATE

    FROM CORE.LEARNERS L

    JOIN CORE.ENROLLMENTS E
        ON L.LEARNER_ID = E.LEARNER_ID

    WHERE L.EMPLOYEE_ID = 'EMP_TEST_103'
),

PLAN AS (
    SELECT
        ENROLLMENT_ID,
        COUNT(*) AS ASSIGNED_TOPICS,
        MIN(PLANNED_START_DATE) AS PLAN_START_DATE,
        MAX(PLANNED_END_DATE) AS PLAN_END_DATE

    FROM CORE.LEARNER_TOPIC_PLAN

    GROUP BY ENROLLMENT_ID
)

SELECT
    T.EMPLOYEE_ID,
    T.ENROLLED_DATE,
    T.TARGET_COMPLETION_DATE,
    T.TARGET_EXAM_DATE,
    P.ASSIGNED_TOPICS,
    P.PLAN_START_DATE,
    P.PLAN_END_DATE,
    TP.PROGRESS_STATUS,
    TP.COMPLETION_PERCENT,
    TP.HOURS_SPENT,

    IFF(
        T.ENROLLED_DATE = '2026-09-30'::DATE
        AND T.TARGET_COMPLETION_DATE = '2026-12-29'::DATE
        AND T.TARGET_EXAM_DATE = '2027-01-05'::DATE
        AND P.ASSIGNED_TOPICS = 31
        AND P.PLAN_START_DATE = T.ENROLLED_DATE
        AND P.PLAN_END_DATE = T.TARGET_COMPLETION_DATE
        AND TP.PROGRESS_STATUS = 'IN_PROGRESS'
        AND TP.COMPLETION_PERCENT = 25
        AND TP.HOURS_SPENT = 0.50,
        'PASS',
        'FAIL'
    ) AS TEST_STATUS

FROM TARGET T

JOIN PLAN P
    ON T.ENROLLMENT_ID = P.ENROLLMENT_ID

JOIN CORE.TOPIC_PROGRESS TP
    ON T.ENROLLMENT_ID = TP.ENROLLMENT_ID
   AND TP.TOPIC_ID = 'D01_T01';


/*==============================================================================
  TEST 8: SAFE WEEKLY REMINDER CONFIGURATION

  Expected:
  - Normal reminder mode is INACTIVE_ONLY.
  - Inactivity threshold is seven days.
  - Live sending remains disabled.
==============================================================================*/

SELECT
    CONFIG_ID,
    REMINDER_MODE,
    INACTIVITY_DAYS,
    EMAIL_INTEGRATION_NAME,
    SEND_ENABLED,
    ACTIVE_FLAG,

    IFF(
        REMINDER_MODE = 'INACTIVE_ONLY'
        AND INACTIVITY_DAYS = 7
        AND SEND_ENABLED = FALSE
        AND ACTIVE_FLAG = TRUE,
        'PASS',
        'FAIL'
    ) AS TEST_STATUS

FROM CONTROL.REMINDER_CONFIGURATION

WHERE CONFIG_ID = 'WEEKLY_PROGRESS_REMINDER';


/*==============================================================================
  TEST 9: LEARNER AND POD LEAD REMINDER SIMULATION

  Expected:
  - Both LEARNER and POD_LEAD recipient types were simulated.
  - No real email was sent during this test.
==============================================================================*/

SELECT
    EMPLOYEE_ID,
    COUNT(DISTINCT RECIPIENT_TYPE) AS RECIPIENT_TYPES_TESTED,
    LISTAGG(
        DISTINCT RECIPIENT_TYPE,
        ', '
    ) WITHIN GROUP (
        ORDER BY RECIPIENT_TYPE
    ) AS RECIPIENT_TYPES,
    MAX(REMINDER_SENT_AT) AS LATEST_SIMULATION_AT,

    IFF(
        COUNT(DISTINCT RECIPIENT_TYPE) = 2
        AND COUNT_IF(REMINDER_STATUS = 'FAILED') = 0,
        'PASS',
        'FAIL'
    ) AS TEST_STATUS

FROM CONTROL.REMINDER_NOTIFICATION_LOG

WHERE EMPLOYEE_ID IN (
    'EMP_DEMO_101',
    'EMP_DEMO_102'
)
  AND RECIPIENT_TYPE IN (
      'LEARNER',
      'POD_LEAD'
  )
  AND REMINDER_STATUS = 'SIMULATED'

GROUP BY EMPLOYEE_ID

ORDER BY EMPLOYEE_ID;


/*==============================================================================
  TEST 10: REMINDER AUDIT DETAILS

  Expected:
  - Learner and Pod Lead rows have names, emails and SIMULATED status.
  - FAILURE_MESSAGE is empty.
==============================================================================*/

SELECT
    EMPLOYEE_ID,
    RECIPIENT_TYPE,
    RECIPIENT_NAME,
    RECIPIENT_EMAIL,
    REMINDER_STATUS,
    FAILURE_MESSAGE,
    REMINDER_SENT_AT,

    IFF(
        RECIPIENT_NAME IS NOT NULL
        AND RECIPIENT_EMAIL IS NOT NULL
        AND REMINDER_STATUS = 'SIMULATED'
        AND FAILURE_MESSAGE IS NULL,
        'PASS',
        'FAIL'
    ) AS TEST_STATUS

FROM CONTROL.REMINDER_NOTIFICATION_LOG

WHERE EMPLOYEE_ID IN (
    'EMP_DEMO_101',
    'EMP_DEMO_102'
)
  AND RECIPIENT_TYPE IN (
      'LEARNER',
      'POD_LEAD'
  )

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY
        EMPLOYEE_ID,
        RECIPIENT_TYPE
    ORDER BY REMINDER_SENT_AT DESC
) = 1

ORDER BY
    EMPLOYEE_ID,
    RECIPIENT_TYPE;


/*==============================================================================
  TEST 11: AUTOMATION TASK STATUS

  Expected:
  - Both Tasks exist.
  - The reminder Task remains suspended after testing.
==============================================================================*/

SHOW TASKS LIKE
    'TSK_PROCESS_CERT_NOMINATIONS_1MIN'
IN SCHEMA DB_CERT_ENABLEMENT_DEV.CONTROL;

SHOW TASKS LIKE
    'TSK_SEND_PROGRESS_REMINDERS_WEEKLY'
IN SCHEMA DB_CERT_ENABLEMENT_DEV.CONTROL;


/*==============================================================================
  EXPECTED FINAL RESULT

  1. Approved Pod and Pod Lead configuration: PASS
  2. Unified nomination pipeline: PASS
  3. Dynamic 31-topic learning plans: PASS
  4. Duplicate prevention: PASS
  5. Internal identifier generation: PASS
  6. Automatic target exam date: PASS
  7. Incremental update and progress preservation: PASS
  8. Safe reminder configuration: PASS
  9. Learner and Pod Lead reminder simulation: PASS
  10. Reminder audit details: PASS
  11. Automation Tasks created and reminder Task suspended: PASS
==============================================================================*/
