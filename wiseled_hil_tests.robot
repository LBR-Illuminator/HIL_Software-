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
${ILLUMINATOR_PORT}    COM20     # Default port for Illuminator, override with -v ILLUMINATOR_PORT:COM4
${HIL_PORT}            COM19    # Default port for HIL board, override with -v HIL_PORT:COM19
${BAUD_RATE}           115200
${TIMEOUT}             5
${RETRY_MAX}           3        # Maximum number of retry attempts
${TOLERANCE}           5        # Tolerance percentage for sensor readings (5%)

# Test intensity values
@{INTENSITY_LEVELS}    0    25    50    75    100

# Safety thresholds (from documentation)
${CURRENT_THRESHOLD}    3000    # 3.0 Amps (in milliamps)
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
            # Set light intensity
            ${result}=    Set Light Intensity    ${light_id}    ${intensity}
            Should Be Equal    ${result}[data][status]    ok
            
            # Allow time for PWM to stabilize
            Wait For Stable Reading    0.5
            
            # Read PWM duty cycle from HIL
            ${duty_cycle}=    Get PWM Duty Cycle    ${light_id}
            
            # Check if intensity is within valid HIL measurement range (1-99%)
            ${verify_pwm}=    Set Variable    ${TRUE}
            IF    ${intensity} == 0 or ${intensity} == 100
                Log    Cannot verify exact PWM at ${intensity}% - HIL hardware limitation    console=yes
                ${verify_pwm}=    Set Variable    ${FALSE}
            END
            
            # Verify PWM value matches commanded intensity (within tolerance)
            IF    ${verify_pwm}
                ${success}=    Verify PWM Output    ${light_id}    ${intensity}
                Should Be True    ${success}    PWM verification failed for light ${light_id} at ${intensity}%
            END
            
            # Check other lights are not affected
            FOR    ${other_light}    IN RANGE    1    4
                IF    ${other_light} != ${light_id}
                    ${other_duty}=    Get PWM Duty Cycle    ${other_light}
                    # Other lights should be at 0% (allow small tolerance due to noise)
                    Should Be True    ${other_duty} < 5    Light ${other_light} should be off but measured PWM duty cycle = ${other_duty}%
                END
            END
        END
    END

Test All Lights PWM Control
    [Documentation]    Test control of all lights simultaneously and verify PWM output
    [Tags]            light    pwm    control
    
    # Test Case 1: All lights at same intensity
    FOR    ${intensity}    IN    25    50    75
        Log    Setting all lights to ${intensity}%    console=yes
        
        ${result}=    Set All Lights Intensity    ${intensity}    ${intensity}    ${intensity}
        Should Be Equal    ${result}[data][status]    ok
        
        # Allow time for PWM to stabilize
        Wait For Stable Reading    0.5
        
        # Verify all lights have correct PWM duty cycle
        FOR    ${light_id}    IN RANGE    1    4
            ${success}=    Verify PWM Output    ${light_id}    ${intensity}
            Should Be True    ${success}    PWM verification failed for light ${light_id} at ${intensity}%
        END
    END
    
    # Test Case 2: Different intensities for each light
    @{test_combinations}=    Create List
    ...    25,50,75
    ...    75,50,25
    ...    100,50,0
    
    FOR    ${combo}    IN    @{test_combinations}
        ${intensities}=    Split String    ${combo}    ,
        ${i1}=    Set Variable    ${intensities}[0]
        ${i2}=    Set Variable    ${intensities}[1]
        ${i3}=    Set Variable    ${intensities}[2]
        
        Log    Setting lights to ${i1}%, ${i2}%, ${i3}%    console=yes
        
        ${result}=    Set All Lights Intensity    ${i1}    ${i2}    ${i3}
        Should Be Equal    ${result}[data][status]    ok
        
        # Allow time for PWM to stabilize
        Wait For Stable Reading    0.5
        
        # Verify each light has correct PWM duty cycle
        # Note: For extreme values (0%, 100%), we use special verification
        ${duty1}=    Get PWM Duty Cycle    1
        ${duty2}=    Get PWM Duty Cycle    2
        ${duty3}=    Get PWM Duty Cycle    3
        
        # Verify within reasonable bounds
        Run Keyword If    ${i1} > 0 and ${i1} < 100    Verify PWM Output    1    ${i1}
        Run Keyword If    ${i2} > 0 and ${i2} < 100    Verify PWM Output    2    ${i2}
        Run Keyword If    ${i3} > 0 and ${i3} < 100    Verify PWM Output    3    ${i3}
        
        # Special verification for extreme values
        Run Keyword If    ${i1} == 0    Should Be True    ${duty1} < 5    Light 1 should be OFF but measured ${duty1}%
        Run Keyword If    ${i1} == 100    Should Be True    ${duty1} > 95    Light 1 should be FULL but measured ${duty1}%
        Run Keyword If    ${i2} == 0    Should Be True    ${duty2} < 5    Light 2 should be OFF but measured ${duty2}%
        Run Keyword If    ${i2} == 100    Should Be True    ${duty2} > 95    Light 2 should be FULL but measured ${duty2}%
        Run Keyword If    ${i3} == 0    Should Be True    ${duty3} < 5    Light 3 should be OFF but measured ${duty3}%
        Run Keyword If    ${i3} == 100    Should Be True    ${duty3} > 95    Light 3 should be FULL but measured ${duty3}%
        
        Log    Measured duty cycles: Light 1=${duty1}%, Light 2=${duty2}%, Light 3=${duty3}%    console=yes
    END

