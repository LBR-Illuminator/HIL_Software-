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
    TRY
        SerialLibrary.Add Port    ${port}    baudrate=${baud_rate}    timeout=${timeout}
        SerialLibrary.Port Should Be Open    message=Failed to open serial port ${port}
        Log    Serial connection opened on port ${port} at ${baud_rate} baud
    EXCEPT
        List Available Serial Ports
        Fail    Failed to open serial connection on port ${port}. See available ports above.
    END

Serial Connection Should Be Open
    [Documentation]    Verify that a serial connection is open
    TRY
        SerialLibrary.Port Should Be Open    message=No serial connection is open
    EXCEPT
        List Available Serial Ports
        Fail    No serial connection is open. See available ports above.
    END

List Available Serial Ports
    [Documentation]    Lists all available serial ports on the system
    ${os}=    Evaluate    platform.system()    platform
    IF    '${os}' == 'Windows'
        List Windows Serial Ports
    ELSE IF    '${os}' == 'Darwin'
        List Mac Serial Ports
    ELSE
        List Linux Serial Ports
    END

List Windows Serial Ports
    [Documentation]    List available serial ports on Windows
    Log    Checking available COM ports on Windows:    console=True
    
    # Try using mode command which works in all Windows versions
    ${mode_result}=    Run Process    mode    shell=True
    
    # Extract COM lines from mode output
    ${mode_lines}=    Split To Lines    ${mode_result.stdout}
    ${com_lines}=    Evaluate    [line.strip() for line in $mode_lines if "COM" in line]
    
    # If we found COM ports with mode, display them
    IF    len($com_lines) > 0
        Log    Found COM ports using 'mode' command:    console=True
        FOR    ${line}    IN    @{com_lines}
            Log    - ${line}    console=True
        END
    ELSE
        # Alternative method using PowerShell
        ${ps_cmd}=    Set Variable    powershell -Command "[System.IO.Ports.SerialPort]::GetPortNames()"
        ${ps_result}=    Run Process    ${ps_cmd}    shell=True
        
        # Clean and parse the output
        ${ps_ports}=    Split To Lines    ${ps_result.stdout}
        ${ps_ports}=    Evaluate    [port.strip() for port in $ps_ports if port.strip()]
        
        IF    len($ps_ports) > 0
            Log    Found COM ports using PowerShell:    console=True
            FOR    ${port}    IN    @{ps_ports}
                Log    - ${port}    console=True
            END
        ELSE
            # Last resort - check common COM ports
            Log    No COM ports detected. Checking common port names:    console=True
            FOR    ${i}    IN RANGE    1    20
                ${port}=    Set Variable    COM${i}
                ${exists}=    Run Process    cmd    /c    echo Checking ${port}>\\.\${port}    shell=True
                ${status}=    Evaluate    $exists.rc == 0
                IF    ${status}
                    Log    - ${port} (may be available)    console=True
                END
            END
        END
    END
    
    # General advice for Windows users
    Log    \nTo see all COM ports on your system:    console=True
    Log    1. Open Device Manager    console=True
    Log    2. Expand 'Ports (COM & LPT)'    console=True
    Log    3. Check which COM ports are listed    console=True

List Mac Serial Ports
    [Documentation]    List available serial ports on macOS
    ${result}=    Run Process    ls    -1    /dev/tty.*    /dev/cu.*    shell=True
    @{ports}=    Split String    ${result.stdout}    ${NEWLINE}
    Log    Available Serial Ports on macOS:    console=True
    FOR    ${port}    IN    @{ports}
        ${port}=    Strip String    ${port}
        IF    '${port}' != ''
            Log    - ${port}    console=True
        END
    END

List Linux Serial Ports
    [Documentation]    List available serial ports on Linux
    ${result}=    Run Process    ls    -1    /dev/ttyS*    /dev/ttyUSB*    /dev/ttyACM*    shell=True
    @{ports}=    Split String    ${result.stdout}    ${NEWLINE}
    Log    Available Serial Ports on Linux:    console=True
    FOR    ${port}    IN    @{ports}
        ${port}=    Strip String    ${port}
        IF    '${port}' != ''
            Log    - ${port}    console=True
        END
    END

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