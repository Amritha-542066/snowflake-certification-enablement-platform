# Snowflake Certification Enablement Platform

## CSV Upload Guide

## 1. Purpose

This document explains how to prepare, upload, validate and correct the CSV files used by the Snowflake Certification Enablement Platform.

The current prototype uses manual CSV uploads. The future roadmap is to connect the approved Mastech Excel source directly to the Snowflake RAW layer.

---

## 2. Supported CSV Files

The current dynamic nomination flow uses these files:

1. `pods.csv`
2. `certification_nominations.csv`
3. `learner_progress.csv`

The files must be processed in this order because the Pod must exist before a Pod Lead can nominate an employee.

The older `learner_information.csv` file is retained for backward compatibility. New dynamic enrollments should use `certification_nominations.csv`.

---

## 3. Common File Requirements

All CSV files must follow these rules:

- File type must be `.csv`.
- The first row must contain column headings.
- Column names and column order must match the provided templates.
- Values must be separated using commas.
- Text encoding should be UTF-8.
- Dates must use `YYYY-MM-DD`.
- Timestamps must use `YYYY-MM-DD HH24:MI:SS`.
- Do not change or remove required columns.
- Do not add commas inside values unless the value is enclosed in double quotes.
- Do not include passwords, tokens or credentials.
- Real employee data must not be committed to Git.
- Git should contain only templates and safe demonstration data.

---

## 4. Pod Configuration Upload

### File Name

```text
pods.csv
```

### Template Location

```text
data/pods.csv
```

### Required Columns

| Column | Required | Format | Description |
|---|---:|---|---|
| `POD_ID` | Yes | Text | Unique ID for the Pod |
| `POD_NAME` | Yes | Text | Name of the Pod |
| `POD_LEAD_EMPLOYEE_ID` | Yes | Text | Employee ID of the authorised Pod Lead |
| `POD_LEAD_NAME` | Yes | Text | Name of the Pod Lead |
| `POD_LEAD_EMAIL` | Yes | Email | Corporate email address of the Pod Lead |
| `ACTIVE_FLAG` | Yes | `TRUE` or `FALSE` | Indicates whether the Pod is active |

### Example

```csv
POD_ID,POD_NAME,POD_LEAD_EMPLOYEE_ID,POD_LEAD_NAME,POD_LEAD_EMAIL,ACTIVE_FLAG
POD_001,Snowflake Data Engineering,LEAD_DEMO_001,Demo Pod Lead,podlead@example.com,TRUE
```

### Validation Rules

- Pod ID cannot be empty.
- Pod name cannot be empty.
- Pod Lead employee ID cannot be empty.
- Pod Lead name cannot be empty.
- Pod Lead email must have a valid email format.
- Active flag must be `TRUE` or `FALSE`.

---

## 5. Certification Nomination Upload

### File Name

```text
certification_nominations.csv
```

### Template Location

```text
data/certification_nominations.csv
```

### Required Columns

| Column | Required | Format | Description |
|---|---:|---|---|
| `SOURCE_RECORD_ID` | Yes | Text | Unique ID used to track and correct the record |
| `EMPLOYEE_ID` | Yes | Text | Employee being nominated |
| `LEARNER_NAME` | Yes | Text | Name of the employee |
| `EMAIL` | Yes | Email | Employee's corporate email address |
| `DEPARTMENT_NAME` | No | Text | Employee's department |
| `SNOWFLAKE_EXPERIENCE_YEARS` | Yes | Number, zero or greater | Stored for reference only |
| `POD_ID` | Yes | Text | Pod to which the employee belongs |
| `POD_LEAD_EMPLOYEE_ID` | Yes | Text | Employee ID of the recommending Pod Lead |
| `CERTIFICATION_ID` | Yes | Text | Certification being recommended |
| `TARGET_COMPLETION_DATE` | Yes | `YYYY-MM-DD` | Date supplied by the Pod Lead |
| `TARGET_EXAM_DATE` | Yes | `YYYY-MM-DD` | Planned certification-exam date |
| `NOMINATION_REASON` | No | Text | Reason for the recommendation |

