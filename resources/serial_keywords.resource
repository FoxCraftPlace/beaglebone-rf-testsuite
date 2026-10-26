*** Settings ***
Documentation     Reusable low-level keywords for interacting with the
...               BeagleBone Black serial console (U-Boot / kernel boot
...               log / login prompt).
Library           SerialLibrary    encoding=ascii
Library           OperatingSystem
Variables         ../config/constants.py
Variables         ../config/secrets.py

*** Keywords ***
Open Serial Connection To DUT
    [Documentation]    Opens the serial port used to monitor the DUT console.
    Add Port    ${SERIAL_PORT}    baudrate=${SERIAL_BAUDRATE}    timeout=1

Close Serial Connection To DUT
    [Documentation]    Releases the serial port.
    Delete All Ports

Capture Boot Log Until Login Prompt
    [Documentation]    Accumulates serial output until the login prompt
    ...                appears or max_wait seconds elapse. Periodically
    ...                sends a bare Enter to nudge the console into
    ...                reprinting the prompt, covering cases where it was
    ...                missed due to serial framing desync right after the
    ...                fresh getty process starts post-reboot. Nudging only
    ...                starts after nudge_after_s seconds (default 0 = from
    ...                the first interval) -- after a relay power-on it must
    ...                be delayed so a keypress cannot interrupt U-Boot
    ...                autoboot. Returns the captured text and the elapsed
    ...                seconds.
    [Arguments]    ${max_wait}=90    ${nudge_after_s}=0
    ${start}=    Get Time    epoch
    ${buffer}=    Set Variable    ${EMPTY}
    FOR    ${i}    IN RANGE    ${max_wait}
        ${chunk}=    Read All Data
        ${buffer}=    Catenate    SEPARATOR=${EMPTY}    ${buffer}    ${chunk}
        ${found}=    Run Keyword And Return Status
        ...    Should Contain    ${buffer}    ${BOOT_LOGIN_PROMPT}
        IF    ${found}    BREAK
        ${nudge_due}=    Evaluate    ${i} % 5 == 0 and ${i} > ${nudge_after_s}
        IF    ${nudge_due}    Write Data    \r\n
        Sleep    1s
    END
    ${end}=    Get Time    epoch
    ${duration}=    Evaluate    ${end} - ${start}
    RETURN    ${buffer}    ${duration}

Save Boot Log To File
    [Documentation]    Persists the captured boot log to the results
    ...                directory as timestamped evidence for this run.
    [Arguments]    ${log_content}
    ${timestamp}=    Get Time    epoch
    Create File    ${OUTPUT_DIR}/boot_log_${timestamp}.txt    ${log_content}

Read Serial Until
    [Documentation]    Polls the serial port, accumulating output, until
    ...                the given marker substring appears. Fails hard on
    ...                timeout — used for interactive login control flow,
    ...                unlike the tolerant Capture Boot Log keyword above.
    [Arguments]    ${marker}    ${timeout_s}=15
    ${buffer}=    Set Variable    ${EMPTY}
    FOR    ${i}    IN RANGE    ${timeout_s}
        ${chunk}=    Read All Data
        ${buffer}=    Catenate    SEPARATOR=${EMPTY}    ${buffer}    ${chunk}
        ${found}=    Run Keyword And Return Status
        ...    Should Contain    ${buffer}    ${marker}
        IF    ${found}    BREAK
        Sleep    1s
    END
    Should Contain    ${buffer}    ${marker}
    ...    msg=Timed out waiting for '${marker}' on the serial console
    RETURN    ${buffer}

Wait For Serial Marker Or Timeout
    [Documentation]    Tolerant sibling of Read Serial Until: never fails. Returns
    ...                whether the marker was seen and everything captured, so the
    ...                caller can decide what a missing marker means.
    [Arguments]    ${marker}    ${timeout_s}=15
    ${buffer}=    Set Variable    ${EMPTY}
    ${found}=    Set Variable    ${FALSE}
    FOR    ${i}    IN RANGE    ${timeout_s}
        ${chunk}=    Read All Data
        ${buffer}=    Catenate    SEPARATOR=${EMPTY}    ${buffer}    ${chunk}
        ${found}=    Run Keyword And Return Status
        ...    Should Contain    ${buffer}    ${marker}
        IF    ${found}    BREAK
        Sleep    1s
    END
    RETURN    ${found}    ${buffer}

Login To Serial Console And Run Command
    [Documentation]    Wakes the console with a bare Enter (agetty only
    ...                reprints the login prompt on request), authenticates
    ...                with the DUT's serial credentials, then sends the given
    ...                command. Keeps serial-based suites fully independent of
    ...                SSH/network.
    [Arguments]    ${command}
    Write Data    \r\n
    Read Serial Until    login:    timeout_s=10
    Write Data    ${BBB_SSH_USER}\r\n
    Read Serial Until    Password:    timeout_s=10
    Write Data    ${BBB_SSH_PASSWORD}\r\n
    Read Serial Until    ${SHELL_PROMPT_MARKER}    timeout_s=10
    Write Data    ${command}\r\n

Login To Serial Console And Trigger Reboot
    [Documentation]    Soft reboot over serial -- kept for suites that
    ...                deliberately test the warm-reset path.
    Login To Serial Console And Run Command    reboot