/*==============================================================================
  Snowflake Certification Enablement Platform
  Step 16: Pod and certification-nomination CSV pipeline

  Purpose:
  - Receive Pod configuration through CSV.
  - Receive Pod Lead certification nominations through CSV.
  - Detect new rows using Snowflake Streams.
  - Validate and process the records using stored procedures.
  - Create dynamic learner plans.
  - Record accepted, rejected and pipeline-run details.
==============================================================================*/


/*------------------------------------------------------------------------------
  1. Select the required environment
------------------------------------------------------------------------------*/

USE ROLE ACCOUNTADMIN;

USE WAREHOUSE WH_CERT_ENABLEMENT_DEV_XS;

USE DATABASE DB_CERT_ENABLEMENT_DEV;

USE SCHEMA RAW;


/*==============================================================================
  2. RAW POD CONFIGURATION INBOX
==============================================================================*/

CREATE TABLE IF NOT EXISTS RAW.POD_CONFIGURATION_INBOX (
    POD_ID                    VARCHAR(30),
    POD_NAME                  VARCHAR(200),
    POD_LEAD_EMPLOYEE_ID      VARCHAR(50),
    POD_LEAD_NAME             VARCHAR(200),
    POD_LEAD_EMAIL            VARCHAR(320),
    ACTIVE_FLAG               VARCHAR(10),
    SOURCE_FILE_NAME          VARCHAR(500),
    LOADED_AT                 TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);


/*==============================================================================
  3. RAW CERTIFICATION NOMINATION INBOX
==============================================================================*/

CREATE TABLE IF NOT EXISTS RAW.CERTIFICATION_NOMINATIONS_INBOX (
    SOURCE_RECORD_ID                VARCHAR(50),
    EMPLOYEE_ID                     VARCHAR(50),
    LEARNER_NAME                    VARCHAR(200),
    EMAIL                           VARCHAR(320),
    DEPARTMENT_NAME                 VARCHAR(200),
    SNOWFLAKE_EXPERIENCE_YEARS      VARCHAR(20),
    POD_ID                          VARCHAR(30),
    POD_LEAD_EMPLOYEE_ID            VARCHAR(50),
    CERTIFICATION_ID                VARCHAR(20),
    TARGET_COMPLETION_DATE          VARCHAR(30),
    TARGET_EXAM_DATE                VARCHAR(30),
    NOMINATION_REASON               VARCHAR(1000),
    SOURCE_FILE_NAME                VARCHAR(500),
    LOADED_AT                       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);


/*==============================================================================
  4. STREAMS

  These Streams detect newly inserted CSV rows.
==============================================================================*/

CREATE OR REPLACE STREAM RAW.STR_POD_CONFIGURATION_INBOX
    ON TABLE RAW.POD_CONFIGURATION_INBOX
    APPEND_ONLY = TRUE;


CREATE OR REPLACE STREAM RAW.STR_CERTIFICATION_NOMINATIONS_INBOX
    ON TABLE RAW.CERTIFICATION_NOMINATIONS_INBOX
    APPEND_ONLY = TRUE;


/*==============================================================================
  5. POD AND NOMINATION PROCESSING PROCEDURE
==============================================================================*/

CREATE OR REPLACE PROCEDURE
CONTROL.SP_PROCESS_CERT_ENABLEMENT_NOMINATIONS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$

DECLARE
    V_RUN_ID                       VARCHAR;
    V_STARTED_AT                   TIMESTAMP_NTZ;

    V_RECORDS_RECEIVED             NUMBER DEFAULT 0;
    V_RECORDS_ACCEPTED             NUMBER DEFAULT 0;
    V_RECORDS_REJECTED             NUMBER DEFAULT 0;

    V_POD_ID                       VARCHAR;
    V_POD_NAME                     VARCHAR;
    V_POD_LEAD_EMPLOYEE_ID         VARCHAR;
    V_POD_LEAD_NAME                VARCHAR;
    V_POD_LEAD_EMAIL               VARCHAR;
    V_POD_ACTIVE_FLAG              BOOLEAN;
    V_SOURCE_FILE_NAME             VARCHAR;

    V_SOURCE_RECORD_ID             VARCHAR;
    V_EMPLOYEE_ID                  VARCHAR;
    V_LEARNER_NAME                 VARCHAR;
    V_EMAIL                        VARCHAR;
    V_DEPARTMENT_NAME              VARCHAR;
    V_EXPERIENCE_YEARS             NUMBER(4,1);
    V_CERTIFICATION_ID             VARCHAR;
    V_TARGET_COMPLETION_DATE       DATE;
    V_TARGET_EXAM_DATE             DATE;
    V_NOMINATION_REASON            VARCHAR;

    V_RESULT                       VARCHAR;
    V_REJECTION_REASON             VARCHAR;

BEGIN

    V_RUN_ID :=
        'RUN_' ||
        REPLACE(
            UUID_STRING(),
            '-',
            ''
        );

    V_STARTED_AT := CURRENT_TIMESTAMP();


    /*--------------------------------------------------------------------------
      Create temporary work tables.

      Inserting Stream rows into these temporary tables consumes the Stream.
      Future executions will therefore process only newer rows.
    --------------------------------------------------------------------------*/

    CREATE OR REPLACE TEMPORARY TABLE TMP_POD_CONFIGURATION_ROWS (
        POD_ID                    VARCHAR,
        POD_NAME                  VARCHAR,
        POD_LEAD_EMPLOYEE_ID      VARCHAR,
        POD_LEAD_NAME             VARCHAR,
        POD_LEAD_EMAIL            VARCHAR,
        ACTIVE_FLAG               BOOLEAN,
        SOURCE_FILE_NAME          VARCHAR
    );


    CREATE OR REPLACE TEMPORARY TABLE TMP_CERTIFICATION_NOMINATION_ROWS (
        SOURCE_RECORD_ID                VARCHAR,
        EMPLOYEE_ID                     VARCHAR,
        LEARNER_NAME                    VARCHAR,
        EMAIL                           VARCHAR,
        DEPARTMENT_NAME                 VARCHAR,
        SNOWFLAKE_EXPERIENCE_YEARS      NUMBER(4,1),
        POD_ID                          VARCHAR,
        POD_LEAD_EMPLOYEE_ID            VARCHAR,
        CERTIFICATION_ID                VARCHAR,
        TARGET_COMPLETION_DATE          DATE,
        TARGET_EXAM_DATE                DATE,
        NOMINATION_REASON               VARCHAR,
        SOURCE_FILE_NAME                VARCHAR
    );


    /*--------------------------------------------------------------------------
      Consume newly added Pod configuration rows
    --------------------------------------------------------------------------*/

    INSERT INTO TMP_POD_CONFIGURATION_ROWS (
        POD_ID,
        POD_NAME,
        POD_LEAD_EMPLOYEE_ID,
        POD_LEAD_NAME,
        POD_LEAD_EMAIL,
        ACTIVE_FLAG,
        SOURCE_FILE_NAME
    )

    SELECT
        TRIM(POD_ID),
        TRIM(POD_NAME),
        TRIM(POD_LEAD_EMPLOYEE_ID),
        TRIM(POD_LEAD_NAME),
        LOWER(TRIM(POD_LEAD_EMAIL)),
        TRY_TO_BOOLEAN(ACTIVE_FLAG),
        SOURCE_FILE_NAME

    FROM RAW.STR_POD_CONFIGURATION_INBOX

    WHERE METADATA$ACTION = 'INSERT';


    /*--------------------------------------------------------------------------
      Consume newly added certification-nomination rows
    --------------------------------------------------------------------------*/

    INSERT INTO TMP_CERTIFICATION_NOMINATION_ROWS (
        SOURCE_RECORD_ID,
        EMPLOYEE_ID,
        LEARNER_NAME,
        EMAIL,
        DEPARTMENT_NAME,
        SNOWFLAKE_EXPERIENCE_YEARS,
        POD_ID,
        POD_LEAD_EMPLOYEE_ID,
        CERTIFICATION_ID,
        TARGET_COMPLETION_DATE,
        TARGET_EXAM_DATE,
        NOMINATION_REASON,
        SOURCE_FILE_NAME
    )

    SELECT
        TRIM(SOURCE_RECORD_ID),
        TRIM(EMPLOYEE_ID),
        TRIM(LEARNER_NAME),
        LOWER(TRIM(EMAIL)),
        TRIM(DEPARTMENT_NAME),
        TRY_TO_DECIMAL(
            SNOWFLAKE_EXPERIENCE_YEARS,
            4,
            1
        ),
        UPPER(TRIM(POD_ID)),
        TRIM(POD_LEAD_EMPLOYEE_ID),
        UPPER(TRIM(CERTIFICATION_ID)),
        TRY_TO_DATE(
            TARGET_COMPLETION_DATE,
            'YYYY-MM-DD'
        ),
        TRY_TO_DATE(
            TARGET_EXAM_DATE,
            'YYYY-MM-DD'
        ),
        TRIM(NOMINATION_REASON),
        SOURCE_FILE_NAME

    FROM RAW.STR_CERTIFICATION_NOMINATIONS_INBOX

    WHERE METADATA$ACTION = 'INSERT';


    /*--------------------------------------------------------------------------
      Count all received records
    --------------------------------------------------------------------------*/

    SELECT
        (
            SELECT COUNT(*)
            FROM TMP_POD_CONFIGURATION_ROWS
        )
        +
        (
            SELECT COUNT(*)
            FROM TMP_CERTIFICATION_NOMINATION_ROWS
        )

    INTO
        :V_RECORDS_RECEIVED;


    /*============================================================================
      6. PROCESS POD CONFIGURATION
    ============================================================================*/

    FOR POD_ITEM IN (
        SELECT
            POD_ID,
            POD_NAME,
            POD_LEAD_EMPLOYEE_ID,
            POD_LEAD_NAME,
            POD_LEAD_EMAIL,
            ACTIVE_FLAG,
            SOURCE_FILE_NAME

        FROM TMP_POD_CONFIGURATION_ROWS
    )

    DO

        V_POD_ID :=
            POD_ITEM.POD_ID;

        V_POD_NAME :=
            POD_ITEM.POD_NAME;

        V_POD_LEAD_EMPLOYEE_ID :=
            POD_ITEM.POD_LEAD_EMPLOYEE_ID;

        V_POD_LEAD_NAME :=
            POD_ITEM.POD_LEAD_NAME;

        V_POD_LEAD_EMAIL :=
            POD_ITEM.POD_LEAD_EMAIL;

        V_POD_ACTIVE_FLAG :=
            POD_ITEM.ACTIVE_FLAG;

        V_SOURCE_FILE_NAME :=
            POD_ITEM.SOURCE_FILE_NAME;

        V_REJECTION_REASON := NULL;


        /*----------------------------------------------------------------------
          Validate the Pod record
        ----------------------------------------------------------------------*/

        IF (
            V_POD_ID IS NULL
            OR TRIM(V_POD_ID) = ''
        ) THEN

            V_REJECTION_REASON :=
                'Pod ID is required.';

        ELSEIF (
            V_POD_NAME IS NULL
            OR TRIM(V_POD_NAME) = ''
        ) THEN

            V_REJECTION_REASON :=
                'Pod name is required.';

        ELSEIF (
            V_POD_LEAD_EMPLOYEE_ID IS NULL
            OR TRIM(V_POD_LEAD_EMPLOYEE_ID) = ''
        ) THEN

            V_REJECTION_REASON :=
                'Pod Lead employee ID is required.';

        ELSEIF (
            V_POD_LEAD_NAME IS NULL
            OR TRIM(V_POD_LEAD_NAME) = ''
        ) THEN

            V_REJECTION_REASON :=
                'Pod Lead name is required.';

        ELSEIF (
            V_POD_LEAD_EMAIL IS NULL
            OR TRIM(V_POD_LEAD_EMAIL) = ''
            OR V_POD_LEAD_EMAIL NOT LIKE '%@%.%'
        ) THEN

            V_REJECTION_REASON :=
                'A valid Pod Lead email is required.';

        ELSEIF (V_POD_ACTIVE_FLAG IS NULL) THEN

            V_REJECTION_REASON :=
                'Active flag must be TRUE or FALSE.';

        END IF;


        /*----------------------------------------------------------------------
          Accept or reject the Pod record
        ----------------------------------------------------------------------*/

        IF (V_REJECTION_REASON IS NULL) THEN

            MERGE INTO CORE.PODS AS TARGET

            USING (
                SELECT
                    UPPER(:V_POD_ID)
                        AS POD_ID,

                    :V_POD_NAME
                        AS POD_NAME,

                    :V_POD_LEAD_EMPLOYEE_ID
                        AS POD_LEAD_EMPLOYEE_ID,

                    :V_POD_LEAD_NAME
                        AS POD_LEAD_NAME,

                    :V_POD_LEAD_EMAIL
                        AS POD_LEAD_EMAIL,

                    :V_POD_ACTIVE_FLAG
                        AS ACTIVE_FLAG
            ) AS SOURCE

            ON TARGET.POD_ID = SOURCE.POD_ID

            WHEN MATCHED THEN

                UPDATE SET
                    POD_NAME =
                        SOURCE.POD_NAME,

                    POD_LEAD_EMPLOYEE_ID =
                        SOURCE.POD_LEAD_EMPLOYEE_ID,

                    POD_LEAD_NAME =
                        SOURCE.POD_LEAD_NAME,

                    POD_LEAD_EMAIL =
                        SOURCE.POD_LEAD_EMAIL,

                    ACTIVE_FLAG =
                        SOURCE.ACTIVE_FLAG,

                    UPDATED_AT =
                        CURRENT_TIMESTAMP()

            WHEN NOT MATCHED THEN

                INSERT (
                    POD_ID,
                    POD_NAME,
                    POD_LEAD_EMPLOYEE_ID,
                    POD_LEAD_NAME,
                    POD_LEAD_EMAIL,
                    ACTIVE_FLAG,
                    CREATED_AT,
                    UPDATED_AT
                )

                VALUES (
                    SOURCE.POD_ID,
                    SOURCE.POD_NAME,
                    SOURCE.POD_LEAD_EMPLOYEE_ID,
                    SOURCE.POD_LEAD_NAME,
                    SOURCE.POD_LEAD_EMAIL,
                    SOURCE.ACTIVE_FLAG,
                    CURRENT_TIMESTAMP(),
                    CURRENT_TIMESTAMP()
                );


            V_RECORDS_ACCEPTED :=
                V_RECORDS_ACCEPTED + 1;


            /*------------------------------------------------------------------
              Resolve any earlier rejection for the same Pod
            ------------------------------------------------------------------*/

            UPDATE CONTROL.CSV_REJECTED_RECORDS

            SET
                RESOLVED_FLAG = TRUE,
                RESOLVED_AT = CURRENT_TIMESTAMP()

            WHERE PIPELINE_NAME = 'POD_CONFIGURATION'
              AND SOURCE_RECORD_ID = :V_POD_ID
              AND RESOLVED_FLAG = FALSE;


        ELSE

            V_RECORDS_REJECTED :=
                V_RECORDS_REJECTED + 1;


            INSERT INTO CONTROL.CSV_REJECTED_RECORDS (
                REJECTION_ID,
                PIPELINE_NAME,
                SOURCE_RECORD_ID,
                SOURCE_FILE_NAME,
                REJECTION_REASON,
                RAW_RECORD,
                REJECTED_AT,
                RESOLVED_FLAG,
                RESOLVED_AT
            )

            SELECT
                'REJ_' ||
                REPLACE(
                    UUID_STRING(),
                    '-',
                    ''
                ),

                'POD_CONFIGURATION',

                COALESCE(
                    :V_POD_ID,
                    'UNKNOWN_POD'
                ),

                :V_SOURCE_FILE_NAME,

                :V_REJECTION_REASON,

                OBJECT_CONSTRUCT_KEEP_NULL(
                    'POD_ID',
                    :V_POD_ID,

                    'POD_NAME',
                    :V_POD_NAME,

                    'POD_LEAD_EMPLOYEE_ID',
                    :V_POD_LEAD_EMPLOYEE_ID,

                    'POD_LEAD_NAME',
                    :V_POD_LEAD_NAME,

                    'POD_LEAD_EMAIL',
                    :V_POD_LEAD_EMAIL,

                    'ACTIVE_FLAG',
                    :V_POD_ACTIVE_FLAG
                ),

                CURRENT_TIMESTAMP(),
                FALSE,
                NULL;

        END IF;

    END FOR;


/*==============================================================================
  7. PROCESS CERTIFICATION NOMINATIONS
==============================================================================*/

    FOR NOMINATION_ITEM IN (
        SELECT
            SOURCE_RECORD_ID,
            EMPLOYEE_ID,
            LEARNER_NAME,
            EMAIL,
            DEPARTMENT_NAME,
            SNOWFLAKE_EXPERIENCE_YEARS,
            POD_ID,
            POD_LEAD_EMPLOYEE_ID,
            CERTIFICATION_ID,
            TARGET_COMPLETION_DATE,
            TARGET_EXAM_DATE,
            NOMINATION_REASON,
            SOURCE_FILE_NAME

        FROM TMP_CERTIFICATION_NOMINATION_ROWS
    )

    DO

        V_SOURCE_RECORD_ID :=
            NOMINATION_ITEM.SOURCE_RECORD_ID;

        V_EMPLOYEE_ID :=
            NOMINATION_ITEM.EMPLOYEE_ID;

        V_LEARNER_NAME :=
            NOMINATION_ITEM.LEARNER_NAME;

        V_EMAIL :=
            NOMINATION_ITEM.EMAIL;

        V_DEPARTMENT_NAME :=
            NOMINATION_ITEM.DEPARTMENT_NAME;

        V_EXPERIENCE_YEARS :=
            NOMINATION_ITEM.SNOWFLAKE_EXPERIENCE_YEARS;

        V_POD_ID :=
            NOMINATION_ITEM.POD_ID;

        V_POD_LEAD_EMPLOYEE_ID :=
            NOMINATION_ITEM.POD_LEAD_EMPLOYEE_ID;

        V_CERTIFICATION_ID :=
            NOMINATION_ITEM.CERTIFICATION_ID;

        V_TARGET_COMPLETION_DATE :=
            NOMINATION_ITEM.TARGET_COMPLETION_DATE;

        V_TARGET_EXAM_DATE :=
            NOMINATION_ITEM.TARGET_EXAM_DATE;

        V_NOMINATION_REASON :=
            NOMINATION_ITEM.NOMINATION_REASON;

        V_SOURCE_FILE_NAME :=
            NOMINATION_ITEM.SOURCE_FILE_NAME;

        V_REJECTION_REASON := NULL;


        /*----------------------------------------------------------------------
          Perform basic CSV-format validation
        ----------------------------------------------------------------------*/

        IF (
            V_SOURCE_RECORD_ID IS NULL
            OR TRIM(V_SOURCE_RECORD_ID) = ''
        ) THEN

            V_REJECTION_REASON :=
                'Source record ID is required.';

        ELSEIF (
            V_EMPLOYEE_ID IS NULL
            OR TRIM(V_EMPLOYEE_ID) = ''
        ) THEN

            V_REJECTION_REASON :=
                'Employee ID is required.';

        ELSEIF (
            V_LEARNER_NAME IS NULL
            OR TRIM(V_LEARNER_NAME) = ''
        ) THEN

            V_REJECTION_REASON :=
                'Learner name is required.';

        ELSEIF (
            V_EMAIL IS NULL
            OR TRIM(V_EMAIL) = ''
            OR V_EMAIL NOT LIKE '%@%.%'
        ) THEN

            V_REJECTION_REASON :=
                'A valid learner email is required.';

        ELSEIF (V_EXPERIENCE_YEARS IS NULL) THEN

            V_REJECTION_REASON :=
                'Snowflake experience must be a valid number.';

        ELSEIF (V_TARGET_COMPLETION_DATE IS NULL) THEN

            V_REJECTION_REASON :=
                'Target completion date must use YYYY-MM-DD format.';

        ELSEIF (V_TARGET_EXAM_DATE IS NULL) THEN

            V_REJECTION_REASON :=
                'Target exam date must use YYYY-MM-DD format.';

        END IF;


        /*----------------------------------------------------------------------
          Call the Pod nomination procedure when the CSV structure is valid
        ----------------------------------------------------------------------*/

        IF (V_REJECTION_REASON IS NULL) THEN

            CALL CONTROL.SP_NOMINATE_CERT_ENABLEMENT_LEARNER(
                :V_EMPLOYEE_ID,
                :V_LEARNER_NAME,
                :V_EMAIL,
                :V_DEPARTMENT_NAME,
                :V_EXPERIENCE_YEARS,
                :V_POD_ID,
                :V_POD_LEAD_EMPLOYEE_ID,
                :V_CERTIFICATION_ID,
                :V_TARGET_COMPLETION_DATE,
                :V_TARGET_EXAM_DATE,
                :V_NOMINATION_REASON
            )
            INTO :V_RESULT;


            IF (
                STARTSWITH(
                    V_RESULT,
                    'Learner nominated successfully.'
                )
            ) THEN

                V_RECORDS_ACCEPTED :=
                    V_RECORDS_ACCEPTED + 1;


                /*--------------------------------------------------------------
                  Resolve an earlier corrected rejection
                --------------------------------------------------------------*/

                UPDATE CONTROL.CSV_REJECTED_RECORDS

                SET
                    RESOLVED_FLAG = TRUE,
                    RESOLVED_AT = CURRENT_TIMESTAMP()

                WHERE PIPELINE_NAME = 'CERTIFICATION_NOMINATION'
                  AND SOURCE_RECORD_ID = :V_SOURCE_RECORD_ID
                  AND RESOLVED_FLAG = FALSE;


            ELSE

                V_REJECTION_REASON := V_RESULT;

            END IF;

        END IF;


        /*----------------------------------------------------------------------
          Store rejected nomination records
        ----------------------------------------------------------------------*/

        IF (V_REJECTION_REASON IS NOT NULL) THEN

            V_RECORDS_REJECTED :=
                V_RECORDS_REJECTED + 1;


            INSERT INTO CONTROL.CSV_REJECTED_RECORDS (
                REJECTION_ID,
                PIPELINE_NAME,
                SOURCE_RECORD_ID,
                SOURCE_FILE_NAME,
                REJECTION_REASON,
                RAW_RECORD,
                REJECTED_AT,
                RESOLVED_FLAG,
                RESOLVED_AT
            )

            SELECT
                'REJ_' ||
                REPLACE(
                    UUID_STRING(),
                    '-',
                    ''
                ),

                'CERTIFICATION_NOMINATION',

                COALESCE(
                    :V_SOURCE_RECORD_ID,
                    'UNKNOWN_NOMINATION'
                ),

                :V_SOURCE_FILE_NAME,

                :V_REJECTION_REASON,

                OBJECT_CONSTRUCT_KEEP_NULL(
                    'SOURCE_RECORD_ID',
                    :V_SOURCE_RECORD_ID,

                    'EMPLOYEE_ID',
                    :V_EMPLOYEE_ID,

                    'LEARNER_NAME',
                    :V_LEARNER_NAME,

                    'EMAIL',
                    :V_EMAIL,

                    'DEPARTMENT_NAME',
                    :V_DEPARTMENT_NAME,

                    'SNOWFLAKE_EXPERIENCE_YEARS',
                    :V_EXPERIENCE_YEARS,

                    'POD_ID',
                    :V_POD_ID,

                    'POD_LEAD_EMPLOYEE_ID',
                    :V_POD_LEAD_EMPLOYEE_ID,

                    'CERTIFICATION_ID',
                    :V_CERTIFICATION_ID,

                    'TARGET_COMPLETION_DATE',
                    :V_TARGET_COMPLETION_DATE,

                    'TARGET_EXAM_DATE',
                    :V_TARGET_EXAM_DATE,

                    'NOMINATION_REASON',
                    :V_NOMINATION_REASON
                ),

                CURRENT_TIMESTAMP(),
                FALSE,
                NULL;

        END IF;

    END FOR;


