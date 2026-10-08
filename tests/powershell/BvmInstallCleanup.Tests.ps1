$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot 'TestFramework.ps1')
Initialize-TestSuite 'PowerShell BVM install cleanup'

function Test-InstallCleanup {
    param([string]$Mode, [string]$Phase, [bool]$Force = $false, [string]$Version = '1.18.9')

    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('bvm-cleanup-' + [guid]::NewGuid())
    $versionDir = Join-Path $root 'versions/1.18.9'
    $pipeline = [powershell]::Create()
    try {
        if ($Force) {
            New-Item -ItemType Directory -Path (Join-Path $versionDir 'bin') -Force | Out-Null
            Set-Content (Join-Path $versionDir 'bin/boxlang.bat') 'original'
        }
        $null = $pipeline.AddScript({
            param($Repo, $Root, $Mode, $Phase, $Force, $Version)
            . (Join-Path $Repo 'tests/powershell/TestFramework.ps1')
            Import-ScriptFunctions (Join-Path $Repo 'src/bvm.ps1') @(
                'Install-Version', 'Ensure-BvmDirs', 'Write-BvmInfo',
                'Write-BvmSuccess', 'Write-BvmError', 'Write-BvmWarning'
            )
            $BVM_HOME = $Root
            $BVM_CACHE_DIR = Join-Path $Root 'cache'
            $BVM_VERSIONS_DIR = Join-Path $Root 'versions'
            $BVM_SCRIPTS_DIR = Join-Path $Root 'scripts'
            $DOWNLOAD_BASE_URL = $MINISERVER_BASE_URL = 'https://example.invalid'
            $LATEST_URL = $SNAPSHOT_URL = 'https://example.invalid/boxlang.zip'
            $LATEST_MINISERVER_URL = $SNAPSHOT_MINISERVER_URL = 'https://example.invalid/miniserver.zip'
            function Test-NetworkConnectivity { return $true }
            function Verify-DownloadChecksum { return $true }
            function Fetch-RemoteVersion { return '1.18.9' }
            function Test-Phase {
                param([string]$CurrentPhase)
                if ($Phase -eq $CurrentPhase) {
                    if ($Mode -eq 'cancel') {
                        Set-Content (Join-Path $Root 'ready') $CurrentPhase
                        Start-Sleep -Seconds 60
                    } elseif ($Mode -eq 'failure') {
                        throw 'Simulated installation failure'
                    }
                }
            }
            function Invoke-WebRequest {
                param($Uri, $OutFile, [switch]$UseBasicParsing, $ErrorAction)
                Set-Content $OutFile 'download'
                if ($OutFile -like '*miniserver*') { Test-Phase miniserver }
                else { Test-Phase runtime }
            }
            function Expand-Archive {
                param($Path, $DestinationPath, [switch]$Force, $ErrorAction)
                $bin = Join-Path $DestinationPath 'bin'
                New-Item -ItemType Directory -Path $bin -Force | Out-Null
                if ($Path -like '*miniserver*') { Set-Content (Join-Path $bin 'boxlang-miniserver.bat') 'miniserver' }
                else { Set-Content (Join-Path $bin 'boxlang.bat') 'runtime' }
                Test-Phase extraction
            }
            Install-Version -Version $Version -Force $Force
        }).AddArgument($repoRoot).AddArgument($root).AddArgument($Mode).AddArgument($Phase).AddArgument($Force).AddArgument($Version)
        $pending = $pipeline.BeginInvoke()
        if ($Mode -eq 'cancel') {
            $deadline = [DateTime]::UtcNow.AddSeconds(15)
            while (-not (Test-Path (Join-Path $root 'ready')) -and -not $pending.IsCompleted -and [DateTime]::UtcNow -lt $deadline) {
                Start-Sleep -Milliseconds 20
            }
            Assert-True (Test-Path (Join-Path $root 'ready')) 'Install did not reach cancellation point'
            if (-not $Force) {
                Assert-True (-not (Test-Path $versionDir)) 'Partial install was published before cancellation'
                Assert-True (-not (Test-Path (Join-Path $root "versions/$Version"))) 'Partial alias was published'
            }
            $pipeline.Stop()
        }
        try { $null = $pipeline.EndInvoke($pending) }
        catch {
            if ($Mode -ne 'cancel') { throw }
            Assert-Match 'stopped' $_.Exception.Message 'Unexpected cancellation error'
        }
        $staging = @(Get-ChildItem (Join-Path $root 'cache') -Directory -Filter 'install-*')
        Assert-Equal 0 $staging.Count 'Staging folder remains after installation'
        if ($Mode -eq 'success') {
            Assert-True (-not $pipeline.HadErrors) "Install failed: $($pipeline.Streams.Error)"
            Assert-Equal 'runtime' (Get-Content (Join-Path $versionDir 'bin/boxlang.bat')) 'Runtime was not published'
            Assert-True (Test-Path (Join-Path $versionDir 'bin/boxlang-miniserver.bat')) 'MiniServer was not published'
        } elseif ($Force) {
            Assert-Equal 'original' (Get-Content (Join-Path $versionDir 'bin/boxlang.bat')) 'Forced install destroyed the existing runtime'
        } else {
            Assert-True (-not (Test-Path $versionDir)) 'Incomplete version folder remains'
            Import-ScriptFunctions (Join-Path $repoRoot 'src/bvm.ps1') @(
                'List-InstalledVersions', 'Ensure-BvmDirs', 'Get-CurrentVersion',
                'Write-BvmWarning', 'Write-BvmInfo'
            )
            $BVM_HOME = $root
            $BVM_CACHE_DIR = Join-Path $root 'cache'
            $BVM_VERSIONS_DIR = Join-Path $root 'versions'
            $BVM_SCRIPTS_DIR = Join-Path $root 'scripts'
            $BVM_CURRENT_LINK = Join-Path $root 'current'
            $BVM_CONFIG_FILE = Join-Path $root 'config'
            $listing = List-InstalledVersions 6>&1 | Out-String
            Assert-True ($listing -notmatch '1\.18\.9') 'Incomplete version appears in bvm list'
        }
    }
    finally {
        $pipeline.Dispose()
        Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

foreach ($phase in @('runtime', 'miniserver', 'extraction')) {
    foreach ($mode in @('cancel', 'failure')) {
        Invoke-Test "$mode during $phase removes staging" { Test-InstallCleanup $mode $phase }
        Invoke-Test "$mode during $phase preserves forced reinstall target" { Test-InstallCleanup $mode $phase $true }
    }
}
Invoke-Test 'cancelling latest removes staging' { Test-InstallCleanup cancel runtime $false latest }
Invoke-Test 'cancelling snapshot extraction removes staging' { Test-InstallCleanup cancel extraction $false snapshot }
Invoke-Test 'successful install publishes runtime and MiniServer' { Test-InstallCleanup success '' }
Invoke-Test 'successful forced install replaces existing version' { Test-InstallCleanup success '' $true }
Invoke-Test 'successful latest install publishes detected version' { Test-InstallCleanup success '' $false latest }
Invoke-Test 'successful snapshot install publishes detected version' { Test-InstallCleanup success '' $false snapshot }
Complete-TestSuite
