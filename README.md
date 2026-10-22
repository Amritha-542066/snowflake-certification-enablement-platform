# Snowflake Certification Enablement Platform

## Overview

The Snowflake Certification Enablement Platform is a proof-of-concept platform for managing an employee's certification journey in Snowflake.

It supports:

- Certification reference data such as exam domains and study topics
- Employee and Pod Lead nomination
- Certification enrollment
- Learner-specific topic planning
- Progress tracking
- Readiness analytics
- Inactivity reminders
- Validation, rejection handling and pipeline logging

The current implementation supports the SnowPro Core certification. The design is intended to support additional certifications after architecture review.

> **Project status:** Proof of concept. The main Snowflake workflows are implemented, but the data model and dynamic-enrollment analytics are still under review. Live email sending and external-source integration are not enabled.

---

## Current Workflows

### 1. Study-topic ingestion

```text
Study-topic CSV
    -> Snowflake internal stage
    -> RAW inbox table
    -> Stream
    -> Scheduled Task
    -> Validation procedure
    -> Valid records: CORE
    -> Invalid records: CONTROL rejection table
```

### 2. Pod Lead nomination

A Pod Lead provides business-friendly information such as:

- Employee ID and name
- Email and department
- Pod and Pod Lead
- Certification
- Target completion date

The Pod Lead does not need to supply internal platform IDs.

```text
Nomination CSV
    -> Internal stage
    -> RAW nomination inbox
    -> Stream
    -> Scheduled Task
    -> Nomination-processing procedure
    -> Business nomination procedure
    -> Learner, membership, nomination and enrollment
    -> Learner-specific topic plan
    -> Initial topic progress
```

The processing procedure validates the input structure. The business procedure validates the Pod Lead, Pod, certification and active topics before creating the enrollment and plan.

### 3. Learning progress

```text
Progress CSV or procedure call
    -> RAW progress inbox or learning event
    -> Stream
    -> Scheduled Task
    -> Progress-processing procedure
    -> CORE learning events
    -> Topic progress update
```

### 4. Weekly reminders

The reminder workflow identifies active learners who have not recorded activity within the configured period.

It prepares:

- One reminder for the learner
- One follow-up notification for the Pod Lead

The reminder workflow is in simulation mode by default. Live email sending must not be enabled until the notification integration and recipient addresses are approved and verified.

---

## Snowflake Architecture

The database is separated into four schemas:

| Schema | Responsibility |
|---|---|
| `RAW` | Receives incoming records before business validation |
| `CORE` | Stores validated business data |
| `CONTROL` | Contains procedures, Tasks, configuration, rejection records and pipeline logs |
| `ANALYTICS` | Contains reporting and readiness views |

The development environment uses:

```text
Warehouse: WH_CERT_ENABLEMENT_DEV_XS
Database:  DB_CERT_ENABLEMENT_DEV
```

---

## Implemented Components

| Area | Current status |
|---|---|
| Snowflake environment and schemas | Implemented |
| Certification, domain and topic reference data | Implemented |
| Study-topic CSV pipeline | Implemented |
| Fixed experience-based learner registration | Implemented as an earlier workflow |
| Pod Lead nomination pipeline | Implemented |
| Dynamic learner-specific topic planning | Implemented |
| Learner-information CSV pipeline | Implemented |
| Learner-progress CSV pipeline | Implemented |
| Learning-event processing | Implemented |
| Readiness and progress analytics | Implemented, but dynamic-enrollment alignment requires review |
| Role-based access control | Implemented for the existing objects; newer objects require review |
| Weekly reminder framework | Implemented in simulation mode |
| Automated live email sending | Not enabled |
| SharePoint or approved external ingestion | Roadmap |
| Streamlit user interface | Roadmap |
| Recommendation agent | Roadmap |

---

## Current and Proposed Data Models

The repository currently represents two different stages of the platform:

1. The existing Snowflake implementation created by the numbered SQL files.
2. A proposed relational model studied in PostgreSQL using fictional data.

The PostgreSQL model is a design and normalization exercise. It has not replaced the existing Snowflake `CORE` model.

Before changing Snowflake tables, the proposed model must be reviewed and approved.

Relevant documentation:

- [Platform architecture](docs/architecture.md)
- [Data model](docs/data-model.md)
- [Assumptions and limitations](docs/assumptions-and-limitations.md)
- [Roadmap](docs/roadmap.md)

---

## Repository Structure

