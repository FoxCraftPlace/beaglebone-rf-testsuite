*** Settings ***
Documentation     Category: Active U-Boot Console Validation.
...
...               Interrupts autoboot on a live reboot, inspects the actual
...               running U-Boot environment via printenv, verifies key
...               values match what the board is expected to report, then
...               resumes normal boot and confirms the DUT still reaches a
...               healthy login prompt. No environment variable is ever
...               written -- this is read-only inspection layered on top of
...               Category 1's reboot/capture primitives.
Resource          ../../resources/serial_keywords.resource
Resource          ../../resources/uboot_keywords.resource
Suite Setup       Reboot Interrupt Capture Env And Resume Boot
Suite Teardown    Ensure DUT Is Not Stuck At U-Boot Console

*** Test Cases ***
Autoboot Should Be Interruptible And Reach U-Boot Console
    [Documentation]    Confirms the DUT can be dropped into the U-Boot CLI
    ...                on demand, which every other test in this suite
    ...                depends on.
    [Tags]    uboot    smoke
    Should Contain    ${UBOOT_ENV}    Environment size:

Board Identity Should Match Expected Values
    [Documentation]    Cross-checks the raw env board_name/board_rev
    ...                against the same board Category 1 identifies from
    ...                the boot banner -- two independent sources agreeing
    ...                on hardware identity.
    [Tags]    uboot    bootloader
    Should Contain    ${UBOOT_ENV}    board_name=${EXPECTED_BOARD_NAME_ENV}
    Should Contain    ${UBOOT_ENV}    board_rev=${EXPECTED_BOARD_REV_ENV}

Ethernet MAC Address Should Be Set And Valid
    [Documentation]    ethaddr must be a real, well-formed MAC -- an unset
    ...                or malformed address here means networking will
    ...                fail before Category 2 even gets a chance to test
    ...                it.
    [Tags]    uboot    network
    Should Match Regexp    ${UBOOT_ENV}    ethaddr=${MAC_EXTRACT_REGEX}

Boot Command Should Use Standard Distro Boot Sequence
    [Documentation]    bootcmd must still route through distro_bootcmd --
    ...                the mechanism that scans for uEnv.txt/boot.scr on
    ...                the SD card. A drifted bootcmd would silently change
    ...                how the board decides what to boot.
    [Tags]    uboot    bootloader
    Should Contain    ${UBOOT_ENV}    ${EXPECTED_BOOTCMD_SUBSTRING}

Kernel And FDT Load Addresses Should Match Expected Memory Map
    [Documentation]    loadaddr/fdtaddr define where U-Boot stages the
    ...                kernel and device tree in RAM before handoff --
    ...                these must stay in sync with what the boot log
    ...                actually shows loading.
    [Tags]    uboot    bootloader
    Should Contain    ${UBOOT_ENV}    loadaddr=${EXPECTED_LOADADDR}
    Should Contain    ${UBOOT_ENV}    fdtaddr=${EXPECTED_FDTADDR}

Serial Console Should Be Configured On Expected UART
    [Documentation]    console= determines which UART carries kernel
    ...                messages post-handoff -- if this drifts, the whole
    ...                serial-based test suite loses visibility into the
    ...                kernel boot.
    [Tags]    uboot    bootloader
    Should Contain    ${UBOOT_ENV}    console=${EXPECTED_CONSOLE_SETTING}

DUT Should Resume Normal Boot After Console Inspection
    [Documentation]    The whole point of doing this read-only: after
    ...                being interrupted and inspected, the board must
    ...                still boot cleanly and within the same time budget
    ...                as an uninterrupted reboot.
    [Tags]    uboot    smoke
    Should Contain    ${BOOT_LOG}    ${BOOT_LOGIN_PROMPT}
    Should Be True    ${BOOT_DURATION} <= ${BOOT_TIME_THRESHOLD_SEC}
    ...    msg=Post-inspection boot took ${BOOT_DURATION}s, exceeding ${BOOT_TIME_THRESHOLD_SEC}s