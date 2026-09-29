/*==============================================================================
  Snowflake Certification Enablement Platform
  Pod Nomination, Dynamic Plan and Reminder Tests

  Purpose:
  - Verify Pod and Pod Lead configuration.
  - Verify Pod Lead nomination.
  - Verify dynamic learning-plan creation.
  - Verify invalid nomination handling and correction.
  - Verify weekly reminder configuration and simulation.

  Note:
  - These are read-only verification queries.
  - They do not insert, update or delete data.
==============================================================================*/


/*------------------------------------------------------------------------------
  Test setup
------------------------------------------------------------------------------*/

USE ROLE ACCOUNTADMIN;

USE WAREHOUSE WH_CERT_ENABLEMENT_DEV_XS;

USE DATABASE DB_CERT_ENABLEMENT_DEV;


/*==============================================================================
  TEST 1: VERIFY STUDY TOPICS
==============================================================================*/

/*
Expected:
- TOTAL_STUDY_TOPICS = 31
*/

SELECT
    COUNT(*) AS TOTAL_STUDY_TOPICS

FROM CORE.STUDY_TOPICS

WHERE ACTIVE_FLAG = TRUE;


/*==============================================================================
  TEST 2: VERIFY POD CONFIGURATION
==============================================================================*/

/*
Expected:
- POD_001 should appear.
- Pod Lead employee ID should be LEAD_DEMO_001.
- ACTIVE_FLAG should be TRUE.
*/

SELECT
    POD_ID,
    POD_NAME,
    POD_LEAD_EMPLOYEE_ID,
    POD_LEAD_NAME,
    POD_LEAD_EMAIL,
    ACTIVE_FLAG

FROM CORE.PODS

WHERE POD_ID = 'POD_001';


/*==============================================================================
  TEST 3: VERIFY CERTIFICATION NOMINATIONS
==============================================================================*/

/*
Expected:
- EMP_DEMO_101 and EMP_DEMO_102 should appear.
- Both nominations should be associated with POD_001.
*/

SELECT *

FROM CORE.CERTIFICATION_NOMINATIONS

WHERE EMPLOYEE_ID IN (
    'EMP_DEMO_101',
    'EMP_DEMO_102'
)

ORDER BY EMPLOYEE_ID;


/*==============================================================================
  TEST 4: VERIFY LEARNER REGISTRATION AND ENROLLMENT
==============================================================================*/

/*
Expected:
- Both employees should be registered.
- PLAN_TYPE should be DYNAMIC.
- Target dates should match the dates provided by the Pod Lead.
*/

SELECT
    L.EMPLOYEE_ID,
    L.LEARNER_NAME,
    L.SNOWFLAKE_EXPERIENCE_YEARS,
    E.POD_ID,
    E.TARGET_COMPLETION_DATE,
    E.TARGET_EXAM_DATE,
    E.PLAN_TYPE,
    E.ENROLLMENT_STATUS

FROM CORE.LEARNERS L

JOIN CORE.ENROLLMENTS E
    ON L.LEARNER_ID = E.LEARNER_ID

WHERE L.EMPLOYEE_ID IN (
    'EMP_DEMO_101',
    'EMP_DEMO_102'
)

ORDER BY L.EMPLOYEE_ID;


/*==============================================================================
  TEST 5: COMPARE THE TWO DYNAMIC LEARNING PLANS
==============================================================================*/

/*
Expected:

EMP_DEMO_101:
- 31 assigned topics
- Approximately 12 weeks
- Plan end date: 2026-12-15

EMP_DEMO_102:
- 31 assigned topics
- Approximately 10 weeks
- Plan end date: 2026-11-30

This proves that the schedule is based on the Pod Lead's target date
and is not selected from a fixed experience-based path.
*/

SELECT
    L.EMPLOYEE_ID,
    L.LEARNER_NAME,
    E.TARGET_COMPLETION_DATE,
    E.TARGET_EXAM_DATE,
    E.PLAN_TYPE,
    COUNT(LTP.TOPIC_ID) AS ASSIGNED_TOPICS,
    MIN(LTP.PLANNED_WEEK) AS FIRST_WEEK,
    MAX(LTP.PLANNED_WEEK) AS LAST_WEEK,
    MIN(LTP.PLANNED_START_DATE) AS PLAN_START_DATE,
    MAX(LTP.PLANNED_END_DATE) AS PLAN_END_DATE

FROM CORE.LEARNERS L

JOIN CORE.ENROLLMENTS E
    ON L.LEARNER_ID = E.LEARNER_ID

JOIN CORE.LEARNER_TOPIC_PLAN LTP
    ON E.ENROLLMENT_ID = LTP.ENROLLMENT_ID