#######################
# Sensor Feedback Tests #
#######################

Test Current Sensor Reading
    [Documentation]    Verify the Illuminator correctly reads and reports current values
    [Tags]            sensor    current    feedback
    
    # Test each light individually
    FOR    ${light_id}    IN RANGE    1    4
        Log    Testing current sensor for Light ${light_id}    console=yes
        
        # First ensure the light is on
        ${result}=    Set Light Intensity    ${light_id}    50
        Should Be Equal    ${result}[data][status]    ok
        Wait For Stable Reading    0.5
        
        # Test current values
        @{test_currents}=    Create List    500    1000    1500    2000    2500
        
        FOR    ${current}    IN    @{test_currents}
            # Set simulated current on HIL
            ${set_result}=    Set Current Simulation    ${light_id}    ${current}
            Should Be True    ${set_result}    Failed to set current simulation
            Wait For Stable Reading    0.5    # Allow time for system to register new value
            
            # Read current from Illuminator
            ${sensor_data}=    Get Sensor Data    ${light_id}
            Should Be Equal    ${sensor_data}[data][status]    ok
            
            # Extract reported current
            ${reported_current}=    Set Variable    ${sensor_data}[data][sensors][0][current]
            
            # Verify current is within tolerance
            ${success}=    Verify Value Within Tolerance    ${current}    ${reported_current}    ${TOLERANCE}    Current (mA)
            Should Be True    ${success}    Reported current ${reported_current} not within ${TOLERANCE}% of simulated ${current}
            
            Log    Light ${light_id} Current: Simulated=${current}mA, Reported=${reported_current}mA    console=yes
        END
    END
    
    # Clean up - turn off all lights
    Set All Lights Intensity    0    0    0

Test Temperature Sensor Reading
    [Documentation]    Verify the Illuminator correctly reads and reports temperature values
    [Tags]            sensor    temperature    feedback
    
    # Test each light individually
    FOR    ${light_id}    IN RANGE    1    4
        Log    Testing temperature sensor for Light ${light_id}    console=yes
        
        # First ensure the light is on
        ${result}=    Set Light Intensity    ${light_id}    50
        Should Be Equal    ${result}[data][status]    ok
        Wait For Stable Reading    0.5
        
        # Test temperature values
        @{test_temps}=    Create List    30    45    60    75
        
        FOR    ${temp}    IN    @{test_temps}
            # Set simulated temperature on HIL
            ${set_result}=    Set Temperature Simulation    ${light_id}    ${temp}
            Should Be True    ${set_result}    Failed to set temperature simulation
            Wait For Stable Reading    0.5    # Allow time for system to register new value
            
            # Read temperature from Illuminator
            ${sensor_data}=    Get Sensor Data    ${light_id}
            Should Be Equal    ${sensor_data}[data][status]    ok
            
            # Extract reported temperature
            ${reported_temp}=    Set Variable    ${sensor_data}[data][sensors][0][temperature]
            
            # Verify temperature is within tolerance
            ${success}=    Verify Value Within Tolerance    ${temp}    ${reported_temp}    ${TOLERANCE}    Temperature (°C)
            Should Be True    ${success}    Reported temperature ${reported_temp} not within ${TOLERANCE}% of simulated ${temp}
            
            Log    Light ${light_id} Temperature: Simulated=${temp}°C, Reported=${reported_temp}°C    console=yes
        END
    END
    
    # Clean up - turn off all lights
    Set All Lights Intensity    0    0    0

#######################
# Safety Feature Tests #
#######################

