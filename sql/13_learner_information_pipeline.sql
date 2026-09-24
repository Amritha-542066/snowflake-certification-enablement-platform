/*==============================================================================
  Snowflake Certification Enablement Platform
  Learner Information CSV Pipeline

  Purpose:
  - Receive learner information from CSV files.
  - Load incoming records into the RAW schema.
  - Validate newly loaded records.
  - Register valid learners using the existing REGISTER_LEARNER procedure.
  - Store invalid records with a rejection reason.
  - Record pipeline execution results.
==============================================================================*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SNOWPRO_LEARNING_WH;
USE DATABASE SNOWPRO_ENABLEMENT;


/*------------------------------------------------------------------------------
  1. Create the shared CSV file format
------------------------------------------------------------------------------*/

CREATE FILE FORMAT IF NOT EXISTS RAW.CERTIFICATION_CSV_FORMAT
    TYPE = CSV
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    EMPTY_FIELD_AS_NULL = TRUE
    NULL_IF = ('', 'NULL', 'null')
    ERROR_ON_COLUMN_COUNT_MISMATCH = TRUE
    COMMENT = 'CSV format used for certification learner and progress files';


/*------------------------------------------------------------------------------
  2. Create the internal upload stage
------------------------------------------------------------------------------*/

CREATE STAGE IF NOT EXISTS RAW.CERTIFICATION_UPLOAD_STAGE
    FILE_FORMAT = (
        FORMAT_NAME =
            'SNOWPRO_ENABLEMENT.RAW.CERTIFICATION_CSV_FORMAT'
    )
    DIRECTORY = (
        ENABLE = TRUE
    )
    COMMENT = 'Internal stage for learner and progress CSV files';


/*------------------------------------------------------------------------------
  3. Create the learner-information RAW inbox
------------------------------------------------------------------------------*/

CREATE TABLE IF NOT EXISTS RAW.LEARNER_INFORMATION_INBOX
(
    SOURCE_RECORD_ID              VARCHAR(100),
    EMPLOYEE_ID                   VARCHAR(100),
    LEARNER_NAME                  VARCHAR(250),
    EMAIL                         VARCHAR(320),
    DEPARTMENT_NAME               VARCHAR(250),
    SNOWFLAKE_EXPERIENCE_YEARS    VARCHAR(50),

    SOURCE_FILE_NAME              VARCHAR(500),
    SOURCE_ROW_NUMBER             NUMBER,

    INGESTED_AT                   TIMESTAMP_NTZ
        DEFAULT CURRENT_TIMESTAMP()
);


/*------------------------------------------------------------------------------
  4. Create generic CSV rejected-record storage
------------------------------------------------------------------------------*/

CREATE TABLE IF NOT EXISTS CONTROL.CSV_REJECTED_RECORDS
(
    REJECTION_ID          VARCHAR(100),
    PIPELINE_NAME         VARCHAR(100),
    SOURCE_RECORD_ID      VARCHAR(100),
    SOURCE_FILE_NAME      VARCHAR(500),
    SOURCE_ROW_NUMBER     NUMBER,
    RAW_RECORD            VARIANT,
    REJECTION_REASON      VARCHAR(2000),

    REJECTED_AT           TIMESTAMP_NTZ
        DEFAULT CURRENT_TIMESTAMP(),

    RESOLVED_FLAG         BOOLEAN
        DEFAULT FALSE,

    RESOLVED_AT           TIMESTAMP_NTZ
);


/*------------------------------------------------------------------------------
  5. Create generic CSV pipeline run log
------------------------------------------------------------------------------*/

CREATE TABLE IF NOT EXISTS CONTROL.CSV_PIPELINE_RUN_LOG
(
    RUN_ID                 VARCHAR(100),
    PIPELINE_NAME          VARCHAR(100),
    STARTED_AT             TIMESTAMP_NTZ,
    COMPLETED_AT           TIMESTAMP_NTZ,
    RUN_STATUS             VARCHAR(30),
    RECORDS_RECEIVED       NUMBER,
    RECORDS_ACCEPTED       NUMBER,
    RECORDS_REJECTED       NUMBER,
    RUN_MESSAGE            VARCHAR(4000)
);


/*------------------------------------------------------------------------------
  6. Track successfully processed source records
------------------------------------------------------------------------------*/

CREATE TABLE IF NOT EXISTS CONTROL.CSV_PROCESSED_RECORDS
(
    PIPELINE_NAME          VARCHAR(100),
    SOURCE_RECORD_ID       VARCHAR(100),

    PROCESSED_AT           TIMESTAMP_NTZ
        DEFAULT CURRENT_TIMESTAMP(),

    PROCESSING_RESULT      VARCHAR(2000),

    PRIMARY KEY
    (
        PIPELINE_NAME,
        SOURCE_RECORD_ID
    )
);


