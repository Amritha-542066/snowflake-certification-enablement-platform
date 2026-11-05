import json
from datetime import date, timedelta

import streamlit as st
from snowflake.snowpark.context import get_active_session


st.set_page_config(
    page_title="Snowflake Certification Enablement Platform",
    layout="wide",
)


session = get_active_session()
viewer_user_name = (st.user.user_name or "Unknown user").upper()

# Persona Preview is a development and demonstration feature.
# It does not replace the authenticated Snowflake identity and does not
# perform nomination, approval or other transactional writes.
PERSONA_PREVIEW_DEVELOPERS = {"AMRITHAK"}
UNREGISTERED_PREVIEW_USER = "AARAVMENON"


def load_user_profile(user_name):
    """Return the registered platform profile for a Snowflake username."""

    return session.sql(
        """
        SELECT
            EMPLOYEE_ID,
            SNOWFLAKE_USERNAME,
            EMPLOYEE_NAME,
            DESIGNATION,
            EMPLOYEE_ACTIVE_FLAG,
            ROLE_CODE,
            ROLE_NAME,
            POD_ID,
            POD_NAME,
            POD_LEAD_EMPLOYEE_ID,
            POD_LEAD_NAME
        FROM APP_SCHEMA.VW_USER_CONTEXT
        WHERE UPPER(SNOWFLAKE_USERNAME) = UPPER(?)
        """,
        params=[user_name],
    ).collect()


def load_registered_preview_personas():
    """Return one preview option for every registered demo user."""

    rows = session.sql(
        """
        SELECT
            SNOWFLAKE_USERNAME,
            EMPLOYEE_NAME,
            EMPLOYEE_ACTIVE_FLAG,
            ROLE_NAME,
            POD_NAME
        FROM APP_SCHEMA.VW_USER_CONTEXT
        WHERE SNOWFLAKE_USERNAME IS NOT NULL
        ORDER BY EMPLOYEE_NAME
        """
    ).collect()

    personas = {}

    for row in rows:
        user_name = row["SNOWFLAKE_USERNAME"].upper()

        # Protect against duplicate rows if a person later receives more than
        # one related record in the user-context view.
        if user_name in personas:
            continue

        if not row["EMPLOYEE_ACTIVE_FLAG"]:
            persona_type = "Inactive employee"
        elif row["ROLE_NAME"] is None:
            persona_type = "No active platform role"
        elif row["ROLE_NAME"] == "Pod Member" and row["POD_NAME"] is None:
            persona_type = "Pod Member without a Pod"
        else:
            persona_type = row["ROLE_NAME"]

        personas[user_name] = (
            f"{row['EMPLOYEE_NAME']} - "
            f"{persona_type or 'Registered employee'}"
        )

    return personas


def count_active_pod_members(employee_id):
    """Return the number of active members led by a Pod Lead."""

    result = session.sql(
        """
        SELECT
            COUNT(*) AS ACTIVE_MEMBER_COUNT
        FROM CORE.PODS P

        INNER JOIN CORE.POD_MEMBERSHIPS PM
            ON P.POD_ID = PM.POD_ID
           AND PM.ACTIVE_FLAG = TRUE

        INNER JOIN CORE.EMPLOYEES MEMBER
            ON PM.EMPLOYEE_ID = MEMBER.EMPLOYEE_ID
           AND MEMBER.ACTIVE_FLAG = TRUE

        WHERE P.POD_LEAD_EMPLOYEE_ID = ?
          AND P.ACTIVE_FLAG = TRUE
        """,
        params=[employee_id],
    ).collect()

    return result[0]["ACTIVE_MEMBER_COUNT"]


def load_active_certifications():
    """Return the active certifications available for nomination."""

    return session.sql(
        """
        SELECT
            CERTIFICATION_ID,
            CERTIFICATION_CODE,
            CERTIFICATION_NAME,
            PROVIDER_NAME,
            CERTIFICATION_LEVEL,
            PREREQUISITE_CERTIFICATION_ID,
            DISPLAY_ORDER
        FROM APP_SCHEMA.VW_ACTIVE_CERTIFICATIONS
        ORDER BY DISPLAY_ORDER
        """
    ).collect()