```text
snowpro-core-enablement-platform/
|
|-- README.md
|-- .gitignore
|
|-- data/
|   |-- certification_nominations.csv
|   |-- learner_information.csv
|   |-- learner_progress.csv
|   `-- study_topics.csv
|
|-- docs/
|   |-- README.md
|   |-- architecture.md
|   |-- assumptions-and-limitations.md
|   |-- csv-upload-guide.md
|   |-- data-model.md
|   |-- deployment-guide.md
|   |-- procedure-catalog.md
|   |-- roadmap.md
|   `-- test-results.md
|
|-- sql/
|   |-- 01_setup.sql
|   |-- 02_reference_tables.sql
|   |-- 03_learner_tracking_tables.sql
|   |-- 04_seed_foundation_data.sql
|   |-- 05_raw_ingestion_setup.sql
|   |-- 06_load_study_topics.sql
|   |-- 07_study_topics_pipeline.sql
|   |-- 08_learner_registration.sql
|   |-- 09_learning_schedule.sql
|   |-- 10_learning_activity_pipeline.sql
|   |-- 11_analytics_views.sql
|   |-- 12_rbac.sql
|   |-- 13_learner_information_pipeline.sql
|   |-- 14_learner_progress_pipeline.sql
|   |-- 15_pod_nomination_dynamic_plan.sql
|   |-- 16_pod_nomination_pipeline.sql
|   `-- 17_weekly_progress_reminders.sql
|
`-- tests/
    |-- 01_study_topics_pipeline_test.sql
    |-- 02_platform_data_quality_tests.sql
    |-- 03_csv_pipeline_validation_tests.sql
    |-- 04_pod_dynamic_plan_reminder_tests.sql
    `-- data/
        |-- corrected_learners.csv
        |-- corrected_progress.csv
        |-- invalid_learners.csv
        `-- invalid_progress.csv
```

---

## SQL Deployment Order

The SQL files are numbered according to dependency order.

Execute them from:

```text
sql/01_setup.sql
```

through:

```text
sql/17_weekly_progress_reminders.sql
```

Use a development Snowflake account first. Review environment-specific object names, email settings, role grants and Task states before deployment.

For detailed instructions, see the [deployment guide](docs/deployment-guide.md).

---

## Input Files

The `data` directory contains development and demonstration inputs.

| File | Purpose |
|---|---|
| `study_topics.csv` | Certification study-topic reference data |
| `learner_information.csv` | Learner-registration data for the earlier workflow |
| `learner_progress.csv` | Learner progress and activity updates |
| `certification_nominations.csv` | Pod Lead certification nominations |

Do not commit real employee information, credentials, tokens or verified email addresses.

For file formats and upload instructions, see the [CSV upload guide](docs/csv-upload-guide.md).

---

## Testing

The repository contains four SQL test scripts:

| Test file | Purpose |
|---|---|
| `01_study_topics_pipeline_test.sql` | Tests the study-topic ingestion workflow |
| `02_platform_data_quality_tests.sql` | Validates platform-level data-quality rules |
| `03_csv_pipeline_validation_tests.sql` | Tests learner and progress CSV processing |
| `04_pod_dynamic_plan_reminder_tests.sql` | Tests Pod nomination, dynamic planning and reminders |

Test input files are stored under `tests/data`.

Review the environment and expected data before executing the tests. Some tests insert demonstration records or call stored procedures.

Previous test evidence is recorded in [test results](docs/test-results.md).

---

## Stored Procedures and Tasks

Stored procedures perform validation and business processing.

Snowflake Tasks control when scheduled processing runs. Streams expose new table changes to the processing procedures.

For the procedure and Task inventory, see the [procedure catalogue](docs/procedure-catalog.md).

Tasks should remain suspended when automatic processing is not required, particularly in development or trial accounts.

---

## Known Limitations

- The proposed PostgreSQL data model has not been implemented in Snowflake.
- The older fixed-path and newer dynamic-plan workflows currently coexist.
- Dynamic enrollments and the existing analytics views require alignment.
- Role grants for the newer objects require a complete review.
- Progress relies on activity supplied by users or input files; the platform is not a full Learning Management System.
- The reminder workflow uses simulation mode by default.
- Live email recipients must be verified Snowflake users.
- Manual file upload is still used.
- Weighted topic allocation is a roadmap item, not part of the current implementation.
- Certification results, expiry tracking and renewal reminders are roadmap items.

See [assumptions and limitations](docs/assumptions-and-limitations.md) for more information.

---

## Roadmap

Planned work is separated from the current proof of concept.

Major roadmap areas include:

- Approved SharePoint or external-source ingestion
- Support for additional certifications
- Weighted topic scheduling
- Extension and schedule-recalculation workflows
- Certification results, validity and renewal tracking
- Streamlit-based user interaction
- Interview feedback and employee write-ups
- Recommendation-agent integration
- Partner-level certification reporting

See the [version roadmap](docs/roadmap.md) for the planned version split.

---

## Documentation Guide

Start with:

1. [Documentation index](docs/README.md)
2. [Architecture](docs/architecture.md)
3. [Data model](docs/data-model.md)
4. [Procedure catalogue](docs/procedure-catalog.md)
5. [Deployment guide](docs/deployment-guide.md)
6. [CSV upload guide](docs/csv-upload-guide.md)
7. [Test results](docs/test-results.md)
8. [Assumptions and limitations](docs/assumptions-and-limitations.md)
9. [Roadmap](docs/roadmap.md)

---

## Security

- Do not commit passwords, private keys, access tokens or personal access tokens.
- Do not commit real employee data.
- Keep live notification sending disabled until recipients and integrations are approved.
- Review account-specific role grants before deployment.
- Use least-privilege roles for operational access.

---

## Contribution Guidance

Before extending the platform:

1. Read the architecture and data-model documents.
2. Confirm whether the change belongs to the current implementation or roadmap.
3. Create a feature branch.
4. Update SQL files in dependency order.
5. Add or update relevant tests.
6. Update the documentation.
7. Test in a development account.
8. Request review before merging.

Avoid changing the current Snowflake physical model solely from the PostgreSQL practice model without architecture approval.