/*------------------------------------------------------------------------------
  7. Create a Stream on the learner inbox
------------------------------------------------------------------------------*/

CREATE OR REPLACE STREAM RAW.LEARNER_INFORMATION_STREAM
    ON TABLE RAW.LEARNER_INFORMATION_INBOX
    APPEND_ONLY = TRUE;


/*------------------------------------------------------------------------------
  8. Create the learner-information processing procedure
------------------------------------------------------------------------------*/

CREATE OR REPLACE PROCEDURE CONTROL.PROCESS_LEARNER_INFORMATION()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$

DECLARE

    V_RUN_ID                 VARCHAR
        DEFAULT
            'RUN_' ||
            REPLACE(
                UUID_STRING(),
                '-',
                ''
            );

    V_STARTED_AT             TIMESTAMP_NTZ
        DEFAULT CURRENT_TIMESTAMP();

    V_RECEIVED               NUMBER
        DEFAULT 0;

    V_ACCEPTED               NUMBER
        DEFAULT 0;

    V_REJECTED               NUMBER
        DEFAULT 0;

    V_EMPLOYEE_ID            VARCHAR;
    V_LEARNER_NAME           VARCHAR;
    V_EMAIL                  VARCHAR;
    V_DEPARTMENT_NAME        VARCHAR;
    V_EXPERIENCE_YEARS       NUMBER(4,1);
    V_SOURCE_RECORD_ID       VARCHAR;
    V_REGISTRATION_RESULT    VARCHAR;

    /* Result set used by the FOR loop. */
    V_VALID_ROWS             RESULTSET;

