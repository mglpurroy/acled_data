@echo off
REM Scheduled ACLED update script
REM This script is designed to run automatically via Windows Task Scheduler
REM It includes logging and error handling

setlocal

REM Set log directory (in parent directory)
set SCRIPT_DIR=%~dp0
set PROJECT_DIR=%SCRIPT_DIR%..
set LOG_DIR=%PROJECT_DIR%\logs
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

REM Set log file with timestamp
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do set mydate=%%c-%%a-%%b
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do set mytime=%%a%%b
set mytime=%mytime: =0%
set LOG_FILE=%LOG_DIR%\acled_update_%mydate%_%mytime%.log

REM Redirect output to log file
call :log "======================================================"
call :log "ACLED Scheduled Update Started"
call :log "Date: %date% %time%"
call :log "======================================================"
call :log ""

REM Try to find Rscript
set RSCRIPT=
for /f "delims=" %%i in ('dir /b /ad "C:\Program Files\R" 2^>nul ^| findstr /R "R-"') do (
    if exist "C:\Program Files\R\%%i\bin\Rscript.exe" (
        set RSCRIPT=C:\Program Files\R\%%i\bin\Rscript.exe
    )
)

if "%RSCRIPT%"=="" (
    for /f "delims=" %%i in ('dir /b /ad "C:\Program Files (x86)\R" 2^>nul ^| findstr /R "R-"') do (
        if exist "C:\Program Files (x86)\R\%%i\bin\Rscript.exe" (
            set RSCRIPT=C:\Program Files (x86)\R\%%i\bin\Rscript.exe
        )
    )
)

if "%RSCRIPT%"=="" (
    call :log "ERROR: Rscript not found!"
    call :log "Please install R or update the path in this script."
    exit /b 1
)

call :log "Found R at: %RSCRIPT%"
call :log ""

REM Change to project root directory
cd /d "%PROJECT_DIR%"
call :log "Working directory: %CD%"
call :log ""

REM Run the update
call :log "Running ACLED update..."
call :log ""

"%RSCRIPT%" scripts\update_acled.R >> "%LOG_FILE%" 2>&1
set UPDATE_EXIT=%ERRORLEVEL%

if %UPDATE_EXIT% EQU 0 (
    call :log ""
    call :log "======================================================"
    call :log "Update completed successfully!"
    call :log "======================================================"
) else (
    call :log ""
    call :log "======================================================"
    call :log "ERROR: Update failed with exit code %UPDATE_EXIT%"
    call :log "======================================================"
)

call :log ""
call :log "Log file saved to: %LOG_FILE%"
call :log ""

endlocal
exit /b %UPDATE_EXIT%

:log
echo %~1
echo %~1 >> "%LOG_FILE%"
goto :eof

