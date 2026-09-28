/*==============================================================================
  Snowflake Certification Enablement Platform
  Step 17: Weekly learner progress reminders

  Purpose:
  - Identify active learners who need a progress reminder.
  - Support reminders for inactive learners or all active learners.
  - Support simulation mode before real emails are enabled.
  - Send weekly emails using a Snowflake notification integration.
  - Record every reminder attempt in an audit table.

  Default behavior:
  - Reminder mode: INACTIVE_ONLY
  - Inactivity period: 7 days
  - Real email sending: Disabled
  - Task schedule: Every Monday at 9:00 AM India time
==============================================================================*/


/*------------------------------------------------------------------------------
  1. Select the required Snowflake environment
------------------------------------------------------------------------------*/

USE ROLE ACCOUNTADMIN;

USE WAREHOUSE WH_CERT_ENABLEMENT_DEV_XS;

USE DATABASE DB_CERT_ENABLEMENT_DEV;

USE SCHEMA CONTROL;


/*==============================================================================
  2. EMAIL NOTIFICATION INTEGRATION
==============================================================================*/

/*------------------------------------------------------------------------------
  Snowflake email requirements:

  - The recipient must be a user in the same Snowflake account.
  - The recipient's email address must be verified.
  - The notification integration must be enabled.

  ALLOWED_RECIPIENTS is not specified here because real learner email
  addresses will be added later.

  Real email sending remains disabled in the configuration table until the
  recipient setup has been verified.
------------------------------------------------------------------------------*/

CREATE NOTIFICATION INTEGRATION IF NOT EXISTS
    NI_CERT_ENABLEMENT_EMAIL_DEV

    TYPE = EMAIL

    ENABLED = TRUE

    COMMENT =
        'Email integration for weekly certification progress reminders';


/*==============================================================================
  3. REMINDER CONFIGURATION
==============================================================================*/

/*------------------------------------------------------------------------------
  REMINDER_MODE values:

  INACTIVE_ONLY
  - Send reminders only when the learner has not recorded activity within
    the configured number of days.

  ALL_ACTIVE
  - Send reminders to every active learner.

  SEND_ENABLED values:

  FALSE
  - Simulation mode. Candidates are identified and logged, but no email
    is sent.

  TRUE
  - Live mode. Snowflake attempts to send the email.
------------------------------------------------------------------------------*/

CREATE TABLE IF NOT EXISTS CONTROL.REMINDER_CONFIGURATION (
    CONFIG_ID                  VARCHAR(50)    NOT NULL,
    REMINDER_MODE              VARCHAR(30)    NOT NULL,
    INACTIVITY_DAYS            NUMBER(3,0)    NOT NULL,
    EMAIL_INTEGRATION_NAME     VARCHAR(200)   NOT NULL,
    SEND_ENABLED               BOOLEAN        DEFAULT FALSE,
    ACTIVE_FLAG                BOOLEAN        DEFAULT TRUE,
    CREATED_AT                 TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT                 TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_REMINDER_CONFIGURATION
        PRIMARY KEY (CONFIG_ID)
);


/*------------------------------------------------------------------------------
  Create the default reminder configuration.

  The MERGE prevents duplicate configuration rows when the deployment script
  is executed more than once.
------------------------------------------------------------------------------*/

MERGE INTO CONTROL.REMINDER_CONFIGURATION AS TARGET

USING (
    SELECT
        'WEEKLY_PROGRESS_REMINDER' AS CONFIG_ID,
        'INACTIVE_ONLY' AS REMINDER_MODE,
        7 AS INACTIVITY_DAYS,
        'NI_CERT_ENABLEMENT_EMAIL_DEV'
            AS EMAIL_INTEGRATION_NAME,
        FALSE AS SEND_ENABLED,
        TRUE AS ACTIVE_FLAG
) AS SOURCE

ON TARGET.CONFIG_ID = SOURCE.CONFIG_ID

