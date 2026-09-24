# Snowflake Certification Enablement Platform — Demo Guide

## 1. Demo Objective

The purpose of this demo is to show how the platform provides structured SnowPro Core certification preparation for learners with different levels of Snowflake experience.

The platform:

- Assigns different learning timelines.
- Continuously loads and validates study topics.
- Registers and enrolls learners.
- Tracks topic-level progress.
- Processes learning activities automatically.
- Calculates certification readiness.
- Applies role-based access control.
- Runs data-quality checks.

---

## 2. Recommended Demo Duration

The complete demo can be presented in approximately 10–12 minutes.

| Section | Suggested time |
|---|---:|
| Introduction | 1 minute |
| Repository structure | 1 minute |
| Learning paths and topics | 2 minutes |
| Data pipeline | 2 minutes |
| Learner registration and progress | 2 minutes |
| Analytics and readiness | 2 minutes |
| Security, testing and conclusion | 2 minutes |

---

## 3. Important Presentation Approach

The project source files must be presented from Git or VS Code.

Snowsight should only be used briefly to execute prepared SQL and display results if a live result is required.

Do not use personal employee information during the demo.

---

## 4. Introduction

Suggested explanation:

> This project is called the Snowflake Certification Enablement Platform. It provides a reusable learning framework for employees preparing for the SnowPro Core certification. The learning timeline is assigned based specifically on each learner's Snowflake experience.

The four learning paths are:

| Experience level | Duration | Weekly hours |
|---|---:|---:|
| Fresher | 12 weeks | 8 |
| 0–5 years | 10 weeks | 7 |
| 5–9 years | 8 weeks | 6 |
| 9+ years | 6 weeks | 5 |

---

## 5. Repository Walkthrough

Open the project in VS Code and show:

```text
data/
docs/
sql/
tests/
README.md
```

Explain:

- `data` contains the study-topic CSV.
- `sql` contains all Snowflake implementation scripts.
- `tests` contains repeatable validation queries.
- `docs` contains deployment and demo instructions.
- `README.md` explains the complete project.

Suggested statement:

> All project code, test files and documentation are maintained in Git. Snowflake is used to execute the code and store the deployed objects.

---

## 6. Foundation Data

Show these files:

```text
sql/02_reference_tables.sql
sql/04_seed_foundation_data.sql
data/study_topics.csv
```

Explain:

- One SnowPro Core certification is configured.
- Five exam domains are configured.
- The domain weights total 100%.
- Four experience-based learning paths are available.
- Thirty-one study topics are included.

Suggested statement:

> The learning content is data-driven. New topics or updated study plans can be introduced through the ingestion pipeline instead of changing the application logic.

---

## 7. Study-Topic Pipeline

Show:

```text
sql/05_raw_ingestion_setup.sql
sql/06_load_study_topics.sql
sql/07_study_topics_pipeline.sql
```

Explain the flow:

```text
CSV
  → Internal Stage
  → RAW Inbox
  → Stream
  → Validation Procedure
  → CORE or Rejected Records
```

Important points:

- A Stream detects new RAW records.
- A Task runs the processing procedure.
- Valid records move into `CORE.STUDY_TOPICS`.
- Invalid records move into `CONTROL.REJECTED_RECORDS`.
- Each pipeline execution is logged.

Suggested statement:

> This provides continuous processing. New study-topic data can be loaded later, and only the newly added or changed records are processed.

---

## 8. Learner Registration

Show:

```text
sql/08_learner_registration.sql
```

Explain:

1. The procedure receives learner information.
2. It evaluates Snowflake experience.
3. It assigns the correct learning path.
4. It calculates completion and exam target dates.
5. It creates the enrollment.
6. It assigns all 31 study topics.
7. Running the procedure again does not create duplicates or reset progress.

Do not show an actual learner's employee ID or email.

Suggested statement:

> Learner registration and Snowflake security access are separate. Registration creates the learning record, while a Snowflake administrator separately assigns the appropriate access role.

---

## 9. Weekly Study Schedules

Show:

```text
sql/09_learning_schedule.sql
```

Explain:

- All paths cover the same 31 topics.
- The topics are distributed across different durations.
- Fresher learners receive a 12-week schedule.
- Experienced learners receive shorter schedules.
- Recommended hours are calculated for every topic.

