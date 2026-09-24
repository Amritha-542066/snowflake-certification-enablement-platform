# Snowflake Certification Enablement Platform

## CSV Pipeline Testing Results

**Test Date:** 24 September 2026
**Tested By:** Amritha Kalyanasundaram Ganesh
**Environment:** Snowflake trial account
**Warehouse:** SNOWPRO_LEARNING_WH
**Database:** SNOWPRO_ENABLEMENT
**Overall Status:** PASS

## 1. Testing Objective

The purpose of this testing was to validate the learner-information and learner-progress CSV ingestion workflows.

The testing covered:

- Valid learner processing
- Experience-based learning-path assignment
- Topic-progress initialization
- Valid learning-progress processing
- Data validation
- Rejected-record handling
- Correction and reprocessing
- Duplicate-prevention checks
- Pipeline run logging
- Automatic Stream and Task processing
- Final learner-progress updates

All testing used fictional demonstration data. No real employee information was stored in Git.

## 2. Test Data

The following files were used:

- `data/learner_information.csv`
- `data/learner_progress.csv`
- `tests/data/invalid_learners.csv`
- `tests/data/invalid_progress.csv`
- `tests/data/corrected_learners.csv`
- `tests/data/corrected_progress.csv`

These files form the initial candidate golden record set. Formal approval is still required before identifying them as an approved golden record set.

## 3. Test Summary

| Test ID | Test scenario | Expected result | Actual result | Status |
|---|---|---|---|---|
| TC-001 | Register three demo learners | Three learners created | Three learners created | PASS |
| TC-002 | Create active enrollments | Each learner receives an active enrollment | Three active enrollments created | PASS |
| TC-003 | Assign experience-based paths | Correct path assigned from Snowflake experience | Fresher and 0-5 year paths assigned correctly | PASS |
| TC-004 | Initialize assigned topics | Each learner receives 31 topic-progress rows | 31 topics created for each learner | PASS |
| TC-005 | Process learner source records | Three learner records accepted | Three learner records accepted | PASS |
| TC-006 | Process progress source records | Three progress records accepted | Three progress records accepted | PASS |
| TC-007 | Reject invalid records | Negative experience and 150 percent completion rejected | Both records rejected with expected reasons | PASS |
| TC-008 | Resolve corrected records | Corrected records processed and rejections marked resolved | Both rejection records marked resolved | PASS |
| TC-009 | Prevent duplicate learners | No duplicate employee IDs | Zero duplicate employee IDs found | PASS |
| TC-010 | Prevent duplicate activities | No duplicate activity IDs | Zero duplicate activity IDs found | PASS |
| TC-011 | Correct learner progress | EMP_DEMO_001 reaches 100 percent and 1.00 hours | COMPLETED, 100 percent and 1.00 hours | PASS |
| TC-012 | Complete learner progress | EMP_DEMO_002 reaches 100 percent and 1.25 hours | COMPLETED, 100 percent and 1.25 hours | PASS |
| TC-013 | Automatic learner Task | Stream-triggered Task registers learner | EMP_TASK_001 created with PATH_5_9 and 31 topics | PASS |
| TC-014 | Automatic progress Task | Task processes RAW progress into learning events | ACT_TASK_001 created successfully | PASS |
| TC-015 | Automatic learning-event Task | Task updates final topic progress | D01_T02 updated to IN_PROGRESS, 10 percent and 0.33 hours | PASS |

## 4. Valid Learner Test

Two fictional learner records were uploaded through `learner_information.csv`.

The learner pipeline produced the following result:

```text
Records received: 2
Records accepted: 2
Records rejected: 0
Run status: SUCCESS
```

The first learner had zero years of Snowflake experience and was assigned to `PATH_FRESHER`.

The second learner had three years of Snowflake experience and was assigned to `PATH_0_5`.

Each learner received 31 initialized topic-progress records.

## 5. Valid Progress Test

Two fictional progress records were uploaded through `learner_progress.csv`.

The progress pipeline produced the following result:

```text
Records received: 2
Records accepted: 2
Records rejected: 0
Run status: SUCCESS
```

The final results were:

- `EMP_DEMO_001` initially reached 25 percent with 0.50 study hours.
- `EMP_DEMO_002` reached 100 percent with 1.25 study hours.

## 6. Invalid Learner Test

The invalid learner record contained:

```text
Snowflake experience: -2
```

The record was rejected with the reason:

```text
Snowflake experience must be zero or greater.
```

The value was corrected to two years. The corrected record was uploaded again and processed successfully.

The learner was assigned to:

```text
Experience level: EXP_0_5
Learning path: PATH_0_5
```

The original rejection was marked as resolved.

## 7. Invalid Progress Test

The invalid progress record contained:

```text
Completion percentage: 150
```

The record was rejected with the reason:

```text
Completion percentage must be between 0 and 100.
```

The completion percentage was corrected to 100. The corrected record was uploaded again and processed successfully.

The final progress for `EMP_DEMO_001` and `D01_T01` was:

```text
Status: COMPLETED
Completion: 100 percent
Hours spent: 1.00
```

The original rejection was marked as resolved.

## 8. Automatic Task Testing

The learner-information and learner-progress Tasks were resumed temporarily for testing.

A fictional learner named `EMP_TASK_001` was inserted into the RAW learner inbox. The learner Task detected the Stream data and registered the learner automatically.

The learner received:

```text
Experience level: EXP_5_9
Learning path: PATH_5_9
Assigned topics: 31
```

A progress record named `ACT_TASK_001` was inserted into the RAW progress inbox. The progress Task created a learning event, and the learning-events Task updated topic progress.

The final result was:

```text
Topic: D01_T02
Status: IN_PROGRESS
Completion: 10 percent
Hours spent: 0.33
```

All Tasks were suspended after testing to protect the trial-account credits.

## 9. Pipeline Audit Validation

Pipeline runs were recorded in:

```text
SNOWPRO_ENABLEMENT.CONTROL.CSV_PIPELINE_RUN_LOG
```

Each record included:

- Pipeline name
- Start and completion times
- Run status
- Records received
- Records accepted
- Records rejected
- Processing message

Rejected records were stored in:

```text
SNOWPRO_ENABLEMENT.CONTROL.CSV_REJECTED_RECORDS
```

Each rejection included:

- Pipeline name
- Source record ID
- Source filename
- Raw record
- Rejection reason
- Rejection timestamp
- Resolution status

## 10. Observations

- Re-executing a processing procedure after its Stream has been consumed returns zero received records. This is expected and does not indicate a failure.
- The initial learner procedure loop failed because the query was used directly in the loop. It was corrected by assigning the query to a Snowflake `RESULTSET` before iteration.
- RAW columns use text types so invalid values can be captured and rejected by the validation procedure instead of causing the complete CSV load to fail.
- Successfully processed source IDs are recorded to prevent duplicate acceptance.
- Rejected records can be corrected and uploaded again because rejected source IDs are not added to the processed-record table.
- Scheduled Tasks were tested successfully and then suspended to reduce trial-account usage.

## 11. Final Result

All 15 functional, validation and automation tests passed.

The learner-information and learner-progress CSV pipelines are ready for the prototype demonstration.

The current input method is manual CSV upload. The future roadmap is to connect the approved Mastech Excel-based source and automatically load learner and progress data into the Snowflake RAW layer.