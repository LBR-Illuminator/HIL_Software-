*** Settings ***
Documentation     Serial command implementation for Wiseled_LBR testing
Resource          common.resource
Resource          json_utils.resource
Library           JSONLibrary
Library           Collections
Library           String

*** Variables ***
${CMD_WAIT_TIME}    0.1    # Time to wait after sending a command in seconds

*** Keywords ***
Send Command And Get Response
    [Documentation]    Send a command and get the response
    [Arguments]    ${command}
    Send Serial Data    ${command}
    Sleep    ${CMD_WAIT_TIME}
    ${response_str}=    Wait For Response
    ${response}=    Parse JSON    ${response_str}
    Log JSON Response    ${response}
    RETURN    ${response}

Send Ping Command
    [Documentation]    Send a ping command to check connectivity
    [Arguments]    ${cmd_id}
    ${timestamp}=    Current Timestamp
    ${command}=    Catenate    SEPARATOR=
    ...    {"type":"cmd","id":"${cmd_id}","topic":"system","action":"ping","data":{"timestamp":"${timestamp}"}}
    ${response}=    Send Command And Get Response    ${command}
    RETURN    ${response}

Send Get Light Command
    [Documentation]    Send a command to get a specific light's intensity
    [Arguments]    ${cmd_id}    ${light_id}
    ${command}=    Catenate    SEPARATOR=
    ...    {"type":"cmd","id":"${cmd_id}","topic":"light","action":"get","data":{"id":${light_id}}}
    ${response}=    Send Command And Get Response    ${command}
    RETURN    ${response}

Send Get All Lights Command
    [Documentation]    Send a command to get all lights' intensities
    [Arguments]    ${cmd_id}
    ${command}=    Catenate    SEPARATOR=
    ...    {"type":"cmd","id":"${cmd_id}","topic":"light","action":"get_all","data":{}}
    ${response}=    Send Command And Get Response    ${command}
    RETURN    ${response}

Send Set Light Command
    [Documentation]    Send a command to set a specific light's intensity
    [Arguments]    ${cmd_id}    ${light_id}    ${intensity}
    ${command}=    Catenate    SEPARATOR=
    ...    {"type":"cmd","id":"${cmd_id}","topic":"light","action":"set","data":{"id":${light_id},"intensity":${intensity}}}
    ${response}=    Send Command And Get Response    ${command}
    RETURN    ${response}

Send Set All Lights Command
    [Documentation]    Send a command to set all lights' intensities
    [Arguments]    ${cmd_id}    ${intensity1}    ${intensity2}    ${intensity3}
    ${command}=    Catenate    SEPARATOR=
    ...    {"type":"cmd","id":"${cmd_id}","topic":"light","action":"set_all","data":{"intensities":[${intensity1}, ${intensity2}, ${intensity3}]}}
    ${response}=    Send Command And Get Response    ${command}
    RETURN    ${response}

Send Get Sensors Command
    [Documentation]    Send a command to get a specific light's sensor data
    [Arguments]    ${cmd_id}    ${light_id}
    ${command}=    Catenate    SEPARATOR=
    ...    {"type":"cmd","id":"${cmd_id}","topic":"status","action":"get_sensors","data":{"id":${light_id}}}
    ${response}=    Send Command And Get Response    ${command}
    RETURN    ${response}

Send Get All Sensors Command
    [Documentation]    Send a command to get all lights' sensor data
    [Arguments]    ${cmd_id}
    ${command}=    Catenate    SEPARATOR=
    ...    {"type":"cmd","id":"${cmd_id}","topic":"status","action":"get_all_sensors","data":{}}
    ${response}=    Send Command And Get Response    ${command}
    RETURN    ${response}

Send Alarm Status Command
    [Documentation]    Send a command to get alarm status
    [Arguments]    ${cmd_id}
    ${command}=    Catenate    SEPARATOR=
    ...    {"type":"cmd","id":"${cmd_id}","topic":"alarm","action":"status","data":{}}
    ${response}=    Send Command And Get Response    ${command}
    RETURN    ${response}

Send Clear Alarm Command
    [Documentation]    Send a command to clear an alarm for a specific light
    [Arguments]    ${cmd_id}    ${light_id}
    ${command}=    Catenate    SEPARATOR=
    ...    {"type":"cmd","id":"${cmd_id}","topic":"alarm","action":"clear","data":{"lights":[${light_id}]}}
    ${response}=    Send Command And Get Response    ${command}
    RETURN    ${response}