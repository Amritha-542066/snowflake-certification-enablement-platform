# Step 1 — Home Page and User Identity

## Snowflake Certification Enablement Native App

| Document information | Value |
|---|---|
| Document status | Approved for initial implementation |
| Scope | Step 1 only: application opening, user identification and permitted entry actions |
| Approved date | 1 November 2026 |
| Platform | Snowflake Native App with a simple Streamlit interface |
| Next step | Certification catalogue and nomination journeys |

---

## 1. Purpose

This document defines what should happen when a user opens the Snowflake Certification Enablement Platform.

The home page must:

- Identify the logged-in employee automatically.
- Display the employee's name, Pod and business role.
- Confirm that the employee is active and eligible to use the platform.
- Show only the actions that the employee is authorised to perform.
- Allow an employee to begin a self-nomination request.
- Allow an authorised Pod Lead to begin a Pod-member nomination.
- Handle unregistered, inactive or incomplete employee profiles safely.

This document does not define certification selection, nomination submission, approval screens or enrollment creation. Those belong to later steps.

---

## 2. Finalised Business Rules

The following rules are approved for the initial design.

### BR-001 — Self-Nomination Requires Approval

An employee may request a certification for themselves, but self-nomination does not immediately create an enrollment.

- A regular Pod member's self-nomination must first be reviewed by the Pod Lead of that employee's own Pod.
- The Director (Studio Lead) acts as the fallback approver for a Pod member only when the employee's Pod Lead is formally unavailable, for example because of approved leave.
- A Pod Lead's own self-nomination must be reviewed directly by the Director (Studio Lead).
- The approver must not be the same person as the candidate.
- When the Director acts as a fallback approver, the reason for the fallback and the acting approver must be recorded.
- No enrollment may be created until the self-nomination is approved and the final proposed dates are accepted.

Examples:

- Amritha's self-nomination is normally reviewed by Thiyagarajan because he is her Pod Lead.
- If Thiyagarajan is formally unavailable, Amritha's self-nomination may be routed to Anupama Gangadhar as the Director (Studio Lead).
- Thiyagarajan's own self-nomination is reviewed by Anupama Gangadhar because a Pod Lead cannot approve their own request.

The expected journey is:

```text
Employee submits self-nomination
             ↓
Nomination status becomes PENDING_APPROVAL
             ↓
System identifies the correct primary approver
             ↓
Pod member request → own Pod Lead
Pod Lead request → Director (Studio Lead)
             ↓
Director is used for a Pod member only when the Pod Lead is unavailable
             ↓
The request is approved
             ↓
The final dates are confirmed
             ↓
Enrollment is created
```

### BR-002 — Every Active Employee Can Self-Nominate

Every registered and active employee may request a certification for themselves.

### BR-003 — Only Authorised Users Can Nominate Other Employees

Only an authorised Pod Lead may nominate another employee.

The Pod Lead may nominate only an active, eligible member of their own Pod.

For example:

- Thiyagarajan may nominate Amritha because she belongs to his Pod.
- Bhaskaran may nominate Balaji because he belongs to his Pod.
- Bhaskaran must not be allowed to nominate Amritha because she does not belong to his Pod.

### BR-004 — The Application Identifies the User

The application must identify the employee from their current Snowflake login. The user must not be allowed to manually enter or change their identity.

### BR-005 — No Nomination Is Created from the Home Page

Selecting a journey on the home page only moves the user to the next screen. It does not create a nomination, approval or enrollment.

### BR-006 — Pod Leads Are Restricted to Their Own Pod

When a Pod Lead starts a Pod-member nomination, the application must display only the active, eligible members of that Pod.

- A Pod Lead must not be able to search for or select members of another Pod.
- The restriction must be enforced by backend validation as well as by the user interface.
- A user must not be able to bypass the restriction by manually changing a submitted employee identifier.

### BR-007 — Self-Nomination Approval Routing

The application must determine the approver from the candidate's business role and Pod relationship.

| Candidate type | Primary approver | Fallback approver |
|---|---|---|
| Regular Pod member | Candidate's own Pod Lead | Director (Studio Lead), only when the Pod Lead is formally unavailable |
| Pod Lead | Director (Studio Lead) | Not defined in the initial version |

The application must not route a regular Pod member directly to the Director while their Pod Lead is available.

---

## 3. Home-Page Objective

When a user opens the Native App, the platform should answer four questions:

1. Who is the logged-in user?
2. Is the user a registered and active employee?
3. Which Pod and business role are associated with the employee?
4. Which certification actions is the employee authorised to begin?

---

## 4. User Identification

The application should obtain the current Snowflake username from the active Snowflake session. It should then find the matching employee record.

