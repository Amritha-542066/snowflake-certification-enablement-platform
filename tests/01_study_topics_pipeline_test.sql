/*
    Test one valid update and one invalid topic record.
*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SNOWPRO_LEARNING_WH;
USE DATABASE SNOWPRO_ENABLEMENT;

-- Temporarily stop the schedule while performing the controlled test.
ALTER TASK CONTROL.PROCESS_STUDY_TOPICS_TASK SUSPEND;

-- Add one valid update and one invalid record to RAW.
INSERT INTO RAW.STUDY_TOPICS_INBOX (
    TOPIC_ID,
    DOMAIN_ID,
    TOPIC_NAME,
    TOPIC_DESCRIPTION,
    DIFFICULTY_LEVEL,
    ESTIMATED_HOURS,
    TOPIC_ORDER,
    SOURCE_FILENAME
)
VALUES
(
    'D01_T01',
    'DOMAIN_01',
    'Snowflake AI Data Cloud Overview',
    'Understand Snowflake workloads editions and major platform capabilities',
    'BEGINNER',
    '2',
    '1',
    'pipeline_valid_test.csv'
),
(
    'D99_T01',
    'DOMAIN_99',
    'Invalid Pipeline Test Topic',
    'This record is intentionally invalid',
    'BEGINNER',
    '-2',
    '999',
    'pipeline_invalid_test.csv'
);

-- Process the new Stream records immediately.
CALL CONTROL.PROCESS_STUDY_TOPICS();

-- The valid record updates an existing topic, so the total remains 31.
SELECT COUNT(*) AS CORE_TOPIC_COUNT
FROM CORE.STUDY_TOPICS;

-- The invalid record should be saved with a rejection reason.
SELECT
    RECORD_KEY,
    REJECTION_REASON,
    SOURCE_FILENAME
FROM CONTROL.REJECTED_RECORDS
WHERE SOURCE_FILENAME = 'pipeline_invalid_test.csv';

-- Review the latest pipeline execution.
SELECT *
FROM CONTROL.PIPELINE_RUN_LOG
WHERE PIPELINE_NAME = 'STUDY_TOPICS_PIPELINE'
ORDER BY STARTED_AT DESC
LIMIT 1;

-- Re-enable automatic processing.
ALTER TASK CONTROL.PROCESS_STUDY_TOPICS_TASK RESUME;