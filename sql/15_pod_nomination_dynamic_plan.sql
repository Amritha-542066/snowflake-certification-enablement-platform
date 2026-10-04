/*==============================================================================
  Snowflake Certification Enablement Platform
  Step 15: Pod nomination and dynamic learning plan
  Incremental-update fix: Preserve the original plan start date.

  Purpose:
  - Keep Snowflake-generated identifiers inside Snowflake.
  - Accept business-friendly Pod, Pod Lead and certification names.
  - Validate the supplied Pod Lead against the selected Pod.
  - Generate a learner-specific schedule from the Pod Lead's completion date.
==============================================================================*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_CERT_ENABLEMENT_DEV_XS;
USE DATABASE DB_CERT_ENABLEMENT_DEV;
USE SCHEMA CORE;


/*==============================================================================
  1. CORE TABLES
==============================================================================*/

CREATE TABLE IF NOT EXISTS CORE.PODS (
    POD_ID                    VARCHAR(30)   NOT NULL,
    POD_NAME                  VARCHAR(200)  NOT NULL,
    POD_LEAD_EMPLOYEE_ID      VARCHAR(50)   NOT NULL,
    POD_LEAD_NAME             VARCHAR(200)  NOT NULL,
    POD_LEAD_EMAIL            VARCHAR(320)  NOT NULL,
    ACTIVE_FLAG               BOOLEAN       DEFAULT TRUE,
    CREATED_AT                TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT                TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_PODS PRIMARY KEY (POD_ID)
);


CREATE TABLE IF NOT EXISTS CORE.POD_MEMBERS (
    POD_ID                    VARCHAR(30)   NOT NULL,
    EMPLOYEE_ID               VARCHAR(50)   NOT NULL,
    ACTIVE_FLAG               BOOLEAN       DEFAULT TRUE,
    JOINED_AT                 TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT                TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_POD_MEMBERS PRIMARY KEY (POD_ID, EMPLOYEE_ID)
);


CREATE TABLE IF NOT EXISTS CORE.CERTIFICATION_NOMINATIONS (
    NOMINATION_ID             VARCHAR(50)    NOT NULL,
    EMPLOYEE_ID               VARCHAR(50)    NOT NULL,
    POD_ID                    VARCHAR(30)     NOT NULL,
    POD_LEAD_EMPLOYEE_ID      VARCHAR(50)     NOT NULL,
    CERTIFICATION_ID          VARCHAR(20)     NOT NULL,
    NOMINATION_DATE           DATE            NOT NULL,
    TARGET_COMPLETION_DATE    DATE            NOT NULL,
    TARGET_EXAM_DATE          DATE            NOT NULL,
    NOMINATION_REASON         VARCHAR(1000),
    NOMINATION_STATUS         VARCHAR(30)      DEFAULT 'APPROVED',
    CREATED_AT                TIMESTAMP_NTZ    DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT                TIMESTAMP_NTZ    DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_CERTIFICATION_NOMINATIONS PRIMARY KEY (NOMINATION_ID)
);


CREATE TABLE IF NOT EXISTS CORE.LEARNER_TOPIC_PLAN (
    ENROLLMENT_ID             VARCHAR(30)    NOT NULL,
    TOPIC_ID                  VARCHAR(30)    NOT NULL,
    PLANNED_WEEK_NUMBER       NUMBER(3,0)    NOT NULL,
    PLANNED_START_DATE        DATE           NOT NULL,
    PLANNED_END_DATE          DATE           NOT NULL,
    RECOMMENDED_HOURS         NUMBER(5,1)    NOT NULL,
    REQUIRED_FLAG             BOOLEAN        DEFAULT TRUE,
    CREATED_AT                TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT                TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_LEARNER_TOPIC_PLAN PRIMARY KEY (ENROLLMENT_ID, TOPIC_ID)
);


/*==============================================================================
  2. SUPPORT DYNAMIC ENROLLMENTS
==============================================================================*/

