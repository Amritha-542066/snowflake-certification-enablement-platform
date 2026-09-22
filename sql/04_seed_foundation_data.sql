/*
    Project: SnowPro Core Enablement Platform
    Purpose: Add the certification, experience levels,
             exam domains, and learning paths.
*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SNOWPRO_LEARNING_WH;
USE DATABASE SNOWPRO_ENABLEMENT;
USE SCHEMA CORE;

-- Add the current SnowPro Core certification.
MERGE INTO CERTIFICATIONS AS TARGET
USING (
    SELECT
        COLUMN1 AS CERTIFICATION_ID,
        COLUMN2 AS CERTIFICATION_CODE,
        COLUMN3 AS CERTIFICATION_NAME,
        COLUMN4 AS EXAM_VERSION,
        COLUMN5 AS DESCRIPTION
    FROM VALUES
        (
            'CERT_SNOWPRO_CORE',
            'COF-C03',
            'SnowPro Core Certification',
            'COF-C03',
            'Validates practical knowledge of the Snowflake AI Data Cloud'
        )
) AS SOURCE
ON TARGET.CERTIFICATION_ID = SOURCE.CERTIFICATION_ID
WHEN MATCHED THEN UPDATE SET
    TARGET.CERTIFICATION_CODE = SOURCE.CERTIFICATION_CODE,
    TARGET.CERTIFICATION_NAME = SOURCE.CERTIFICATION_NAME,
    TARGET.EXAM_VERSION = SOURCE.EXAM_VERSION,
    TARGET.DESCRIPTION = SOURCE.DESCRIPTION,
    TARGET.UPDATED_AT = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    CERTIFICATION_ID,
    CERTIFICATION_CODE,
    CERTIFICATION_NAME,
    EXAM_VERSION,
    DESCRIPTION
)
VALUES (
    SOURCE.CERTIFICATION_ID,
    SOURCE.CERTIFICATION_CODE,
    SOURCE.CERTIFICATION_NAME,
    SOURCE.EXAM_VERSION,
    SOURCE.DESCRIPTION
);

-- Add configurable experience-level timelines.
MERGE INTO EXPERIENCE_LEVELS AS TARGET
USING (
    SELECT
        COLUMN1 AS EXPERIENCE_LEVEL_CODE,
        COLUMN2 AS EXPERIENCE_LEVEL_NAME,
        COLUMN3 AS MIN_YEARS,
        COLUMN4 AS MAX_YEARS,
        COLUMN5 AS RECOMMENDED_WEEKS,
        COLUMN6 AS WEEKLY_STUDY_HOURS,
        COLUMN7 AS DISPLAY_ORDER
    FROM VALUES
        ('FRESHER', 'Fresher', 0.0, 0.0, 12, 8, 1),
        ('EXP_0_5', '0-5 Years Snowflake Experience', 0.1, 5.0, 10, 7, 2),
        ('EXP_5_9', '5-9 Years Snowflake Experience', 5.1, 9.0, 8, 6, 3),
        ('EXP_9_PLUS', '9+ Years Snowflake Experience', 9.1, NULL, 6, 5, 4)
) AS SOURCE
ON TARGET.EXPERIENCE_LEVEL_CODE = SOURCE.EXPERIENCE_LEVEL_CODE
WHEN MATCHED THEN UPDATE SET
    TARGET.EXPERIENCE_LEVEL_NAME = SOURCE.EXPERIENCE_LEVEL_NAME,
    TARGET.MIN_YEARS = SOURCE.MIN_YEARS,
    TARGET.MAX_YEARS = SOURCE.MAX_YEARS,
    TARGET.RECOMMENDED_WEEKS = SOURCE.RECOMMENDED_WEEKS,
    TARGET.WEEKLY_STUDY_HOURS = SOURCE.WEEKLY_STUDY_HOURS,
    TARGET.DISPLAY_ORDER = SOURCE.DISPLAY_ORDER,
    TARGET.UPDATED_AT = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    EXPERIENCE_LEVEL_CODE,
    EXPERIENCE_LEVEL_NAME,
    MIN_YEARS,
    MAX_YEARS,
    RECOMMENDED_WEEKS,
    WEEKLY_STUDY_HOURS,
    DISPLAY_ORDER
)
VALUES (
    SOURCE.EXPERIENCE_LEVEL_CODE,
    SOURCE.EXPERIENCE_LEVEL_NAME,
    SOURCE.MIN_YEARS,
    SOURCE.MAX_YEARS,
    SOURCE.RECOMMENDED_WEEKS,
    SOURCE.WEEKLY_STUDY_HOURS,
    SOURCE.DISPLAY_ORDER
);

-- Add COF-C03 exam domains and weights.
MERGE INTO EXAM_DOMAINS AS TARGET
USING (
    SELECT
        COLUMN1 AS DOMAIN_ID,
        COLUMN2 AS CERTIFICATION_ID,
        COLUMN3 AS DOMAIN_NAME,
        COLUMN4 AS EXAM_WEIGHT_PERCENT,
        COLUMN5 AS DOMAIN_ORDER,
        COLUMN6 AS DESCRIPTION
    FROM VALUES
        (
            'DOMAIN_01',
            'CERT_SNOWPRO_CORE',
            'Snowflake AI Data Cloud Features and Architecture',
            31.00,
            1,
            'Architecture, Snowflake objects, storage, interfaces and platform features'
        ),
        (
            'DOMAIN_02',
            'CERT_SNOWPRO_CORE',
            'Performance Optimization, Querying and Transformation',
            21.00,
            2,
            'Querying, transformation, warehouse performance and optimization'
        ),
        (
            'DOMAIN_03',
            'CERT_SNOWPRO_CORE',
            'Account Management and Data Governance',
            20.00,
            3,
            'Security, roles, privileges, account administration and governance'
        ),
        (
            'DOMAIN_04',
            'CERT_SNOWPRO_CORE',
            'Data Loading, Unloading and Connectivity',
            18.00,
            4,
            'Stages, file formats, loading, unloading and client connectivity'
        ),
        (
            'DOMAIN_05',
            'CERT_SNOWPRO_CORE',
            'Data Collaboration',
            10.00,
            5,
            'Secure data sharing, listings and collaboration capabilities'
        )
) AS SOURCE
ON TARGET.DOMAIN_ID = SOURCE.DOMAIN_ID
WHEN MATCHED THEN UPDATE SET
    TARGET.DOMAIN_NAME = SOURCE.DOMAIN_NAME,
    TARGET.EXAM_WEIGHT_PERCENT = SOURCE.EXAM_WEIGHT_PERCENT,
    TARGET.DOMAIN_ORDER = SOURCE.DOMAIN_ORDER,
    TARGET.DESCRIPTION = SOURCE.DESCRIPTION,
    TARGET.UPDATED_AT = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    DOMAIN_ID,
    CERTIFICATION_ID,
    DOMAIN_NAME,
    EXAM_WEIGHT_PERCENT,
    DOMAIN_ORDER,
    DESCRIPTION
)
VALUES (
    SOURCE.DOMAIN_ID,
    SOURCE.CERTIFICATION_ID,
    SOURCE.DOMAIN_NAME,
    SOURCE.EXAM_WEIGHT_PERCENT,
    SOURCE.DOMAIN_ORDER,
    SOURCE.DESCRIPTION
);

-- Add one configurable learning path for every experience level.
MERGE INTO LEARNING_PATHS AS TARGET
USING (
    SELECT
        COLUMN1 AS PATH_ID,
        COLUMN2 AS CERTIFICATION_ID,
        COLUMN3 AS EXPERIENCE_LEVEL_CODE,
        COLUMN4 AS PATH_NAME,
        COLUMN5 AS DURATION_WEEKS,
        COLUMN6 AS WEEKLY_STUDY_HOURS,
        COLUMN7 AS DESCRIPTION
    FROM VALUES
        (
            'PATH_FRESHER',
            'CERT_SNOWPRO_CORE',
            'FRESHER',
            'SnowPro Core Fresher Path',
            12,
            8,
            'Detailed learning path with additional fundamentals and hands-on practice'
        ),
        (
            'PATH_0_5',
            'CERT_SNOWPRO_CORE',
            'EXP_0_5',
            'SnowPro Core 0-5 Years Path',
            10,
            7,
            'Structured learning path for early-career professionals'
        ),
        (
            'PATH_5_9',
            'CERT_SNOWPRO_CORE',
            'EXP_5_9',
            'SnowPro Core 5-9 Years Path',
            8,
            6,
            'Accelerated learning path for experienced professionals'
        ),
        (
            'PATH_9_PLUS',
            'CERT_SNOWPRO_CORE',
            'EXP_9_PLUS',
            'SnowPro Core 9+ Years Path',
            6,
            5,
            'Focused learning path for senior professionals'
        )
) AS SOURCE
ON TARGET.PATH_ID = SOURCE.PATH_ID
WHEN MATCHED THEN UPDATE SET
    TARGET.PATH_NAME = SOURCE.PATH_NAME,
    TARGET.DURATION_WEEKS = SOURCE.DURATION_WEEKS,
    TARGET.WEEKLY_STUDY_HOURS = SOURCE.WEEKLY_STUDY_HOURS,
    TARGET.DESCRIPTION = SOURCE.DESCRIPTION,
    TARGET.UPDATED_AT = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    PATH_ID,
    CERTIFICATION_ID,
    EXPERIENCE_LEVEL_CODE,
    PATH_NAME,
    DURATION_WEEKS,
    WEEKLY_STUDY_HOURS,
    DESCRIPTION
)
VALUES (
    SOURCE.PATH_ID,
    SOURCE.CERTIFICATION_ID,
    SOURCE.EXPERIENCE_LEVEL_CODE,
    SOURCE.PATH_NAME,
    SOURCE.DURATION_WEEKS,
    SOURCE.WEEKLY_STUDY_HOURS,
    SOURCE.DESCRIPTION
);

-- Validation queries.
SELECT * FROM CERTIFICATIONS ORDER BY CERTIFICATION_ID;

SELECT *
FROM EXPERIENCE_LEVELS
ORDER BY DISPLAY_ORDER;

SELECT *
FROM EXAM_DOMAINS
ORDER BY DOMAIN_ORDER;

SELECT *
FROM LEARNING_PATHS
ORDER BY DURATION_WEEKS DESC;