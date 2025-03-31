*** Settings ***
Documentation     Resource file for Wiseled_LBR HIL testing
...               Contains common keywords and utilities for testing both the Illuminator and HIL hardware

Library           OperatingSystem
Library           Collections
Library           String
Library           DateTime
Library           EnhancedSerialHelper.py    WITH NAME    SerialHelper
Library           HILProtocol.py        WITH NAME    HILProtocol

*** Variables ***
${TIMEOUT}               5     # Default timeout in seconds
${NEWLINE}               \n
${RETRY_COUNT}           3     # Number of retries for commands
${RETRY_DELAY}           1     # Delay between retries in seconds
${TOLERANCE_PERCENT}     5     # Tolerance percentage for values

# HIL protocol constants
${HIL_START_MARKER}      0xAA
${HIL_END_MARKER}        0x55
${HIL_CMD_GET}           G
${HIL_CMD_SET}           S
${HIL_CMD_PING}          P
${HIL_LIGHT_1}           1
${HIL_LIGHT_2}           2
${HIL_LIGHT_3}           3
${HIL_SIGNAL_PWM}        P
${HIL_SIGNAL_CURRENT}    C
${HIL_SIGNAL_TEMP}       T
${HIL_SIGNAL_SYSTEM}     S

# Safety thresholds (from documentation)
${CURRENT_THRESHOLD}     3000   # 3.0 Amps (mA)
${TEMP_THRESHOLD}        85     # 85 degrees Celsius

*** Keywords ***
################################
# Connection Management Keywords
################################

Open Illuminator Connection
    [Documentation]    Open a connection to the Illuminator device
    [Arguments]    ${port}    ${baudrate}=115200    ${timeout}=5
    ${result}=    SerialHelper.Open Serial Port    ${port}    ${baudrate}    ${timeout}    illuminator
    RETURN    ${result}

Open HIL Connection
    [Documentation]    Open a connection to the HIL hardware
    [Arguments]    ${port}    ${baudrate}=115200    ${timeout}=5
    ${result}=    SerialHelper.Open Serial Port    ${port}    ${baudrate}    ${timeout}    hil
    HILProtocol.Set Serial Helper    SerialHelper
    RETURN    ${result}

Close All Connections
    [Documentation]    Close all serial connections
    SerialHelper.Close Serial Port

#################################
# Illuminator Communication Keywords
#################################

Send Illuminator Command
    [Documentation]    Send a command to the Illuminator and get response
    [Arguments]    ${command_dict}    ${timeout}=${TIMEOUT}
    ${response}=    SerialHelper.Send Illuminator Command    ${command_dict}    ${timeout}
    RETURN    ${response}

Retry Illuminator Command
    [Documentation]    Send an Illuminator command with retry logic
    [Arguments]    ${command_dict}    ${expected_status}=ok    ${retry_count}=${RETRY_COUNT}    ${retry_delay}=${RETRY_DELAY}
    
    FOR    ${i}    IN RANGE    1    ${retry_count} + 1
        ${response}=    Send Illuminator Command    ${command_dict}
        ${status}=    Set Variable    ${response}[data][status]
        
        IF    "${status}" == "${expected_status}"
            RETURN    ${response}
        ELSE
            Log    Retry ${i}/${retry_count}: Command failed with status ${status}    console=yes
            Sleep    ${retry_delay}s
        END
    END
    
    # If we get here, all retries failed
    Fail    Command failed after ${retry_count} retries

Ping Illuminator
    [Documentation]    Send a ping command to the Illuminator
    ${timestamp}=    Get Current Timestamp
    ${command}=    Create Dictionary
    ...    type=cmd
    ...    id=ping-test
    ...    topic=system
    ...    action=ping
    ...    data={"timestamp": "${timestamp}"}
    
    ${response}=    Send Illuminator Command    ${command}
    RETURN    ${response}

Set Light Intensity
    [Documentation]    Set the intensity of a specific light
    [Arguments]    ${light_id}    ${intensity}
    
    ${command}=    Create Dictionary
    ...    type=cmd
    ...    id=set-light-${light_id}
    ...    topic=light
    ...    action=set
    ...    data={"id": ${light_id}, "intensity": ${intensity}}
    
    ${response}=    Send Illuminator Command    ${command}
    RETURN    ${response}

Set All Lights Intensity
    [Documentation]    Set the intensity of all lights
    [Arguments]    ${intensity1}    ${intensity2}    ${intensity3}
    
    ${command}=    Create Dictionary
    ...    type=cmd
    ...    id=set-all-lights
    ...    topic=light
    ...    action=set_all
    ...    data={"intensities": [${intensity1}, ${intensity2}, ${intensity3}]}
    
    ${response}=    Send Illuminator Command    ${command}
    RETURN    ${response}

Get Light Intensity
    [Documentation]    Get the current intensity of a specific light
    [Arguments]    ${light_id}
    
    ${command}=    Create Dictionary
    ...    type=cmd
    ...    id=get-light-${light_id}
    ...    topic=light
    ...    action=get
    ...    data={"id": ${light_id}}
    
    ${response}=    Send Illuminator Command    ${command}
    RETURN    ${response}

Get All Lights Intensity
    [Documentation]    Get the current intensity of all lights
    
    ${command}=    Create Dictionary
    ...    type=cmd
    ...    id=get-all-lights
    ...    topic=light
    ...    action=get_all
    ...    data={}
    
    ${response}=    Send Illuminator Command    ${command}
    RETURN    ${response}

Get Sensor Data
    [Documentation]    Get sensor data for a specific light
    [Arguments]    ${light_id}
    
    ${command}=    Create Dictionary
    ...    type=cmd
    ...    id=get-sensors-${light_id}
    ...    topic=status
    ...    action=get_sensors
    ...    data={"id": ${light_id}}
    
    ${response}=    Send Illuminator Command    ${command}
    RETURN    ${response}

Get All Sensors Data
    [Documentation]    Get sensor data for all lights
    
    ${command}=    Create Dictionary
    ...    type=cmd
    ...    id=get-all-sensors
    ...    topic=status
    ...    action=get_all_sensors
    ...    data={}
    
    ${response}=    Send Illuminator Command    ${command}
    RETURN    ${response}

Get Alarm Status
    [Documentation]    Get the current alarm status
    
    ${command}=    Create Dictionary
    ...    type=cmd
    ...    id=get-alarm-status
    ...    topic=alarm
    ...    action=status
    ...    data={}
    
    ${response}=    Send Illuminator Command    ${command}
    RETURN    ${response}

Clear Alarm
    [Documentation]    Clear alarms for specific lights
    [Arguments]    ${light_ids}
    
    # Convert single ID to list if needed
    ${light_list}=    Run Keyword If    not isinstance($light_ids, list)    Create List    ${light_ids}
    ...    ELSE    Set Variable    ${light_ids}
    
    ${command}=    Create Dictionary
    ...    type=cmd
    ...    id=clear-alarm
    ...    topic=alarm
    ...    action=clear
    ...    data={"lights": ${light_list}}
    
    ${response}=    Send Illuminator Command    ${command}
    RETURN    ${response}

#################################
# HIL Communication Keywords
#################################

Send HIL Command
    [Documentation]    Send a binary command to the HIL hardware
    [Arguments]    ${cmd_type}    ${light_id}    ${signal_type}    ${value}
    ${response}=    HILProtocol.Send Command    ${cmd_type}    ${light_id}    ${signal_type}    ${value}
    RETURN    ${response}

Ping HIL
    [Documentation]    Send a ping command to the HIL hardware
    ${response}=    HILProtocol.Ping
    RETURN    ${response}

Get PWM Duty Cycle
    [Documentation]    Get the PWM duty cycle for a specific light
    [Arguments]    ${light_id}
    ${duty_cycle}=    HILProtocol.Get PWM Duty Cycle    ${light_id}
    RETURN    ${duty_cycle}

Set Current Simulation
    [Documentation]    Set the simulated current for a specific light
    [Arguments]    ${light_id}    ${current_ma}
    ${result}=    HILProtocol.Set Current Simulation    ${light_id}    ${current_ma}
    RETURN    ${result}

Set Temperature Simulation
    [Documentation]    Set the simulated temperature for a specific light
    [Arguments]    ${light_id}    ${temperature_c}
    ${result}=    HILProtocol.Set Temperature Simulation    ${light_id}    ${temperature_c}
    RETURN    ${result}

#################################
# Utility Keywords
#################################

Get Current Timestamp
    [Documentation]    Get current timestamp in ISO 8601 format
    ${timestamp}=    Evaluate    datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')    datetime
    RETURN    ${timestamp}

Wait For Stable Reading
    [Documentation]    Wait for a stable reading before measurement
    [Arguments]    ${delay}=0.5
    Sleep    ${delay}s

