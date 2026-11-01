import streamlit as st
from snowflake.snowpark.context import get_active_session


st.set_page_config(
    page_title="Snowflake Certification Enablement Platform",
    layout="wide",
)


session = get_active_session()

current_user = session.sql(
    """
    SELECT
        CURRENT_USER() AS LOGIN_NAME,
        CURRENT_ROLE() AS SESSION_ROLE
    """
).collect()[0]


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
        value=current_user["LOGIN_NAME"],
    )

with role_column:
    st.metric(
        label="Current session role",
        value=current_user["SESSION_ROLE"],
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