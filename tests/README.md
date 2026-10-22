# Test Suite

This directory contains SQL tests and fictional test data for the Snowflake Certification Enablement Platform.

Run tests only in a development environment. Some scripts create demonstration records, call stored procedures or change configuration values.

## Test Files

| Order | File | Purpose |
| ---: | --- | --- |
| 1 | `01_study_topics_pipeline_test.sql` | Validates study-topic loading, processing and rejection handling |
| 2 | `02_platform_data_quality_tests.sql` | Validates platform-level relationships, ranges, duplicates and data-quality rules |
| 3 | `03_csv_pipeline_validation_tests.sql` | Validates learner-information and progress CSV processing, corrections and rejected records |
| 4 | `04_pod_dynamic_plan_reminder_tests.sql` | Validates Pod nomination, dynamic-plan creation and reminder simulation |

## Test Data

The `data` subdirectory contains fictional validation inputs:

| File | Purpose |
| --- | --- |
| `invalid_learners.csv` | Contains deliberately invalid learner records |
| `corrected_learners.csv` | Contains corrected versions of learner records |
| `invalid_progress.csv` | Contains deliberately invalid progress records |
| `corrected_progress.csv` | Contains corrected versions of progress records |

These files are intended to verify rejection, correction and reprocessing behavior.

## Recommended Execution Process

1. Deploy the SQL scripts under `../sql` in numerical order.
2. Confirm that the required warehouse is available.
3. Confirm that expected foundation and sample data exist.
4. Review the test script before execution.
5. Execute one test file at a time in numerical order.
6. Review query results, rejected records and pipeline-run logs.
7. Suspend Tasks after automated testing.
8. Restore configuration values changed temporarily for a test.

## Important Safety Notes

- Do not run these tests in a production or partner account without approval.
- Tests may insert fictional learners, nominations, events and reminder records.
- Reminder tests must use simulation mode unless live-email testing is explicitly approved.
- Use fictional email addresses unless verified Snowflake recipients are intentionally being tested.
- Check Task state before and after scheduled-processing tests.

## Expected Evidence

Test evidence should include:

- The test name
- Execution date and environment
- Expected result
- Actual result
- Pass or fail status
- Relevant rejection or failure message
- Any cleanup or configuration restoration performed

The existing validation snapshot is documented in [Test Results](../docs/test-results.md).

## Adding New Tests

When a new feature is introduced:

1. Add or update a numbered SQL test file.
2. Use fictional and repeatable input data.
3. Include both successful and invalid scenarios.
4. Verify that rejected records contain useful reasons.
5. Update this README and the test-results document.
6. Ensure the test can be rerun safely in the development environment.
