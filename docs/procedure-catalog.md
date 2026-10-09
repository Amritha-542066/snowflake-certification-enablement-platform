# Stored Procedure and Task Catalogue

## 1. Study-Topic Pipeline

### `CONTROL.SP_PROCESS_CERT_ENABLEMENT_STUDY_TOPICS()`

**Called by:** `CONTROL.TSK_PROCESS_STUDY_TOPICS_1MIN`

**Purpose:**

- Reads newly inserted RAW topic records.
- Validates topic ID, domain ID, domain existence, topic name, difficulty, estimated hours and topic order.
- Stores invalid records with rejection reasons.
- Merges valid topics into `CORE.STUDY_TOPICS`.
- Records the pipeline result.

**Task status in deployment script:** Explicitly resumed.

## 2. Fixed-Path Learner Registration

### `CONTROL.SP_REGISTER_CERT_ENABLEMENT_LEARNER(...)`

**Purpose:**

- Validates employee information and experience.
- Selects an experience level and fixed learning path.
- Creates or updates the learner.
- Creates or updates the enrollment.
- Initializes topic progress from `PATH_TOPIC_PLAN`.

**Architecture note:** This belongs to the older fixed-path workflow. Its future role must be confirmed.

## 3. Learning Activity Recording

### `CONTROL.SP_RECORD_CERT_ENABLEMENT_LEARNING_ACTIVITY(...)`

**Purpose:**

- Confirms the topic is assigned to the enrollment.
- Validates event type, duration and completion percentage.
- Inserts a learning event into `CORE.LEARNING_EVENTS`.

## 4. Learning-Event Processing

### `CONTROL.SP_PROCESS_CERT_ENABLEMENT_LEARNING_EVENTS()`

**Called by:** `CONTROL.TSK_PROCESS_LEARNING_EVENTS_5MIN`

**Purpose:**

- Reads new events from `CORE.STR_LEARNING_EVENTS`.
- Aggregates additional hours and completion percentage.
- Updates `CORE.TOPIC_PROGRESS`.
- Sets started, completed and last-activity timestamps.

**Task status in deployment script:** Explicitly resumed.

## 5. Learner-Information CSV Pipeline

### `CONTROL.SP_PROCESS_CERT_ENABLEMENT_LEARNER_INFORMATION()`

**Called by:** `CONTROL.TSK_PROCESS_LEARNER_INFORMATION_1MIN`

**Purpose:**

- Reads new learner-information inbox records.
- Validates required values, email and experience.
- Rejects duplicate or previously processed source IDs.
- Calls the fixed-path learner-registration procedure for valid rows.
- Records accepted, rejected and failed counts.

**Task status in deployment script:** Created suspended for testing.

## 6. Learner-Progress CSV Pipeline

### `CONTROL.SP_PROCESS_CERT_ENABLEMENT_LEARNER_PROGRESS()`

**Called by:** `CONTROL.TSK_PROCESS_LEARNER_PROGRESS_1MIN`

**Purpose:**

- Reads new progress-inbox records.
- Validates event, duration, percentage and timestamp values.
- Resolves the employee's active enrollment.
- Confirms that the topic is assigned.
- Inserts valid records into `CORE.LEARNING_EVENTS`.
- Stores rejected records and run results.

**Task status in deployment script:** Created suspended for testing.

## 7. Dynamic Nomination Business Procedure

### `CONTROL.SP_NOMINATE_CERT_ENABLEMENT_LEARNER(...)`

**Called by:** `CONTROL.SP_PROCESS_CERT_ENABLEMENT_NOMINATIONS()`

**Purpose:**

- Validates required nomination inputs.
- Resolves and validates the Pod and Pod Lead.
- Resolves and validates the certification.
- Confirms active topics exist for the certification.
- Creates or updates the employee.
- Creates or updates Pod membership.
- Creates or updates the certification nomination.
- Creates or updates the dynamic enrollment.
- Generates the learner-specific topic plan.
- Initializes missing progress records without deleting existing progress.

## 8. Nomination CSV Pipeline

### `CONTROL.SP_PROCESS_CERT_ENABLEMENT_NOMINATIONS()`

**Called by:** `CONTROL.TSK_PROCESS_CERT_NOMINATIONS_1MIN`

**Purpose:**

- Reads and standardizes incoming nomination rows.
- Validates required fields, email, experience and date format.
- Calls the dynamic nomination business procedure for structurally valid rows.
- Stores rejected rows with a business-readable reason.
- Records pipeline execution counts and status.

**Task status in deployment script:** Created suspended for controlled testing.

## 9. Reminder Procedure

### `CONTROL.SP_SEND_CERT_ENABLEMENT_PROGRESS_REMINDERS()`

**Called by:** `CONTROL.TSK_SEND_PROGRESS_REMINDERS_WEEKLY`

**Purpose:**

- Reads eligible learner and Pod Lead recipients.
- Creates recipient-specific reminder content.
- Logs simulated reminders when sending is disabled.
- Sends and audits email when sending is enabled.
- Records individual failures without ending the complete run.

**Task status in deployment script:** Created suspended.

## 10. Task Summary

| Task | Schedule | Script state |
|---|---|---|
| `TSK_PROCESS_STUDY_TOPICS_1MIN` | Every minute when stream has data | Resumed |
| `TSK_PROCESS_LEARNING_EVENTS_5MIN` | Every five minutes when stream has data | Resumed |
| `TSK_PROCESS_LEARNER_INFORMATION_1MIN` | Every minute when stream has data | Suspended |
| `TSK_PROCESS_LEARNER_PROGRESS_1MIN` | Every minute when stream has data | Suspended |
| `TSK_PROCESS_CERT_NOMINATIONS_1MIN` | Every minute when stream has data | Suspended |
| `TSK_SEND_PROGRESS_REMINDERS_WEEKLY` | Monday 9:00 AM Asia/Kolkata | Suspended |

Task state should be verified in the target account before presentation because deployment scripts and current account state may differ.

