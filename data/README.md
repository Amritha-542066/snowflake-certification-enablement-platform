# Sample Input Data

This directory contains sample CSV files used to demonstrate and test the Snowflake Certification Enablement Platform.

The files contain fictional development data. Real employee information must not be committed to this repository.

## Files

| File | Purpose | Related SQL |
| --- | --- | --- |
| `study_topics.csv` | Certification study-topic reference data | `sql/06_load_study_topics.sql`, `sql/07_study_topics_pipeline.sql` |
| `learner_information.csv` | Learner-registration input for the earlier fixed-path workflow | `sql/13_learner_information_pipeline.sql` |
| `learner_progress.csv` | Learning activities and topic-progress updates | `sql/14_learner_progress_pipeline.sql` |
| `certification_nominations.csv` | Pod Lead nominations for the newer dynamic-plan workflow | `sql/15_pod_nomination_dynamic_plan.sql`, `sql/16_pod_nomination_pipeline.sql` |

## Processing Workflows

### Study-topic input

```text
CSV -> Internal stage -> RAW inbox -> Stream -> Task
    -> Validation procedure -> CORE study topics
```

### Learner-information input

```text
CSV -> RAW learner inbox -> Stream -> Task
    -> Registration procedure -> Enrollment and fixed learning path
```

### Learner-progress input

```text
CSV -> RAW progress inbox -> Stream -> Task
    -> Learning events -> Topic progress
```

### Certification-nomination input

```text
CSV -> RAW nomination inbox -> Stream -> Task
    -> Nomination validation -> Dynamic enrollment and topic plan
```

## File Requirements

- Preserve the expected column names.
- Store one source record per row.
- Save files in CSV format.
- Use ISO date values such as `2026-12-31`.
- Use unique source-record identifiers where required.
- Review the corresponding SQL pipeline before changing a file structure.
- Update the CSV upload guide whenever columns are added, removed or renamed.

For field definitions and upload instructions, see the [CSV Upload Guide](../docs/csv-upload-guide.md).

## Data-Safety Rules

Do not commit:

- Real employee information
- Personal email addresses
- Passwords or Snowflake credentials
- Personal access tokens or private keys
- Production account details

Use clearly fictional names and email addresses for development and demonstrations.

## Test Data

Correction and rejection test files are stored separately under:

```text
../tests/data
```

Those files are intended for validation testing and should not be used as normal demonstration input.