Verify Value Within Tolerance
    [Documentation]    Verify a value is within tolerance of expected
    [Arguments]    ${expected}    ${actual}    ${tolerance_percent}=${TOLERANCE_PERCENT}    ${name}=Value
    
    ${min_acceptable}=    Evaluate    ${expected} * (1 - ${tolerance_percent}/100)
    ${max_acceptable}=    Evaluate    ${expected} * (1 + ${tolerance_percent}/100)
    
    ${within_range}=    Evaluate    ${min_acceptable} <= ${actual} <= ${max_acceptable}
    
    IF    ${within_range}
        Log    ${name}: Expected=${expected}, Actual=${actual} - within ${tolerance_percent}% tolerance - OK    console=yes
        RETURN    ${TRUE}
    ELSE
        ${error_msg}=    Set Variable    ${name}: Expected=${expected}, Actual=${actual} - outside ${tolerance_percent}% tolerance
        Log    ${error_msg}    console=yes  level=WARN
        RETURN    ${FALSE}
    END

Check For Alarm
    [Documentation]    Check if a specific alarm is active
    [Arguments]    ${light_id}    ${alarm_code}
    
    ${response}=    Get Alarm Status
    ${has_alarms}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${response}[data]    active_alarms
    
    IF    ${has_alarms}
        ${alarms}=    Set Variable    ${response}[data][active_alarms]
        FOR    ${alarm}    IN    @{alarms}
            IF    ${alarm}[light] == ${light_id} and "${alarm}[code]" == "${alarm_code}"
                RETURN    ${TRUE}
            END
        END
    END
    
    RETURN    ${FALSE}

Setup Safe Conditions
    [Documentation]    Set up safe conditions for all lights
    
    # Set all simulated sensors to safe values
    FOR    ${light_id}    IN RANGE    1    4
        Set Current Simulation    ${light_id}    1000
        Set Temperature Simulation    ${light_id}    50
    END
    
    # Clear any existing alarms
    ${clear_cmd}=    Create Dictionary
    ...    type=cmd
    ...    id=clear-all-alarms
    ...    topic=alarm
    ...    action=clear
    ...    data={"lights": [1, 2, 3]}
    
    Send Illuminator Command    ${clear_cmd}
    
    # Turn all lights off
    ${set_cmd}=    Create Dictionary
    ...    type=cmd
    ...    id=all-lights-off
    ...    topic=light
    ...    action=set_all
    ...    data={"intensities": [0, 0, 0]}
    
    Send Illuminator Command    ${set_cmd}

Verify PWM Output
    [Documentation]    Verify PWM output for a light matches expected intensity
    [Arguments]    ${light_id}    ${expected_intensity}
    
    Wait For Stable Reading    0.5
    ${duty_cycle}=    Get PWM Duty Cycle    ${light_id}
    
    # Special case for extreme values (0% and 100%) since HIL can't measure precisely
    IF    ${expected_intensity} == 0
        ${result}=    Evaluate    ${duty_cycle} < 5
        IF    not ${result}
            Log    Light ${light_id} expected to be OFF (0%) but measured ${duty_cycle}%    console=yes    level=WARN
        ELSE
            Log    Light ${light_id} OFF (${duty_cycle}%) - OK    console=yes
        END
        RETURN    ${result}
    ELSIF    ${expected_intensity} == 100
        ${result}=    Evaluate    ${duty_cycle} > 95
        IF    not ${result}
            Log    Light ${light_id} expected to be FULL (100%) but measured ${duty_cycle}%    console=yes    level=WARN
        ELSE
            Log    Light ${light_id} FULL (${duty_cycle}%) - OK    console=yes
        END
        RETURN    ${result}
    ELSE
        # Normal case - verify within tolerance
        ${min_acceptable}=    Evaluate    ${expected_intensity} - 2
        ${max_acceptable}=    Evaluate    ${expected_intensity} + 2
        ${within_range}=    Evaluate    ${min_acceptable} <= ${duty_cycle} <= ${max_acceptable}
        
        IF    ${within_range}
            Log    Light ${light_id} at ${duty_cycle}% (expected ${expected_intensity}%) - OK    console=yes
        ELSE
            Log    Light ${light_id} at ${duty_cycle}% - outside acceptable range for expected ${expected_intensity}%    console=yes    level=WARN
        END
        
        RETURN    ${within_range}
    END