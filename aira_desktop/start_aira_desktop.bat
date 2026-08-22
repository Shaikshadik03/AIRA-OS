@echo off
title AIRA Desktop Agent
color 0A
echo.
echo  =========================================
echo    AIRA Desktop Agent v4.0.0 - Starting
echo  =========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Python is not installed or not in PATH.
    echo  Please install Python from https://www.python.org/downloads/
    echo  Make sure to check "Add Python to PATH" during install.
    pause
    exit /b 1
)

REM Install dependencies if not already installed
echo  [1/2] Checking dependencies...
pip install -r requirements.txt --quiet --disable-pip-version-check

echo  [2/2] Starting AIRA Desktop Agent...
echo.
python main.py

REM If it crashes, pause so you can see the error
if errorlevel 1 (
    echo.
    echo  [ERROR] AIRA Desktop Agent stopped unexpectedly.
    pause
)
