:: BVM (BoxLang Version Manager) Installer
:: Description: This script installs BVM (BoxLang Version Manager) on a Windows system.
:: Author: BoxLang Team
:: Version: @build.version@
:: License: Apache License, Version 2.0

:: This is the Windows batch script to install BVM.
:: It checks for administrative privileges, and if not, it requests them.
:: It then runs a PowerShell script to perform the installation.
:: Usage: install-bvm.bat [additional_arguments]
:: Note: This script assumes that the PowerShell script 'install-bvm.ps1' is in the same directory.
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
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%curdir%install-bvm.ps1' %*"
