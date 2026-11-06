# Snowflake Certification Enablement Platform

## Platform Overview

The Snowflake Certification Enablement Platform is a Snowflake Native App designed to manage an employee's certification journey in one place.

The platform provides a structured process for:

- Employee self-nomination
- Pod Lead nomination of eligible Pod Members
- Role-based review and approval
- Certification enrollment
- Personalised study-plan generation
- Topic-level learning progress
- Certification-readiness measurement

The platform follows the organisation's Studio Lead, Pod Lead and Pod Member structure. It also records important requests, decisions and status changes so that the complete certification journey can be reviewed later.

The application is being developed in phases. Each phase builds on the information and workflow completed in the previous phase.

---

## Phase 1: Certification Nomination Workflow

### Objective

The objective of Phase 1 is to establish the identity, access, nomination and approval foundation of the platform.

### Implemented capabilities

Phase 1 currently supports:

- Identification of the signed-in Snowflake user
- Mapping of the user to their employee profile, platform role and Pod
- Employee self-nomination for a certification
- Pod Lead nomination of an active member of their own Pod
- Prevention of cross-Pod nominations
- Certification selection from the active certification catalogue
- Preparation start date and target completion date capture
- Routing of a Pod Member's self-request to their Pod Lead
- Routing of a Pod Lead's self-request to the Studio Lead
- Routing of a Pod Lead nomination to the nominated employee
- Review and approval or rejection of self-requests
- A **My Requests** section showing the employee's self-requests and their current status
- A **Nominations Received** section showing nominations received from a Pod Lead
- A notification message when a Pod Member receives a nomination
- A **Start My Journey** entry point after a self-request is approved
- Storage of nomination decisions and status history for audit purposes

### Current approval rules

| Request type | Reviewer or recipient |
|---|---|
| Pod Member self-request | The employee's Pod Lead |
| Pod Lead self-request | Studio Lead |
| Pod Lead nominates a Pod Member | The nominated Pod Member |

### Possible Phase 1 enhancements

#### Candidate response workflow

When a Pod Member receives a nomination, the platform can provide the following responses:

- Accept the nomination
- Request changes to the preparation or target dates
- Decline the nomination

If the employee requests a date change, the nomination can remain on hold until revised dates are agreed.

#### Email notifications

Email notifications can be sent when:

- A Pod Member receives a nomination
- A Pod Member's self-request is sent to their Pod Lead
- A Pod Lead's self-request is sent to the Studio Lead
- A request is approved or rejected
- A candidate accepts, declines or requests a date change

The email can include the certification, nominator, reviewer, preparation dates, current status and a link to open the application.

#### In-application notification centre

A central notification area can show new nominations, pending reviews, decisions and date-change requests.

#### Alternate approver

The Studio Lead can be introduced as an alternate approver when a Pod Lead is unavailable. The system should capture why the alternate route was used.

---

## Phase 2: Certification Enrollment

### Objective

The objective of Phase 2 is to convert an approved or accepted nomination into an active certification journey.

### Planned capabilities

- Automatically create an enrollment after the required approval or candidate acceptance
- Link every enrollment to its original nomination
- Store the approved preparation start date and target completion date
- Track the enrollment status, such as:
  - Not Started
  - Active
  - On Hold
  - Completed
  - Cancelled
- Record whether the journey is a first attempt, retake or renewal
- Display active and completed enrollments on the employee's page
- Prevent more than one active enrollment for the same approved nomination
- Preserve enrollment history even when an attempt is completed or cancelled

The **Start My Journey** action from Phase 1 will connect to the enrollment created in this phase.

---

## Phase 3: Personalised Study-Plan Generation

### Objective

The objective of Phase 3 is to generate a realistic study plan based on the selected certification and the employee's availability.

### Information used for plan generation

The learning plan can consider:

- Selected certification
- Certification syllabus and study topics
- Exam-domain weightages
- Approved preparation start date
- Target completion date
- Employee's available study hours per day or week
- Employee's current knowledge or assessment results
- Topic difficulty
- Revision time
- Practice-test time
- Buffer time for missed activities

### Planned employee experience

1. The employee opens their active enrollment.
2. The platform displays the certification syllabus, topics and weightages.
3. The employee enters their available learning hours.
4. The employee selects **Generate My Learning Plan**.
5. The platform creates a proposed topic-by-topic schedule.
6. The employee reviews the plan.
7. The employee can accept it or customise it.
8. The final confirmed plan becomes the employee's active study plan.

### Learning-resource enhancement

Pluralsight learning paths, courses and assessments can complement the generated study plan. Information will be gathered from the Pluralsight administrators to understand the available content, reporting options and possible integration methods.

---

## Phase 4: Topic Progress and Certification Readiness

### Objective

The objective of Phase 4 is to track learning progress at topic level and use that information to provide an indicative certification-readiness score.

### Topic-progress tracking

For every topic in an employee's study plan, the platform can capture:

- Not Started, In Progress or Completed status
- Completion percentage
- Study hours completed
- Last activity date
- Assessment result
- Practice-test result
- Revision completion
- Employee notes

Progress can initially be entered by the employee. Where supported, course and assessment progress can later be obtained from connected learning platforms such as Pluralsight.

### Certification-readiness calculation

The readiness score can combine factors such as:

- Weighted topic completion
- Performance in topic assessments
- Practice-test results
- Revision completion
- Consistency of learning activity
- Completion of high-weightage exam domains

The exact formula and weight assigned to each factor must be reviewed and approved as a business decision before implementation.

### Important disclaimer

> The certification-readiness score is an internal guidance measure. It does not guarantee that the employee will pass the official Snowflake certification examination.

### Reminders and inactivity monitoring

The progress information can also support reminders:

- After three days without learning activity, remind the employee.
- After five days without activity, remind the employee and notify the responsible Pod Lead or nominator.
- Send reminders for upcoming target dates and overdue activities.

The reminder intervals should remain configurable business rules.

---

## Phase Summary

| Phase | Focus | Current status |
|---|---|---|
| Phase 1 | Nomination, routing, approval and request visibility | Implemented foundation; candidate responses and email are enhancements |
| Phase 2 | Approved nomination to active enrollment | Planned |
| Phase 3 | Personalised study-plan generation | Planned |
| Phase 4 | Topic progress and certification readiness | Planned |

---

## Overall Direction

The phased approach allows the platform to grow from a controlled nomination workflow into a complete certification-enablement solution.

The final platform will connect:

```text
Nomination
    -> Approval or Candidate Acceptance
    -> Enrollment
    -> Personalised Study Plan
    -> Topic Progress
    -> Certification Readiness
    -> Certification Completion
```

Each phase will retain the employee, certification and decision history required for visibility, governance and future reporting.