WHEN MATCHED THEN

    UPDATE SET
        REMINDER_MODE =
            SOURCE.REMINDER_MODE,

        INACTIVITY_DAYS =
            SOURCE.INACTIVITY_DAYS,

        EMAIL_INTEGRATION_NAME =
            SOURCE.EMAIL_INTEGRATION_NAME,

        ACTIVE_FLAG =
            SOURCE.ACTIVE_FLAG,

        UPDATED_AT =
            CURRENT_TIMESTAMP()

WHEN NOT MATCHED THEN

    INSERT (
        CONFIG_ID,
        REMINDER_MODE,
        INACTIVITY_DAYS,
        EMAIL_INTEGRATION_NAME,
        SEND_ENABLED,
        ACTIVE_FLAG,
        CREATED_AT,
        UPDATED_AT
    )

    VALUES (
        SOURCE.CONFIG_ID,
        SOURCE.REMINDER_MODE,
        SOURCE.INACTIVITY_DAYS,
        SOURCE.EMAIL_INTEGRATION_NAME,
        SOURCE.SEND_ENABLED,
        SOURCE.ACTIVE_FLAG,
        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP()
    );


/*==============================================================================
  4. REMINDER NOTIFICATION LOG
==============================================================================*/

/*------------------------------------------------------------------------------
  Records every simulated, sent or failed reminder.

  REMINDER_STATUS values:

  SIMULATED
  - Learner was identified, but real sending was disabled.

  SENT
  - Snowflake successfully submitted the email.

  FAILED
  - Snowflake could not send the email.
------------------------------------------------------------------------------*/

CREATE TABLE IF NOT EXISTS CONTROL.REMINDER_NOTIFICATION_LOG (
    REMINDER_ID                VARCHAR(50)    NOT NULL,
    ENROLLMENT_ID              VARCHAR(30)    NOT NULL,
    LEARNER_ID                 VARCHAR(30)    NOT NULL,
    EMPLOYEE_ID                VARCHAR(50)    NOT NULL,
    RECIPIENT_EMAIL            VARCHAR(320)   NOT NULL,
    REMINDER_STATUS            VARCHAR(30)    NOT NULL,
    REMINDER_SUBJECT           VARCHAR(256),
    FAILURE_MESSAGE            VARCHAR(2000),
    LAST_ACTIVITY_AT           TIMESTAMP_NTZ,
    REMINDER_SENT_AT           TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_REMINDER_NOTIFICATION_LOG
        PRIMARY KEY (REMINDER_ID)
);


/*==============================================================================
  5. REMINDER-CANDIDATE VIEW
==============================================================================*/

/*------------------------------------------------------------------------------
  The view identifies learners who should receive a weekly reminder.

  A learner is eligible when:

  - The learner is active.
  - The enrollment is active.
  - The target completion date has not passed.
  - The reminder configuration is active.
  - The configured reminder rule is satisfied.
  - A successful reminder was not already sent in the last six days.
------------------------------------------------------------------------------*/

CREATE OR REPLACE VIEW
ANALYTICS.VW_WEEKLY_REMINDER_CANDIDATES
AS

WITH LAST_LEARNING_ACTIVITY AS (
    SELECT
        ENROLLMENT_ID,
        MAX(EVENT_TIMESTAMP) AS LAST_ACTIVITY_AT

    FROM CORE.LEARNING_EVENTS

    GROUP BY
        ENROLLMENT_ID
)

SELECT
    L.LEARNER_ID,
    L.EMPLOYEE_ID,
    L.LEARNER_NAME,
    L.EMAIL,
    E.ENROLLMENT_ID,
    E.CERTIFICATION_ID,
    E.POD_ID,
    E.TARGET_COMPLETION_DATE,
    E.TARGET_EXAM_DATE,
    A.LAST_ACTIVITY_AT,

    DATEDIFF(
        'DAY',
        COALESCE(
            TO_DATE(A.LAST_ACTIVITY_AT),
            E.ENROLLED_DATE
        ),
        CURRENT_DATE()
    ) AS DAYS_SINCE_LAST_ACTIVITY,

    C.REMINDER_MODE,
    C.INACTIVITY_DAYS,
    C.EMAIL_INTEGRATION_NAME,
    C.SEND_ENABLED

