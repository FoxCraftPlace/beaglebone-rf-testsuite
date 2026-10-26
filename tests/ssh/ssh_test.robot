*** Settings ***
Documentation     Category 3: SSH-based system validation for the BeagleBone Black DUT.
...
...               A single SSH session is opened once in Suite Setup and reused by every
...               test below, mirroring the single-capture pattern from Category 1's boot
...               log. If the session cannot be established, the first test reports it
...               clearly and every later test is skipped rather than failing on a
...               confusing low-level SSH error.
Resource          ../../resources/ssh_keywords.resource
Suite Setup       Establish BBB SSH Session
Suite Teardown    Close BBB SSH Session
Test Tags         ssh


*** Test Cases ***
SSH Login Should Succeed With Root Credentials
    [Documentation]    Confirms the SSH session set up in Suite Setup was actually
    ...    established. Baseline smoke test for Category 3; if this fails, every other
    ...    test in this suite is skipped.
    [Tags]    smoke    critical
    Should Be True    ${SSH_SESSION_ESTABLISHED}
    ...    msg=SSH session could not be established: ${SSH_SESSION_ERROR}

System Uptime Should Be Positive And Sane
    [Documentation]    Reads /proc/uptime over SSH and checks the value is a positive
    ...    number within a sane upper bound, catching parsing bugs that would otherwise
    ...    silently return garbage.
    [Setup]    Ensure SSH Session Is Available
    ${output}=    Execute Command    cat /proc/uptime
    ${uptime}=    Get Uptime Seconds From Output    ${output}
    Should Be True    0 < ${uptime} < ${MAX_SANE_UPTIME_SEC}
    ...    msg=Uptime ${uptime}s is outside the sane range (0, ${MAX_SANE_UPTIME_SEC})

Kernel Release Should Match The Expected Version
    [Documentation]    Compares 'uname -r' over SSH with EXPECTED_KERNEL_RELEASE from
    ...    config/constants.py, so a different running kernel is caught. The constant
    ...    holds the release the U-Boot log reports loading (vmlinuz-<release>).
    [Setup]    Ensure SSH Session Is Available
    ${output}=    Execute Command    uname -r
    Should Be Equal As Strings    ${output}    ${EXPECTED_KERNEL_RELEASE}

Root Filesystem Usage Should Be Below Threshold
    [Documentation]    Confirms the root filesystem has not filled up after repeated test
    ...    cycles (reboots, log captures, etc).
    [Setup]    Ensure SSH Session Is Available
    ${output}=    Execute Command    df --output=pcent / | tail -1
    ${usage}=    Remove String    ${output}    %
    ${usage}=    Convert To Number    ${usage}
    Should Be True    ${usage} < ${MAX_ROOT_FS_USAGE_PERCENT}
    ...    msg=Root filesystem usage ${usage}% exceeds threshold of ${MAX_ROOT_FS_USAGE_PERCENT}%

Available Memory Should Be Above Minimum Threshold
    [Documentation]    Confirms the DUT has enough free/available memory to keep running
    ...    tests reliably, on a board with only 512 MiB of RAM total.
    [Setup]    Ensure SSH Session Is Available
    ${output}=    Execute Command    free -m | awk '/^Mem:/{print $7}'
    ${available}=    Convert To Number    ${output}
    Should Be True    ${available} > ${MIN_AVAILABLE_MEMORY_MB}
    ...    msg=Available memory ${available}MB is below threshold of ${MIN_AVAILABLE_MEMORY_MB}MB

System Load Average Should Be Within Healthy Range
    [Documentation]    Confirms the 1-minute load average is within a healthy range for
    ...    this board's single Cortex-A8 core.
    [Setup]    Ensure SSH Session Is Available
    ${output}=    Execute Command    cat /proc/loadavg
    @{fields}=    Split String    ${output}
    ${load_1min}=    Convert To Number    ${fields}[0]
    Should Be True    ${load_1min} < ${MAX_LOAD_AVERAGE_1MIN}
    ...    msg=1-minute load average ${load_1min} exceeds threshold of ${MAX_LOAD_AVERAGE_1MIN}

Critical Services Should Be Active
    [Documentation]    Confirms sshd and ConnMan are both active, guarding against the two
    ...    configuration regressions found and fixed earlier in this project.
    [Setup]    Ensure SSH Session Is Available
    FOR    ${service}    IN    @{CRITICAL_SERVICES}
        ${status}=    Execute Command    systemctl is-active ${service}
        Should Be Equal As Strings    ${status}    active
        ...    msg=Service '${service}' is not active (got: ${status})
    END

Device Should Not Have Rebooted Unexpectedly During The Test Session
    [Documentation]    Compares the DUT's current uptime against the value recorded when
    ...    the SSH session was first established. If the device rebooted mid-suite, uptime
    ...    would be smaller than the recorded start value instead of having grown.
    [Setup]    Ensure SSH Session Is Available
    ${output}=    Execute Command    cat /proc/uptime
    ${current_uptime}=    Get Uptime Seconds From Output    ${output}
    Should Be True    ${current_uptime} >= ${SSH_SESSION_START_UPTIME}
    ...    msg=Uptime dropped from ${SSH_SESSION_START_UPTIME}s to ${current_uptime}s -- device rebooted unexpectedly