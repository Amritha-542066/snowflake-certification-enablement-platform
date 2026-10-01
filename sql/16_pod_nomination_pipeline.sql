/*==============================================================================
  Snowflake Certification Enablement Platform
  Step 16: Unified certification-nomination CSV pipeline

  Purpose:
  - Accept one business-friendly nomination CSV.
  - Keep technical IDs inside Snowflake.
  - Validate, standardize and process newly uploaded nominations.
  - Store rejected records and pipeline run details.

  Important:
  This development script recreates only the RAW nomination inbox and its
  Stream. Validated CORE data is not deleted.
==============================================================================*/


/*==============================================================================
  1. ENVIRONMENT
==============================================================================*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_CERT_ENABLEMENT_DEV_XS;
USE DATABASE DB_CERT_ENABLEMENT_DEV;
USE SCHEMA RAW;


/*==============================================================================
  2. UNIFIED RAW NOMINATION INBOX

  The Pod Lead supplies only understandable business fields. SOURCE_FILE_NAME
  and LOADED_AT are added by Snowflake during ingestion.
==============================================================================*/

CREATE OR REPLACE TABLE RAW.CERTIFICATION_NOMINATIONS_INBOX (
    EMPLOYEE_ID                       VARCHAR(50),
    LEARNER_NAME                      VARCHAR(200),
    EMAIL                             VARCHAR(320),
    DEPARTMENT_NAME                   VARCHAR(200),
    SNOWFLAKE_EXPERIENCE_YEARS        VARCHAR(20),
    POD_NAME                          VARCHAR(200),
    POD_LEAD_NAME                     VARCHAR(200),
    CERTIFICATION_NAME                VARCHAR(200),
    TARGET_COMPLETION_DATE            VARCHAR(30),
    SOURCE_FILE_NAME                  VARCHAR(500),
    LOADED_AT                         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);


/*==============================================================================
  3. STREAM
==============================================================================*/

CREATE OR REPLACE STREAM RAW.STR_CERTIFICATION_NOMINATIONS_INBOX
    ON TABLE RAW.CERTIFICATION_NOMINATIONS_INBOX
    APPEND_ONLY = TRUE;


