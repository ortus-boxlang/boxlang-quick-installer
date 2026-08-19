$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot 'TestFramework.ps1')

Initialize-TestSuite 'PowerShell BVM use command'
$bvmScript = Join-Path $repoRoot 'src\bvm.ps1'

Invoke-Test 'creates a current junction for the selected version' {
    $testHome = Join-Path ([System.IO.Path]::GetTempPath()) ("bvm-use-test-" + [guid]::NewGuid())
    $previousBvmHome = $env:BVM_HOME
    $previousUserProfile = $env:USERPROFILE
    $previousUserPath = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::User)
    try {
        $env:BVM_HOME = $testHome
        $env:USERPROFILE = $testHome
        $versionDirectory = Join-Path $testHome 'versions\1.12.0'
        New-Item -ItemType Directory -Path $versionDirectory -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $versionDirectory 'bin') -Force | Out-Null

        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $bvmScript use 1.12.0 2>&1 | Out-String
        Assert-Equal 0 $LASTEXITCODE 'bvm use should succeed'
        $current = Join-Path $testHome 'current'
        Assert-True (Test-Path $current) 'BVM current junction was not created'
        Assert-Equal '1.12.0' (Split-Path (Get-Item $current).Target -Leaf) 'BVM current junction targets the wrong version'
        Assert-Match 'Now using BoxLang 1.12.0' $output 'BVM did not report the selected version'
    }
    finally {
        [Environment]::SetEnvironmentVariable('Path', $previousUserPath, [EnvironmentVariableTarget]::User)
        $env:BVM_HOME = $previousBvmHome
        $env:USERPROFILE = $previousUserProfile
        Remove-Item $testHome -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Invoke-Test 'shows BVM command help without network access' {
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $bvmScript help 2>&1 | Out-String
    Assert-Equal 0 $LASTEXITCODE 'bvm help should succeed'
    Assert-Match 'use <version>' $output 'BVM help is missing use command'
    Assert-Match 'local <version>' $output 'BVM help is missing local command'
}

Complete-TestSuite
