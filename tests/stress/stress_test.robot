*** Settings ***
Documentation     Category 5: Reboot-cycle stress testing for the BeagleBone Black DUT.
...
...               Suite Setup runs ${REBOOT_CYCLE_COUNT} consecutive reboot cycles, all
...               over the serial console -- the exact same trigger-and-capture
...               mechanism Category 1 uses for its single reboot, just repeated. This
...               keeps the suite's core verdict independent of the network/SSH layers,
...               which are Category 2/3's job to validate, not this suite's. Each test
...               below analyzes a different aspect of the same captured dataset.
...
...               Expect this suite to take several minutes to set up -- each cycle
...               costs roughly one full boot.
Resource          ../../resources/stress_keywords.resource
Suite Setup       Run Reboot Stress Cycles
Suite Teardown    Close Serial Connection To DUT
Test Tags         stress


*** Test Cases ***
Reboot Cycle Success Rate Should Meet Minimum Threshold
    [Documentation]    The primary stress-test verdict: at least
    ...    ${MIN_REBOOT_SUCCESS_RATE_PERCENT}% of cycles must reach the login prompt
    ...    again. Reports a rate rather than demanding 100%, since characterizing
    ...    occasional flakiness is the point of a stress test.
    [Tags]    critical
    ${successful}=    Get Successful Cycles    ${REBOOT_CYCLE_RESULTS}
    ${rate}=    Evaluate    100.0 * len($successful) / len($REBOOT_CYCLE_RESULTS)
    Should Be True    ${rate} >= ${MIN_REBOOT_SUCCESS_RATE_PERCENT}
    ...    msg=Only ${rate}% of ${REBOOT_CYCLE_COUNT} reboot cycles reached the login prompt (need >= ${MIN_REBOOT_SUCCESS_RATE_PERCENT}%)

Boot Time Should Stay Within Threshold On Every Successful Cycle
    [Documentation]    For every cycle that did reach the login prompt, boot time must
    ...    stay under ${BOOT_TIME_THRESHOLD_SEC}s -- the same calibrated threshold
    ...    Category 1 uses for its single reboot. Catches a device that eventually
    ...    comes back but has degraded badly on a later cycle.
    ${successful}=    Get Successful Cycles    ${REBOOT_CYCLE_RESULTS}
    Should Not Be Empty    ${successful}    msg=No cycles succeeded, nothing to check
    FOR    ${cycle}    IN    @{successful}
        Should Be True    $cycle['boot_time_sec'] <= $BOOT_TIME_THRESHOLD_SEC
        ...    msg=Cycle ${cycle}[cycle] took ${cycle}[boot_time_sec]s, over threshold of ${BOOT_TIME_THRESHOLD_SEC}s
    END

Boot Time Variance Should Remain Low Across Cycles
    [Documentation]    Even if every cycle is individually under threshold, a widening
    ...    spread between the fastest and slowest boot is an early sign of
    ...    inconsistent behavior worth investigating.
    ${successful}=    Get Successful Cycles    ${REBOOT_CYCLE_RESULTS}
    ${count}=    Get Length    ${successful}
    Skip If    ${count} < 2    Fewer than 2 successful cycles, variance is not meaningful
    @{times}=    Create List
    FOR    ${cycle}    IN    @{successful}
        Append To List    ${times}    ${cycle}[boot_time_sec]
    END
    ${spread}=    Evaluate    max($times) - min($times)
    Should Be True    ${spread} <= ${MAX_BOOT_TIME_VARIANCE_SEC}
    ...    msg=Boot time spread of ${spread}s across cycles exceeds threshold of ${MAX_BOOT_TIME_VARIANCE_SEC}s: ${times}

No Reboot Cycle Should Introduce New Critical Kernel Failures
    [Documentation]    Runs the same fatal-pattern check Category 1 applies to its
    ...    single boot log, against every successful cycle's captured log here --
    ...    catching faults that only appear after repeated reboots rather than on one
    ...    clean boot.
    ${successful}=    Get Successful Cycles    ${REBOOT_CYCLE_RESULTS}
    Should Not Be Empty    ${successful}    msg=No cycles succeeded, nothing to check
    FOR    ${cycle}    IN    @{successful}
        Text Should Contain No Listed Patterns    ${cycle}[boot_log]    @{CRITICAL_FAILURE_PATTERNS}
    END

Every Reboot Cycle Should Show A Fresh U-Boot Banner And Correct Board Identity
    [Documentation]    Confirms each cycle was a genuine fresh boot, not a stale buffer
    ...    artifact, by checking the same U-Boot version pattern and board name
    ...    Category 1 checks on its single boot log, now on every cycle here.
    ${successful}=    Get Successful Cycles    ${REBOOT_CYCLE_RESULTS}
    Should Not Be Empty    ${successful}    msg=No cycles succeeded, nothing to check
    FOR    ${cycle}    IN    @{successful}
        Should Match Regexp    ${cycle}[boot_log]    ${UBOOT_VERSION_PATTERN}
        ...    msg=Cycle ${cycle}[cycle] boot log does not show the expected U-Boot banner
        Should Contain    ${cycle}[boot_log]    ${EXPECTED_BOARD_NAME}
        ...    msg=Cycle ${cycle}[cycle] boot log does not identify the board correctly
    END