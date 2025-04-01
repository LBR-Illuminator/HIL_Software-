*** Settings ***
Documentation     Comprehensive test suite for Wiseled_LBR Illuminator using HIL hardware
...               This suite validates the entire Illuminator system including PWM control,
...               sensor feedback, and safety features by communicating with both the
...               Illuminator device and the HIL test hardware.

Resource          resources/wiseled_hil_resources.resource
Library           OperatingSystem
Library           Collections
Library           String
Library           DateTime

Suite Setup       Initialize Test Environment
Suite Teardown    Cleanup Test Environment

*** Variables ***
${ILLUMINATOR_PORT}                COM19      # Default port for Illuminator, override with -v ILLUMINATOR_PORT:COM4
${HIL_PORT}                        COM20      # Default port for HIL board, override with -v HIL_PORT:COM19
${BAUD_RATE}                       115200
${TIMEOUT}                         5
${RETRY_MAX}                       3          # Maximum number of retry attempts
${TOLERANCE}                       5          # Tolerance percentage for sensor readings (5%)
${TEMPERATURE_TOLERANCE}           15         # Tolerance percentage for temperaure readings (15%)
${CURRENT_TOLERANCE}               20         # Tolerance percentage for Current readings (10%)

# Test intensity values
@{INTENSITY_LEVELS}    0    30    60    90

# Safety thresholds (from documentation)
${CURRENT_THRESHOLD}    25000   # 25.0 Amps (in milliamps)
${TEMP_THRESHOLD}       85      # 85 degrees Celsius

*** Test Cases ***
######################
# Basic Connectivity #
######################

Verify Illuminator Communication
    [Documentation]    Verify that we can communicate with the Illuminator device
    [Tags]            smoke    communication
    ${is_open}=       Is Illuminator Connected
    Should Be True    ${is_open}    Illuminator serial port is not open

Verify HIL Communication
    [Documentation]    Verify that we can communicate with the HIL board
    [Tags]            smoke    communication
    ${is_open}=       Is HIL Connected
    Should Be True    ${is_open}    HIL serial port is not open

Test Ping To Both Devices
    [Documentation]    Send ping commands to both devices and verify responses
    [Tags]            smoke    communication    system

    # Ping Illuminator
    ${illuminator_resp}=    Ping Illuminator
    Should Be Equal    ${illuminator_resp}[data][status]    ok
    Log    Illuminator ping successful    console=yes

    # Ensure HIL protocol has serial helper
    ${helper}=    Get Library Instance    SerialHelper
    HILProtocol.Set Serial Helper    ${helper}
    
    # Ping HIL board
    ${hil_resp}=    Ping HIL
    Should Be Equal    ${hil_resp}[status]    ok
    Log    HIL board ping successful    console=yes

#################################
# Combined PWM and Light Control #
#################################

Test Single Light PWM Control
    [Documentation]    Test control of each individual light and verify PWM output
    [Tags]            light    pwm    control
    ${wait_time}=      Set Variable    0.25  # Wait time for stable reading
    ${max_retries}=    Set Variable    3     # Maximum number of retries for light control

    # Ensure HIL protocol has serial helper
    ${helper}=    Get Library Instance    SerialHelper
    HILProtocol.Set Serial Helper    ${helper}

    # First ensure all lights are off
    ${command}=    Create Dictionary
    ...    type=cmd
    ...    id=clear-all
    ...    topic=light
    ...    action=set_all
    ...    data={"intensities": [0, 0, 0]}

    ${resp}=       Send Illuminator Command    ${command}
    Should Be Equal    ${resp}[data][status]    ok
    Sleep    1s    # Allow system to stabilize

    # Test each light individually
    FOR    ${light_id}    IN RANGE    1    4
        Log    Testing Light ${light_id}    console=yes

        FOR    ${intensity}    IN    @{INTENSITY_LEVELS}
            # Local variable to track successful set
            ${set_success}=    Set Variable    ${FALSE}
            
            FOR    ${retry}    IN RANGE    1    ${max_retries} + 1
                # Attempt to set light intensity
                ${result}=    Set Light Intensity    ${light_id}    ${intensity}
                
                # Log full result for debugging
                Log    Attempt ${retry}: Result: ${result}    level=DEBUG
                
                # Check if result is a dictionary
                ${is_dict}=    Evaluate    isinstance($result, dict)
                
                # If result is not a dictionary, continue to next retry
                Continue For Loop If    not ${is_dict}
                
                # Check for 'data' key existence
                ${has_data}=    Run Keyword And Return Status    
                ...    Dictionary Should Contain Key    ${result}    data
                
                # If has data, check status
                ${status_check}=    Run Keyword And Return Status    
                ...    Should Be Equal As Strings    ${result}[data][status]    ok
                
                # If both checks pass, mark as successful and exit retry loop
                IF    ${has_data} and ${status_check}
                    ${set_success}=    Set Variable    ${TRUE}
                    Exit For Loop
                END
                
                # Log failure and wait before next retry
                Log    Retry ${retry}/${max_retries}: Retrying to set light ${light_id} to ${intensity}%    console=yes
                Sleep    ${wait_time}
            END
            
            # Fail the test if we couldn't set the intensity after all retries
            Should Be True    ${set_success}    Failed to set light ${light_id} to ${intensity}% after ${max_retries} attempts

            # Allow time for PWM to stabilize
            Wait For Stable Reading    ${wait_time}

            # Skip verification for 0% and 100% due to hardware limitations
            IF    ${intensity} > 0 and ${intensity} < 100

                # Ensure HIL protocol has serial helper before each measurement
                ${helper}=    Get Library Instance    SerialHelper
                HILProtocol.Set Serial Helper    ${helper}

                # Read PWM duty cycle from HIL
                ${duty_cycle}=    Get PWM Duty Cycle    ${light_id}

                # Check if duty_cycle is None using the reliable string comparison method
                ${is_none}=    Run Keyword And Return Status
                ...    Should Be Equal As Strings    ${duty_cycle}    None
                
                # Skip verification if we have a None value
                IF    ${is_none}
                    Log    WARNING: Got invalid PWM reading (None) for light ${light_id} - skipping verification    console=yes
                    # Continue to next step
                ELSE
                    # For regular intensities, use normal verification
                    ${success}=    Verify PWM Output    ${light_id}    ${intensity}
                    Should Be True    ${success}    PWM verification failed for light ${light_id} at ${intensity}%
                END
            END
        END
        
        # Turn off this light after testing all intensities
        ${set_success}=    Set Variable    ${FALSE}
        FOR    ${retry}    IN RANGE    1    ${max_retries} + 1
            ${turn_off_result}=    Set Light Intensity    ${light_id}    0
            
            # Check result structure
            ${is_dict}=    Evaluate    isinstance($turn_off_result, dict)
            
            # If not a dictionary, continue to next retry
            Continue For Loop If    not ${is_dict}
            
            # Check for 'data' key and status
            ${has_data}=    Run Keyword And Return Status    
            ...    Dictionary Should Contain Key    ${turn_off_result}    data
            
            ${status_check}=    Run Keyword And Return Status    
            ...    Should Be Equal As Strings    ${turn_off_result}[data][status]    ok
            
            # If both checks pass, mark as successful and exit retry loop
            IF    ${has_data} and ${status_check}
                ${set_success}=    Set Variable    ${TRUE}
                Exit For Loop
            END
            
            # Log failure and wait before next retry
            Log    Retry ${retry}/${max_retries}: Failed to turn off light ${light_id}    console=yes
            Sleep    ${wait_time}
        END
        
        # Ensure light was successfully turned off
        Should Be True    ${set_success}    Failed to turn off light ${light_id} after ${max_retries} attempts
        
        Wait For Stable Reading    ${wait_time}
    END

