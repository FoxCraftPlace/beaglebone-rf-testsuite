*** Settings ***
Documentation     Reusable keywords for the U-Boot Console Validation suite:
...
...               power-cycles the DUT with the relay, interrupts autoboot
...               right after power is applied, inspects the real running
...               U-Boot environment via printenv, then resumes the normal
...               boot sequence. No environment variable is ever written or
...               saved (no setenv/saveenv) -- this is read-only inspection
...               layered on top of the same power-cycle/capture primitives
...               the serial boot monitoring suite uses, so there is nothing
...               to corrupt and nothing to restore in Teardown.
Library           SerialLibrary    encoding=ascii
Library           OperatingSystem
Resource          serial_keywords.resource
Resource          power_keywords.resource
Variables         ../config/constants.py
Variables         ../config/secrets.py

*** Keywords ***
Power Cycle DUT And Interrupt Autoboot
    [Documentation]    Graceful power cycle (poweroff over serial, relay off,
    ...                hold, relay on), then immediately spams a keypress to
    ...                catch U-Boot's autoboot interrupt window. Works even
    ...                with bootdelay=0: U-Boot buffers console input received
    ...                during early SPL/U-Boot init and evaluates it once the
    ...                console driver is live, so input sent before/during the
    ...                "Press SPACE to abort" line still lands inside the
    ...                window. Time-based, not iteration-based, so it doesn't
    ...                depend on how long each Write/Read/Sleep cycle actually
    ...                takes. The wait window starts at power-on; the time it
    ...                took to reach the '=>' prompt is logged for calibration.
    ...                Whether the prompt was reached is recorded in the
    ...                DUT_HELD_AT_UBOOT suite variable, which tells the Suite
    ...                Teardown if the board is waiting for a 'boot' command.
    [Arguments]    ${max_wait}=${UBOOT_INTERRUPT_MAX_WAIT_SEC}
    Graceful Power Cycle DUT
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
    Set Suite Variable    ${DUT_HELD_AT_UBOOT}    ${reached}
    ${now}=    Get Time    epoch
    ${elapsed}=    Evaluate    ${now} - ${start}
    Log    U-Boot console reached=${reached} ${elapsed}s after power-on
    Should Be True    ${reached}
    ...    msg=Could not interrupt autoboot within ${max_wait}s of power-on -- DUT likely booted straight to Linux
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
    ...                exactly like the serial boot monitoring suite, so this
    ...                suite can confirm the DUT still reaches a healthy login
    ...                prompt after being inspected. Sets
    ...                ${BOOT_LOG}/${BOOT_DURATION} for any test that wants
    ...                to check the second half of the boot too.
    Write Data    boot\r\n
    Set Suite Variable    ${DUT_HELD_AT_UBOOT}    ${FALSE}
    ${log}    ${duration}=    Capture Boot Log Until Login Prompt
    Set Suite Variable    ${BOOT_LOG}    ${log}
    Set Suite Variable    ${BOOT_DURATION}    ${duration}
    Save Boot Log To File    ${log}

Power Cycle Interrupt Capture Env And Resume Boot
    [Documentation]    Full Suite Setup sequence for this suite: opens the
    ...                serial port, power-cycles the DUT with the relay,
    ...                interrupts autoboot, captures printenv output into
    ...                ${UBOOT_ENV}, then resumes the normal boot sequence
    ...                and captures the rest into ${BOOT_LOG}/${BOOT_DURATION}.
    ...                One power cycle serves every test case in this suite.
    Open Serial Connection To DUT
    Power Cycle DUT And Interrupt Autoboot
    ${env_output}=    Run Printenv And Capture Output
    Set Suite Variable    ${UBOOT_ENV}    ${env_output}
    Resume Normal Boot From U-Boot Console

Ensure DUT Is Powered And Not Stuck At U-Boot Console
    [Documentation]    Safety-net Suite Teardown, best-effort whatever failed
    ...                earlier. 'boot' is written only while the suite is still
    ...                holding the DUT at the '=>' prompt (DUT_HELD_AT_UBOOT
    ...                suite variable: set when the prompt is reached, cleared
    ...                once 'boot' has been sent). After a normal run the console
    ...                sits at the Linux login prompt, where 'boot' would be
    ...                typed in as a user name. Nothing is written to the console
    ...                after the relay is released: with bootdelay 0 any byte
    ...                could interrupt autoboot. The relay is always released, so
    ...                the bench is never left with the DUT unpowered, and the
    ...                port is closed.
    ${held}=    Get Variable Value    ${DUT_HELD_AT_UBOOT}    ${FALSE}
    IF    ${held}
        Log    DUT is still held at the U-Boot prompt -- sending boot.
        Run Keyword And Ignore Error    Write Data    boot\r\n
        Run Keyword And Ignore Error    Sleep    2s
    ELSE
        Log    DUT is not held at the U-Boot prompt -- nothing is written to the console.
    END
    Run Keyword And Continue On Failure    Power On DUT
    Close Serial Connection To DUT