### Example

```csv
SOURCE_RECORD_ID,EMPLOYEE_ID,LEARNER_NAME,EMAIL,DEPARTMENT_NAME,SNOWFLAKE_EXPERIENCE_YEARS,POD_ID,POD_LEAD_EMPLOYEE_ID,CERTIFICATION_ID,TARGET_COMPLETION_DATE,TARGET_EXAM_DATE,NOMINATION_REASON
NOM_DEMO_001,EMP_DEMO_101,Asha Rao,asha.rao@example.com,Data Engineering,1.5,POD_001,LEAD_DEMO_001,CERT_SNOWPRO_CORE,2026-12-15,2026-12-22,Recommended by Pod Lead
```

### Validation Rules

- Source record ID must be provided.
- Employee ID must be provided.
- Learner name must be provided.
- Email must have a valid format.
- Snowflake experience must be a number equal to or greater than zero.
- Pod ID must exist and must be active.
- Pod Lead employee ID must match the authorised lead of the Pod.
- Certification ID must exist and must be active.
- Target completion date must be in the future.
- Target exam date cannot be earlier than the target completion date.

### Dynamic Schedule

Snowflake experience does not select a fixed learning path.

The system calculates the available study weeks using:

```text
Current date → Pod Lead's target completion date
```

Active certification topics are then distributed across those weeks for the individual learner.

---

## 6. Learner Progress Upload

### File Name

```text
learner_progress.csv
```

### Template Location

```text
data/learner_progress.csv
```

### Required Columns

| Column | Required | Format | Description |
|---|---:|---|---|
| `ACTIVITY_ID` | Yes | Text | Unique learning-activity ID |
| `EMPLOYEE_ID` | Yes | Text | Employee whose progress is being updated |
| `TOPIC_ID` | Yes | Text | Certification topic being updated |
| `EVENT_TYPE` | Yes | `STARTED`, `STUDIED` or `COMPLETED` | Type of learning activity |
| `ACTIVITY_TIMESTAMP` | Yes | `YYYY-MM-DD HH24:MI:SS` | Time of the activity |
| `DURATION_MINUTES` | Yes | Number, zero or greater | Time spent studying |
| `COMPLETION_PERCENT` | Yes | Number from 0 to 100 | Current completion percentage |
| `NOTES` | No | Text | Optional learner notes |

### Validation Rules

- Activity ID must be unique.
- Employee must be registered and actively enrolled.
- Topic ID must exist in the learner's study plan.
- Event type must be supported.
- Activity timestamp must use the required format.
- Duration cannot be negative.
- Completion percentage must be between 0 and 100.
- A completed event should normally have 100% completion.

---

## 7. Upload Location

Upload the CSV files to this Snowflake internal stage:

```text
@DB_CERT_ENABLEMENT_DEV.RAW.INT_RAW_CERTIFICATION_UPLOAD_DEV
```

### Upload Through Snowsight

1. Sign in to Snowsight.
2. Open the `DB_CERT_ENABLEMENT_DEV` database.
3. Open the `RAW` schema.
4. Open **Stages**.
5. Select `INT_RAW_CERTIFICATION_UPLOAD_DEV`.
6. Select **Upload files**.
7. Choose the required CSV file.
8. Complete the upload.
9. Run the following command to verify the uploaded file:

```sql
LIST @DB_CERT_ENABLEMENT_DEV.RAW.INT_RAW_CERTIFICATION_UPLOAD_DEV;
```

---

## 8. Processing Order

### Step 1: Pod Configuration

Upload and load `pods.csv`.

The Pod information is validated and stored in:

```text
CORE.PODS
```

### Step 2: Certification Nomination

Upload and load `certification_nominations.csv`.