BEGIN

    /* Store the current Stream records in a temporary batch table. */

    CREATE OR REPLACE TEMPORARY TABLE TMP_LEARNER_INFORMATION_BATCH
    (
        SOURCE_RECORD_ID              VARCHAR(100),
        EMPLOYEE_ID                   VARCHAR(100),
        LEARNER_NAME                  VARCHAR(250),
        EMAIL                         VARCHAR(320),
        DEPARTMENT_NAME               VARCHAR(250),
        SNOWFLAKE_EXPERIENCE_YEARS    VARCHAR(50),
        SOURCE_FILE_NAME              VARCHAR(500),
        SOURCE_ROW_NUMBER             NUMBER,
        INGESTED_AT                   TIMESTAMP_NTZ,
        VALIDATION_ERROR              VARCHAR(2000)
    );


    /* Insert and consume the currently available Stream records. */

    INSERT INTO TMP_LEARNER_INFORMATION_BATCH
    (
        SOURCE_RECORD_ID,
        EMPLOYEE_ID,
        LEARNER_NAME,
        EMAIL,
        DEPARTMENT_NAME,
        SNOWFLAKE_EXPERIENCE_YEARS,
        SOURCE_FILE_NAME,
        SOURCE_ROW_NUMBER,
        INGESTED_AT,
        VALIDATION_ERROR
    )

    SELECT
        TRIM(SOURCE_RECORD_ID),
        TRIM(EMPLOYEE_ID),
        TRIM(LEARNER_NAME),
        LOWER(TRIM(EMAIL)),
        TRIM(DEPARTMENT_NAME),
        TRIM(SNOWFLAKE_EXPERIENCE_YEARS),
        SOURCE_FILE_NAME,
        SOURCE_ROW_NUMBER,
        INGESTED_AT,
        NULL

    FROM RAW.LEARNER_INFORMATION_STREAM

    WHERE METADATA$ACTION = 'INSERT';


    /* Count received records. */

    SELECT COUNT(*)
    INTO :V_RECEIVED
    FROM TMP_LEARNER_INFORMATION_BATCH;


    /* Validate required fields and data types. */

    UPDATE TMP_LEARNER_INFORMATION_BATCH

    SET VALIDATION_ERROR =

        CASE

            WHEN SOURCE_RECORD_ID IS NULL
                 OR SOURCE_RECORD_ID = ''
                THEN
                    'Source record ID is required.'

            WHEN EMPLOYEE_ID IS NULL
                 OR EMPLOYEE_ID = ''
                THEN
                    'Employee ID is required.'

            WHEN LEARNER_NAME IS NULL
                 OR LEARNER_NAME = ''
                THEN
                    'Learner name is required.'

            WHEN EMAIL IS NULL
                 OR EMAIL = ''
                THEN
                    'Email is required.'

            WHEN EMAIL NOT LIKE '%@%.%'
                THEN
                    'Email format is invalid.'

            WHEN SNOWFLAKE_EXPERIENCE_YEARS IS NULL
                 OR SNOWFLAKE_EXPERIENCE_YEARS = ''
                THEN
                    'Snowflake experience is required.'

            WHEN TRY_TO_DECIMAL(
                    SNOWFLAKE_EXPERIENCE_YEARS,
                    4,
                    1
                 ) IS NULL
                THEN
                    'Snowflake experience must be numeric.'

            WHEN TRY_TO_DECIMAL(
                    SNOWFLAKE_EXPERIENCE_YEARS,
                    4,
                    1
                 ) < 0
                THEN
                    'Snowflake experience must be zero or greater.'

            ELSE
                NULL

        END;


    /* Reject duplicate source IDs within the same batch. */

    UPDATE TMP_LEARNER_INFORMATION_BATCH AS TARGET

    SET VALIDATION_ERROR =
        'Duplicate source record ID exists in the uploaded batch.'

    WHERE TARGET.VALIDATION_ERROR IS NULL

      AND TARGET.SOURCE_RECORD_ID IN
      (
          SELECT SOURCE_RECORD_ID

          FROM TMP_LEARNER_INFORMATION_BATCH

          GROUP BY SOURCE_RECORD_ID

          HAVING COUNT(*) > 1
      );


    /* Prevent previously accepted source records from being repeated. */

    UPDATE TMP_LEARNER_INFORMATION_BATCH AS TARGET

    SET VALIDATION_ERROR =
        'Source record has already been processed successfully.'

    WHERE TARGET.VALIDATION_ERROR IS NULL

      AND EXISTS
      (
          SELECT 1

          FROM CONTROL.CSV_PROCESSED_RECORDS AS PROCESSED

          WHERE PROCESSED.PIPELINE_NAME =
                    'LEARNER_INFORMATION'

            AND PROCESSED.SOURCE_RECORD_ID =
                    TARGET.SOURCE_RECORD_ID
      );


    /* Store invalid records and their rejection reasons. */

    INSERT INTO CONTROL.CSV_REJECTED_RECORDS
    (
        REJECTION_ID,
        PIPELINE_NAME,
        SOURCE_RECORD_ID,
        SOURCE_FILE_NAME,
        SOURCE_ROW_NUMBER,
        RAW_RECORD,
        REJECTION_REASON,
        REJECTED_AT,
        RESOLVED_FLAG
    )

    SELECT
        'REJ_' ||
        REPLACE(
            UUID_STRING(),
            '-',
            ''
        ),

        'LEARNER_INFORMATION',

        SOURCE_RECORD_ID,

        SOURCE_FILE_NAME,

        SOURCE_ROW_NUMBER,

        OBJECT_CONSTRUCT_KEEP_NULL(
            'SOURCE_RECORD_ID',
                SOURCE_RECORD_ID,

            'EMPLOYEE_ID',
                EMPLOYEE_ID,

            'LEARNER_NAME',
                LEARNER_NAME,

            'EMAIL',
                EMAIL,

            'DEPARTMENT_NAME',
                DEPARTMENT_NAME,

            'SNOWFLAKE_EXPERIENCE_YEARS',
                SNOWFLAKE_EXPERIENCE_YEARS
        ),

        VALIDATION_ERROR,

        CURRENT_TIMESTAMP(),

        FALSE

    FROM TMP_LEARNER_INFORMATION_BATCH

    WHERE VALIDATION_ERROR IS NOT NULL;


    /* Count rejected records. */

    SELECT COUNT(*)
    INTO :V_REJECTED

    FROM TMP_LEARNER_INFORMATION_BATCH

    WHERE VALIDATION_ERROR IS NOT NULL;


    /* Select valid records into a RESULTSET. */

    V_VALID_ROWS :=
    (
        SELECT
            SOURCE_RECORD_ID,
            EMPLOYEE_ID,
            LEARNER_NAME,
            EMAIL,
            DEPARTMENT_NAME,

            TRY_TO_DECIMAL(
                SNOWFLAKE_EXPERIENCE_YEARS,
                4,
                1
            ) AS EXPERIENCE_YEARS

        FROM TMP_LEARNER_INFORMATION_BATCH

        WHERE VALIDATION_ERROR IS NULL

        ORDER BY SOURCE_ROW_NUMBER
    );


    /* Register each valid learner. */

    FOR RECORD_ITEM IN V_VALID_ROWS

    DO

        V_SOURCE_RECORD_ID :=
            RECORD_ITEM.SOURCE_RECORD_ID;

        V_EMPLOYEE_ID :=
            RECORD_ITEM.EMPLOYEE_ID;

        V_LEARNER_NAME :=
            RECORD_ITEM.LEARNER_NAME;

        V_EMAIL :=
            RECORD_ITEM.EMAIL;

        V_DEPARTMENT_NAME :=
            RECORD_ITEM.DEPARTMENT_NAME;

        V_EXPERIENCE_YEARS :=
            RECORD_ITEM.EXPERIENCE_YEARS;


        CALL CONTROL.REGISTER_LEARNER(
            :V_EMPLOYEE_ID,
            :V_LEARNER_NAME,
            :V_EMAIL,
            :V_DEPARTMENT_NAME,
            :V_EXPERIENCE_YEARS
        )
        INTO :V_REGISTRATION_RESULT;


        INSERT INTO CONTROL.CSV_PROCESSED_RECORDS
        (
            PIPELINE_NAME,
            SOURCE_RECORD_ID,
            PROCESSED_AT,
            PROCESSING_RESULT
        )

        VALUES
        (
            'LEARNER_INFORMATION',
            :V_SOURCE_RECORD_ID,
            CURRENT_TIMESTAMP(),
            :V_REGISTRATION_RESULT
        );


        V_ACCEPTED :=
            V_ACCEPTED + 1;

    END FOR;


    /* Record the successful pipeline run. */

    INSERT INTO CONTROL.CSV_PIPELINE_RUN_LOG
    (
        RUN_ID,
        PIPELINE_NAME,
        STARTED_AT,
        COMPLETED_AT,
        RUN_STATUS,
        RECORDS_RECEIVED,
        RECORDS_ACCEPTED,
        RECORDS_REJECTED,
        RUN_MESSAGE
    )

    VALUES
    (
        :V_RUN_ID,
        'LEARNER_INFORMATION',
        :V_STARTED_AT,
        CURRENT_TIMESTAMP(),
        'SUCCESS',
        :V_RECEIVED,
        :V_ACCEPTED,
        :V_REJECTED,
        'Learner-information processing completed.'
    );


    RETURN
        'Learner pipeline completed. Received: ' ||
        V_RECEIVED ||
        ', accepted: ' ||
        V_ACCEPTED ||
        ', rejected: ' ||
        V_REJECTED ||
        '.';

