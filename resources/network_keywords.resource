*** Settings ***
Documentation     Reusable keywords for network-layer validation of the BeagleBone Black DUT.
...
...               Covers ICMP reachability (single-shot and sustained load) and Layer 2
...               neighbor discovery (ARP/ND), both executed from the test runner's point
...               of view. None of these keywords require SSH access to the DUT.
Library           Process
Library           String
Variables         ../config/constants.py


*** Keywords ***
Ping Host And Get Packet Loss Percentage
    [Documentation]    Sends ${count} ICMP echo requests to ${target_ip} with a per-packet
    ...    timeout of ${timeout} seconds and returns the reported packet loss as a number.
    [Arguments]    ${target_ip}    ${count}    ${timeout}
    ${result}=    Run Process    ping    -c    ${count}    -W    ${timeout}    ${target_ip}
    ...    stderr=STDOUT
    Log    ${result.stdout}
    ${matches}=    Get Regexp Matches    ${result.stdout}    ${PING_LOSS_REGEX}    1
    Should Not Be Empty    ${matches}
    ...    msg=Could not parse packet loss percentage from ping output
    ${loss}=    Convert To Number    ${matches}[0]
    RETURN    ${loss}

Packet Loss Should Not Exceed
    [Documentation]    Fails if the measured packet loss percentage is greater than the
    ...    given maximum allowed threshold.
    [Arguments]    ${measured_loss}    ${max_allowed_loss}
    Should Be True    ${measured_loss} <= ${max_allowed_loss}
    ...    msg=Packet loss ${measured_loss}% exceeds allowed threshold of ${max_allowed_loss}%

Get Neighbor MAC Address
    [Documentation]    Reads the kernel neighbor (ARP) table entry for ${target_ip} on the
    ...    test runner and returns its MAC address plus the raw command output. Assumes
    ...    at least one packet has already been exchanged with the target so the entry
    ...    exists in the table.
    [Arguments]    ${target_ip}
    ${result}=    Run Process    ip    neigh    show    ${target_ip}    stderr=STDOUT
    Log    ${result.stdout}
    Should Not Be Empty    ${result.stdout}
    ...    msg=No ARP/neighbor entry found for ${target_ip}. Was the device pinged first?
    ${matches}=    Get Regexp Matches    ${result.stdout}    ${MAC_EXTRACT_REGEX}
    Should Not Be Empty    ${matches}
    ...    msg=Could not find a MAC address in neighbor table output
    RETURN    ${matches}[0]    ${result.stdout}

Neighbor Entry State Should Be Valid
    [Documentation]    Fails if the neighbor table output indicates the entry is in a
    ...    FAILED or INCOMPLETE state, which would mean the DUT is not truly reachable
    ...    at Layer 2 despite ICMP possibly having succeeded via a stale cache entry.
    [Arguments]    ${neighbor_output}
    FOR    ${bad_state}    IN    @{ARP_INVALID_STATES}
        Should Not Contain    ${neighbor_output}    ${bad_state}
        ...    msg=Neighbor entry is in invalid state: ${bad_state}
    END

MAC Address Should Be Valid Format
    [Documentation]    Validates that the given string is a properly formatted, non-null,
    ...    non-broadcast MAC address.
    [Arguments]    ${mac_address}
    Should Match Regexp    ${mac_address}    ${MAC_ADDRESS_REGEX}
    ...    msg=MAC address '${mac_address}' does not match the expected format
    Should Not Be Equal As Strings    ${mac_address}    00:00:00:00:00:00
    ...    msg=MAC address is null    ignore_case=True
    Should Not Be Equal As Strings    ${mac_address}    ff:ff:ff:ff:ff:ff
    ...    msg=MAC address is broadcast    ignore_case=True