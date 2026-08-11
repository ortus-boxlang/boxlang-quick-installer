[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testRoot = $PSScriptRoot
$repository = Split-Path -Parent $testRoot
$dockerCli = Join-Path $env:ProgramFiles 'Docker\Docker\DockerCli.exe'
$originalEngine = docker info --format '{{.OSType}}'
if ($LASTEXITCODE -ne 0) { throw 'Docker must be running.' }

function Set-DockerEngine {
    param([ValidateSet('linux', 'windows')][string]$Engine)

    if ((docker info --format '{{.OSType}}') -eq $Engine) { return }
    if (-not (Test-Path $dockerCli)) { throw "Docker Desktop CLI was not found at '$dockerCli'." }

    $switch = if ($Engine -eq 'linux') { '-SwitchLinuxEngine' } else { '-SwitchWindowsEngine' }
    & $dockerCli $switch
    if ($LASTEXITCODE -ne 0) { throw "Docker could not switch to $Engine containers." }
    if ((docker info --format '{{.OSType}}') -ne $Engine) { throw "Docker did not switch to $Engine containers." }
}

try {
    Set-DockerEngine linux
    & "$testRoot\run-linux-containers.ps1"
    & "$testRoot\run-offline-container-tests.ps1" -Platform Linux

    Set-DockerEngine windows
    & docker run --rm --isolation=hyperv -v "${repository}:C:\workspace:ro" -w C:\workspace mcr.microsoft.com/windows/servercore:ltsc2022 powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\workspace\tests\powershell\run.ps1
    if ($LASTEXITCODE -ne 0) { throw 'Windows PowerShell test suites failed.' }
    & "$testRoot\run-offline-container-tests.ps1" -Platform Windows
}
finally {
    Set-DockerEngine $originalEngine
}

Write-Host 'All Windows host test runs passed.' -ForegroundColor Green