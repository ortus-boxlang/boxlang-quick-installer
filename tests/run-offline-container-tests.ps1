[CmdletBinding()]
param(
    [ValidateSet('Linux', 'Windows')]
    [string]$Platform,
    [ValidateSet('process', 'hyperv')]
    [string]$WindowsIsolation = 'hyperv'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repository = Split-Path -Parent $PSScriptRoot

function Invoke-OfflineLinuxTest {
    param([string]$Name, [string]$Image)

    $setup = switch ($Name) {
        'Alpine' { 'apk add --no-cache zip unzip >/dev/null' }
        'Debian' { 'apt-get update >/dev/null; DEBIAN_FRONTEND=noninteractive apt-get install -y zip unzip >/dev/null' }
        'Ubuntu' { 'apt-get update >/dev/null; DEBIAN_FRONTEND=noninteractive apt-get install -y zip unzip >/dev/null' }
        'Fedora' { 'dnf install -y util-linux zip unzip >/dev/null' }
        'Arch' { 'pacman -Sy --noconfirm util-linux zip unzip >/dev/null' }
    }
    $preparedImage = "boxlang-offline-$($Name.ToLowerInvariant())-$([guid]::NewGuid().ToString('N'))"
    @("FROM $Image", "RUN $setup") | & docker build --quiet --tag $preparedImage --file - $repository
    if ($LASTEXITCODE -ne 0) { throw "Could not prepare the offline test image for $Name." }
    $command = @'
set -eu
if command -v useradd >/dev/null 2>&1; then
    useradd --create-home --shell /bin/sh boxlangtest
else
    adduser -D -h /home/boxlangtest -s /bin/sh boxlangtest
fi
if command -v su >/dev/null 2>&1; then
    HOME=/home/boxlangtest TERM=xterm-256color su boxlangtest -s /bin/sh tests/run.sh
else
    HOME=/home/boxlangtest TERM=xterm-256color runuser -u boxlangtest -- sh tests/run.sh
fi
'@
    $command = $command -replace "`r`n", "`n"

    Write-Host "Running pristine offline test suite in $Name" -ForegroundColor Cyan
    try {
        & docker run --rm --network none -v "${repository}:/workspace:ro" -w /workspace $preparedImage sh -c $command
        if ($LASTEXITCODE -ne 0) { throw "Offline BoxLang installation failed in $Name." }
    }
    finally {
        & docker image rm --force $preparedImage | Out-Null
    }
}

function Invoke-OfflineWindowsTest {
    $command = @'
$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Offline suite must run as a standard user.' }
$env:BOXLANG_EXPECT_STANDARD_USER = 'true'
& C:\workspace\tests\powershell\run.ps1
'@

    Write-Host 'Running pristine offline test suite in Windows Server Core' -ForegroundColor Cyan
    $isolation = "--isolation=$WindowsIsolation"
    & docker run --rm --network none $isolation --user 'ContainerUser' -v "${repository}:C:\workspace:ro" -w C:\workspace mcr.microsoft.com/windows/servercore:ltsc2022 powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $command
    if ($LASTEXITCODE -ne 0) { throw 'Offline BoxLang installation failed in Windows Server Core.' }
}

$dockerOs = docker info --format '{{.OSType}}'
if ($LASTEXITCODE -ne 0) { throw 'Docker must be running.' }

if ($Platform -eq 'Linux' -or (-not $Platform -and $dockerOs -eq 'linux')) {
    if ($dockerOs -ne 'linux') { throw 'Docker must be switched to Linux containers.' }
    $failedDistributions = @()
    foreach ($distribution in @(
        @{ Name = 'Alpine'; Image = 'alpine:3.20' },
        @{ Name = 'Debian'; Image = 'debian:12' },
        @{ Name = 'Ubuntu'; Image = 'ubuntu:24.04' },
        @{ Name = 'Fedora'; Image = 'fedora:40' },
        @{ Name = 'Arch'; Image = 'archlinux:latest' }
    )) {
        try {
            Invoke-OfflineLinuxTest @distribution
        }
        catch {
            $failedDistributions += $distribution.Name
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }
    if ($failedDistributions.Count -gt 0) {
        throw "Offline BoxLang installation failed in: $($failedDistributions -join ', ')."
    }
    exit 0
}

if ($Platform -eq 'Windows' -or (-not $Platform -and $dockerOs -eq 'windows')) {
    if ($dockerOs -ne 'windows') { throw 'Docker must be switched to Windows containers.' }
    Invoke-OfflineWindowsTest
    exit 0
}

throw "Unsupported Docker container mode '$dockerOs'."