def load_eligible_pod_members(pod_lead_employee_id):
    """Return active members of the specified Pod Lead's own active Pod."""

    return session.sql(
        """
        SELECT
            POD_ID,
            POD_NAME,
            MEMBER_EMPLOYEE_ID,
            MEMBER_SNOWFLAKE_USERNAME,
            MEMBER_NAME,
            MEMBER_DESIGNATION
        FROM APP_SCHEMA.VW_ELIGIBLE_POD_MEMBERS
        WHERE POD_LEAD_EMPLOYEE_ID = ?
        ORDER BY MEMBER_NAME
        """,
        params=[pod_lead_employee_id],
    ).collect()


def normalize_procedure_result(result):
    """Convert a procedure VARIANT result into a Python dictionary."""

    if isinstance(result, dict):
        return result

    if isinstance(result, str):
        return json.loads(result)

    return dict(result)


def submit_nomination(
    nominator_employee_id,
    candidate_employee_id,
    certification_id,
    preparation_start_date,
    target_completion_date,
    request_notes,
    created_by_snowflake_username,
):
    """Call the owner-rights procedure that validates and stores a request."""

    result = session.call(
        "APP_SCHEMA.SP_SUBMIT_NOMINATION",
        nominator_employee_id,
        candidate_employee_id,
        certification_id,
        preparation_start_date,
        target_completion_date,
        request_notes,
        created_by_snowflake_username,
    )

    return normalize_procedure_result(result)


def load_pending_reviews(reviewer_employee_id):
    """Return pending approval requests assigned to one reviewer."""

    return session.sql(
        """
        SELECT
            NOMINATION_ID,
            NOMINATION_TYPE,
            NOMINATOR_NAME,
            CANDIDATE_NAME,
            CERTIFICATION_NAME,
            POD_NAME,
            PREPARATION_START_DATE,
            TARGET_COMPLETION_DATE,
            NOMINATION_STATUS,
            REQUEST_NOTES,
            CREATED_AT
        FROM APP_SCHEMA.VW_NOMINATION_DETAILS
        WHERE ASSIGNED_REVIEWER_EMPLOYEE_ID = ?
          AND NOMINATION_STATUS = 'PENDING_APPROVAL'
        ORDER BY CREATED_AT
        """,
        params=[reviewer_employee_id],
    ).collect()


def decide_nomination(
    nomination_id,
    reviewer_employee_id,
    decision,
    decision_notes,
):
    """Approve or reject a request assigned to the current reviewer."""

    result = session.call(
        "APP_SCHEMA.SP_DECIDE_NOMINATION",
        nomination_id,
        reviewer_employee_id,
        decision,
        decision_notes,
    )

    return normalize_procedure_result(result)


st.title("Snowflake Certification Enablement Platform")

st.write(
    "Manage certification requests, approvals, learning plans "
    "and certification progress from one place."
)

action_message = st.session_state.pop("action_message", None)

if action_message:
    st.success(action_message)


# Developer-only Persona Preview
preview_active = False
context_user_name = viewer_user_name

if viewer_user_name in PERSONA_PREVIEW_DEVELOPERS:
    registered_personas = load_registered_preview_personas()

    preview_labels = {
        "__ACTUAL_USER__": f"Actual signed-in user - {viewer_user_name}",
        **registered_personas,
        UNREGISTERED_PREVIEW_USER: "Aarav Menon - Unregistered user",
    }

    preview_options = ["__ACTUAL_USER__"]
    preview_options.extend(registered_personas.keys())
    preview_options.append(UNREGISTERED_PREVIEW_USER)

    with st.sidebar:
        st.header("Developer tools")

        selected_persona = st.selectbox(
            "Persona Preview",
            options=preview_options,
            format_func=lambda value: preview_labels[value],
            help=(
                "Preview how the home page behaves for a demo persona. "
                "This does not change the authenticated Snowflake user."
            ),
        )

        st.caption(
            "Preview mode is read-only and intended only for development "
            "and live demonstrations."
        )

    if selected_persona != "__ACTUAL_USER__":
        preview_active = True
        context_user_name = selected_persona


# Clear an open form when the developer changes the previewed persona.
if st.session_state.get("profile_context_user") != context_user_name:
    st.session_state["profile_context_user"] = context_user_name
    st.session_state.pop("nomination_type", None)
    st.session_state.pop("show_review_queue", None)


st.divider()

if preview_active:
    st.warning(
        "Developer Persona Preview is active. "
        f"You are previewing {preview_labels[context_user_name]}. "
        f"The actual signed-in Snowflake user remains {viewer_user_name}. "
        "No transactional data will be created from this preview."
    )


