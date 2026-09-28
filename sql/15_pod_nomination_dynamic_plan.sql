/*==============================================================================
  Snowflake Certification Enablement Platform
  Step 15: Pod nomination and dynamic learning plan

  Purpose:
  - Store Pod and Pod Lead information.
  - Allow a Pod Lead to nominate an employee for certification.
  - Allow the Pod Lead to provide target completion and exam dates.
  - Create a learner-specific study schedule dynamically.
  - Stop using Snowflake experience to select a fixed timeline.

  Important:
  - Snowflake experience is retained as learner-profile information.
  - It is not used to calculate the learning-plan duration.
  - The Pod Lead controls the target dates.
==============================================================================*/


/*------------------------------------------------------------------------------
  1. Select the required Snowflake environment
------------------------------------------------------------------------------*/

USE ROLE ACCOUNTADMIN;

USE WAREHOUSE WH_CERT_ENABLEMENT_DEV_XS;

USE DATABASE DB_CERT_ENABLEMENT_DEV;

USE SCHEMA CORE;


/*==============================================================================
  2. POD MASTER TABLE
==============================================================================*/

/*------------------------------------------------------------------------------
  Stores each Pod and its authorised Pod Lead.

  The Pod Lead employee ID is used to validate certification nominations.
------------------------------------------------------------------------------*/

CREATE TABLE IF NOT EXISTS CORE.PODS (
    POD_ID                    VARCHAR(30)   NOT NULL,
    POD_NAME                  VARCHAR(200)  NOT NULL,
    POD_LEAD_EMPLOYEE_ID      VARCHAR(50)   NOT NULL,
    POD_LEAD_NAME             VARCHAR(200)  NOT NULL,
    POD_LEAD_EMAIL            VARCHAR(320)  NOT NULL,
    ACTIVE_FLAG               BOOLEAN       DEFAULT TRUE,
    CREATED_AT                TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT                TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_PODS
        PRIMARY KEY (POD_ID)
);


/*==============================================================================
  3. POD MEMBERSHIP TABLE
==============================================================================*/

/*------------------------------------------------------------------------------
  Stores the relationship between an employee and a Pod.

  For the current prototype, membership is created when the employee is
  successfully nominated.

  Future roadmap:
  Load approved Pod membership directly from the Mastech source file.
------------------------------------------------------------------------------*/

CREATE TABLE IF NOT EXISTS CORE.POD_MEMBERS (
    POD_ID                    VARCHAR(30)   NOT NULL,
    EMPLOYEE_ID               VARCHAR(50)   NOT NULL,
    ACTIVE_FLAG               BOOLEAN       DEFAULT TRUE,
    JOINED_AT                 TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT                TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_POD_MEMBERS
        PRIMARY KEY (POD_ID, EMPLOYEE_ID)
);


/*==============================================================================
  4. CERTIFICATION NOMINATION TABLE
==============================================================================*/

/*------------------------------------------------------------------------------
  Stores the certification recommendation made by the Pod Lead.

  The Pod Lead supplies:
  - Certification
  - Target completion date
  - Target exam date
  - Optional nomination reason
------------------------------------------------------------------------------*/

CREATE TABLE IF NOT EXISTS CORE.CERTIFICATION_NOMINATIONS (
    NOMINATION_ID             VARCHAR(50)    NOT NULL,
    EMPLOYEE_ID               VARCHAR(50)    NOT NULL,
    POD_ID                    VARCHAR(30)    NOT NULL,
    POD_LEAD_EMPLOYEE_ID      VARCHAR(50)    NOT NULL,
    CERTIFICATION_ID          VARCHAR(20)    NOT NULL,
    NOMINATION_DATE           DATE           NOT NULL,
    TARGET_COMPLETION_DATE    DATE           NOT NULL,
    TARGET_EXAM_DATE          DATE           NOT NULL,
    NOMINATION_REASON         VARCHAR(1000),
    NOMINATION_STATUS         VARCHAR(30)     DEFAULT 'APPROVED',
    CREATED_AT                TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT                TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_CERTIFICATION_NOMINATIONS
        PRIMARY KEY (NOMINATION_ID)
);


/*==============================================================================
  5. LEARNER-SPECIFIC DYNAMIC TOPIC PLAN
==============================================================================*/

