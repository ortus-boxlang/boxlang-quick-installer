:: BoxLang Version Manager (BVM) - Windows Batch Wrapper
:: Description: This wrapper script calls the PowerShell BVM implementation
:: Author: BoxLang Team
:: Version: @build.version@
:: License: Apache License, Version 2.0

@echo off
setlocal

:: Get the script directory
set "curdir=%~dp0"

:: Run the PowerShell BVM script from the same directory
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%curdir%bvm.ps1' '%1' @('%2', '%3', '%4', '%5', '%6', '%7', '%8', '%9')"