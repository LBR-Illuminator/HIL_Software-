*** Settings ***
Documentation     Improved resource file for Wiseled_LBR HIL testing
...               Provides dedicated connection management for both devices

Library           OperatingSystem
Library           Collections
Library           String
Library           DateTime
Library           ${CURDIR}/ImprovedSerialHelper.py    WITH NAME    SerialHelper
Library           ${CURDIR}/ImprovedHILProtocol.py     WITH NAME    HILProtocol

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
    [Documentation]    Open a dedicated connection to the Illuminator device
    [Arguments]    ${port}    ${baudrate}=115200    ${timeout}=5
    ${result}=    SerialHelper.Open Illuminator Connection    ${port}    ${baudrate}    ${timeout}
    RETURN    ${result}

Open HIL Connection
    [Documentation]    Open a dedicated connection to the HIL hardware
    [Arguments]    ${port}    ${baudrate}=115200    ${timeout}=5
    ${result}=    SerialHelper.Open HIL Connection    ${port}    ${baudrate}    ${timeout}
    
    # After opening the connection, immediately set the serial helper for HILProtocol
    ${helper}=    Get Library Instance    SerialHelper
    HILProtocol.Set Serial Helper    ${helper}
    
    RETURN    ${result}

Is Illuminator Connected
    [Documentation]    Check if Illuminator is connected
    ${connected}=    SerialHelper.Is Illuminator Connected
    RETURN    ${connected}

Is HIL Connected
    [Documentation]    Check if HIL board is connected
    ${connected}=    SerialHelper.Is HIL Connected
    RETURN    ${connected}

Close All Connections
    [Documentation]    Close all serial connections
    SerialHelper.Close All Connections

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
        
        # Check if response has data and status
        ${has_status}=    Run Keyword And Return Status
        ...    Dictionary Should Contain Key    ${response}    data
        
        # If we have data and status matches expected, return
        IF    ${has_status}
            ${data_has_status}=    Run Keyword And Return Status
            ...    Dictionary Should Contain Key    ${response}[data]    status
            
            IF    ${data_has_status}
                ${status}=    Set Variable    ${response}[data][status]
                
                IF    "${status}" == "${expected_status}"
                    RETURN    ${response}
                END
            END
        END
        
        # If we get here, command failed or invalid response
        Log    Retry ${i}/${retry_count}: Command failed or invalid response    console=yes
        Sleep    ${retry_delay}s
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

Get PWM Duty Cycle
    [Documentation]    Get the PWM duty cycle for a specific light
    [Arguments]    ${light_id}
    
    # Ensure HIL protocol has serial helper
    ${helper}=    Get Library Instance    SerialHelper
    HILProtocol.Set Serial Helper    ${helper}
    
    ${duty_cycle}=    HILProtocol.Get PWM Duty Cycle    ${light_id}
    RETURN    ${duty_cycle}

Set Current Simulation
    [Documentation]    Set the simulated current for a specific light
    [Arguments]    ${light_id}    ${current_ma}
    
    # Ensure HIL protocol has serial helper
    ${helper}=    Get Library Instance    SerialHelper
    HILProtocol.Set Serial Helper    ${helper}
    
    ${result}=    HILProtocol.Set Current Simulation    ${light_id}    ${current_ma}
    RETURN    ${result}

Set Temperature Simulation
    [Documentation]    Set the simulated temperature for a specific light
    [Arguments]    ${light_id}    ${temperature_c}
    
    # Ensure HIL protocol has serial helper
    ${helper}=    Get Library Instance    SerialHelper
    HILProtocol.Set Serial Helper    ${helper}
    
    ${result}=    HILProtocol.Set Temperature Simulation    ${light_id}    ${temperature_c}
    RETURN    ${result}

Ping HIL
    [Documentation]    Send a ping command to the HIL hardware
    
    # Ensure HIL protocol has serial helper
    ${helper}=    Get Library Instance    SerialHelper
    HILProtocol.Set Serial Helper    ${helper}
    
    ${response}=    HILProtocol.Ping
    RETURN    ${response}

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
    [Arguments]    ${expected}    ${actual}    ${tolerance_percent}=${TOLERANCE}    ${name}=Value
    
    ${min_acceptable}=    Evaluate    ${expected} * (1 - ${tolerance_percent}/100)
    ${max_acceptable}=    Evaluate    ${expected} * (1 + ${tolerance_percent}/100)
    
    ${within_tolerance}=    Evaluate    ${min_acceptable} <= ${actual} <= ${max_acceptable}
    
    # Log the result
    IF    ${within_tolerance}
        Log    ${name} within tolerance: Expected ${expected}, Actual ${actual}, Tolerance ±${tolerance_percent}%    console=yes
    ELSE
        Log    ${name} outside tolerance: Expected ${expected}, Actual ${actual}, Tolerance ±${tolerance_percent}%    level=WARN    console=yes
    END
    
    RETURN    ${within_tolerance}

Check For Alarm
    [Documentation]    Check if a specific alarm is active for a light
    [Arguments]    ${light_id}    ${alarm_type}
    
    # Get current alarm status
    ${alarm_status}=    Get Alarm Status
    
    # Check if there are active alarms in the response
    ${has_alarms}=    Run Keyword And Return Status
    ...    Dictionary Should Contain Key    ${alarm_status}[data]    active_alarms
    
    # If no alarms at all, return False immediately
    IF    not ${has_alarms}
        RETURN    ${FALSE}
    END
    
    # Check if any active alarm matches the light_id and alarm_type
    FOR    ${alarm}    IN    @{alarm_status}[data][active_alarms]
        ${light_match}=    Evaluate    str(${alarm}['light']) == str(${light_id})
        ${code_match}=    Evaluate    '${alarm}['code']' == '${alarm_type}'
        
        IF    ${light_match} and ${code_match}
            RETURN    ${TRUE}
        END
    END
    
    # No matching alarm found
    RETURN    ${FALSE}

Verify PWM Output
    [Documentation]    Verify that PWM output matches expected intensity
    [Arguments]    ${light_id}    ${expected_intensity}
    
    # Ensure HIL protocol has serial helper
    ${helper}=    Get Library Instance    SerialHelper
    HILProtocol.Set Serial Helper    ${helper}
    
    # Get the actual PWM duty cycle
    ${actual_duty}=    Get PWM Duty Cycle    ${light_id}
    
    # Make sure we have a valid reading
    ${duty_valid}=    Run Keyword And Return Status    Evaluate    ${actual_duty} != None
    
    IF    not ${duty_valid}
        Log    WARNING: Invalid PWM reading (None) - cannot verify    console=yes
        RETURN    ${FALSE}
    END
    
    # Calculate acceptable range
    ${min_acceptable}=    Evaluate    ${expected_intensity} - ${TOLERANCE}
    ${max_acceptable}=    Evaluate    ${expected_intensity} + ${TOLERANCE}
    
    # Verify within range
    ${within_range}=    Evaluate    ${min_acceptable} <= ${actual_duty} <= ${max_acceptable}
    
    # Log the result
    Log    Light ${light_id} - Expected: ${expected_intensity}%, Actual: ${actual_duty}%, Tolerance: ±${TOLERANCE}%    console=yes
    
    RETURN    ${within_range}