/*==============================================================================
  Snowflake Certification Enablement Platform
  Step 19: Platform data-quality tests

  Expected result:
  Every test should return PASS.
==============================================================================*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SNOWPRO_LEARNING_WH;
USE DATABASE SNOWPRO_ENABLEMENT;


/*------------------------------------------------------------------------------
  Run all platform data-quality checks
------------------------------------------------------------------------------*/

WITH TEST_RESULTS AS (

    /* Test 1: Domain weights must total 100 percent */

    SELECT
        '01_DOMAIN_WEIGHTS_TOTAL' AS TEST_NAME,

        CASE
            WHEN SUM(EXAM_WEIGHT_PERCENT) = 100
                THEN 'PASS'
            ELSE 'FAIL'
        END AS TEST_STATUS,

        TO_VARCHAR(
            SUM(EXAM_WEIGHT_PERCENT)
        ) AS ACTUAL_VALUE,

        '100' AS EXPECTED_VALUE

    FROM CORE.EXAM_DOMAINS

    WHERE ACTIVE_FLAG = TRUE


    UNION ALL


    /* Test 2: Four active learning paths must exist */

    SELECT
        '02_ACTIVE_LEARNING_PATH_COUNT',

        CASE
            WHEN COUNT(*) = 4
                THEN 'PASS'
            ELSE 'FAIL'
        END,

        TO_VARCHAR(COUNT(*)),

        '4'

    FROM CORE.LEARNING_PATHS

    WHERE ACTIVE_FLAG = TRUE
      AND CERTIFICATION_ID = 'CERT_SNOWPRO_CORE'


    UNION ALL


    /* Test 3: Every path must contain every active topic */

    SELECT
        '03_PATH_TOPIC_COMPLETENESS',

        CASE
            WHEN COUNT(*) = 0
                THEN 'PASS'
            ELSE 'FAIL'
        END,

        TO_VARCHAR(COUNT(*)),

        '0 incomplete paths'

    FROM (
        SELECT
            LP.PATH_ID

        FROM CORE.LEARNING_PATHS LP

        LEFT JOIN CORE.PATH_TOPIC_PLAN PTP
            ON LP.PATH_ID = PTP.PATH_ID

        WHERE LP.ACTIVE_FLAG = TRUE
          AND LP.CERTIFICATION_ID = 'CERT_SNOWPRO_CORE'

        GROUP BY
            LP.PATH_ID

        HAVING COUNT(PTP.TOPIC_ID) <> (
            SELECT COUNT(*)
            FROM CORE.STUDY_TOPICS
            WHERE ACTIVE_FLAG = TRUE
        )
    )


    UNION ALL


    /* Test 4: Planned weeks must be inside the path duration */

    SELECT
        '04_VALID_PLANNED_WEEKS',

        CASE
            WHEN COUNT(*) = 0
                THEN 'PASS'
            ELSE 'FAIL'
        END,

        TO_VARCHAR(COUNT(*)),

        '0 invalid schedule rows'

    FROM CORE.PATH_TOPIC_PLAN PTP

    JOIN CORE.LEARNING_PATHS LP
        ON PTP.PATH_ID = LP.PATH_ID

    WHERE PTP.PLANNED_WEEK < 1
       OR PTP.PLANNED_WEEK > LP.DURATION_WEEKS


    UNION ALL


    /* Test 5: Progress values must be valid */

    SELECT
        '05_VALID_PROGRESS_VALUES',

        CASE
            WHEN COUNT(*) = 0
                THEN 'PASS'
            ELSE 'FAIL'
        END,

        TO_VARCHAR(COUNT(*)),

        '0 invalid progress rows'

    FROM CORE.TOPIC_PROGRESS

    WHERE COMPLETION_PERCENT < 0
       OR COMPLETION_PERCENT > 100
       OR HOURS_SPENT < 0


    UNION ALL


    /* Test 6: Topic-progress records must reference valid data */

    SELECT
        '06_NO_ORPHAN_TOPIC_PROGRESS',

        CASE
            WHEN COUNT(*) = 0
                THEN 'PASS'
            ELSE 'FAIL'
        END,

        TO_VARCHAR(COUNT(*)),

        '0 orphan rows'

    FROM CORE.TOPIC_PROGRESS TP

    LEFT JOIN CORE.ENROLLMENTS E
        ON TP.ENROLLMENT_ID = E.ENROLLMENT_ID

    LEFT JOIN CORE.STUDY_TOPICS ST
        ON TP.TOPIC_ID = ST.TOPIC_ID

    WHERE E.ENROLLMENT_ID IS NULL
       OR ST.TOPIC_ID IS NULL


    UNION ALL


    /* Test 7: Employee IDs must not be duplicated */

    SELECT
        '07_NO_DUPLICATE_LEARNERS',

        CASE
            WHEN COUNT(*) = 0
                THEN 'PASS'
            ELSE 'FAIL'
        END,

        TO_VARCHAR(COUNT(*)),

        '0 duplicate employee IDs'

    FROM (
        SELECT
            EMPLOYEE_ID

        FROM CORE.LEARNERS

        GROUP BY
            EMPLOYEE_ID

        HAVING COUNT(*) > 1
    )


    UNION ALL


    /* Test 8: A learner should have one enrollment per certification */

    SELECT
        '08_NO_DUPLICATE_ENROLLMENTS',

        CASE
            WHEN COUNT(*) = 0
                THEN 'PASS'
            ELSE 'FAIL'
        END,

        TO_VARCHAR(COUNT(*)),

        '0 duplicate enrollments'

    FROM (
        SELECT
            LEARNER_ID,
            CERTIFICATION_ID

        FROM CORE.ENROLLMENTS

        GROUP BY
            LEARNER_ID,
            CERTIFICATION_ID

        HAVING COUNT(*) > 1
    )


    UNION ALL


    /* Test 9: Assessment scores must be between 0 and 100 */

    SELECT
        '09_VALID_ASSESSMENT_SCORES',

        CASE
            WHEN COUNT(*) = 0
                THEN 'PASS'
            ELSE 'FAIL'
        END,

        TO_VARCHAR(COUNT(*)),

        '0 invalid assessments'

    FROM CORE.ASSESSMENT_RESULTS

    WHERE SCORE_PERCENT < 0
       OR SCORE_PERCENT > 100


    UNION ALL


    /* Test 10: Active enrollments must contain all assigned topics */

    SELECT
        '10_ACTIVE_ENROLLMENT_TOPIC_COUNT',

        CASE
            WHEN COUNT(*) = 0
                THEN 'PASS'
            ELSE 'FAIL'
        END,

        TO_VARCHAR(COUNT(*)),

        '0 incomplete enrollments'

    FROM (
        SELECT
            E.ENROLLMENT_ID

        FROM CORE.ENROLLMENTS E

        LEFT JOIN CORE.TOPIC_PROGRESS TP
            ON E.ENROLLMENT_ID = TP.ENROLLMENT_ID

        WHERE E.ENROLLMENT_STATUS = 'ACTIVE'

        GROUP BY
            E.ENROLLMENT_ID,
            E.PATH_ID

        HAVING COUNT(TP.TOPIC_ID) <> (
            SELECT COUNT(*)
            FROM CORE.PATH_TOPIC_PLAN PTP
            WHERE PTP.PATH_ID = E.PATH_ID
              AND PTP.REQUIRED_FLAG = TRUE
        )
    )


    UNION ALL


    /* Test 11: Learner and learning-path experience levels must match */

    SELECT
        '11_EXPERIENCE_PATH_MATCH',

        CASE
            WHEN COUNT(*) = 0
                THEN 'PASS'
            ELSE 'FAIL'
        END,

        TO_VARCHAR(COUNT(*)),

        '0 mismatched enrollments'

    FROM CORE.LEARNERS L

    JOIN CORE.ENROLLMENTS E
        ON L.LEARNER_ID = E.LEARNER_ID

    JOIN CORE.LEARNING_PATHS LP
        ON E.PATH_ID = LP.PATH_ID

    WHERE L.EXPERIENCE_LEVEL_CODE <>
          LP.EXPERIENCE_LEVEL_CODE


    UNION ALL


    /* Test 12: Active learners must have an active enrollment */

    SELECT
        '12_ACTIVE_LEARNERS_HAVE_ENROLLMENT',

        CASE
            WHEN COUNT(*) = 0
                THEN 'PASS'
            ELSE 'FAIL'
        END,

        TO_VARCHAR(COUNT(*)),

        '0 learners without enrollment'

    FROM CORE.LEARNERS L

    LEFT JOIN CORE.ENROLLMENTS E
        ON L.LEARNER_ID = E.LEARNER_ID
       AND E.ENROLLMENT_STATUS = 'ACTIVE'

    WHERE L.ACTIVE_FLAG = TRUE
      AND E.ENROLLMENT_ID IS NULL
)

SELECT
    TEST_NAME,
    TEST_STATUS,
    ACTUAL_VALUE,
    EXPECTED_VALUE

FROM TEST_RESULTS

ORDER BY TEST_NAME;