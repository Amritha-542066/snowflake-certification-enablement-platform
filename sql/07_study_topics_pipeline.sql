/*
    Project: Snowflake Certification Enablement Platform
    Purpose: Validate RAW study topics, store rejected records,
             load valid records into CORE and process future changes.
*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SNOWPRO_LEARNING_WH;
USE DATABASE SNOWPRO_ENABLEMENT;

-- Stores records that fail validation.
CREATE TABLE IF NOT EXISTS CONTROL.REJECTED_RECORDS (
    REJECTION_ID       VARCHAR(50) DEFAULT UUID_STRING(),
    PIPELINE_NAME      VARCHAR(100),
    RECORD_KEY         VARCHAR(100),
    RAW_RECORD         VARIANT,
    REJECTION_REASON   VARCHAR(1000),
    SOURCE_FILENAME    VARCHAR(1000),
    REJECTED_AT        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Records rejected by project data pipelines';

-- Stores the result of every pipeline execution.
CREATE TABLE IF NOT EXISTS CONTROL.PIPELINE_RUN_LOG (
    RUN_ID              VARCHAR(50),
    PIPELINE_NAME       VARCHAR(100),
    STARTED_AT          TIMESTAMP_NTZ,
    COMPLETED_AT        TIMESTAMP_NTZ,
    RUN_STATUS          VARCHAR(30),
    SOURCE_ROW_COUNT    NUMBER,
    VALID_ROW_COUNT     NUMBER,
    REJECTED_ROW_COUNT  NUMBER,
    RUN_MESSAGE         VARCHAR(2000)
)
COMMENT = 'Execution history for project data pipelines';

-- Tracks the initial RAW records and future inserts.
CREATE STREAM IF NOT EXISTS RAW.STUDY_TOPICS_STREAM
    ON TABLE RAW.STUDY_TOPICS_INBOX
    APPEND_ONLY = TRUE
    SHOW_INITIAL_ROWS = TRUE
    COMMENT = 'Tracks incoming study-topic records';

-- Procedure that validates and processes Stream records.
CREATE OR REPLACE PROCEDURE CONTROL.PROCESS_STUDY_TOPICS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
    V_RUN_ID          VARCHAR DEFAULT UUID_STRING();
    V_STARTED_AT      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    V_SOURCE_COUNT    NUMBER DEFAULT 0;
    V_VALID_COUNT     NUMBER DEFAULT 0;
    V_REJECTED_COUNT  NUMBER DEFAULT 0;
BEGIN
    BEGIN TRANSACTION;

    SELECT COUNT(*)
    INTO :V_SOURCE_COUNT
    FROM RAW.STUDY_TOPICS_STREAM
    WHERE METADATA$ACTION = 'INSERT';

    -- Save invalid records and explain why they failed.
    INSERT INTO CONTROL.REJECTED_RECORDS (
        PIPELINE_NAME,
        RECORD_KEY,
        RAW_RECORD,
        REJECTION_REASON,
        SOURCE_FILENAME
    )
    SELECT
        'STUDY_TOPICS_PIPELINE',
        R.TOPIC_ID,
        OBJECT_CONSTRUCT_KEEP_NULL(
            'TOPIC_ID', R.TOPIC_ID,
            'DOMAIN_ID', R.DOMAIN_ID,
            'TOPIC_NAME', R.TOPIC_NAME,
            'TOPIC_DESCRIPTION', R.TOPIC_DESCRIPTION,
            'DIFFICULTY_LEVEL', R.DIFFICULTY_LEVEL,
            'ESTIMATED_HOURS', R.ESTIMATED_HOURS,
            'TOPIC_ORDER', R.TOPIC_ORDER
        ),
        CASE
            WHEN NOT REGEXP_LIKE(
                COALESCE(TRIM(R.TOPIC_ID), ''),
                '^D[0-9]{2}_T[0-9]{2}$'
            )
                THEN 'Missing or invalid topic ID'

            WHEN NOT REGEXP_LIKE(
                COALESCE(TRIM(R.DOMAIN_ID), ''),
                '^DOMAIN_[0-9]{2}$'
            )
                THEN 'Missing or invalid domain ID'

            WHEN NOT EXISTS (
                SELECT 1
                FROM CORE.EXAM_DOMAINS AS D
                WHERE D.DOMAIN_ID = R.DOMAIN_ID
            )
                THEN 'Domain does not exist in the approved domain list'

            WHEN COALESCE(TRIM(R.TOPIC_NAME), '') = ''
                THEN 'Topic name is required'

            WHEN UPPER(COALESCE(TRIM(R.DIFFICULTY_LEVEL), ''))
                 NOT IN ('BEGINNER', 'INTERMEDIATE', 'ADVANCED')
                THEN 'Difficulty level is invalid'

            WHEN TRY_CAST(R.ESTIMATED_HOURS AS NUMBER(5,1)) IS NULL
                 OR TRY_CAST(R.ESTIMATED_HOURS AS NUMBER(5,1)) <= 0
                THEN 'Estimated hours must be a positive number'

            WHEN TRY_CAST(R.TOPIC_ORDER AS NUMBER(3,0)) IS NULL
                 OR TRY_CAST(R.TOPIC_ORDER AS NUMBER(3,0)) <= 0
                THEN 'Topic order must be a positive whole number'

            ELSE 'Record failed validation'
        END,
        R.SOURCE_FILENAME
    FROM RAW.STUDY_TOPICS_STREAM AS R
    WHERE METADATA$ACTION = 'INSERT'
      AND NOT (
          REGEXP_LIKE(
              COALESCE(TRIM(R.TOPIC_ID), ''),
              '^D[0-9]{2}_T[0-9]{2}$'
          )
          AND REGEXP_LIKE(
              COALESCE(TRIM(R.DOMAIN_ID), ''),
              '^DOMAIN_[0-9]{2}$'
          )
          AND EXISTS (
              SELECT 1
              FROM CORE.EXAM_DOMAINS AS D
              WHERE D.DOMAIN_ID = R.DOMAIN_ID
          )
          AND COALESCE(TRIM(R.TOPIC_NAME), '') <> ''
          AND UPPER(COALESCE(TRIM(R.DIFFICULTY_LEVEL), ''))
              IN ('BEGINNER', 'INTERMEDIATE', 'ADVANCED')
          AND TRY_CAST(R.ESTIMATED_HOURS AS NUMBER(5,1)) > 0
          AND TRY_CAST(R.TOPIC_ORDER AS NUMBER(3,0)) > 0
      );

    V_REJECTED_COUNT := SQLROWCOUNT;

    -- Insert new valid topics or update existing topics.
    MERGE INTO CORE.STUDY_TOPICS AS TARGET
    USING (
        SELECT
            R.TOPIC_ID,
            R.DOMAIN_ID,
            R.TOPIC_NAME,
            R.TOPIC_DESCRIPTION,
            UPPER(TRIM(R.DIFFICULTY_LEVEL)) AS DIFFICULTY_LEVEL,
            TRY_CAST(R.ESTIMATED_HOURS AS NUMBER(5,1))
                AS ESTIMATED_HOURS,
            TRY_CAST(R.TOPIC_ORDER AS NUMBER(3,0))
                AS TOPIC_ORDER
        FROM RAW.STUDY_TOPICS_STREAM AS R
        WHERE METADATA$ACTION = 'INSERT'
          AND REGEXP_LIKE(
              COALESCE(TRIM(R.TOPIC_ID), ''),
              '^D[0-9]{2}_T[0-9]{2}$'
          )
          AND REGEXP_LIKE(
              COALESCE(TRIM(R.DOMAIN_ID), ''),
              '^DOMAIN_[0-9]{2}$'
          )
          AND EXISTS (
              SELECT 1
              FROM CORE.EXAM_DOMAINS AS D
              WHERE D.DOMAIN_ID = R.DOMAIN_ID
          )
          AND COALESCE(TRIM(R.TOPIC_NAME), '') <> ''
          AND UPPER(COALESCE(TRIM(R.DIFFICULTY_LEVEL), ''))
              IN ('BEGINNER', 'INTERMEDIATE', 'ADVANCED')
          AND TRY_CAST(R.ESTIMATED_HOURS AS NUMBER(5,1)) > 0
          AND TRY_CAST(R.TOPIC_ORDER AS NUMBER(3,0)) > 0
        QUALIFY ROW_NUMBER() OVER (
            PARTITION BY R.TOPIC_ID
            ORDER BY R.INGESTED_AT DESC
        ) = 1
    ) AS SOURCE
    ON TARGET.TOPIC_ID = SOURCE.TOPIC_ID

    WHEN MATCHED THEN UPDATE SET
        TARGET.DOMAIN_ID = SOURCE.DOMAIN_ID,
        TARGET.TOPIC_NAME = SOURCE.TOPIC_NAME,
        TARGET.TOPIC_DESCRIPTION = SOURCE.TOPIC_DESCRIPTION,
        TARGET.DIFFICULTY_LEVEL = SOURCE.DIFFICULTY_LEVEL,
        TARGET.ESTIMATED_HOURS = SOURCE.ESTIMATED_HOURS,
        TARGET.TOPIC_ORDER = SOURCE.TOPIC_ORDER,
        TARGET.ACTIVE_FLAG = TRUE,
        TARGET.UPDATED_AT = CURRENT_TIMESTAMP()

    WHEN NOT MATCHED THEN INSERT (
        TOPIC_ID,
        DOMAIN_ID,
        TOPIC_NAME,
        TOPIC_DESCRIPTION,
        DIFFICULTY_LEVEL,
        ESTIMATED_HOURS,
        TOPIC_ORDER
    )
    VALUES (
        SOURCE.TOPIC_ID,
        SOURCE.DOMAIN_ID,
        SOURCE.TOPIC_NAME,
        SOURCE.TOPIC_DESCRIPTION,
        SOURCE.DIFFICULTY_LEVEL,
        SOURCE.ESTIMATED_HOURS,
        SOURCE.TOPIC_ORDER
    );

    V_VALID_COUNT := SQLROWCOUNT;

    INSERT INTO CONTROL.PIPELINE_RUN_LOG (
        RUN_ID,
        PIPELINE_NAME,
        STARTED_AT,
        COMPLETED_AT,
        RUN_STATUS,
        SOURCE_ROW_COUNT,
        VALID_ROW_COUNT,
        REJECTED_ROW_COUNT,
        RUN_MESSAGE
    )
    VALUES (
        :V_RUN_ID,
        'STUDY_TOPICS_PIPELINE',
        :V_STARTED_AT,
        CURRENT_TIMESTAMP(),
        'SUCCESS',
        :V_SOURCE_COUNT,
        :V_VALID_COUNT,
        :V_REJECTED_COUNT,
        'Study-topic pipeline completed successfully'
    );

    COMMIT;

    RETURN
        'Processed ' || V_SOURCE_COUNT ||
        ' rows. Valid: ' || V_VALID_COUNT ||
        ', Rejected: ' || V_REJECTED_COUNT;
END;
$$;

-- Scheduled processing for future RAW records.
CREATE OR REPLACE TASK CONTROL.PROCESS_STUDY_TOPICS_TASK
    WAREHOUSE = SNOWPRO_LEARNING_WH
    SCHEDULE = '1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA(
        'SNOWPRO_ENABLEMENT.RAW.STUDY_TOPICS_STREAM'
    )
AS
    CALL CONTROL.PROCESS_STUDY_TOPICS();

-- Process the initial 31 records before enabling the schedule.
CALL CONTROL.PROCESS_STUDY_TOPICS();

-- Enable automatic processing for future records.
ALTER TASK CONTROL.PROCESS_STUDY_TOPICS_TASK RESUME;

-- Validation queries.
SELECT COUNT(*) AS CORE_TOPIC_COUNT
FROM CORE.STUDY_TOPICS;

SELECT COUNT(*) AS REJECTED_TOPIC_COUNT
FROM CONTROL.REJECTED_RECORDS
WHERE PIPELINE_NAME = 'STUDY_TOPICS_PIPELINE';

SELECT *
FROM CONTROL.PIPELINE_RUN_LOG
WHERE PIPELINE_NAME = 'STUDY_TOPICS_PIPELINE'
ORDER BY STARTED_AT DESC;

SHOW TASKS LIKE 'PROCESS_STUDY_TOPICS_TASK'
    IN SCHEMA SNOWPRO_ENABLEMENT.CONTROL;