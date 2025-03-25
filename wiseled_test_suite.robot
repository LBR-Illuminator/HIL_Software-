*** Settings ***
Documentation     Master test suite for Wiseled_LBR Illuminator system
...               This suite tests the serial communication protocol and system functionality
...               according to the requirements specified in the project documentation.

Resource          resources/common.resource
Resource          resources/serial_commands.resource
Resource          resources/json_utils.resource

Suite Setup       Initialize Test Environment
Suite Teardown    Cleanup Test Environment

*** Variables ***
${SERIAL_PORT}    COM19    # Default port, override with -v SERIAL_PORT:COM4
${BAUD_RATE}      115200
${TIMEOUT}        5

*** Test Cases ***
Verify Serial Connection
    [Documentation]    Verify that we can establish a serial connection to the device
    [Tags]            smoke    communication
    Serial Connection Should Be Open
    
Test System Ping Command
    [Documentation]    Send a ping command and verify the response
    [Tags]            smoke    communication    system
    ${response}=    Send Ping Command    cmd-ping-001
    Response Should Be Valid    ${response}    resp    cmd-ping-001    system    ping
    Response Status Should Be    ${response}    ok
    
Test Get Light Intensity
    [Documentation]    Test retrieving intensity for each light source
    [Tags]            light    communication
    FOR    ${light_id}    IN RANGE    1    4
        ${response}=    Send Get Light Command    cmd-get-${light_id}    ${light_id}
        Response Should Be Valid    ${response}    resp    cmd-get-${light_id}    light    get
        Response Status Should Be    ${response}    ok
        Dictionary Should Contain Key    ${response}[data]    intensity
    END
    
Test Get All Light Intensities
    [Documentation]    Test retrieving intensities for all light sources at once
    [Tags]            light    communication
    ${response}=    Send Get All Lights Command    cmd-get-all-001
    Response Should Be Valid    ${response}    resp    cmd-get-all-001    light    get_all
    Response Status Should Be    ${response}    ok
    Dictionary Should Contain Key    ${response}[data]    intensities
    Length Should Be    ${response}[data][intensities]    3
    
Test Set Light Intensity
    [Documentation]    Test setting intensity for each light source
    [Tags]            light    communication
    FOR    ${light_id}    IN RANGE    1    4
        ${response}=    Send Set Light Command    cmd-set-${light_id}    ${light_id}    50
        Response Should Be Valid    ${response}    resp    cmd-set-${light_id}    light    set
        Response Status Should Be    ${response}    ok
        
        # Verify the light was set correctly
        ${get_response}=    Send Get Light Command    cmd-verify-${light_id}    ${light_id}
        Response Status Should Be    ${get_response}    ok
        Should Be Equal As Numbers    ${get_response}[data][intensity]    50
    END
    
Test Set All Light Intensities
    [Documentation]    Test setting intensities for all light sources at once
    [Tags]            light    communication
    ${response}=    Send Set All Lights Command    cmd-set-all-001    75    60    45
    Response Should Be Valid    ${response}    resp    cmd-set-all-001    light    set_all
    Response Status Should Be    ${response}    ok
    
    # Verify all lights were set correctly
    ${get_response}=    Send Get All Lights Command    cmd-verify-all-001
    Response Status Should Be    ${get_response}    ok
    Should Be Equal As Numbers    ${get_response}[data][intensities][0]    75
    Should Be Equal As Numbers    ${get_response}[data][intensities][1]    60
    Should Be Equal As Numbers    ${get_response}[data][intensities][2]    45
    
Test Get Sensor Data
    [Documentation]    Test retrieving sensor data for each light source
    [Tags]            status    communication
    FOR    ${light_id}    IN RANGE    1    4
        ${response}=    Send Get Sensors Command    cmd-get-sensor-${light_id}    ${light_id}
        Response Should Be Valid    ${response}    resp    cmd-get-sensor-${light_id}    status    get_sensors
        Response Status Should Be    ${response}    ok
        Dictionary Should Contain Key    ${response}[data]    sensor
        Dictionary Should Contain Key    ${response}[data][sensor]    current
        Dictionary Should Contain Key    ${response}[data][sensor]    temperature
    END
    
Test Get All Sensor Data
    [Documentation]    Test retrieving sensor data for all light sources at once
    [Tags]            status    communication
    ${response}=    Send Get All Sensors Command    cmd-get-all-sensors-001
    Response Should Be Valid    ${response}    resp    cmd-get-all-sensors-001    status    get_all_sensors
    Response Status Should Be    ${response}    ok
    Dictionary Should Contain Key    ${response}[data]    sensors
    Length Should Be    ${response}[data][sensors]    3
    FOR    ${index}    IN RANGE    0    3
        Dictionary Should Contain Key    ${response}[data][sensors][${index}]    current
        Dictionary Should Contain Key    ${response}[data][sensors][${index}]    temperature
    END

Test Get Alarm Status
    [Documentation]    Test retrieving alarm status
    [Tags]            alarm    communication
    ${response}=    Send Alarm Status Command    cmd-alarm-status-001
    Response Should Be Valid    ${response}    resp    cmd-alarm-status-001    alarm    status
    Response Status Should Be    ${response}    ok
    Dictionary Should Contain Key    ${response}[data]    active_alarms

Test Clear Alarm
    [Documentation]    Test clearing an alarm (may not trigger anything if no alarms active)
    [Tags]            alarm    communication
    FOR    ${light_id}    IN RANGE    1    4
        ${response}=    Send Clear Alarm Command    cmd-clear-alarm-${light_id}    ${light_id}
        Response Should Be Valid    ${response}    resp    cmd-clear-alarm-${light_id}    alarm    clear
        # Note: We don't check status as it might be "error" if no alarm was active
    END

*** Keywords ***
Initialize Test Environment
    [Documentation]    Set up the test environment
    Open Serial Connection    ${SERIAL_PORT}    ${BAUD_RATE}    ${TIMEOUT}
    Sleep    1s    # Allow time for device to initialize

Cleanup Test Environment
    [Documentation]    Clean up the test environment
    Close All Serial Connections
