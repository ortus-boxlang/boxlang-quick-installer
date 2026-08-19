$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot 'TestFramework.ps1')

Initialize-TestSuite 'PowerShell BVM installer'
$installer = Join-Path $repoRoot 'src\install-bvm.ps1'

function Invoke-BvmInstallerWithMockDownloads {
    param([string[]]$InstallerArguments)

    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('bvm-installer-' + [guid]::NewGuid())
    [System.IO.Directory]::CreateDirectory($root) | Out-Null
    try {
        $bundleDirectory = Join-Path $root 'bundle'
        New-Item -ItemType Directory -Path $bundleDirectory -Force | Out-Null
        Set-Content -Path (Join-Path $bundleDirectory 'install-bx-module.ps1') -Value '# test bundle' -Encoding UTF8
        $bundle = Join-Path $root 'bundle.zip'
        Compress-Archive -Path (Join-Path $bundleDirectory '*') -DestinationPath $bundle
        $bvmScript = Join-Path $root 'bvm.ps1'
        Set-Content -Path $bvmScript -Value 'Write-Host "BVM test script"' -Encoding UTF8
        $wrapper = Join-Path $root 'run-installer.ps1'
        $wrapperContent = @'
param([string]$Installer, [string]$Bundle, [string]$BvmScript, [string]$BvmHome, [string]$InstallerArguments)
function Invoke-WebRequest {
    [CmdletBinding()]
    param(
        [string]$Uri,
        [string]$OutFile,
        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]$AdditionalArguments
    )

    if ($OutFile) {
        if ($Uri -like '*bvm.ps1') {
            Copy-Item -Path $BvmScript -Destination $OutFile -Force
        } else {
            Copy-Item -Path $Bundle -Destination $OutFile -Force
        }
    }
    return [PSCustomObject]@{ StatusCode = 200 }
}

$env:BVM_HOME = $BvmHome
& $Installer @($InstallerArguments -split '\|')
exit $LASTEXITCODE
'@
        Set-Content -Path $wrapper -Value $wrapperContent -Encoding UTF8
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $wrapper, '-Installer', $installer, '-Bundle', $bundle, '-BvmScript', $bvmScript, '-BvmHome', (Join-Path $root 'home'), '-InstallerArguments', ($InstallerArguments -join '|'))
        $output = & powershell.exe @arguments 2>&1 | Out-String
        return @{ Output = $output; ExitCode = $LASTEXITCODE }
    }
    finally {
        Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Invoke-Test 'skips Java checking when --without-jre is selected' {
    $result = Invoke-BvmInstallerWithMockDownloads @('--yes', '--without-jre')
    Assert-Equal 0 $result.ExitCode 'BVM installation with --without-jre should succeed'
    Assert-Match 'Skipping Java check' $result.Output '--without-jre did not skip the Java check'
    Assert-True ($result.Output -notmatch 'Checking Java installation') '--without-jre still checked Java'
}

Invoke-Test 'checks Java in automatic mode' {
    $result = Invoke-BvmInstallerWithMockDownloads @('--yes', '--with-jre')
    Assert-Equal 0 $result.ExitCode 'BVM installation with --with-jre should succeed'
    Assert-Match 'Checking Java installation' $result.Output '--with-jre did not check Java'
    Assert-Match 'Java not found' $result.Output 'Automatic Java mode did not report missing Java'
}

Complete-TestSuite