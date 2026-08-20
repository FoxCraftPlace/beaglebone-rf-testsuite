*** Settings ***
Documentation     Reusable keywords for log-analysis validation of the BeagleBone Black DUT.
...
...               Covers the kernel ring buffer (dmesg) and the systemd journal
...               (journalctl), both read live over the SSH session established by
...               ssh_keywords.resource. Deliberately separate from Category 1's serial
...               boot log: dmesg/journalctl reflect the DUT's full running state, not
...               just the one-time boot capture taken before login.
Library           String
Resource          ssh_keywords.resource


*** Keywords ***
Text Should Contain No Listed Patterns
    [Documentation]    Fails if any string in @{patterns} appears in ${text}, reporting
    ...    every match found rather than stopping at the first one.
    [Arguments]    ${text}    @{patterns}
    @{found}=    Create List
    FOR    ${pattern}    IN    @{patterns}
        ${matched}=    Run Keyword And Return Status    Should Contain    ${text}    ${pattern}
        IF    ${matched}    Append To List    ${found}    ${pattern}
    END
    Should Be Empty    ${found}
    ...    msg=Found disallowed pattern(s) in output: ${found}

Get Journal Error Count For Current Boot
    [Documentation]    Counts journal entries at priority 'err' or higher for the current
    ...    boot, using 'wc -l' on the DUT so counting happens on the remote shell rather
    ...    than by splitting text in Robot Framework.
    ${count}=    Execute Command    journalctl -b -p err --no-pager -q | wc -l
    ${count}=    Convert To Integer    ${count}
    RETURN    ${count}

Get Previous Boot Tail
    [Documentation]    Returns the last ${lines} lines of the previous boot's journal
    ...    (boot offset -1). Returns an empty string if there is no previous boot yet
    ...    (e.g. first boot since flashing the image).
    [Arguments]    ${lines}=30
    ${boot_count}=    Execute Command    journalctl --list-boots -q | wc -l
    ${boot_count}=    Convert To Integer    ${boot_count}
    IF    ${boot_count} < 2
        RETURN    ${EMPTY}
    END
    ${tail}=    Execute Command    journalctl -b -1 -q --no-pager | tail -n ${lines}
    RETURN    ${tail}

Get Journal Disk Usage MB
    [Documentation]    Reads 'journalctl --disk-usage' over SSH and returns the reported
    ...    size in megabytes.
    ${output}=    Execute Command    journalctl --disk-usage
    ${mb}=    Parse Journal Disk Usage MB    ${output}
    RETURN    ${mb}

Parse Journal Disk Usage MB
    [Documentation]    Parses the human-readable size out of the raw output of
    ...    'journalctl --disk-usage' and returns it as a number of megabytes.
    [Arguments]    ${disk_usage_output}
    ${matches}=    Get Regexp Matches    ${disk_usage_output}    take up ([\\d.]+)([KMG])    1    2
    Should Not Be Empty    ${matches}
    ...    msg=Could not parse disk usage from: ${disk_usage_output}
    ${value}=    Convert To Number    ${matches}[0][0]
    ${unit}=    Set Variable    ${matches}[0][1]
    IF    '${unit}' == 'K'
        ${mb}=    Evaluate    ${value} / 1024
    ELSE IF    '${unit}' == 'G'
        ${mb}=    Evaluate    ${value} * 1024
    ELSE
        ${mb}=    Set Variable    ${value}
    END
    RETURN    ${mb}

    Get Full Journal For Current Boot
    [Documentation]    Returns the complete journal for the current boot,
    ...    unfiltered by priority. Used for pattern-scanning checks (like
    ...    OOM killer detection) that need to catch messages regardless of
    ...    their log level -- unlike Get Journal Error Count For Current
    ...    Boot, which deliberately only counts 'err' and above.
    ${output}=    Execute Command    journalctl -b -q --no-pager
    RETURN    ${output}