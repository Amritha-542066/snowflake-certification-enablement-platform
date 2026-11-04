/*=============================================================================
  FILE: 04_create_nomination_foundation.sql

  PURPOSE:
  Create the physical nomination foundation for the Snowflake Certification
  Enablement Native App.

  EXECUTION ORDER:
  1. 01_create_user_identity_model.sql
  2. 02_seed_user_identity_demo_data.sql
  3. 03_create_and_seed_certification_catalog.sql
  4. 04_create_nomination_foundation.sql  <-- this file

  BUSINESS RULES IMPLEMENTED:
  - An active Pod Lead may nominate only an active member of their own active
    Pod.
  - A Pod Member's self-request is routed to that member's Pod Lead.
  - A Pod Lead's self-request is routed to the active Studio Lead.
  - A Pod Lead nomination is stored as PENDING_CANDIDATE_RESPONSE. The full
    candidate-response workflow is intentionally deferred to the roadmap.
  - A target completion date must be later than the preparation start date.
  - Duplicate pending requests for the same candidate and certification are
    rejected.
  - Every initial status and approval decision is recorded in status history.

  SECURITY NOTE:
  Native App procedures run with owner rights, as required by Snowflake. The
  Streamlit layer supplies the authenticated employee identity. Persona Preview
  remains read-only and must never call these procedures.
=============================================================================*/


/*-----------------------------------------------------------------------------
  SECTION 1: NOMINATION TRANSACTION TABLE

  Stores one row for every self-request or Pod Lead nomination. The record is
  retained even when a later decision rejects or cancels the request.
-----------------------------------------------------------------------------*/

CREATE TABLE IF NOT EXISTS CORE.NOMINATIONS (
    NOMINATION_ID                 VARCHAR(36)  NOT NULL,
    NOMINATION_TYPE               VARCHAR(30)  NOT NULL,
    NOMINATOR_EMPLOYEE_ID         VARCHAR(20)  NOT NULL,
    CANDIDATE_EMPLOYEE_ID         VARCHAR(20)  NOT NULL,
    CERTIFICATION_ID              VARCHAR(20)  NOT NULL,
    POD_ID                        VARCHAR(20),
    PREPARATION_START_DATE        DATE         NOT NULL,
    TARGET_COMPLETION_DATE        DATE         NOT NULL,
    NOMINATION_STATUS             VARCHAR(40)  NOT NULL,
    ASSIGNED_REVIEWER_EMPLOYEE_ID VARCHAR(20),
    REQUEST_NOTES                 VARCHAR(2000),
    DECISION_NOTES                VARCHAR(2000),
    CREATED_BY_SNOWFLAKE_USERNAME VARCHAR(255) NOT NULL,
    CREATED_AT                    TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT                    TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    DECIDED_AT                    TIMESTAMP_NTZ,

    CONSTRAINT PK_NOMINATIONS
        PRIMARY KEY (NOMINATION_ID),

    CONSTRAINT FK_NOMINATIONS_NOMINATOR
        FOREIGN KEY (NOMINATOR_EMPLOYEE_ID)
        REFERENCES CORE.EMPLOYEES (EMPLOYEE_ID),

    CONSTRAINT FK_NOMINATIONS_CANDIDATE
        FOREIGN KEY (CANDIDATE_EMPLOYEE_ID)
        REFERENCES CORE.EMPLOYEES (EMPLOYEE_ID),

    CONSTRAINT FK_NOMINATIONS_CERTIFICATION
        FOREIGN KEY (CERTIFICATION_ID)
        REFERENCES CORE.CERTIFICATIONS (CERTIFICATION_ID),

    CONSTRAINT FK_NOMINATIONS_POD
        FOREIGN KEY (POD_ID)
        REFERENCES CORE.PODS (POD_ID),

    CONSTRAINT FK_NOMINATIONS_REVIEWER
        FOREIGN KEY (ASSIGNED_REVIEWER_EMPLOYEE_ID)
        REFERENCES CORE.EMPLOYEES (EMPLOYEE_ID),

    CONSTRAINT CK_NOMINATIONS_TYPE
        CHECK (
            NOMINATION_TYPE IN (
                'SELF_REQUEST',
                'POD_LEAD_NOMINATION'
            )
        ),

    CONSTRAINT CK_NOMINATIONS_STATUS
        CHECK (
            NOMINATION_STATUS IN (
                'PENDING_APPROVAL',
                'PENDING_CANDIDATE_RESPONSE',
                'APPROVED',
                'REJECTED',
                'CANCELLED'
            )
        ),

    CONSTRAINT CK_NOMINATIONS_DATES
        CHECK (TARGET_COMPLETION_DATE > PREPARATION_START_DATE)
);


