# Project Documentation

This directory contains the technical documentation for the Snowflake Certification Enablement Platform.

The platform is currently a proof of concept. Some documents describe the implemented Snowflake workflows, while the data model also includes proposed changes that require architecture approval.

## Recommended Reading Order

A new developer should read the documentation in this order:

1. [Project README](../README.md)
   Provides the project overview, current status, repository structure and known limitations.

2. [Platform Architecture](architecture.md)
   Explains the Snowflake schemas and the study-topic, nomination, progress, analytics and reminder workflows.

3. [Data Model](data-model.md)
   Describes the logical data model, table responsibilities, relationships and proposed improvements.

4. [Stored Procedure and Task Catalogue](procedure-catalog.md)
   Lists the procedures and Tasks used by each pipeline.

5. [Deployment Guide](deployment-guide.md)
   Provides prerequisites, SQL execution order, verification steps, Task management and deployment guidance.

6. [CSV Upload Guide](csv-upload-guide.md)
   Describes supported input files, required columns, upload steps, processing and rejected-record handling.

7. [Test Results](test-results.md)
   Records the previous functional, validation and automation test results.

8. [Assumptions and Limitations](assumptions-and-limitations.md)
   Documents business assumptions, technical assumptions, current limitations and decisions requiring review.

9. [Version Roadmap](roadmap.md)
   Separates the current foundation from future operational and automation enhancements.

## Documentation Catalogue

| Document | Purpose | Status |
|---|---|---|
| `architecture.md` | Current platform layers and workflows | Current |
| `data-model.md` | Logical model and proposed structural improvements | Under review |
| `procedure-catalog.md` | Procedure and Task inventory | Current |
| `deployment-guide.md` | Deployment and operating instructions | Current |
| `csv-upload-guide.md` | Input-file and processing instructions | Current |
| `test-results.md` | Recorded test evidence | Historical snapshot |
| `assumptions-and-limitations.md` | Assumptions, limitations and open decisions | Current |
| `roadmap.md` | Version 1.0, 1.1 and 2.0 plans | Current |

## Current Versus Proposed Information

The documentation contains two types of information:

### Current implementation

The current implementation is represented by:

- SQL files under `../sql`
- Test files under `../tests`
- Current workflows documented in `architecture.md`
- Procedures and Tasks documented in `procedure-catalog.md`
- Deployment instructions documented in `deployment-guide.md`

### Proposed design

The proposed data-model changes were studied using PostgreSQL, pgAdmin, fictional sample data and normalization exercises.

The proposed model:

- Is intended to improve table relationships and reduce repeated data.
- Has not replaced the existing Snowflake `CORE` model.
- Must be reviewed before Snowflake implementation.
- Must not be treated as a deployed production model.

## Important Development Rules

Before changing or extending the platform:

1. Confirm whether the change belongs to the current implementation or the roadmap.
2. Review the dependencies between numbered SQL files.
3. Use a feature branch.
4. Test changes in a development Snowflake account.
5. Add or update the relevant SQL tests.
6. Update the corresponding documentation.
7. Do not commit credentials, tokens or real employee information.
8. Request review before merging data-model changes.

## Documentation Maintenance

Documentation should be updated whenever:

- A table, view, procedure, Stream or Task is added or changed.
- A CSV format changes.
- The deployment order changes.
- A test is added or its expected result changes.
- A limitation is resolved.
- A roadmap item becomes part of the current implementation.

Meeting scripts, presentation notes and individual feedback notes should not be stored as permanent technical documentation. Important decisions from those discussions should instead be incorporated into the architecture, data-model, assumptions or roadmap documents.