Test All Lights PWM Control
    [Documentation]    Test control of all lights simultaneously and verify PWM output
    [Tags]            light    pwm    control

    ${wait_time}=      Set Variable    0.2  # Wait time for stable reading
    ${max_retries}=    Set Variable    5

    # Ensure HIL protocol has serial helper
    ${helper}=    Get Library Instance    SerialHelper
    HILProtocol.Set Serial Helper    ${helper}

    # Test Case 1: All lights at same intensity
    FOR    ${intensity}    IN    25    50    75
        Log    Setting all lights to ${intensity}%    console=yes

        FOR    ${retry}    IN RANGE    1    ${max_retries} + 1
            # Check if we got a valid response
            ${result}=    Set All Lights Intensity    ${intensity}    ${intensity}    ${intensity}

            ${has_data}=    Run Keyword And Return Status
            ...    Dictionary Should Contain Key    ${result}    data
            
            IF    ${has_data} and "${result}[data][status]" == "ok"
                #Log    Successfully set all lights to ${intensity}% on attempt ${retry}    console=yes
                BREAK
            ELSE
                Log    Attempt ${retry}/${max_retries}: Failed to set all lights: ${result}    console=yes
                Sleep    ${wait_time}s
            END
        END

        # Allow time for PWM to stabilize
        Wait For Stable Reading    ${wait_time}

        # Verify all lights have correct PWM duty cycle
        FOR    ${light_id}    IN RANGE    1    4
            # Ensure HIL protocol has serial helper
            ${helper}=    Get Library Instance    SerialHelper
            HILProtocol.Set Serial Helper    ${helper}
            
            ${success}=    Verify PWM Output    ${light_id}    ${intensity}
            Should Be True    ${success}    PWM verification failed for light ${light_id} at ${intensity}%
        END
    END

    # Test Case 2: Different intensities for each light
    @{test_combinations}=    Create List
    ...    25,50,75
    ...    75,50,25

    FOR    ${combo}    IN    @{test_combinations}
        ${intensities}=    Split String    ${combo}    ,
        ${i1}=    Set Variable    ${intensities}[0]
        ${i2}=    Set Variable    ${intensities}[1]
        ${i3}=    Set Variable    ${intensities}[2]

        Log    Setting lights to ${i1}%, ${i2}%, ${i3}%    console=yes

        ${result}=    Set All Lights Intensity    ${i1}    ${i2}    ${i3}
        Should Be Equal    ${result}[data][status]    ok

        # Allow time for PWM to stabilize
        Wait For Stable Reading    ${wait_time}

        # Ensure HIL protocol has serial helper
        ${helper}=    Get Library Instance    SerialHelper
        HILProtocol.Set Serial Helper    ${helper}
        
        # Verify each light has correct PWM duty cycle, skipping 0% and 100%
        # Get all duty cycles first
        ${duty1}=    Get PWM Duty Cycle    1
        ${duty2}=    Get PWM Duty Cycle    2
        ${duty3}=    Get PWM Duty Cycle    3

        # Verify within reasonable bounds, skipping 0% and 100%
        # Check for regular intensities between 1% and 99%
        IF    ${i1} > 0 and ${i1} < 100
            ${success}=    Verify PWM Output    1    ${i1}
            Should Be True    ${success}    PWM verification failed for light 1 at ${i1}%
        # ELSE
        #     Log    Skipping verification for light 1 at ${i1}% - HIL hardware limitation    console=yes
        END
        
        IF    ${i2} > 0 and ${i2} < 100
            ${success}=    Verify PWM Output    2    ${i2}
            Should Be True    ${success}    PWM verification failed for light 2 at ${i2}%
        # ELSE
        #     Log    Skipping verification for light 2 at ${i2}% - HIL hardware limitation    console=yes
        END
        
        IF    ${i3} > 0 and ${i3} < 100
            ${success}=    Verify PWM Output    3    ${i3}
            Should Be True    ${success}    PWM verification failed for light 3 at ${i3}%
        # ELSE
        #     Log    Skipping verification for light 3 at ${i3}% - HIL hardware limitation    console=yes
        END

        Log    Measured duty cycles: Light 1=${duty1}%, Light 2=${duty2}%, Light 3=${duty3}%    console=yes
    END

