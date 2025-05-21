:: This is the Windows batch script to install BoxLang to the system.
:: It checks for administrative privileges, and if not, it requests them.
:: It then runs a PowerShell script to perform the installation.
:: This script is intended to be run from the command line with administrative privileges.
:: Usage: install-boxlang.bat [additional_arguments]
:: Note: This script assumes that the PowerShell script 'install-boxlang.ps1' is in the same directory as this batch file.
@REM Install BoxLang
@echo off
setlocal

:: Get the script directory
set "curdir=%~dp0"

:: Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -ArgumentList @('%*') -Verb RunAs"
    exit /b
)

:: Run the PowerShell install script from the same directory
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%curdir%install-boxlang.ps1' %*"