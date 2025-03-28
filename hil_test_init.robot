*** Settings ***
Documentation     Initialization file for Wiseled_LBR HIL test suite
...               Sets up the test environment and connections to both devices

Resource          resources/wiseled_hil_resources.resource
Library           OperatingSystem

Suite Setup       Initialize Test Suite
Suite Teardown    Cleanup Test Suite

*** Variables ***
${ILLUMINATOR_PORT}    COM4     # Default port for Illuminator, override with -v ILLUMINATOR_PORT:COM4
${HIL_PORT}            COM19    # Default port for HIL board, override with -v HIL_PORT:COM19
${BAUD_RATE}           115200
${TIMEOUT}             5
${LOG_DIR}             ${CURDIR}${/}logs
${TIMESTAMP_FORMAT}    %Y%m%d-%H%M%S

*** Keywords ***
Initialize Test Suite
    [Documentation]    Initialize the test suite environment
    Create Log Directory
    Initialize Connections
    Validate Connections
    Configure Test Environment

Cleanup Test Suite
    [Documentation]    Clean up resources after test suite execution
    Log    Cleaning up test environment    console=yes
    
    TRY
        Setup Safe Conditions
    EXCEPT
        Log    Error during cleanup - unable to reset to safe conditions    console=yes
    END
    
    Close All Connections

Create Log Directory
    [Documentation]    Create directory for logs
    ${timestamp}=    Get Current Date    result_format=${TIMESTAMP_FORMAT}
    ${log_path}=    Set Variable    ${LOG_DIR}${/}${timestamp}
    Create Directory    ${log_path}
    Set Suite Variable    ${CURRENT_LOG_DIR}    ${log_path}
    RETURN    ${log_path}

Initialize Connections
    [Documentation]    Initialize connections to both devices
    
    # Connect to Illuminator
    Log    Connecting to Illuminator on port ${ILLUMINATOR_PORT}    console=yes
    ${illum_result}=    Open Illuminator Connection    ${ILLUMINATOR_PORT}    ${BAUD_RATE}    ${TIMEOUT}
    Set Suite Variable    ${ILLUMINATOR_CONNECTED}    ${illum_result}
    
    # Connect to HIL board
    Log    Connecting to HIL board on port ${HIL_PORT}    console=yes
    ${hil_result}=    Open HIL Connection    ${HIL_PORT}    ${BAUD_RATE}    ${TIMEOUT}
    Set Suite Variable    ${HIL_CONNECTED}    ${hil_result}

Validate Connections
    [Documentation]    Validate connections to both devices
    
    # Check if both connections are established
    IF    not ${ILLUMINATOR_CONNECTED}
        Log    Failed to connect to Illuminator on port ${ILLUMINATOR_PORT}    console=yes    level=WARN
        Fail    Cannot continue without Illuminator connection
    END
    
    IF    not ${HIL_CONNECTED}
        Log    Failed to connect to HIL board on port ${HIL_PORT}    console=yes    level=WARN
        Fail    Cannot continue without HIL board connection
    END
    
    # Try basic communication with both devices
    TRY
        ${illum_ping}=    Ping Illuminator
        Log    Illuminator ping successful    console=yes
    EXCEPT
        Log    Failed to communicate with Illuminator    console=yes    level=WARN
        Fail    Cannot continue without valid Illuminator communication
    END
    
    TRY
        ${hil_ping}=    Ping HIL
        Log    HIL board ping successful    console=yes
    EXCEPT
        Log    Failed to communicate with HIL board    console=yes    level=WARN
        Fail    Cannot continue without valid HIL board communication
    END
    
    Log    All connections validated successfully    console=yes

Configure Test Environment
    [Documentation]    Configure the test environment
    
    # Set up safe conditions for testing
    Setup Safe Conditions
    
    # Brief delay to allow devices to stabilize
    Sleep    1s
