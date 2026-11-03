-- Snowflake Certification Enablement Platform
-- Initial Native App installation script

-- Application role used to access the app
CREATE APPLICATION ROLE IF NOT EXISTS APP_USER;

-- Schema for the app's tables, views and Streamlit interface
CREATE SCHEMA IF NOT EXISTS APP_SCHEMA;

-- Allow the application role to use the schema
GRANT USAGE ON SCHEMA APP_SCHEMA
    TO APPLICATION ROLE APP_USER;

-- Create the employee, role and Pod identity model.
-- The path begins at the root of the staged Native App files.
EXECUTE IMMEDIATE FROM
    '/scripts/01_create_user_identity_model.sql';
-- Load the controlled user, role and Pod demo personas.
EXECUTE IMMEDIATE FROM
    '/scripts/02_seed_user_identity_demo_data.sql';
-- Create and seed the certification catalogue used by Streamlit.
EXECUTE IMMEDIATE FROM
    '/scripts/03_create_and_seed_certification_catalog.sql';
-- Create the Streamlit interface from the staged source files
CREATE OR REPLACE STREAMLIT APP_SCHEMA.CERT_ENABLEMENT_UI
    FROM '/streamlit'
    MAIN_FILE = '/main.py'
    TITLE = 'Snowflake Certification Enablement Platform';

-- Allow the application role to open the Streamlit interface
GRANT USAGE ON STREAMLIT APP_SCHEMA.CERT_ENABLEMENT_UI
    TO APPLICATION ROLE APP_USER;