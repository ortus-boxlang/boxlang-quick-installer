@REM Install BoxLang
@echo off
setlocal

:: Pass in the arguments to the PS script!

:: Get current directory
set "curdir=%~dp0"

:: Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process '%~f0' -ArgumentList '%curdir% %1%' -Verb runAs"
    exit /b
)

:: Use passed argument as the working directory (if needed)
if not "%~1"=="" (
    cd /d "%~1"
)

:: Run the Powershell command using the current directory
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '%cd%/install-boxlang.ps1'" %~2
