*** Settings ***
Documentation     Improved test suite for Wiseled_LBR Illuminator using HIL hardware
...               This suite validates the entire Illuminator system including PWM control,
...               sensor feedback, and safety features by communicating with both the
...               Illuminator device and the HIL test hardware.
...               
...               The improved version uses dedicated serial connections to both devices.

Resource          resources/improved_wiseled_hil_resources.resource
Library           OperatingSystem
Library           Collections
Library           String
Library           DateTime

Suite Setup       Initialize Test Environment
Suite Teardown    Cleanup Test Environment

*** Variables ***
${ILLUMINATOR_PORT}    COM19     # Default port for Illuminator, override with -v ILLUMINATOR_PORT:COM4
${HIL_PORT}            COM20     # Default port for HIL board, override with -v HIL_PORT:COM19
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
    
    # Test basic communication
    TRY
        ${response}=    Ping Illuminator
        Log    Illuminator responded: ${response}    console=yes
    EXCEPT    AS    ${error}
        Fail    Failed to communicate with Illuminator: ${error}
    END

Verify HIL Communication
    [Documentation]    Verify that we can communicate with the HIL board
    [Tags]            smoke    communication
    ${is_open}=       Is HIL Connected
    Should Be True    ${is_open}    HIL serial port is not open
    
    # Test basic communication
    TRY
        ${response}=    Ping HIL
        Log    HIL board responded: ${response}    console=yes
    EXCEPT    AS    ${error}
        Fail    Failed to communicate with HIL board: ${error}
    END

Test Ping To Both Devices
    [Documentation]    Send ping commands to both devices and verify responses
    [Tags]            smoke    communication    system
    
    # Skip test if either device is not connected
    ${illum_connected}=    Is Illuminator Connected
    ${hil_connected}=      Is HIL Connected
    
    Skip If    not ${illum_connected} or not ${hil_connected}
    ...    Skipping test as one or both devices are not connected

    # Ping Illuminator
    ${illuminator_resp}=    Ping Illuminator
    ${has_data}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${illuminator_resp}    data
    ${has_status}=    Run Keyword If    ${has_data}    
    ...    Run Keyword And Return Status    Dictionary Should Contain Key    ${illuminator_resp}[data]    status
    ...    ELSE    Set Variable    ${FALSE}
    
    IF    ${has_status} and "${illuminator_resp}[data][status]" == "ok"
        Log    Illuminator ping successful    console=yes
    ELSE
        Fail    Illuminator ping failed: ${illuminator_resp}
    END

    # Ping HIL board
    ${hil_resp}=    Ping HIL
    Should Be Equal    ${hil_resp}[status]    ok    HIL ping failed
    
    # Display firmware version if available
    IF    'firmware_version' in ${hil_resp}
        Log    HIL board ping successful (Firmware v${hil_resp}[firmware_version])    console=yes
    ELSE
        Log    HIL board ping successful    console=yes
    END

******* Add remaining test cases from the original file here *******

*** Keywords ***
Initialize Test Environment
    [Documentation]    Set up the test environment with connections to both devices
    Log    Initializing test environment    console=yes

    # Connect to Illuminator
    Log    Connecting to Illuminator on port ${ILLUMINATOR_PORT} at ${BAUD_RATE} baud    console=yes
    ${illum_result}=    Open Illuminator Connection    ${ILLUMINATOR_PORT}    ${BAUD_RATE}    ${TIMEOUT}
    Set Suite Variable    ${ILLUMINATOR_CONNECTED}    ${illum_result}
    
    IF    not ${illum_result}
        Log    WARNING: Failed to connect to Illuminator    console=yes    level=WARN
    ELSE
        Log    Successfully connected to Illuminator    console=yes
        
        # Test basic communication
        TRY
            ${ping_result}=    Ping Illuminator
            Log    Illuminator communication verified    console=yes
        EXCEPT    AS    ${error}
            Log    WARNING: Connected to Illuminator but communication failed: ${error}    console=yes    level=WARN
            Set Suite Variable    ${ILLUMINATOR_CONNECTED}    ${FALSE}
        END
    END

    # Connect to HIL
    Log    Connecting to HIL board on port ${HIL_PORT} at ${BAUD_RATE} baud    console=yes
    ${hil_result}=    Open HIL Connection    ${HIL_PORT}    ${BAUD_RATE}    ${TIMEOUT}
    Set Suite Variable    ${HIL_CONNECTED}    ${hil_result}
    
    IF    not ${hil_result}
        Log    WARNING: Failed to connect to HIL board    console=yes    level=WARN
    ELSE
        Log    Successfully connected to HIL board    console=yes
        
        # Test basic communication
        TRY
            ${ping_result}=    Ping HIL
            Log    HIL communication verified    console=yes
        EXCEPT    AS    ${error}
            Log    WARNING: Connected to HIL board but communication failed: ${error}    console=yes    level=WARN
            Set Suite Variable    ${HIL_CONNECTED}    ${FALSE}
        END
    END

    # Allow time for devices to initialize
    Sleep    1s
    
    # Check if we can continue with testing
    ${can_continue}=    Evaluate    ${ILLUMINATOR_CONNECTED} or ${HIL_CONNECTED}
    IF    not ${can_continue}
        Fail    Cannot continue testing: No devices connected
    END

Cleanup Test Environment
    [Documentation]    Clean up the test environment
    Log    Cleaning up test environment    console=yes

    # Turn off all lights and reset to safe conditions
    TRY
        Setup Safe Conditions
    EXCEPT    AS    ${error}
        Log    Error during cleanup - unable to reset to safe conditions: ${error}    console=yes    level=WARN
    END

    # Close serial ports
    Close All Connections