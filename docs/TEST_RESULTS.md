# Snowflake Certification Enablement Platform

## Test Results

## 1. Test Information

| Item | Value |
|---|---|
| Tested by | Amritha Kalyanasundaram Ganesh |
| Test period | 24–29 September 2026 |
| Environment | Development |
| Snowflake account | Trial account |
| Database | DB_CERT_ENABLEMENT_DEV |
| Warehouse | WH_CERT_ENABLEMENT_DEV_XS |
| Git branch | feature/pod-dynamic-plan-reminders |

## 2. Testing Objective

The purpose of testing was to confirm that the platform can:

- Store Snowflake certification topics and learning resources.
- Register learners.
- Track learner progress.
- Process learner and progress CSV files.
- Validate incoming records.
- Store invalid records with a rejection reason.
- Support Pod Lead certification nominations.
- Create dynamic learning plans.
- Record pipeline execution results.
- Prepare weekly progress reminders.
- Apply the approved Snowflake object-naming standards.

## 3. Foundation Data Testing

### 3.1 Certification Data

The platform was tested to confirm that the SnowPro Core certification information was available.

Expected result:

- The SnowPro Core certification should be active.

Result:

- Certification data was available successfully.

Status: **PASS**

### 3.2 Exam Domains

The certification topics were grouped under five exam domains.

Expected result:

- Five exam domains should be available.

Result:

- All five exam domains were available.

Status: **PASS**

### 3.3 Study Topics

The study-topic data was loaded from `data/study_topics.csv`.

Expected result:

- 31 active study topics should be available.
- Every topic should belong to a valid domain.
- Required fields should not be empty.

Result:

- 31 active study topics were loaded successfully.
- The topics were distributed across five domains.

Status: **PASS**

### 3.4 Original Experience-Based Paths

The original prototype contained the following learning paths:

| Experience category | Original duration |
|---|---:|
| Fresher | 12 weeks |
| 0–5 years | 10 weeks |
| 5–9 years | 8 weeks |
| 9+ years | 6 weeks |

These paths were tested successfully during the first version of the prototype.

Following feedback, the new nomination workflow no longer depends on these fixed durations. The Pod Lead now provides the learner’s target dates, and the platform creates a dynamic schedule.

Status: **PASS**

## 4. Study-Topic Pipeline Testing

The study-topic pipeline was tested to confirm that new RAW records could be validated and processed into the CORE schema.

The pipeline contains:

- A RAW inbox table.
- A Snowflake Stream.
- A processing stored procedure.
- A scheduled Task.
- A rejected-records table.
- A pipeline run-log table.

Expected result:

- Valid topics should be merged into `CORE.STUDY_TOPICS`.
- Invalid topics should be stored with a rejection reason.
- Every execution should be written to the pipeline run log.

Result:

- Valid topic records were processed successfully.
- The CORE table contained 31 topics.
- Pipeline execution details were recorded.

Status: **PASS**

## 5. Learner Registration Testing

The learner-registration procedure was tested using a demo learner.

Expected result:

- A learner record should be created.
- A certification enrollment should be created.
- All 31 topics should be assigned to the learner.
- Every topic should initially have the status `NOT_STARTED`.

Result:

| Validation | Result |
|---|---:|
| Assigned topics | 31 |
| Completed topics at initial registration | 0 |
| In-progress topics at initial registration | 0 |
| Not-started topics at initial registration | 31 |

The registration procedure returned a success message.

Status: **PASS**

## 6. Learning Activity and Progress Testing

The learning-activity pipeline was tested by recording topic activity for a learner.

Expected result:

- A valid activity should update the related topic-progress record.
- The status should change based on completion percentage.
- Study duration should be converted from minutes to hours.
- Activity timestamps should be updated.

Observed result:

| Field | Result |
|---|---|
| Topic | D01_T01 |
| Progress status | COMPLETED |
| Completion percentage | 100 |
| Hours spent | 1.25 |
| Started timestamp | Recorded |
| Completed timestamp | Recorded |
| Last activity timestamp | Recorded |