/*-----------------------------------------------------------------------------
  SECTION 2: NOMINATION STATUS HISTORY

  Stores an append-only record of the initial status and every later decision.
-----------------------------------------------------------------------------*/

CREATE TABLE IF NOT EXISTS CORE.NOMINATION_STATUS_HISTORY (
    STATUS_HISTORY_ID             VARCHAR(36)  NOT NULL,
    NOMINATION_ID                 VARCHAR(36)  NOT NULL,
    FROM_STATUS                   VARCHAR(40),
    TO_STATUS                     VARCHAR(40)  NOT NULL,
    CHANGED_BY_EMPLOYEE_ID        VARCHAR(20)  NOT NULL,
    CHANGE_NOTES                  VARCHAR(2000),
    CHANGED_AT                    TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_NOMINATION_STATUS_HISTORY
        PRIMARY KEY (STATUS_HISTORY_ID),

    CONSTRAINT FK_STATUS_HISTORY_NOMINATION
        FOREIGN KEY (NOMINATION_ID)
        REFERENCES CORE.NOMINATIONS (NOMINATION_ID),

    CONSTRAINT FK_STATUS_HISTORY_CHANGED_BY
        FOREIGN KEY (CHANGED_BY_EMPLOYEE_ID)
        REFERENCES CORE.EMPLOYEES (EMPLOYEE_ID)
);


/*-----------------------------------------------------------------------------
  SECTION 3: ELIGIBLE POD MEMBERS VIEW

  Produces only valid Pod Lead-to-member combinations. Streamlit filters this
  view by POD_LEAD_EMPLOYEE_ID, preventing a lead from selecting a member from
  another Pod.
-----------------------------------------------------------------------------*/

CREATE OR REPLACE VIEW APP_SCHEMA.VW_ELIGIBLE_POD_MEMBERS AS
SELECT
    P.POD_ID,
    P.POD_NAME,
    P.POD_LEAD_EMPLOYEE_ID,
    LEAD_EMPLOYEE.SNOWFLAKE_USERNAME AS POD_LEAD_SNOWFLAKE_USERNAME,
    LEAD_EMPLOYEE.EMPLOYEE_NAME      AS POD_LEAD_NAME,
    MEMBER.EMPLOYEE_ID               AS MEMBER_EMPLOYEE_ID,
    MEMBER.SNOWFLAKE_USERNAME        AS MEMBER_SNOWFLAKE_USERNAME,
    MEMBER.EMPLOYEE_NAME             AS MEMBER_NAME,
    MEMBER.DESIGNATION               AS MEMBER_DESIGNATION,
    PM.JOINED_DATE
FROM CORE.PODS AS P

INNER JOIN CORE.EMPLOYEES AS LEAD_EMPLOYEE
    ON P.POD_LEAD_EMPLOYEE_ID = LEAD_EMPLOYEE.EMPLOYEE_ID
   AND LEAD_EMPLOYEE.ACTIVE_FLAG = TRUE

INNER JOIN CORE.POD_MEMBERSHIPS AS PM
    ON P.POD_ID = PM.POD_ID
   AND PM.ACTIVE_FLAG = TRUE

