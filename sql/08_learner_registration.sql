/*==============================================================================
  SnowPro Core Enablement Platform
  Step 16: Real learner registration

  Purpose:
  - Register a real learner.
  - Assign a path based on Snowflake experience.
  - Create the learner's certification enrollment.
  - Initialize progress for all assigned topics.

  Important:
  Do not store real employee details in this Git file.
==============================================================================*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SNOWPRO_LEARNING_WH;
USE DATABASE SNOWPRO_ENABLEMENT;
USE SCHEMA CONTROL;


/*------------------------------------------------------------------------------
  Create the learner-registration procedure
------------------------------------------------------------------------------*/

CREATE OR REPLACE PROCEDURE CONTROL.REGISTER_LEARNER(
    P_EMPLOYEE_ID VARCHAR,
    P_LEARNER_NAME VARCHAR,
    P_EMAIL VARCHAR,
    P_DEPARTMENT_NAME VARCHAR,
    P_SNOWFLAKE_EXPERIENCE_YEARS NUMBER(4,1)
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
    V_EXPERIENCE_LEVEL_CODE VARCHAR;
    V_PATH_ID VARCHAR;
    V_DURATION_WEEKS NUMBER;
    V_LEARNER_ID VARCHAR;
    V_ENROLLMENT_ID VARCHAR;
    V_TARGET_COMPLETION_DATE DATE;
    V_TARGET_EXAM_DATE DATE;

BEGIN

    /* Validate required learner details */

    IF (
        P_EMPLOYEE_ID IS NULL
        OR TRIM(P_EMPLOYEE_ID) = ''
        OR P_LEARNER_NAME IS NULL
        OR TRIM(P_LEARNER_NAME) = ''
        OR P_EMAIL IS NULL
        OR TRIM(P_EMAIL) = ''
    ) THEN

        RETURN
            'Registration failed: Employee ID, learner name and email are required.';

    END IF;


    /* Validate Snowflake experience */

    IF (
        P_SNOWFLAKE_EXPERIENCE_YEARS IS NULL
        OR P_SNOWFLAKE_EXPERIENCE_YEARS < 0
    ) THEN

        RETURN
            'Registration failed: Snowflake experience must be zero or greater.';

    END IF;


    /* Determine the learner's experience level */

    IF (P_SNOWFLAKE_EXPERIENCE_YEARS = 0) THEN

        V_EXPERIENCE_LEVEL_CODE := 'FRESHER';

    ELSEIF (P_SNOWFLAKE_EXPERIENCE_YEARS <= 5) THEN

        V_EXPERIENCE_LEVEL_CODE := 'EXP_0_5';

    ELSEIF (P_SNOWFLAKE_EXPERIENCE_YEARS <= 9) THEN

        V_EXPERIENCE_LEVEL_CODE := 'EXP_5_9';

    ELSE

        V_EXPERIENCE_LEVEL_CODE := 'EXP_9_PLUS';

    END IF;


    /* Find the matching learning path */

    SELECT
        PATH_ID,
        DURATION_WEEKS

    INTO
        :V_PATH_ID,
        :V_DURATION_WEEKS

    FROM CORE.LEARNING_PATHS

    WHERE CERTIFICATION_ID = 'CERT_SNOWPRO_CORE'
      AND EXPERIENCE_LEVEL_CODE = :V_EXPERIENCE_LEVEL_CODE
      AND ACTIVE_FLAG = TRUE;


    /* Generate consistent learner and enrollment IDs */

    V_LEARNER_ID :=
        'LRN_' ||
        LEFT(
            SHA2(
                UPPER(TRIM(P_EMPLOYEE_ID)),
                256
            ),
            20
        );


    V_ENROLLMENT_ID :=
        'ENR_' ||
        LEFT(
            SHA2(
                UPPER(TRIM(P_EMPLOYEE_ID)) ||
                '_CERT_SNOWPRO_CORE',
                256
            ),
            20
        );


    /* Calculate the target dates */

    V_TARGET_COMPLETION_DATE :=
        DATEADD(
            'WEEK',
            V_DURATION_WEEKS,
            CURRENT_DATE()
        );


    V_TARGET_EXAM_DATE :=
        DATEADD(
            'DAY',
            7,
            V_TARGET_COMPLETION_DATE
        );


    /* Create the learner or update an existing learner */

    MERGE INTO CORE.LEARNERS AS TARGET

    USING (
        SELECT
            :V_LEARNER_ID AS LEARNER_ID,
            :P_EMPLOYEE_ID AS EMPLOYEE_ID,
            :P_LEARNER_NAME AS LEARNER_NAME,
            :P_EMAIL AS EMAIL,
            :P_DEPARTMENT_NAME AS DEPARTMENT_NAME,
            :P_SNOWFLAKE_EXPERIENCE_YEARS
                AS SNOWFLAKE_EXPERIENCE_YEARS,
            :V_EXPERIENCE_LEVEL_CODE
                AS EXPERIENCE_LEVEL_CODE
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
                SOURCE.EXPERIENCE_LEVEL_CODE,

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
            SOURCE.EXPERIENCE_LEVEL_CODE,
            TRUE,
            CURRENT_TIMESTAMP(),
            CURRENT_TIMESTAMP()
        );


    /* Create the enrollment or update an existing enrollment */

    MERGE INTO CORE.ENROLLMENTS AS TARGET

    USING (
        SELECT
            :V_ENROLLMENT_ID AS ENROLLMENT_ID,
            :V_LEARNER_ID AS LEARNER_ID,
            'CERT_SNOWPRO_CORE' AS CERTIFICATION_ID,
            :V_PATH_ID AS PATH_ID,
            :V_TARGET_COMPLETION_DATE
                AS TARGET_COMPLETION_DATE,
            :V_TARGET_EXAM_DATE
                AS TARGET_EXAM_DATE
    ) AS SOURCE

    ON TARGET.ENROLLMENT_ID = SOURCE.ENROLLMENT_ID


    WHEN MATCHED THEN

        UPDATE SET
            PATH_ID =
                SOURCE.PATH_ID,

            TARGET_COMPLETION_DATE =
                SOURCE.TARGET_COMPLETION_DATE,

            TARGET_EXAM_DATE =
                SOURCE.TARGET_EXAM_DATE,

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
            CREATED_AT,
            UPDATED_AT
        )

        VALUES (
            SOURCE.ENROLLMENT_ID,
            SOURCE.LEARNER_ID,
            SOURCE.CERTIFICATION_ID,
            SOURCE.PATH_ID,
            CURRENT_DATE(),
            SOURCE.TARGET_COMPLETION_DATE,
            SOURCE.TARGET_EXAM_DATE,
            'ACTIVE',
            CURRENT_TIMESTAMP(),
            CURRENT_TIMESTAMP()
        );


    /* Initialize all assigned topics for the learner */

    MERGE INTO CORE.TOPIC_PROGRESS AS TARGET

    USING (
        SELECT
            :V_ENROLLMENT_ID AS ENROLLMENT_ID,
            PTP.TOPIC_ID

        FROM CORE.PATH_TOPIC_PLAN PTP

        WHERE PTP.PATH_ID = :V_PATH_ID
          AND PTP.REQUIRED_FLAG = TRUE
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


    /* Return the registration result */

    RETURN
        'Learner registered successfully. Experience level: ' ||
        V_EXPERIENCE_LEVEL_CODE ||
        ', learning path: ' ||
        V_PATH_ID ||
        ', duration: ' ||
        V_DURATION_WEEKS ||
        ' weeks.';

END;
$$;


/*------------------------------------------------------------------------------
  Verify that the procedure was created
------------------------------------------------------------------------------*/

SHOW PROCEDURES LIKE 'REGISTER_LEARNER'
IN SCHEMA SNOWPRO_ENABLEMENT.CONTROL;