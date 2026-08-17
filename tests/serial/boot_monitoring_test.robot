*** Settings ***
Documentation     Monitors a full BeagleBone Black boot sequence over the
...               serial console — from U-Boot through kernel boot to the
...               login prompt. The reboot is triggered once over the
...               serial console itself in Suite Setup; every test case
...               below analyzes that same captured evidence from a
...               different angle, rather than re-rebooting per test case.
Resource          ../../resources/serial_keywords.resource
Variables         ../../config/secrets.py
Variables         ../../config/constants.py
Suite Setup       Reboot DUT And Capture Boot Log
Suite Teardown    Close Serial Connection To DUT

*** Variables ***
# Calibrated from real measurement: single-run baseline was 60s.
# 75s gives ~25% margin for normal run-to-run jitter (fsck, network
# negotiation, scheduler variance) while still catching genuine
# regressions. Revisit after collecting a few more real runs.
${BOOT_TIME_THRESHOLD}    75

*** Test Cases ***
Boot Log Should Be Captured
    [Documentation]    Sanity check — capture actually reached the login
    ...                prompt within the timeout window.
    [Tags]    serial    smoke
    Should Contain    ${BOOT_LOG}    ${BOOT_LOGIN_PROMPT}

Boot Log Should Contain No Critical Failures
    [Documentation]    Scans for genuinely fatal patterns only. Known
    ...                cosmetic warnings on this board (e.g. the tda998x
    ...                HDMI driver with no cape attached) are intentionally
    ...                NOT flagged — see KNOWN_BENIGN_WARNINGS.
    [Tags]    serial    log-analysis
    FOR    ${pattern}    IN    @{CRITICAL_FAILURE_PATTERNS}
        Should Not Contain    ${BOOT_LOG}    ${pattern}
    END

Boot Time Should Be Within Threshold
    [Documentation]    DUT must reach the login prompt within an
    ...                acceptable time after a software reboot.
    [Tags]    serial    performance
    Should Be True    ${BOOT_DURATION} <= ${BOOT_TIME_THRESHOLD}
    ...    msg=Boot took ${BOOT_DURATION}s, exceeding ${BOOT_TIME_THRESHOLD}s

U-Boot Banner Should Match Expected Version
    [Tags]    serial    bootloader
    Should Match Regexp    ${BOOT_LOG}    ${UBOOT_VERSION_PATTERN}

Board Should Be Identified As BeagleBone Black
    [Tags]    serial    bootloader
    Should Contain    ${BOOT_LOG}    ${EXPECTED_BOARD_NAME}

Network And Storage Drivers Should Initialize
    [Documentation]    Confirms eth0/MMC came up despite the early cosmetic
    ...                "No match for driver" warning during U-Boot.
    [Tags]    serial    drivers
    Should Contain    ${BOOT_LOG}    eth0: MII MODE
    Should Contain    ${BOOT_LOG}    OMAP SD/MMC

Root Filesystem Should Be Clean
    [Tags]    serial    filesystem
    Should Contain    ${BOOT_LOG}    rootfs: clean

*** Keywords ***
Reboot DUT And Capture Boot Log
    [Documentation]    Opens the serial console, logs in and triggers
    ...                'reboot' entirely over serial (no SSH dependency),
    ...                then captures console output until the login
    ...                prompt reappears. Sets ${BOOT_LOG}/${BOOT_DURATION}
    ...                for use by every test case in this suite.
    Open Serial Connection To DUT
    Login To Serial Console And Trigger Reboot
    ${log}    ${duration}=    Capture Boot Log Until Login Prompt
    Set Suite Variable    ${BOOT_LOG}    ${log}
    Set Suite Variable    ${BOOT_DURATION}    ${duration}
    Save Boot Log To File    ${log}