Suggested statement:

> The certification syllabus remains consistent, but the pace changes based on Snowflake experience.

---

## 10. Learning-Activity Pipeline

Show:

```text
sql/10_learning_activity_pipeline.sql
```

Explain:

```text
Learning Activity
  → Learning Events
  → Stream
  → Task
  → Topic Progress
```

Important points:

- Learners can record study duration and completion percentage.
- A Stream detects the new learning event.
- The scheduled Task processes the activity.
- Topic status changes from `NOT_STARTED` to `IN_PROGRESS` or `COMPLETED`.
- Study hours and activity timestamps are updated.

Example tested result:

- Initial study activity: 30 minutes and 25% completion.
- Completion activity: 45 minutes and 100% completion.
- Final result: `COMPLETED`, `100%`, and `1.25` total hours.

---

## 11. Analytics and Readiness

Show:

```text
sql/11_analytics_views.sql
```

The four views are:

| View | Purpose |
|---|---|
| `V_WEEKLY_STUDY_PLAN` | Displays the weekly learning schedule |
| `V_LEARNER_PROGRESS` | Shows overall progress and hours |
| `V_DOMAIN_PROGRESS` | Shows progress across exam domains |
| `V_CERTIFICATION_READINESS` | Shows readiness score and recommendation |

Explain the readiness calculation:

- Before an assessment, readiness is based on weighted learning progress.
- After an assessment, the score uses:
  - 60% weighted learning progress
  - 40% latest assessment score

Mention that the readiness score is an internal learning indicator and not a guarantee of exam success.

---

## 12. Security

Show:

```text
sql/12_rbac.sql
```

Explain the roles:

| Role | Access |
|---|---|
| `SNOWPRO_LEARNER` | View study plans and record activities |
| `SNOWPRO_PROGRAM_MANAGER` | Register learners, maintain assessments and view analytics |
| `SNOWPRO_PLATFORM_ADMIN` | Manage the complete platform |

Suggested statement:

> Users receive only the access required for their responsibilities. Real usernames are assigned to roles separately and are not committed to Git.

---

## 13. Data-Quality Testing

Show:

```text
tests/01_study_topics_pipeline_test.sql
tests/02_platform_data_quality_tests.sql
```

Explain:

- Pipeline testing verifies valid and rejected records.
- Platform testing checks the full CORE data.
- Twelve platform checks were executed.
- All twelve checks returned `PASS`.

The tests include:

- Domain-weight validation.
- Learning-path validation.
- Topic-assignment checks.
- Progress-value validation.
- Duplicate detection.
- Orphan-record detection.
- Assessment-score validation.
- Experience and path matching.

---

## 14. Key Snowflake Features Used

- Virtual warehouse
- Databases and schemas
- Tables and views
- Internal stage
- CSV file format
- `COPY INTO`
- Streams
- Tasks
- SQL stored procedures
- `MERGE`
- Role-based access control
- Future grants
- Analytics views
- Data-quality SQL tests

---

## 15. Key Learnings

Suggested explanation:

> Through this project, I learned how to structure a Snowflake solution using RAW, CORE, CONTROL and ANALYTICS layers. I also learned how Streams and Tasks support continuous processing, how stored procedures provide reusable business logic, how MERGE prevents duplicates, and how roles control access. I also understood that data validation is needed both before data enters CORE and after processing through repeatable quality checks.

---

## 16. Current Limitations

- Learner registration currently uses a stored-procedure call.
- Assessment entry currently uses SQL.
- Timelines may need adjustment after feedback from experienced learners.
- The readiness calculation is an internal indicator.
- Streamlit is not included in the current phase.

---

## 17. Future Enhancement

After approval, a Streamlit application can provide:

- Learner self-registration.
- Personalized weekly study plans.
- Progress-update forms.
- Assessment entry.
- Readiness dashboards.
- Role-based pages.

---

## 18. Closing Statement

Suggested conclusion:

> The current implementation provides the complete Snowflake backend for a reusable SnowPro Core learning platform. It supports experience-based schedules, continuous data processing, progress tracking, analytics, security and data-quality checks. The next possible phase is to add a Streamlit interface after receiving approval.