FROM CORE.LEARNERS L

JOIN CORE.ENROLLMENTS E
    ON L.LEARNER_ID = E.LEARNER_ID

LEFT JOIN LAST_LEARNING_ACTIVITY A
    ON E.ENROLLMENT_ID = A.ENROLLMENT_ID

CROSS JOIN CONTROL.REMINDER_CONFIGURATION C

WHERE L.ACTIVE_FLAG = TRUE

  AND E.ENROLLMENT_STATUS = 'ACTIVE'

  AND E.TARGET_COMPLETION_DATE >= CURRENT_DATE()

  AND C.CONFIG_ID = 'WEEKLY_PROGRESS_REMINDER'

  AND C.ACTIVE_FLAG = TRUE

  AND (
        UPPER(C.REMINDER_MODE) = 'ALL_ACTIVE'

        OR

        (
            UPPER(C.REMINDER_MODE) = 'INACTIVE_ONLY'

            AND DATEDIFF(
                    'DAY',
                    COALESCE(
                        TO_DATE(A.LAST_ACTIVITY_AT),
                        E.ENROLLED_DATE
                    ),
                    CURRENT_DATE()
                ) >= C.INACTIVITY_DAYS
        )
      )

  AND NOT EXISTS (
        SELECT
            1

        FROM CONTROL.REMINDER_NOTIFICATION_LOG RL

        WHERE RL.ENROLLMENT_ID = E.ENROLLMENT_ID
          AND RL.REMINDER_STATUS = 'SENT'
          AND RL.REMINDER_SENT_AT >=
              DATEADD(
                  'DAY',
                  -6,
                  CURRENT_TIMESTAMP()
              )
      );


/*==============================================================================
  6. WEEKLY REMINDER PROCEDURE
==============================================================================*/

CREATE OR REPLACE PROCEDURE
CONTROL.SP_SEND_CERT_ENABLEMENT_PROGRESS_REMINDERS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$

DECLARE
    V_CONFIG_COUNT              NUMBER DEFAULT 0;
    V_SEND_ENABLED              BOOLEAN;
    V_EMAIL_INTEGRATION_NAME    VARCHAR;

    V_CANDIDATE_COUNT           NUMBER DEFAULT 0;
    V_SENT_COUNT                NUMBER DEFAULT 0;
    V_SIMULATED_COUNT           NUMBER DEFAULT 0;
    V_FAILED_COUNT              NUMBER DEFAULT 0;

    V_REMINDER_ID               VARCHAR;
    V_LEARNER_ID                VARCHAR;
    V_EMPLOYEE_ID               VARCHAR;
    V_LEARNER_NAME              VARCHAR;
    V_EMAIL                     VARCHAR;
    V_ENROLLMENT_ID             VARCHAR;
    V_CERTIFICATION_ID          VARCHAR;
    V_TARGET_COMPLETION_DATE    DATE;
    V_LAST_ACTIVITY_AT          TIMESTAMP_NTZ;
    V_DAYS_INACTIVE             NUMBER;

    V_EMAIL_SUBJECT             VARCHAR;
    V_EMAIL_BODY                VARCHAR;
    V_SEND_RESULT               VARCHAR;
    V_FAILURE_MESSAGE           VARCHAR;

BEGIN

    /*--------------------------------------------------------------------------
      Check that an active reminder configuration exists
    --------------------------------------------------------------------------*/

    SELECT
        COUNT(*)

    INTO
        :V_CONFIG_COUNT

    FROM CONTROL.REMINDER_CONFIGURATION

    WHERE CONFIG_ID = 'WEEKLY_PROGRESS_REMINDER'
      AND ACTIVE_FLAG = TRUE;


    IF (V_CONFIG_COUNT = 0) THEN

        RETURN
            'Reminder processing stopped: No active reminder configuration exists.';

    END IF;


    /*--------------------------------------------------------------------------
      Read the current reminder configuration
    --------------------------------------------------------------------------*/

    SELECT
        SEND_ENABLED,
        EMAIL_INTEGRATION_NAME

    INTO
        :V_SEND_ENABLED,
        :V_EMAIL_INTEGRATION_NAME

    FROM CONTROL.REMINDER_CONFIGURATION

    WHERE CONFIG_ID = 'WEEKLY_PROGRESS_REMINDER'
      AND ACTIVE_FLAG = TRUE;


    /*--------------------------------------------------------------------------
      Process each eligible learner
    --------------------------------------------------------------------------*/

    FOR LEARNER_ITEM IN (
        SELECT
            LEARNER_ID,
            EMPLOYEE_ID,
            LEARNER_NAME,
            EMAIL,
            ENROLLMENT_ID,
            CERTIFICATION_ID,
            TARGET_COMPLETION_DATE,
            LAST_ACTIVITY_AT,
            DAYS_SINCE_LAST_ACTIVITY

        FROM ANALYTICS.VW_WEEKLY_REMINDER_CANDIDATES

        ORDER BY
            EMPLOYEE_ID
    )

    DO

        V_CANDIDATE_COUNT :=
            V_CANDIDATE_COUNT + 1;

        V_REMINDER_ID :=
            'REM_' ||
            REPLACE(
                UUID_STRING(),
                '-',
                ''
            );

        V_LEARNER_ID :=
            LEARNER_ITEM.LEARNER_ID;

        V_EMPLOYEE_ID :=
            LEARNER_ITEM.EMPLOYEE_ID;

        V_LEARNER_NAME :=
            LEARNER_ITEM.LEARNER_NAME;

        V_EMAIL :=
            LEARNER_ITEM.EMAIL;

        V_ENROLLMENT_ID :=
            LEARNER_ITEM.ENROLLMENT_ID;

        V_CERTIFICATION_ID :=
            LEARNER_ITEM.CERTIFICATION_ID;

        V_TARGET_COMPLETION_DATE :=
            LEARNER_ITEM.TARGET_COMPLETION_DATE;

        V_LAST_ACTIVITY_AT :=
            LEARNER_ITEM.LAST_ACTIVITY_AT;

        V_DAYS_INACTIVE :=
            LEARNER_ITEM.DAYS_SINCE_LAST_ACTIVITY;


        /*----------------------------------------------------------------------
          Prepare a simple email subject and message
        ----------------------------------------------------------------------*/

        V_EMAIL_SUBJECT :=
            'Weekly certification progress reminder';


        V_EMAIL_BODY :=
            'Hello ' ||
            V_LEARNER_NAME ||
            ',' ||
            CHR(10) ||
            CHR(10) ||
            'This is a weekly reminder to update your learning progress for ' ||
            V_CERTIFICATION_ID ||
            '.' ||
            CHR(10) ||
            CHR(10) ||
            'Target completion date: ' ||
            TO_VARCHAR(
                V_TARGET_COMPLETION_DATE,
                'YYYY-MM-DD'
            ) ||
            CHR(10) ||
            'Days since the last recorded activity: ' ||
            V_DAYS_INACTIVE ||
            CHR(10) ||
            CHR(10) ||
            'Please update the topics you have started or completed.' ||
            CHR(10) ||
            CHR(10) ||
            'Snowflake Certification Enablement Platform';


        /*----------------------------------------------------------------------
          Simulation mode

          The candidate is logged, but an email is not sent.
        ----------------------------------------------------------------------*/

        IF (V_SEND_ENABLED = FALSE) THEN

            INSERT INTO CONTROL.REMINDER_NOTIFICATION_LOG (
                REMINDER_ID,
                ENROLLMENT_ID,
                LEARNER_ID,
                EMPLOYEE_ID,
                RECIPIENT_EMAIL,
                REMINDER_STATUS,
                REMINDER_SUBJECT,
                FAILURE_MESSAGE,
                LAST_ACTIVITY_AT,
                REMINDER_SENT_AT
            )

            VALUES (
                :V_REMINDER_ID,
                :V_ENROLLMENT_ID,
                :V_LEARNER_ID,
                :V_EMPLOYEE_ID,
                :V_EMAIL,
                'SIMULATED',
                :V_EMAIL_SUBJECT,
                NULL,
                :V_LAST_ACTIVITY_AT,
                CURRENT_TIMESTAMP()
            );


            V_SIMULATED_COUNT :=
                V_SIMULATED_COUNT + 1;


        /*----------------------------------------------------------------------
          Live mode

          Snowflake attempts to send the email through the configured
          notification integration.
        ----------------------------------------------------------------------*/

        ELSE

            BEGIN

                V_FAILURE_MESSAGE := NULL;


                CALL SYSTEM$SEND_EMAIL(
                    :V_EMAIL_INTEGRATION_NAME,
                    :V_EMAIL,
                    :V_EMAIL_SUBJECT,
                    :V_EMAIL_BODY
                )
                INTO :V_SEND_RESULT;


                INSERT INTO CONTROL.REMINDER_NOTIFICATION_LOG (
                    REMINDER_ID,
                    ENROLLMENT_ID,
                    LEARNER_ID,
                    EMPLOYEE_ID,
                    RECIPIENT_EMAIL,
                    REMINDER_STATUS,
                    REMINDER_SUBJECT,
                    FAILURE_MESSAGE,
                    LAST_ACTIVITY_AT,
                    REMINDER_SENT_AT
                )

                VALUES (
                    :V_REMINDER_ID,
                    :V_ENROLLMENT_ID,
                    :V_LEARNER_ID,
                    :V_EMPLOYEE_ID,
                    :V_EMAIL,
                    'SENT',
                    :V_EMAIL_SUBJECT,
                    NULL,
                    :V_LAST_ACTIVITY_AT,
                    CURRENT_TIMESTAMP()
                );


                V_SENT_COUNT :=
                    V_SENT_COUNT + 1;


            EXCEPTION

                WHEN OTHER THEN

                    V_FAILURE_MESSAGE := SQLERRM;


                    INSERT INTO CONTROL.REMINDER_NOTIFICATION_LOG (
                        REMINDER_ID,
                        ENROLLMENT_ID,
                        LEARNER_ID,
                        EMPLOYEE_ID,
                        RECIPIENT_EMAIL,
                        REMINDER_STATUS,
                        REMINDER_SUBJECT,
                        FAILURE_MESSAGE,
                        LAST_ACTIVITY_AT,
                        REMINDER_SENT_AT
                    )

                    VALUES (
                        :V_REMINDER_ID,
                        :V_ENROLLMENT_ID,
                        :V_LEARNER_ID,
                        :V_EMPLOYEE_ID,
                        :V_EMAIL,
                        'FAILED',
                        :V_EMAIL_SUBJECT,
                        :V_FAILURE_MESSAGE,
                        :V_LAST_ACTIVITY_AT,
                        CURRENT_TIMESTAMP()
                    );


                    V_FAILED_COUNT :=
                        V_FAILED_COUNT + 1;

            END;

        END IF;

    END FOR;


    /*--------------------------------------------------------------------------
      Return the reminder-run result
    --------------------------------------------------------------------------*/

    RETURN
        'Weekly reminder processing completed. Candidates: ' ||
        V_CANDIDATE_COUNT ||
        ', emails sent: ' ||
        V_SENT_COUNT ||
        ', simulated: ' ||
        V_SIMULATED_COUNT ||
        ', failed: ' ||
        V_FAILED_COUNT ||
        '.';

