*** Settings ***
Documentation     Category 2: Network layer validation for the BeagleBone Black DUT.
...
...               Verifies basic and sustained ICMP reachability over the direct Ethernet
...               link (10.0.0.1 <-> 10.0.0.2) and confirms the DUT is correctly visible
...               in the test runner's Layer 2 neighbor table.
...
...               These tests only assume the DUT is powered on and its network interface
...               has come up; they do not require SSH access.
Resource          ../../resources/network_keywords.resource
Test Tags         network


*** Test Cases ***
BeagleBone Should Respond To Ping
    [Documentation]    Sends a small burst of ICMP echo requests to the DUT and expects
    ...    zero packet loss. Baseline smoke test for network reachability.
    [Tags]    smoke    critical
    ${loss}=    Ping Host And Get Packet Loss Percentage    ${BBB_IP_ADDRESS}
    ...    ${PING_BASIC_COUNT}    ${PING_BASIC_TIMEOUT_SEC}
    Packet Loss Should Not Exceed    ${loss}    ${PING_BASIC_MAX_LOSS_PERCENT}

BeagleBone Should Maintain Stable Connection Under Sustained Ping Load
    [Documentation]    Sends a sustained burst of ${PING_LOAD_COUNT} ICMP echo requests
    ...    and expects packet loss to stay within an acceptable tolerance. A coarse
    ...    indicator of link/driver stability over a longer window than the basic
    ...    smoke test provides.
    [Tags]    load    reliability
    ${loss}=    Ping Host And Get Packet Loss Percentage    ${BBB_IP_ADDRESS}
    ...    ${PING_LOAD_COUNT}    ${PING_LOAD_TIMEOUT_SEC}
    Packet Loss Should Not Exceed    ${loss}    ${PING_LOAD_MAX_LOSS_PERCENT}

Host Neighbor Table Should Show A Valid Entry For BeagleBone
    [Documentation]    Confirms that, from the test runner's perspective, the DUT has a
    ...    resolved and valid Layer 2 neighbor (ARP) entry: a correctly formatted MAC
    ...    address in a reachable state, not FAILED or INCOMPLETE.
    [Tags]    sanity
    Ping Host And Get Packet Loss Percentage    ${BBB_IP_ADDRESS}
    ...    ${PING_BASIC_COUNT}    ${PING_BASIC_TIMEOUT_SEC}
    ${mac}    ${raw_output}=    Get Neighbor MAC Address    ${BBB_IP_ADDRESS}
    MAC Address Should Be Valid Format    ${mac}
    Neighbor Entry State Should Be Valid    ${raw_output}