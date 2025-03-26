@echo off
REM Enhanced launcher script for Wiseled_LBR HIL tests (Windows version) with cleaner output

REM Activate virtual environment if it exists
if exist venv\Scripts\activate.bat (
    call venv\Scripts\activate.bat >nul 2>&1
)

REM Default values
set DEFAULT_PORT=COM19
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

cls
echo.
echo =====================================================
echo              Wiseled_LBR Test Runner
echo =====================================================
echo.
echo   Port: %PORT%  ^|  Tags: %TAGS%  ^|  Timeout: %TIMEOUT%s
echo.
echo =====================================================
echo.

REM Run the robot tests with cleaner output
echo Starting test execution...
echo.

if "%TAGS%"=="all" (
    REM Run all tests with cleaner output
    call robot --outputdir "%LOG_DIR%" --consolewidth 0 --console dotted --nostatusrc -v SERIAL_PORT:%PORT% -v TIMEOUT:%TIMEOUT% wiseled_test_suite.robot
) else (
    REM Run only tests with the specified tag with cleaner output
    call robot --outputdir "%LOG_DIR%" --consolewidth 0 --console dotted --nostatusrc -v SERIAL_PORT:%PORT% -v TIMEOUT:%TIMEOUT% -i %TAGS% wiseled_test_suite.robot
)

REM Check if the test failed
if %ERRORLEVEL% neq 0 (
    echo.
    echo [31mTests completed with errors. Error level: %ERRORLEVEL%[0m
) else (
    echo.
    echo [32mAll tests completed successfully.[0m
)

REM Copy the most recent results to the root directory for easy access
copy "%LOG_DIR%\report.html" "report.html" >nul
copy "%LOG_DIR%\log.html" "log.html" >nul

echo.
echo Results saved to %LOG_DIR% and copied to the project root.
echo.
echo Open report.html in your browser to view detailed results.
echo.