/*------------------------------------------------------------------------------
  Stores the schedule calculated separately for each learner.

  Unlike PATH_TOPIC_PLAN, this table does not use a fixed Fresher,
  0–5, 5–9 or 9+ year duration.

  Topics are distributed between:
  - Nomination date
  - Pod Lead's target completion date
------------------------------------------------------------------------------*/

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

    CONSTRAINT PK_LEARNER_TOPIC_PLAN
        PRIMARY KEY (ENROLLMENT_ID, TOPIC_ID)
);


/*==============================================================================
  6. EXTEND THE EXISTING LEARNER AND ENROLLMENT TABLES
==============================================================================*/

/*------------------------------------------------------------------------------
  Experience level is now optional.

  Snowflake experience years may still be stored for reference, but the
  experience category no longer determines the learner's study timeline.
------------------------------------------------------------------------------*/

ALTER TABLE CORE.LEARNERS
    ALTER COLUMN EXPERIENCE_LEVEL_CODE DROP NOT NULL;


/*------------------------------------------------------------------------------
  PATH_ID was required by the earlier fixed-path design.

  It is now optional because dynamically planned learners do not use one of
  the earlier experience-based paths.
------------------------------------------------------------------------------*/

ALTER TABLE CORE.ENROLLMENTS
    ALTER COLUMN PATH_ID DROP NOT NULL;


/*------------------------------------------------------------------------------
  Add nomination and Pod information to each enrollment.
------------------------------------------------------------------------------*/

ALTER TABLE CORE.ENROLLMENTS
    ADD COLUMN IF NOT EXISTS NOMINATION_ID VARCHAR(50);

ALTER TABLE CORE.ENROLLMENTS
    ADD COLUMN IF NOT EXISTS POD_ID VARCHAR(30);

ALTER TABLE CORE.ENROLLMENTS
    ADD COLUMN IF NOT EXISTS NOMINATED_BY_EMPLOYEE_ID VARCHAR(50);

ALTER TABLE CORE.ENROLLMENTS
    ADD COLUMN IF NOT EXISTS PLAN_TYPE VARCHAR(30);


/*==============================================================================
  7. POD-LEAD NOMINATION PROCEDURE
==============================================================================*/

/*------------------------------------------------------------------------------
  Procedure workflow:

  1. Validate learner, Pod Lead and target-date information.
  2. Confirm that the supplied employee is the active lead of the Pod.
  3. Create or update the learner.
  4. Record the employee's Pod membership.
  5. Create or update the certification nomination.
  6. Create or update the certification enrollment.
  7. Calculate the available number of study weeks.
  8. Distribute active certification topics across those weeks.
  9. Initialize progress tracking for all assigned topics.
------------------------------------------------------------------------------*/

