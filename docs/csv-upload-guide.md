# Snowflake Certification Enablement Platform

## CSV Upload Guide

## 1. Purpose

This guide explains how to prepare, upload, validate and correct the CSV files used by the prototype.

The current prototype uses manual CSV uploads. Real employee data must be handled only through an approved company source and must not be committed to Git.

## 2. Supported CSV Files

The current workflow uses:

1. `certification_nominations.csv` for Pod Lead nominations and dynamic learning plans.
2. `learner_progress.csv` for ongoing learner progress updates.

The older `learner_information.csv` is retained only for backward compatibility. The separate `pods.csv` input is no longer required. Approved Pod and Pod Lead configuration is maintained inside Snowflake.

## 3. Common File Requirements

- Use the `.csv` file type.
- Use UTF-8 encoding.
- Keep the provided headings and column order.
- Separate values with commas.
- Use `YYYY-MM-DD` for dates.
- Use `YYYY-MM-DD HH24:MI:SS` for timestamps.
- Do not add passwords, tokens or credentials.
- Do not commit real employee data to Git.
- Use a new file name when uploading a corrected file so Snowflake load history does not skip it.

## 4. Certification Nomination File

### File and template

```text
data/certification_nominations.csv
```

### Required columns

| Column | Required | Format | Description |
|---|---:|---|---|
| `EMPLOYEE_ID` | Yes | Text | Stable company employee identifier |
| `LEARNER_NAME` | Yes | Text | Employee name |
| `EMAIL` | Yes | Email | Employee email address |
| `DEPARTMENT_NAME` | No | Text | Employee department |
| `SNOWFLAKE_EXPERIENCE_YEARS` | Yes | Number, zero or greater | Profile information used by the Pod Lead when choosing a date |
| `POD_NAME` | Yes | Text | Approved Pod name |
| `POD_LEAD_NAME` | Yes | Text | Authorized Pod Lead name |
| `CERTIFICATION_NAME` | Yes | Text | Active certification name stored in Snowflake |
| `TARGET_COMPLETION_DATE` | Yes | `YYYY-MM-DD` | Completion date agreed by the Pod Lead and employee |

### Example

```csv
EMPLOYEE_ID,LEARNER_NAME,EMAIL,DEPARTMENT_NAME,SNOWFLAKE_EXPERIENCE_YEARS,POD_NAME,POD_LEAD_NAME,CERTIFICATION_NAME,TARGET_COMPLETION_DATE
EMP_DEMO_101,Asha Rao,asha.rao@example.com,Data Engineering,1.5,Snowflake Data Engineering,Durga Rajaneesh Maturu,SnowPro Core Certification,2026-12-15
```

### Information not entered by the user

Snowflake resolves or generates these values internally:

- Pod ID
- Pod Lead employee ID
- Certification ID
- Learner ID
- Nomination ID
- Enrollment ID
- Source record ID for rejection tracking
- Target exam date, calculated as seven days after completion

### Validation rules

- Employee ID, learner name and email are required.
- Email must use a valid format.
- Snowflake experience must be zero or greater.
- Pod name must match an active Pod stored in Snowflake.
- Pod Lead name must match the authorized lead of that Pod.
- Certification name must match an active certification stored in Snowflake.
- Target completion date must be a valid future date.
- Names are trimmed and repeated spaces are removed.
- Email addresses are converted to lowercase.

### Dynamic schedule behavior

For a new learner, the processing date becomes the enrollment and plan start date.

For an existing learner, the original enrollment date is preserved when the target completion date changes. The schedule is recalculated without creating a duplicate learner or enrollment, and existing topic progress is preserved.

All active certification topics are distributed between the plan start date and the Pod Lead's target completion date.

## 5. Learner Progress File

### File and template

```text
data/learner_progress.csv
```

### Required columns

| Column | Required | Format | Description |
|---|---:|---|---|
| `ACTIVITY_ID` | Yes | Text | Unique activity identifier |
| `EMPLOYEE_ID` | Yes | Text | Enrolled employee |
| `TOPIC_ID` | Yes | Text | Assigned certification topic |
| `EVENT_TYPE` | Yes | `STARTED`, `STUDIED` or `COMPLETED` | Activity type |
| `ACTIVITY_TIMESTAMP` | Yes | `YYYY-MM-DD HH24:MI:SS` | Activity time |
| `DURATION_MINUTES` | Yes | Number, zero or greater | Study time |
| `COMPLETION_PERCENT` | Yes | Number from 0 to 100 | Topic completion |
| `NOTES` | No | Text | Optional notes |

### Validation rules

