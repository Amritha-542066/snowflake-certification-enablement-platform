# SnowPro Core Enablement Platform

## Overview

The SnowPro Core Enablement Platform is a Snowflake-based learning platform for employees preparing for the SnowPro Core certification.

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