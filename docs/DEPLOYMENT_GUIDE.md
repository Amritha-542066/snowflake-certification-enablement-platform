# Snowflake Certification Enablement Platform

## Deployment Guide

## 1. Purpose

This document explains how to deploy, configure and verify the Snowflake Certification Enablement Platform.

The platform provides:

- Snowflake certification study topics
- Learning paths based on Snowflake experience
- Learner registration
- Learner enrollment
- Learning schedule generation
- Learner-progress tracking
- CSV-based data ingestion
- Invalid-record handling
- Pipeline run logging
- Analytics views
- Role-based access control

All SQL scripts, CSV templates, tests and documentation are maintained in Git.

---

## 2. Prerequisites

Before deployment, confirm that the following are available:

- A Snowflake account
- Access to Snowsight
- A Snowflake role that can create databases, schemas, warehouses, roles, Tasks and stored procedures
- The project Git repository
- The CSV files available in the `data` folder
- The SQL files available in the `sql` folder
- The validation files available in the `tests` folder

The prototype was tested using a Snowflake trial account.

---

## 3. Repository Structure

```text
snowflake-certification-enablement-platform/
│
├── data/
│   ├── study_topics.csv
│   ├── learner_information.csv
│   └── learner_progress.csv
│
├── docs/
│   ├── DESIGN_DOCUMENT.md
│   ├── DEPLOYMENT_GUIDE.md
│   ├── DEMO_GUIDE.md
│   └── TEST_RESULTS.md
│
├── sql/
│   ├── 01_setup.sql
│   ├── 02_reference_tables.sql
│   ├── 03_learner_tracking_tables.sql
│   ├── 04_seed_foundation_data.sql
│   ├── 05_raw_ingestion_setup.sql
│   ├── 06_load_study_topics.sql
│   ├── 07_study_topics_pipeline.sql
│   ├── 08_learner_registration.sql
│   ├── 09_learning_schedule.sql
│   ├── 10_learning_activity_pipeline.sql
│   ├── 11_analytics_views.sql
│   ├── 12_rbac.sql
│   ├── 13_learner_information_pipeline.sql
│   └── 14_learner_progress_pipeline.sql
│
├── tests/
│   ├── data/
│   │   ├── invalid_learners.csv
│   │   ├── corrected_learners.csv
│   │   ├── invalid_progress.csv
│   │   └── corrected_progress.csv
│   │
│   ├── 02_platform_data_quality_tests.sql
│   └── 03_csv_pipeline_validation_tests.sql
│
├── .gitignore
└── README.md
```

---

## 4. Snowflake Objects

The deployment creates the following main objects.

### Database

```text
SNOWPRO_ENABLEMENT
```

### Schemas

| Schema | Purpose |
|---|---|
| `RAW` | Stores newly uploaded source records |
| `CORE` | Stores validated certification and learner data |
| `CONTROL` | Stores procedures, rejected records and run logs |
| `ANALYTICS` | Stores reporting views |

### Warehouse

```text
SNOWPRO_LEARNING_WH
```

The warehouse uses an X-Small size and auto-suspend to reduce unnecessary credit consumption.

---

## 5. Deployment Order

Execute the SQL files in the following order.

### Step 1: Create the Snowflake Environment

Execute:

```text
sql/01_setup.sql
```

This script creates:

- `SNOWPRO_ENABLEMENT` database
- Required schemas
- `SNOWPRO_LEARNING_WH` warehouse
- Initial Snowflake configuration

Verify the schemas:

```sql
SHOW SCHEMAS IN DATABASE SNOWPRO_ENABLEMENT;
```

Verify the warehouse:

```sql
SHOW WAREHOUSES LIKE 'SNOWPRO_LEARNING_WH';
```

---

### Step 2: Create Reference Tables

Execute:

```text
sql/02_reference_tables.sql
```

This script creates the reference tables used by the platform, including:

- Certifications
- Exam domains
- Experience levels
- Learning paths
- Study topics
- Learning-path topic plans

