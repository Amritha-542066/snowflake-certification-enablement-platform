/*==============================================================================
  Snowflake Certification Enablement Platform
  Step 17: Generate learning schedules and initialize learner progress

  Purpose:
  - Distribute the 31 SnowPro topics across each learning path.
  - Create different schedules based on path duration.
  - Initialize topic progress for registered learners.
==============================================================================*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SNOWPRO_LEARNING_WH;
USE DATABASE SNOWPRO_ENABLEMENT;
USE SCHEMA CORE;


/*------------------------------------------------------------------------------
  1. Generate weekly schedules for all active learning paths
------------------------------------------------------------------------------*/

MERGE INTO CORE.PATH_TOPIC_PLAN AS TARGET
USING (
    WITH ORDERED_TOPICS AS (
        SELECT
            TOPIC_ID,
            ESTIMATED_HOURS,
            TOPIC_ORDER,
            ROW_NUMBER() OVER (
                ORDER BY TOPIC_ORDER, TOPIC_ID
            ) AS TOPIC_POSITION,
            COUNT(*) OVER () AS TOTAL_TOPICS
        FROM CORE.STUDY_TOPICS
        WHERE ACTIVE_FLAG = TRUE
    ),

    PLANNED_TOPICS AS (
        SELECT
            P.PATH_ID,
            T.TOPIC_ID,
            CAST(
                LEAST(
                    P.DURATION_WEEKS,
                    CEIL(
                        T.TOPIC_POSITION *
                        P.DURATION_WEEKS /
                        T.TOTAL_TOPICS
                    )
                )
                AS NUMBER(3,0)
            ) AS PLANNED_WEEK,
            P.WEEKLY_STUDY_HOURS,
            T.ESTIMATED_HOURS
        FROM CORE.LEARNING_PATHS P
        CROSS JOIN ORDERED_TOPICS T
        WHERE P.ACTIVE_FLAG = TRUE
          AND P.CERTIFICATION_ID = 'CERT_SNOWPRO_CORE'
    ),

    FINAL_SCHEDULE AS (
        SELECT
            PATH_ID,
            TOPIC_ID,
            PLANNED_WEEK,

            ROUND(
                WEEKLY_STUDY_HOURS *
                ESTIMATED_HOURS /
                NULLIF(
                    SUM(ESTIMATED_HOURS) OVER (
                        PARTITION BY PATH_ID, PLANNED_WEEK
                    ),
                    0
                ),
                1
            ) AS RECOMMENDED_HOURS,

            TRUE AS REQUIRED_FLAG
        FROM PLANNED_TOPICS
    )

    SELECT
        PATH_ID,
        TOPIC_ID,
        PLANNED_WEEK,
        RECOMMENDED_HOURS,
        REQUIRED_FLAG
    FROM FINAL_SCHEDULE

) AS SOURCE

ON TARGET.PATH_ID = SOURCE.PATH_ID
AND TARGET.TOPIC_ID = SOURCE.TOPIC_ID

WHEN MATCHED THEN
    UPDATE SET
        PLANNED_WEEK = SOURCE.PLANNED_WEEK,
        RECOMMENDED_HOURS = SOURCE.RECOMMENDED_HOURS,
        REQUIRED_FLAG = SOURCE.REQUIRED_FLAG,
        UPDATED_AT = CURRENT_TIMESTAMP()

WHEN NOT MATCHED THEN
    INSERT (
        PATH_ID,
        TOPIC_ID,
        PLANNED_WEEK,
        RECOMMENDED_HOURS,
        REQUIRED_FLAG,
        CREATED_AT,
        UPDATED_AT
    )
    VALUES (
        SOURCE.PATH_ID,
        SOURCE.TOPIC_ID,
        SOURCE.PLANNED_WEEK,
        SOURCE.RECOMMENDED_HOURS,
        SOURCE.REQUIRED_FLAG,
        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP()
    );


/*------------------------------------------------------------------------------
  2. Initialize topic progress for all active learner enrollments
------------------------------------------------------------------------------*/

MERGE INTO CORE.TOPIC_PROGRESS AS TARGET
USING (
    SELECT
        E.ENROLLMENT_ID,
        PTP.TOPIC_ID
    FROM CORE.ENROLLMENTS E
    JOIN CORE.PATH_TOPIC_PLAN PTP
        ON E.PATH_ID = PTP.PATH_ID
    WHERE E.ENROLLMENT_STATUS = 'ACTIVE'
      AND PTP.REQUIRED_FLAG = TRUE
) AS SOURCE

ON TARGET.ENROLLMENT_ID = SOURCE.ENROLLMENT_ID
AND TARGET.TOPIC_ID = SOURCE.TOPIC_ID

WHEN NOT MATCHED THEN
    INSERT (
        ENROLLMENT_ID,
        TOPIC_ID,
        PROGRESS_STATUS,
        COMPLETION_PERCENT,
        HOURS_SPENT,
        UPDATED_AT
    )
    VALUES (
        SOURCE.ENROLLMENT_ID,
        SOURCE.TOPIC_ID,
        'NOT_STARTED',
        0,
        0,
        CURRENT_TIMESTAMP()
    );


/*------------------------------------------------------------------------------
  3. Validate the generated learning paths
------------------------------------------------------------------------------*/

SELECT
    LP.PATH_ID,
    LP.PATH_NAME,
    LP.DURATION_WEEKS,
    LP.WEEKLY_STUDY_HOURS,
    COUNT(PTP.TOPIC_ID) AS TOTAL_TOPICS,
    MIN(PTP.PLANNED_WEEK) AS FIRST_WEEK,
    MAX(PTP.PLANNED_WEEK) AS LAST_WEEK
FROM CORE.LEARNING_PATHS LP
JOIN CORE.PATH_TOPIC_PLAN PTP
    ON LP.PATH_ID = PTP.PATH_ID
GROUP BY
    LP.PATH_ID,
    LP.PATH_NAME,
    LP.DURATION_WEEKS,
    LP.WEEKLY_STUDY_HOURS
ORDER BY LP.DURATION_WEEKS DESC;


/*------------------------------------------------------------------------------
  4. Validate initialized learner progress
------------------------------------------------------------------------------*/

SELECT
    E.ENROLLMENT_ID,
    E.PATH_ID,
    COUNT(TP.TOPIC_ID) AS ASSIGNED_TOPICS,
    COUNT_IF(TP.PROGRESS_STATUS = 'NOT_STARTED')
        AS NOT_STARTED_TOPICS
FROM CORE.ENROLLMENTS E
LEFT JOIN CORE.TOPIC_PROGRESS TP
    ON E.ENROLLMENT_ID = TP.ENROLLMENT_ID
GROUP BY
    E.ENROLLMENT_ID,
    E.PATH_ID
ORDER BY E.ENROLLMENT_ID;