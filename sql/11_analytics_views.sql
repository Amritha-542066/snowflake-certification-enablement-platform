/*==============================================================================
  Snowflake Certification Enablement Platform
  Step 18: Analytics and certification-readiness views

  Purpose:
  - Display weekly learning schedules.
  - Track overall learner progress.
  - Track progress by exam domain.
  - Calculate a simple certification-readiness indicator.
==============================================================================*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SNOWPRO_LEARNING_WH;
USE DATABASE SNOWPRO_ENABLEMENT;
USE SCHEMA ANALYTICS;


/*------------------------------------------------------------------------------
  1. Weekly study-plan view
------------------------------------------------------------------------------*/

CREATE OR REPLACE VIEW ANALYTICS.V_WEEKLY_STUDY_PLAN AS

SELECT
    LP.PATH_ID,
    LP.PATH_NAME,
    LP.EXPERIENCE_LEVEL_CODE,
    LP.DURATION_WEEKS,
    LP.WEEKLY_STUDY_HOURS,

    PTP.PLANNED_WEEK,
    PTP.RECOMMENDED_HOURS,
    PTP.REQUIRED_FLAG,

    ED.DOMAIN_ID,
    ED.DOMAIN_NAME,
    ED.DOMAIN_ORDER,
    ED.EXAM_WEIGHT_PERCENT,

    ST.TOPIC_ID,
    ST.TOPIC_NAME,
    ST.TOPIC_DESCRIPTION,
    ST.DIFFICULTY_LEVEL,
    ST.ESTIMATED_HOURS,
    ST.TOPIC_ORDER

FROM CORE.LEARNING_PATHS LP

JOIN CORE.PATH_TOPIC_PLAN PTP
    ON LP.PATH_ID = PTP.PATH_ID

JOIN CORE.STUDY_TOPICS ST
    ON PTP.TOPIC_ID = ST.TOPIC_ID

JOIN CORE.EXAM_DOMAINS ED
    ON ST.DOMAIN_ID = ED.DOMAIN_ID

WHERE LP.ACTIVE_FLAG = TRUE
  AND ST.ACTIVE_FLAG = TRUE
  AND ED.ACTIVE_FLAG = TRUE;


/*------------------------------------------------------------------------------
  2. Overall learner-progress view
------------------------------------------------------------------------------*/

CREATE OR REPLACE VIEW ANALYTICS.V_LEARNER_PROGRESS AS

SELECT
    L.LEARNER_ID,
    L.LEARNER_NAME,
    L.DEPARTMENT_NAME,
    L.SNOWFLAKE_EXPERIENCE_YEARS,
    L.EXPERIENCE_LEVEL_CODE,

    E.ENROLLMENT_ID,
    E.CERTIFICATION_ID,
    E.ENROLLMENT_STATUS,
    E.ENROLLED_DATE,
    E.TARGET_COMPLETION_DATE,
    E.TARGET_EXAM_DATE,

    LP.PATH_ID,
    LP.PATH_NAME,
    LP.DURATION_WEEKS,
    LP.WEEKLY_STUDY_HOURS,

    COUNT(PTP.TOPIC_ID) AS TOTAL_TOPICS,

    COUNT_IF(
        TP.PROGRESS_STATUS = 'COMPLETED'
    ) AS COMPLETED_TOPICS,

    COUNT_IF(
        TP.PROGRESS_STATUS = 'IN_PROGRESS'
    ) AS IN_PROGRESS_TOPICS,

    COUNT_IF(
        COALESCE(
            TP.PROGRESS_STATUS,
            'NOT_STARTED'
        ) = 'NOT_STARTED'
    ) AS NOT_STARTED_TOPICS,

    ROUND(
        AVG(
            COALESCE(
                TP.COMPLETION_PERCENT,
                0
            )
        ),
        2
    ) AS OVERALL_COMPLETION_PERCENT,

    ROUND(
        SUM(
            COALESCE(
                TP.HOURS_SPENT,
                0
            )
        ),
        2
    ) AS TOTAL_HOURS_SPENT,

    LEAST(
        LP.DURATION_WEEKS,
        GREATEST(
            1,
            DATEDIFF(
                'WEEK',
                E.ENROLLED_DATE,
                CURRENT_DATE()
            ) + 1
        )
    ) AS CURRENT_STUDY_WEEK,

    DATEDIFF(
        'DAY',
        CURRENT_DATE(),
        E.TARGET_COMPLETION_DATE
    ) AS DAYS_TO_TARGET_COMPLETION

FROM CORE.LEARNERS L

