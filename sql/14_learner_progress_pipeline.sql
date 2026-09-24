/*==============================================================================
  Snowflake Certification Enablement Platform
  Learner Progress CSV Pipeline

  Purpose:
  - Receive learner progress through CSV files.
  - Load incoming progress into the RAW schema.
  - Validate learner, enrollment, topic and activity information.
  - Insert valid records into CORE.LEARNING_EVENTS.
  - Store invalid records with a rejection reason.
  - Record pipeline execution results.
==============================================================================*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SNOWPRO_LEARNING_WH;
USE DATABASE SNOWPRO_ENABLEMENT;


/*------------------------------------------------------------------------------
  1. Create the learner-progress RAW inbox
------------------------------------------------------------------------------*/

CREATE TABLE IF NOT EXISTS RAW.LEARNER_PROGRESS_INBOX
(
    ACTIVITY_ID             VARCHAR(100),
    EMPLOYEE_ID             VARCHAR(100),
    TOPIC_ID                VARCHAR(100),
    EVENT_TYPE              VARCHAR(50),
    DURATION_MINUTES        VARCHAR(50),
    COMPLETION_PERCENT      VARCHAR(50),
    ACTIVITY_TIMESTAMP      VARCHAR(100),
    NOTES                   VARCHAR(1000),

    SOURCE_FILE_NAME        VARCHAR(500),
    SOURCE_ROW_NUMBER       NUMBER,

    INGESTED_AT             TIMESTAMP_NTZ
        DEFAULT CURRENT_TIMESTAMP()
);


/*------------------------------------------------------------------------------
  2. Create a Stream on the learner-progress inbox
------------------------------------------------------------------------------*/

CREATE OR REPLACE STREAM RAW.LEARNER_PROGRESS_STREAM
    ON TABLE RAW.LEARNER_PROGRESS_INBOX
    APPEND_ONLY = TRUE;


/*------------------------------------------------------------------------------
  3. Create the learner-progress processing procedure
------------------------------------------------------------------------------*/

CREATE OR REPLACE PROCEDURE CONTROL.PROCESS_LEARNER_PROGRESS()
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