profile_rows = load_user_profile(context_user_name)


if not profile_rows:
    st.error(
        "This Snowflake login is not registered in the Certification "
        "Enablement Platform. Please contact the Studio Lead."
    )

    st.caption(f"Profile being evaluated: {context_user_name}")
    st.caption(f"Actual signed-in Snowflake login: {viewer_user_name}")
    st.stop()


profile = profile_rows[0]


if not profile["EMPLOYEE_ACTIVE_FLAG"]:
    st.error(
        "This employee profile is inactive and cannot currently access "
        "certification actions."
    )

    st.caption(f"Profile being evaluated: {context_user_name}")
    st.caption(f"Actual signed-in Snowflake login: {viewer_user_name}")
    st.stop()


if profile["ROLE_CODE"] is None:
    st.error(
        "This employee profile does not have an active platform role. "
        "Please contact the Studio Lead."
    )

    st.caption(f"Profile being evaluated: {context_user_name}")
    st.stop()


if profile["ROLE_CODE"] == "POD_MEMBER" and profile["POD_ID"] is None:
    st.error(
        "This employee profile is active, but is not assigned to an "
        "active Pod. A Pod assignment is required before self-nomination."
    )

    st.caption(f"Profile being evaluated: {context_user_name}")
    st.stop()


st.subheader(f"Welcome, {profile['EMPLOYEE_NAME']}")

identity_one, identity_two, identity_three = st.columns(3)

with identity_one:
    st.metric(
        label="Platform role",
        value=profile["ROLE_NAME"],
    )

with identity_two:
    st.metric(
        label="Pod",
        value=profile["POD_NAME"] or "Not applicable",
    )

with identity_three:
    st.metric(
        label="Pod Lead",
        value=profile["POD_LEAD_NAME"] or "Not applicable",
    )


if preview_active:
    st.caption(f"Previewed Snowflake login: {context_user_name}")
    st.caption(f"Actual signed-in Snowflake login: {viewer_user_name}")
else:
    st.caption(f"Signed-in Snowflake login: {viewer_user_name}")


st.divider()

st.subheader("Available actions")

role_code = profile["ROLE_CODE"]
active_member_count = 0

if role_code == "POD_LEAD":
    active_member_count = count_active_pod_members(
        profile["EMPLOYEE_ID"]
    )


# Studio Lead self-request routing is not enabled until the business owner
# identifies an approver above the Studio Lead.
self_request_allowed = role_code in {"POD_MEMBER", "POD_LEAD"}

pod_nomination_allowed = (
    role_code == "POD_LEAD"
    and active_member_count > 0
)

review_requests_allowed = role_code in {"POD_LEAD", "STUDIO_LEAD"}


action_one, action_two, action_three = st.columns(3)

with action_one:
    self_request_clicked = st.button(
        "Request a Certification for Myself",
        disabled=not self_request_allowed,
        use_container_width=True,
    )

with action_two:
    pod_nomination_clicked = st.button(
        "Nominate a Pod Member",
        disabled=not pod_nomination_allowed,
        use_container_width=True,
    )

with action_three:
    review_requests_clicked = st.button(
        "Review Pending Requests",
        disabled=not review_requests_allowed,
        use_container_width=True,
    )


if self_request_clicked:
    st.session_state["nomination_type"] = "SELF"
    st.session_state["show_review_queue"] = False

if pod_nomination_clicked:
    st.session_state["nomination_type"] = "POD_MEMBER"
    st.session_state["show_review_queue"] = False

if review_requests_clicked:
    st.session_state.pop("nomination_type", None)
    st.session_state["show_review_queue"] = True


nomination_type = st.session_state.get("nomination_type")