INNER JOIN CORE.EMPLOYEES AS MEMBER
    ON PM.EMPLOYEE_ID = MEMBER.EMPLOYEE_ID
   AND MEMBER.ACTIVE_FLAG = TRUE

WHERE P.ACTIVE_FLAG = TRUE;


/*-----------------------------------------------------------------------------
  SECTION 4: NOMINATION DETAILS VIEW

  Provides business-friendly nomination information for request history and
  reviewer queues without exposing the physical transaction tables directly.
-----------------------------------------------------------------------------*/

CREATE OR REPLACE VIEW APP_SCHEMA.VW_NOMINATION_DETAILS AS
SELECT
    N.NOMINATION_ID,
    N.NOMINATION_TYPE,
    N.NOMINATOR_EMPLOYEE_ID,
    NOMINATOR.EMPLOYEE_NAME          AS NOMINATOR_NAME,
    NOMINATOR.SNOWFLAKE_USERNAME     AS NOMINATOR_SNOWFLAKE_USERNAME,
    N.CANDIDATE_EMPLOYEE_ID,
    CANDIDATE.EMPLOYEE_NAME          AS CANDIDATE_NAME,
    CANDIDATE.SNOWFLAKE_USERNAME     AS CANDIDATE_SNOWFLAKE_USERNAME,
    N.CERTIFICATION_ID,
    C.CERTIFICATION_CODE,
    C.CERTIFICATION_NAME,
    C.CERTIFICATION_LEVEL,
    N.POD_ID,
    P.POD_NAME,
    N.PREPARATION_START_DATE,
    N.TARGET_COMPLETION_DATE,
    N.NOMINATION_STATUS,
    N.ASSIGNED_REVIEWER_EMPLOYEE_ID,
    REVIEWER.EMPLOYEE_NAME           AS ASSIGNED_REVIEWER_NAME,
    REVIEWER.SNOWFLAKE_USERNAME      AS REVIEWER_SNOWFLAKE_USERNAME,
    N.REQUEST_NOTES,
    N.DECISION_NOTES,
    N.CREATED_BY_SNOWFLAKE_USERNAME,
    N.CREATED_AT,
    N.UPDATED_AT,
    N.DECIDED_AT
FROM CORE.NOMINATIONS AS N

INNER JOIN CORE.EMPLOYEES AS NOMINATOR
    ON N.NOMINATOR_EMPLOYEE_ID = NOMINATOR.EMPLOYEE_ID

INNER JOIN CORE.EMPLOYEES AS CANDIDATE
    ON N.CANDIDATE_EMPLOYEE_ID = CANDIDATE.EMPLOYEE_ID

INNER JOIN CORE.CERTIFICATIONS AS C
    ON N.CERTIFICATION_ID = C.CERTIFICATION_ID

LEFT JOIN CORE.PODS AS P
    ON N.POD_ID = P.POD_ID

LEFT JOIN CORE.EMPLOYEES AS REVIEWER
    ON N.ASSIGNED_REVIEWER_EMPLOYEE_ID = REVIEWER.EMPLOYEE_ID;


/*-----------------------------------------------------------------------------
  SECTION 5: SUBMIT NOMINATION PROCEDURE

  Validates a request, determines its type and reviewer, prevents duplicate
  pending requests, inserts the nomination and records its initial status.

  RETURN VALUE:
  A VARIANT object containing SUCCESS, MESSAGE, NOMINATION_ID, STATUS and
  ASSIGNED_REVIEWER_EMPLOYEE_ID.
-----------------------------------------------------------------------------*/

