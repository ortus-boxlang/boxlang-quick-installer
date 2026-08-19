[CmdletBinding()]
param(
    [string]$TestName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testRoot = Split-Path -Parent $PSCommandPath
$testFiles = @(Get-ChildItem -Path $testRoot -Filter '*.Tests.ps1' -File | Sort-Object Name)
if ($TestName) {
    $testFiles = @($testFiles | Where-Object { $_.BaseName -replace '\.Tests$', '' -eq $TestName })
}

if (-not $testFiles) {
    throw "No PowerShell test suite found for '$TestName'."
}

$failed = @()
foreach ($testFile in $testFiles) {
    Write-Host "`nRunning $($testFile.Name)" -ForegroundColor Cyan
    try {
        & $testFile.FullName
    }
    catch {
        $failed += $testFile.BaseName
        Write-Host "FAILED: $($testFile.BaseName) - $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($failed.Count -gt 0) {
    throw "PowerShell test suites failed: $($failed -join ', ')"
}

Write-Host "All $($testFiles.Count) PowerShell test suites passed." -ForegroundColor Green