if nomination_type in {"SELF", "POD_MEMBER"}:
    st.divider()
    st.subheader("Create a certification request")

    candidate_employee_id = profile["EMPLOYEE_ID"]
    candidate_name = profile["EMPLOYEE_NAME"]
    candidate_available = True

    if nomination_type == "SELF":
        st.write(f"Candidate: **{candidate_name}**")
    else:
        eligible_members = load_eligible_pod_members(
            profile["EMPLOYEE_ID"]
        )

        if not eligible_members:
            candidate_available = False
            st.warning(
                "No active members of your own Pod are available "
                "for nomination."
            )
        else:
            member_by_id = {
                row["MEMBER_EMPLOYEE_ID"]: row
                for row in eligible_members
            }

            selected_member_id = st.selectbox(
                "Pod member",
                options=list(member_by_id.keys()),
                format_func=lambda employee_id: (
                    f"{member_by_id[employee_id]['MEMBER_NAME']} - "
                    f"{member_by_id[employee_id]['MEMBER_DESIGNATION']}"
                ),
                key=f"member_{context_user_name}",
            )

            selected_member = member_by_id[selected_member_id]
            candidate_employee_id = selected_member_id
            candidate_name = selected_member["MEMBER_NAME"]

            st.caption(
                f"Eligible member of {selected_member['POD_NAME']}"
            )

    certification_rows = load_active_certifications()

    if not certification_rows:
        st.warning("No active certifications are currently available.")
    elif candidate_available:
        certification_by_id = {
            row["CERTIFICATION_ID"]: row
            for row in certification_rows
        }

        selected_certification_id = st.selectbox(
            "Available certifications",
            options=list(certification_by_id.keys()),
            format_func=lambda certification_id: (
                certification_by_id[certification_id][
                    "CERTIFICATION_NAME"
                ]
            ),
            key=(
                f"certification_{context_user_name}_{nomination_type}"
            ),
        )

        selected_certification = certification_by_id[
            selected_certification_id
        ]

        detail_one, detail_two, detail_three = st.columns(3)

        with detail_one:
            st.metric(
                label="Provider",
                value=selected_certification["PROVIDER_NAME"],
            )

        with detail_two:
            st.metric(
                label="Certification level",
                value=selected_certification["CERTIFICATION_LEVEL"],
            )

        with detail_three:
            prerequisite_id = selected_certification[
                "PREREQUISITE_CERTIFICATION_ID"
            ]

            if prerequisite_id:
                prerequisite = certification_by_id.get(prerequisite_id)
                prerequisite_value = (
                    prerequisite["CERTIFICATION_NAME"]
                    if prerequisite
                    else prerequisite_id
                )
            else:
                prerequisite_value = "None"

            st.metric(
                label="Prerequisite",
                value=prerequisite_value,
            )

        st.caption(
            "Certification code: "
            f"{selected_certification['CERTIFICATION_CODE']}"
        )

        if preview_active:
            st.warning(
                "Persona Preview is active. You may inspect the complete "
                "form, but submission is disabled because Preview is read-only."
            )

        with st.form(
            key=f"nomination_form_{context_user_name}_{nomination_type}"
        ):
            date_one, date_two = st.columns(2)

            with date_one:
                preparation_start_date = st.date_input(
                    "Preparation start date",
                    value=date.today() + timedelta(days=1),
                )

            with date_two:
                target_completion_date = st.date_input(
                    "Target completion date",
                    value=date.today() + timedelta(days=56),
                )

            request_notes = st.text_area(
                "Notes (optional)",
                placeholder=(
                    "Add any information that the reviewer or candidate "
                    "should know."
                ),
                max_chars=2000,
            )

            submit_column, cancel_column = st.columns(2)

            with submit_column:
                submit_clicked = st.form_submit_button(
                    "Submit Request",
                    disabled=preview_active,
                    use_container_width=True,
                )

            with cancel_column:
                cancel_clicked = st.form_submit_button(
                    "Cancel",
                    use_container_width=True,
                )

        if cancel_clicked:
            st.session_state.pop("nomination_type", None)
            st.rerun()

        if submit_clicked:
            if target_completion_date <= preparation_start_date:
                st.error(
                    "The target completion date must be later than "
                    "the preparation start date."
                )
            else:
                try:
                    submission_result = submit_nomination(
                        nominator_employee_id=profile["EMPLOYEE_ID"],
                        candidate_employee_id=candidate_employee_id,
                        certification_id=selected_certification_id,
                        preparation_start_date=preparation_start_date,
                        target_completion_date=target_completion_date,
                        request_notes=request_notes,
                        created_by_snowflake_username=viewer_user_name,
                    )

                    if submission_result.get("SUCCESS"):
                        st.success(submission_result["MESSAGE"])

                        result_one, result_two, result_three = st.columns(3)

                        with result_one:
                            st.metric(
                                "Candidate",
                                candidate_name,
                            )

                        with result_two:
                            st.metric(
                                "Status",
                                submission_result["STATUS"],
                            )

                        with result_three:
                            st.metric(
                                "Nomination ID",
                                submission_result["NOMINATION_ID"],
                            )
                    else:
                        st.error(submission_result["MESSAGE"])

                except Exception as error:
                    st.error(
                        "The request could not be submitted. "
                        f"Technical details: {error}"
                    )