- Activity ID must be unique.
- Employee must have an active enrollment.
- Topic must be assigned to the learner.
- Event type must be supported.
- Duration cannot be negative.
- Completion percentage must be between 0 and 100.

## 6. Upload Location

Upload files to:

```text
@DB_CERT_ENABLEMENT_DEV.RAW.INT_RAW_CERTIFICATION_UPLOAD_DEV
```

### Snowsight steps

1. Open `DB_CERT_ENABLEMENT_DEV`.
2. Open the `RAW` schema.
3. Open **Stages**.
4. Select `INT_RAW_CERTIFICATION_UPLOAD_DEV`.
5. Select **Upload files**.
6. Choose the CSV file and complete the upload.
7. Verify the stage:

```sql
LIST @DB_CERT_ENABLEMENT_DEV.RAW.INT_RAW_CERTIFICATION_UPLOAD_DEV;
```

## 7. Load and Process Nominations

Use the `COPY INTO` command provided in:

```text
sql/16_pod_nomination_pipeline.sql
```

The flow is:

```text
certification_nominations.csv
→ Internal stage
→ RAW.CERTIFICATION_NOMINATIONS_INBOX
→ RAW.STR_CERTIFICATION_NOMINATIONS_INBOX
→ CONTROL.SP_PROCESS_CERT_ENABLEMENT_NOMINATIONS
→ Validation and standardization
→ CORE learner, nomination, enrollment and topic-plan tables
→ Pipeline run log or rejected-record log
```

The Task `CONTROL.TSK_PROCESS_CERT_NOMINATIONS_1MIN` may be resumed during active testing and suspended afterward.

## 8. Load and Process Progress

Use the `COPY INTO` and processing commands provided in:

```text
sql/14_learner_progress_pipeline.sql
```

Valid progress updates learning events, topic status, completion percentage, study hours and activity timestamps.

## 9. Check Pipeline Runs

```sql
SELECT
    PIPELINE_NAME,
    RUN_STATUS,
    RECORDS_RECEIVED,
    RECORDS_ACCEPTED,
    RECORDS_REJECTED,
    RUN_MESSAGE,
    STARTED_AT,
    COMPLETED_AT
FROM DB_CERT_ENABLEMENT_DEV.CONTROL.CSV_PIPELINE_RUN_LOG
ORDER BY STARTED_AT DESC;
```

## 10. Check and Correct Rejected Records

```sql
SELECT
    PIPELINE_NAME,
    SOURCE_RECORD_ID,
    SOURCE_FILE_NAME,
    REJECTION_REASON,
    RESOLVED_FLAG,
    REJECTED_AT,
    RESOLVED_AT
FROM DB_CERT_ENABLEMENT_DEV.CONTROL.CSV_REJECTED_RECORDS
ORDER BY REJECTED_AT DESC;
```

Correction process:

1. Read the rejection reason.
2. Correct the business value in the CSV.
3. Save the correction using a new file name.
4. Upload and load the corrected file.
5. Run the procedure or allow the Task to process it.
6. Confirm that the record reached CORE and the earlier rejection was resolved.

## 11. Weekly Reminder Verification

The reminder system normally selects learners whose progress has not been updated for seven days. For every eligible enrollment it prepares:

- One learner reminder.
- One Pod Lead follow-up reminder.

The Pod Lead email is retrieved from `CORE.PODS`; it is not entered in each nomination CSV.

Simulation mode is the safe default:

```text
REMINDER_MODE = INACTIVE_ONLY
INACTIVITY_DAYS = 7
SEND_ENABLED = FALSE
```

Check reminder results:

```sql
SELECT
    EMPLOYEE_ID,
    RECIPIENT_TYPE,
    RECIPIENT_NAME,
    RECIPIENT_EMAIL,
    REMINDER_STATUS,
    FAILURE_MESSAGE,
    REMINDER_SENT_AT
FROM DB_CERT_ENABLEMENT_DEV.CONTROL.REMINDER_NOTIFICATION_LOG
ORDER BY REMINDER_SENT_AT DESC;
```

Live email must be enabled only when both learner and Pod Lead addresses belong to eligible, verified Snowflake users in the same account.

## 12. Security Guidelines

- Keep real employee data out of Git.
- Never place secrets or credentials in CSV files.
- Use approved corporate sources and email addresses.
- Restrict stages, tables and procedures using Snowflake roles.
- Keep scheduled Tasks suspended when automatic processing is not required.

## 13. Future Roadmap

- Replace manual CSV upload with the approved company source.
- Provide existing records back to Pod Leads for controlled updates.
- Support additional Snowflake certifications.
- Add optional refresher and recertification plans.
- Allow Pod Lead-approved topic exclusions with an audit trail.
- Add dashboards, escalation rules and operational monitoring.