Example mapping:

| Field | Example |
|---|---|
| Snowflake username | `THIYAGARAJAN.C` |
| Employee ID | `EMP002` |
| Employee name | Thiyagarajan Chokalingam |
| Email | thiyagarajan@example.com |
| Pod | Data Engineering |
| Business role | Pod Lead |
| Active status | Active |

The employee information must eventually support the following fields:

| Information | Purpose |
|---|---|
| Employee ID | Stable internal identifier |
| Employee name | Display the employee's name in the app |
| Email | Support future notifications |
| Snowflake username | Match the logged-in Snowflake user to an employee |
| Pod association | Identify the employee's organisational Pod |
| Active status | Prevent inactive profiles from starting a journey |

The Pod information must identify the active Pod Lead.

---

## 5. Fixed Demo and Test Personas

The following people will be used consistently while building and testing the application.

### Director (Studio Lead)

| Person | Business role |
|---|---|
| Anupama Gangadhar | Director (Studio Lead) |

### Pod Leads and Members

| Pod context | Pod Lead | Active Pod member |
|---|---|---|
| Thiyagarajan's Pod | Thiyagarajan | Amritha |
| Durga's Pod | Durga | Nitheesh |
| Kani's Pod | Kani | Deekshita |
| Bhaskaran's Pod | Bhaskaran | Balaji |

The final Pod display names and employee identifiers will be assigned when the physical sample data is created. These relationships are fixed for the initial testing scope.

### Negative-Test Personas

These fictional names are used only to test validation and error handling.

| Test persona | Test condition | Expected home-page result |
|---|---|---|
| Aarav Menon | Unregistered Snowflake user | Registration message; no actions |
| Priya Raman | Registered but inactive employee | Inactive-profile message; no actions |
| Karthik Iyer | Active employee without a Pod | Missing-Pod message; no actions |
| Meera Nair | Pod Lead with no active Pod members | Self-request available; member nomination disabled or explained |

These names must not be treated as real employee records outside the demo dataset.

### Fixed Cross-Pod Validation Examples

The following combinations must succeed when the employee is otherwise eligible:

| Pod Lead | Permitted candidate |
|---|---|
| Thiyagarajan | Amritha |
| Durga | Nitheesh |
| Kani | Deekshita |
| Bhaskaran | Balaji |

The following examples must be rejected:

| Pod Lead | Candidate from another Pod | Expected result |
|---|---|---|
| Bhaskaran | Amritha | Rejected |
| Thiyagarajan | Balaji | Rejected |
| Durga | Deekshita | Rejected |
| Kani | Nitheesh | Rejected |

---

## 6. Access Role and Business Role

Snowflake access roles and platform business roles have different purposes.

### Snowflake Access Role

A Snowflake role controls whether the user can open and use the installed Native App.

Example:

```text
CERT_ENABLEMENT_APP_USER
```

### Platform Business Role

A business role determines what the employee can do inside the certification process.

Examples:

- Employee
- Pod Lead
- Director (Studio Lead)

The platform must determine the business role from the employee and Pod information. It must not assume that a user is a Pod Lead only because of their Snowflake access role.

---

## 7. Home-Page Content

For a recognised Pod Lead, the page should display:

```text
Snowflake Certification Enablement Platform

Welcome, Thiyagarajan Chokalingam

Pod: Data Engineering
Role: Pod Lead

Manage your certification journey or support a member of your Pod.

How would you like to continue?

[ Request a Certification for Myself ]

[ Nominate a Pod Member ]
```

The approved action labels are:

### Request a Certification for Myself

This label is used instead of "Start My Certification Journey" because self-nomination requires approval before an enrollment can be created.

### Nominate a Pod Member

This label is used instead of "Nominate Someone Else" because a Pod Lead should initially be able to nominate only an eligible member of their Pod.

---

## 8. Actions by Business Role

### Regular Employee

A regular employee should see:

```text
[ Request a Certification for Myself ]
```

They must not see the Pod-member nomination action unless they have been explicitly authorised to nominate other employees.

### Pod Lead

A Pod Lead should see:

```text
[ Request a Certification for Myself ]

[ Nominate a Pod Member ]
```

### Director (Studio Lead)

The Director (Studio Lead) may eventually see:

```text
[ Request a Certification for Myself ]

[ Review Pending Requests ]
```

The Director's main business responsibility in this scope is reviewing a Pod Lead's self-nomination and other escalated requests. The complete Director workflow is outside Step 1 and will be designed later.

---

## 9. User Scenarios

### Scenario A — Recognised Active Employee

Conditions:

- The Snowflake username matches an employee record.
- The employee is active.
- The employee has a valid Pod association.

