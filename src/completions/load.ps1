# Loads the PowerShell completions that sit next to this file.
Get-ChildItem -Path (Join-Path $PSScriptRoot 'powershell') -Filter '*.ps1' -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }
