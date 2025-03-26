*** Settings ***
Documentation     Master test suite for Wiseled_LBR Illuminator system
...               This suite tests the serial communication protocol and system functionality
...               according to the requirements specified in the project documentation.

Library           OperatingSystem
Library           Collections
Library           resources/SerialHelper.py
Resource          resources/json_utils.resource

Suite Setup       Initialize Test Environment
Suite Teardown    Cleanup Test Environment

*** Variables ***
${SERIAL_PORT}    COM19    # Default port, override with -v SERIAL_PORT:COM4
${BAUD_RATE}      115200
${TIMEOUT}        5
${CMD_WAIT_TIME}  0.1      # Time to wait after sending a command in seconds
${RETRY_MAX}      3        # Maximum number of retry attempts

*** Test Cases ***
Verify Serial Connection
    [Documentation]    Verify that we can establish a serial connection to the device
    [Tags]            smoke    communication
    ${is_open}=    Is Port Open
    Should Be True    ${is_open}    Serial port is not open
    
Test System Ping Command
    [Documentation]    Send a ping command and verify the response
    [Tags]            smoke    communication    system
    ${timestamp}=    Get Current Timestamp
    ${command}=    Evaluate    {"type": "cmd", "id": "cmd-ping-001", "topic": "system", "action": "ping", "data": {"timestamp": "${timestamp}"}}
    ${response}=    Retry Command Until Success    ${command}    system    ping
    Log    \nPing response data: ${response}[data]    console=yes
    
Test Get Light Intensity
    [Documentation]    Test retrieving intensity for each light source
    [Tags]            light    communication
    FOR    ${light_id}    IN RANGE    1    4
        ${command}=    Evaluate    {"type": "cmd", "id": "cmd-get-${light_id}", "topic": "light", "action": "get", "data": {"id": ${light_id}}}
        ${response}=    Retry Command Until Success    ${command}    light    get
        Log    \nLight ${light_id} intensity data: ${response}[data]    console=yes
    END
    
Test Get All Light Intensities
    [Documentation]    Test retrieving intensities for all light sources at once
    [Tags]            light    communication
    ${command}=    Evaluate    {"type": "cmd", "id": "cmd-get-all-001", "topic": "light", "action": "get_all", "data": {}}
    ${response}=    Retry Command Until Success    ${command}    light    get_all
    Log    \nAll light intensities data: ${response}[data]    console=yes
    
Test Set Light Intensity
    [Documentation]    Test setting intensity for each light source
    [Tags]            light    communication
    FOR    ${light_id}    IN RANGE    1    4
        # Set light intensity
        ${set_command}=    Evaluate    {"type": "cmd", "id": "cmd-set-${light_id}", "topic": "light", "action": "set", "data": {"id": ${light_id}, "intensity": 50}}
        ${set_response}=    Retry Command Until Success    ${set_command}    light    set
        Log    \nSetting light ${light_id} response data: ${set_response}[data]    console=yes
        
        # Verify the light was set correctly
        ${get_command}=    Evaluate    {"type": "cmd", "id": "cmd-verify-${light_id}", "topic": "light", "action": "get", "data": {"id": ${light_id}}}
        ${get_response}=    Retry Command Until Success    ${get_command}    light    get
        Log    State of light ${light_id} data: ${get_response}[data]    console=yes
        
        # Verify the intensity is set to the expected value
        Should Be Equal As Numbers    ${get_response}[data][intensity]    50
    END
    
Test Set All Light Intensities
    [Documentation]    Test setting intensities for all light sources at once
    [Tags]            light    communication
    
    # Set all light intensities
    ${set_command}=    Evaluate    {"type": "cmd", "id": "cmd-set-all-001", "topic": "light", "action": "set_all", "data": {"intensities": [75, 60, 45]}}
    ${set_response}=    Retry Command Until Success    ${set_command}    light    set_all
    Log    \nSet all lights response data: ${set_response}[data]    console=yes
    
    # Verify all lights were set correctly
    ${get_command}=    Evaluate    {"type": "cmd", "id": "cmd-verify-all-001", "topic": "light", "action": "get_all", "data": {}}
    ${get_response}=    Retry Command Until Success    ${get_command}    light    get_all
    Log    Current state of all lights data: ${get_response}[data]    console=yes
    
    # Verify intensities
    Should Be Equal As Numbers    ${get_response}[data][intensities][0]    75
    Should Be Equal As Numbers    ${get_response}[data][intensities][1]    60
    Should Be Equal As Numbers    ${get_response}[data][intensities][2]    45
    
Test Get Sensor Data
    [Documentation]    Test retrieving sensor data for each light source
    [Tags]            status    communication
    FOR    ${light_id}    IN RANGE    1    4
        ${command}=    Evaluate    {"type": "cmd", "id": "cmd-get-sensor-${light_id}", "topic": "status", "action": "get_sensors", "data": {"id": ${light_id}}}
        ${response}=    Retry Command Until Success    ${command}    status    get_sensors
        Log    \nSensor data for light ${light_id}: ${response}[data]    console=yes
    END
    
Test Get All Sensor Data
    [Documentation]    Test retrieving sensor data for all light sources at once
    [Tags]            status    communication
    ${command}=    Evaluate    {"type": "cmd", "id": "cmd-get-all-sensors-001", "topic": "status", "action": "get_all_sensors", "data": {}}
    ${response}=    Retry Command Until Success    ${command}    status    get_all_sensors
    Log    \nAll sensor data: ${response}[data]    console=yes

Test Get Alarm Status
    [Documentation]    Test retrieving alarm status
    [Tags]            alarm    communication
    ${command}=    Evaluate    {"type": "cmd", "id": "cmd-alarm-status-001", "topic": "alarm", "action": "status", "data": {}}
    ${response}=    Retry Command Until Success    ${command}    alarm    status
    Log    \nAlarm status data: ${response}[data]    console=yes

Test Clear Alarm
    [Documentation]    Test clearing an alarm (may not trigger anything if no alarms active)
    [Tags]            alarm    communication
    FOR    ${light_id}    IN RANGE    1    4
        ${command}=    Evaluate    {"type": "cmd", "id": "cmd-clear-alarm-${light_id}", "topic": "alarm", "action": "clear", "data": {"lights": [${light_id}]}}
        
        # Note: We don't use retry for clearing alarms as it might legitimately return error if no alarm exists
        ${response}=    Send Command And Get Response    ${command}
        Log    \nClear alarm for light ${light_id} response: ${response}    console=yes
        
        # Just verify the response structure, not the status
        Should Be Equal    ${response}[type]      resp
        Should Be Equal    ${response}[id]        cmd-clear-alarm-${light_id}
        Should Be Equal    ${response}[topic]     alarm
        Should Be Equal    ${response}[action]    clear
    END

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

Send Command And Get Response
    [Documentation]    Send a command and get the response
    [Arguments]    ${command_dict}
    ${response}=    SerialHelper.Send Command And Get Response    ${command_dict}    ${TIMEOUT}
    RETURN    ${response}

Retry Command Until Success
    [Documentation]    Execute a command with retry logic
    [Arguments]    ${command_dict}    ${expected_topic}    ${expected_action}    ${retry_max}=${RETRY_MAX}
    
    ${retry_count}=    Set Variable    0
    ${success}=    Set Variable    ${FALSE}
    
    WHILE    (${retry_count} < ${retry_max}) and (${success} == ${FALSE})
        ${retry_count}=    Evaluate    ${retry_count} + 1
        
        # Add retry number to command ID to make each attempt unique
        ${original_id}=    Set Variable    ${command_dict}[id]
        Set To Dictionary    ${command_dict}    id=${original_id}-retry${retry_count}
        
        TRY
            ${response}=    Send Command And Get Response    ${command_dict}
            
            # Check for basic response structure
            Dictionary Should Contain Key    ${response}    type
            Dictionary Should Contain Key    ${response}    id
            Dictionary Should Contain Key    ${response}    topic
            Dictionary Should Contain Key    ${response}    action
            Dictionary Should Contain Key    ${response}    data
            
            # Verify response matches what we expect
            Should Be Equal    ${response}[type]      resp
            Should Be Equal    ${response}[topic]     ${expected_topic}
            Should Be Equal    ${response}[action]    ${expected_action}
            
            # Verify status is ok
            Dictionary Should Contain Key    ${response}[data]    status
            Should Be Equal    ${response}[data][status]    ok
            
            # If we got here, the command was successful
            ${success}=    Set Variable    ${TRUE}
            
        EXCEPT    AS    ${error}
            IF    ${retry_count} < ${retry_max}
                Log    ⚠️Attempt ${retry_count} failed: ${error}. Retrying...    console=yes
                Sleep    1s    # Wait before retrying
            ELSE
                Log    All ${retry_max} attempts failed. Last error: ${error}    console=yes
            END
        END
    END
    
    # If we got here and success is still FALSE, all retries failed
    Should Be True    ${success}    Command ${command_dict}[topic]/${command_dict}[action] failed after ${retry_max} attempts
    
    # Restore original command ID
    Set To Dictionary    ${command_dict}    id=${original_id}
    
    RETURN    ${response}

Verify Response
    [Documentation]    Verify that a response has the expected structure and values
    [Arguments]    ${response}    ${expected_type}    ${expected_id}    ${expected_topic}    ${expected_action}    ${expected_status}=None
    Dictionary Should Contain Key    ${response}    type
    Dictionary Should Contain Key    ${response}    id
    Dictionary Should Contain Key    ${response}    topic
    Dictionary Should Contain Key    ${response}    action
    Dictionary Should Contain Key    ${response}    data
    
    Should Be Equal    ${response}[type]      ${expected_type}
    Should Be Equal    ${response}[id]        ${expected_id}
    Should Be Equal    ${response}[topic]     ${expected_topic}
    Should Be Equal    ${response}[action]    ${expected_action}
    
    IF    '${expected_status}' != 'None'
        Dictionary Should Contain Key    ${response}[data]    status
        Should Be Equal    ${response}[data][status]    ${expected_status}
    END

Get Current Timestamp
    [Documentation]    Get current timestamp in ISO 8601 format
    ${timestamp}=    Evaluate    datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')    datetime
    RETURN    ${timestamp}