/*==============================================================================
  SnowPro Core Enablement Platform
  Step 17: Learning activity processing pipeline

  Purpose:
  - Record learner study activities.
  - Detect new activities using a Stream.
  - Update topic progress.
  - Process activities automatically using a Task.
==============================================================================*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SNOWPRO_LEARNING_WH;
USE DATABASE SNOWPRO_ENABLEMENT;


/*------------------------------------------------------------------------------
  1. Create an append-only Stream on learning events
------------------------------------------------------------------------------*/

CREATE STREAM IF NOT EXISTS CORE.LEARNING_EVENTS_STREAM
ON TABLE CORE.LEARNING_EVENTS
APPEND_ONLY = TRUE;


/*------------------------------------------------------------------------------
  2. Create the procedure used to record a learner activity
------------------------------------------------------------------------------*/

CREATE OR REPLACE PROCEDURE CONTROL.RECORD_LEARNING_ACTIVITY(
    P_ENROLLMENT_ID VARCHAR,
    P_TOPIC_ID VARCHAR,
    P_EVENT_TYPE VARCHAR,
    P_DURATION_MINUTES NUMBER,
    P_COMPLETION_PERCENT NUMBER,
    P_NOTES VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
    V_EVENT_ID VARCHAR;
    V_FINAL_COMPLETION NUMBER(5,2);
    V_PROGRESS_RECORD_COUNT NUMBER;

BEGIN

    /* Confirm that the topic is assigned to this enrollment */

    SELECT COUNT(*)
    INTO :V_PROGRESS_RECORD_COUNT
    FROM CORE.TOPIC_PROGRESS
    WHERE ENROLLMENT_ID = :P_ENROLLMENT_ID
      AND TOPIC_ID = :P_TOPIC_ID;


    IF (V_PROGRESS_RECORD_COUNT = 0) THEN

        RETURN
            'Activity rejected: The topic is not assigned to this enrollment.';

    END IF;


    /* Validate the activity type */

    IF (
        UPPER(TRIM(P_EVENT_TYPE)) NOT IN (
            'STARTED',
            'STUDIED',
            'PROGRESS_UPDATED',
            'COMPLETED'
        )
    ) THEN

        RETURN
            'Activity rejected: Use STARTED, STUDIED, PROGRESS_UPDATED or COMPLETED.';

    END IF;


    /* Validate the study duration */

    IF (
        P_DURATION_MINUTES IS NOT NULL
        AND P_DURATION_MINUTES < 0
    ) THEN

        RETURN
            'Activity rejected: Duration cannot be negative.';

    END IF;


    /* Completed activities are always stored as 100 percent */

    V_FINAL_COMPLETION :=
        CASE
            WHEN UPPER(TRIM(P_EVENT_TYPE)) = 'COMPLETED'
                THEN 100
            ELSE COALESCE(P_COMPLETION_PERCENT, 0)
        END;


    /* Validate the completion percentage */

    IF (
        V_FINAL_COMPLETION < 0
        OR V_FINAL_COMPLETION > 100
    ) THEN

        RETURN
            'Activity rejected: Completion percentage must be between 0 and 100.';

    END IF;


    /* Generate a unique event ID */

    V_EVENT_ID :=
        'EVT_' ||
        REPLACE(UUID_STRING(), '-', '');


    /* Insert the activity into the learning-events table */

    INSERT INTO CORE.LEARNING_EVENTS (
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
    VALUES (
        :V_EVENT_ID,
        :P_ENROLLMENT_ID,
        :P_TOPIC_ID,
        UPPER(TRIM(:P_EVENT_TYPE)),
        CURRENT_TIMESTAMP(),
        COALESCE(:P_DURATION_MINUTES, 0),
        :V_FINAL_COMPLETION,
        'RECORD_LEARNING_ACTIVITY',
        :P_NOTES,
        NULL
    );


    RETURN
        'Activity recorded successfully. Event ID: ' ||
        V_EVENT_ID;

END;
$$;


/*------------------------------------------------------------------------------
  3. Create the procedure that processes new learning events
------------------------------------------------------------------------------*/

CREATE OR REPLACE PROCEDURE CONTROL.PROCESS_LEARNING_EVENTS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
    V_ROWS_PROCESSED NUMBER DEFAULT 0;

BEGIN

    MERGE INTO CORE.TOPIC_PROGRESS AS TARGET

    USING (
        SELECT
            ENROLLMENT_ID,
            TOPIC_ID,

            SUM(
                COALESCE(DURATION_MINUTES, 0)
            ) / 60.0 AS ADDITIONAL_HOURS,

            MAX(
                COALESCE(COMPLETION_PERCENT, 0)
            ) AS NEW_COMPLETION_PERCENT,

            MIN(EVENT_TIMESTAMP) AS FIRST_ACTIVITY_AT,

            MAX(EVENT_TIMESTAMP) AS LAST_ACTIVITY_AT

        FROM CORE.LEARNING_EVENTS_STREAM

        GROUP BY
            ENROLLMENT_ID,
            TOPIC_ID
    ) AS SOURCE

    ON TARGET.ENROLLMENT_ID = SOURCE.ENROLLMENT_ID
    AND TARGET.TOPIC_ID = SOURCE.TOPIC_ID


    WHEN MATCHED THEN

        UPDATE SET

            HOURS_SPENT =
                COALESCE(TARGET.HOURS_SPENT, 0) +
                SOURCE.ADDITIONAL_HOURS,

            COMPLETION_PERCENT =
                GREATEST(
                    COALESCE(
                        TARGET.COMPLETION_PERCENT,
                        0
                    ),
                    SOURCE.NEW_COMPLETION_PERCENT
                ),

            PROGRESS_STATUS =
                CASE

                    WHEN GREATEST(
                        COALESCE(
                            TARGET.COMPLETION_PERCENT,
                            0
                        ),
                        SOURCE.NEW_COMPLETION_PERCENT
                    ) >= 100

                        THEN 'COMPLETED'


                    WHEN GREATEST(
                        COALESCE(
                            TARGET.COMPLETION_PERCENT,
                            0
                        ),
                        SOURCE.NEW_COMPLETION_PERCENT
                    ) > 0

                    OR SOURCE.ADDITIONAL_HOURS > 0

                        THEN 'IN_PROGRESS'


                    ELSE TARGET.PROGRESS_STATUS

                END,

            STARTED_AT =
                COALESCE(
                    TARGET.STARTED_AT,
                    SOURCE.FIRST_ACTIVITY_AT
                ),

            COMPLETED_AT =
                CASE

                    WHEN GREATEST(
                        COALESCE(
                            TARGET.COMPLETION_PERCENT,
                            0
                        ),
                        SOURCE.NEW_COMPLETION_PERCENT
                    ) >= 100

                        THEN COALESCE(
                            TARGET.COMPLETED_AT,
                            SOURCE.LAST_ACTIVITY_AT
                        )

                    ELSE TARGET.COMPLETED_AT

                END,

            LAST_ACTIVITY_AT =
                SOURCE.LAST_ACTIVITY_AT,

            UPDATED_AT =
                CURRENT_TIMESTAMP()


    WHEN NOT MATCHED THEN

        INSERT (
            ENROLLMENT_ID,
            TOPIC_ID,
            PROGRESS_STATUS,
            COMPLETION_PERCENT,
            HOURS_SPENT,
            STARTED_AT,
            COMPLETED_AT,
            LAST_ACTIVITY_AT,
            UPDATED_AT
        )

        VALUES (
            SOURCE.ENROLLMENT_ID,
            SOURCE.TOPIC_ID,

            CASE

                WHEN SOURCE.NEW_COMPLETION_PERCENT >= 100

                    THEN 'COMPLETED'

                WHEN SOURCE.NEW_COMPLETION_PERCENT > 0
                     OR SOURCE.ADDITIONAL_HOURS > 0

                    THEN 'IN_PROGRESS'

                ELSE 'NOT_STARTED'

            END,

            SOURCE.NEW_COMPLETION_PERCENT,
            SOURCE.ADDITIONAL_HOURS,
            SOURCE.FIRST_ACTIVITY_AT,

            CASE

                WHEN SOURCE.NEW_COMPLETION_PERCENT >= 100

                    THEN SOURCE.LAST_ACTIVITY_AT

                ELSE NULL

            END,

            SOURCE.LAST_ACTIVITY_AT,
            CURRENT_TIMESTAMP()
        );


    V_ROWS_PROCESSED := SQLROWCOUNT;


    RETURN
        'Learning events processed successfully. Progress records affected: ' ||
        V_ROWS_PROCESSED;

END;
$$;


/*------------------------------------------------------------------------------
  4. Create the scheduled Task

  The Task checks every five minutes. The warehouse runs only when the Stream
  contains a new learning activity.
------------------------------------------------------------------------------*/

CREATE OR REPLACE TASK CONTROL.PROCESS_LEARNING_EVENTS_TASK
    WAREHOUSE = SNOWPRO_LEARNING_WH
    SCHEDULE = '5 MINUTE'

    WHEN SYSTEM$STREAM_HAS_DATA(
        'SNOWPRO_ENABLEMENT.CORE.LEARNING_EVENTS_STREAM'
    )

AS
    CALL CONTROL.PROCESS_LEARNING_EVENTS();


/*------------------------------------------------------------------------------
  5. Enable automatic learning-event processing
------------------------------------------------------------------------------*/

ALTER TASK CONTROL.PROCESS_LEARNING_EVENTS_TASK
RESUME;


/*------------------------------------------------------------------------------
  6. Verify the created objects
------------------------------------------------------------------------------*/

SHOW STREAMS LIKE 'LEARNING_EVENTS_STREAM'
IN SCHEMA SNOWPRO_ENABLEMENT.CORE;


SHOW PROCEDURES LIKE '%LEARNING_ACTIVITY%'
IN SCHEMA SNOWPRO_ENABLEMENT.CONTROL;


SHOW PROCEDURES LIKE 'PROCESS_LEARNING_EVENTS'
IN SCHEMA SNOWPRO_ENABLEMENT.CONTROL;


SHOW TASKS LIKE 'PROCESS_LEARNING_EVENTS_TASK'
IN SCHEMA SNOWPRO_ENABLEMENT.CONTROL;