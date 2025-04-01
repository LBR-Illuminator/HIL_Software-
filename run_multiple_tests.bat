@echo off
setlocal enabledelayedexpansion

:: Set the number of test runs
set TOTAL_RUNS=20

:: Create a directory for comprehensive logging
if not exist logs\multiple_runs mkdir logs\multiple_runs

:: Initialize counters
set TOTAL_PASSED=0
set TOTAL_FAILED=0

:: Run the test multiple times
for /L %%i in (1,1,%TOTAL_RUNS%) do (
    echo Running test suite - Attempt %%i
    
    :: Run the robot test with exitonfailure
    robot --outputdir logs\multiple_runs\run_%%i --consolewidth 0 --exitonfailure wiseled_hil_tests.robot
    
    :: Check the test result
    if !ERRORLEVEL! EQU 0 (
        echo ✓ Test run %%i PASSED
        set /a TOTAL_PASSED+=1
    ) else (
        echo ✗ Test run %%i FAILED
        set /a TOTAL_FAILED+=1
    )
)

:: Calculate pass rate
set /a PASS_RATE=TOTAL_PASSED*100/TOTAL_RUNS

:: Print summary
echo.
echo ===== TEST RUN SUMMARY =====
echo Total Runs:   %TOTAL_RUNS%
echo Passed Runs:  %TOTAL_PASSED%
echo Failed Runs:  %TOTAL_FAILED%
echo Pass Rate:    %PASS_RATE%%%

:: Pause to keep the window open if double-clicked
pause