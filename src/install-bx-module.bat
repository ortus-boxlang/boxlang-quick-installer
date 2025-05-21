@echo off
@REM Install BoxLang Modules

:: Get the current script directory
set "script_dir=%~dp0"

:: Execute the PowerShell installer, passing all arguments
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '%script_dir%install-bx-module.ps1' %*"