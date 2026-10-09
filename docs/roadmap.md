# Version Roadmap

## Version 1.0 — Foundation

### Objective

Provide a working certification-tracking foundation for SnowPro Core COF-C03 with clear documentation and an approved data model.

### Included

- Four-schema Snowflake architecture
- Certification, domain and topic reference data
- Employee, Pod and Pod-membership data
- Certification nomination processing
- Employee-certification enrollment
- Learner-specific topic-plan generation
- Topic-progress and learning-event tracking
- Practice assessments and readiness views
- Reminder simulation
- Manual CSV ingestion
- Streams, Tasks and stored procedures
- Logical data model and ER diagram
- Markdown documentation in Git

### Completion focus

- Obtain architecture approval for the logical data model.
- Document current assumptions and limitations.
- Confirm naming standards.
- Align the repository documentation with the approved design.
- Plan SQL changes only after the model is approved.

## Version 1.1 — Operational Improvements

### Planning

- Assign approved effort weights to topics.
- Allocate available days proportionally by topic weight.
- Recalculate only incomplete topics after an extension.
- Preserve completed progress during plan changes.
- Support fresh and renewal plan variations.

### Certification lifecycle

- Track official exam attempts.
- Track passed, failed, scheduled and absent outcomes.
- Store certification-awarded and expiry dates.
- Notify employees about upcoming expiry.
- Support employees joining with an existing certification.

### Analytics and governance

- Unify fixed and dynamic assigned-topic reporting.
- Correct analytics to use the approved learner-plan model.
- Add validation for certification and topic validity periods.
- Update RBAC for all approved new objects.
- Complete controlled end-to-end tests.

## Version 2.0 — User Experience and Automation

### User experience

- Streamlit interface for nominations
- Streamlit interface for progress entry
- Pod Lead monitoring dashboard
- Employee study-plan view

### Ingestion and orchestration

- Approved SharePoint or shared-source integration
- Snowpipe or another approved automated-ingestion pattern
- Dynamic Tables suitability assessment for derived datasets
- Reduced dependency on manually uploaded CSV files

### Intelligence and expansion

- Multiple certification providers
- Governed Semantic Views
- Recommendation agent
- Mastech-approved certification information
- Interview feedback and employee write-ups, subject to privacy approval
- Partner-level certification requirements, if formally required

## Versioning Principle

Version 1.0 establishes the correct foundation. Version 1.1 improves scheduling, lifecycle tracking and analytics. Version 2.0 introduces user-facing applications, automated ingestion and intelligent recommendations.

