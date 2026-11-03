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


st.title("Snowflake Certification Enablement Platform")

st.write(
    "Manage certification requests, approvals, learning plans "
    "and certification progress from one place."
)


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


self_request_allowed = True

pod_nomination_allowed = (
    role_code == "POD_LEAD"
    and active_member_count > 0
)

review_requests_allowed = role_code == "STUDIO_LEAD"


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

if pod_nomination_clicked:
    st.session_state["nomination_type"] = "POD_MEMBER"

if review_requests_clicked:
    st.info(
        "The approval queue will be added in a later implementation step."
    )


nomination_type = st.session_state.get("nomination_type")


if nomination_type in {"SELF", "POD_MEMBER"}:
    st.divider()
    st.subheader("Choose a certification")

    if nomination_type == "SELF":
        st.write(
            f"Certification request for: {profile['EMPLOYEE_NAME']}"
        )
    else:
        st.write(
            "Select the certification first. Pod-member selection will "
            "be added in the next step."
        )

    certification_rows = load_active_certifications()

    if not certification_rows:
        st.warning(
            "No active certifications are currently available."
        )
    else:
        certification_by_id = {
            row["CERTIFICATION_ID"]: row
            for row in certification_rows
        }

        certification_options = list(certification_by_id.keys())

        selected_certification_id = st.selectbox(
            "Available certifications",
            options=certification_options,
            format_func=lambda certification_id: (
                certification_by_id[certification_id][
                    "CERTIFICATION_NAME"
                ]
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
                prerequisite_name = certification_by_id.get(
                    prerequisite_id,
                    {},
                )

                prerequisite_value = (
                    prerequisite_name["CERTIFICATION_NAME"]
                    if prerequisite_name
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
                "Persona Preview is active. You can review the catalogue, "
                "but no nomination will be submitted."
            )

        continue_column, cancel_column = st.columns(2)

        with continue_column:
            st.button(
                "Continue",
                disabled=True,
                use_container_width=True,
                help=(
                    "Submission will be enabled after the nomination "
                    "form is implemented."
                ),
            )

        with cancel_column:
            if st.button(
                "Cancel",
                use_container_width=True,
            ):
                st.session_state.pop("nomination_type", None)
                st.rerun()


if preview_active:
    st.caption(
        "Preview note: these buttons validate visibility and access rules "
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
        "You can request a certification for yourself and review "
        "requests routed to the Studio Lead."
    )


st.caption(
    "This milestone validates user identity and permitted home-page actions. "
    "The nomination forms and approval workflow are implemented separately."
)