/*==============================================================================
  8. WRITE THE PIPELINE RUN LOG
==============================================================================*/

    INSERT INTO CONTROL.CSV_PIPELINE_RUN_LOG (
        RUN_ID,
        PIPELINE_NAME,
        RUN_STATUS,
        RECORDS_RECEIVED,
        RECORDS_ACCEPTED,
        RECORDS_REJECTED,
        RUN_MESSAGE,
        STARTED_AT,
        COMPLETED_AT
    )

    VALUES (
        :V_RUN_ID,
        'POD_AND_CERTIFICATION_NOMINATION',
        'SUCCESS',
        :V_RECORDS_RECEIVED,
        :V_RECORDS_ACCEPTED,
        :V_RECORDS_REJECTED,
        'Pod and certification-nomination processing completed.',
        :V_STARTED_AT,
        CURRENT_TIMESTAMP()
    );


    RETURN
        'Processing completed. Records received: ' ||
        V_RECORDS_RECEIVED ||
        ', accepted: ' ||
        V_RECORDS_ACCEPTED ||
        ', rejected: ' ||
        V_RECORDS_REJECTED ||
        '.';


EXCEPTION

    WHEN OTHER THEN

        INSERT INTO CONTROL.CSV_PIPELINE_RUN_LOG (
            RUN_ID,
            PIPELINE_NAME,
            RUN_STATUS,
            RECORDS_RECEIVED,
            RECORDS_ACCEPTED,
            RECORDS_REJECTED,
            RUN_MESSAGE,
            STARTED_AT,
            COMPLETED_AT
        )

        VALUES (
            :V_RUN_ID,
            'POD_AND_CERTIFICATION_NOMINATION',
            'FAILED',
            :V_RECORDS_RECEIVED,
            :V_RECORDS_ACCEPTED,
            :V_RECORDS_REJECTED,
            :SQLERRM,
            :V_STARTED_AT,
            CURRENT_TIMESTAMP()
        );


        RETURN
            'Processing failed: ' || SQLERRM;

