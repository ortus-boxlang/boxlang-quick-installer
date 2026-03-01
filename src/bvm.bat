:: BVM (BoxLang Version Manager)
:: Description: BoxLang Version Manager - manages BoxLang installations on Windows.
:: Author: BoxLang Team
:: Version: @build.version@
:: License: Apache License, Version 2.0

:: Usage: bvm <command> [arguments]
:: Run 'bvm help' for full usage information.
@echo off
setlocal

:: Resolve BVM_HOME - default to %USERPROFILE%\.bvm
if not defined BVM_HOME set "BVM_HOME=%USERPROFILE%\.bvm"

:: Determine the location of bvm.ps1
:: First check next to this script (development mode), then in scripts directory
set "curdir=%~dp0"
if exist "%curdir%bvm.ps1" (
    set "BVM_PS1=%curdir%bvm.ps1"
) else if exist "%BVM_HOME%\scripts\bvm.ps1" (
    set "BVM_PS1=%BVM_HOME%\scripts\bvm.ps1"
) else (
    echo Error: bvm.ps1 not found. Please reinstall BVM.
    echo You can reinstall BVM using: iwr -useb https://install-bvm.boxlang.io/install-bvm.ps1 ^| iex
    exit /b 1
)

:: Run BVM PowerShell script with all arguments
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%BVM_PS1%' %*"
