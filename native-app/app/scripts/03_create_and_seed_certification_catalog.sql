/*=============================================================================
  FILE: 03_create_and_seed_certification_catalog.sql

  PURPOSE:
  Create the physical certification catalogue used by the Snowflake
  Certification Enablement Native App and seed the initial demo catalogue.

  EXECUTION ORDER:
  1. 01_create_user_identity_model.sql
  2. 02_seed_user_identity_demo_data.sql
  3. 03_create_and_seed_certification_catalog.sql  <-- this file

  DESIGN NOTES:
  - CORE.CERTIFICATIONS stores one row for each certification offered by the
    enablement platform.
  - APP_SCHEMA.VW_ACTIVE_CERTIFICATIONS exposes only active certifications to
    the Streamlit application.
  - MERGE makes the seed operation repeatable during Native App upgrades.
  - The Native App role receives read access through the application view.
  - Nomination and enrollment records are deliberately not created here.
=============================================================================*/


/*-----------------------------------------------------------------------------
  SECTION 1: CERTIFICATION MASTER TABLE

  CERTIFICATION_ID is the stable internal identifier used by relationships.
  CERTIFICATION_CODE is a business-friendly code used in application logic.
  PREREQUISITE_CERTIFICATION_ID supports certifications that require another
  certification to be completed first.
-----------------------------------------------------------------------------*/

CREATE TABLE IF NOT EXISTS CORE.CERTIFICATIONS (
    CERTIFICATION_ID              VARCHAR(20)  NOT NULL,
    CERTIFICATION_CODE            VARCHAR(100) NOT NULL,
    CERTIFICATION_NAME            VARCHAR(250) NOT NULL,
    PROVIDER_NAME                 VARCHAR(100) NOT NULL,
    CERTIFICATION_LEVEL           VARCHAR(50)  NOT NULL,
    CERTIFICATION_DESCRIPTION     VARCHAR(2000),
    PREREQUISITE_CERTIFICATION_ID VARCHAR(20),
    ACTIVE_FLAG                   BOOLEAN      NOT NULL DEFAULT TRUE,
    DISPLAY_ORDER                 NUMBER(5, 0) NOT NULL,
    CREATED_AT                    TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT                    TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_CERTIFICATIONS
        PRIMARY KEY (CERTIFICATION_ID),

    CONSTRAINT UQ_CERTIFICATIONS_CODE
        UNIQUE (CERTIFICATION_CODE),

    CONSTRAINT FK_CERTIFICATIONS_PREREQUISITE
        FOREIGN KEY (PREREQUISITE_CERTIFICATION_ID)
        REFERENCES CORE.CERTIFICATIONS (CERTIFICATION_ID),

    CONSTRAINT CK_CERTIFICATIONS_LEVEL
        CHECK (
            CERTIFICATION_LEVEL IN (
                'ASSOCIATE',
                'CORE',
                'ADVANCED'
            )
        ),

    CONSTRAINT CK_CERTIFICATIONS_DISPLAY_ORDER
        CHECK (DISPLAY_ORDER > 0)
);


/*-----------------------------------------------------------------------------
  SECTION 2: INITIAL CERTIFICATION CATALOGUE

  These rows provide a useful demonstration catalogue. Additional
  certifications can be introduced later by inserting new rows.
-----------------------------------------------------------------------------*/

MERGE INTO CORE.CERTIFICATIONS AS TARGET
USING (
    SELECT
        COLUMN1 AS CERTIFICATION_ID,
        COLUMN2 AS CERTIFICATION_CODE,
        COLUMN3 AS CERTIFICATION_NAME,
        COLUMN4 AS PROVIDER_NAME,
        COLUMN5 AS CERTIFICATION_LEVEL,
        COLUMN6 AS CERTIFICATION_DESCRIPTION,
        COLUMN7 AS PREREQUISITE_CERTIFICATION_ID,
        COLUMN8 AS ACTIVE_FLAG,
        COLUMN9 AS DISPLAY_ORDER
    FROM VALUES
        (
            'CERT001',
            'SNOWPRO_ASSOCIATE_PLATFORM',
            'SnowPro Associate: Platform Certification',
            'Snowflake',
            'ASSOCIATE',
            'Validates foundational Snowflake platform, data management, compute, access-control and Cortex knowledge.',
            NULL,
            TRUE,
            1
        ),
        (
            'CERT002',
            'SNOWPRO_CORE',
            'SnowPro Core Certification',
            'Snowflake',
            'CORE',
            'Validates core knowledge required to implement, operate and work effectively with the Snowflake AI Data Cloud.',
            NULL,
            TRUE,
            2
        ),
        (
            'CERT003',
            'SNOWPRO_ADVANCED_DATA_ENGINEER',
            'SnowPro Advanced: Data Engineer Certification',
            'Snowflake',
            'ADVANCED',
            'Validates advanced Snowflake data-engineering, pipeline, transformation and performance-optimization skills.',
            'CERT002',
            TRUE,
            3
        ),
        (
            'CERT004',
            'SNOWPRO_ADVANCED_ADMINISTRATOR',
            'SnowPro Advanced: Administrator Certification',
            'Snowflake',
            'ADVANCED',
            'Validates advanced Snowflake administration, security, governance, workload-management and recovery skills.',
            'CERT002',
            TRUE,
            4
        )
) AS SOURCE
ON TARGET.CERTIFICATION_ID = SOURCE.CERTIFICATION_ID