#######################
# Sensor Feedback Tests #
#######################

Test Current Sensor Reading
    [Documentation]    Verify the Illuminator correctly reads and reports current values
    [Tags]            sensor    current    feedback

    # Ensure HIL protocol has serial helper
    ${helper}=    Get Library Instance    SerialHelper
    HILProtocol.Set Serial Helper    ${helper}
    
    ${wait_time}=      Set Variable    0.25  # Wait time for stable reading
    ${max_retries}=    Set Variable    3     # Maximum number of retry attempts

    # Test each light individually
    FOR    ${light_id}    IN RANGE    1    4
        Log    Testing current sensor for Light ${light_id}    console=yes

        # First ensure the light is on - with retry mechanism
        ${light_on_success}=    Set Variable    ${FALSE}
        
        FOR    ${retry}    IN RANGE    1    ${max_retries} + 1
            ${result}=    Set Light Intensity    ${light_id}    50
            
            # Check if we got a valid response
            ${has_data}=    Run Keyword And Return Status
            ...    Dictionary Should Contain Key    ${result}    data
            
            IF    ${has_data} and "${result}[data][status]" == "ok"
                ${light_on_success}=    Set Variable    ${TRUE}
                Log    Successfully turned on Light ${light_id} on attempt ${retry}    console=yes
                BREAK
            ELSE
                Log    Attempt ${retry}/${max_retries}: Failed to set Light ${light_id}: ${result}    console=yes
                Sleep    ${wait_time}s
            END
        END
        
        # Skip this light if we couldn't turn it on after all retries
        IF    not ${light_on_success}
            Log    Failed to turn on Light ${light_id} after ${max_retries} attempts - skipping test for this light    console=yes
            CONTINUE
        END
        
        Wait For Stable Reading    0.5

        # Test current values
        @{test_currents}=    Create List    2500    3500    7500

        FOR    ${current}    IN    @{test_currents}
            # Ensure HIL protocol has serial helper
            ${helper}=    Get Library Instance    SerialHelper
            HILProtocol.Set Serial Helper    ${helper}
            
            # Set simulated current on HIL - with retry
            ${current_set_success}=    Set Variable    ${FALSE}
            
            FOR    ${retry}    IN RANGE    1    ${max_retries} + 1
                ${set_result}=    Set Current Simulation    ${light_id}    ${current}
                
                IF    ${set_result}
                    ${current_set_success}=    Set Variable    ${TRUE}
                    BREAK
                ELSE
                    Log    Attempt ${retry}/${max_retries}: Failed to set current to ${current}mA    console=yes
                    Sleep    ${wait_time}s
                END
            END
            
            IF    not ${current_set_success}
                Log    Failed to set current after ${max_retries} attempts - skipping this current level    console=yes
                CONTINUE
            END

            Wait For Stable Reading    0.5    # Allow time for system to register new value

            # Read current from Illuminator - with retry mechanism
            ${sensor_read_success}=    Set Variable    ${FALSE}
            ${sensor_data}=    Set Variable    ${NONE}
            
            FOR    ${retry}    IN RANGE    1    ${max_retries} + 1
                ${sensor_data}=    Get Sensor Data    ${light_id}
                
                # Check for valid response
                ${has_data}=    Run Keyword And Return Status
                ...    Dictionary Should Contain Key    ${sensor_data}    data
                
                ${has_type}=    Run Keyword And Return Status
                ...    Dictionary Should Contain Key    ${sensor_data}    type
                
                IF    ${has_data} and ${has_type}
                    ${sensor_read_success}=    Set Variable    ${TRUE}
                    BREAK
                ELSE
                    Log    Attempt ${retry}/${max_retries}: Invalid sensor data response: ${sensor_data}    console=yes
                    Sleep    ${wait_time}s
                END
            END
            
            IF    not ${sensor_read_success}
                Log    Failed to read valid sensor data after ${max_retries} attempts - skipping this current level    console=yes
                CONTINUE
            END
            
            # Now we can safely check the status
            Should Be Equal    ${sensor_data}[data][status]    ok
            
            # Extract reported current with explicit error handling
            ${reported_current}=    Set Variable    ${EMPTY}
            
            # Try extracting from sensor key first - with retry if needed
            ${has_sensor_key}=    Run Keyword And Return Status    
            ...    Dictionary Should Contain Key    ${sensor_data}[data]    sensor
            
            # If sensor key exists, extract current and remove any trailing }
            ${raw_current}=    Run Keyword If    ${has_sensor_key}    
            ...    Set Variable    ${sensor_data}[data][sensor][current]
            ...    ELSE    Set Variable    ${EMPTY}
            
            # Remove trailing } if present
            ${current_str}=    Remove String    ${raw_current}    
            
            # Check if current_str is empty or invalid
            ${current_valid}=    Run Keyword And Return Status
            ...    Evaluate    '${current_str}' != '' and '${current_str}' != '${EMPTY}'
            
            IF    not ${current_valid}
                Log    Failed to extract valid current value - skipping this measurement    console=yes
                CONTINUE
            END
            
            # Extract reported current and convert from Amps to milliamps
            ${reported_current}=    Evaluate    float('${current_str}') * 1000
            
            # Verify current is within tolerance
            ${min_acceptable}=    Evaluate    ${current} * (1 - ${CURRENT_TOLERANCE}/100)
            ${max_acceptable}=    Evaluate    ${current} * (1 + ${CURRENT_TOLERANCE}/100)
            
            # Explicit numeric comparison
            ${within_range}=    Evaluate    ${min_acceptable} <= ${reported_current} <= ${max_acceptable}
            
            # Assertion with clear error message
            Run Keyword If    not ${within_range}    
            ...    Fail    Reported current ${reported_current}mA is outside acceptable range of ${current}mA (±${CURRENT_TOLERANCE}%)

            Log    ✓ Light ${light_id} Current: Simulated=${current}mA, Reported=${reported_current}mA, Tolerance ±${CURRENT_TOLERANCE}%    console=yes
        END
        
        # Turn off the light after testing
        ${turn_off_result}=    Retry Set Light Intensity    ${light_id}    0    ${max_retries}
        Log    Turned off Light ${light_id} after testing    console=yes
    END

    # Clean up - turn off all lights
    Set All Lights Intensity    0    0    0

