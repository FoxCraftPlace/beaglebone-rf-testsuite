*** Settings ***
Documentation     Reusable keywords for the Category 5 reboot-stress suite.
...
...               Every cycle is a full power cycle: Cold Boot DUT
...               (power_keywords.resource) shuts the DUT down gracefully over the
...               serial console, cuts and restores its power with the relay and
...               captures the console from the first byte of the new boot -- the
...               same sequence Category 1 uses for its single cold boot, just
...               repeated ${REBOOT_CYCLE_COUNT} times. This keeps the suite's core
...               pass/fail verdict independent of the network/SSH layers --
...               validating those is Category 2/3's job, not this one's.
Library           Collections
Resource          serial_keywords.resource
Resource          power_keywords.resource
Resource          log_keywords.resource


*** Keywords ***
Run Reboot Stress Cycles
    [Documentation]    Opens the serial console once, then runs ${REBOOT_CYCLE_COUNT}
    ...    consecutive power cycles over it, storing the per-cycle results as a list
    ...    of dictionaries in ${REBOOT_CYCLE_RESULTS}. Intended for Suite Setup; pair
    ...    with 'Restore Power And Close Serial' (from power_keywords.resource) as
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
    [Documentation]    One power cycle with Cold Boot DUT: graceful shutdown over the
    ...    serial console, relay cut, relay restored, then the boot log up to the next
    ...    login prompt. A boot that never reaches the login prompt is a failed cycle
    ...    whose log is kept as evidence. If the bench itself fails (relay or serial
    ...    port), that error is captured in the result instead of aborting the
    ...    remaining cycles. A board left hung by a cycle is recovered by the next
    ...    one, whose shutdown falls back to a plain relay power cut.
    [Arguments]    ${cycle_number}
    TRY
        ${log}    ${duration}=    Cold Boot DUT
    EXCEPT    AS    ${error}
        &{result}=    Create Dictionary    cycle=${cycle_number}    success=${FALSE}
        ...    boot_time_sec=${NONE}    boot_log=${EMPTY}    error=${error}
        RETURN    ${result}
    END
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