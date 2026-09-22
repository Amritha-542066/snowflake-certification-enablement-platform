/*
    Project: SnowPro Core Enablement Platform
    Purpose: Create the RAW table, CSV file format,
             and internal stage for study-topic ingestion.
*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SNOWPRO_LEARNING_WH;
USE DATABASE SNOWPRO_ENABLEMENT;
USE SCHEMA RAW;

-- Stores study-topic records exactly as they arrive.
-- Numeric fields are initially VARCHAR so invalid incoming
-- values can be detected safely during pipeline processing.
CREATE TABLE IF NOT EXISTS STUDY_TOPICS_INBOX (
    TOPIC_ID               VARCHAR(30),
    DOMAIN_ID              VARCHAR(20),
    TOPIC_NAME             VARCHAR(250),
    TOPIC_DESCRIPTION      VARCHAR(2000),
    DIFFICULTY_LEVEL       VARCHAR(20),
    ESTIMATED_HOURS        VARCHAR(50),
    TOPIC_ORDER            VARCHAR(50),
    SOURCE_FILENAME        VARCHAR(1000),
    INGESTED_AT            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw incoming SnowPro study-topic records';

-- Defines how Snowflake should read the CSV file.
CREATE FILE FORMAT IF NOT EXISTS STUDY_TOPICS_CSV_FORMAT
    TYPE = CSV
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    TRIM_SPACE = TRUE
    NULL_IF = ('', 'NULL')
    EMPTY_FIELD_AS_NULL = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = TRUE
    COMMENT = 'CSV format for SnowPro study-topic files';

-- Internal storage location for incoming project files.
CREATE STAGE IF NOT EXISTS SNOWPRO_DATA_STAGE
    FILE_FORMAT = STUDY_TOPICS_CSV_FORMAT
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Internal stage for SnowPro enablement platform files';

-- Validation commands.
SHOW TABLES LIKE 'STUDY_TOPICS_INBOX'
    IN SCHEMA SNOWPRO_ENABLEMENT.RAW;

SHOW FILE FORMATS LIKE 'STUDY_TOPICS_CSV_FORMAT'
    IN SCHEMA SNOWPRO_ENABLEMENT.RAW;

SHOW STAGES LIKE 'SNOWPRO_DATA_STAGE'
    IN SCHEMA SNOWPRO_ENABLEMENT.RAW;