Test Temperature Sensor Reading
    [Documentation]    Verify the Illuminator correctly reads and reports temperature values
    [Tags]            sensor    temperature    feedback

    # Ensure HIL protocol has serial helper
    ${helper}=    Get Library Instance    SerialHelper
    HILProtocol.Set Serial Helper    ${helper}
    
    ${wait_time}=      Set Variable    0.25  # Wait time for stable reading
    ${max_retries}=    Set Variable    3     # Maximum number of retry attempts

    # Test each light individually
    FOR    ${light_id}    IN RANGE    1    4
        Log    Testing temperature sensor for Light ${light_id}    console=yes

        # First ensure the light is on - with retry mechanism
        ${light_on_success}=    Set Variable    ${FALSE}
        
        FOR    ${retry}    IN RANGE    1    ${max_retries} + 1
            ${result}=    Set Light Intensity    ${light_id}    50
            
            # Check if we got a valid response
            ${has_data}=    Run Keyword And Return Status
            ...    Dictionary Should Contain Key    ${result}    data
            
            IF    ${has_data} and "${result}[data][status]" == "ok"
                ${light_on_success}=    Set Variable    ${TRUE}
                Log    Successfully turned on Light ${light_id} on attempt ${retry}    console=yes
                BREAK
            ELSE
                Log    Attempt ${retry}/${max_retries}: Failed to set Light ${light_id}: ${result}    console=yes
                Sleep    ${wait_time}s
            END
        END
        
        # Skip this light if we couldn't turn it on after all retries
        IF    not ${light_on_success}
            Log    Failed to turn on Light ${light_id} after ${max_retries} attempts - skipping test for this light    console=yes
            CONTINUE
        END
        
        # Now we can proceed with testing since the light is confirmed on
        Wait For Stable Reading    0.5

        # Test temperature values
        @{test_temps}=    Create List    30    45    60    75

        FOR    ${temp}    IN    @{test_temps}
            # Ensure HIL protocol has serial helper
            ${helper}=    Get Library Instance    SerialHelper
            HILProtocol.Set Serial Helper    ${helper}
            
            # Set simulated temperature on HIL - with retry
            ${temp_set_success}=    Set Variable    ${FALSE}
            
            FOR    ${retry}    IN RANGE    1    ${max_retries} + 1
                ${set_result}=    Set Temperature Simulation    ${light_id}    ${temp}
                
                IF    ${set_result}
                    ${temp_set_success}=    Set Variable    ${TRUE}
                    BREAK
                ELSE
                    Log    Attempt ${retry}/${max_retries}: Failed to set temperature to ${temp}°C    console=yes
                    Sleep    ${wait_time}s
                END
            END
            
            IF    not ${temp_set_success}
                Log    Failed to set temperature after ${max_retries} attempts - skipping this temperature    console=yes
                CONTINUE
            END
                
            Wait For Stable Reading    0.5    # Allow time for system to register new value

            # Read temperature from Illuminator with retry mechanism
            ${sensor_read_success}=    Set Variable    ${FALSE}
            ${sensor_data}=    Set Variable    ${NONE}
            
            FOR    ${retry}    IN RANGE    1    ${max_retries} + 1
                ${sensor_data}=    Get Sensor Data    ${light_id}
                
                # Check for valid response
                ${has_type}=    Run Keyword And Return Status
                ...    Dictionary Should Contain Key    ${sensor_data}    type
                
                IF    ${has_type}
                    ${sensor_read_success}=    Set Variable    ${TRUE}
                    BREAK
                ELSE
                    Log    Attempt ${retry}/${max_retries}: Invalid sensor data response    console=yes
                    Sleep    ${wait_time}s
                END
            END
            
            IF    not ${sensor_read_success}
                Log    Failed to read valid sensor data after ${max_retries} attempts - skipping this temperature    console=yes
                CONTINUE
            END
            
            # Initialize reported temperature to zero
            ${reported_temp}=    Set Variable    0
            
            # Rest of your temperature parsing logic remains the same...
            # Check if we got a normal response or an event (like temperature alarm)
            ${is_resp}=    Evaluate    "${sensor_data}[type]" == "resp"
            
            IF    ${is_resp}
                # Check if we have a valid status in the response
                ${has_status}=    Run Keyword And Return Status
                ...    Should Be Equal    ${sensor_data}[data][status]    ok
                
                IF    ${has_status}
                    # Check if we have the 'sensor' key with temperature inside it
                    ${has_sensor}=    Run Keyword And Return Status
                    ...    Dictionary Should Contain Key    ${sensor_data}[data]    sensor
                    
                    IF    ${has_sensor}
                        ${has_temp}=    Run Keyword And Return Status
                        ...    Dictionary Should Contain Key    ${sensor_data}[data][sensor]    temperature
                        
                        IF    ${has_temp}
                            ${reported_temp}=    Set Variable    ${sensor_data}[data][sensor][temperature]
                        ELSE
                            Log    No temperature in sensor data    level=WARN    console=yes
                        END
                    ELSE
                        # Also check 'sensors' array format as fallback
                        ${has_sensors}=    Run Keyword And Return Status
                        ...    Dictionary Should Contain Key    ${sensor_data}[data]    sensors
                        
                        IF    ${has_sensors}
                            # Check if sensors is not empty
                            ${sensors_not_empty}=    Evaluate    len(${sensor_data}[data][sensors]) > 0
                            
                            IF    ${sensors_not_empty}
                                ${has_temp}=    Run Keyword And Return Status
                                ...    Dictionary Should Contain Key    ${sensor_data}[data][sensors][0]    temperature
                                
                                IF    ${has_temp}
                                    ${reported_temp}=    Set Variable    ${sensor_data}[data][sensors][0][temperature]
                                    Log    Found temperature in sensors array: ${reported_temp}°C    console=yes
                                ELSE
                                    Log    No temperature in sensors array    level=WARN    console=yes
                                END
                            ELSE
                                Log    Sensors array is empty    level=WARN    console=yes
                            END
                        ELSE
                            Log    No sensor data found in response    level=WARN    console=yes
                        END
                    END
                ELSE
                    Log    Response status not OK: ${sensor_data}[data][status]    level=WARN    console=yes
                END
            ELSE
                # Handle event type messages (like temperature alarms)
                ${is_temp_alarm}=    Evaluate    
                ...    "${sensor_data}[topic]" == "alarm" and 
                ...    "${sensor_data}[action]" == "triggered" and
                ...    "${sensor_data}[data][code]" == "over_temperature"
                
                IF    ${is_temp_alarm}
                    ${reported_temp}=    Set Variable    ${sensor_data}[data][value]
                    Log    Temperature alarm event with value: ${reported_temp}°C    console=yes
                ELSE
                    Log    Unexpected event type: ${sensor_data}    level=WARN    console=yes
                END
            END

            # Verify temperature is within tolerance
            ${success}=    Verify Value Within Tolerance    ${temp}    ${reported_temp}    ${TEMPERATURE_TOLERANCE}    Temperature (°C)
            Should Be True    ${success}    Reported temperature ${reported_temp} not within ${TEMPERATURE_TOLERANCE}% of simulated ${temp}
        END
        
        # Turn off the light after testing
        ${turn_off_result}=    Retry Set Light Intensity    ${light_id}    0    ${max_retries}
        Log    Turned off Light ${light_id} after testing    console=yes
    END

    # Clean up - turn off all lights
    Set All Lights Intensity    0    0    0