CREATE OR REPLACE PROCEDURE APP_SCHEMA.SP_SUBMIT_NOMINATION (
    P_NOMINATOR_EMPLOYEE_ID         VARCHAR,
    P_CANDIDATE_EMPLOYEE_ID         VARCHAR,
    P_CERTIFICATION_ID              VARCHAR,
    P_PREPARATION_START_DATE        DATE,
    P_TARGET_COMPLETION_DATE        DATE,
    P_REQUEST_NOTES                 VARCHAR,
    P_CREATED_BY_SNOWFLAKE_USERNAME VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
    V_NOMINATION_ID             VARCHAR;
    V_NOMINATION_TYPE           VARCHAR;
    V_INITIAL_STATUS            VARCHAR;
    V_ASSIGNED_REVIEWER_ID      VARCHAR;
    V_NOMINATOR_ROLE_CODE       VARCHAR;
    V_NOMINATOR_POD_ID          VARCHAR;
    V_NOMINATOR_POD_LEAD_ID     VARCHAR;
    V_CANDIDATE_POD_ID          VARCHAR;
    V_CANDIDATE_POD_LEAD_ID     VARCHAR;
    V_NOMINATOR_COUNT           NUMBER;
    V_CANDIDATE_COUNT           NUMBER;
    V_CERTIFICATION_COUNT       NUMBER;
    V_ELIGIBLE_MEMBER_COUNT     NUMBER;
    V_DUPLICATE_COUNT           NUMBER;
    V_REQUEST_NOTES             VARCHAR;
    V_STATUS_HISTORY_ID         VARCHAR;
BEGIN
    IF (P_NOMINATOR_EMPLOYEE_ID IS NULL
        OR P_CANDIDATE_EMPLOYEE_ID IS NULL
        OR P_CERTIFICATION_ID IS NULL
        OR P_PREPARATION_START_DATE IS NULL
        OR P_TARGET_COMPLETION_DATE IS NULL
        OR P_CREATED_BY_SNOWFLAKE_USERNAME IS NULL) THEN
        RETURN OBJECT_CONSTRUCT(
            'SUCCESS', FALSE,
            'MESSAGE', 'All required nomination values must be supplied.'
        );
    END IF;

    IF (P_TARGET_COMPLETION_DATE <= P_PREPARATION_START_DATE) THEN
        RETURN OBJECT_CONSTRUCT(
            'SUCCESS', FALSE,
            'MESSAGE', 'The target completion date must be later than the preparation start date.'
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(ROLE_CODE),
        MAX(POD_ID),
        MAX(POD_LEAD_EMPLOYEE_ID)
    INTO
        :V_NOMINATOR_COUNT,
        :V_NOMINATOR_ROLE_CODE,
        :V_NOMINATOR_POD_ID,
        :V_NOMINATOR_POD_LEAD_ID
    FROM APP_SCHEMA.VW_USER_CONTEXT
    WHERE EMPLOYEE_ID = :P_NOMINATOR_EMPLOYEE_ID
      AND EMPLOYEE_ACTIVE_FLAG = TRUE;

    IF (V_NOMINATOR_COUNT = 0 OR V_NOMINATOR_ROLE_CODE IS NULL) THEN
        RETURN OBJECT_CONSTRUCT(
            'SUCCESS', FALSE,
            'MESSAGE', 'The nominator does not have an active platform profile and role.'
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(POD_ID),
        MAX(POD_LEAD_EMPLOYEE_ID)
    INTO
        :V_CANDIDATE_COUNT,
        :V_CANDIDATE_POD_ID,
        :V_CANDIDATE_POD_LEAD_ID
    FROM APP_SCHEMA.VW_USER_CONTEXT
    WHERE EMPLOYEE_ID = :P_CANDIDATE_EMPLOYEE_ID
      AND EMPLOYEE_ACTIVE_FLAG = TRUE;

    IF (V_CANDIDATE_COUNT = 0) THEN
        RETURN OBJECT_CONSTRUCT(
            'SUCCESS', FALSE,
            'MESSAGE', 'The candidate does not have an active platform profile.'
        );
    END IF;

    SELECT COUNT(*)
    INTO :V_CERTIFICATION_COUNT
    FROM CORE.CERTIFICATIONS
    WHERE CERTIFICATION_ID = :P_CERTIFICATION_ID
      AND ACTIVE_FLAG = TRUE;

    IF (V_CERTIFICATION_COUNT = 0) THEN
        RETURN OBJECT_CONSTRUCT(
            'SUCCESS', FALSE,
            'MESSAGE', 'The selected certification is not active or does not exist.'
        );
    END IF;

    IF (P_NOMINATOR_EMPLOYEE_ID = P_CANDIDATE_EMPLOYEE_ID) THEN
        V_NOMINATION_TYPE := 'SELF_REQUEST';
        V_INITIAL_STATUS := 'PENDING_APPROVAL';

        IF (V_NOMINATOR_ROLE_CODE = 'POD_MEMBER') THEN
            IF (V_NOMINATOR_POD_ID IS NULL OR V_NOMINATOR_POD_LEAD_ID IS NULL) THEN
                RETURN OBJECT_CONSTRUCT(
                    'SUCCESS', FALSE,
                    'MESSAGE', 'A Pod Member must belong to an active Pod before submitting a self-request.'
                );
            END IF;

            V_ASSIGNED_REVIEWER_ID := V_NOMINATOR_POD_LEAD_ID;

        ELSEIF (V_NOMINATOR_ROLE_CODE = 'POD_LEAD') THEN
            SELECT MAX(EMPLOYEE_ID)
            INTO :V_ASSIGNED_REVIEWER_ID
            FROM APP_SCHEMA.VW_USER_CONTEXT
            WHERE ROLE_CODE = 'STUDIO_LEAD'
              AND EMPLOYEE_ACTIVE_FLAG = TRUE;

            IF (V_ASSIGNED_REVIEWER_ID IS NULL) THEN
                RETURN OBJECT_CONSTRUCT(
                    'SUCCESS', FALSE,
                    'MESSAGE', 'No active Studio Lead is available to review this request.'
                );
            END IF;

        ELSEIF (V_NOMINATOR_ROLE_CODE = 'STUDIO_LEAD') THEN
            RETURN OBJECT_CONSTRUCT(
                'SUCCESS', FALSE,
                'MESSAGE', 'Studio Lead self-request routing requires a business decision and is not enabled in this milestone.'
            );

        ELSE
            RETURN OBJECT_CONSTRUCT(
                'SUCCESS', FALSE,
                'MESSAGE', 'This platform role cannot submit a self-request.'
            );
        END IF;

    ELSE
        IF (V_NOMINATOR_ROLE_CODE <> 'POD_LEAD') THEN
            RETURN OBJECT_CONSTRUCT(
                'SUCCESS', FALSE,
                'MESSAGE', 'Only a Pod Lead may nominate another employee.'
            );
        END IF;

        SELECT COUNT(*)
        INTO :V_ELIGIBLE_MEMBER_COUNT
        FROM APP_SCHEMA.VW_ELIGIBLE_POD_MEMBERS
        WHERE POD_LEAD_EMPLOYEE_ID = :P_NOMINATOR_EMPLOYEE_ID
          AND MEMBER_EMPLOYEE_ID = :P_CANDIDATE_EMPLOYEE_ID;

        IF (V_ELIGIBLE_MEMBER_COUNT = 0) THEN
            RETURN OBJECT_CONSTRUCT(
                'SUCCESS', FALSE,
                'MESSAGE', 'A Pod Lead may nominate only an active member of their own active Pod.'
            );
        END IF;

        V_NOMINATION_TYPE := 'POD_LEAD_NOMINATION';
        V_INITIAL_STATUS := 'PENDING_CANDIDATE_RESPONSE';
        V_ASSIGNED_REVIEWER_ID := P_CANDIDATE_EMPLOYEE_ID;
    END IF;

    SELECT COUNT(*)
    INTO :V_DUPLICATE_COUNT
    FROM CORE.NOMINATIONS
    WHERE CANDIDATE_EMPLOYEE_ID = :P_CANDIDATE_EMPLOYEE_ID
      AND CERTIFICATION_ID = :P_CERTIFICATION_ID
      AND NOMINATION_STATUS IN (
          'PENDING_APPROVAL',
          'PENDING_CANDIDATE_RESPONSE'
      );

    IF (V_DUPLICATE_COUNT > 0) THEN
        RETURN OBJECT_CONSTRUCT(
            'SUCCESS', FALSE,
            'MESSAGE', 'A pending request already exists for this candidate and certification.'
        );
    END IF;

    V_NOMINATION_ID := UUID_STRING();
    V_STATUS_HISTORY_ID := UUID_STRING();
    V_REQUEST_NOTES := NULLIF(TRIM(P_REQUEST_NOTES), '');

    INSERT INTO CORE.NOMINATIONS (
        NOMINATION_ID,
        NOMINATION_TYPE,
        NOMINATOR_EMPLOYEE_ID,
        CANDIDATE_EMPLOYEE_ID,
        CERTIFICATION_ID,
        POD_ID,
        PREPARATION_START_DATE,
        TARGET_COMPLETION_DATE,
        NOMINATION_STATUS,
        ASSIGNED_REVIEWER_EMPLOYEE_ID,
        REQUEST_NOTES,
        CREATED_BY_SNOWFLAKE_USERNAME
    )
    VALUES (
        :V_NOMINATION_ID,
        :V_NOMINATION_TYPE,
        :P_NOMINATOR_EMPLOYEE_ID,
        :P_CANDIDATE_EMPLOYEE_ID,
        :P_CERTIFICATION_ID,
        :V_CANDIDATE_POD_ID,
        :P_PREPARATION_START_DATE,
        :P_TARGET_COMPLETION_DATE,
        :V_INITIAL_STATUS,
        :V_ASSIGNED_REVIEWER_ID,
        :V_REQUEST_NOTES,
        UPPER(:P_CREATED_BY_SNOWFLAKE_USERNAME)
    );

    INSERT INTO CORE.NOMINATION_STATUS_HISTORY (
        STATUS_HISTORY_ID,
        NOMINATION_ID,
        FROM_STATUS,
        TO_STATUS,
        CHANGED_BY_EMPLOYEE_ID,
        CHANGE_NOTES
    )
    VALUES (
        :V_STATUS_HISTORY_ID,
        :V_NOMINATION_ID,
        NULL,
        :V_INITIAL_STATUS,
        :P_NOMINATOR_EMPLOYEE_ID,
        'Nomination submitted.'
    );

    RETURN OBJECT_CONSTRUCT(
        'SUCCESS', TRUE,
        'MESSAGE', 'Nomination submitted successfully.',
        'NOMINATION_ID', V_NOMINATION_ID,
        'STATUS', V_INITIAL_STATUS,
        'ASSIGNED_REVIEWER_EMPLOYEE_ID', V_ASSIGNED_REVIEWER_ID
    );
END;
$$;


/*-----------------------------------------------------------------------------
  SECTION 6: APPROVE OR REJECT PROCEDURE

  Allows the assigned reviewer to approve or reject a PENDING_APPROVAL record.
  Candidate responses for PENDING_CANDIDATE_RESPONSE remain on the roadmap.
-----------------------------------------------------------------------------*/

CREATE OR REPLACE PROCEDURE APP_SCHEMA.SP_DECIDE_NOMINATION (
    P_NOMINATION_ID             VARCHAR,
    P_REVIEWER_EMPLOYEE_ID      VARCHAR,
    P_DECISION                  VARCHAR,
    P_DECISION_NOTES            VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
    V_MATCH_COUNT       NUMBER;
    V_CURRENT_STATUS    VARCHAR;
    V_ASSIGNED_REVIEWER VARCHAR;
    V_NEW_STATUS        VARCHAR;
    V_DECISION_NOTES    VARCHAR;
    V_STATUS_HISTORY_ID VARCHAR;
BEGIN
    V_NEW_STATUS := UPPER(TRIM(P_DECISION));
    V_DECISION_NOTES := NULLIF(TRIM(P_DECISION_NOTES), '');
    V_STATUS_HISTORY_ID := UUID_STRING();

    IF (V_NEW_STATUS NOT IN ('APPROVED', 'REJECTED')) THEN
        RETURN OBJECT_CONSTRUCT(
            'SUCCESS', FALSE,
            'MESSAGE', 'The decision must be APPROVED or REJECTED.'
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(NOMINATION_STATUS),
        MAX(ASSIGNED_REVIEWER_EMPLOYEE_ID)
    INTO
        :V_MATCH_COUNT,
        :V_CURRENT_STATUS,
        :V_ASSIGNED_REVIEWER
    FROM CORE.NOMINATIONS
    WHERE NOMINATION_ID = :P_NOMINATION_ID;

    IF (V_MATCH_COUNT = 0) THEN
        RETURN OBJECT_CONSTRUCT(
            'SUCCESS', FALSE,
            'MESSAGE', 'The nomination does not exist.'
        );
    END IF;

    IF (V_CURRENT_STATUS <> 'PENDING_APPROVAL') THEN
        RETURN OBJECT_CONSTRUCT(
            'SUCCESS', FALSE,
            'MESSAGE', 'Only a nomination with PENDING_APPROVAL status can be approved or rejected.'
        );
    END IF;

    IF (V_ASSIGNED_REVIEWER <> P_REVIEWER_EMPLOYEE_ID) THEN
        RETURN OBJECT_CONSTRUCT(
            'SUCCESS', FALSE,
            'MESSAGE', 'This nomination is assigned to a different reviewer.'
        );
    END IF;

    UPDATE CORE.NOMINATIONS
    SET
        NOMINATION_STATUS = :V_NEW_STATUS,
        DECISION_NOTES = :V_DECISION_NOTES,
        UPDATED_AT = CURRENT_TIMESTAMP(),
        DECIDED_AT = CURRENT_TIMESTAMP()
    WHERE NOMINATION_ID = :P_NOMINATION_ID;

    INSERT INTO CORE.NOMINATION_STATUS_HISTORY (
        STATUS_HISTORY_ID,
        NOMINATION_ID,
        FROM_STATUS,
        TO_STATUS,
        CHANGED_BY_EMPLOYEE_ID,
        CHANGE_NOTES
    )
    VALUES (
        :V_STATUS_HISTORY_ID,
        :P_NOMINATION_ID,
        :V_CURRENT_STATUS,
        :V_NEW_STATUS,
        :P_REVIEWER_EMPLOYEE_ID,
        :V_DECISION_NOTES
    );

    RETURN OBJECT_CONSTRUCT(
        'SUCCESS', TRUE,
        'MESSAGE', 'Nomination decision recorded successfully.',
        'NOMINATION_ID', P_NOMINATION_ID,
        'STATUS', V_NEW_STATUS
    );
END;
$$;


/*-----------------------------------------------------------------------------
  SECTION 7: APPLICATION ROLE GRANTS

  Streamlit reads only the application views and writes through owner-rights
  procedures. Direct access to the CORE transaction tables is not granted.
-----------------------------------------------------------------------------*/

GRANT SELECT ON VIEW APP_SCHEMA.VW_ELIGIBLE_POD_MEMBERS
    TO APPLICATION ROLE APP_USER;

GRANT SELECT ON VIEW APP_SCHEMA.VW_NOMINATION_DETAILS
    TO APPLICATION ROLE APP_USER;

GRANT USAGE ON PROCEDURE APP_SCHEMA.SP_SUBMIT_NOMINATION(
    VARCHAR,
    VARCHAR,
    VARCHAR,
    DATE,
    DATE,
    VARCHAR,
    VARCHAR
)
    TO APPLICATION ROLE APP_USER;

GRANT USAGE ON PROCEDURE APP_SCHEMA.SP_DECIDE_NOMINATION(
    VARCHAR,
    VARCHAR,
    VARCHAR,
    VARCHAR
)
    TO APPLICATION ROLE APP_USER;