The pipeline performs the following actions:

1. Validates the CSV structure.
2. Confirms that the Pod exists.
3. Confirms that the Pod is active.
4. Confirms that the supplied employee is the authorised Pod Lead.
5. Confirms that the certification exists.
6. Creates or updates the learner.
7. Records the employee's Pod membership.
8. Creates the certification nomination.
9. Creates the certification enrollment.
10. Calculates the dynamic study duration.
11. Distributes active topics across the available weeks.
12. Initializes learner-topic progress.

### Step 3: Learner Progress

Upload and load `learner_progress.csv`.

The learner-progress pipeline updates:

- Progress status
- Completion percentage
- Study hours
- Started timestamp
- Completed timestamp
- Last activity timestamp

---

## 9. Loading Pod Data

After uploading `pods.csv`, run the Pod `COPY INTO` statement from:

```text
sql/16_pod_nomination_pipeline.sql
```

The data is first loaded into:

```text
RAW.POD_CONFIGURATION_INBOX
```

A Snowflake Stream detects the newly loaded rows.

The processing procedure validates the records and loads valid Pod information into:

```text
CORE.PODS
```

---

## 10. Loading Certification Nominations

After uploading `certification_nominations.csv`, run the nomination `COPY INTO` statement from:

```text
sql/16_pod_nomination_pipeline.sql
```

The data is first loaded into:

```text
RAW.CERTIFICATION_NOMINATIONS_INBOX
```

A Snowflake Stream detects newly loaded nominations.

The processing Task calls:

```text
CONTROL.SP_PROCESS_CERT_ENABLEMENT_NOMINATIONS
```

The procedure validates the nomination and calls:

```text
CONTROL.SP_NOMINATE_CERT_ENABLEMENT_LEARNER
```

The valid nomination is stored in the CORE tables.

---

## 11. Loading Learner Progress

After uploading `learner_progress.csv`, run the learner-progress `COPY INTO` statement from:

```text
sql/14_learner_progress_pipeline.sql
```

The data is loaded into:

```text
RAW.LEARNER_PROGRESS_INBOX
```

The learner-progress pipeline validates the record and updates the learner's progress.

---

## 12. Checking Pipeline Runs

Use the following query to check recent CSV pipeline executions:

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

A successful run should have:

```text
RUN_STATUS = SUCCESS
```

A run with zero received records is valid when the Stream contains no new data.

---

## 13. Checking Rejected Records

Rejected rows are stored in:

```text
CONTROL.CSV_REJECTED_RECORDS
```

Use:

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

---

## 14. Error-Correction Process

If a record is rejected:

1. Read the `REJECTION_REASON`.
2. Identify the original CSV file and source record.
3. Open the original CSV file.
4. Correct the invalid value.
5. Keep the same `SOURCE_RECORD_ID` when correcting a nomination.
6. Save the corrected data using a new file name.
7. Upload the corrected file to the internal stage.
8. Run the appropriate `COPY INTO` statement.
9. Allow the scheduled Task to process the row, or call the procedure manually.
10. Check that the corrected row reached the CORE tables.
11. Confirm that the earlier rejected record has `RESOLVED_FLAG = TRUE`.
12. Confirm that `RESOLVED_AT` contains a timestamp.

Using a new file name prevents Snowflake load history from skipping a corrected file that was previously loaded.

---

## 15. Example Nomination Errors

### Unauthorised Pod Lead

Example rejection:

```text
The supplied Pod Lead is not authorised for this Pod.
```

Correction:

- Check the Pod ID.
- Check the Pod Lead employee ID.
- Confirm the Pod is active.
- Upload the corrected nomination using the same source record ID.

### Invalid Completion Date

Example rejection:

```text
Target completion date must be in the future.
```

Correction:

- Enter a future completion date.
- Use `YYYY-MM-DD` format.

### Invalid Exam Date

Example rejection:

```text
Target exam date cannot be earlier than the target completion date.
```

Correction:

- Set the exam date on or after the target completion date.

### Invalid Experience Value

Example rejection:

```text
Snowflake experience must be zero or greater.
```

Correction:

- Enter zero or a positive number.
- Do not enter negative values or text.

### Invalid Progress Percentage

Example rejection:

```text
Completion percentage must be between 0 and 100.
```

Correction:

- Enter a value from 0 to 100.
- Upload the corrected progress file.

---

## 16. Weekly Email Reminders

The reminder system supports these modes:

### Inactive Learners Only

```text
REMINDER_MODE = INACTIVE_ONLY
```

Only learners who have not recorded progress within the configured number of days are selected.

### All Active Learners

```text
REMINDER_MODE = ALL_ACTIVE
```

Every learner with an active enrollment is selected.

### Simulation Mode

```text
SEND_ENABLED = FALSE
```

The system identifies reminder candidates and writes them to the reminder log. It does not send an email.

### Live Mode

```text
SEND_ENABLED = TRUE
```

The system attempts to send an email using the configured Snowflake email notification integration.

Live email should be enabled only after:

- The learner exists as a user in the Snowflake account.
- The learner's email address has been verified.
- The email notification integration has been tested.
- The company has approved live reminder emails.

The default configuration is:

```text
Reminder mode: INACTIVE_ONLY
Inactivity period: 7 days
Email sending: Disabled
Schedule: Every Monday at 9:00 AM India time
```

---

## 17. Checking Reminder Candidates

Use:

```sql
SELECT
    EMPLOYEE_ID,
    LEARNER_NAME,
    EMAIL,
    CERTIFICATION_ID,
    TARGET_COMPLETION_DATE,
    LAST_ACTIVITY_AT,
    DAYS_SINCE_LAST_ACTIVITY,
    REMINDER_MODE,
    SEND_ENABLED

FROM DB_CERT_ENABLEMENT_DEV.ANALYTICS.VW_WEEKLY_REMINDER_CANDIDATES

ORDER BY EMPLOYEE_ID;
```

---

## 18. Checking Reminder Results

Use:

```sql
SELECT
    REMINDER_ID,
    EMPLOYEE_ID,
    RECIPIENT_EMAIL,
    REMINDER_STATUS,
    FAILURE_MESSAGE,
    REMINDER_SENT_AT

FROM DB_CERT_ENABLEMENT_DEV.CONTROL.REMINDER_NOTIFICATION_LOG

ORDER BY REMINDER_SENT_AT DESC;
```

Possible statuses are:

| Status | Meaning |
|---|---|
| `SIMULATED` | Learner was identified, but no email was sent |
| `SENT` | Snowflake submitted the email successfully |
| `FAILED` | Snowflake could not send the email |

---

## 19. Data Security Guidelines

- Do not commit real employee records to Git.
- Do not include passwords, tokens or secrets in CSV files.
- Keep only demonstration records and templates in Git.
- Upload real operational files directly to the approved Snowflake stage.
- Use corporate email addresses only.
- Limit stage and table access through Snowflake roles.
- Verify rejected records do not expose unnecessary sensitive data.
- Follow company retention and deletion requirements.

---

## 20. Future Roadmap

The current prototype uses manually uploaded CSV files.

The planned production flow is:

```text
Approved Mastech Excel source
→ Automated ingestion pipeline
→ Snowflake RAW layer
→ Validation
→ CORE tables
→ Dynamic learner plan
→ Progress tracking
→ Weekly reminders
```

Future improvements may include:

- Direct connection to the approved Mastech employee and Pod source.
- Automatic Pod and employee synchronization.
- Support for additional Snowflake certifications.
- Configurable certification topics.
- Configurable reminder schedules.
- Pod Lead approval workflow.
- Notification escalation for overdue learners.
- Dashboard or Streamlit interface.
- Central monitoring and operational alerts.