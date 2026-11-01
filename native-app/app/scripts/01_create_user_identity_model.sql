/*
===============================================================================
Script: 01_create_user_identity_model.sql
Project: Snowflake Certification Enablement Platform

Purpose:
Creates the physical tables and view required to identify the signed-in
employee, their platform role, their Pod and their Pod Lead.

Executed by:
native-app/app/setup.sql

Execution order:
This is the first secondary Native App setup script.

Objects created:
1. CORE.EMPLOYEES
2. CORE.APP_ROLES
3. CORE.EMPLOYEE_ROLE_ASSIGNMENTS
4. CORE.PODS
5. CORE.POD_MEMBERSHIPS
6. APP_SCHEMA.VW_USER_CONTEXT

Important:
This script creates only the structure. Demo employee and Pod records will be
loaded separately by 02_seed_user_identity_demo_data.sql.

Rerun behaviour:
CREATE TABLE IF NOT EXISTS preserves existing business data.
CREATE OR REPLACE VIEW refreshes the derived user-context view.
===============================================================================
*/


-- Create the schema that stores validated business data for the application.
CREATE SCHEMA IF NOT EXISTS CORE;


-- Allow authorised application users to access objects inside CORE.
GRANT USAGE ON SCHEMA CORE
    TO APPLICATION ROLE APP_USER;


/*
-------------------------------------------------------------------------------
Table: CORE.EMPLOYEES

Purpose:
Stores each employee once. SNOWFLAKE_USERNAME connects the person viewing the
Streamlit app to their employee profile.

Examples:
AMRITHAK identifies Amritha.
An inactive employee remains in this table with ACTIVE_FLAG = FALSE.
An unregistered user does not have a row in this table.
-------------------------------------------------------------------------------
*/
CREATE TABLE IF NOT EXISTS CORE.EMPLOYEES
(
    EMPLOYEE_ID         VARCHAR(20)  NOT NULL,
    SNOWFLAKE_USERNAME  VARCHAR(255) NOT NULL,
    EMPLOYEE_NAME       VARCHAR(150) NOT NULL,
    EMAIL_ADDRESS       VARCHAR(200),
    DESIGNATION         VARCHAR(100) NOT NULL,
    ACTIVE_FLAG         BOOLEAN      NOT NULL DEFAULT TRUE,
    CREATED_AT          TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT          TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_EMPLOYEES
        PRIMARY KEY (EMPLOYEE_ID),

    CONSTRAINT UQ_EMPLOYEES_SNOWFLAKE_USERNAME
        UNIQUE (SNOWFLAKE_USERNAME)
);


/*
-------------------------------------------------------------------------------
Table: CORE.APP_ROLES

Purpose:
Stores the business roles used by this platform. These are application roles,
not Snowflake account roles.

Initial role codes:
STUDIO_LEAD
POD_LEAD
POD_MEMBER
-------------------------------------------------------------------------------
*/
CREATE TABLE IF NOT EXISTS CORE.APP_ROLES
(
    ROLE_CODE        VARCHAR(30)  NOT NULL,
    ROLE_NAME        VARCHAR(100) NOT NULL,
    ROLE_DESCRIPTION VARCHAR(500),
    ACTIVE_FLAG      BOOLEAN      NOT NULL DEFAULT TRUE,
    CREATED_AT       TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_APP_ROLES
        PRIMARY KEY (ROLE_CODE)
);


/*
-------------------------------------------------------------------------------
Table: CORE.EMPLOYEE_ROLE_ASSIGNMENTS

Purpose:
Connects an employee to a platform role.

The role is stored separately from the employee because a person's business
responsibility can change without duplicating the employee's personal data.
-------------------------------------------------------------------------------
*/
CREATE TABLE IF NOT EXISTS CORE.EMPLOYEE_ROLE_ASSIGNMENTS
(
    EMPLOYEE_ID  VARCHAR(20) NOT NULL,
    ROLE_CODE    VARCHAR(30) NOT NULL,
    ACTIVE_FLAG  BOOLEAN     NOT NULL DEFAULT TRUE,
    ASSIGNED_AT  TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_EMPLOYEE_ROLE_ASSIGNMENTS
        PRIMARY KEY (EMPLOYEE_ID, ROLE_CODE),

    CONSTRAINT FK_ROLE_ASSIGNMENT_EMPLOYEE
        FOREIGN KEY (EMPLOYEE_ID)
        REFERENCES CORE.EMPLOYEES (EMPLOYEE_ID),

    CONSTRAINT FK_ROLE_ASSIGNMENT_ROLE
        FOREIGN KEY (ROLE_CODE)
        REFERENCES CORE.APP_ROLES (ROLE_CODE)
);


/*
-------------------------------------------------------------------------------
Table: CORE.PODS

Purpose:
Stores every Pod and the employee responsible for leading it.

The POD_LEAD_EMPLOYEE_ID points to CORE.EMPLOYEES so the Pod Lead's name and
other employee information are not repeated in this table.
-------------------------------------------------------------------------------
*/
CREATE TABLE IF NOT EXISTS CORE.PODS
(
    POD_ID                VARCHAR(20)  NOT NULL,
    POD_NAME              VARCHAR(150) NOT NULL,
    POD_LEAD_EMPLOYEE_ID  VARCHAR(20)  NOT NULL,
    ACTIVE_FLAG           BOOLEAN      NOT NULL DEFAULT TRUE,
    CREATED_AT            TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT            TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_PODS
        PRIMARY KEY (POD_ID),

    CONSTRAINT FK_POD_LEAD_EMPLOYEE
        FOREIGN KEY (POD_LEAD_EMPLOYEE_ID)
        REFERENCES CORE.EMPLOYEES (EMPLOYEE_ID)
);