WHEN MATCHED THEN UPDATE SET
    TARGET.CERTIFICATION_CODE = SOURCE.CERTIFICATION_CODE,
    TARGET.CERTIFICATION_NAME = SOURCE.CERTIFICATION_NAME,
    TARGET.PROVIDER_NAME = SOURCE.PROVIDER_NAME,
    TARGET.CERTIFICATION_LEVEL = SOURCE.CERTIFICATION_LEVEL,
    TARGET.CERTIFICATION_DESCRIPTION = SOURCE.CERTIFICATION_DESCRIPTION,
    TARGET.PREREQUISITE_CERTIFICATION_ID = SOURCE.PREREQUISITE_CERTIFICATION_ID,
    TARGET.ACTIVE_FLAG = SOURCE.ACTIVE_FLAG,
    TARGET.DISPLAY_ORDER = SOURCE.DISPLAY_ORDER,
    TARGET.UPDATED_AT = CURRENT_TIMESTAMP()

WHEN NOT MATCHED THEN INSERT (
    CERTIFICATION_ID,
    CERTIFICATION_CODE,
    CERTIFICATION_NAME,
    PROVIDER_NAME,
    CERTIFICATION_LEVEL,
    CERTIFICATION_DESCRIPTION,
    PREREQUISITE_CERTIFICATION_ID,
    ACTIVE_FLAG,
    DISPLAY_ORDER
)
VALUES (
    SOURCE.CERTIFICATION_ID,
    SOURCE.CERTIFICATION_CODE,
    SOURCE.CERTIFICATION_NAME,
    SOURCE.PROVIDER_NAME,
    SOURCE.CERTIFICATION_LEVEL,
    SOURCE.CERTIFICATION_DESCRIPTION,
    SOURCE.PREREQUISITE_CERTIFICATION_ID,
    SOURCE.ACTIVE_FLAG,
    SOURCE.DISPLAY_ORDER
);


/*-----------------------------------------------------------------------------
  SECTION 3: APPLICATION-FACING VIEW

  Streamlit reads this view rather than querying the physical table directly.
  Inactive certifications remain stored for history but are not displayed.
-----------------------------------------------------------------------------*/

CREATE OR REPLACE VIEW APP_SCHEMA.VW_ACTIVE_CERTIFICATIONS AS
SELECT
    CERTIFICATION_ID,
    CERTIFICATION_CODE,
    CERTIFICATION_NAME,
    PROVIDER_NAME,
    CERTIFICATION_LEVEL,
    CERTIFICATION_DESCRIPTION,
    PREREQUISITE_CERTIFICATION_ID,
    DISPLAY_ORDER
FROM CORE.CERTIFICATIONS
WHERE ACTIVE_FLAG = TRUE;


/*-----------------------------------------------------------------------------
  SECTION 4: NATIVE APP ACCESS

  APP_USER can read the controlled application view. Direct table writes are
  not granted to the Streamlit user.
-----------------------------------------------------------------------------*/

GRANT SELECT ON VIEW APP_SCHEMA.VW_ACTIVE_CERTIFICATIONS
    TO APPLICATION ROLE APP_USER;


/*-----------------------------------------------------------------------------
  SECTION 5: INSTALLATION VERIFICATION OUTPUT

  This result can be inspected during direct worksheet testing. During Native
  App installation, the separate validation script provides the formal tests.
-----------------------------------------------------------------------------*/

SELECT
    CERTIFICATION_ID,
    CERTIFICATION_CODE,
    CERTIFICATION_NAME,
    CERTIFICATION_LEVEL,
    PREREQUISITE_CERTIFICATION_ID,
    DISPLAY_ORDER
FROM APP_SCHEMA.VW_ACTIVE_CERTIFICATIONS
ORDER BY DISPLAY_ORDER;