ALTER TABLE CORE.LEARNERS
    ALTER COLUMN EXPERIENCE_LEVEL_CODE DROP NOT NULL;

ALTER TABLE CORE.ENROLLMENTS
    ALTER COLUMN PATH_ID DROP NOT NULL;

ALTER TABLE CORE.ENROLLMENTS
    ADD COLUMN IF NOT EXISTS NOMINATION_ID VARCHAR(50);

ALTER TABLE CORE.ENROLLMENTS
    ADD COLUMN IF NOT EXISTS POD_ID VARCHAR(30);

ALTER TABLE CORE.ENROLLMENTS
    ADD COLUMN IF NOT EXISTS NOMINATED_BY_EMPLOYEE_ID VARCHAR(50);

ALTER TABLE CORE.ENROLLMENTS
    ADD COLUMN IF NOT EXISTS PLAN_TYPE VARCHAR(30);


/*==============================================================================
  3. BUSINESS-FRIENDLY NOMINATION PROCEDURE

  The caller supplies names. The procedure resolves internal Pod and
  certification identifiers and generates learner, nomination and enrollment
  identifiers inside Snowflake.
==============================================================================*/

/* Remove the earlier 11-argument technical-ID version of the procedure. */

DROP PROCEDURE IF EXISTS
CONTROL.SP_NOMINATE_CERT_ENABLEMENT_LEARNER(
    VARCHAR,
    VARCHAR,
    VARCHAR,
    VARCHAR,
    NUMBER,
    VARCHAR,
    VARCHAR,
    VARCHAR,
    DATE,
    DATE,
    VARCHAR
);

