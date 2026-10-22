# SQL Deployment Guide

This directory contains the Snowflake SQL scripts for the Certification Enablement Platform.

The files are numbered according to dependency order. For a new environment, review the configuration and execute the scripts from `01` through `17`.

## Execution Order

| Order | File | Purpose |
| ---: | --- | --- |
| 1 | `01_setup.sql` | Creates the development warehouse, database and schemas |
| 2 | `02_reference_tables.sql` | Creates certification reference tables such as certifications, exam domains, topics and resources |
| 3 | `03_learner_tracking_tables.sql` | Creates learner, enrollment, plan, progress, event and assessment tables |
| 4 | `04_seed_foundation_data.sql` | Inserts the initial certification, domain, path and supporting reference data |
| 5 | `05_raw_ingestion_setup.sql` | Creates stages, file formats, RAW inboxes and common ingestion-control objects |
| 6 | `06_load_study_topics.sql` | Provides the initial study-topic file loading steps |
| 7 | `07_study_topics_pipeline.sql` | Creates the study-topic Stream, validation procedure and Task |
| 8 | `08_learner_registration.sql` | Creates the earlier fixed-path learner-registration procedure |
| 9 | `09_learning_schedule.sql` | Creates the learner schedule and topic-assignment logic |
| 10 | `10_learning_activity_pipeline.sql` | Creates learning-event recording and progress-processing objects |
| 11 | `11_analytics_views.sql` | Creates progress, domain and certification-readiness views |
| 12 | `12_rbac.sql` | Creates functional roles and grants for existing platform objects |
| 13 | `13_learner_information_pipeline.sql` | Creates the learner-information CSV pipeline |
| 14 | `14_learner_progress_pipeline.sql` | Creates the learner-progress CSV pipeline |
| 15 | `15_pod_nomination_dynamic_plan.sql` | Creates Pod, nomination and learner-specific dynamic-plan objects |
| 16 | `16_pod_nomination_pipeline.sql` | Creates the nomination inbox, Stream, processing procedure and Task |
| 17 | `17_weekly_progress_reminders.sql` | Creates reminder configuration, candidate view, procedure, log and weekly Task |

## Deployment Rules

Before execution:

1. Use a development Snowflake account.
2. Review the role, warehouse, database and schema names.
3. Confirm that required privileges are available.
4. Check account-specific notification and security settings.
5. Do not enable live email sending during initial deployment.
6. Do not automatically resume Tasks until the supporting objects are verified.

For full instructions, see the [Deployment Guide](../docs/deployment-guide.md).

## Earlier and Newer Workflows

The repository currently contains two learner-planning approaches:

### Earlier fixed-path workflow

The earlier workflow uses Snowflake experience to select a predefined learning-path duration. Its main implementation is contained in scripts `08` through `10`, with CSV support in scripts `13` and `14`.

### Newer Pod nomination workflow

The newer workflow accepts a Pod Lead nomination and generates a learner-specific plan using the enrollment period and target completion date. Its main implementation is contained in scripts `15` and `16`.

Both workflows currently remain in the repository. Do not remove the earlier workflow until the replacement approach is approved and migration impacts are understood.

## Task Safety

- Tasks should remain suspended when automatic processing is not required.
- Confirm Stream and procedure behavior manually before resuming Tasks.
- Keep reminder sending in simulation mode until recipient eligibility is verified.
- Suspend development Tasks after testing to limit credit usage.

## Validation After Deployment

After deploying the SQL files:

1. Confirm that the warehouse, database and four schemas exist.
2. Confirm that tables, views, procedures, Streams and Tasks were created.
3. Run the tests under `../tests` in numerical order.
4. Review rejected records and pipeline-run logs.
5. Confirm that demonstration data does not contain real employee information.
6. Review role grants for objects introduced by scripts `15`, `16` and `17`.

## Change Guidelines

When adding or changing SQL:

- Preserve the dependency order.
- Prefer idempotent DDL where appropriate.
- Document new procedures and Tasks in `docs/procedure-catalog.md`.
- Update deployment and testing documentation.
- Add a corresponding validation query or test.
- Test changes on a feature branch and in a development account before merging.
