# SnowPro Core Enablement Platform

## Project Overview

The SnowPro Core Enablement Platform is a centralized learning and progress-tracking solution for employees preparing for the SnowPro Core Certification.

The platform provides a structured study plan, recommended learning resources, experience-based timelines, and learner progress tracking.

## Objectives

- Organize all SnowPro Core exam topics.
- Provide clear study plans for different experience levels.
- Track each learner's topic completion and learning progress.
- Continuously accept new learning content and learner activity.
- Provide progress and readiness reports.
- Keep all project code, data, documentation, and tests in Git.

## Experience Levels

The learning timelines will be configurable for:

- Fresher
- 0–5 years of experience
- 5–9 years of experience
- 9+ years of experience

The timelines can be reviewed and adjusted based on learner feedback and experience.

## High-Level Data Flow

1. Study-plan data and learner activities are loaded into the RAW schema.
2. Snowflake Streams identify new or updated records.
3. Snowflake Tasks process the records continuously.
4. Validated data is stored in the CORE schema.
5. ANALYTICS views provide learner progress and certification-readiness reports.
6. The CONTROL schema stores pipeline logs and rejected records.

## Snowflake Components

- Database: `SNOWPRO_ENABLEMENT`
- Schemas: `RAW`, `CORE`, `ANALYTICS`, and `CONTROL`
- Tables for topics, learning paths, learners, enrollments, and progress
- Streams and Tasks for continuous processing
- Views for progress and readiness reporting
- Role-based access control
- Data-quality validation queries

## Repository Structure

- `data/` – Sample and reference data
- `docs/` – Architecture, study-plan, and demo documentation
- `sql/` – Snowflake SQL deployment scripts
- `tests/` – Data-quality and pipeline-validation queries

## Current Scope

The current version focuses on the Snowflake database, study-plan data, progress tracking, pipeline processing, security, and reporting.

A Streamlit user interface is not included in the current scope.