Status: **PASS**

## 7. Learner-Information CSV Pipeline Testing

The learner-information pipeline was tested using:

- `data/learner_information.csv`
- `tests/data/invalid_learners.csv`
- `tests/data/corrected_learners.csv`

### 7.1 Valid Learner Records

Expected result:

- Valid learner records should be registered.
- Enrollments should be created.
- Topic-progress records should be initialized.

Result:

- Valid learner records were processed successfully.
- Each registered learner received 31 assigned topics.

Status: **PASS**

### 7.2 Invalid Learner Record

An intentional invalid record was created with:

```text
Snowflake experience = -2
```

Expected result:

- The record should be rejected.
- The rejection reason should be stored.

Observed rejection reason:

```text
Snowflake experience must be zero or greater.
```

Status: **PASS**

### 7.3 Corrected Learner Record

The invalid experience value was corrected and submitted again.

Expected result:

- The corrected learner should be registered.
- The earlier rejection should be marked as resolved.

Result:

- The corrected learner was registered.
- `RESOLVED_FLAG` changed to `TRUE`.
- `RESOLVED_AT` was populated.

Status: **PASS**

## 8. Learner-Progress CSV Pipeline Testing

The learner-progress pipeline was tested using:

- `data/learner_progress.csv`
- `tests/data/invalid_progress.csv`
- `tests/data/corrected_progress.csv`

### 8.1 Valid Progress Records

Expected result:

- Valid activities should update topic progress.
- Completion percentage, status and study hours should be updated.

Result:

- Two valid progress records were received.
- Two records were accepted.
- No records were rejected.

Status: **PASS**

### 8.2 Invalid Progress Record

An intentional invalid progress record was created with:

```text
Completion percentage = 150
```

Expected result:

- The record should be rejected because the valid range is 0–100.

Observed rejection reason:

```text
Completion percentage must be between 0 and 100.
```

Status: **PASS**

### 8.3 Corrected Progress Record

The completion percentage was corrected to `100`.

Expected result:

- The corrected activity should be processed.
- The topic should be marked as completed.
- The earlier rejection should be resolved.

Result:

- The corrected record was processed successfully.
- Topic status changed to `COMPLETED`.
- Completion percentage changed to `100`.
- The earlier rejection was marked as resolved.

Status: **PASS**

## 9. Pipeline Run-Log Testing

The run-log tables were checked after each pipeline execution.

Expected result:

Every execution should record:

- Pipeline name.
- Run status.
- Records received.
- Records accepted.
- Records rejected.
- Run message.
- Start time.
- Completion time.

Result:

- Successful executions were recorded.
- Executions with zero new records were also recorded correctly.
- Zero-record executions occurred because the Stream had already consumed the previously processed records.

Status: **PASS**

## 10. Data-Quality Testing

The platform data-quality tests checked:

- Required fields.
- Duplicate identifiers.
- Invalid experience values.
- Invalid completion percentages.
- Invalid topic references.
- Missing learner references.
- Learning-plan completeness.
- Enrollment and progress consistency.

Result:

- All platform data-quality tests passed.

Status: **PASS**

## 11. Role-Based Access Testing

The platform roles were created using the approved functional-role naming convention:

- `FR_CERT_ENABLEMENT_LEARNER_DEV`
- `FR_CERT_ENABLEMENT_PROGRAM_MANAGER_DEV`
- `FR_CERT_ENABLEMENT_PLATFORM_ADMIN_DEV`

Expected result:

- Learner access should be limited to required learner features.
- Program managers should have monitoring and management access.
- Platform administrators should have administrative access.

Result:

- The required roles and grants were created successfully.

Status: **PASS**

## 12. Snowflake Naming-Convention Validation

The Snowflake objects were renamed according to the shared naming standards.

Examples include:

| Object type | Implemented name |
|---|---|
| Database | DB_CERT_ENABLEMENT_DEV |
| Warehouse | WH_CERT_ENABLEMENT_DEV_XS |
| Internal stage | INT_RAW_CERTIFICATION_UPLOAD_DEV |
| Stream | STR_LEARNER_INFORMATION_INBOX |
| Stored procedure | SP_PROCESS_CERT_ENABLEMENT_LEARNER_INFORMATION |
| Task | TSK_PROCESS_LEARNER_INFORMATION_1MIN |
| View | VW_LEARNER_PROGRESS |
| Functional role | FR_CERT_ENABLEMENT_LEARNER_DEV |

Result:

- The SQL scripts, tests and documentation were updated.
- Searches for the previous database and warehouse names returned no results.

Status: **PASS**

## 13. Pod Configuration Testing

Pod information was uploaded using:

```text
data/pods.csv
```

Test Pod:

| Field | Value |
|---|---|
| Pod ID | POD_001 |
| Pod name | Snowflake Data Engineering |
| Pod Lead employee ID | LEAD_DEMO_001 |
| Active flag | TRUE |

Expected result:

- The Pod should be created in `CORE.PODS`.
- The Pod Lead details should be stored.
- The Pod should be active.

Result:

- `POD_001` was created successfully.
- The Pod Lead information was stored.
- The Pod was active.

Status: **PASS**

## 14. Pod Lead Nomination Testing

Certification nominations were uploaded using:

```text
data/certification_nominations.csv
```

The nomination included:

- Employee information.
- Pod information.
- Pod Lead employee ID.
- Certification ID.
- Target completion date.
- Target exam date.
- Nomination reason.

Expected result:

- Only the authorized Pod Lead should be allowed to nominate an employee.
- A successful nomination should create the learner, enrollment and dynamic topic plan.

Result:

- Valid nominations were processed successfully.
- Learner and enrollment records were created.
- All 31 topics were assigned.

Status: **PASS**

## 15. Dynamic Learning-Plan Testing

The dynamic-plan logic was tested using two employees with different Pod Lead target dates.

| Employee | Target completion date | Target exam date | Topics | First week | Last week |
|---|---|---|---:|---:|---:|
| Asha Rao | 15 December 2026 | Provided by Pod Lead | 31 | 1 | 12 |
| Rahul Mehta | 30 November 2026 | 7 December 2026 | 31 | 1 | 10 |

Expected result:

- Both learners should receive all 31 topics.
- The number of weeks should be calculated using the target completion date.
- The plan should not use a fixed duration based only on Snowflake experience.

Result:

- Asha Rao received a 12-week plan.
- Rahul Mehta received a 10-week plan.
- Both learners received 31 topics.
- Both enrollments had `PLAN_TYPE = DYNAMIC`.

This confirms that the completion timeline is controlled by the Pod Lead’s target dates.

Status: **PASS**

## 16. Unauthorized Pod Lead Testing

An intentional invalid nomination was submitted using:

```text
Pod Lead employee ID = WRONG_LEAD_999
```

Expected result:

- The nomination should be rejected.
- The rejection reason should explain that the Pod Lead is not authorized.

Observed rejection reason:

```text
Nomination failed: The supplied Pod Lead is not authorised for this Pod.
```

Status: **PASS**

## 17. Corrected Nomination Testing

The rejected nomination was submitted again using the correct Pod Lead:

```text
Pod Lead employee ID = LEAD_DEMO_001
```

Expected result:

- The corrected nomination should be accepted.
- The learner should receive a dynamic learning plan.
- The earlier rejection should be marked as resolved.

Result:

- The corrected nomination was accepted.
- Rahul Mehta received a 10-week dynamic plan.
- The earlier rejection was resolved.

Status: **PASS**

## 18. Pod Nomination Pipeline Testing

The Pod and nomination pipeline returned:

```text
Processing completed. Records received: 2, accepted: 2, rejected: 0.
```

Expected result:

- The Pod record should be accepted.
- The valid nomination should be accepted.
- The pipeline execution should be recorded.

Result:

