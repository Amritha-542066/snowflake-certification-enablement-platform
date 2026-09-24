# Snowflake Certification Enablement Platform

## Overview

The Snowflake Certification Enablement Platform is a Snowflake-based learning platform for employees preparing for the SnowPro Core certification.

It provides structured learning paths based specifically on a learner's Snowflake experience and tracks their progress from registration to certification readiness.

The project is designed for multiple learners and supports continuous data processing, progress tracking, analytics, security and data-quality validation.

---

## Learning Paths

| Snowflake experience | Duration | Weekly study hours |
|---|---:|---:|
| Fresher | 12 weeks | 8 hours |
| 0–5 years | 10 weeks | 7 hours |
| 5–9 years | 8 weeks | 6 hours |
| 9+ years | 6 weeks | 5 hours |

The learning timelines can be adjusted based on feedback and business requirements.

---

## Main Features

- Experience-based SnowPro Core learning paths
- Five certification exam domains
- Thirty-one structured study topics
- Weekly study schedules
- Reusable learner-registration procedure
- Automatic topic assignment
- Topic-level progress tracking
- Continuous learning-activity processing
- Mock-assessment tracking
- Certification-readiness analytics
- Role-based access control
- Repeatable data-quality tests
- Git-based source control and documentation

---

## Architecture

```text
Study-topic CSV
      ↓
Internal Stage
      ↓
RAW Inbox
      ↓
Stream and Task
      ↓
Validation Procedure
      ├── Valid records → CORE
      └── Invalid records → CONTROL.REJECTED_RECORDS

Learner Registration
      ↓
Experience-Based Learning Path
      ↓
Weekly Topic Schedule
      ↓
Learning Events
      ↓
Stream and Task
      ↓
Topic Progress
      ↓
Analytics and Readiness Views
```

---

## Snowflake Objects

### Warehouse

```text
SNOWPRO_LEARNING_WH
```

Configuration:

- X-Small
- Auto-suspend enabled
- Auto-resume enabled

### Database

```text
SNOWPRO_ENABLEMENT
```

### Schemas

| Schema | Purpose |
|---|---|
| `RAW` | Incoming source data |
| `CORE` | Validated certification and learner data |
| `CONTROL` | Pipeline procedures, Tasks, logs and rejected records |
| `ANALYTICS` | Progress, schedule and readiness views |

---

## Repository Structure