EXCEPTION

    WHEN OTHER THEN

        INSERT INTO CONTROL.CSV_PIPELINE_RUN_LOG
        (
            RUN_ID,
            PIPELINE_NAME,
            STARTED_AT,
            COMPLETED_AT,
            RUN_STATUS,
            RECORDS_RECEIVED,
            RECORDS_ACCEPTED,
            RECORDS_REJECTED,
            RUN_MESSAGE
        )

        VALUES
        (
            :V_RUN_ID,
            'LEARNER_INFORMATION',
            :V_STARTED_AT,
            CURRENT_TIMESTAMP(),
            'FAILED',
            :V_RECEIVED,
            :V_ACCEPTED,
            :V_REJECTED,
            :SQLERRM
        );


        RETURN
            'Learner pipeline failed: ' ||
            SQLERRM;

END;
$$;


/*------------------------------------------------------------------------------
  9. Create the scheduled processing Task

  The Task remains suspended until testing is complete.
------------------------------------------------------------------------------*/

CREATE OR REPLACE TASK CONTROL.PROCESS_LEARNER_INFORMATION_TASK
    WAREHOUSE = SNOWPRO_LEARNING_WH
    SCHEDULE = '1 MINUTE'

    WHEN SYSTEM$STREAM_HAS_DATA(
        'SNOWPRO_ENABLEMENT.RAW.LEARNER_INFORMATION_STREAM'
    )

    AS

    CALL CONTROL.PROCESS_LEARNER_INFORMATION();


/*------------------------------------------------------------------------------
  10. Verify the created objects
------------------------------------------------------------------------------*/

SHOW FILE FORMATS LIKE 'CERTIFICATION_CSV_FORMAT'
IN SCHEMA SNOWPRO_ENABLEMENT.RAW;

SHOW STAGES LIKE 'CERTIFICATION_UPLOAD_STAGE'
IN SCHEMA SNOWPRO_ENABLEMENT.RAW;

SHOW TABLES LIKE 'LEARNER_INFORMATION_INBOX'
IN SCHEMA SNOWPRO_ENABLEMENT.RAW;

SHOW STREAMS LIKE 'LEARNER_INFORMATION_STREAM'
IN SCHEMA SNOWPRO_ENABLEMENT.RAW;

SHOW PROCEDURES LIKE 'PROCESS_LEARNER_INFORMATION'
IN SCHEMA SNOWPRO_ENABLEMENT.CONTROL;

SHOW TASKS LIKE 'PROCESS_LEARNER_INFORMATION_TASK'
IN SCHEMA SNOWPRO_ENABLEMENT.CONTROL;