Test Current Threshold Safety
    [Documentation]    Verify the over-current protection feature for each light
    [Tags]            safety    current    alarm
    
    # Test each light individually
    FOR    ${light_id}    IN RANGE    1    4
        Log    Testing over-current protection for Light ${light_id}    console=yes
        
        # First clear any existing alarms
        Clear Alarm    ${light_id}
        Wait For Stable Reading    0.5
        
        # Set normal current simulation
        Set Current Simulation    ${light_id}    1000
        Wait For Stable Reading    0.5
        
        # Turn on the light
        ${result}=    Set Light Intensity    ${light_id}    75
        Should Be Equal    ${result}[data][status]    ok
        Wait For Stable Reading    1
        
        # Verify PWM is active
        ${initial_duty}=    Get PWM Duty Cycle    ${light_id}
        Should Be True    ${initial_duty} > 70    Light ${light_id} should be on with ~75% duty cycle but measured ${initial_duty}%
        
        # Now gradually increase current until it exceeds threshold
        FOR    ${current}    IN RANGE    2000    3500    500
            Set Current Simulation    ${light_id}    ${current}
            Log    Light ${light_id}: Setting current to ${current}mA    console=yes
            Wait For Stable Reading    1
            
            # Check if light is still on by measuring PWM
            ${current_duty}=    Get PWM Duty Cycle    ${light_id}
            
            # Check alarm status
            ${alarm_resp}=    Get Alarm Status
            
            # If current exceeds threshold, PWM should stop and alarm should be active
            IF    ${current} >= ${CURRENT_THRESHOLD}
                # Verify PWM has stopped
                Should Be True    ${current_duty} < 5    Light ${light_id} should be turned off but measured PWM duty cycle = ${current_duty}%
                
                # Verify alarm is active
                ${has_alarms}=    Run Keyword And Return Status
                ...    Dictionary Should Contain Key    ${alarm_resp}[data]    active_alarms
                
                Should Be True    ${has_alarms}    Expected active_alarms in response data
                
                # Verify that the right light has the right alarm type
                ${alarm_active}=    Check For Alarm    ${light_id}    over_current
                Should Be True    ${alarm_active}    Expected over_current alarm for light ${light_id}
                
                # Test is successful, we can break the loop
                BREAK
            ELSE
                # Current below threshold - light should still be on
                Should Be True    ${current_duty} > 70    Light ${light_id} should be on but measured PWM duty cycle = ${current_duty}%
                
                # No alarm should be active for this light
                ${alarm_active}=    Check For Alarm    ${light_id}    over_current
                Should Be False    ${alarm_active}    Unexpected alarm for light ${light_id} at current ${current}mA
            END
        END
        
        # Reset to normal current
        Set Current Simulation    ${light_id}    1000
    END

Test Temperature Threshold Safety
    [Documentation]    Verify the over-temperature protection feature for each light
    [Tags]            safety    temperature    alarm
    
    # Test each light individually
    FOR    ${light_id}    IN RANGE    1    4
        Log    Testing over-temperature protection for Light ${light_id}    console=yes
        
        # First clear any existing alarms
        Clear Alarm    ${light_id}
        Wait For Stable Reading    0.5
        
        # Set normal temperature simulation
        Set Temperature Simulation    ${light_id}    50
        Wait For Stable Reading    0.5
        
        # Turn on the light
        ${result}=    Set Light Intensity    ${light_id}    75
        Should Be Equal    ${result}[data][status]    ok
        Wait For Stable Reading    1
        
        # Verify PWM is active
        ${initial_duty}=    Get PWM Duty Cycle    ${light_id}
        Should Be True    ${initial_duty} > 70    Light ${light_id} should be on with ~75% duty cycle but measured ${initial_duty}%
        
        # Now gradually increase temperature until it exceeds threshold
        FOR    ${temp}    IN RANGE    70    95    5
            Set Temperature Simulation    ${light_id}    ${temp}
            Log    Light ${light_id}: Setting temperature to ${temp}°C    console=yes
            Wait For Stable Reading    1
            
            # Check if light is still on by measuring PWM
            ${current_duty}=    Get PWM Duty Cycle    ${light_id}
            
            # Check alarm status
            ${alarm_resp}=    Get Alarm Status
            
            # If temperature exceeds threshold, PWM should stop and alarm should be active
            IF    ${temp} >= ${TEMP_THRESHOLD}
                # Verify PWM has stopped
                Should Be True    ${current_duty} < 5    Light ${light_id} should be turned off but measured PWM duty cycle = ${current_duty}%
                
                # Verify alarm is active
                ${has_alarms}=    Run Keyword And Return Status
                ...    Dictionary Should Contain Key    ${alarm_resp}[data]    active_alarms
                
                Should Be True    ${has_alarms}    Expected active_alarms in response data
                
                # Verify that the right light has the right alarm type
                ${alarm_active}=    Check For Alarm    ${light_id}    over_temperature
                Should Be True    ${alarm_active}    Expected over_temperature alarm for light ${light_id}
                
                # Test is successful, we can break the loop
                BREAK
            ELSE
                # Temperature below threshold - light should still be on
                Should Be True    ${current_duty} > 70    Light ${light_id} should be on but measured PWM duty cycle = ${current_duty}%
                
                # No alarm should be active for this light
                ${alarm_active}=    Check For Alarm    ${light_id}    over_temperature
                Should Be False    ${alarm_active}    Unexpected alarm for light ${light_id} at temperature ${temp}°C
            END
        END
        
        # Reset to normal temperature
        Set Temperature Simulation    ${light_id}    50
    END