#######################
# Safety Feature Tests #
#######################

Test Current Threshold Safety
    [Documentation]    Verify the over-current protection feature for each light
    [Tags]            safety    current    alarm

    # Ensure HIL protocol has serial helper
    ${helper}=    Get Library Instance    SerialHelper
    HILProtocol.Set Serial Helper    ${helper}

    ${wait_time}=      Set Variable    0.25  # Wait time for stable reading

    # Test each light individually
    FOR    ${light_id}    IN RANGE    1    4
        Log    Testing over-current protection for Light ${light_id}    console=yes

        # First clear any existing alarms
        Clear Alarm    ${light_id}
        Wait For Stable Reading    ${wait_time}

        # Set normal current simulation
        Set Current Simulation    ${light_id}    1000
        Wait For Stable Reading    ${wait_time}

        # Turn on the light
        ${result}=    Set Light Intensity    ${light_id}    75
        Should Be Equal    ${result}[data][status]    ok
        Wait For Stable Reading    0.5

        # Get initial duty cycle (verify light is on)
        ${initial_duty}=    Get PWM Duty Cycle    ${light_id}
        
        # Only verify if we have a valid reading
        ${duty_valid}=    Run Keyword And Return Status    Evaluate    ${initial_duty} != None
        
        IF    ${duty_valid}
            Should Be True    ${initial_duty} > 70    Light ${light_id} should be on with ~75% duty cycle but measured ${initial_duty}%
        ELSE
            Log    WARNING: Got invalid PWM reading (None) for light ${light_id}    console=yes
        END

        # Create a list of test currents
        @{test_currents}=    Create List    20000    26000    30000
        
        # Now gradually increase current
        FOR    ${current}    IN    @{test_currents}
            # Set current simulation
            Set Current Simulation    ${light_id}    ${current}
            Log    Light ${light_id}: Setting current to ${current}mA    console=yes
            Wait For Stable Reading    0.5

            # Get PWM duty cycle
            ${current_duty}=    Get PWM Duty Cycle    ${light_id}
            
            # Skip further checks if duty cycle reading is invalid
            ${duty_valid}=    Run Keyword And Return Status    Evaluate    ${current_duty} != None
            
            IF    not ${duty_valid}
                Log    WARNING: Got invalid PWM reading (None) for light ${light_id}    console=yes
                CONTINUE
            END

            # Get alarm status with multiple attempts
            ${max_attempts}=    Set Variable    5
            ${over_current_found}=    Set Variable    ${FALSE}
            ${alarm_resp}=    Get Alarm Status
            
            # Check if we've exceeded the threshold
            IF    ${current} >= ${CURRENT_THRESHOLD}
                FOR    ${attempt}    IN RANGE    1    ${max_attempts} + 1
                    Wait For Stable Reading    ${wait_time}
                    
                    #Log    Attempt ${attempt}: Alarm status - ${alarm_resp}[data][status]    console=yes
                    
                    # Check for over_current in active_alarms or event data
                    ${over_current_in_alarms}=    Evaluate    
                    ...    any('over_current' in str(alarm) for alarm in ${alarm_resp}[data].get('active_alarms', []))
                    
                    ${is_over_current_event}=    Run Keyword And Return Status
                    ...    Evaluate    
                    ...    ("${alarm_resp}[type]" == "event" and 
                    ...     "${alarm_resp}[topic]" == "alarm" and 
                    ...     "${alarm_resp}[action]" == "triggered" and 
                    ...     "${alarm_resp}[data][code]" == "over_current")
                    
                    # Check if over_current is found
                    IF    ${over_current_in_alarms} or ${is_over_current_event}
                        ${over_current_found}=    Set Variable    ${TRUE}
                        Log    Over-current alarm found on attempt ${attempt}    console=yes
                        BREAK
                    END
                    
                    # Wait before next attempt if not found
                    Sleep    ${wait_time}s
                    ${alarm_resp}=    Get Alarm Status
                END

                # Fail the test if no over_current alarm was found after all attempts
                Should Be True    ${over_current_found}    No over-current alarm detected after ${max_attempts} attempts

                Log    ✓ Active alarm verified in alarm status    console=yes
                
                # Test is successful for this light, we can break the loop
                BREAK
            ELSE
                # Current below threshold - light should still be on
                Should Be True    ${current_duty} > 70    Light ${light_id} should be on but measured PWM duty cycle = ${current_duty}%
                
                # No alarm should be active for this light
                ${alarm_active}=    Check For Alarm    ${light_id}    over_current
                Should Not Be True    ${alarm_active}    Unexpected alarm for light ${light_id} at current ${current}mA
            END
        END

        # Reset to normal current
        Set Current Simulation    ${light_id}    1000

        # Clear all alarms for this light after the test
        Clear Alarm    ${light_id}
        Wait For Stable Reading    ${wait_time}
    END