BEGIN

    /* Store the current Stream records in a temporary batch table. */

    CREATE OR REPLACE TEMPORARY TABLE TMP_LEARNER_PROGRESS_BATCH
    (
        ACTIVITY_ID             VARCHAR(100),
        EMPLOYEE_ID             VARCHAR(100),
        TOPIC_ID                VARCHAR(100),
        EVENT_TYPE              VARCHAR(50),
        DURATION_MINUTES        VARCHAR(50),
        COMPLETION_PERCENT      VARCHAR(50),
        ACTIVITY_TIMESTAMP      VARCHAR(100),
        NOTES                   VARCHAR(1000),

        SOURCE_FILE_NAME        VARCHAR(500),
        SOURCE_ROW_NUMBER       NUMBER,
        INGESTED_AT             TIMESTAMP_NTZ,

        ENROLLMENT_ID           VARCHAR(100),
        VALIDATION_ERROR        VARCHAR(2000)
    );


    /* Insert and consume the currently available Stream records. */

    INSERT INTO TMP_LEARNER_PROGRESS_BATCH
    (
        ACTIVITY_ID,
        EMPLOYEE_ID,
        TOPIC_ID,
        EVENT_TYPE,
        DURATION_MINUTES,
        COMPLETION_PERCENT,
        ACTIVITY_TIMESTAMP,
        NOTES,
        SOURCE_FILE_NAME,
        SOURCE_ROW_NUMBER,
        INGESTED_AT,
        ENROLLMENT_ID,
        VALIDATION_ERROR
    )

    SELECT
        TRIM(ACTIVITY_ID),
        TRIM(EMPLOYEE_ID),
        UPPER(TRIM(TOPIC_ID)),
        UPPER(TRIM(EVENT_TYPE)),
        TRIM(DURATION_MINUTES),
        TRIM(COMPLETION_PERCENT),
        TRIM(ACTIVITY_TIMESTAMP),
        TRIM(NOTES),
        SOURCE_FILE_NAME,
        SOURCE_ROW_NUMBER,
        INGESTED_AT,
        NULL,
        NULL

    FROM RAW.LEARNER_PROGRESS_STREAM

    WHERE METADATA$ACTION = 'INSERT';


    /* Count received records. */

    SELECT COUNT(*)
    INTO :V_RECEIVED
    FROM TMP_LEARNER_PROGRESS_BATCH;


    /* Validate required values and data types. */

    UPDATE TMP_LEARNER_PROGRESS_BATCH

    SET VALIDATION_ERROR =

        CASE

            WHEN ACTIVITY_ID IS NULL
                 OR ACTIVITY_ID = ''
                THEN
                    'Activity ID is required.'

            WHEN EMPLOYEE_ID IS NULL
                 OR EMPLOYEE_ID = ''
                THEN
                    'Employee ID is required.'

            WHEN TOPIC_ID IS NULL
                 OR TOPIC_ID = ''
                THEN
                    'Topic ID is required.'

            WHEN EVENT_TYPE IS NULL
                 OR EVENT_TYPE = ''
                THEN
                    'Event type is required.'

            WHEN EVENT_TYPE NOT IN
                 (
                     'STARTED',
                     'STUDIED',
                     'COMPLETED'
                 )
                THEN
                    'Event type must be STARTED, STUDIED or COMPLETED.'

            WHEN DURATION_MINUTES IS NULL
                 OR DURATION_MINUTES = ''
                THEN
                    'Duration in minutes is required.'

            WHEN TRY_TO_NUMBER(DURATION_MINUTES) IS NULL
                THEN
                    'Duration in minutes must be numeric.'

            WHEN TRY_TO_NUMBER(DURATION_MINUTES) < 0
                THEN
                    'Duration in minutes cannot be negative.'

            WHEN TRY_TO_NUMBER(DURATION_MINUTES) <>
                 FLOOR(
                     TRY_TO_NUMBER(DURATION_MINUTES)
                 )
                THEN
                    'Duration in minutes must be a whole number.'

            WHEN COMPLETION_PERCENT IS NULL
                 OR COMPLETION_PERCENT = ''
                THEN
                    'Completion percentage is required.'

            WHEN TRY_TO_DECIMAL(
                    COMPLETION_PERCENT,
                    5,
                    2
                 ) IS NULL
                THEN
                    'Completion percentage must be numeric.'

            WHEN TRY_TO_DECIMAL(
                    COMPLETION_PERCENT,
                    5,
                    2
                 ) < 0
                 OR
                 TRY_TO_DECIMAL(
                    COMPLETION_PERCENT,
                    5,
                    2
                 ) > 100
                THEN
                    'Completion percentage must be between 0 and 100.'

            WHEN ACTIVITY_TIMESTAMP IS NULL
                 OR ACTIVITY_TIMESTAMP = ''
                THEN
                    'Activity timestamp is required.'

            WHEN TRY_TO_TIMESTAMP_NTZ(
                    ACTIVITY_TIMESTAMP
                 ) IS NULL
                THEN
                    'Activity timestamp is invalid.'

            ELSE
                NULL

        END;


    /* Reject duplicate activity IDs within the same uploaded batch. */

    UPDATE TMP_LEARNER_PROGRESS_BATCH AS TARGET

    SET VALIDATION_ERROR =
        'Duplicate activity ID exists in the uploaded batch.'

    WHERE TARGET.VALIDATION_ERROR IS NULL

      AND TARGET.ACTIVITY_ID IN
      (
          SELECT ACTIVITY_ID

          FROM TMP_LEARNER_PROGRESS_BATCH

          GROUP BY ACTIVITY_ID

          HAVING COUNT(*) > 1
      );


    /* Prevent source activities already accepted earlier from repeating. */

    UPDATE TMP_LEARNER_PROGRESS_BATCH AS TARGET

    SET VALIDATION_ERROR =
        'Activity has already been processed successfully.'

    WHERE TARGET.VALIDATION_ERROR IS NULL

      AND EXISTS
      (
          SELECT 1

          FROM CONTROL.CSV_PROCESSED_RECORDS AS PROCESSED

          WHERE PROCESSED.PIPELINE_NAME =
                    'LEARNER_PROGRESS'

            AND PROCESSED.SOURCE_RECORD_ID =
                    TARGET.ACTIVITY_ID
      );


    /* Prevent activity IDs already present in CORE from repeating. */

    UPDATE TMP_LEARNER_PROGRESS_BATCH AS TARGET

    SET VALIDATION_ERROR =
        'Activity ID already exists in the learning-events table.'

    WHERE TARGET.VALIDATION_ERROR IS NULL

      AND EXISTS
      (
          SELECT 1

          FROM CORE.LEARNING_EVENTS AS LEARNING_EVENT

          WHERE LEARNING_EVENT.EVENT_ID =
                    TARGET.ACTIVITY_ID
      );


    /* Resolve employee IDs to their active SnowPro Core enrollment. */

    UPDATE TMP_LEARNER_PROGRESS_BATCH AS TARGET

    SET ENROLLMENT_ID =
        SOURCE.ENROLLMENT_ID

    FROM
    (
        SELECT
            LEARNER.EMPLOYEE_ID,
            ENROLLMENT.ENROLLMENT_ID

        FROM CORE.LEARNERS AS LEARNER

        JOIN CORE.ENROLLMENTS AS ENROLLMENT
            ON LEARNER.LEARNER_ID =
               ENROLLMENT.LEARNER_ID

        WHERE ENROLLMENT.CERTIFICATION_ID =
                    'CERT_SNOWPRO_CORE'

          AND ENROLLMENT.ENROLLMENT_STATUS =
                    'ACTIVE'

        QUALIFY
            ROW_NUMBER() OVER
            (
                PARTITION BY LEARNER.EMPLOYEE_ID
                ORDER BY ENROLLMENT.CREATED_AT DESC
            ) = 1
    ) AS SOURCE

    WHERE TARGET.VALIDATION_ERROR IS NULL

      AND TARGET.EMPLOYEE_ID =
            SOURCE.EMPLOYEE_ID;


    /* Reject records where an active enrollment cannot be found. */

    UPDATE TMP_LEARNER_PROGRESS_BATCH

    SET VALIDATION_ERROR =
        'No active SnowPro Core enrollment was found for the employee.'

    WHERE VALIDATION_ERROR IS NULL

      AND ENROLLMENT_ID IS NULL;


    /* Confirm that the topic is assigned to the learner. */

    UPDATE TMP_LEARNER_PROGRESS_BATCH AS TARGET

    SET VALIDATION_ERROR =
        'Topic is not assigned to the learner enrollment.'

    WHERE TARGET.VALIDATION_ERROR IS NULL

      AND NOT EXISTS
      (
          SELECT 1

          FROM CORE.TOPIC_PROGRESS AS PROGRESS

          WHERE PROGRESS.ENROLLMENT_ID =
                    TARGET.ENROLLMENT_ID

            AND PROGRESS.TOPIC_ID =
                    TARGET.TOPIC_ID
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

        'LEARNER_PROGRESS',

        ACTIVITY_ID,

        SOURCE_FILE_NAME,

        SOURCE_ROW_NUMBER,

        OBJECT_CONSTRUCT_KEEP_NULL(
            'ACTIVITY_ID',
                ACTIVITY_ID,

            'EMPLOYEE_ID',
                EMPLOYEE_ID,

            'TOPIC_ID',
                TOPIC_ID,

            'EVENT_TYPE',
                EVENT_TYPE,

            'DURATION_MINUTES',
                DURATION_MINUTES,

            'COMPLETION_PERCENT',
                COMPLETION_PERCENT,

            'ACTIVITY_TIMESTAMP',
                ACTIVITY_TIMESTAMP,

            'NOTES',
                NOTES
        ),

        VALIDATION_ERROR,

        CURRENT_TIMESTAMP(),

        FALSE

    FROM TMP_LEARNER_PROGRESS_BATCH

    WHERE VALIDATION_ERROR IS NOT NULL;


    /* Count rejected records. */

    SELECT COUNT(*)
    INTO :V_REJECTED

    FROM TMP_LEARNER_PROGRESS_BATCH

    WHERE VALIDATION_ERROR IS NOT NULL;


    /* Count valid records. */

    SELECT COUNT(*)
    INTO :V_ACCEPTED

    FROM TMP_LEARNER_PROGRESS_BATCH

    WHERE VALIDATION_ERROR IS NULL;


    /* Insert valid activity into the existing learning-events table. */

    INSERT INTO CORE.LEARNING_EVENTS
    (
        EVENT_ID,
        ENROLLMENT_ID,
        TOPIC_ID,
        EVENT_TYPE,
        EVENT_TIMESTAMP,
        DURATION_MINUTES,
        COMPLETION_PERCENT,
        EVENT_SOURCE,
        NOTES,
        PROCESSED_AT
    )

    SELECT
        ACTIVITY_ID,

        ENROLLMENT_ID,

        TOPIC_ID,

        EVENT_TYPE,

        TRY_TO_TIMESTAMP_NTZ(
            ACTIVITY_TIMESTAMP
        ),

        TRY_TO_NUMBER(
            DURATION_MINUTES
        ),

        TRY_TO_DECIMAL(
            COMPLETION_PERCENT,
            5,
            2
        ),

        'CSV_UPLOAD',

        NOTES,

        CURRENT_TIMESTAMP()

    FROM TMP_LEARNER_PROGRESS_BATCH

    WHERE VALIDATION_ERROR IS NULL;


    /* Record successfully accepted activity IDs. */

    INSERT INTO CONTROL.CSV_PROCESSED_RECORDS
    (
        PIPELINE_NAME,
        SOURCE_RECORD_ID,
        PROCESSED_AT,
        PROCESSING_RESULT
    )

    SELECT
        'LEARNER_PROGRESS',

        ACTIVITY_ID,

        CURRENT_TIMESTAMP(),

        'Learning activity accepted and inserted into CORE.LEARNING_EVENTS.'

    FROM TMP_LEARNER_PROGRESS_BATCH

    WHERE VALIDATION_ERROR IS NULL;


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
        'LEARNER_PROGRESS',
        :V_STARTED_AT,
        CURRENT_TIMESTAMP(),
        'SUCCESS',
        :V_RECEIVED,
        :V_ACCEPTED,
        :V_REJECTED,
        'Learner-progress processing completed.'
    );


    RETURN
        'Progress pipeline completed. Received: ' ||
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
            'LEARNER_PROGRESS',
            :V_STARTED_AT,
            CURRENT_TIMESTAMP(),
            'FAILED',
            :V_RECEIVED,
            :V_ACCEPTED,
            :V_REJECTED,
            :SQLERRM
        );


        RETURN
            'Progress pipeline failed: ' ||
            SQLERRM;