END;
$$;


/*==============================================================================
  9. AUTOMATED PROCESSING TASK
==============================================================================*/

CREATE OR REPLACE TASK
CONTROL.TSK_PROCESS_CERT_NOMINATIONS_1MIN

    WAREHOUSE = WH_CERT_ENABLEMENT_DEV_XS

    SCHEDULE = '1 MINUTE'

    WHEN
        SYSTEM$STREAM_HAS_DATA(
            'DB_CERT_ENABLEMENT_DEV.RAW.STR_POD_CONFIGURATION_INBOX'
        )

        OR

        SYSTEM$STREAM_HAS_DATA(
            'DB_CERT_ENABLEMENT_DEV.RAW.STR_CERTIFICATION_NOMINATIONS_INBOX'
        )

AS

    CALL CONTROL.SP_PROCESS_CERT_ENABLEMENT_NOMINATIONS();


/*------------------------------------------------------------------------------
  The Task remains suspended after creation.

  Resume it only during testing or active usage:

  ALTER TASK CONTROL.TSK_PROCESS_CERT_NOMINATIONS_1MIN RESUME;

  Suspend it after testing to control trial-account cost:

  ALTER TASK CONTROL.TSK_PROCESS_CERT_NOMINATIONS_1MIN SUSPEND;
------------------------------------------------------------------------------*/


