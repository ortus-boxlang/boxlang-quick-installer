[CmdletBinding()]
param(
    [string]$Distro
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ((docker info --format '{{.OSType}}') -ne 'linux') {
    throw 'Docker must be switched to Linux containers.'
}

$distributions = @(
    @{ Name = 'alpine'; Image = 'alpine:3.20'; Setup = 'apk add --no-cache zip unzip >/dev/null' },
    @{ Name = 'debian'; Image = 'debian:12'; Setup = 'apt-get update >/dev/null && DEBIAN_FRONTEND=noninteractive apt-get install -y zip unzip >/dev/null' },
    @{ Name = 'ubuntu'; Image = 'ubuntu:24.04'; Setup = 'apt-get update >/dev/null && DEBIAN_FRONTEND=noninteractive apt-get install -y zip unzip >/dev/null' },
    @{ Name = 'fedora'; Image = 'fedora:40'; Setup = 'dnf install -y util-linux zip unzip >/dev/null' },
    @{ Name = 'arch'; Image = 'archlinux:latest'; Setup = 'pacman -Sy --noconfirm util-linux zip unzip >/dev/null' }
)

if ($Distro) {
    $distributions = @($distributions | Where-Object { $_.Name -eq $Distro })
    if ($distributions.Count -eq 0) {
        throw "Unknown Linux distribution '$Distro'."
    }
}

$repository = (Split-Path -Parent $PSScriptRoot)
foreach ($distribution in $distributions) {
    Write-Host "`nRunning POSIX sh tests in $($distribution.Name)" -ForegroundColor Cyan
    $command = "$($distribution.Setup) && sh tests/run.sh"
    & docker run --rm -v "${repository}:/workspace:ro" -w /workspace $distribution.Image sh -c $command
    if ($LASTEXITCODE -ne 0) {
        throw "POSIX sh tests failed in $($distribution.Name)."
    }
}

Write-Host "All $($distributions.Count) Linux container test runs passed." -ForegroundColor Green
