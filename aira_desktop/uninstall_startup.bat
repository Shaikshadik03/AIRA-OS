@echo off
title Remove AIRA Desktop from Windows Startup
color 0C
echo =====================================================
echo   AIRA OS Desktop Companion — Remove Windows Startup
echo =====================================================
echo.

set "SHORTCUT=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\AIRA_Desktop.lnk"

if exist "%SHORTCUT%" (
    del /f /q "%SHORTCUT%"
    echo  [SUCCESS] AIRA Desktop shortcut removed from Windows Startup folder.
) else (
    echo  [INFO] No AIRA Desktop startup shortcut was found.
)
echo.
pause