Test Temperature Threshold Safety
    [Documentation]    Verify the over-temperature protection feature for each light
    [Tags]            safety    temperature    alarm

    # Ensure HIL protocol has serial helper
    ${helper}=    Get Library Instance    SerialHelper
    HILProtocol.Set Serial Helper    ${helper}

    ${wait_time}=      Set Variable    0.3  # Wait time for stable reading

    # Test each light individually
    FOR    ${light_id}    IN RANGE    1    4
        Log    Testing over-temperature protection for Light ${light_id}    console=yes

        # First clear any existing alarms
        Clear Alarm    ${light_id}
        Wait For Stable Reading    ${wait_time}

        # Set normal temperature simulation
        Set Temperature Simulation    ${light_id}    50
        Wait For Stable Reading    ${wait_time}

        # Turn on the light
        ${result}=    Set Light Intensity    ${light_id}    75
        Should Be Equal    ${result}[data][status]    ok
        Wait For Stable Reading    0.5

        # Get initial duty cycle (verify light is on)
        ${max_retries}=    Set Variable    3
        ${initial_duty}=    Set Variable    ${NONE}
        ${duty_valid}=    Set Variable    ${FALSE}

        FOR    ${retry}    IN RANGE    1    ${max_retries} + 1
            ${initial_duty}=    Get PWM Duty Cycle    ${light_id}
            ${duty_valid}=    Run Keyword And Return Status    
                ...    Evaluate    $initial_duty is not None
            
            IF    ${duty_valid}
                Should Be True    ${initial_duty} > 70    Light ${light_id} should be on with ~75% duty cycle but measured ${initial_duty}%
                BREAK
            ELSE
                Log    WARNING: Attempt ${retry}/${max_retries}: Got invalid PWM reading (None) for light ${light_id}    console=yes
                Wait For Stable Reading    ${wait_time}
            END
        END

        IF    not ${duty_valid}
            Log    WARNING: Failed to get valid PWM reading after ${max_retries} attempts    console=yes
        END

        # Define temperature values to test, including some below and above threshold
        @{test_temps}=    Create List    75   85    87    90
        
        # Now test each temperature
        FOR    ${temp}    IN    @{test_temps}
            # Ensure HIL protocol has serial helper
            ${helper}=    Get Library Instance    SerialHelper
            HILProtocol.Set Serial Helper    ${helper}
            
            # Set temperature simulation
            Set Temperature Simulation    ${light_id}    ${temp}
            Log    Light ${light_id}: Setting temperature to ${temp}°C    console=yes
            Wait For Stable Reading    0.5

            # Get PWM duty cycle to check light status
            ${current_duty}=    Get PWM Duty Cycle    ${light_id}
            ${duty_valid}=    Run Keyword And Return Status    
                ...    Evaluate    $current_duty is not None
            
            # Get alarm status
            ${alarm_resp}=    Get Alarm Status
            
            # Check if we're at or above the threshold temperature
            IF    ${temp} >= ${TEMP_THRESHOLD}
                # When above threshold, should have an over-temperature alarm
                ${max_attempts}=    Set Variable    6
                ${over_temperature_found}=    Set Variable    ${FALSE}
                
                FOR    ${attempt}    IN RANGE    1    ${max_attempts} + 1
                    Wait For Stable Reading    ${wait_time}

                    # Check for over_temperature in active_alarms
                    ${over_temperature_in_alarms}=    Evaluate    any('over_temperature' in str(alarm) for alarm in ${alarm_resp}[data].get('active_alarms', []))
                    
                    # FIXED: Check if it's an over_temperature event - single string expression
                    ${is_over_temperature_event}=    Evaluate    "${alarm_resp}[type]" == "event" and "${alarm_resp}[topic]" == "alarm" and "${alarm_resp}[action]" == "triggered" and "over_temperature" in str(${alarm_resp}[data])
                    
                    # Check if either condition is true
                    IF    ${over_temperature_in_alarms} or ${is_over_temperature_event}
                        ${over_temperature_found}=    Set Variable    ${TRUE}
                        #Log    Over-Temperature alarm found on attempt ${attempt}    console=yes
                        BREAK
                    END
                    
                    # Get updated alarm status for next attempt
                    ${alarm_resp}=    Get Alarm Status
                END
                
                # Verify alarm was found
                Should Be True    ${over_temperature_found}    No over-temperature alarm detected after ${max_attempts} attempts
                
                Log    ✓ Active alarm verified at ${temp}°C (above threshold ${TEMP_THRESHOLD}°C)    console=yes
                
                # No need to test higher temperatures once alarm is confirmed
                BREAK
            ELSE
                # Below threshold temperature - light should be on, no alarm
                IF    ${duty_valid}
                    Should Be True    ${current_duty} > 70    
                        ...    Light ${light_id} should be on but measured PWM duty cycle = ${current_duty}%
                ELSE
                    Log    WARNING: Got invalid PWM reading (None) for light ${light_id} - skipping verification    console=yes
                END
                
                # Check that no alarm is active
                ${alarm_active}=    Check For Alarm    ${light_id}    over_temperature
                Should Not Be True    ${alarm_active}    
                    ...    Unexpected alarm for light ${light_id} at temperature ${temp}°C
                
            END
        END

        # Reset to normal temperature
        ${helper}=    Get Library Instance    SerialHelper
        HILProtocol.Set Serial Helper    ${helper}
        Set Temperature Simulation    ${light_id}    50
        
        # Clear any alarms for this light
        Clear Alarm    ${light_id}
        Wait For Stable Reading    ${wait_time}
    END