```text
snowpro-core-enablement-platform/
├── data/
│   └── study_topics.csv
├── docs/
│   ├── DEPLOYMENT_GUIDE.md
│   └── DEMO_GUIDE.md
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

## Continuous Data Pipelines

### Study-Topic Pipeline

```text
CSV → Stage → RAW → Stream → Task → Validation → CORE
```

The pipeline:

- Processes newly loaded study topics.
- Moves valid records into CORE.
- Stores invalid records with rejection reasons.
- Records each pipeline execution.

### Learning-Activity Pipeline

```text
Activity → Learning Events → Stream → Task → Topic Progress
```

The pipeline:

- Records study time and completion percentage.
- Detects new activities.
- Updates learner progress automatically.
- Maintains activity timestamps and completion status.

---

## Analytics Views

| View | Purpose |
|---|---|
| `V_WEEKLY_STUDY_PLAN` | Weekly study schedule for each learning path |
| `V_LEARNER_PROGRESS` | Overall learner progress and study hours |
| `V_DOMAIN_PROGRESS` | Progress across the five exam domains |
| `V_CERTIFICATION_READINESS` | Readiness score, status and recommendation |

The readiness score is an internal learning indicator and is not a guarantee of certification success.

---

## Roles

| Role | Purpose |
|---|---|
| `SNOWPRO_LEARNER` | View study plans and record activities |
| `SNOWPRO_PROGRAM_MANAGER` | Register learners, maintain assessments and view analytics |
| `SNOWPRO_PLATFORM_ADMIN` | Manage the complete platform |

Actual Snowflake usernames are assigned to roles separately and are not stored in Git.

---

## Data Quality

The platform includes two test files:

```text
tests/01_study_topics_pipeline_test.sql
tests/02_platform_data_quality_tests.sql
```

The platform-level test file contains 12 checks covering:

- Exam-domain weights
- Learning-path availability
- Topic assignments
- Planned-week validation
- Progress percentages and study hours
- Orphan records
- Duplicate learners
- Duplicate enrollments
- Assessment scores
- Experience-level mapping

Expected result:

```text
12 PASS
0 FAIL
```

---

## Deployment

For the complete deployment order and instructions, see:

```text
docs/DEPLOYMENT_GUIDE.md
```

The SQL files are stored in Git and can be executed through Snowsight or Snowflake CLI.

Real learner details and real Snowflake usernames must not be committed to the repository.

---

## Demo

For the recommended presentation flow, see:

```text
docs/DEMO_GUIDE.md
```

The demo should primarily present the implementation from Git or VS Code.

---

## Technologies and Snowflake Features

- Snowflake SQL
- Virtual warehouses
- Internal stages
- CSV file formats
- `COPY INTO`
- Streams
- Tasks
- SQL stored procedures
- `MERGE`
- Views
- Role-based access control
- Future grants
- Git and GitHub

---

## Current Limitations

- Learner registration currently uses a stored-procedure call.
- Assessment entry currently uses SQL.
- Learning timelines may require adjustment after user feedback.
- Streamlit is not included in the current phase.

---

## Future Enhancement

After approval, a Streamlit application can provide:

- Learner self-registration
- Personalized weekly plans
- Progress-update forms
- Mock-assessment entry
- Readiness dashboards
- Role-based page visibility

---

## Project Status

The Snowflake backend implementation is complete.

Completed areas:

- Environment setup
- Certification data model
- Continuous topic ingestion
- Experience-based learning paths
- Learner registration
- Progress tracking
- Analytics and readiness
- RBAC
- Data-quality testing
- Deployment and demo documentation


## CSV Learner and Progress Ingestion

The platform supports CSV-based learner registration and learning-progress updates.

### Learner Information

The learner file is located at:

```text
data/learner_information.csv
```

Required fields:

- Source record ID
- Employee ID
- Learner name
- Email
- Department
- Snowflake experience in years

The learner pipeline:

1. Loads the CSV into `RAW.LEARNER_INFORMATION_INBOX`.
2. Uses `RAW.LEARNER_INFORMATION_STREAM` to detect new records.
3. Calls `CONTROL.PROCESS_LEARNER_INFORMATION`.
4. Validates learner information.
5. Calls `CONTROL.REGISTER_LEARNER`.
6. Assigns an experience-based learning path.
7. Initializes all assigned topics.
8. Stores invalid records with a rejection reason.
9. Records the pipeline result.

The implementation is available in:

```text
sql/13_learner_information_pipeline.sql
```

### Learner Progress

The progress file is located at:

```text
data/learner_progress.csv
```

Required fields:

- Activity ID
- Employee ID
- Topic ID
- Event type
- Duration in minutes
- Completion percentage
- Activity timestamp
- Notes

The progress pipeline:

1. Loads the CSV into `RAW.LEARNER_PROGRESS_INBOX`.
2. Uses `RAW.LEARNER_PROGRESS_STREAM` to detect new records.
3. Calls `CONTROL.PROCESS_LEARNER_PROGRESS`.
4. Validates the learner, enrollment, topic and activity.
5. Inserts valid activity into `CORE.LEARNING_EVENTS`.
6. Uses the existing learning-events pipeline to update topic progress.
7. Stores invalid records with a rejection reason.
8. Records the pipeline result.

The implementation is available in:

```text
sql/14_learner_progress_pipeline.sql
```

## Validation and Error Handling

Invalid records are stored in:

```text
SNOWPRO_ENABLEMENT.CONTROL.CSV_REJECTED_RECORDS
```

Pipeline execution results are stored in:

```text
SNOWPRO_ENABLEMENT.CONTROL.CSV_PIPELINE_RUN_LOG
```

Successfully accepted source IDs are stored in:

```text
SNOWPRO_ENABLEMENT.CONTROL.CSV_PROCESSED_RECORDS
```

This prevents the same source record from being accepted twice.

Rejected records can be corrected, uploaded again and marked as resolved after successful processing.

## Testing

The test data is stored under:

```text
tests/data
```

The complete CSV-pipeline validation script is:

```text
tests/03_csv_pipeline_validation_tests.sql
```

The testing results are documented in:

```text
docs/TEST_RESULTS.md
```

A total of 15 functional, validation and automation tests passed.

## Design Documentation

The platform design is documented in:

```text
docs/DESIGN_DOCUMENT.md
```

## Task Management

The following Snowflake Tasks are available:

- `PROCESS_STUDY_TOPICS_TASK`
- `PROCESS_LEARNER_INFORMATION_TASK`
- `PROCESS_LEARNER_PROGRESS_TASK`
- `PROCESS_LEARNING_EVENTS_TASK`

The Tasks were successfully tested and then suspended to protect trial-account credits.

Resume them only when automatic processing is required.

## Roadmap

Planned enhancements include:

- Connect the platform to the approved Mastech Excel source
- Automatically load learner and progress data into the RAW layer
- Add pipeline-failure and rejection notifications
- Support additional Snowflake certifications
- Make learning-path durations configurable
- Make experience categories configurable
- Add a Streamlit interface
- Establish a formal cost baseline