Expected result:

- Display the employee's name.
- Display their Pod and business role.
- Display only the actions permitted for that employee.

### Scenario B — Unregistered Snowflake User

Condition:

- The logged-in Snowflake username does not match an employee record.

Expected message:

> Your Snowflake account is not registered in the Certification Enablement Platform. Please contact the platform administrator.

Expected behaviour:

- Do not display nomination actions.
- Do not allow the user to enter another employee's identity.

### Scenario C — Inactive Employee

Condition:

- The employee record exists, but the employee is inactive.

Expected message:

> Your employee profile is currently inactive. Please contact the platform administrator.

Expected behaviour:

- Do not display nomination actions.

### Scenario D — Missing Pod Association

Condition:

- The employee record exists and is active, but it is not associated with a valid Pod.

Expected message:

> Your employee profile is not associated with a Pod. Please contact the platform administrator.

Expected behaviour for the initial version:

- Do not allow the employee to start either journey.

### Scenario E — Pod Lead with No Active Pod Members

Condition:

- The employee is a valid Pod Lead, but the Pod has no other active eligible members.

Expected behaviour:

- Display the self-nomination action.
- The Pod-member nomination action may be disabled with an explanatory message.

---

## 10. User Stories

### US-001 — Automatic User Identification

> As a logged-in employee, I want the platform to identify me automatically so that I do not need to enter my identity manually.

### US-002 — View Profile Context

> As an employee, I want to see my name, Pod and business role so that I can confirm that the platform has identified me correctly.

### US-003 — Begin Self-Nomination

> As an active employee, I want to request a certification for myself so that the correct approver is selected from my role and Pod relationship.

### US-004 — Begin Pod-Member Nomination

> As a Pod Lead, I want to nominate an eligible member of my own Pod so that the employee can review the certification request.

### US-005 — Restrict Unauthorised Actions

> As the platform owner, I want nomination actions to be shown only to authorised employees so that users cannot nominate employees outside their permitted scope.

### US-006 — Handle Invalid Profiles Safely

> As the platform owner, I want unregistered, inactive or incomplete employee profiles to receive clear guidance without being allowed to start a journey.

---

## 11. Functional Requirements

| ID | Requirement |
|---|---|
| FR-001 | The application must obtain the current Snowflake username from the active session. |
| FR-002 | The application must locate the employee associated with that username. |
| FR-003 | The application must confirm that the employee is active. |
| FR-004 | The application must confirm that the employee has a valid Pod association. |
| FR-005 | The application must display the employee's name, Pod and business role. |
| FR-006 | The application must allow every eligible active employee to begin self-nomination. |
| FR-007 | The application must show Pod-member nomination only to authorised Pod Leads. |
| FR-008 | The application must not allow the user to manually change their identity. |
| FR-009 | The application must not create a nomination or enrollment from the home page. |
| FR-010 | The application must show clear guidance when the employee profile is unavailable, inactive or incomplete. |
| FR-011 | The application must show a Pod Lead only the active, eligible members of their own Pod. |
| FR-012 | Backend validation must reject an attempt to nominate an employee from another Pod. |
| FR-013 | A regular Pod member's self-nomination must be routed to the employee's own Pod Lead. |
| FR-014 | A Pod Lead's self-nomination must be routed to the Director (Studio Lead). |
| FR-015 | A regular Pod member's self-nomination may be routed to the Director only when the Pod Lead is formally unavailable. |
| FR-016 | Director fallback routing must record the original approver, acting approver and fallback reason. |

---

## 12. Wireframe

```text
┌─────────────────────────────────────────────────────┐
│ Snowflake Certification Enablement Platform         │
│                                                     │
│ Welcome, Thiyagarajan Chokalingam                    │
│                                                     │
│ Pod: Data Engineering                               │
│ Role: Pod Lead                                      │
│                                                     │
│ Manage your certification journey or support a      │
│ member of your Pod.                                 │
│                                                     │
│ How would you like to continue?                     │
│                                                     │
│ [ Request a Certification for Myself ]              │
│                                                     │
│ [ Nominate a Pod Member ]                           │
└─────────────────────────────────────────────────────┘
```

---

## 13. Acceptance Criteria

### AC-001 — Registered User

When a registered active employee opens the app, their name is displayed automatically.

### AC-002 — Pod Context

The app displays the employee's current Pod.

### AC-003 — Business Role

The app correctly determines whether the employee is a regular employee, Pod Lead or Director (Studio Lead).

### AC-004 — Self-Nomination Entry

Every eligible active employee can see `Request a Certification for Myself`.

### AC-005 — Pod-Member Nomination Entry

Only an authorised Pod Lead can see `Nominate a Pod Member`.

