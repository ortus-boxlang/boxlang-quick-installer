@REM Install BoxLang Modules
set "script_dir=%~dp0"
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '%script_dir%install-bx-module.ps1'" %*
