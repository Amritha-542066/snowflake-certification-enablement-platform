/*
    Project: Snowflake Certification Enablement Platform
    Purpose: Load the staged study-topic CSV into the RAW inbox table.
*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SNOWPRO_LEARNING_WH;
USE DATABASE SNOWPRO_ENABLEMENT;
USE SCHEMA RAW;

-- Confirm that the input file is available.
LIST @SNOWPRO_DATA_STAGE;

-- Load the seven CSV columns and capture the source filename.
COPY INTO STUDY_TOPICS_INBOX (
    TOPIC_ID,
    DOMAIN_ID,
    TOPIC_NAME,
    TOPIC_DESCRIPTION,
    DIFFICULTY_LEVEL,
    ESTIMATED_HOURS,
    TOPIC_ORDER,
    SOURCE_FILENAME
)
FROM (
    SELECT
        $1::VARCHAR,
        $2::VARCHAR,
        $3::VARCHAR,
        $4::VARCHAR,
        $5::VARCHAR,
        $6::VARCHAR,
        $7::VARCHAR,
        METADATA$FILENAME
    FROM @SNOWPRO_DATA_STAGE/study_topics.csv
)
FILE_FORMAT = (
    FORMAT_NAME = 'SNOWPRO_ENABLEMENT.RAW.STUDY_TOPICS_CSV_FORMAT'
)
ON_ERROR = 'ABORT_STATEMENT'
PURGE = FALSE;

-- Validate the total number of loaded records.
SELECT COUNT(*) AS RAW_TOPIC_COUNT
FROM STUDY_TOPICS_INBOX;

-- Validate the number of topics in every domain.
SELECT
    DOMAIN_ID,
    COUNT(*) AS TOPIC_COUNT
FROM STUDY_TOPICS_INBOX
GROUP BY DOMAIN_ID
ORDER BY DOMAIN_ID;