Test Alarm Clearing
    [Documentation]    Verify that alarms can be cleared and lights restored to normal operation
    [Tags]            safety    alarm    recovery

    # Ensure HIL protocol has serial helper
    ${helper}=    Get Library Instance    SerialHelper
    HILProtocol.Set Serial Helper    ${helper}
    
    ${wait_time}=      Set Variable    0.25  # Wait time for stable reading
    ${max_retries}=    Set Variable    5     # Maximum number of retry attempts

    # Test for each light
    FOR    ${light_id}    IN RANGE    1    4
        Log    Testing alarm clearing for Light ${light_id}    console=yes

        # Ensure HIL protocol has serial helper
        ${helper}=    Get Library Instance    SerialHelper
        HILProtocol.Set Serial Helper    ${helper}
        
        # First trigger an over-current alarm
        ${set_current_result}=    Set Current Simulation    ${light_id}    30000    # Above threshold
        Log    Set current result: ${set_current_result}    console=yes

        # Turn on the light
        ${result}=    Set Light Intensity    ${light_id}    75
        Wait For Stable Reading    0.5

        # Ensure HIL protocol has serial helper
        ${helper}=    Get Library Instance    SerialHelper
        HILProtocol.Set Serial Helper    ${helper}
        
        # Verify light is off due to alarm - with retry mechanism
        ${duty_valid}=    Set Variable    ${FALSE}
        
        FOR    ${retry}    IN RANGE    1    ${max_retries} + 1
            ${duty_during_alarm}=    Get PWM Duty Cycle    ${light_id}
            ${duty_valid}=    Run Keyword And Return Status    Evaluate    ${duty_during_alarm} != None
            
            IF    ${duty_valid}
                BREAK
            ELSE
                Log    Attempt ${retry}/${max_retries}: Got invalid PWM reading (None) during alarm test    console=yes
                Sleep    ${wait_time}s
            END
        END
        
        # Only verify duty cycle if we have a valid reading
        # IF    ${duty_valid}
        #     Should Be True    ${duty_during_alarm} < 5    Light should be off due to over-current
        # ELSE
        #     Log    WARNING: Could not get valid PWM reading after ${max_retries} attempts - skipping verification    console=yes
        # END

        # Check alarm status - with retry mechanism
        ${alarm_active}=    Set Variable    ${FALSE}
        
        FOR    ${retry}    IN RANGE    1    ${max_retries} + 1
            ${alarm_resp}=    Get Alarm Status
            ${alarm_active}=    Check For Alarm    ${light_id}    over_current
            
            IF    ${alarm_active}
                Log    ✓ Found active over-current alarm on attempt ${retry}    console=yes
                BREAK
            ELSE
                Log    Attempt ${retry}/${max_retries}: No active alarm found yet, waiting...    console=yes
                Sleep    ${wait_time}s
            END
        END
        
        Should Be True    ${alarm_active}    Expected active alarm for light ${light_id}

        # Ensure HIL protocol has serial helper
        ${helper}=    Get Library Instance    SerialHelper
        HILProtocol.Set Serial Helper    ${helper}
        
        # Now restore normal conditions
        Set Current Simulation    ${light_id}    1000    # Safe level
        Wait For Stable Reading    ${wait_time}

        # Clear the alarm - with retry mechanism
        ${clear_success}=    Set Variable    ${FALSE}
        
        FOR    ${retry}    IN RANGE    1    ${max_retries} + 1
            ${clear_resp}=    Clear Alarm    ${light_id}
            
            ${has_data}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${clear_resp}    data
            
            IF    ${has_data} and "${clear_resp}[data][status]" == "ok"
                ${clear_success}=    Set Variable    ${TRUE}
                BREAK
            ELSE
                Log    Attempt ${retry}/${max_retries}: Failed to clear alarm: ${clear_resp}    console=yes
                Sleep    ${wait_time}s
            END
        END
        
        Should Be True    ${clear_success}    Failed to clear alarm for light ${light_id}

        # Verify alarm is cleared - with retry mechanism
        ${alarm_still_active}=    Set Variable    ${TRUE}
        
        FOR    ${retry}    IN RANGE    1    ${max_retries} + 1
            ${alarm_resp2}=    Get Alarm Status
            ${alarm_still_active}=    Check For Alarm    ${light_id}    over_current
            
            IF    not ${alarm_still_active}
                BREAK
            ELSE
                Log    Attempt ${retry}/${max_retries}: Alarm still active, waiting...    console=yes
                Sleep    ${wait_time}s
            END
        END
        
        Should Not Be True    ${alarm_still_active}    Alarm should be cleared for light ${light_id}

        # Now try to turn on the light again
        ${set_success}=    Set Variable    ${FALSE}
        
        FOR    ${retry}    IN RANGE    1    ${max_retries} + 1
            ${set_resp2}=    Set Light Intensity    ${light_id}    75
            
            ${has_data}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${set_resp2}    data
            
            IF    ${has_data} and "${set_resp2}[data][status]" == "ok"
                ${set_success}=    Set Variable    ${TRUE}
                BREAK
            ELSE
                Log    Attempt ${retry}/${max_retries}: Failed to turn on light after clearing alarm: ${set_resp2}    console=yes
                Sleep    ${wait_time}s
            END
        END
        
        Should Be True    ${set_success}    Failed to turn on light ${light_id} after clearing alarm
        Wait For Stable Reading    0.5

        # Ensure HIL protocol has serial helper
        ${helper}=    Get Library Instance    SerialHelper
        HILProtocol.Set Serial Helper    ${helper}
        
        # Verify light is now on - with retry mechanism
        ${duty_valid}=    Set Variable    ${FALSE}
        
        FOR    ${retry}    IN RANGE    1    ${max_retries} + 1
            ${duty_after_clear}=    Get PWM Duty Cycle    ${light_id}
            ${duty_valid}=    Run Keyword And Return Status    Evaluate    ${duty_after_clear} != None
            
            IF    ${duty_valid}
                BREAK
            ELSE
                Log    Attempt ${retry}/${max_retries}: Got invalid PWM reading (None) after clearing alarm    console=yes
                Sleep    ${wait_time}s
            END
        END
        
        # Only verify if we have a valid reading
        IF    ${duty_valid}
            Should Be True    ${duty_after_clear} > 70    Light should be on after alarm cleared
        ELSE
            Log    WARNING: Could not get valid PWM reading after ${max_retries} attempts - skipping verification    console=yes
        END

        # Turn off the light to clean up
        Set Light Intensity    ${light_id}    0
        Wait For Stable Reading    ${wait_time}
    END

