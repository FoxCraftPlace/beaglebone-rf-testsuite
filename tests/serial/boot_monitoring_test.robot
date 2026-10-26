*** Settings ***
Documentation     Monitors a full BeagleBone Black cold boot over the serial
...               console — from SPL and U-Boot through kernel boot to the
...               login prompt. In Suite Setup the DUT is shut down gracefully
...               over serial and then power-cycled with the relay, so the
...               capture starts at the very first byte of a real power-on.
...               Every test case below analyzes that same captured evidence
...               from a different angle, rather than re-booting per test case.
Resource          ../../resources/serial_keywords.resource
Resource          ../../resources/power_keywords.resource
Variables         ../../config/secrets.py
Variables         ../../config/constants.py
Suite Setup       Power Cycle DUT And Capture Boot Log
Suite Teardown    Restore Power And Close Serial

*** Test Cases ***
Boot Log Should Be Captured
    [Documentation]    Sanity check — the capture started at power-on (SPL banner
    ...                present) and reached the login prompt within the timeout window.
    [Tags]    serial    smoke
    Should Contain    ${BOOT_LOG}    Boot SPL
    ...    msg=Capture did not start at power-on (no SPL banner in the log)
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
    [Documentation]    DUT must reach the login prompt within an acceptable
    ...                time after power is applied (relay power-on to login).
    [Tags]    serial    performance
    Should Be True    ${BOOT_DURATION} <= ${COLD_BOOT_TIME_THRESHOLD_SEC}
    ...    msg=Cold boot took ${BOOT_DURATION}s, exceeding ${COLD_BOOT_TIME_THRESHOLD_SEC}s

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
    [Documentation]    The root filesystem must be clean and need no journal recovery.
    ...                'rootfs: recovering journal' was seen on this bench only after
    ...                a power cut without shutdown (Hard Power Cycle DUT), so its
    ...                presence here also exposes a graceful shutdown that silently
    ...                fell back to a plain power cut.
    [Tags]    serial    filesystem
    Should Contain    ${BOOT_LOG}    rootfs: clean
    Should Not Contain    ${BOOT_LOG}    rootfs: recovering journal
    ...    msg=Boot log shows journal recovery: power was cut without a completed shutdown
    ...    values=False

*** Keywords ***
Power Cycle DUT And Capture Boot Log
    [Documentation]    Opens the serial console, shuts the DUT down gracefully,
    ...                cuts and restores power with the relay, then captures the
    ...                console until the login prompt appears. Sets
    ...                ${BOOT_LOG}/${BOOT_DURATION} for every test case in this suite.
    Open Serial Connection To DUT
    ${log}    ${duration}=    Cold Boot DUT
    Set Suite Variable    ${BOOT_LOG}    ${log}
    Set Suite Variable    ${BOOT_DURATION}    ${duration}
    Save Boot Log To File    ${log}