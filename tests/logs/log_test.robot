*** Settings ***
Documentation     Category 4: Log analysis for the BeagleBone Black DUT.
...
...               Reads the kernel ring buffer (dmesg) and the systemd journal
...               (journalctl) over SSH to catch issues that would not show up in
...               Category 1's one-time serial boot capture: faults that occur after
...               boot completes, and signs of an unclean shutdown on a previous run.
...
...               One SSH session is opened in Suite Setup and reused by every test.
...               If it cannot be established, the first test fails with the reason
...               and the rest are skipped, so the suite can never pass by skipping
...               everything.
Resource          ../../resources/log_keywords.resource
Suite Setup       Establish BBB SSH Session
Suite Teardown    Close BBB SSH Session
Test Tags         logs


*** Test Cases ***
SSH Session Should Be Available For Log Analysis
    [Documentation]    Fails when the SSH session opened in Suite Setup could not be
    ...    established. Every test below skips itself in that case, so without this
    ...    check the whole suite would be reported as skipped and robot would still
    ...    exit with 0.
    [Tags]    smoke    critical
    Should Be True    ${SSH_SESSION_ESTABLISHED}
    ...    msg=SSH session could not be established: ${SSH_SESSION_ERROR}

Dmesg Should Contain No Critical Kernel Failures
    [Documentation]    Checks the live kernel ring buffer for the same fatal patterns
    ...    used in Category 1's boot log analysis. Catches faults that occurred any time
    ...    after boot, not just during the initial serial capture.
    [Setup]    Ensure SSH Session Is Available
    ${dmesg}=    Execute Command    dmesg
    Text Should Contain No Listed Patterns    ${dmesg}    @{CRITICAL_FAILURE_PATTERNS}

Dmesg Should Not Contain Out Of Memory Killer Events
    [Documentation]    Checks for signs the OOM killer fired. Worth its own dedicated
    ...    test on a 512 MiB board that gets rebooted and re-tested repeatedly.
    [Setup]    Ensure SSH Session Is Available
    ${dmesg}=    Execute Command    dmesg
    Text Should Contain No Listed Patterns    ${dmesg}    @{OOM_KILLER_PATTERNS}

Current Boot Journal Should Not Exceed Error Threshold
    [Documentation]    Counts journal entries at priority 'err' or higher for the current
    ...    boot and compares against MAX_ALLOWED_ERROR_JOURNAL_ENTRIES, which is
    ...    calibrated from a real boot (see the comment next to it in constants.py).
    [Setup]    Ensure SSH Session Is Available
    ${count}=    Get Journal Error Count For Current Boot
    Should Be True    ${count} <= ${MAX_ALLOWED_ERROR_JOURNAL_ENTRIES}
    ...    msg=${count} error-level journal entries exceeds threshold of ${MAX_ALLOWED_ERROR_JOURNAL_ENTRIES}

Previous Boot Should Have Ended With A Clean Shutdown Sequence
    [Documentation]    Looks at the tail of the previous boot's journal for markers that
    ...    the system went down via an orderly shutdown/reboot target rather than a
    ...    crash or hard power loss. Skips with a note if there is no previous boot yet.
    ...    Marker text verified against real journal output on this board:
    ...    'Reached target Shutdown' and 'Reached target Reboot' both confirmed present.
    [Setup]    Ensure SSH Session Is Available
    ${tail}=    Get Previous Boot Tail
    IF    not $tail
        Skip    No previous boot recorded yet
    END
    ${has_marker}=    Set Variable    ${FALSE}
    FOR    ${marker}    IN    @{CLEAN_SHUTDOWN_MARKERS}
        ${matched}=    Run Keyword And Return Status    Should Contain    ${tail}    ${marker}
        IF    ${matched}
            ${has_marker}=    Set Variable    ${TRUE}
        END
    END
    Should Be True    ${has_marker}
    ...    msg=No clean-shutdown marker found in previous boot's final log lines:\n${tail}

Journal Disk Usage Should Be Below Threshold
    [Documentation]    Confirms the systemd journal has not grown unbounded on limited
    ...    embedded storage -- a common oversight when journald size limits are left
    ...    at their defaults.
    [Setup]    Ensure SSH Session Is Available
    ${usage_mb}=    Get Journal Disk Usage MB
    Should Be True    ${usage_mb} < ${MAX_JOURNAL_DISK_USAGE_MB}
    ...    msg=Journal disk usage ${usage_mb}MB exceeds threshold of ${MAX_JOURNAL_DISK_USAGE_MB}MB