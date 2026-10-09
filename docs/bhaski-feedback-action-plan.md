# Bhaski Feedback and Action Plan

## 1. Overall Message

The broad workflow—upload, detect, validate, build and track—is acceptable. The priority is to strengthen the data-model foundation before adding future features.

## 2. Feedback Mapping

| Feedback | Current response | Version |
|---|---|---|
| Separate employee, certification and topic information | Proposed normalized logical model | 1.0 |
| Clearly connect topics to certifications | Documented `Certification → Domain → Topic` relationship | 1.0 |
| Connect employees to certifications | `ENROLLMENTS` defined as central relationship | 1.0 |
| Avoid repeated data and follow third normal form | Employee and Pod Lead details stored once in the proposed model | 1.0 |
| Make the platform expandable | Provider-neutral certification structure | 1.0 design |
| Add certification and topic validity | Proposed validity fields | Review decision |
| Document assumptions | Separate assumptions document | 1.0 |
| Use Markdown and Git | Documentation pack prepared in Markdown | 1.0 |
| Include a data-model diagram | Mermaid ER diagram included | 1.0 |
| Follow naming standards | Final physical names pending naming review | 1.0 |
| Document procedure responsibilities | Procedure catalogue prepared | 1.0 |
| Do not allocate equal time to every topic | Weighted allocation retained as roadmap | 1.1 |
| Handle extension using remaining topics and days | Retained as roadmap | 1.1 |
| Track exam result and certification expiry | Proposed certification-results entity | 1.1 |
| Do not base plans primarily on experience | Future plan based on dates, weights and attempt type | 1.1 |
| Consider Streamlit for progress entry | Retained as future enhancement | 2.0 |
| Evaluate Dynamic Tables | Suitability assessment retained as future work | 2.0 evaluation |
| Treat partner-tier tracking separately | Kept outside the current scope | Future |

## 3. Immediate Actions

- Review the proposed logical data model with Durga and the architecture reviewers.
- Check organizational naming standards before renaming physical objects.
- Confirm the future of the older fixed-path workflow.
- Confirm whether validity fields and normalized topic-resource mapping are Version 1.0 changes.
- Keep SQL changes limited until the model is approved.
- Maintain the documentation in Git.

## 4. Items Deliberately Deferred

- Weighted plan calculation
- Extension recalculation
- Official result integration
- Streamlit interface
- Automated SharePoint ingestion
- Semantic View and recommendation agent
- Partner-tier tracking

