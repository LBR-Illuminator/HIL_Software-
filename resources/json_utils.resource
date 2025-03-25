*** Settings ***
Documentation     JSON utilities for Wiseled_LBR testing
Library           JSONLibrary
Library           Collections
Library           String

*** Keywords ***
Parse JSON
    [Documentation]    Parse a JSON string into a dictionary
    [Arguments]    ${json_string}
    ${json_dict}=    Evaluate    json.loads('''${json_string}''')    json
    RETURN    ${json_dict}

Response Should Be Valid
    [Documentation]    Verify that a response has the expected structure and values
    [Arguments]    ${response}    ${expected_type}    ${expected_id}    ${expected_topic}    ${expected_action}
    Dictionary Should Contain Key    ${response}    type
    Dictionary Should Contain Key    ${response}    id
    Dictionary Should Contain Key    ${response}    topic
    Dictionary Should Contain Key    ${response}    action
    Dictionary Should Contain Key    ${response}    data
    
    Should Be Equal    ${response}[type]      ${expected_type}
    Should Be Equal    ${response}[id]        ${expected_id}
    Should Be Equal    ${response}[topic]     ${expected_topic}
    Should Be Equal    ${response}[action]    ${expected_action}

Response Status Should Be
    [Documentation]    Verify that a response has the expected status
    [Arguments]    ${response}    ${expected_status}
    Dictionary Should Contain Key    ${response}[data]    status
    Should Be Equal    ${response}[data][status]    ${expected_status}

Validate JSON Against Schema
    [Documentation]    Validate a JSON object against a schema
    [Arguments]    ${json_obj}    ${schema_file}
    ${schema}=    Load JSON From File    ${schema_file}
    ${result}=    Evaluate    jsonschema.validate($json_obj, $schema)    jsonschema
    RETURN    ${result}

Format JSON Message
    [Documentation]    Format a JSON message for readability
    [Arguments]    ${json_obj}
    ${formatted}=    Evaluate    json.dumps($json_obj, indent=2)    json
    RETURN    ${formatted}

Log JSON Response
    [Documentation]    Log a JSON response in a readable format
    [Arguments]    ${response}    ${level}=INFO
    ${formatted}=    Format JSON Message    ${response}
    Log    ${formatted}    ${level}