/*
-------------------------------------------------------------------------------
Table: CORE.POD_MEMBERSHIPS

Purpose:
Connects employees to Pods.

This table supports the rule that a Pod Lead may nominate only an active member
of their own Pod. An employee without a Pod has no active row in this table.
-------------------------------------------------------------------------------
*/
CREATE TABLE IF NOT EXISTS CORE.POD_MEMBERSHIPS
(
    POD_ID        VARCHAR(20) NOT NULL,
    EMPLOYEE_ID   VARCHAR(20) NOT NULL,
    JOINED_DATE   DATE        NOT NULL,
    ACTIVE_FLAG   BOOLEAN     NOT NULL DEFAULT TRUE,
    CREATED_AT    TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_POD_MEMBERSHIPS
        PRIMARY KEY (POD_ID, EMPLOYEE_ID),

    CONSTRAINT FK_POD_MEMBERSHIP_POD
        FOREIGN KEY (POD_ID)
        REFERENCES CORE.PODS (POD_ID),

    CONSTRAINT FK_POD_MEMBERSHIP_EMPLOYEE
        FOREIGN KEY (EMPLOYEE_ID)
        REFERENCES CORE.EMPLOYEES (EMPLOYEE_ID)
);


/*
-------------------------------------------------------------------------------
View: APP_SCHEMA.VW_USER_CONTEXT

Purpose:
Combines employee, role and Pod information into one result for the Streamlit
home page.

The Streamlit app will filter this view using st.user.user_name.
-------------------------------------------------------------------------------
*/
CREATE OR REPLACE VIEW APP_SCHEMA.VW_USER_CONTEXT AS
SELECT
    E.EMPLOYEE_ID,
    E.SNOWFLAKE_USERNAME,
    E.EMPLOYEE_NAME,
    E.EMAIL_ADDRESS,
    E.DESIGNATION,
    E.ACTIVE_FLAG AS EMPLOYEE_ACTIVE_FLAG,
    ERA.ROLE_CODE,
    AR.ROLE_NAME,
    COALESCE(MEMBER_POD.POD_ID, LEAD_POD.POD_ID) AS POD_ID,
    COALESCE(MEMBER_POD.POD_NAME, LEAD_POD.POD_NAME) AS POD_NAME,
    COALESCE(
        MEMBER_POD.POD_LEAD_EMPLOYEE_ID,
        LEAD_POD.POD_LEAD_EMPLOYEE_ID
    ) AS POD_LEAD_EMPLOYEE_ID,
    COALESCE(
        MEMBER_POD_LEAD.EMPLOYEE_NAME,
        LEAD_EMPLOYEE.EMPLOYEE_NAME
    ) AS POD_LEAD_NAME
FROM CORE.EMPLOYEES E

LEFT JOIN CORE.EMPLOYEE_ROLE_ASSIGNMENTS ERA
    ON E.EMPLOYEE_ID = ERA.EMPLOYEE_ID
   AND ERA.ACTIVE_FLAG = TRUE

LEFT JOIN CORE.APP_ROLES AR
    ON ERA.ROLE_CODE = AR.ROLE_CODE
   AND AR.ACTIVE_FLAG = TRUE

LEFT JOIN CORE.POD_MEMBERSHIPS PM
    ON E.EMPLOYEE_ID = PM.EMPLOYEE_ID
   AND PM.ACTIVE_FLAG = TRUE

LEFT JOIN CORE.PODS MEMBER_POD
    ON PM.POD_ID = MEMBER_POD.POD_ID
   AND MEMBER_POD.ACTIVE_FLAG = TRUE

LEFT JOIN CORE.EMPLOYEES MEMBER_POD_LEAD
    ON MEMBER_POD.POD_LEAD_EMPLOYEE_ID =
       MEMBER_POD_LEAD.EMPLOYEE_ID

LEFT JOIN CORE.PODS LEAD_POD
    ON E.EMPLOYEE_ID = LEAD_POD.POD_LEAD_EMPLOYEE_ID
   AND LEAD_POD.ACTIVE_FLAG = TRUE

LEFT JOIN CORE.EMPLOYEES LEAD_EMPLOYEE
    ON LEAD_POD.POD_LEAD_EMPLOYEE_ID =
       LEAD_EMPLOYEE.EMPLOYEE_ID;


/*
-------------------------------------------------------------------------------
Access grants

Purpose:
Allows APP_USER to read the identity-model tables and the consolidated view.
-------------------------------------------------------------------------------
*/
GRANT SELECT ON TABLE CORE.EMPLOYEES
    TO APPLICATION ROLE APP_USER;

GRANT SELECT ON TABLE CORE.APP_ROLES
    TO APPLICATION ROLE APP_USER;

GRANT SELECT ON TABLE CORE.EMPLOYEE_ROLE_ASSIGNMENTS
    TO APPLICATION ROLE APP_USER;

GRANT SELECT ON TABLE CORE.PODS
    TO APPLICATION ROLE APP_USER;

GRANT SELECT ON TABLE CORE.POD_MEMBERSHIPS
    TO APPLICATION ROLE APP_USER;

GRANT SELECT ON VIEW APP_SCHEMA.VW_USER_CONTEXT
    TO APPLICATION ROLE APP_USER;