END;
$$;


/*==============================================================================
  7. WEEKLY REMINDER TASK
==============================================================================*/

/*------------------------------------------------------------------------------
  Schedule:
  Every Monday at 9:00 AM, India time.

  The Task remains suspended after creation.
------------------------------------------------------------------------------*/

CREATE OR REPLACE TASK
CONTROL.TSK_SEND_PROGRESS_REMINDERS_WEEKLY

    WAREHOUSE = WH_CERT_ENABLEMENT_DEV_XS

    SCHEDULE =
        'USING CRON 0 9 * * MON Asia/Kolkata'

AS

    CALL CONTROL.SP_SEND_CERT_ENABLEMENT_PROGRESS_REMINDERS();


/*==============================================================================
  8. OPERATING COMMANDS
==============================================================================*/

/*------------------------------------------------------------------------------
  Test in simulation mode
------------------------------------------------------------------------------*/

/*
CALL CONTROL.SP_SEND_CERT_ENABLEMENT_PROGRESS_REMINDERS();
*/


/*------------------------------------------------------------------------------
  Review simulation or email results
------------------------------------------------------------------------------*/

/*
SELECT
    REMINDER_ID,
    EMPLOYEE_ID,
    RECIPIENT_EMAIL,
    REMINDER_STATUS,
    FAILURE_MESSAGE,
    REMINDER_SENT_AT

FROM CONTROL.REMINDER_NOTIFICATION_LOG

ORDER BY REMINDER_SENT_AT DESC;
*/


