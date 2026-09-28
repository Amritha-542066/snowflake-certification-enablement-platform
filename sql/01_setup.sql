/*
    Project: Snowflake Certification Enablement Platform
    Purpose: Create the warehouse, database, and project schemas.
*/

USE ROLE ACCOUNTADMIN;

-- Small warehouse used for deployment and learning activities.
CREATE WAREHOUSE IF NOT EXISTS WH_CERT_ENABLEMENT_DEV_XS
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for the Snowflake Certification Enablement Platform';

-- Main project database.
CREATE DATABASE IF NOT EXISTS DB_CERT_ENABLEMENT_DEV
    COMMENT = 'Central platform for SnowPro Core study plans and learner progress';

-- RAW stores incoming study content and learner activity.
CREATE SCHEMA IF NOT EXISTS DB_CERT_ENABLEMENT_DEV.RAW
    COMMENT = 'Incoming study-plan and learner-activity data';

-- CORE stores validated business data.
CREATE SCHEMA IF NOT EXISTS DB_CERT_ENABLEMENT_DEV.CORE
    COMMENT = 'Validated certification, learner, and progress data';

-- ANALYTICS stores reporting views.
CREATE SCHEMA IF NOT EXISTS DB_CERT_ENABLEMENT_DEV.ANALYTICS
    COMMENT = 'Learner progress and certification-readiness reporting';

-- CONTROL stores pipeline configuration, logs, and rejected records.
CREATE SCHEMA IF NOT EXISTS DB_CERT_ENABLEMENT_DEV.CONTROL
    COMMENT = 'Pipeline monitoring, configuration, and rejected records';

USE WAREHOUSE WH_CERT_ENABLEMENT_DEV_XS;
USE DATABASE DB_CERT_ENABLEMENT_DEV;
USE SCHEMA CORE;

-- Validation command.
SHOW SCHEMAS IN DATABASE DB_CERT_ENABLEMENT_DEV;