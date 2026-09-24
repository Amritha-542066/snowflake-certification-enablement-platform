/*
    Project: Snowflake Certification Enablement Platform
    Purpose: Create the warehouse, database, and project schemas.
*/

USE ROLE ACCOUNTADMIN;

-- Small warehouse used for deployment and learning activities.
CREATE WAREHOUSE IF NOT EXISTS SNOWPRO_LEARNING_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for the Snowflake Certification Enablement Platform';

-- Main project database.
CREATE DATABASE IF NOT EXISTS SNOWPRO_ENABLEMENT
    COMMENT = 'Central platform for SnowPro Core study plans and learner progress';

-- RAW stores incoming study content and learner activity.
CREATE SCHEMA IF NOT EXISTS SNOWPRO_ENABLEMENT.RAW
    COMMENT = 'Incoming study-plan and learner-activity data';

-- CORE stores validated business data.
CREATE SCHEMA IF NOT EXISTS SNOWPRO_ENABLEMENT.CORE
    COMMENT = 'Validated certification, learner, and progress data';

-- ANALYTICS stores reporting views.
CREATE SCHEMA IF NOT EXISTS SNOWPRO_ENABLEMENT.ANALYTICS
    COMMENT = 'Learner progress and certification-readiness reporting';

-- CONTROL stores pipeline configuration, logs, and rejected records.
CREATE SCHEMA IF NOT EXISTS SNOWPRO_ENABLEMENT.CONTROL
    COMMENT = 'Pipeline monitoring, configuration, and rejected records';

USE WAREHOUSE SNOWPRO_LEARNING_WH;
USE DATABASE SNOWPRO_ENABLEMENT;
USE SCHEMA CORE;

-- Validation command.
SHOW SCHEMAS IN DATABASE SNOWPRO_ENABLEMENT;