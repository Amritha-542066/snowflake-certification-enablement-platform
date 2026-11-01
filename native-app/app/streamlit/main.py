import streamlit as st


st.set_page_config(
    page_title="Snowflake Certification Enablement Platform",
    layout="wide",
)


viewer_user_name = st.user.user_name or "Unknown user"


st.title("Snowflake Certification Enablement Platform")

st.write(
    "Manage certification requests, approvals, learning plans "
    "and certification progress from one place."
)

st.divider()

st.subheader("Signed-in user")

user_column, role_column = st.columns(2)

with user_column:
    st.metric(
        label="Snowflake login",
        value=viewer_user_name,
    )

with role_column:
    st.metric(
        label="Platform role",
        value="Pending profile mapping",
    )

st.divider()

st.subheader("Certification journey")

st.info(
    "The application shell is working. Employee identity, Pod membership "
    "and permitted actions will be connected in the next implementation step."
)

action_one, action_two, action_three = st.columns(3)

with action_one:
    st.button(
        "Request a Certification for Myself",
        disabled=True,
        use_container_width=True,
    )

with action_two:
    st.button(
        "Nominate a Pod Member",
        disabled=True,
        use_container_width=True,
    )

with action_three:
    st.button(
        "Review Pending Requests",
        disabled=True,
        use_container_width=True,
    )

st.caption(
    "The buttons are temporarily disabled while the user-identity "
    "and authorisation foundation is being created."
)