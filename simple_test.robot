*** Settings ***
Documentation     Simple test to verify Python library loading
Library           SimpleHelper.py   WITH NAME    SimpleLib

*** Test Cases ***
Test Simple Library
    ${message}=    SimpleLib.Say Hello    World
    Should Be Equal    ${message}    Hello, World!
    
    ${sum}=    SimpleLib.Add Numbers    2    3
    Should Be Equal As Integers    ${sum}    5