### AC-006 — Unregistered User

An unregistered Snowflake user sees a clear message and no nomination actions.

### AC-007 — Inactive User

An inactive employee sees a clear message and cannot begin either journey.

### AC-008 — Identity Protection

The user cannot manually change or impersonate the employee identity associated with their Snowflake login.

### AC-009 — Navigation Only

Clicking a home-page action navigates to the relevant next step but does not create a nomination or enrollment.

### AC-010 — Missing Pod

An employee without a valid Pod association receives a clear message and cannot begin a journey in the initial version.

### AC-011 — Own-Pod Member List

When a Pod Lead begins a member nomination, the selection list contains only active, eligible members of that Pod.

### AC-012 — Cross-Pod Nomination Is Rejected

If a Pod Lead attempts to submit the identifier of an employee from another Pod, the backend rejects the request and no nomination is created.

### AC-013 — Pod-Member Self-Nomination Routing

When Amritha self-nominates and Thiyagarajan is available, the request is routed to Thiyagarajan and not to Anupama.

### AC-014 — Pod-Lead Self-Nomination Routing

When Thiyagarajan self-nominates, the request is routed to Anupama Gangadhar as Director (Studio Lead).

### AC-015 — Director Fallback Routing

When Thiyagarajan is formally unavailable, Amritha's self-nomination may be routed to Anupama, and the fallback reason is recorded.

---

## 14. Initial Test Scenarios

| Test ID | Scenario | Expected result |
|---|---|---|
| T-001 | Active regular employee opens the app | Name and Pod shown; only self-nomination action shown |
| T-002 | Active Pod Lead opens the app | Name and Pod shown; both actions shown |
| T-003 | Anupama Gangadhar opens the app as Director (Studio Lead) | Self-request and pending-review actions shown |
| T-004 | Unregistered user opens the app | Registration error shown; no actions shown |
| T-005 | Inactive employee opens the app | Inactive-profile message shown; no actions shown |
| T-006 | Employee without a Pod opens the app | Missing-Pod message shown; no actions shown |
| T-007 | Pod Lead has no active members | Self-nomination remains available; member nomination disabled or explained |
| T-008 | User attempts to change identity | Action is not available |
| T-009 | Thiyagarajan starts a Pod-member nomination | Amritha is available for selection |
| T-010 | Bhaskaran starts a Pod-member nomination | Balaji is available; Amritha is not available |
| T-011 | Bhaskaran submits Amritha's employee identifier manually | Backend rejects the request; no nomination is created |
| T-012 | Amritha self-nominates while Thiyagarajan is available | Thiyagarajan is assigned as approver |
| T-013 | Amritha self-nominates while Thiyagarajan is formally unavailable | Anupama is assigned as fallback approver; reason is recorded |
| T-014 | Thiyagarajan self-nominates | Anupama is assigned as approver |

---

## 15. Physical-Model Implications

This step creates requirements for the later physical model. At minimum, the final implementation must be able to determine:

- The employee associated with a Snowflake username
- Whether the employee is active
- Which Pod the employee belongs to
- Who leads the Pod
- Whether the employee is the Director (Studio Lead)
- Whether the primary approver is currently available
- Which approver was originally selected
- Whether fallback approval was used and why

The exact tables, keys and Snowflake data types will be finalised during physical modelling. This document does not approve a final table design.

---

## 16. Streamlit Implementation Outline

When implementation begins, the Step 1 Streamlit page will:

1. Get the current Snowflake user from the active session.
2. Find the matching employee profile.
3. Validate the active status.
4. Find the employee's Pod.
5. Determine the employee's business role.
6. Display the welcome message and profile context.
7. Display only the permitted journey buttons.
8. Display an appropriate error state when validation fails.

No certification catalogue, nomination, approval or enrollment logic will be implemented as part of Step 1.

---

## 17. Out of Scope for Step 1

The following items will be handled later:

- Certification catalogue
- Self-nomination form
- Pod-member selection
- Nomination submission
- Approver selection
- Candidate notification
- Candidate response
- Date-change requests
- Enrollment creation
- Syllabus display
- Learning-plan generation
- Progress tracking
- Readiness calculation
- Reminder processing
- Reporting

---

## 18. Definition of Done

Step 1 is complete when:

- The approved business rules are documented.
- User identification behaviour is defined.
- Role-based home-page actions are defined.
- Error and incomplete-profile scenarios are defined.
- User stories and acceptance criteria are approved.
- The wireframe is accepted.
- The new Snowflake development environment is available.
- The Streamlit home page passes the Step 1 test scenarios.

Only after Step 1 is complete should the project proceed to the certification catalogue and nomination journeys.