CREATE OR REPLACE PROCEDURE
CONTROL.SP_NOMINATE_CERT_ENABLEMENT_LEARNER(
    P_EMPLOYEE_ID                  VARCHAR,
    P_LEARNER_NAME                 VARCHAR,
    P_EMAIL                        VARCHAR,
    P_DEPARTMENT_NAME              VARCHAR,
    P_SNOWFLAKE_EXPERIENCE_YEARS   NUMBER(4,1),
    P_POD_ID                       VARCHAR,
    P_POD_LEAD_EMPLOYEE_ID         VARCHAR,
    P_CERTIFICATION_ID             VARCHAR,
    P_TARGET_COMPLETION_DATE       DATE,
    P_TARGET_EXAM_DATE             DATE,
    P_NOMINATION_REASON            VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$

DECLARE
    V_POD_COUNT             NUMBER DEFAULT 0;
    V_CERTIFICATION_COUNT   NUMBER DEFAULT 0;
    V_TOPIC_COUNT           NUMBER DEFAULT 0;
    V_PLAN_WEEKS            NUMBER DEFAULT 0;

    V_LEARNER_ID            VARCHAR;
    V_NOMINATION_ID         VARCHAR;
    V_ENROLLMENT_ID         VARCHAR;

BEGIN

    /*--------------------------------------------------------------------------
      Validate mandatory learner information
    --------------------------------------------------------------------------*/

    IF (
        P_EMPLOYEE_ID IS NULL
        OR TRIM(P_EMPLOYEE_ID) = ''
        OR P_LEARNER_NAME IS NULL
        OR TRIM(P_LEARNER_NAME) = ''
        OR P_EMAIL IS NULL
        OR TRIM(P_EMAIL) = ''
        OR P_POD_ID IS NULL
        OR TRIM(P_POD_ID) = ''
        OR P_POD_LEAD_EMPLOYEE_ID IS NULL
        OR TRIM(P_POD_LEAD_EMPLOYEE_ID) = ''
        OR P_CERTIFICATION_ID IS NULL
        OR TRIM(P_CERTIFICATION_ID) = ''
    ) THEN

        RETURN
            'Nomination failed: Learner, Pod, Pod Lead and certification details are required.';

    END IF;


    /*--------------------------------------------------------------------------
      Validate Snowflake experience

      Experience is stored only as learner-profile information.
      It does not select or control the learning timeline.
    --------------------------------------------------------------------------*/

    IF (
        P_SNOWFLAKE_EXPERIENCE_YEARS IS NULL
        OR P_SNOWFLAKE_EXPERIENCE_YEARS < 0
    ) THEN

        RETURN
            'Nomination failed: Snowflake experience must be zero or greater.';

    END IF;


    /*--------------------------------------------------------------------------
      Validate the Pod Lead's target dates
    --------------------------------------------------------------------------*/

    IF (
        P_TARGET_COMPLETION_DATE IS NULL
        OR P_TARGET_EXAM_DATE IS NULL
    ) THEN

        RETURN
            'Nomination failed: Target completion and exam dates are required.';

    END IF;


    IF (P_TARGET_COMPLETION_DATE <= CURRENT_DATE()) THEN

        RETURN
            'Nomination failed: Target completion date must be in the future.';

    END IF;


    IF (P_TARGET_EXAM_DATE < P_TARGET_COMPLETION_DATE) THEN

        RETURN
            'Nomination failed: Target exam date cannot be earlier than the target completion date.';

    END IF;


    /*--------------------------------------------------------------------------
      Confirm that the Pod exists and the nominated lead is its active Pod Lead
    --------------------------------------------------------------------------*/

    SELECT
        COUNT(*)

    INTO
        :V_POD_COUNT

    FROM CORE.PODS

    WHERE UPPER(POD_ID) = UPPER(TRIM(:P_POD_ID))
      AND UPPER(POD_LEAD_EMPLOYEE_ID) =
          UPPER(TRIM(:P_POD_LEAD_EMPLOYEE_ID))
      AND ACTIVE_FLAG = TRUE;


    IF (V_POD_COUNT = 0) THEN

        RETURN
            'Nomination failed: The supplied Pod Lead is not authorised for this Pod.';

    END IF;


    /*--------------------------------------------------------------------------
      Confirm that the requested certification is active
    --------------------------------------------------------------------------*/

    SELECT
        COUNT(*)

    INTO
        :V_CERTIFICATION_COUNT

    FROM CORE.CERTIFICATIONS

    WHERE UPPER(CERTIFICATION_ID) =
          UPPER(TRIM(:P_CERTIFICATION_ID))
      AND ACTIVE_FLAG = TRUE;


    IF (V_CERTIFICATION_COUNT = 0) THEN

        RETURN
            'Nomination failed: The requested certification is not active or does not exist.';

    END IF;


    /*--------------------------------------------------------------------------
      Confirm that study topics exist for the certification
    --------------------------------------------------------------------------*/

    SELECT
        COUNT(*)

    INTO
        :V_TOPIC_COUNT

    FROM CORE.STUDY_TOPICS ST

    JOIN CORE.EXAM_DOMAINS ED
        ON ST.DOMAIN_ID = ED.DOMAIN_ID

    WHERE UPPER(ED.CERTIFICATION_ID) =
          UPPER(TRIM(:P_CERTIFICATION_ID))
      AND ST.ACTIVE_FLAG = TRUE
      AND ED.ACTIVE_FLAG = TRUE;


    IF (V_TOPIC_COUNT = 0) THEN

        RETURN
            'Nomination failed: No active study topics were found for the certification.';

    END IF;


    /*--------------------------------------------------------------------------
      Calculate the number of available study weeks

      The duration is calculated from today to the Pod Lead's target
      completion date. It is not taken from a fixed experience-based path.
    --------------------------------------------------------------------------*/

    V_PLAN_WEEKS :=
        GREATEST(
            1,
            CEIL(
                (
                    DATEDIFF(
                        'DAY',
                        CURRENT_DATE(),
                        P_TARGET_COMPLETION_DATE
                    ) + 1
                ) / 7.0
            )
        );


    /*--------------------------------------------------------------------------
      Generate repeatable learner, nomination and enrollment IDs
    --------------------------------------------------------------------------*/

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
                UPPER(TRIM(P_CERTIFICATION_ID)),
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
                UPPER(TRIM(P_CERTIFICATION_ID)),
                256
            ),
            20
        );


    /*--------------------------------------------------------------------------
      Create the learner or update the existing learner
    --------------------------------------------------------------------------*/

    MERGE INTO CORE.LEARNERS AS TARGET

    USING (
        SELECT
            :V_LEARNER_ID AS LEARNER_ID,
            TRIM(:P_EMPLOYEE_ID) AS EMPLOYEE_ID,
            TRIM(:P_LEARNER_NAME) AS LEARNER_NAME,
            LOWER(TRIM(:P_EMAIL)) AS EMAIL,
            TRIM(:P_DEPARTMENT_NAME) AS DEPARTMENT_NAME,
            :P_SNOWFLAKE_EXPERIENCE_YEARS
                AS SNOWFLAKE_EXPERIENCE_YEARS
    ) AS SOURCE

    ON TARGET.LEARNER_ID = SOURCE.LEARNER_ID

    WHEN MATCHED THEN

        UPDATE SET
            LEARNER_NAME =
                SOURCE.LEARNER_NAME,

            EMAIL =
                SOURCE.EMAIL,

            DEPARTMENT_NAME =
                SOURCE.DEPARTMENT_NAME,

            SNOWFLAKE_EXPERIENCE_YEARS =
                SOURCE.SNOWFLAKE_EXPERIENCE_YEARS,

            EXPERIENCE_LEVEL_CODE =
                NULL,

            ACTIVE_FLAG =
                TRUE,

            UPDATED_AT =
                CURRENT_TIMESTAMP()

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


    /*--------------------------------------------------------------------------
      Record or reactivate the learner's Pod membership
    --------------------------------------------------------------------------*/

    MERGE INTO CORE.POD_MEMBERS AS TARGET

    USING (
        SELECT
            UPPER(TRIM(:P_POD_ID)) AS POD_ID,
            TRIM(:P_EMPLOYEE_ID) AS EMPLOYEE_ID
    ) AS SOURCE

    ON TARGET.POD_ID = SOURCE.POD_ID
    AND TARGET.EMPLOYEE_ID = SOURCE.EMPLOYEE_ID

    WHEN MATCHED THEN

        UPDATE SET
            ACTIVE_FLAG =
                TRUE,

            UPDATED_AT =
                CURRENT_TIMESTAMP()

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


    /*--------------------------------------------------------------------------
      Create or update the Pod Lead's nomination
    --------------------------------------------------------------------------*/

    MERGE INTO CORE.CERTIFICATION_NOMINATIONS AS TARGET

    USING (
        SELECT
            :V_NOMINATION_ID AS NOMINATION_ID,
            TRIM(:P_EMPLOYEE_ID) AS EMPLOYEE_ID,
            UPPER(TRIM(:P_POD_ID)) AS POD_ID,
            TRIM(:P_POD_LEAD_EMPLOYEE_ID)
                AS POD_LEAD_EMPLOYEE_ID,
            UPPER(TRIM(:P_CERTIFICATION_ID))
                AS CERTIFICATION_ID,
            :P_TARGET_COMPLETION_DATE
                AS TARGET_COMPLETION_DATE,
            :P_TARGET_EXAM_DATE
                AS TARGET_EXAM_DATE,
            :P_NOMINATION_REASON
                AS NOMINATION_REASON
    ) AS SOURCE

    ON TARGET.NOMINATION_ID = SOURCE.NOMINATION_ID

    WHEN MATCHED THEN

        UPDATE SET
            POD_ID =
                SOURCE.POD_ID,

            POD_LEAD_EMPLOYEE_ID =
                SOURCE.POD_LEAD_EMPLOYEE_ID,

            TARGET_COMPLETION_DATE =
                SOURCE.TARGET_COMPLETION_DATE,

            TARGET_EXAM_DATE =
                SOURCE.TARGET_EXAM_DATE,

            NOMINATION_REASON =
                SOURCE.NOMINATION_REASON,

            NOMINATION_STATUS =
                'APPROVED',

            UPDATED_AT =
                CURRENT_TIMESTAMP()

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


    /*--------------------------------------------------------------------------
      Create or update the learner's enrollment

      PATH_ID is NULL because this enrollment uses a dynamic learner-specific
      plan instead of a fixed experience-based path.
    --------------------------------------------------------------------------*/

    MERGE INTO CORE.ENROLLMENTS AS TARGET

    USING (
        SELECT
            :V_ENROLLMENT_ID AS ENROLLMENT_ID,
            :V_LEARNER_ID AS LEARNER_ID,
            UPPER(TRIM(:P_CERTIFICATION_ID))
                AS CERTIFICATION_ID,
            :V_NOMINATION_ID AS NOMINATION_ID,
            UPPER(TRIM(:P_POD_ID)) AS POD_ID,
            TRIM(:P_POD_LEAD_EMPLOYEE_ID)
                AS NOMINATED_BY_EMPLOYEE_ID,
            :P_TARGET_COMPLETION_DATE
                AS TARGET_COMPLETION_DATE,
            :P_TARGET_EXAM_DATE
                AS TARGET_EXAM_DATE
    ) AS SOURCE

    ON TARGET.ENROLLMENT_ID = SOURCE.ENROLLMENT_ID

    WHEN MATCHED THEN

        UPDATE SET
            PATH_ID =
                NULL,

            NOMINATION_ID =
                SOURCE.NOMINATION_ID,

            POD_ID =
                SOURCE.POD_ID,

            NOMINATED_BY_EMPLOYEE_ID =
                SOURCE.NOMINATED_BY_EMPLOYEE_ID,

            PLAN_TYPE =
                'DYNAMIC',

            TARGET_COMPLETION_DATE =
                SOURCE.TARGET_COMPLETION_DATE,

            TARGET_EXAM_DATE =
                SOURCE.TARGET_EXAM_DATE,

            ENROLLMENT_STATUS =
                'ACTIVE',

            UPDATED_AT =
                CURRENT_TIMESTAMP()

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


    /*--------------------------------------------------------------------------
      Rebuild the learner-specific schedule

      This allows a Pod Lead to update the target completion date and have the
      learner's topic schedule recalculated.
    --------------------------------------------------------------------------*/

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

        WHERE UPPER(ED.CERTIFICATION_ID) =
              UPPER(TRIM(:P_CERTIFICATION_ID))
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
                        (
                            TOPIC_SEQUENCE *
                            :V_PLAN_WEEKS
                        ) /
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
            CURRENT_DATE()
        ) AS PLANNED_START_DATE,

        LEAST(
            DATEADD(
                'DAY',
                6,

                DATEADD(
                    'WEEK',
                    PLANNED_WEEK_NUMBER - 1,
                    CURRENT_DATE()
                )
            ),

            :P_TARGET_COMPLETION_DATE
        ) AS PLANNED_END_DATE,

        ESTIMATED_HOURS,
        TRUE,
        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP()

    FROM SCHEDULED_TOPICS;


    /*--------------------------------------------------------------------------
      Initialize topic-progress tracking

      Existing progress is preserved. Only missing topics are initialized.
    --------------------------------------------------------------------------*/

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


    /*--------------------------------------------------------------------------
      Return the nomination result
    --------------------------------------------------------------------------*/

    RETURN
        'Learner nominated successfully. Pod: ' ||
        UPPER(TRIM(P_POD_ID)) ||
        ', certification: ' ||
        UPPER(TRIM(P_CERTIFICATION_ID)) ||
        ', dynamic duration: ' ||
        V_PLAN_WEEKS ||
        ' weeks, assigned topics: ' ||
        V_TOPIC_COUNT ||
        '.';

END;
$$;


/*==============================================================================
  8. VERIFICATION COMMANDS
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