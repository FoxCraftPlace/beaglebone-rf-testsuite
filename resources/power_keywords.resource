*** Settings ***
Documentation     Power control of the BeagleBone Black through the USB-serial
...               relay (NC wiring: coil energized = DUT unpowered), plus the
...               power-cycle sequences built on top of it.
...
...               Two levels on purpose:
...               - Graceful Power Cycle DUT / Cold Boot DUT: graceful 'poweroff'
...                 over serial first, then the relay cut. A true cold start with
...                 no filesystem risk -- used by suite setups.
...               - Hard Power Cycle DUT: power is cut with no shutdown at all.
...                 Reserved for dedicated power-loss tests (limited cycles,
...                 eMMC wear).
Variables         ../config/constants.py
Library           ../libraries/RelayPower.py
...               port=${RELAY_PORT}
...               baudrate=${RELAY_BAUDRATE}
...               energize_hex=${RELAY_CMD_ENERGIZE_HEX}
...               release_hex=${RELAY_CMD_RELEASE_HEX}
Library           SerialLibrary    encoding=ascii
Resource          serial_keywords.resource

*** Keywords ***
Power Off DUT
    [Documentation]    Cuts DUT power. NC wiring: energizing the coil opens the contact.
    Relay Energize

Power On DUT
    [Documentation]    Restores DUT power. NC wiring: releasing the coil closes the contact.
    Relay Release

Hard Power Cycle DUT
    [Documentation]    Cuts and restores power with NO shutdown -- simulates sudden
    ...                power loss. Hold time lets the board fully de-energize.
    [Arguments]    ${hold_s}=${POWER_OFF_HOLD_SEC}
    Power Off DUT
    Sleep    ${hold_s}s
    Power On DUT

Shutdown DUT Gracefully Over Serial
    [Documentation]    Logs in over the serial console and runs 'poweroff', then waits
    ...                for the halt marker. Never fails the suite: if the console is
    ...                unresponsive (board off or hung) or the marker is not seen, it
    ...                logs a WARN and returns ${FALSE} -- the relay cut that follows
    ...                makes the outcome the same either way.
    ${status}    ${error}=    Run Keyword And Ignore Error
    ...    Login To Serial Console And Run Command    poweroff
    IF    '${status}' == 'FAIL'
        Log    Graceful shutdown failed (${error}) -- falling back to hard power cut.    WARN
        RETURN    ${FALSE}
    END
    ${seen}    ${output}=    Wait For Serial Marker Or Timeout
    ...    ${POWEROFF_MARKER}    ${POWEROFF_WAIT_SEC}
    Log    ${output}    level=DEBUG
    IF    not ${seen}
        Log    Marker '${POWEROFF_MARKER}' not seen within ${POWEROFF_WAIT_SEC}s -- cutting power anyway.    WARN
    END
    Sleep    2s
    RETURN    ${seen}

Graceful Power Cycle DUT
    [Documentation]    Graceful shutdown over serial -> relay off -> hold -> relay on.
    ...                Returns right after power is applied, WITHOUT capturing the
    ...                console, so the caller decides how to consume the new boot
    ...                (passive capture, or interrupting U-Boot). Stale shutdown output
    ...                is flushed just before power-on. Requires the serial port to be
    ...                open.
    Shutdown DUT Gracefully Over Serial
    Power Off DUT
    Sleep    ${POWER_OFF_HOLD_SEC}s
    ${stale}=    Read All Data
    Power On DUT

Cold Boot DUT
    [Documentation]    Graceful Power Cycle DUT, then captures the console from the
    ...                very first byte of the new boot (SPL included). Returns the
    ...                boot log and the seconds from power-on to the login prompt.
    Graceful Power Cycle DUT
    ${log}    ${duration}=    Capture Boot Log Until Login Prompt
    ...    ${COLD_BOOT_CAPTURE_TIMEOUT_SEC}    nudge_after_s=${COLD_BOOT_NUDGE_AFTER_SEC}
    RETURN    ${log}    ${duration}