JOIN CORE.ENROLLMENTS E
    ON L.LEARNER_ID = E.LEARNER_ID

JOIN CORE.LEARNING_PATHS LP
    ON E.PATH_ID = LP.PATH_ID

JOIN CORE.PATH_TOPIC_PLAN PTP
    ON LP.PATH_ID = PTP.PATH_ID

LEFT JOIN CORE.TOPIC_PROGRESS TP
    ON E.ENROLLMENT_ID = TP.ENROLLMENT_ID
   AND PTP.TOPIC_ID = TP.TOPIC_ID

GROUP BY
    L.LEARNER_ID,
    L.LEARNER_NAME,
    L.DEPARTMENT_NAME,
    L.SNOWFLAKE_EXPERIENCE_YEARS,
    L.EXPERIENCE_LEVEL_CODE,
    E.ENROLLMENT_ID,
    E.CERTIFICATION_ID,
    E.ENROLLMENT_STATUS,
    E.ENROLLED_DATE,
    E.TARGET_COMPLETION_DATE,
    E.TARGET_EXAM_DATE,
    LP.PATH_ID,
    LP.PATH_NAME,
    LP.DURATION_WEEKS,
    LP.WEEKLY_STUDY_HOURS;


/*------------------------------------------------------------------------------
  3. Exam-domain progress view
------------------------------------------------------------------------------*/

CREATE OR REPLACE VIEW ANALYTICS.V_DOMAIN_PROGRESS AS

SELECT
    E.ENROLLMENT_ID,
    E.LEARNER_ID,
    E.PATH_ID,

    ED.DOMAIN_ID,
    ED.DOMAIN_NAME,
    ED.DOMAIN_ORDER,
    ED.EXAM_WEIGHT_PERCENT,

    COUNT(ST.TOPIC_ID) AS TOTAL_DOMAIN_TOPICS,

    COUNT_IF(
        TP.PROGRESS_STATUS = 'COMPLETED'
    ) AS COMPLETED_DOMAIN_TOPICS,

    ROUND(
        AVG(
            COALESCE(
                TP.COMPLETION_PERCENT,
                0
            )
        ),
        2
    ) AS DOMAIN_COMPLETION_PERCENT,

    ROUND(
        AVG(
            COALESCE(
                TP.COMPLETION_PERCENT,
                0
            )
        ) *
        ED.EXAM_WEIGHT_PERCENT / 100,
        2
    ) AS WEIGHTED_PROGRESS_CONTRIBUTION,

    ROUND(
        SUM(
            COALESCE(
                TP.HOURS_SPENT,
                0
            )
        ),
        2
    ) AS DOMAIN_HOURS_SPENT

FROM CORE.ENROLLMENTS E

JOIN CORE.PATH_TOPIC_PLAN PTP
    ON E.PATH_ID = PTP.PATH_ID

JOIN CORE.STUDY_TOPICS ST
    ON PTP.TOPIC_ID = ST.TOPIC_ID

JOIN CORE.EXAM_DOMAINS ED
    ON ST.DOMAIN_ID = ED.DOMAIN_ID

LEFT JOIN CORE.TOPIC_PROGRESS TP
    ON E.ENROLLMENT_ID = TP.ENROLLMENT_ID
   AND ST.TOPIC_ID = TP.TOPIC_ID

GROUP BY
    E.ENROLLMENT_ID,
    E.LEARNER_ID,
    E.PATH_ID,
    ED.DOMAIN_ID,
    ED.DOMAIN_NAME,
    ED.DOMAIN_ORDER,
    ED.EXAM_WEIGHT_PERCENT;


/*------------------------------------------------------------------------------
  4. Certification-readiness view

  Readiness calculation:
  - Before an assessment: based on weighted topic progress.
  - After an assessment:
      60% weighted topic progress
      40% latest overall assessment score

  This is an internal learning indicator, not an exam-result guarantee.
------------------------------------------------------------------------------*/

CREATE OR REPLACE VIEW ANALYTICS.V_CERTIFICATION_READINESS AS

WITH WEIGHTED_PROGRESS AS (

    SELECT
        ENROLLMENT_ID,

        ROUND(
            SUM(
                WEIGHTED_PROGRESS_CONTRIBUTION
            ),
            2
        ) AS WEIGHTED_LEARNING_PROGRESS

    FROM ANALYTICS.V_DOMAIN_PROGRESS

    GROUP BY
        ENROLLMENT_ID
),

