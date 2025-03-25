*** Settings ***
Documentation     Common keywords and variables for Wiseled_LBR testing
Library           SerialLibrary
Library           Collections
Library           String
Library           OperatingSystem
Library           Process
Library           DateTime

*** Variables ***
${TIMEOUT}            5    # Default timeout in seconds
${NEWLINE}            \n
${LOG_DIR}            ${CURDIR}${/}logs
${TIMESTAMP_FORMAT}   %Y%m%d-%H%M%S

*** Keywords ***
Open Serial Connection
    [Documentation]    Open a serial connection with the specified parameters
    [Arguments]    ${port}    ${baud_rate}    ${timeout}=5
    SerialLibrary.Add Port    ${port}    baudrate=${baud_rate}    timeout=${timeout}
    ${is_open}=    SerialLibrary.Port Is Open
    Should Be True    ${is_open}    Failed to open serial port ${port}
    Log    Serial connection opened on port ${port} at ${baud_rate} baud

Serial Connection Should Be Open
    [Documentation]    Verify that a serial connection is open
    ${is_open}=    SerialLibrary.Port Is Open
    Should Be True    ${is_open}    No serial connection is open

Wait For Response
    [Documentation]    Wait for a response from the serial port
    [Arguments]    ${timeout}=${TIMEOUT}
    ${data}=    SerialLibrary.Read Until    ${NEWLINE}    timeout=${timeout}
    RETURN    ${data}

Send Serial Data
    [Documentation]    Send data over the serial connection
    [Arguments]    ${data}
    SerialLibrary.Write Data    ${data}${NEWLINE}

Generate Timestamp
    [Documentation]    Generate a timestamp string
    ${timestamp}=    Get Current Date    result_format=${TIMESTAMP_FORMAT}
    RETURN    ${timestamp}

Create Log Directory
    [Documentation]    Create a directory for log files if it doesn't exist
    Create Directory    ${LOG_DIR}
    RETURN    ${LOG_DIR}

Log To File
    [Documentation]    Log data to a file
    [Arguments]    ${filename}    ${data}    ${mode}=a
    ${log_dir}=    Create Log Directory
    ${file_path}=    Join Path    ${log_dir}    ${filename}
    Append To File    ${file_path}    ${data}${NEWLINE}    encoding=UTF-8

Current Timestamp
    [Documentation]    Get current timestamp in ISO 8601 format
    ${timestamp}=    Get Current Date    result_format=%Y-%m-%dT%H:%M:%SZ
    RETURN    ${timestamp}
