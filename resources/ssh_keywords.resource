*** Settings ***
Documentation     Reusable keywords for SSH-based system validation of the BeagleBone Black DUT.
...
...               A single SSH session is established once (intended for Suite Setup) and
...               reused across all tests in a suite, mirroring the single-capture pattern
...               used for the serial boot log in Category 1.
...
...               Connection failures are captured rather than raised, so that the first
...               test in the suite can report a clear, specific failure message instead
...               of every test in the suite failing with an opaque "suite setup failed".
Library           SSHLibrary
Library           String
Library           Collections
Variables         ../config/secrets.py
Variables         ../config/constants.py


*** Keywords ***
Establish BBB SSH Session
    [Documentation]    Opens an SSH connection to the DUT and logs in using the credentials
    ...    from config/secrets.py. Never raises: stores success/failure in
    ...    ${SSH_SESSION_ESTABLISHED} and, on failure, the error in ${SSH_SESSION_ERROR}, so
    ...    that Suite Setup itself always succeeds and individual tests can report clearly.
    ...    On success, also records the DUT's current uptime for later reboot detection.
    ${status}    ${error}=    Run Keyword And Ignore Error
    ...    Open Connection And Login
    IF    '${status}' == 'PASS'
        Set Suite Variable    ${SSH_SESSION_ESTABLISHED}    ${TRUE}
        Set Suite Variable    ${SSH_SESSION_ERROR}    ${EMPTY}
        ${uptime_output}=    Execute Command    cat /proc/uptime
        ${start_uptime}=    Get Uptime Seconds From Output    ${uptime_output}
        Set Suite Variable    ${SSH_SESSION_START_UPTIME}    ${start_uptime}
    ELSE
        Set Suite Variable    ${SSH_SESSION_ESTABLISHED}    ${FALSE}
        Set Suite Variable    ${SSH_SESSION_ERROR}    ${error}
        Set Suite Variable    ${SSH_SESSION_START_UPTIME}    ${0}
    END

Open Connection And Login
    [Documentation]    Raw connect-and-login step, isolated so it can be wrapped by
    ...    'Run Keyword And Ignore Error' without swallowing unrelated setup logic.
    Open Connection    ${BBB_IP}
    Login    ${BBB_SSH_USER}    ${BBB_SSH_PASSWORD}

Close BBB SSH Session
    [Documentation]    Closes all open SSH connections. Safe to call even if no connection
    ...    was ever successfully established.
    Run Keyword And Ignore Error    Close All Connections

Ensure SSH Session Is Available
    [Documentation]    Skips the current test with a clear reason if Suite Setup could not
    ...    establish the SSH session, instead of letting the test fail on a confusing
    ...    "no connection open" error from SSHLibrary.
    Skip If    not ${SSH_SESSION_ESTABLISHED}
    ...    SSH session was not established: ${SSH_SESSION_ERROR}

Get Uptime Seconds From Output
    [Documentation]    Parses the first (uptime) field out of the raw contents of
    ...    /proc/uptime and returns it as a number.
    [Arguments]    ${proc_uptime_output}
    @{parts}=    Split String    ${proc_uptime_output}
    ${uptime}=    Convert To Number    ${parts}[0]
    RETURN    ${uptime}