$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot 'TestFramework.ps1')

Initialize-TestSuite 'PowerShell BVM helpers'
Import-ScriptFunctions -Path (Join-Path $repoRoot 'src\bvm.ps1') -Names @('Get-SemanticVersion', 'Compare-SemanticVersions', 'Ensure-BvmDirs', 'Resolve-VersionAlias', 'Write-BvmrcVersion', 'Read-BvmrcVersion', 'Write-BvmInfo', 'Write-BvmSuccess', 'Write-BvmWarning')

Invoke-Test 'extracts semantic versions' {
    Assert-Equal '1.2.3' (Get-SemanticVersion 'BoxLang 1.2.3+20241201.120000') 'Semantic version extraction failed'
    Assert-Equal $null (Get-SemanticVersion 'no version') 'Invalid version should return null'
}

Invoke-Test 'compares semantic versions' {
    Assert-Equal 0 (Compare-SemanticVersions '1.2.3' '1.2.3') 'Equal versions should compare equally'
    Assert-Equal 1 (Compare-SemanticVersions '1.2.4' '1.2.3') 'Greater version should compare greater'
    Assert-Equal -1 (Compare-SemanticVersions '1.2.3' '1.3.0') 'Lower version should compare lower'
    Assert-Equal 0 (Compare-SemanticVersions '1.2' '1.2.0') 'Missing patch should compare as zero'
}

Invoke-Test 'creates BVM directories in a temporary home' {
    $tempHome = Join-Path ([System.IO.Path]::GetTempPath()) ("bvm-helper-test-" + [guid]::NewGuid())
    try {
        $global:BVM_HOME = $tempHome
        $global:BVM_CACHE_DIR = Join-Path $tempHome 'cache'
        $global:BVM_VERSIONS_DIR = Join-Path $tempHome 'versions'
        $global:BVM_SCRIPTS_DIR = Join-Path $tempHome 'scripts'
        Ensure-BvmDirs
        foreach ($path in @($BVM_HOME, $BVM_CACHE_DIR, $BVM_VERSIONS_DIR, $BVM_SCRIPTS_DIR)) {
            Assert-True (Test-Path $path -PathType Container) "Missing BVM directory $path"
        }
    }
    finally {
        Remove-Item $tempHome -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Invoke-Test 'writes and reads .bvmrc files' {
    $tempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("bvmrc-test-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $tempDirectory -Force | Out-Null
    Push-Location $tempDirectory
    try {
        $global:BVM_VERSIONS_DIR = Join-Path $tempDirectory 'versions'
        New-Item -ItemType Directory -Path (Join-Path $BVM_VERSIONS_DIR '1.12.0') -Force | Out-Null
        Write-BvmrcVersion '1.12.0' | Out-Null
        Assert-Equal '1.12.0' (Read-BvmrcVersion) '.bvmrc version was not read'
    }
    finally {
        Pop-Location
        Remove-Item $tempDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Complete-TestSuite