Verify the tables:

```sql
SHOW TABLES IN SCHEMA SNOWPRO_ENABLEMENT.CORE;
```

---

### Step 3: Create Learner-Tracking Tables

Execute:

```text
sql/03_learner_tracking_tables.sql
```

This script creates the tables used for:

- Learners
- Enrollments
- Topic progress
- Learning events
- Assessment results

Verify the learner tables:

```sql
DESC TABLE SNOWPRO_ENABLEMENT.CORE.LEARNERS;

DESC TABLE SNOWPRO_ENABLEMENT.CORE.ENROLLMENTS;

DESC TABLE SNOWPRO_ENABLEMENT.CORE.TOPIC_PROGRESS;
```

---

### Step 4: Load Foundation Data

Execute:

```text
sql/04_seed_foundation_data.sql
```

This script loads the initial configuration data, including:

- SnowPro Core certification
- Certification domains
- Experience categories
- Learning paths

The current experience categories are:

| Experience category | Learning path | Duration |
|---|---|---:|
| Fresher | `PATH_FRESHER` | 12 weeks |
| 0–5 years | `PATH_0_5` | 10 weeks |
| 5–9 years | `PATH_5_9` | 8 weeks |
| 9+ years | `PATH_9_PLUS` | 6 weeks |

Verify the learning paths:

```sql
SELECT
    PATH_ID,
    EXPERIENCE_LEVEL_CODE,
    PATH_NAME,
    DURATION_WEEKS,
    WEEKLY_STUDY_HOURS
FROM SNOWPRO_ENABLEMENT.CORE.LEARNING_PATHS
ORDER BY DURATION_WEEKS DESC;
```

---

### Step 5: Create the RAW Ingestion Objects

Execute:

```text
sql/05_raw_ingestion_setup.sql
```

This script creates the initial objects required for CSV ingestion, such as:

- CSV file format
- Internal stage
- RAW ingestion tables

Verify the stage:

```sql
SHOW STAGES IN SCHEMA SNOWPRO_ENABLEMENT.RAW;
```

Verify the file format:

```sql
SHOW FILE FORMATS IN SCHEMA SNOWPRO_ENABLEMENT.RAW;
```

---

### Step 6: Upload and Load Study Topics

The study-topic file is:

```text
data/study_topics.csv
```

The file currently contains 31 SnowPro Core study topics across five domains.

Upload the file through Snowsight:

1. Open Snowsight.
2. Select `Data`.
3. Open the `SNOWPRO_ENABLEMENT` database.
4. Open the `RAW` schema.
5. Select the internal stage created by the setup script.
6. Select `Files`.
7. Select `Upload files`.
8. Choose `data/study_topics.csv`.
9. Complete the upload.

Confirm that the file is available:

```sql
LIST @SNOWPRO_ENABLEMENT.RAW.CERTIFICATION_UPLOAD_STAGE;
```

Execute:

```text
sql/06_load_study_topics.sql
```

This script loads the CSV data into the RAW study-topic table.

---

### Step 7: Deploy the Study-Topic Pipeline

Execute:

```text
sql/07_study_topics_pipeline.sql
```

This script creates:

- A Stream for detecting new study-topic records
- A stored procedure for validating study topics
- A rejected-records table
- A pipeline run-log table
- A scheduled Snowflake Task

The pipeline validates new study topics before merging them into:

```text
SNOWPRO_ENABLEMENT.CORE.STUDY_TOPICS
```

Valid records are loaded into the CORE schema.

Invalid records are stored with their rejection reason.

Verify the study topics:

```sql
SELECT
    DOMAIN_ID,
    COUNT(*) AS TOPIC_COUNT
FROM SNOWPRO_ENABLEMENT.CORE.STUDY_TOPICS
GROUP BY DOMAIN_ID
ORDER BY DOMAIN_ID;
```

The expected total is 31 topics.

---

### Step 8: Deploy Learner Registration

Execute:

```text
sql/08_learner_registration.sql
```

This script creates the learner-registration procedure:

```text
SNOWPRO_ENABLEMENT.CONTROL.REGISTER_LEARNER
```

The procedure:

1. Validates required learner details.
2. Validates Snowflake experience.
3. Determines the experience category.
4. Selects the matching learning path.
5. Creates or updates the learner.
6. Creates the certification enrollment.
7. Initializes progress for all assigned topics.
8. Calculates the target completion and exam dates.

Verify the procedure:

```sql
SHOW PROCEDURES LIKE 'REGISTER_LEARNER'
IN SCHEMA SNOWPRO_ENABLEMENT.CONTROL;
```

Example procedure call:

```sql
CALL SNOWPRO_ENABLEMENT.CONTROL.REGISTER_LEARNER(
    'EMP_SAMPLE_001',
    'Sample Learner',
    'sample.learner@example.com',
    'Data Engineering',
    0
);
```

Do not store real employee details directly in the Git SQL files.

---

### Step 9: Generate Learning Schedules

Execute:

```text
sql/09_learning_schedule.sql
```

This script creates the learning schedule for each experience-based learning path.

The schedule determines:

- Topics assigned to each path
- Planned study week
- Recommended study hours
- Required topics

Verify the schedule:

```sql
SELECT
    PATH_ID,
    COUNT(*) AS TOTAL_TOPICS,
    MIN(PLANNED_WEEK) AS FIRST_WEEK,
    MAX(PLANNED_WEEK) AS LAST_WEEK,
    SUM(RECOMMENDED_HOURS) AS TOTAL_STUDY_HOURS
FROM SNOWPRO_ENABLEMENT.CORE.PATH_TOPIC_PLAN
GROUP BY PATH_ID
ORDER BY LAST_WEEK DESC;
```

Expected path durations:

| Path | Topics | Last week |
|---|---:|---:|
| `PATH_FRESHER` | 31 | 12 |
| `PATH_0_5` | 31 | 10 |
| `PATH_5_9` | 31 | 8 |
| `PATH_9_PLUS` | 31 | 6 |

---

### Step 10: Deploy the Learning-Activity Pipeline

Execute:

```text
sql/10_learning_activity_pipeline.sql
```

This script creates:

- Learning-events table
- Learning-events Stream
- Learning-event processing procedure
- Learning-event processing Task

When a learner activity is received, the pipeline updates:

- Progress status
- Completion percentage
- Study hours
- Started timestamp
- Completed timestamp
- Last activity timestamp

Verify the Task:

```sql
SHOW TASKS LIKE 'PROCESS_LEARNING_EVENTS_TASK'
IN SCHEMA SNOWPRO_ENABLEMENT.CONTROL;
```

---

### Step 11: Create Analytics Views

Execute:

```text
sql/11_analytics_views.sql
```

This script creates views for reporting and monitoring.

The views provide information about:

- Learner enrollment
- Assigned learning path
- Topic completion
- Study hours
- Overall progress
- Assessment performance

Verify the views:

```sql
SHOW VIEWS IN SCHEMA SNOWPRO_ENABLEMENT.ANALYTICS;
```

---

### Step 12: Configure Role-Based Access Control

Execute:

```text
sql/12_rbac.sql
```

This script creates the platform roles and grants the required access.

The access model separates:

- Administrative access
- Learner access
- Reporting access
- Pipeline-processing access

Verify the roles:

```sql
SHOW ROLES;
```

Verify role grants:

```sql
SHOW GRANTS TO ROLE SNOWPRO_ADMIN_ROLE;

SHOW GRANTS TO ROLE SNOWPRO_LEARNER_ROLE;
```

The exact role names should be verified against `sql/12_rbac.sql`.

---

### Step 13: Deploy the Learner-Information CSV Pipeline

Execute:

```text
sql/13_learner_information_pipeline.sql
```

This script creates:

- `RAW.LEARNER_INFORMATION_INBOX`
- `RAW.LEARNER_INFORMATION_STREAM`
- `CONTROL.CSV_REJECTED_RECORDS`
- `CONTROL.CSV_PIPELINE_RUN_LOG`
- `CONTROL.CSV_PROCESSED_RECORDS`
- `CONTROL.PROCESS_LEARNER_INFORMATION()`
- `CONTROL.PROCESS_LEARNER_INFORMATION_TASK`

The learner-information CSV template is:

```text
data/learner_information.csv
```

The file contains fields such as:

- Source record ID
- Employee ID
- Learner name
- Email address
- Department name
- Snowflake experience in years

Upload the file to:

```text
SNOWPRO_ENABLEMENT.RAW.CERTIFICATION_UPLOAD_STAGE
```

Load it into:

```text
SNOWPRO_ENABLEMENT.RAW.LEARNER_INFORMATION_INBOX
```

Run the processing procedure:

```sql
CALL SNOWPRO_ENABLEMENT.CONTROL.PROCESS_LEARNER_INFORMATION();
```

The procedure:

1. Reads newly added records from the Stream.
2. Validates required learner details.
3. Validates Snowflake experience.
4. Assigns the correct experience category.
5. Assigns the correct learning path.
6. Creates the learner record.
7. Creates the enrollment.
8. Initializes all assigned topics.
9. Stores invalid records with a rejection reason.
10. Records the pipeline execution in the run-log table.

Verify learners:

```sql
SELECT
    LEARNER_ID,
    EMPLOYEE_ID,
    LEARNER_NAME,
    SNOWFLAKE_EXPERIENCE_YEARS,
    EXPERIENCE_LEVEL_CODE,
    CREATED_AT
FROM SNOWPRO_ENABLEMENT.CORE.LEARNERS
ORDER BY CREATED_AT DESC;
```

Verify learner enrollments:

```sql
SELECT
    ENROLLMENT_ID,
    LEARNER_ID,
    PATH_ID,
    ENROLLED_DATE,
    TARGET_COMPLETION_DATE,
    TARGET_EXAM_DATE,
    ENROLLMENT_STATUS
FROM SNOWPRO_ENABLEMENT.CORE.ENROLLMENTS
ORDER BY CREATED_AT DESC;
```

---

### Step 14: Deploy the Learner-Progress CSV Pipeline

Execute:

```text
sql/14_learner_progress_pipeline.sql
```

This script creates:

- `RAW.LEARNER_PROGRESS_INBOX`
- `RAW.LEARNER_PROGRESS_STREAM`
- `CONTROL.PROCESS_LEARNER_PROGRESS()`
- `CONTROL.PROCESS_LEARNER_PROGRESS_TASK`

The learner-progress CSV template is:

```text
data/learner_progress.csv
```

The file contains fields such as:

- Activity ID
- Employee ID
- Topic ID
- Event type
- Activity timestamp
- Duration in minutes
- Completion percentage
- Notes

Upload the file to:

```text
SNOWPRO_ENABLEMENT.RAW.CERTIFICATION_UPLOAD_STAGE
```

Load it into:

```text
SNOWPRO_ENABLEMENT.RAW.LEARNER_PROGRESS_INBOX
```

Run the processing procedures:

```sql
CALL SNOWPRO_ENABLEMENT.CONTROL.PROCESS_LEARNER_PROGRESS();

CALL SNOWPRO_ENABLEMENT.CONTROL.PROCESS_LEARNING_EVENTS();
```

The progress pipeline:

1. Detects newly loaded progress records.
2. Validates the employee ID.
3. Validates the topic ID.
4. Validates the event type.
5. Validates the completion percentage.
6. Validates the activity duration.
7. Creates a learning event.
8. Updates the learner’s topic progress.
9. Updates study hours and timestamps.
10. Stores invalid records with a rejection reason.
11. Records the pipeline execution in the run-log table.

---

## 6. Streams, Tasks and Procedures

The platform uses Streams, Tasks and stored procedures for automated processing.

### Streams

Streams detect data changes that have not already been processed.

The main Streams are:

- Study-topic Stream
- Learner-information Stream
- Learner-progress Stream
- Learning-events Stream

After a stored procedure successfully processes the Stream records, those changes are considered consumed.

Later executions see only newer changes.

### Tasks

Tasks check whether a Stream contains new data.

If the Stream contains data, the Task calls the relevant stored procedure.

If the Stream contains no new data, the procedure is not called.

### Stored Procedures

Stored procedures perform the main processing logic, including:

- Data validation
- Learner registration
- Learning-path assignment
- Progress updates
- Invalid-record handling
- Pipeline logging

---

## 7. Task Management

### View All Tasks

```sql
SHOW TASKS IN DATABASE SNOWPRO_ENABLEMENT;
```

### Resume Automatic Tasks

Resume the Tasks only when scheduled processing is required:

```sql
ALTER TASK SNOWPRO_ENABLEMENT.CONTROL.PROCESS_LEARNER_INFORMATION_TASK RESUME;

ALTER TASK SNOWPRO_ENABLEMENT.CONTROL.PROCESS_LEARNER_PROGRESS_TASK RESUME;

ALTER TASK SNOWPRO_ENABLEMENT.CONTROL.PROCESS_LEARNING_EVENTS_TASK RESUME;

ALTER TASK SNOWPRO_ENABLEMENT.CONTROL.PROCESS_STUDY_TOPICS_TASK RESUME;
```

### Suspend Automatic Tasks

Suspend the Tasks after testing to reduce trial-account usage:

```sql
ALTER TASK SNOWPRO_ENABLEMENT.CONTROL.PROCESS_LEARNER_INFORMATION_TASK SUSPEND;

ALTER TASK SNOWPRO_ENABLEMENT.CONTROL.PROCESS_LEARNER_PROGRESS_TASK SUSPEND;

ALTER TASK SNOWPRO_ENABLEMENT.CONTROL.PROCESS_LEARNING_EVENTS_TASK SUSPEND;

ALTER TASK SNOWPRO_ENABLEMENT.CONTROL.PROCESS_STUDY_TOPICS_TASK SUSPEND;
```

### Execute a Task Manually

A Task can be executed manually for testing:

```sql
EXECUTE TASK SNOWPRO_ENABLEMENT.CONTROL.PROCESS_LEARNER_INFORMATION_TASK;
```

```sql
EXECUTE TASK SNOWPRO_ENABLEMENT.CONTROL.PROCESS_LEARNER_PROGRESS_TASK;
```

---

## 8. Invalid-Record Handling

Invalid learner and progress records are stored in:

```text
SNOWPRO_ENABLEMENT.CONTROL.CSV_REJECTED_RECORDS
```

Each rejected record contains:

- Pipeline name
- Source record ID
- Source file name
- Rejection reason
- Original source record
- Rejected timestamp
- Resolution status
- Resolution timestamp

View rejected records:

```sql
SELECT
    PIPELINE_NAME,
    SOURCE_RECORD_ID,
    SOURCE_FILE_NAME,
    REJECTION_REASON,
    RAW_RECORD,
    REJECTED_AT,
    RESOLVED_FLAG,
    RESOLVED_AT
FROM SNOWPRO_ENABLEMENT.CONTROL.CSV_REJECTED_RECORDS
ORDER BY REJECTED_AT DESC;
```

Examples of validation failures include:

- Negative Snowflake experience
- Missing employee ID
- Missing learner name
- Missing email address
- Unknown employee ID
- Unknown topic ID
- Invalid event type
- Completion percentage below 0
- Completion percentage above 100
- Negative activity duration

---

## 9. Correcting and Reprocessing Invalid Records

To correct an invalid record:

1. Review the rejection reason.
2. Correct the value in the source CSV file.
3. Use a new source record ID or activity ID.
4. Upload the corrected CSV file.
5. Load it into the appropriate RAW inbox table.
6. Run the relevant processing procedure.
7. Confirm that the corrected record reached the CORE schema.
8. Confirm that the earlier rejected record is marked as resolved.

Test files are available in:

```text
tests/data/
```

The test files include:

- `invalid_learners.csv`
- `corrected_learners.csv`
- `invalid_progress.csv`
- `corrected_progress.csv`

---

## 10. Pipeline Run Logging

Every pipeline execution is recorded in:

```text
SNOWPRO_ENABLEMENT.CONTROL.CSV_PIPELINE_RUN_LOG
```

View recent pipeline runs:

```sql
SELECT
    PIPELINE_NAME,
    RUN_STATUS,
    RECORDS_RECEIVED,
    RECORDS_ACCEPTED,
    RECORDS_REJECTED,
    RUN_MESSAGE,
    STARTED_AT
FROM SNOWPRO_ENABLEMENT.CONTROL.CSV_PIPELINE_RUN_LOG
ORDER BY STARTED_AT DESC;
```

The run log provides:

- Pipeline name
- Execution status
- Records received
- Records accepted
- Records rejected
- Processing message
- Execution timestamp

A repeated procedure call can show zero records processed.

This is expected when the Stream does not contain any new unprocessed records.

---

## 11. Deployment Verification

### Verify Study Topics

```sql
SELECT COUNT(*) AS TOTAL_STUDY_TOPICS
FROM SNOWPRO_ENABLEMENT.CORE.STUDY_TOPICS;
```

Expected result:

```text
31
```

### Verify Learners

```sql
SELECT
    EMPLOYEE_ID,
    LEARNER_NAME,
    SNOWFLAKE_EXPERIENCE_YEARS,
    EXPERIENCE_LEVEL_CODE
FROM SNOWPRO_ENABLEMENT.CORE.LEARNERS
ORDER BY CREATED_AT DESC;
```

### Verify Enrollments

```sql
SELECT
    ENROLLMENT_ID,
    LEARNER_ID,
    PATH_ID,
    ENROLLMENT_STATUS
FROM SNOWPRO_ENABLEMENT.CORE.ENROLLMENTS
ORDER BY CREATED_AT DESC;
```

### Verify Topic Assignment

```sql
SELECT
    ENROLLMENT_ID,
    COUNT(*) AS ASSIGNED_TOPICS,
    COUNT_IF(PROGRESS_STATUS = 'COMPLETED') AS COMPLETED_TOPICS,
    COUNT_IF(PROGRESS_STATUS = 'IN_PROGRESS') AS IN_PROGRESS_TOPICS,
    COUNT_IF(PROGRESS_STATUS = 'NOT_STARTED') AS NOT_STARTED_TOPICS
FROM SNOWPRO_ENABLEMENT.CORE.TOPIC_PROGRESS
GROUP BY ENROLLMENT_ID
ORDER BY ENROLLMENT_ID;
```

### Verify Recent Progress

```sql
SELECT
    ENROLLMENT_ID,
    TOPIC_ID,
    PROGRESS_STATUS,
    COMPLETION_PERCENT,
    HOURS_SPENT,
    STARTED_AT,
    COMPLETED_AT,
    LAST_ACTIVITY_AT
FROM SNOWPRO_ENABLEMENT.CORE.TOPIC_PROGRESS
ORDER BY UPDATED_AT DESC;
```

### Verify Rejected Records

```sql
SELECT *
FROM SNOWPRO_ENABLEMENT.CONTROL.CSV_REJECTED_RECORDS
ORDER BY REJECTED_AT DESC;
```

### Verify Pipeline Runs

```sql
SELECT *
FROM SNOWPRO_ENABLEMENT.CONTROL.CSV_PIPELINE_RUN_LOG
ORDER BY STARTED_AT DESC;
```

---

## 12. Testing

Execute the data-quality tests:

```text
tests/02_platform_data_quality_tests.sql
```

Execute the CSV-pipeline validation tests:

```text
tests/03_csv_pipeline_validation_tests.sql
```

The tests cover:

- Certification data
- Exam domains
- Experience-based learning paths
- Study-topic counts
- Learner creation
- Experience-level assignment
- Learning-path assignment
- Enrollment creation
- Topic-progress initialization
- Learner-progress processing
- Invalid learner rejection
- Invalid progress rejection
- Corrected-record processing
- Rejection resolution
- Pipeline run logging
- Scheduled Task processing

All functional, validation and automation tests should return `PASS`.

The recorded test results are available in:

```text
docs/TEST_RESULTS.md
```

---

## 13. Cost Management

The platform uses an X-Small warehouse.

The warehouse should use:

- Auto-suspend
- Auto-resume
- Short Task schedules only during testing
- Suspended Tasks when automation is not required

Suspend the warehouse after testing if it is still running:

```sql
ALTER WAREHOUSE SNOWPRO_LEARNING_WH SUSPEND;
```

An already suspended warehouse may return a message stating that it cannot be suspended. This is expected.

---

## 14. Security Considerations

The following security practices must be followed:

- Do not commit passwords or authentication details to Git.
- Do not store real employee data in sample Git CSV files.
- Use fictional records for demonstrations.
- Keep real learner information only in approved company locations.
- Grant users only the access required for their work.
- Separate administrative and learner access.
- Review role grants before production deployment.
- Use approved Snowflake authentication methods.

---

## 15. Current Deployment Status

The following features have been implemented and tested:

- Snowflake database and schema setup
- X-Small learning warehouse
- Certification reference tables
- SnowPro Core foundation data
- Experience-based learning paths
- Study-topic CSV ingestion
- Study-topic validation pipeline
- Learner-registration procedure
- Learning schedule generation
- Learning-activity processing
- Learner-information CSV pipeline
- Learner-progress CSV pipeline
- Invalid-record handling
- Corrected-record reprocessing
- Rejected-record resolution
- Pipeline run logging
- Analytics views
- Role-based access control
- Scheduled Snowflake Tasks
- Data-quality tests
- Automation tests
- Git-based source control

All 15 functional, validation and automation tests passed during prototype testing.

---

## 16. Current Limitations

The current prototype has the following limitations:

- CSV files are uploaded manually through Snowsight.
- Only the SnowPro Core certification is configured.
- Notifications are not yet implemented.
- Learning-path durations are currently stored in seed configuration.
- The platform does not yet have a Streamlit user interface.
- The Mastech learner Excel source is not yet connected.
- Production deployment and release automation are not yet configured.

---

## 17. Future Roadmap

Planned enhancements include:

- Connect the approved Mastech Excel source.
- Automatically load learner information into the RAW schema.
- Automatically load learner progress into the RAW schema.
- Add pipeline-failure notifications.
- Add rejected-record notifications.
- Support additional Snowflake certifications.
- Make certification topics configurable.
- Make learning-path durations configurable.
- Make Task schedules configurable.
- Add administrative reporting.
- Add a learner-facing Streamlit application.
- Add production deployment automation.
- Add environment-specific configuration.
- Add formal approval and release processes.

---

## 18. Git Deployment Process

All project artifacts must remain in Git.

After completing and verifying changes, run:

```powershell
git status
```

Stage the changes:

```powershell
git add .
```

Check for formatting problems:

```powershell
git diff --cached --check
```

Commit the changes:

```powershell
git commit -m "Update platform deployment documentation"
```

Push the changes:

```powershell
git push origin main
```

Confirm that the repository is clean:

```powershell
git status
```

Expected result:

```text
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean
```

---

## 19. Final Deployment Result

The Snowflake Certification Enablement Platform is ready for prototype demonstration.

The deployed workflow supports:

1. Initial platform configuration
2. Study-topic configuration
3. Learner-information CSV upload
4. Experience-based learning-path assignment
5. Learner-progress CSV upload
6. Automatic progress updates
7. Invalid-record rejection
8. Corrected-record reprocessing
9. Pipeline monitoring
10. Analytics and reporting

The current input method is manual CSV upload.

The planned production enhancement is to connect the approved Mastech Excel-based source and automatically load learner and progress information into the Snowflake RAW layer.