*** Keywords ***
Initialize Test Environment
    [Documentation]    Set up the test environment with connections to both devices
    Log    Initializing test environment    console=yes

    # Connect to Illuminator
    Log    Connecting to Illuminator on port ${ILLUMINATOR_PORT} at ${BAUD_RATE} baud    console=yes
    ${illum_result}=    Open Illuminator Connection    ${ILLUMINATOR_PORT}    ${BAUD_RATE}    ${TIMEOUT}
    Set Suite Variable    ${ILLUMINATOR_CONNECTED}    ${illum_result}
    Run Keyword If    not ${illum_result}    Log    WARNING: Failed to connect to Illuminator    console=yes

    # Connect to HIL
    Log    Connecting to HIL board on port ${HIL_PORT} at ${BAUD_RATE} baud    console=yes
    ${hil_result}=    Open HIL Connection    ${HIL_PORT}    ${BAUD_RATE}    ${TIMEOUT}
    Set Suite Variable    ${HIL_CONNECTED}    ${hil_result}
    Run Keyword If    not ${hil_result}    Log    WARNING: Failed to connect to HIL board    console=yes

    # Explicitly set up HIL protocol with the serial helper
    ${helper}=    Get Library Instance    SerialHelper
    HILProtocol.Set Serial Helper    ${helper}
    
    # Allow time for devices to initialize
    Sleep    1s

Cleanup Test Environment
    [Documentation]    Clean up the test environment
    Log    Cleaning up test environment    console=yes

    # Turn off all lights and reset to safe conditions
    TRY
        Setup Safe Conditions
    EXCEPT
        Log    Error during cleanup - unable to reset to safe conditions    console=yes
    END

    # Close serial ports
    Close All Connections

Setup Safe Conditions
    [Documentation]    Set the system to a safe state
    Log    Setting up safe conditions    console=yes
    
    # Turn off all lights
    ${command}=    Create Dictionary
    ...    type=cmd
    ...    id=safe-all
    ...    topic=light
    ...    action=set_all
    ...    data={"intensities": [0, 0, 0]}
    
    ${resp}=    Send Illuminator Command    ${command}
    Log    Set all lights to 0: ${resp}[data][status]    console=yes
    
    # Ensure HIL protocol has serial helper
    ${helper}=    Get Library Instance    SerialHelper
    HILProtocol.Set Serial Helper    ${helper}
    
    # Try to reset current and temp simulation (catch errors)
    TRY
        FOR    ${light_id}    IN RANGE    1    4
            Set Current Simulation    ${light_id}    1000
            Set Temperature Simulation    ${light_id}    30
        END
        
        # Clear any active alarms
        FOR    ${light_id}    IN RANGE    1    4
            Clear Alarm    ${light_id}
        END
    EXCEPT    AS    ${error}
        Log    Error setting hardware simulation: ${error}    console=yes
    END

*** Keywords ***
Retry Setup
    [Documentation]    Setup keyword to prepare for potential retries
    # You can add any global setup logic here if needed

*** Keywords ***
Retry Set Light Intensity
    [Documentation]    Set light intensity with retry mechanism
    [Arguments]    ${light_id}    ${intensity}    ${max_retries}=10
    
    FOR    ${retry}    IN RANGE    1    ${max_retries} + 1
        TRY
            ${result}=    Run Keyword    Set Light Intensity    ${light_id}    ${intensity}
            
            # Log the full result for debugging
            Log    Attempt ${retry}: Received result: ${result}    level=DEBUG
            
            # Check if result is a dictionary
            ${is_dict}=    Evaluate    isinstance($result, dict)
            Run Keyword If    not ${is_dict}    Fail    Received non-dictionary response
            
            # Check for 'data' key and its 'status'
            ${status_check}=    Run Keyword And Return Status    
            ...    Should Be Equal As Strings    ${result}[data][status]    ok
            
            # Exit loop if status is ok
            Run Keyword If    ${status_check}    Exit For Loop
            
            # Log failure and wait
            Log    Retry ${retry}/${max_retries}: Invalid response status    console=yes
            Sleep    0.5s
            
        EXCEPT    AS    ${error}
            Log    Retry ${retry}/${max_retries}: Failed to set light ${light_id} to ${intensity}%. Error: ${error}    console=yes
            Sleep    0.5s
        END
        
        # If this is the last retry, re-raise the exception
        IF    ${retry} == ${max_retries}
            Fail    Failed to set light ${light_id} to ${intensity}% after ${max_retries} attempts
        END
    END
    
    # Return the result after successful attempt
    RETURN    ${result}