/*==============================================================================
  10. CSV LOAD COMMANDS

  Upload these files to the internal stage before executing COPY INTO:

  - pods.csv
  - certification_nominations.csv
==============================================================================*/

/*------------------------------------------------------------------------------
  Load Pod configuration
------------------------------------------------------------------------------*/

/*
COPY INTO RAW.POD_CONFIGURATION_INBOX (
    POD_ID,
    POD_NAME,
    POD_LEAD_EMPLOYEE_ID,
    POD_LEAD_NAME,
    POD_LEAD_EMAIL,
    ACTIVE_FLAG,
    SOURCE_FILE_NAME
)

FROM (
    SELECT
        $1,
        $2,
        $3,
        $4,
        $5,
        $6,
        METADATA$FILENAME

    FROM @RAW.INT_RAW_CERTIFICATION_UPLOAD_DEV/pods.csv
)

FILE_FORMAT = (
    FORMAT_NAME = RAW.CERTIFICATION_CSV_FORMAT
)

ON_ERROR = 'ABORT_STATEMENT';
*/


/*------------------------------------------------------------------------------
  Load certification nominations
------------------------------------------------------------------------------*/

/*
COPY INTO RAW.CERTIFICATION_NOMINATIONS_INBOX (
    SOURCE_RECORD_ID,
    EMPLOYEE_ID,
    LEARNER_NAME,
    EMAIL,
    DEPARTMENT_NAME,
    SNOWFLAKE_EXPERIENCE_YEARS,
    POD_ID,
    POD_LEAD_EMPLOYEE_ID,
    CERTIFICATION_ID,
    TARGET_COMPLETION_DATE,
    TARGET_EXAM_DATE,
    NOMINATION_REASON,
    SOURCE_FILE_NAME
)

FROM (
    SELECT
        $1,
        $2,
        $3,
        $4,
        $5,
        $6,
        $7,
        $8,
        $9,
        $10,
        $11,
        $12,
        METADATA$FILENAME

    FROM
        @RAW.INT_RAW_CERTIFICATION_UPLOAD_DEV/certification_nominations.csv
)

FILE_FORMAT = (
    FORMAT_NAME = RAW.CERTIFICATION_CSV_FORMAT
)

ON_ERROR = 'ABORT_STATEMENT';
*/


/*==============================================================================
  11. VERIFICATION COMMANDS
==============================================================================*/

SHOW STREAMS
IN SCHEMA DB_CERT_ENABLEMENT_DEV.RAW;

SHOW PROCEDURES LIKE
    'SP_PROCESS_CERT_ENABLEMENT_NOMINATIONS'
IN SCHEMA DB_CERT_ENABLEMENT_DEV.CONTROL;

SHOW TASKS LIKE
    'TSK_PROCESS_CERT_NOMINATIONS_1MIN'
IN SCHEMA DB_CERT_ENABLEMENT_DEV.CONTROL;