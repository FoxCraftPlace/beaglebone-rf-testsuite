*** Settings ***
Documentation     Reusable keywords for the Category 5 reboot-stress suite.
...
...               Reboots are triggered and captured entirely over the serial console,
...               reusing the exact same primitives as Category 1's single-reboot boot
...               monitoring (serial_keywords.resource), just repeated
...               ${REBOOT_CYCLE_COUNT} times. This keeps the suite's core pass/fail
...               verdict independent of the network/SSH layers -- validating those is
...               Category 2/3's job, not this one's.
Library           Collections
Resource          serial_keywords.resource
Resource          log_keywords.resource


*** Keywords ***
Run Reboot Stress Cycles
    [Documentation]    Opens the serial console once, then runs ${REBOOT_CYCLE_COUNT}
    ...    consecutive reboot cycles over it, storing the per-cycle results as a list
    ...    of dictionaries in ${REBOOT_CYCLE_RESULTS}. Intended for Suite Setup; pair
    ...    with 'Close Serial Connection To DUT' (from serial_keywords.resource) as
    ...    Suite Teardown.
    Open Serial Connection To DUT
    @{cycle_results}=    Create List
    ${cycle_stop}=    Evaluate    $REBOOT_CYCLE_COUNT + 1
    FOR    ${i}    IN RANGE    1    ${cycle_stop}
        &{result}=    Run Single Reboot Cycle    ${i}
        Append To List    ${cycle_results}    ${result}
        Log    Cycle ${i} result: ${result}
    END
    Set Suite Variable    ${REBOOT_CYCLE_RESULTS}    ${cycle_results}

Run Single Reboot Cycle
    [Documentation]    Logs into the serial console and triggers 'reboot', then
    ...    captures the boot log up to the next login prompt -- the same mechanism
    ...    Category 1 uses for its single reboot, just called in a loop here. If the
    ...    console doesn't respond to trigger the reboot at all (e.g. left stuck by a
    ...    previous cycle), that failure is captured in the result instead of aborting
    ...    the remaining cycles.
    [Arguments]    ${cycle_number}
    ${trigger_status}    ${trigger_error}=    Run Keyword And Ignore Error
    ...    Login To Serial Console And Trigger Reboot
    IF    '${trigger_status}' != 'PASS'
        &{result}=    Create Dictionary    cycle=${cycle_number}    success=${FALSE}
        ...    boot_time_sec=${NONE}    boot_log=${EMPTY}    error=${trigger_error}
        RETURN    ${result}
    END

    ${log}    ${duration}=    Capture Boot Log Until Login Prompt
    ...    max_wait=${REBOOT_CYCLE_CAPTURE_TIMEOUT_SEC}
    Save Boot Log To File    ${log}
    ${reached_login}=    Run Keyword And Return Status
    ...    Should Contain    ${log}    ${BOOT_LOGIN_PROMPT}

    &{result}=    Create Dictionary    cycle=${cycle_number}    success=${reached_login}
    ...    boot_time_sec=${duration}    boot_log=${log}    error=${EMPTY}
    RETURN    ${result}

Get Successful Cycles
    [Documentation]    Filters ${REBOOT_CYCLE_RESULTS} down to only the cycles that
    ...    reached the login prompt successfully.
    [Arguments]    ${all_cycles}
    @{successful}=    Create List
    FOR    ${cycle}    IN    @{all_cycles}
        IF    $cycle['success']
            Append To List    ${successful}    ${cycle}
        END
    END
    RETURN    ${successful}