Test Alarm Clearing
    [Documentation]    Verify that alarms can be cleared and lights restored to normal operation
    [Tags]            safety    alarm    recovery
    
    # Test for each light
    FOR    ${light_id}    IN RANGE    1    4
        Log    Testing alarm clearing for Light ${light_id}    console=yes
        
        # First trigger an over-current alarm
        Set Current Simulation    ${light_id}    3300    # Above threshold
        
        # Turn on the light
        ${result}=    Set Light Intensity    ${light_id}    75
        Wait For Stable Reading    1
        
        # Verify light is off due to alarm
        ${duty_during_alarm}=    Get PWM Duty Cycle    ${light_id}
        Should Be True    ${duty_during_alarm} < 5    Light should be off due to over-current
        
        # Check alarm status
        ${alarm_resp}=    Get Alarm Status
        ${alarm_active}=    Check For Alarm    ${light_id}    over_current
        Should Be True    ${alarm_active}    Expected active alarm
        
        # Now restore normal conditions
        Set Current Simulation    ${light_id}    1000    # Safe level
        Wait For Stable Reading    1
        
        # Clear the alarm
        ${clear_resp}=    Clear Alarm    ${light_id}
        Should Be Equal    ${clear_resp}[data][status]    ok
        
        # Verify alarm is cleared
        ${alarm_resp2}=    Get Alarm Status
        ${alarm_still_active}=    Check For Alarm    ${light_id}    over_current
        Should Be False    ${alarm_still_active}    Alarm should be cleared for light ${light_id}
        
        # Now try to turn on the light again
        ${set_resp2}=    Set Light Intensity    ${light_id}    75
        Should Be Equal    ${set_resp2}[data][status]    ok
        Wait For Stable Reading    1
        
        # Verify light is now on
        ${duty_after_clear}=    Get PWM Duty Cycle    ${light_id}
        Should Be True    ${duty_after_clear} > 70    Light should be on after alarm cleared
        
        # Turn off the light to clean up
        Set Light Intensity    ${light_id}    0
    END

*** Keywords ***
Initialize Test Environment
    [Documentation]    Set up the test environment with connections to both devices
    Log    Initializing test environment    console=yes
    
    # Connect to Illuminator
    Log    Connecting to Illuminator on port ${ILLUMINATOR_PORT} at ${BAUD_RATE} baud    console=yes
    ${illum_result}=    Open Illuminator Connection    ${ILLUMINATOR_PORT}    ${BAUD_RATE}    ${TIMEOUT}
    Set Test Variable    ${ILLUMINATOR_CONNECTED}    ${illum_result}
    Run Keyword If    not ${illum_result}    Log    WARNING: Failed to connect to Illuminator    console=yes
    
    # Connect to HIL
    Log    Connecting to HIL board on port ${HIL_PORT} at ${BAUD_RATE} baud    console=yes
    ${hil_result}=    Open HIL Connection    ${HIL_PORT}    ${BAUD_RATE}    ${TIMEOUT}
    Set Test Variable    ${HIL_CONNECTED}    ${hil_result}
    Run Keyword If    not ${hil_result}    Log    WARNING: Failed to connect to HIL board    console=yes
    
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

Is Illuminator Connected
    [Documentation]    Check if Illuminator is connected
    RETURN    ${ILLUMINATOR_CONNECTED}

Is HIL Connected
    [Documentation]    Check if HIL board is connected
    RETURN    ${HIL_CONNECTED}