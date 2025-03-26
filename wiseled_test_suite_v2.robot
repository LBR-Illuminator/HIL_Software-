*** Settings ***
Documentation     Master test suite for Wiseled_LBR Illuminator system
...               This suite tests the serial communication protocol and system functionality
...               according to the requirements specified in the project documentation.

Library           OperatingSystem
Library           Collections
Library           resources/SerialHelper.py

Suite Setup       Initialize Test Environment
Suite Teardown    Cleanup Test Environment

*** Variables ***
${SERIAL_PORT}    COM19    # Default port, override with -v SERIAL_PORT:COM19
${BAUD_RATE}      115200
${TIMEOUT}        5

*** Test Cases ***
Verify Serial Connection
    [Documentation]    Verify that we can establish a serial connection to the device
    [Tags]            smoke    communication
    ${is_open}=    Is Port Open
    Should Be True    ${is_open}    Serial port is not open

Test System Ping Command
    [Documentation]    Send a ping command and verify the response
    [Tags]            smoke    communication    system
    ${command}=    Set Variable    {"type":"cmd","id":"cmd-ping-001","topic":"system","action":"ping","data":{"timestamp":"2023-03-25T10:00:00Z"}}
    ${response}=    Send Command And Get Response    ${command}
    Log    ${response}
    Dictionary Should Contain Key    ${response}    type

*** Keywords ***
Initialize Test Environment
    [Documentation]    Set up the test environment
    Log    Initializing test environment    console=yes
    Log    Connecting to serial port ${SERIAL_PORT} at ${BAUD_RATE} baud    console=yes
    ${result}=    Open Serial Port    ${SERIAL_PORT}    ${BAUD_RATE}    ${TIMEOUT}
    Should Be True    ${result}    Failed to open serial port ${SERIAL_PORT}
    Sleep    1s    # Allow time for device to initialize

Cleanup Test Environment
    [Documentation]    Clean up the test environment
    Close Serial Port