# Assumptions and Limitations

## 1. Business Assumptions

- Every employee has a stable and unique company employee ID.
- Pod and Pod Lead reference data is maintained before nomination processing.
- A nomination is submitted by an authorized Pod Lead for the selected Pod.
- Certification, domain and topic information comes from an approved source.
- SnowPro Core COF-C03 is the initial certification supported by Version 1.0.
- The logical model is designed to support additional certifications and providers later.
- An enrollment represents one employee's journey for one certification attempt.
- Fresh and renewal attempts may require separate enrollments.

## 2. Learning and Progress Assumptions

- Employees manually report learning activities, hours and completion percentages.
- Reported study time is treated as self-reported information.
- The platform does not observe reading, viewing, login or logout activity automatically.
- Learning resources are hosted externally; the platform stores links and metadata.
- Employees may revisit topics after completing them.
- Topic completion does not by itself prove official certification completion.

## 3. Technical Assumptions

- Incoming CSV files follow the documented column order and file format.
- RAW inbox tables preserve incoming values until validation occurs.
- CORE contains only validated and standardized records.
- CONTROL contains pipeline logs, rejection records and configuration.
- Streams and Tasks are available in the target Snowflake account.
- Stored-procedure owners have the privileges required to read and write the relevant objects.
- Snowflake primary-key and foreign-key constraints on standard tables are informational; procedures and validation logic enforce business integrity.
- Email notifications require an enabled integration and verified, eligible recipients.

## 4. Version 1.0 Limitations

- Input-file upload is manual.
- SnowPro Core COF-C03 is the only seeded certification.
- The plan uses the existing non-weighted topic distribution.
- Topic duration is an estimate rather than automatically measured learning time.
- Progress input depends on CSV files or stored-procedure calls.
- Live email sending is disabled by default.
- Official certification-provider results are not automatically retrieved.
- Certification expiry is not yet fully operationalized.
- The analytics views were originally designed for fixed paths and require alignment with the dynamic learner plan.
- The older fixed-path and newer dynamic-plan designs currently coexist.
- Dynamic Tables have not yet been validated as a replacement for any existing orchestration.

## 5. Out of Scope for Version 1.0

- Full Learning Management System capabilities
- Hosting all learning content inside the platform
- Automatic employee-time tracking
- Topic-weighted scheduling
- Automatic extension recalculation
- Official exam-provider integration
- Streamlit user interface
- Automated SharePoint ingestion
- Semantic View and recommendation-agent integration
- Partner-level Select, Premier or Elite tracking

## 6. Review Decisions Required

- Confirm the physical employee-table name after checking the naming standard.
- Confirm whether the older fixed-path workflow remains supported.
- Confirm when certification and topic validity fields must be implemented.
- Confirm the approved source for official exam results and credential expiry.
- Confirm the future employee progress-entry approach.
- Confirm whether any specific derived flow is suitable for Dynamic Tables.