/*==============================================================================
  4. PROCESSING PROCEDURE
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

    V_SOURCE_RECORD_ID             VARCHAR;
    V_SOURCE_FILE_NAME             VARCHAR;

    V_EMPLOYEE_ID                  VARCHAR;
    V_LEARNER_NAME                 VARCHAR;
    V_EMAIL                        VARCHAR;
    V_DEPARTMENT_NAME              VARCHAR;
    V_EXPERIENCE_YEARS             NUMBER(4,1);
    V_EXPERIENCE_YEARS_RAW         VARCHAR;
    V_POD_NAME                     VARCHAR;
    V_POD_LEAD_NAME                VARCHAR;
    V_CERTIFICATION_NAME           VARCHAR;
    V_TARGET_COMPLETION_DATE       DATE;
    V_TARGET_COMPLETION_DATE_RAW   VARCHAR;

    V_RESULT                       VARCHAR;
    V_REJECTION_REASON             VARCHAR;
    V_NOMINATION_RESULTSET         RESULTSET;

BEGIN

    V_RUN_ID :=
        'RUN_' ||
        REPLACE(
            UUID_STRING(),
            '-',
            ''
        );

    V_STARTED_AT := CURRENT_TIMESTAMP();


    /* Consume newly inserted Stream rows into a temporary work table. */

    CREATE OR REPLACE TEMPORARY TABLE
        TMP_CERTIFICATION_NOMINATION_ROWS (
            EMPLOYEE_ID                       VARCHAR,
            LEARNER_NAME                      VARCHAR,
            EMAIL                             VARCHAR,
            DEPARTMENT_NAME                   VARCHAR,
            SNOWFLAKE_EXPERIENCE_YEARS        NUMBER(4,1),
            SNOWFLAKE_EXPERIENCE_YEARS_RAW    VARCHAR,
            POD_NAME                          VARCHAR,
            POD_LEAD_NAME                     VARCHAR,
            CERTIFICATION_NAME                VARCHAR,
            TARGET_COMPLETION_DATE            DATE,
            TARGET_COMPLETION_DATE_RAW        VARCHAR,
            SOURCE_FILE_NAME                  VARCHAR
        );


    INSERT INTO TMP_CERTIFICATION_NOMINATION_ROWS (
        EMPLOYEE_ID,
        LEARNER_NAME,
        EMAIL,
        DEPARTMENT_NAME,
        SNOWFLAKE_EXPERIENCE_YEARS,
        SNOWFLAKE_EXPERIENCE_YEARS_RAW,
        POD_NAME,
        POD_LEAD_NAME,
        CERTIFICATION_NAME,
        TARGET_COMPLETION_DATE,
        TARGET_COMPLETION_DATE_RAW,
        SOURCE_FILE_NAME
    )

    SELECT
        TRIM(EMPLOYEE_ID),

        REGEXP_REPLACE(
            TRIM(LEARNER_NAME),
            '[[:space:]]+',
            ' '
        ),

        LOWER(TRIM(EMAIL)),

        REGEXP_REPLACE(
            TRIM(DEPARTMENT_NAME),
            '[[:space:]]+',
            ' '
        ),

        TRY_TO_DECIMAL(
            SNOWFLAKE_EXPERIENCE_YEARS,
            4,
            1
        ),

        TRIM(SNOWFLAKE_EXPERIENCE_YEARS),

        REGEXP_REPLACE(
            TRIM(POD_NAME),
            '[[:space:]]+',
            ' '
        ),

        REGEXP_REPLACE(
            TRIM(POD_LEAD_NAME),
            '[[:space:]]+',
            ' '
        ),

        REGEXP_REPLACE(
            TRIM(CERTIFICATION_NAME),
            '[[:space:]]+',
            ' '
        ),

        TRY_TO_DATE(
            TARGET_COMPLETION_DATE,
            'YYYY-MM-DD'
        ),

        TRIM(TARGET_COMPLETION_DATE),
        SOURCE_FILE_NAME

    FROM RAW.STR_CERTIFICATION_NOMINATIONS_INBOX

    WHERE METADATA$ACTION = 'INSERT';


    SELECT
        COUNT(*)

    INTO
        :V_RECORDS_RECEIVED

    FROM TMP_CERTIFICATION_NOMINATION_ROWS;


    /* Process each new nomination. */

    V_NOMINATION_RESULTSET := (
        SELECT
            EMPLOYEE_ID,
            LEARNER_NAME,
            EMAIL,
            DEPARTMENT_NAME,
            SNOWFLAKE_EXPERIENCE_YEARS,
            SNOWFLAKE_EXPERIENCE_YEARS_RAW,
            POD_NAME,
            POD_LEAD_NAME,
            CERTIFICATION_NAME,
            TARGET_COMPLETION_DATE,
            TARGET_COMPLETION_DATE_RAW,
            SOURCE_FILE_NAME

        FROM TMP_CERTIFICATION_NOMINATION_ROWS
    );


    FOR NOMINATION_ITEM IN V_NOMINATION_RESULTSET DO

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

        V_EXPERIENCE_YEARS_RAW :=
            NOMINATION_ITEM.SNOWFLAKE_EXPERIENCE_YEARS_RAW;

        V_POD_NAME :=
            NOMINATION_ITEM.POD_NAME;

        V_POD_LEAD_NAME :=
            NOMINATION_ITEM.POD_LEAD_NAME;

        V_CERTIFICATION_NAME :=
            NOMINATION_ITEM.CERTIFICATION_NAME;

        V_TARGET_COMPLETION_DATE :=
            NOMINATION_ITEM.TARGET_COMPLETION_DATE;

        V_TARGET_COMPLETION_DATE_RAW :=
            NOMINATION_ITEM.TARGET_COMPLETION_DATE_RAW;

        V_SOURCE_FILE_NAME :=
            NOMINATION_ITEM.SOURCE_FILE_NAME;

        V_REJECTION_REASON := NULL;
        V_RESULT := NULL;


        /* Generate an internal source identifier for audit and corrections. */

        V_SOURCE_RECORD_ID :=
            'NOM_' ||
            LEFT(
                SHA2(
                    UPPER(
                        COALESCE(
                            TRIM(V_EMPLOYEE_ID),
                            'UNKNOWN_EMPLOYEE'
                        )
                    ) ||
                    '|' ||
                    UPPER(
                        COALESCE(
                            TRIM(V_CERTIFICATION_NAME),
                            'UNKNOWN_CERTIFICATION'
                        )
                    ),
                    256
                ),
                20
            );


        /* Validate the business-friendly CSV record. */

        IF (
            V_EMPLOYEE_ID IS NULL
            OR TRIM(V_EMPLOYEE_ID) = ''
        ) THEN
            V_REJECTION_REASON := 'Employee ID is required.';

        ELSEIF (
            V_LEARNER_NAME IS NULL
            OR TRIM(V_LEARNER_NAME) = ''
        ) THEN
            V_REJECTION_REASON := 'Learner name is required.';

        ELSEIF (
            V_EMAIL IS NULL
            OR TRIM(V_EMAIL) = ''
            OR V_EMAIL NOT LIKE '%@%.%'
        ) THEN
            V_REJECTION_REASON := 'A valid learner email is required.';

        ELSEIF (
            V_DEPARTMENT_NAME IS NULL
            OR TRIM(V_DEPARTMENT_NAME) = ''
        ) THEN
            V_REJECTION_REASON := 'Department name is required.';

        ELSEIF (V_EXPERIENCE_YEARS IS NULL) THEN
            V_REJECTION_REASON := 'Snowflake experience must be a valid number.';

        ELSEIF (V_EXPERIENCE_YEARS < 0) THEN
            V_REJECTION_REASON := 'Snowflake experience must be zero or greater.';

        ELSEIF (
            V_POD_NAME IS NULL
            OR TRIM(V_POD_NAME) = ''
        ) THEN
            V_REJECTION_REASON := 'Pod name is required.';

        ELSEIF (
            V_POD_LEAD_NAME IS NULL
            OR TRIM(V_POD_LEAD_NAME) = ''
        ) THEN
            V_REJECTION_REASON := 'Pod Lead name is required.';

        ELSEIF (
            V_CERTIFICATION_NAME IS NULL
            OR TRIM(V_CERTIFICATION_NAME) = ''
        ) THEN
            V_REJECTION_REASON := 'Certification name is required.';

        ELSEIF (V_TARGET_COMPLETION_DATE IS NULL) THEN
            V_REJECTION_REASON := 'Target completion date must use YYYY-MM-DD format.';

        END IF;


        /* Call the nomination procedure for structurally valid records. */

        IF (V_REJECTION_REASON IS NULL) THEN

            CALL CONTROL.SP_NOMINATE_CERT_ENABLEMENT_LEARNER(
                :V_EMPLOYEE_ID,
                :V_LEARNER_NAME,
                :V_EMAIL,
                :V_DEPARTMENT_NAME,
                :V_EXPERIENCE_YEARS,
                :V_POD_NAME,
                :V_POD_LEAD_NAME,
                :V_CERTIFICATION_NAME,
                :V_TARGET_COMPLETION_DATE
            );


            SELECT
                $1::VARCHAR

            INTO
                :V_RESULT

            FROM TABLE(
                RESULT_SCAN(
                    LAST_QUERY_ID()
                )
            );


            IF (
                STARTSWITH(
                    V_RESULT,
                    'Learner nominated successfully.'
                )
            ) THEN

                V_RECORDS_ACCEPTED :=
                    V_RECORDS_ACCEPTED + 1;


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


        /* Store rejected records with a business-readable reason. */

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
                :V_SOURCE_RECORD_ID,
                :V_SOURCE_FILE_NAME,
                :V_REJECTION_REASON,

                OBJECT_CONSTRUCT_KEEP_NULL(
                    'EMPLOYEE_ID',
                    :V_EMPLOYEE_ID,

                    'LEARNER_NAME',
                    :V_LEARNER_NAME,

                    'EMAIL',
                    :V_EMAIL,

                    'DEPARTMENT_NAME',
                    :V_DEPARTMENT_NAME,

                    'SNOWFLAKE_EXPERIENCE_YEARS',
                    :V_EXPERIENCE_YEARS_RAW,

                    'POD_NAME',
                    :V_POD_NAME,

                    'POD_LEAD_NAME',
                    :V_POD_LEAD_NAME,

                    'CERTIFICATION_NAME',
                    :V_CERTIFICATION_NAME,

                    'TARGET_COMPLETION_DATE',
                    :V_TARGET_COMPLETION_DATE_RAW
                ),

                CURRENT_TIMESTAMP(),
                FALSE,
                NULL;

        END IF;

    END FOR;


    /* Write one audit row for the pipeline execution. */

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
        'CERTIFICATION_NOMINATION',
        'SUCCESS',
        :V_RECORDS_RECEIVED,
        :V_RECORDS_ACCEPTED,
        :V_RECORDS_REJECTED,
        'Unified certification-nomination processing completed.',
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
            'CERTIFICATION_NOMINATION',
            'FAILED',
            :V_RECORDS_RECEIVED,
            :V_RECORDS_ACCEPTED,
            :V_RECORDS_REJECTED,
            :SQLERRM,
            :V_STARTED_AT,
            CURRENT_TIMESTAMP()
        );


        RETURN 'Processing failed: ' || SQLERRM;

