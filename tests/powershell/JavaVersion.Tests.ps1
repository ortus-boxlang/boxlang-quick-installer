$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot 'TestFramework.ps1')

Initialize-TestSuite 'PowerShell Java version detection'
$installer = Join-Path $repoRoot 'src\install-boxlang.ps1'
Import-ScriptFunctions -Path $installer -Names @('Test-JavaVersion')
$global:requiredJavaVersion = 21

function New-MockJava {
    param([string]$Path, [string]$VersionOutput)

    Set-Content -Path $Path -Value "@echo off`r`necho $VersionOutput 1>&2" -Encoding ASCII
}

function Invoke-JavaDetectionTest {
    param([string[]]$MockVersions)

    $tempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("java-test-" + [guid]::NewGuid())
    $previousPath = $env:PATH
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        New-Item -ItemType Directory -Path $tempDirectory -Force | Out-Null
        $mockJavaDirectories = @()
        for ($index = 0; $index -lt $MockVersions.Count; $index++) {
            $javaDirectory = Join-Path $tempDirectory "java-$index"
            New-Item -ItemType Directory -Path $javaDirectory -Force | Out-Null
            $javaPath = Join-Path $javaDirectory 'java.cmd'
            New-MockJava -Path $javaPath -VersionOutput $MockVersions[$index]
            $mockJavaDirectories += $javaDirectory
        }
        $env:PATH = ($mockJavaDirectories -join ';') + ";$previousPath"
        $ErrorActionPreference = 'Continue'
        return [bool](Test-JavaVersion)
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
        $env:PATH = $previousPath
        Remove-Item $tempDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Invoke-Test 'accepts Java 21' {
    Assert-Equal $true (Invoke-JavaDetectionTest @('openjdk version "21.0.1"')) 'Java 21 should be accepted'
}

Invoke-Test 'rejects Java 17 and Java 8' {
    Assert-Equal $false (Invoke-JavaDetectionTest @('openjdk version "17.0.5"')) 'Java 17 should be rejected'
    Assert-Equal $false (Invoke-JavaDetectionTest @('java version "1.8.0_345"')) 'Java 8 should be rejected'
}

Invoke-Test 'accepts future and Oracle Java versions' {
    Assert-Equal $true (Invoke-JavaDetectionTest @('openjdk version "25.0.0"')) 'Java 25 should be accepted'
    Assert-Equal $true (Invoke-JavaDetectionTest @('java version "21.0.1"')) 'Oracle Java 21 should be accepted'
}

Invoke-Test 'finds a valid Java later on PATH' {
    Assert-Equal $true (Invoke-JavaDetectionTest @('openjdk version "17.0.5"', 'openjdk version "21.0.1"')) 'A later Java 21 should be found'
}

Complete-TestSuite