LATEST_ASSESSMENT AS (

    SELECT
        ENROLLMENT_ID,
        ASSESSMENT_NAME,
        ASSESSMENT_TYPE,
        SCORE_PERCENT,
        PASSED_FLAG,
        ATTEMPTED_AT

    FROM CORE.ASSESSMENT_RESULTS

    WHERE DOMAIN_ID IS NULL

    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY ENROLLMENT_ID
        ORDER BY ATTEMPTED_AT DESC
    ) = 1
),

READINESS_SCORES AS (

    SELECT
        LP.LEARNER_ID,
        LP.LEARNER_NAME,
        LP.DEPARTMENT_NAME,
        LP.SNOWFLAKE_EXPERIENCE_YEARS,
        LP.EXPERIENCE_LEVEL_CODE,

        LP.ENROLLMENT_ID,
        LP.PATH_ID,
        LP.PATH_NAME,
        LP.ENROLLMENT_STATUS,
        LP.TARGET_COMPLETION_DATE,
        LP.TARGET_EXAM_DATE,

        LP.OVERALL_COMPLETION_PERCENT,
        LP.COMPLETED_TOPICS,
        LP.TOTAL_TOPICS,
        LP.TOTAL_HOURS_SPENT,

        COALESCE(
            WP.WEIGHTED_LEARNING_PROGRESS,
            0
        ) AS WEIGHTED_LEARNING_PROGRESS,

        LA.ASSESSMENT_NAME AS LATEST_ASSESSMENT_NAME,
        LA.ASSESSMENT_TYPE AS LATEST_ASSESSMENT_TYPE,
        LA.SCORE_PERCENT AS LATEST_ASSESSMENT_SCORE,
        LA.PASSED_FLAG AS LATEST_ASSESSMENT_PASSED,
        LA.ATTEMPTED_AT AS LATEST_ASSESSMENT_DATE,

        ROUND(
            CASE
                WHEN LA.SCORE_PERCENT IS NULL
                    THEN COALESCE(
                        WP.WEIGHTED_LEARNING_PROGRESS,
                        0
                    )

                ELSE
                    COALESCE(
                        WP.WEIGHTED_LEARNING_PROGRESS,
                        0
                    ) * 0.60
                    +
                    LA.SCORE_PERCENT * 0.40
            END,
            2
        ) AS READINESS_SCORE

    FROM ANALYTICS.V_LEARNER_PROGRESS LP

    LEFT JOIN WEIGHTED_PROGRESS WP
        ON LP.ENROLLMENT_ID = WP.ENROLLMENT_ID

    LEFT JOIN LATEST_ASSESSMENT LA
        ON LP.ENROLLMENT_ID = LA.ENROLLMENT_ID
)

SELECT
    *,

    CASE
        WHEN LATEST_ASSESSMENT_SCORE IS NULL
             AND READINESS_SCORE >= 80
            THEN 'ASSESSMENT_REQUIRED'

        WHEN LATEST_ASSESSMENT_SCORE IS NOT NULL
             AND READINESS_SCORE >= 80
             AND LATEST_ASSESSMENT_SCORE >= 75
            THEN 'READY'

        WHEN READINESS_SCORE >= 65
            THEN 'ALMOST_READY'

        WHEN READINESS_SCORE > 0
            THEN 'IN_PROGRESS'

        ELSE 'NOT_STARTED'
    END AS READINESS_STATUS,

    CASE
        WHEN LATEST_ASSESSMENT_SCORE IS NULL
            THEN 'Complete a mock assessment to confirm readiness.'

        WHEN READINESS_SCORE >= 80
             AND LATEST_ASSESSMENT_SCORE >= 75
            THEN 'Learner meets the internal readiness criteria.'

        WHEN READINESS_SCORE >= 65
            THEN 'Continue revision and improve weaker domains.'

        ELSE 'Continue the assigned learning path.'
    END AS READINESS_RECOMMENDATION

FROM READINESS_SCORES;


/*------------------------------------------------------------------------------
  5. Validate the analytics views
------------------------------------------------------------------------------*/

SELECT *
FROM ANALYTICS.V_LEARNER_PROGRESS
ORDER BY LEARNER_ID;


SELECT *
FROM ANALYTICS.V_DOMAIN_PROGRESS
ORDER BY ENROLLMENT_ID, DOMAIN_ORDER;


SELECT *
FROM ANALYTICS.V_CERTIFICATION_READINESS
ORDER BY LEARNER_ID;


SELECT *
FROM ANALYTICS.V_WEEKLY_STUDY_PLAN
WHERE PATH_ID = 'PATH_FRESHER'
ORDER BY PLANNED_WEEK, DOMAIN_ORDER, TOPIC_ORDER;