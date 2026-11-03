/*=============================================================================
  FILE: 04_validate_certification_catalog.sql

  PURPOSE:
  Validate the Certification Enablement Native App certification catalogue
  after the application package has been upgraded.

  EXECUTION ORDER:
  1. Upload setup.sql and script 03 to APP_STAGE.
  2. Upgrade CERT_ENABLEMENT_NATIVE_APP.
  3. Run this validation script in Snowsight.

  EXPECTED RESULT:
  Every returned TEST_STATUS value must be PASS.
=============================================================================*/


/*-----------------------------------------------------------------------------
  TEST CONTEXT
-----------------------------------------------------------------------------*/

USE ROLE CERT_ENABLEMENT_APP_DEVELOPER;
USE WAREHOUSE WH_CERT_ENABLEMENT_DEV_XS;


/*-----------------------------------------------------------------------------
  CERTIFICATION CATALOGUE VALIDATION

  Each SELECT returns one independent test result. UNION ALL combines the
  tests into one easy-to-review result grid.
-----------------------------------------------------------------------------*/

SELECT
    'T01 - Four active certifications are available' AS TEST_NAME,
    '4' AS EXPECTED_RESULT,
    TO_VARCHAR(COUNT(*)) AS ACTUAL_RESULT,
    IFF(COUNT(*) = 4, 'PASS', 'FAIL') AS TEST_STATUS
FROM CERT_ENABLEMENT_NATIVE_APP.APP_SCHEMA.VW_ACTIVE_CERTIFICATIONS

UNION ALL

SELECT
    'T02 - SnowPro Core exists' AS TEST_NAME,
    '1' AS EXPECTED_RESULT,
    TO_VARCHAR(COUNT(*)) AS ACTUAL_RESULT,
    IFF(COUNT(*) = 1, 'PASS', 'FAIL') AS TEST_STATUS
FROM CERT_ENABLEMENT_NATIVE_APP.APP_SCHEMA.VW_ACTIVE_CERTIFICATIONS
WHERE CERTIFICATION_CODE = 'SNOWPRO_CORE'

UNION ALL

SELECT
    'T03 - Certification IDs are unique' AS TEST_NAME,
    '0 duplicate IDs' AS EXPECTED_RESULT,
    TO_VARCHAR(COUNT(*) - COUNT(DISTINCT CERTIFICATION_ID)) || ' duplicate IDs'
        AS ACTUAL_RESULT,
    IFF(
        COUNT(*) = COUNT(DISTINCT CERTIFICATION_ID),
        'PASS',
        'FAIL'
    ) AS TEST_STATUS
FROM CERT_ENABLEMENT_NATIVE_APP.APP_SCHEMA.VW_ACTIVE_CERTIFICATIONS

UNION ALL

SELECT
    'T04 - Certification codes are unique' AS TEST_NAME,
    '0 duplicate codes' AS EXPECTED_RESULT,
    TO_VARCHAR(COUNT(*) - COUNT(DISTINCT CERTIFICATION_CODE)) || ' duplicate codes'
        AS ACTUAL_RESULT,
    IFF(
        COUNT(*) = COUNT(DISTINCT CERTIFICATION_CODE),
        'PASS',
        'FAIL'
    ) AS TEST_STATUS
FROM CERT_ENABLEMENT_NATIVE_APP.APP_SCHEMA.VW_ACTIVE_CERTIFICATIONS

UNION ALL

SELECT
    'T05 - Required values are populated' AS TEST_NAME,
    '0 incomplete rows' AS EXPECTED_RESULT,
    TO_VARCHAR(COUNT_IF(
        CERTIFICATION_ID IS NULL
        OR CERTIFICATION_CODE IS NULL
        OR CERTIFICATION_NAME IS NULL
        OR PROVIDER_NAME IS NULL
        OR CERTIFICATION_LEVEL IS NULL
        OR DISPLAY_ORDER IS NULL
    )) || ' incomplete rows' AS ACTUAL_RESULT,
    IFF(
        COUNT_IF(
            CERTIFICATION_ID IS NULL
            OR CERTIFICATION_CODE IS NULL
            OR CERTIFICATION_NAME IS NULL
            OR PROVIDER_NAME IS NULL
            OR CERTIFICATION_LEVEL IS NULL
            OR DISPLAY_ORDER IS NULL
        ) = 0,
        'PASS',
        'FAIL'
    ) AS TEST_STATUS
FROM CERT_ENABLEMENT_NATIVE_APP.APP_SCHEMA.VW_ACTIVE_CERTIFICATIONS

UNION ALL

SELECT
    'T06 - Display order values are unique' AS TEST_NAME,
    '0 duplicate display orders' AS EXPECTED_RESULT,
    TO_VARCHAR(COUNT(*) - COUNT(DISTINCT DISPLAY_ORDER)) ||
        ' duplicate display orders' AS ACTUAL_RESULT,
    IFF(
        COUNT(*) = COUNT(DISTINCT DISPLAY_ORDER),
        'PASS',
        'FAIL'
    ) AS TEST_STATUS
FROM CERT_ENABLEMENT_NATIVE_APP.APP_SCHEMA.VW_ACTIVE_CERTIFICATIONS

UNION ALL

SELECT
    'T07 - Advanced certifications reference SnowPro Core' AS TEST_NAME,
    '0 invalid prerequisites' AS EXPECTED_RESULT,
    TO_VARCHAR(COUNT_IF(
        CERTIFICATION_LEVEL = 'ADVANCED'
        AND COALESCE(PREREQUISITE_CERTIFICATION_ID, '') <> 'CERT002'
    )) || ' invalid prerequisites' AS ACTUAL_RESULT,
    IFF(
        COUNT_IF(
            CERTIFICATION_LEVEL = 'ADVANCED'
            AND COALESCE(PREREQUISITE_CERTIFICATION_ID, '') <> 'CERT002'
        ) = 0,
        'PASS',
        'FAIL'
    ) AS TEST_STATUS
FROM CERT_ENABLEMENT_NATIVE_APP.APP_SCHEMA.VW_ACTIVE_CERTIFICATIONS

UNION ALL

SELECT
    'T08 - Certification levels are supported' AS TEST_NAME,
    '0 invalid levels' AS EXPECTED_RESULT,
    TO_VARCHAR(COUNT_IF(
        CERTIFICATION_LEVEL NOT IN ('ASSOCIATE', 'CORE', 'ADVANCED')
    )) || ' invalid levels' AS ACTUAL_RESULT,
    IFF(
        COUNT_IF(
            CERTIFICATION_LEVEL NOT IN ('ASSOCIATE', 'CORE', 'ADVANCED')
        ) = 0,
        'PASS',
        'FAIL'
    ) AS TEST_STATUS
FROM CERT_ENABLEMENT_NATIVE_APP.APP_SCHEMA.VW_ACTIVE_CERTIFICATIONS

ORDER BY TEST_NAME;


/*-----------------------------------------------------------------------------
  OPTIONAL DETAIL OUTPUT

  Run this statement separately when the individual catalogue rows need to be
  inspected during development or demonstrated during a review.
-----------------------------------------------------------------------------*/

SELECT
    CERTIFICATION_ID,
    CERTIFICATION_CODE,
    CERTIFICATION_NAME,
    PROVIDER_NAME,
    CERTIFICATION_LEVEL,
    PREREQUISITE_CERTIFICATION_ID,
    DISPLAY_ORDER
FROM CERT_ENABLEMENT_NATIVE_APP.APP_SCHEMA.VW_ACTIVE_CERTIFICATIONS
ORDER BY DISPLAY_ORDER;