CREATE OR REPLACE PROCEDURE
CONTROL.SP_NOMINATE_CERT_ENABLEMENT_LEARNER(
    P_EMPLOYEE_ID                  VARCHAR,
    P_LEARNER_NAME                 VARCHAR,
    P_EMAIL                        VARCHAR,
    P_DEPARTMENT_NAME              VARCHAR,
    P_SNOWFLAKE_EXPERIENCE_YEARS   NUMBER(4,1),
    P_POD_NAME                     VARCHAR,
    P_POD_LEAD_NAME                VARCHAR,
    P_CERTIFICATION_NAME           VARCHAR,
    P_TARGET_COMPLETION_DATE       DATE
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
    V_POD_COUNT                    NUMBER DEFAULT 0;
    V_CERTIFICATION_COUNT          NUMBER DEFAULT 0;
    V_TOPIC_COUNT                  NUMBER DEFAULT 0;
    V_PLAN_WEEKS                   NUMBER DEFAULT 0;
    V_PLAN_START_DATE              DATE;

    V_POD_ID                       VARCHAR;
    V_POD_LEAD_EMPLOYEE_ID         VARCHAR;
    V_CERTIFICATION_ID             VARCHAR;
    V_TARGET_EXAM_DATE             DATE;

    V_LEARNER_ID                   VARCHAR;
    V_NOMINATION_ID                VARCHAR;
    V_ENROLLMENT_ID                VARCHAR;

BEGIN

    /* Validate the business fields supplied by the Pod Lead. */

    IF (
        P_EMPLOYEE_ID IS NULL
        OR TRIM(P_EMPLOYEE_ID) = ''
        OR P_LEARNER_NAME IS NULL
        OR TRIM(P_LEARNER_NAME) = ''
        OR P_EMAIL IS NULL
        OR TRIM(P_EMAIL) = ''
        OR P_DEPARTMENT_NAME IS NULL
        OR TRIM(P_DEPARTMENT_NAME) = ''
        OR P_POD_NAME IS NULL
        OR TRIM(P_POD_NAME) = ''
        OR P_POD_LEAD_NAME IS NULL
        OR TRIM(P_POD_LEAD_NAME) = ''
        OR P_CERTIFICATION_NAME IS NULL
        OR TRIM(P_CERTIFICATION_NAME) = ''
    ) THEN
        RETURN 'Nomination failed: Employee, Pod, Pod Lead and certification details are required.';
    END IF;


    IF (
        P_EMAIL NOT LIKE '%@%.%'
    ) THEN
        RETURN 'Nomination failed: A valid learner email is required.';
    END IF;


    IF (
        P_SNOWFLAKE_EXPERIENCE_YEARS IS NULL
        OR P_SNOWFLAKE_EXPERIENCE_YEARS < 0
    ) THEN
        RETURN 'Nomination failed: Snowflake experience must be zero or greater.';
    END IF;


    IF (P_TARGET_COMPLETION_DATE IS NULL) THEN
        RETURN 'Nomination failed: Target completion date is required.';
    END IF;


    IF (P_TARGET_COMPLETION_DATE <= CURRENT_DATE()) THEN
        RETURN 'Nomination failed: Target completion date must be in the future.';
    END IF;


    /* Resolve and validate the internal Pod information using names. */

    SELECT
        COUNT(*),
        MIN(POD_ID),
        MIN(POD_LEAD_EMPLOYEE_ID)

    INTO
        :V_POD_COUNT,
        :V_POD_ID,
        :V_POD_LEAD_EMPLOYEE_ID

    FROM CORE.PODS

    WHERE UPPER(
              REGEXP_REPLACE(
                  TRIM(POD_NAME),
                  '[[:space:]]+',
                  ' '
              )
          ) =
          UPPER(
              REGEXP_REPLACE(
                  TRIM(:P_POD_NAME),
                  '[[:space:]]+',
                  ' '
              )
          )

      AND UPPER(
              REGEXP_REPLACE(
                  TRIM(POD_LEAD_NAME),
                  '[[:space:]]+',
                  ' '
              )
          ) =
          UPPER(
              REGEXP_REPLACE(
                  TRIM(:P_POD_LEAD_NAME),
                  '[[:space:]]+',
                  ' '
              )
          )

      AND ACTIVE_FLAG = TRUE;


    IF (V_POD_COUNT = 0) THEN
        RETURN 'Nomination failed: The supplied Pod Lead is not authorised for the selected Pod.';
    END IF;


    IF (V_POD_COUNT > 1) THEN
        RETURN 'Nomination failed: More than one active Pod Lead configuration matched the supplied names.';
    END IF;


    /* Resolve the internal certification identifier using its business name. */

    SELECT
        COUNT(*),
        MIN(CERTIFICATION_ID)

    INTO
        :V_CERTIFICATION_COUNT,
        :V_CERTIFICATION_ID

    FROM CORE.CERTIFICATIONS

    WHERE UPPER(
              REGEXP_REPLACE(
                  TRIM(CERTIFICATION_NAME),
                  '[[:space:]]+',
                  ' '
              )
          ) =
          UPPER(
              REGEXP_REPLACE(
                  TRIM(:P_CERTIFICATION_NAME),
                  '[[:space:]]+',
                  ' '
              )
          )

      AND ACTIVE_FLAG = TRUE;


    IF (V_CERTIFICATION_COUNT = 0) THEN
        RETURN 'Nomination failed: The requested certification name is not active or does not exist.';
    END IF;


    IF (V_CERTIFICATION_COUNT > 1) THEN
        RETURN 'Nomination failed: More than one active certification matched the supplied name.';
    END IF;


    /* Confirm that the certification has active study topics. */

    SELECT
        COUNT(*)

    INTO
        :V_TOPIC_COUNT

    FROM CORE.STUDY_TOPICS ST

    JOIN CORE.EXAM_DOMAINS ED
        ON ST.DOMAIN_ID = ED.DOMAIN_ID

    WHERE ED.CERTIFICATION_ID = :V_CERTIFICATION_ID
      AND ST.ACTIVE_FLAG = TRUE
      AND ED.ACTIVE_FLAG = TRUE;


    IF (V_TOPIC_COUNT = 0) THEN
        RETURN 'Nomination failed: No active study topics were found for the certification.';
    END IF;


    /* The exam date is generated internally as seven days after completion. */

    V_TARGET_EXAM_DATE :=
        DATEADD(
            'DAY',
            7,
            P_TARGET_COMPLETION_DATE
        );


    /* Generate stable internal identifiers. */

    V_LEARNER_ID :=
        'LRN_' ||
        LEFT(
            SHA2(
                UPPER(TRIM(P_EMPLOYEE_ID)),
                256
            ),
            20
        );


    V_NOMINATION_ID :=
        'NOM_' ||
        LEFT(
            SHA2(
                UPPER(TRIM(P_EMPLOYEE_ID)) ||
                '_' ||
                UPPER(V_CERTIFICATION_ID),
                256
            ),
            20
        );


    V_ENROLLMENT_ID :=
        'ENR_' ||
        LEFT(
            SHA2(
                UPPER(TRIM(P_EMPLOYEE_ID)) ||
                '_' ||
                UPPER(V_CERTIFICATION_ID),
                256
            ),
            20
        );


    /*
      Preserve the original enrollment date when an existing nomination is
      updated. New enrollments start on the current processing date.
    */

    SELECT
        COALESCE(
            MAX(ENROLLED_DATE),
            CURRENT_DATE()
        )

    INTO
        :V_PLAN_START_DATE

    FROM CORE.ENROLLMENTS

    WHERE ENROLLMENT_ID = :V_ENROLLMENT_ID;


    /* Calculate the dynamic duration from the preserved plan start date. */

    V_PLAN_WEEKS :=
        GREATEST(
            1,
            CEIL(
                (
                    DATEDIFF(
                        'DAY',
                        V_PLAN_START_DATE,
                        P_TARGET_COMPLETION_DATE
                    ) + 1
                ) / 7.0
            )
        );


    /* Create or update the learner using the company employee ID as the key. */

    MERGE INTO CORE.LEARNERS AS TARGET

    USING (
        SELECT
            :V_LEARNER_ID AS LEARNER_ID,
            TRIM(:P_EMPLOYEE_ID) AS EMPLOYEE_ID,
            REGEXP_REPLACE(
                TRIM(:P_LEARNER_NAME),
                '[[:space:]]+',
                ' '
            ) AS LEARNER_NAME,
            LOWER(TRIM(:P_EMAIL)) AS EMAIL,
            REGEXP_REPLACE(
                TRIM(:P_DEPARTMENT_NAME),
                '[[:space:]]+',
                ' '
            ) AS DEPARTMENT_NAME,
            :P_SNOWFLAKE_EXPERIENCE_YEARS AS SNOWFLAKE_EXPERIENCE_YEARS
    ) AS SOURCE

    ON TARGET.LEARNER_ID = SOURCE.LEARNER_ID

    WHEN MATCHED THEN
        UPDATE SET
            LEARNER_NAME = SOURCE.LEARNER_NAME,
            EMAIL = SOURCE.EMAIL,
            DEPARTMENT_NAME = SOURCE.DEPARTMENT_NAME,
            SNOWFLAKE_EXPERIENCE_YEARS = SOURCE.SNOWFLAKE_EXPERIENCE_YEARS,
            EXPERIENCE_LEVEL_CODE = NULL,
            ACTIVE_FLAG = TRUE,
            UPDATED_AT = CURRENT_TIMESTAMP()

    WHEN NOT MATCHED THEN
        INSERT (
            LEARNER_ID,
            EMPLOYEE_ID,
            LEARNER_NAME,
            EMAIL,
            DEPARTMENT_NAME,
            SNOWFLAKE_EXPERIENCE_YEARS,
            EXPERIENCE_LEVEL_CODE,
            ACTIVE_FLAG,
            CREATED_AT,
            UPDATED_AT
        )

        VALUES (
            SOURCE.LEARNER_ID,
            SOURCE.EMPLOYEE_ID,
            SOURCE.LEARNER_NAME,
            SOURCE.EMAIL,
            SOURCE.DEPARTMENT_NAME,
            SOURCE.SNOWFLAKE_EXPERIENCE_YEARS,
            NULL,
            TRUE,
            CURRENT_TIMESTAMP(),
            CURRENT_TIMESTAMP()
        );


    /* Create or reactivate the learner's Pod membership. */

    MERGE INTO CORE.POD_MEMBERS AS TARGET

    USING (
        SELECT
            :V_POD_ID AS POD_ID,
            TRIM(:P_EMPLOYEE_ID) AS EMPLOYEE_ID
    ) AS SOURCE

    ON TARGET.POD_ID = SOURCE.POD_ID
    AND TARGET.EMPLOYEE_ID = SOURCE.EMPLOYEE_ID

    WHEN MATCHED THEN
        UPDATE SET
            ACTIVE_FLAG = TRUE,
            UPDATED_AT = CURRENT_TIMESTAMP()

    WHEN NOT MATCHED THEN
        INSERT (
            POD_ID,
            EMPLOYEE_ID,
            ACTIVE_FLAG,
            JOINED_AT,
            UPDATED_AT
        )

        VALUES (
            SOURCE.POD_ID,
            SOURCE.EMPLOYEE_ID,
            TRUE,
            CURRENT_TIMESTAMP(),
            CURRENT_TIMESTAMP()
        );


    /* Create or update the internal certification nomination. */

    MERGE INTO CORE.CERTIFICATION_NOMINATIONS AS TARGET

    USING (
        SELECT
            :V_NOMINATION_ID AS NOMINATION_ID,
            TRIM(:P_EMPLOYEE_ID) AS EMPLOYEE_ID,
            :V_POD_ID AS POD_ID,
            :V_POD_LEAD_EMPLOYEE_ID AS POD_LEAD_EMPLOYEE_ID,
            :V_CERTIFICATION_ID AS CERTIFICATION_ID,
            :P_TARGET_COMPLETION_DATE AS TARGET_COMPLETION_DATE,
            :V_TARGET_EXAM_DATE AS TARGET_EXAM_DATE,
            'Submitted through the unified certification nomination file.'
                AS NOMINATION_REASON
    ) AS SOURCE

    ON TARGET.NOMINATION_ID = SOURCE.NOMINATION_ID

    WHEN MATCHED THEN
        UPDATE SET
            POD_ID = SOURCE.POD_ID,
            POD_LEAD_EMPLOYEE_ID = SOURCE.POD_LEAD_EMPLOYEE_ID,
            TARGET_COMPLETION_DATE = SOURCE.TARGET_COMPLETION_DATE,
            TARGET_EXAM_DATE = SOURCE.TARGET_EXAM_DATE,
            NOMINATION_REASON = SOURCE.NOMINATION_REASON,
            NOMINATION_STATUS = 'APPROVED',
            UPDATED_AT = CURRENT_TIMESTAMP()

    WHEN NOT MATCHED THEN
        INSERT (
            NOMINATION_ID,
            EMPLOYEE_ID,
            POD_ID,
            POD_LEAD_EMPLOYEE_ID,
            CERTIFICATION_ID,
            NOMINATION_DATE,
            TARGET_COMPLETION_DATE,
            TARGET_EXAM_DATE,
            NOMINATION_REASON,
            NOMINATION_STATUS,
            CREATED_AT,
            UPDATED_AT
        )

        VALUES (
            SOURCE.NOMINATION_ID,
            SOURCE.EMPLOYEE_ID,
            SOURCE.POD_ID,
            SOURCE.POD_LEAD_EMPLOYEE_ID,
            SOURCE.CERTIFICATION_ID,
            CURRENT_DATE(),
            SOURCE.TARGET_COMPLETION_DATE,
            SOURCE.TARGET_EXAM_DATE,
            SOURCE.NOMINATION_REASON,
            'APPROVED',
            CURRENT_TIMESTAMP(),
            CURRENT_TIMESTAMP()
        );


    /* Create or update the dynamic enrollment. */

    MERGE INTO CORE.ENROLLMENTS AS TARGET

    USING (
        SELECT
            :V_ENROLLMENT_ID AS ENROLLMENT_ID,
            :V_LEARNER_ID AS LEARNER_ID,
            :V_CERTIFICATION_ID AS CERTIFICATION_ID,
            :V_NOMINATION_ID AS NOMINATION_ID,
            :V_POD_ID AS POD_ID,
            :V_POD_LEAD_EMPLOYEE_ID AS NOMINATED_BY_EMPLOYEE_ID,
            :P_TARGET_COMPLETION_DATE AS TARGET_COMPLETION_DATE,
            :V_TARGET_EXAM_DATE AS TARGET_EXAM_DATE
    ) AS SOURCE

    ON TARGET.ENROLLMENT_ID = SOURCE.ENROLLMENT_ID

    WHEN MATCHED THEN
        UPDATE SET
            PATH_ID = NULL,
            NOMINATION_ID = SOURCE.NOMINATION_ID,
            POD_ID = SOURCE.POD_ID,
            NOMINATED_BY_EMPLOYEE_ID = SOURCE.NOMINATED_BY_EMPLOYEE_ID,
            PLAN_TYPE = 'DYNAMIC',
            TARGET_COMPLETION_DATE = SOURCE.TARGET_COMPLETION_DATE,
            TARGET_EXAM_DATE = SOURCE.TARGET_EXAM_DATE,
            ENROLLMENT_STATUS = 'ACTIVE',
            UPDATED_AT = CURRENT_TIMESTAMP()

    WHEN NOT MATCHED THEN
        INSERT (
            ENROLLMENT_ID,
            LEARNER_ID,
            CERTIFICATION_ID,
            PATH_ID,
            ENROLLED_DATE,
            TARGET_COMPLETION_DATE,
            TARGET_EXAM_DATE,
            ENROLLMENT_STATUS,
            NOMINATION_ID,
            POD_ID,
            NOMINATED_BY_EMPLOYEE_ID,
            PLAN_TYPE,
            CREATED_AT,
            UPDATED_AT
        )

        VALUES (
            SOURCE.ENROLLMENT_ID,
            SOURCE.LEARNER_ID,
            SOURCE.CERTIFICATION_ID,
            NULL,
            CURRENT_DATE(),
            SOURCE.TARGET_COMPLETION_DATE,
            SOURCE.TARGET_EXAM_DATE,
            'ACTIVE',
            SOURCE.NOMINATION_ID,
            SOURCE.POD_ID,
            SOURCE.NOMINATED_BY_EMPLOYEE_ID,
            'DYNAMIC',
            CURRENT_TIMESTAMP(),
            CURRENT_TIMESTAMP()
        );


    /* Rebuild the learner-specific schedule after a date change. */

    DELETE FROM CORE.LEARNER_TOPIC_PLAN
    WHERE ENROLLMENT_ID = :V_ENROLLMENT_ID;


    INSERT INTO CORE.LEARNER_TOPIC_PLAN (
        ENROLLMENT_ID,
        TOPIC_ID,
        PLANNED_WEEK_NUMBER,
        PLANNED_START_DATE,
        PLANNED_END_DATE,
        RECOMMENDED_HOURS,
        REQUIRED_FLAG,
        CREATED_AT,
        UPDATED_AT
    )

    WITH ORDERED_TOPICS AS (
        SELECT
            ST.TOPIC_ID,
            ST.ESTIMATED_HOURS,

            ROW_NUMBER() OVER (
                ORDER BY
                    ED.DOMAIN_ORDER,
                    ST.TOPIC_ORDER,
                    ST.TOPIC_ID
            ) AS TOPIC_SEQUENCE,

            COUNT(*) OVER () AS TOTAL_TOPICS

        FROM CORE.STUDY_TOPICS ST

        JOIN CORE.EXAM_DOMAINS ED
            ON ST.DOMAIN_ID = ED.DOMAIN_ID

        WHERE ED.CERTIFICATION_ID = :V_CERTIFICATION_ID
          AND ST.ACTIVE_FLAG = TRUE
          AND ED.ACTIVE_FLAG = TRUE
    ),

    SCHEDULED_TOPICS AS (
        SELECT
            TOPIC_ID,
            ESTIMATED_HOURS,

            LEAST(
                :V_PLAN_WEEKS,
                GREATEST(
                    1,
                    CEIL(
                        (TOPIC_SEQUENCE * :V_PLAN_WEEKS) /
                        TOTAL_TOPICS
                    )
                )
            ) AS PLANNED_WEEK_NUMBER

        FROM ORDERED_TOPICS
    )

    SELECT
        :V_ENROLLMENT_ID,
        TOPIC_ID,
        PLANNED_WEEK_NUMBER,

        DATEADD(
            'WEEK',
            PLANNED_WEEK_NUMBER - 1,
            :V_PLAN_START_DATE
        ) AS PLANNED_START_DATE,

        LEAST(
            DATEADD(
                'DAY',
                6,
                DATEADD(
                    'WEEK',
                    PLANNED_WEEK_NUMBER - 1,
                    :V_PLAN_START_DATE
                )
            ),
            :P_TARGET_COMPLETION_DATE
        ) AS PLANNED_END_DATE,

        ESTIMATED_HOURS,
        TRUE,
        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP()

    FROM SCHEDULED_TOPICS;


    /* Initialize missing topic-progress records without deleting progress. */

    MERGE INTO CORE.TOPIC_PROGRESS AS TARGET

    USING (
        SELECT
            :V_ENROLLMENT_ID AS ENROLLMENT_ID,
            TOPIC_ID

        FROM CORE.LEARNER_TOPIC_PLAN

        WHERE ENROLLMENT_ID = :V_ENROLLMENT_ID
          AND REQUIRED_FLAG = TRUE
    ) AS SOURCE

    ON TARGET.ENROLLMENT_ID = SOURCE.ENROLLMENT_ID
    AND TARGET.TOPIC_ID = SOURCE.TOPIC_ID

    WHEN NOT MATCHED THEN
        INSERT (
            ENROLLMENT_ID,
            TOPIC_ID,
            PROGRESS_STATUS,
            COMPLETION_PERCENT,
            HOURS_SPENT,
            UPDATED_AT
        )

        VALUES (
            SOURCE.ENROLLMENT_ID,
            SOURCE.TOPIC_ID,
            'NOT_STARTED',
            0,
            0,
            CURRENT_TIMESTAMP()
        );


    RETURN
        'Learner nominated successfully. Pod: ' ||
        REGEXP_REPLACE(TRIM(P_POD_NAME), '[[:space:]]+', ' ') ||
        ', certification: ' ||
        REGEXP_REPLACE(TRIM(P_CERTIFICATION_NAME), '[[:space:]]+', ' ') ||
        ', dynamic duration: ' ||
        V_PLAN_WEEKS ||
        ' weeks, assigned topics: ' ||
        V_TOPIC_COUNT ||
        '.';

END;
$$;


/*==============================================================================
  4. VERIFICATION
==============================================================================*/

SHOW TABLES LIKE 'PODS'
IN SCHEMA DB_CERT_ENABLEMENT_DEV.CORE;

SHOW TABLES LIKE 'POD_MEMBERS'
IN SCHEMA DB_CERT_ENABLEMENT_DEV.CORE;

SHOW TABLES LIKE 'CERTIFICATION_NOMINATIONS'
IN SCHEMA DB_CERT_ENABLEMENT_DEV.CORE;

SHOW TABLES LIKE 'LEARNER_TOPIC_PLAN'
IN SCHEMA DB_CERT_ENABLEMENT_DEV.CORE;

SHOW PROCEDURES LIKE 'SP_NOMINATE_CERT_ENABLEMENT_LEARNER'
IN SCHEMA DB_CERT_ENABLEMENT_DEV.CONTROL;