END;
$$;


/*------------------------------------------------------------------------------
  4. Create the scheduled progress-ingestion Task

  This Task remains suspended until testing is complete.
------------------------------------------------------------------------------*/

CREATE OR REPLACE TASK CONTROL.PROCESS_LEARNER_PROGRESS_TASK
    WAREHOUSE = SNOWPRO_LEARNING_WH
    SCHEDULE = '1 MINUTE'

    WHEN SYSTEM$STREAM_HAS_DATA(
        'SNOWPRO_ENABLEMENT.RAW.LEARNER_PROGRESS_STREAM'
    )

    AS

    CALL CONTROL.PROCESS_LEARNER_PROGRESS();


/*------------------------------------------------------------------------------
  5. Verify the created objects
------------------------------------------------------------------------------*/

SHOW TABLES LIKE 'LEARNER_PROGRESS_INBOX'
IN SCHEMA SNOWPRO_ENABLEMENT.RAW;

SHOW STREAMS LIKE 'LEARNER_PROGRESS_STREAM'
IN SCHEMA SNOWPRO_ENABLEMENT.RAW;

SHOW PROCEDURES LIKE 'PROCESS_LEARNER_PROGRESS'
IN SCHEMA SNOWPRO_ENABLEMENT.CONTROL;

SHOW TASKS LIKE 'PROCESS_LEARNER_PROGRESS_TASK'
IN SCHEMA SNOWPRO_ENABLEMENT.CONTROL;