WHERE L.EMPLOYEE_ID IN (
    'EMP_DEMO_101',
    'EMP_DEMO_102'
)

GROUP BY
    L.EMPLOYEE_ID,
    L.LEARNER_NAME,
    E.TARGET_COMPLETION_DATE,
    E.TARGET_EXAM_DATE,
    E.PLAN_TYPE

ORDER BY L.EMPLOYEE_ID;


/*==============================================================================
  TEST 6: VERIFY INVALID POD LEAD REJECTION AND CORRECTION
==============================================================================*/

/*
Test performed:
- NOM_DEMO_002 was first submitted with WRONG_LEAD_999.
- The pipeline rejected the record.
- It was resubmitted with LEAD_DEMO_001.
- The corrected record was accepted.

Expected:
- Rejection reason should mention that the supplied Pod Lead was not authorised.
- RESOLVED_FLAG should be TRUE.
- RESOLVED_AT should contain a timestamp.
*/

SELECT
    PIPELINE_NAME,
    SOURCE_RECORD_ID,
    SOURCE_FILE_NAME,
    REJECTION_REASON,
    RESOLVED_FLAG,
    REJECTED_AT,
    RESOLVED_AT

FROM CONTROL.CSV_REJECTED_RECORDS

WHERE SOURCE_RECORD_ID = 'NOM_DEMO_002'

ORDER BY REJECTED_AT DESC;


/*==============================================================================
  TEST 7: VERIFY NOMINATION PIPELINE RUNS
==============================================================================*/

/*
Expected:
- Successful pipeline runs should appear.
- Records received, accepted and rejected should be recorded.
*/

SELECT
    PIPELINE_NAME,
    RUN_STATUS,
    RECORDS_RECEIVED,
    RECORDS_ACCEPTED,
    RECORDS_REJECTED,
    RUN_MESSAGE,
    STARTED_AT,
    COMPLETED_AT

FROM CONTROL.CSV_PIPELINE_RUN_LOG

WHERE PIPELINE_NAME = 'POD_AND_CERTIFICATION_NOMINATION'

ORDER BY STARTED_AT DESC

LIMIT 10;


/*==============================================================================
  TEST 8: VERIFY WEEKLY REMINDER CONFIGURATION
==============================================================================*/

/*
Expected:
- Reminder configuration should exist.
- SEND_ENABLED should remain FALSE during prototype testing.
- The normal reminder mode should be INACTIVE_ONLY.
*/

SELECT *

FROM CONTROL.REMINDER_CONFIG;


/*==============================================================================
  TEST 9: VERIFY REMINDER CANDIDATES VIEW
==============================================================================*/

/*
Purpose:
Shows learners who are currently eligible for a progress reminder.

The result may be empty when no learner currently satisfies the configured
reminder conditions. That is valid.
*/

SELECT *

FROM ANALYTICS.VW_WEEKLY_REMINDER_CANDIDATES

ORDER BY EMPLOYEE_ID;


/*==============================================================================
  TEST 10: VERIFY SIMULATED REMINDER RESULT
==============================================================================*/

/*
Expected:
- EMP_DEMO_101 should have a SIMULATED reminder record.
- A simulated record proves the reminder workflow without sending a real email.
*/

SELECT
    EMPLOYEE_ID,
    RECIPIENT_EMAIL,
    REMINDER_STATUS,
    FAILURE_MESSAGE,
    REMINDER_SENT_AT

FROM CONTROL.REMINDER_LOG

WHERE EMPLOYEE_ID = 'EMP_DEMO_101'

ORDER BY REMINDER_SENT_AT DESC;


/*==============================================================================
  TEST 11: VERIFY AUTOMATION TASKS
==============================================================================*/

/*
Expected tasks:
- TSK_PROCESS_CERT_NOMINATIONS_1MIN
- TSK_SEND_PROGRESS_REMINDERS_WEEKLY

The reminder task should remain suspended after testing to avoid unnecessary
trial-account usage.
*/

SHOW TASKS IN DATABASE DB_CERT_ENABLEMENT_DEV;


/*==============================================================================
  FINAL TEST SUMMARY

  Expected result:
  1. Naming standards applied.
  2. Pod configuration processed.
  3. Pod Lead nominations processed.
  4. Invalid Pod Lead rejected.
  5. Corrected nomination accepted.
  6. Dynamic plans created with different durations.
  7. All 31 study topics assigned to each learner.
  8. Pipeline executions recorded.
  9. Weekly reminder simulation completed.
  10. Automation tasks created and left suspended after testing.
==============================================================================*/