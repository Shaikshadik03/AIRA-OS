@echo off
title Install AIRA Desktop to Windows Startup
color 0A
echo ===================================================
echo   AIRA OS Desktop Companion — Windows Startup Setup
echo ===================================================
echo.

set "TARGET_BAT=%~dp0start_aira_desktop.bat"
set "SHORTCUT=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\AIRA_Desktop.lnk"

powershell -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('%SHORTCUT%'); $s.TargetPath = '%TARGET_BAT%'; $s.WorkingDirectory = '%~dp0'; $s.Description = 'AIRA OS Companion Agent'; $s.Save()"

if exist "%SHORTCUT%" (
    echo  [SUCCESS] AIRA Desktop Agent has been registered to start automatically on Windows boot!
    echo  Location: %SHORTCUT%
) else (
    echo  [ERROR] Failed to create startup shortcut.
)
echo.
pause
