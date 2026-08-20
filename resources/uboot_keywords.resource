*** Settings ***
Documentation     Reusable keywords for the U-Boot Console Validation suite:
...
...               interrupts autoboot on a live reboot cycle, inspects the
...               real running U-Boot environment via printenv, then resumes
...               the normal boot sequence. No environment variable is ever
...               written or saved (no setenv/saveenv) -- this is read-only
...               inspection layered on top of the exact same reboot/capture
...               primitives Category 1 uses, so there is nothing to corrupt
...               and nothing to restore in Teardown.
Library           SerialLibrary    encoding=ascii
Library           OperatingSystem
Resource          serial_keywords.resource
Variables         ../config/constants.py
Variables         ../config/secrets.py

*** Keywords ***
Reboot DUT And Interrupt Autoboot
    [Documentation]    Triggers a reboot over serial (reusing Category 1's
    ...                login+reboot keyword), then immediately spams a
    ...                keypress to catch U-Boot's autoboot interrupt window.
    ...                Works even with bootdelay=0: U-Boot buffers console
    ...                input received during early SPL/U-Boot init and
    ...                evaluates it once the console driver is live, so
    ...                input sent before/during the "Press SPACE to abort"
    ...                line still lands inside the window. Time-based, not
    ...                iteration-based, so it doesn't depend on how long
    ...                each Write/Read/Sleep cycle actually takes.
    [Arguments]    ${max_wait}=${UBOOT_INTERRUPT_MAX_WAIT_SEC}
    Login To Serial Console And Trigger Reboot
    ${start}=    Get Time    epoch
    ${buffer}=    Set Variable    ${EMPTY}
    ${reached}=    Set Variable    ${FALSE}
    FOR    ${i}    IN RANGE    9999
        Write Data    ${SPACE}
        Sleep    0.2s
        ${chunk}=    Read All Data
        ${buffer}=    Catenate    SEPARATOR=${EMPTY}    ${buffer}    ${chunk}
        ${reached}=    Run Keyword And Return Status
        ...    Should Contain    ${buffer}    ${UBOOT_PROMPT_MARKER}
        IF    ${reached}    BREAK
        ${now}=    Get Time    epoch
        ${elapsed}=    Evaluate    ${now} - ${start}
        IF    ${elapsed} >= ${max_wait}    BREAK
    END
    Should Be True    ${reached}
    ...    msg=Could not interrupt autoboot within ${max_wait}s -- DUT likely booted straight to Linux
    RETURN    ${buffer}

Run Printenv And Capture Output
    [Documentation]    Issues 'printenv' at the U-Boot prompt and returns
    ...                the full variable dump. Read-only command -- does
    ...                not touch the saved environment.
    Write Data    printenv\r\n
    ${output}=    Read Serial Until    Environment size:    timeout_s=10
    RETURN    ${output}

Resume Normal Boot From U-Boot Console
    [Documentation]    Runs the board's normal boot sequence from the
    ...                U-Boot prompt and captures the rest of the boot
    ...                exactly like Category 1, so this suite can confirm
    ...                the DUT still reaches a healthy login prompt after
    ...                being inspected. Sets ${BOOT_LOG}/${BOOT_DURATION}
    ...                for any test that wants to check the second half
    ...                of the boot too.
    Write Data    boot\r\n
    ${log}    ${duration}=    Capture Boot Log Until Login Prompt
    Set Suite Variable    ${BOOT_LOG}    ${log}
    Set Suite Variable    ${BOOT_DURATION}    ${duration}
    Save Boot Log To File    ${log}

Reboot Interrupt Capture Env And Resume Boot
    [Documentation]    Full Suite Setup sequence for this suite: opens the
    ...                serial port, reboots the DUT, interrupts autoboot,
    ...                captures printenv output into ${UBOOT_ENV}, then
    ...                resumes the normal boot sequence and captures the
    ...                rest into ${BOOT_LOG}/${BOOT_DURATION}. One reboot
    ...                cycle serves every test case in this suite.
    Open Serial Connection To DUT
    Reboot DUT And Interrupt Autoboot
    ${env_output}=    Run Printenv And Capture Output
    Set Suite Variable    ${UBOOT_ENV}    ${env_output}
    Resume Normal Boot From U-Boot Console

Ensure DUT Is Not Stuck At U-Boot Console
    [Documentation]    Safety-net Suite Teardown. If an earlier keyword
    ...                failed while the DUT was sitting at the '=>'
    ...                prompt, the board would be left requiring a manual
    ...                power-cycle. Best-effort nudges it back into a
    ...                normal boot regardless of what already failed, then
    ...                closes the port.
    Run Keyword And Ignore Error    Write Data    boot\r\n
    Run Keyword And Ignore Error    Sleep    2s
    Close Serial Connection To DUT