END;
$$;


/*==============================================================================
  5. AUTOMATED TASK
==============================================================================*/

CREATE OR REPLACE TASK
CONTROL.TSK_PROCESS_CERT_NOMINATIONS_1MIN

    WAREHOUSE = WH_CERT_ENABLEMENT_DEV_XS
    SCHEDULE = '1 MINUTE'

    WHEN
        SYSTEM$STREAM_HAS_DATA(
            'DB_CERT_ENABLEMENT_DEV.RAW.STR_CERTIFICATION_NOMINATIONS_INBOX'
        )

AS
    CALL CONTROL.SP_PROCESS_CERT_ENABLEMENT_NOMINATIONS();


/*------------------------------------------------------------------------------
  The Task is created in a suspended state.

  Resume during automatic testing:

  ALTER TASK CONTROL.TSK_PROCESS_CERT_NOMINATIONS_1MIN RESUME;

  Suspend after testing:

  ALTER TASK CONTROL.TSK_PROCESS_CERT_NOMINATIONS_1MIN SUSPEND;
------------------------------------------------------------------------------*/


/*==============================================================================
  6. UNIFIED CSV LOAD COMMAND
==============================================================================*/

/*
COPY INTO RAW.CERTIFICATION_NOMINATIONS_INBOX (
    EMPLOYEE_ID,
    LEARNER_NAME,
    EMAIL,
    DEPARTMENT_NAME,
    SNOWFLAKE_EXPERIENCE_YEARS,
    POD_NAME,
    POD_LEAD_NAME,
    CERTIFICATION_NAME,
    TARGET_COMPLETION_DATE,
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
        METADATA$FILENAME

    FROM
        @RAW.INT_RAW_CERTIFICATION_UPLOAD_DEV/certification_nominations.csv
)

FILE_FORMAT = (
    FORMAT_NAME = RAW.CERTIFICATION_CSV_FORMAT
)

ON_ERROR = 'ABORT_STATEMENT'
FORCE = TRUE;
*/


/*==============================================================================
  7. VERIFICATION
==============================================================================*/

SHOW STREAMS LIKE 'STR_CERTIFICATION_NOMINATIONS_INBOX'
IN SCHEMA DB_CERT_ENABLEMENT_DEV.RAW;

SHOW PROCEDURES LIKE 'SP_PROCESS_CERT_ENABLEMENT_NOMINATIONS'
IN SCHEMA DB_CERT_ENABLEMENT_DEV.CONTROL;

SHOW TASKS LIKE 'TSK_PROCESS_CERT_NOMINATIONS_1MIN'
IN SCHEMA DB_CERT_ENABLEMENT_DEV.CONTROL;
