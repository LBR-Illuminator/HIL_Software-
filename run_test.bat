@echo off
REM Simple launcher script for Wiseled_LBR HIL tests (Windows version)

REM Activate virtual environment if it exists
if exist venv\Scripts\activate.bat (
    echo Activating virtual environment...
    call venv\Scripts\activate.bat
)

REM Default values
set DEFAULT_PORT=COM3
set DEFAULT_TAGS=all
set DEFAULT_TIMEOUT=5

REM Parse command-line arguments
if "%~1"=="" (
    set PORT=%DEFAULT_PORT%
) else (
    set PORT=%~1
)

if "%~2"=="" (
    set TAGS=%DEFAULT_TAGS%
) else (
    set TAGS=%~2
)

if "%~3"=="" (
    set TIMEOUT=%DEFAULT_TIMEOUT%
) else (
    set TIMEOUT=%~3
)

REM Generate timestamp for logs
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /format:list') do set datetime=%%I
set TIMESTAMP=%datetime:~0,8%_%datetime:~8,6%
set LOG_DIR=logs\%TIMESTAMP%
mkdir "%LOG_DIR%" 2>nul

echo ==============================================
echo   Wiseled_LBR HIL Test Runner
echo ==============================================
echo Serial Port: %PORT%
echo Test Tags:   %TAGS%
echo Timeout:     %TIMEOUT% seconds
echo Log Dir:     %LOG_DIR%
echo ==============================================

REM Run the robot tests
if "%TAGS%"=="all" (
    REM Run all tests
    robot --outputdir "%LOG_DIR%" -v SERIAL_PORT:"%PORT%" -v TIMEOUT:"%TIMEOUT%" wiseled_test_suite.robot
) else (
    REM Run only tests with the specified tag
    robot --outputdir "%LOG_DIR%" -v SERIAL_PORT:"%PORT%" -v TIMEOUT:"%TIMEOUT%" -i "%TAGS%" wiseled_test_suite.robot
)

REM Copy the most recent results to the root directory for easy access
copy "%LOG_DIR%\report.html" "report.html"
copy "%LOG_DIR%\log.html" "log.html"

echo Tests completed. Results are in %LOG_DIR% and copied to the project root.