- Two records were received.
- Two records were accepted.
- No records were rejected during the valid execution.

Status: **PASS**

## 19. Weekly Progress Reminder Testing

The weekly reminder feature contains:

- Reminder configuration.
- Reminder-candidate view.
- Reminder stored procedure.
- Reminder execution log.
- Weekly scheduled Task.

Task:

```text
TSK_SEND_PROGRESS_REMINDERS_WEEKLY
```

Schedule:

```text
Every Monday at 9:00 AM Asia/Kolkata
```

### 19.1 Reminder Simulation

The reminder procedure was tested with email delivery disabled.

Observed result:

| Employee | Status |
|---|---|
| EMP_DEMO_101 | SIMULATED |

Expected result:

- An eligible learner should appear in the reminder log.
- No real email should be sent in simulation mode.
- No failure message should be recorded.

Result:

- A simulated reminder was recorded successfully.
- No failure message was recorded.

Status: **PASS**

### 19.2 Live Email Limitation

Live email delivery was not tested.

Snowflake email notifications require the recipient email address to belong to a verified Snowflake user in the same account. The prototype used demonstration email addresses.

This is an environment prerequisite and not a platform defect.

Status: **NOT EXECUTED – ENVIRONMENT PREREQUISITE**

## 20. Scheduled Task Validation

The following automated Tasks were created and verified:

- Study-topic processing Task.
- Learning-event processing Task.
- Learner-information processing Task.
- Learner-progress processing Task.
- Certification-nomination processing Task.
- Weekly progress-reminder Task.

The Tasks were suspended after testing to reduce Snowflake trial-account credit usage.

Status: **PASS**

## 21. CSV Upload Documentation

The following upload documentation was prepared:

```text
docs/CSV_UPLOAD_GUIDE.md
```

The guide covers:

- Required CSV files.
- Mandatory fields.
- Accepted formats.
- Date formats.
- Validation rules.
- Upload steps.
- Error-checking process.
- Correction and reprocessing.
- Security guidelines.

Status: **PASS**

## 22. Git Validation

The following artifacts were stored in Git:

- SQL deployment scripts.
- CSV templates.
- Test CSV files.
- Data-quality tests.
- Pod and nomination tests.
- Deployment documentation.
- Design documentation.
- CSV upload guidelines.
- Test results.

The work was developed in:

```text
feature/pod-dynamic-plan-reminders
```

Result:

- Changes were committed successfully.
- Changes were pushed to GitHub.
- The working tree was clean after the commits.

Status: **PASS**

## 23. Final Test Summary

| Test area | Status |
|---|---|
| Foundation data | PASS |
| Study-topic pipeline | PASS |
| Learner registration | PASS |
| Learning-activity processing | PASS |
| Learner-information CSV pipeline | PASS |
| Learner-progress CSV pipeline | PASS |
| Invalid-record handling | PASS |
| Data-quality checks | PASS |
| Role-based access | PASS |
| Naming standards | PASS |
| Pod configuration | PASS |
| Pod Lead nomination | PASS |
| Dynamic timeline | PASS |
| Unauthorized Pod Lead rejection | PASS |
| Corrected nomination processing | PASS |
| Pipeline monitoring | PASS |
| Weekly reminder simulation | PASS |
| Live email delivery | NOT EXECUTED – ENVIRONMENT PREREQUISITE |
| CSV upload documentation | PASS |
| Git version control | PASS |

## 24. Final Result

The prototype passed the completed functional, validation, pipeline, security, dynamic-planning and automation tests.

The platform now supports:

- Pod Lead certification nominations.
- Pod-based learner registration.
- Pod Lead-provided completion and exam dates.
- Dynamic learning-plan creation.
- Learner-progress tracking.
- CSV validation and rejection handling.
- Pipeline monitoring.
- Weekly progress-reminder simulation.
- Approved Snowflake object-naming standards.
- Clear CSV upload instructions.

The weekly reminder Task remains suspended after testing to avoid unnecessary Snowflake trial-account usage.