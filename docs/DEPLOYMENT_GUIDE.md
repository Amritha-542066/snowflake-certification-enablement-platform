# Snowflake Certification Enablement Platform — Deployment Guide

## 1. Purpose

The Snowflake Certification Enablement Platform provides structured certification learning paths based on a learner's Snowflake experience.

The platform supports:

- Four experience-based learning paths.
- SnowPro Core exam domains and study topics.
- Weekly study schedules.
- Learner registration and enrollment.
- Topic-level progress tracking.
- Continuous learning-activity processing.
- Assessment and certification-readiness tracking.
- Role-based access control.
- Data-quality validation.

---

## 2. Experience-Based Learning Paths

| Experience level | Duration | Weekly study hours |
|---|---:|---:|
| Fresher | 12 weeks | 8 hours |
| 0–5 years of Snowflake experience | 10 weeks | 7 hours |
| 5–9 years of Snowflake experience | 8 weeks | 6 hours |
| 9+ years of Snowflake experience | 6 weeks | 5 hours |

The timelines can be adjusted based on business requirements.

---

## 3. Prerequisites

Before deployment, confirm that the following are available:

- A Snowflake account.
- A role with permission to create warehouses, databases, schemas, tables, procedures, Streams, Tasks, views and roles.
- Snowsight or another supported Snowflake SQL client.
- Git installed locally.
- The `study_topics.csv` file from the repository.
- Sufficient Snowflake credits for an X-Small warehouse.

For the current demonstration, the scripts use the `ACCOUNTADMIN` role.

---

## 4. Repository Structure

```text
snowpro-core-enablement-platform/
├── data/
│   └── study_topics.csv
├── docs/
│   └── DEPLOYMENT_GUIDE.md
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
│   └── 12_rbac.sql
├── tests/
│   ├── 01_study_topics_pipeline_test.sql
│   └── 02_platform_data_quality_tests.sql
├── .gitignore
└── README.md
```

---

## 5. Deployment Order

Execute the SQL files in the order listed below.

### How to Execute the SQL Files

The SQL files are stored and maintained in Git using VS Code.

For the current deployment:

1. Open each SQL file in VS Code.
2. Copy the complete SQL content.
3. Paste it into a Snowflake Snowsight worksheet.
4. Select all the statements and run them.
5. Verify the results before continuing to the next file.

If Snowflake CLI is available in another environment, the same files can also be executed through the CLI.

Snowsight is used in the current setup because the local Snowflake CLI connection is restricted by the corporate SSL configuration.

You do not need to execute the files again if the platform is already deployed. These instructions are for deploying the project in a new Snowflake environment.

### Step 1: Create the Snowflake Environment

Run:

```text
sql/01_setup.sql
```

This creates:

- `SNOWPRO_LEARNING_WH`
- `SNOWPRO_ENABLEMENT`
- `RAW`
- `CORE`
- `ANALYTICS`
- `CONTROL`

### Step 2: Create the Reference Tables

Run:

```text
sql/02_reference_tables.sql
```

This creates the certification, exam-domain, experience-level, learning-path and study-topic structures.

### Step 3: Create the Learner-Tracking Tables

Run:

```text
sql/03_learner_tracking_tables.sql
```

This creates tables for:

- Learners
- Enrollments
- Topic progress
- Learning events
- Assessment results

### Step 4: Load the Foundation Data

Run:

```text
sql/04_seed_foundation_data.sql
```

This loads:

- SnowPro Core certification details.
- Five exam domains.
- Four experience levels.
- Four learning paths.

### Step 5: Create the Ingestion Objects

Run:

```text
sql/05_raw_ingestion_setup.sql
```

This creates:

- RAW inbox table.
- CSV file format.
- Internal stage.

### Step 6: Upload the Study-Topic CSV

Upload:

```text
data/study_topics.csv
```

to:

```text
@SNOWPRO_ENABLEMENT.RAW.SNOWPRO_DATA_STAGE
```

For the current deployment, upload the file through Snowsight:

1. Open Snowsight.
2. Locate the `SNOWPRO_ENABLEMENT` database.
3. Open the `RAW` schema.
4. Open the `SNOWPRO_DATA_STAGE` stage.
5. Select **Upload files**.
6. Select `data/study_topics.csv` from the local repository.
7. Complete the upload.

### Step 7: Load the CSV into RAW

Run:

```text
sql/06_load_study_topics.sql
```

This copies the CSV records into the RAW inbox table.

### Step 8: Create and Run the Study-Topic Pipeline

Run:

```text
sql/07_study_topics_pipeline.sql
```

This creates:

- A Stream to detect new RAW records.
- A validation procedure.
- A rejected-records table.
- A pipeline-run log.
- A Task for continuous processing.

Valid records move to `CORE.STUDY_TOPICS`. Invalid records move to `CONTROL.REJECTED_RECORDS`.

### Step 9: Create Learner Registration

Run:

```text
sql/08_learner_registration.sql
```

This creates the reusable learner-registration procedure.

Do not add actual learner details to this Git file.

### Step 10: Generate the Weekly Schedules

Run:

```text
sql/09_learning_schedule.sql
```

This distributes all active study topics across the four learning paths.

The learning schedules must be generated before registering real learners so the registration procedure can assign the required topics.

### Step 11: Create the Learning-Activity Pipeline

Run:

```text
sql/10_learning_activity_pipeline.sql
```

This creates:

- Learning-event recording procedure.
- Learning-event Stream.
- Progress-processing procedure.
- Scheduled Task.

### Step 12: Create the Analytics Views

Run:

```text
sql/11_analytics_views.sql
```

This creates:

- `V_WEEKLY_STUDY_PLAN`
- `V_LEARNER_PROGRESS`
- `V_DOMAIN_PROGRESS`
- `V_CERTIFICATION_READINESS`

### Step 13: Create Roles and Permissions

Run:

```text
sql/12_rbac.sql
```

This creates:

- `SNOWPRO_LEARNER`
- `SNOWPRO_PROGRAM_MANAGER`
- `SNOWPRO_PLATFORM_ADMIN`

---

## 6. Register a Learner

Register learners after the weekly learning schedules have been generated.

Run learner-registration commands separately in a Snowflake worksheet.

Do not store real employee details in Git.

```sql
CALL SNOWPRO_ENABLEMENT.CONTROL.REGISTER_LEARNER(
    '<employee_id>',
    '<learner_name>',
    '<company_email>',
    '<department>',
    <snowflake_experience_years>
);
```

The procedure automatically:

1. Determines the learner's experience level.
2. Assigns the correct learning path.
3. Calculates the completion and exam target dates.
4. Creates the learner enrollment.
5. Assigns all required study topics.
6. Preserves existing progress if the learner is registered again.

---

## 7. Assign a Snowflake Role

Learner registration and Snowflake security access are separate processes.

Registering a learner does not automatically grant that person a Snowflake role. A Snowflake administrator must assign the appropriate role to the person's Snowflake username.

Real usernames must not be stored in the repository.

### Learner role

```sql
GRANT ROLE SNOWPRO_LEARNER
TO USER <snowflake_username>;
```

### Program-manager role

```sql
GRANT ROLE SNOWPRO_PROGRAM_MANAGER
TO USER <snowflake_username>;
```

### Platform-administrator role

```sql
GRANT ROLE SNOWPRO_PLATFORM_ADMIN
TO USER <snowflake_username>;
```

Users can verify their active role using:

```sql
SELECT
    CURRENT_USER(),
    CURRENT_ROLE();
```

---

## 8. Run the Tests

### Study-Topic Pipeline Test

Run:

```text
tests/01_study_topics_pipeline_test.sql
```

This confirms that:

- Valid records enter the CORE schema.
- Invalid records are stored in `CONTROL.REJECTED_RECORDS`.
- Pipeline execution is recorded.

### Platform Data-Quality Tests

Run:

```text
tests/02_platform_data_quality_tests.sql
```

Expected result:

- 12 test results.
- Every test returns `PASS`.

These tests verify:

- Domain weights.
- Learning-path count.
- Topic assignments.
- Valid planned weeks.
- Valid progress values.
- Missing or orphan records.
- Duplicate learners.
- Duplicate enrollments.
- Assessment scores.
- Experience-level and path mapping.

---

## 9. Continuous Processing

The project uses Snowflake Streams and Tasks.

### Study-Topic Pipeline

```text
CSV
  → Internal Stage
  → RAW Inbox
  → Stream
  → Validation Procedure
  → CORE or Rejected Records
```

### Learning-Activity Pipeline

```text
Learning Activity
  → Learning Events
  → Stream
  → Scheduled Task
  → Topic Progress
  → Analytics Views
```

Tasks process records only when the related Stream contains new data.

---

## 10. Data-Validation Locations

Validation is performed at different points.

### Before RAW Data Enters CORE

`CONTROL.PROCESS_STUDY_TOPICS()` validates incoming study topics.

- Valid records move to `CORE.STUDY_TOPICS`.
- Invalid records move to `CONTROL.REJECTED_RECORDS`.

### During Learner Registration

`CONTROL.REGISTER_LEARNER()` validates:

- Required learner information.
- Snowflake experience.
- Experience-level assignment.
- Learning-path assignment.

### During Learning-Activity Recording

`CONTROL.RECORD_LEARNING_ACTIVITY()` validates:

- Enrollment and topic assignment.
- Event type.
- Study duration.
- Completion percentage.

### After Data Is Processed

`tests/02_platform_data_quality_tests.sql` performs an overall health check of the platform.

The tests return `PASS` or `FAIL`. They do not insert, update or delete data.

---

## 11. Security Notes

- Real employee information is stored only in Snowflake.
- Real learner details are not committed to Git.
- Real Snowflake usernames are not committed to Git.
- Roles are assigned separately by a Snowflake administrator.
- Learners do not receive direct access to personal CORE tables.
- Stored procedures provide controlled access to registration and progress operations.
- Program managers can view analytics and maintain assessment results.
- Platform administrators can manage the complete platform.

---

## 12. Validation Checklist

After deployment, verify:

- The X-Small warehouse exists.
- All four schemas exist.
- Five exam domains are available.
- Four learning paths are available.
- Thirty-one study topics are present.
- Each learning path contains 31 topics.
- Learner registration works.
- A registered learner receives 31 topic-progress records.
- Streams and Tasks are created.
- The learning-activity Task is started.
- Analytics views return results.
- The three platform roles exist.
- All 12 data-quality tests pass.

---

## 13. Future Enhancement

A Streamlit interface can be added later for:

- Learner self-registration.
- Weekly study-plan display.
- Learning-progress updates.
- Assessment entry.
- Certification-readiness dashboards.
- Role-based page visibility.

Streamlit is not required for the current implementation and will be considered after approval.