if st.session_state.get("show_review_queue"):
    st.divider()
    st.subheader("Pending certification requests")

    pending_reviews = load_pending_reviews(profile["EMPLOYEE_ID"])

    if not pending_reviews:
        st.info("You do not currently have any pending approval requests.")
    else:
        st.write(
            f"{len(pending_reviews)} request(s) require your review."
        )

        if preview_active:
            st.warning(
                "Persona Preview is active. You may inspect the assigned "
                "requests, but approval and rejection are disabled."
            )

        for request in pending_reviews:
            expander_label = (
                f"{request['CANDIDATE_NAME']} - "
                f"{request['CERTIFICATION_NAME']}"
            )

            with st.expander(expander_label, expanded=True):
                request_one, request_two, request_three = st.columns(3)

                with request_one:
                    st.metric(
                        "Candidate",
                        request["CANDIDATE_NAME"],
                    )

                with request_two:
                    st.metric(
                        "Certification",
                        request["CERTIFICATION_NAME"],
                    )

                with request_three:
                    st.metric(
                        "Status",
                        request["NOMINATION_STATUS"],
                    )

                st.write(f"**Requested by:** {request['NOMINATOR_NAME']}")
                st.write(
                    "**Preparation period:** "
                    f"{request['PREPARATION_START_DATE']} to "
                    f"{request['TARGET_COMPLETION_DATE']}"
                )

                if request["POD_NAME"]:
                    st.write(f"**Pod:** {request['POD_NAME']}")

                st.write(
                    "**Request notes:** "
                    f"{request['REQUEST_NOTES'] or 'No notes provided'}"
                )

                st.caption(
                    f"Nomination ID: {request['NOMINATION_ID']}"
                )

                with st.form(
                    key=f"decision_{request['NOMINATION_ID']}"
                ):
                    decision_notes = st.text_area(
                        "Decision notes (optional)",
                        max_chars=2000,
                        key=f"notes_{request['NOMINATION_ID']}",
                    )

                    approve_column, reject_column = st.columns(2)

                    with approve_column:
                        approve_clicked = st.form_submit_button(
                            "Approve",
                            disabled=preview_active,
                            use_container_width=True,
                        )

                    with reject_column:
                        reject_clicked = st.form_submit_button(
                            "Reject",
                            disabled=preview_active,
                            use_container_width=True,
                        )

                if approve_clicked or reject_clicked:
                    decision = (
                        "APPROVED" if approve_clicked else "REJECTED"
                    )

                    try:
                        decision_result = decide_nomination(
                            nomination_id=request["NOMINATION_ID"],
                            reviewer_employee_id=profile["EMPLOYEE_ID"],
                            decision=decision,
                            decision_notes=decision_notes,
                        )

                        if decision_result.get("SUCCESS"):
                            st.session_state["action_message"] = (
                                f"Request {request['NOMINATION_ID']} was "
                                f"{decision.lower()} successfully."
                            )
                            st.rerun()
                        else:
                            st.error(decision_result["MESSAGE"])

                    except Exception as error:
                        st.error(
                            "The decision could not be recorded. "
                            f"Technical details: {error}"
                        )

    if st.button(
        "Close Pending Requests",
        use_container_width=True,
    ):
        st.session_state["show_review_queue"] = False
        st.rerun()


if preview_active:
    st.caption(
        "Preview note: these controls validate visibility and access rules "
        "only. They do not create or update application records."
    )


if role_code == "POD_MEMBER":
    st.info(
        "You can request a certification for yourself. Your Pod Lead "
        "will review the request."
    )

elif role_code == "POD_LEAD" and active_member_count > 0:
    st.info(
        "You can request a certification for yourself or nominate "
        "an active member of your own Pod."
    )

elif role_code == "POD_LEAD":
    st.warning(
        "You can request a certification for yourself, but your Pod "
        "currently has no active members available for nomination."
    )

elif role_code == "STUDIO_LEAD":
    st.info(
        "You can review certification requests routed to the Studio Lead. "
        "Studio Lead self-request routing requires a separate business decision."
    )


st.caption(
    "This milestone implements identity-aware certification requests, "
    "own-Pod nomination controls and Snowflake-backed request storage."
)