/*------------------------------------------------------------------------------
  Enable live email only after recipient emails have been verified
------------------------------------------------------------------------------*/

/*
UPDATE CONTROL.REMINDER_CONFIGURATION

SET
    SEND_ENABLED = TRUE,
    UPDATED_AT = CURRENT_TIMESTAMP()

WHERE CONFIG_ID = 'WEEKLY_PROGRESS_REMINDER';
*/


/*------------------------------------------------------------------------------
  Change the reminder rule to all active learners if required
------------------------------------------------------------------------------*/

/*
UPDATE CONTROL.REMINDER_CONFIGURATION

SET
    REMINDER_MODE = 'ALL_ACTIVE',
    UPDATED_AT = CURRENT_TIMESTAMP()

WHERE CONFIG_ID = 'WEEKLY_PROGRESS_REMINDER';
*/


/*------------------------------------------------------------------------------
  Resume the weekly Task after testing
------------------------------------------------------------------------------*/

/*
ALTER TASK
    CONTROL.TSK_SEND_PROGRESS_REMINDERS_WEEKLY
RESUME;
*/


/*------------------------------------------------------------------------------
  Suspend the weekly Task when it is not required
------------------------------------------------------------------------------*/

/*
ALTER TASK
    CONTROL.TSK_SEND_PROGRESS_REMINDERS_WEEKLY
SUSPEND;
*/


/*==============================================================================
  9. VERIFICATION COMMANDS
==============================================================================*/

SHOW NOTIFICATION INTEGRATIONS
LIKE 'NI_CERT_ENABLEMENT_EMAIL_DEV';

SHOW TABLES LIKE
    'REMINDER_CONFIGURATION'
IN SCHEMA DB_CERT_ENABLEMENT_DEV.CONTROL;

SHOW TABLES LIKE
    'REMINDER_NOTIFICATION_LOG'
IN SCHEMA DB_CERT_ENABLEMENT_DEV.CONTROL;

SHOW VIEWS LIKE
    'VW_WEEKLY_REMINDER_CANDIDATES'
IN SCHEMA DB_CERT_ENABLEMENT_DEV.ANALYTICS;

SHOW PROCEDURES LIKE
    'SP_SEND_CERT_ENABLEMENT_PROGRESS_REMINDERS'
IN SCHEMA DB_CERT_ENABLEMENT_DEV.CONTROL;

SHOW TASKS LIKE
    'TSK_SEND_PROGRESS_REMINDERS_WEEKLY'
IN SCHEMA DB_CERT_ENABLEMENT_DEV.CONTROL;