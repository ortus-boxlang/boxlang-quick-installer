# BoxLang Module Script
# Description: This script installs, removes, and lists BoxLang modules from FORGEBOX.
# Author: BoxLang Team
# Version: @build.version@
# License: Apache License, Version 2.0

# Configuration
$FORGEBOX_API_URL = "https://forgebox.io/api/v1"

# Global variables
$LOCAL_INSTALL = $false
$REMOVE_MODE = $false
$FORCE_REMOVE = $false
$LIST_MODE = $false
$MODULES_HOME = ""

# Enable UTF-8 encoding for emoji support
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Parse-ModuleList {
    param([string[]]$Arguments)

    $modules = @()
    $moduleList = ""

    # Concatenate all arguments into a single string, skipping flags
    foreach ($arg in $Arguments) {
        if (-not $arg.StartsWith("--")) {
            $moduleList += " $arg"
        }
    }

    # Replace commas with spaces and normalize whitespace
    $moduleList = $moduleList -replace ",", " " -replace "\s+", " "
    $moduleList = $moduleList.Trim()

    # Split by spaces and add to array
    if ($moduleList) {
        $modules = $moduleList -split " " | Where-Object { $_ -ne "" }
    }

    return $modules
}

function Resolve-ForgeboxStorageUrl {
    param(
        [string]$ModuleName,
        [string]$Version = ""
    )

    $storageUrl = if ($Version) {
        "$FORGEBOX_API_URL/storage/$ModuleName/$Version"
    } else {
        "$FORGEBOX_API_URL/storage/$ModuleName"
    }

    Write-Host "🔗 Resolving secure download URL from ForgeBox storage..." -ForegroundColor Blue

    try {
        # Get the secure download URL
        $storageJson = Invoke-RestMethod -Uri $storageUrl -ErrorAction Stop

        if (-not $storageJson -or -not $storageJson.data) {
            Write-Host "❌ Error: Failed to get secure download URL from ForgeBox storage" -ForegroundColor Red
            exit 1
        }

        $secureUrl = $storageJson.data

        if (-not $secureUrl) {
            Write-Host "❌ Error: Invalid response from ForgeBox storage" -ForegroundColor Red
            exit 1
        }

        return $secureUrl
    } catch {
        Write-Host "❌ Error: Failed to get secure download URL from ForgeBox storage: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Get-BeVersionFromForgebox {
    param([string]$ModuleName)

    Write-Host "🔍 Getting latest bleeding edge version from FORGEBOX..." -ForegroundColor Yellow

    try {
        # Store versions JSON From ForgeBox (versions only)
        $versionsJson = Invoke-RestMethod -Uri "$FORGEBOX_API_URL/entry/$ModuleName/versions" -ErrorAction Stop

        # Validate API response
        if (-not $versionsJson -or -not $versionsJson.data) {
            Write-Host "❌ Error: Failed to fetch version information from FORGEBOX" -ForegroundColor Red
            exit 1
        }

        # Take the first (latest) version regardless of stable/pre-release status
        # The ForgeBox API returns versions in newest-first order
        $version = $versionsJson.data | Select-Object -First 1 | Select-Object -ExpandProperty version

        # Validate parsed data
        if (-not $version) {
            Write-Host "❌ Error: No version(s) found for module '$ModuleName' in FORGEBOX" -ForegroundColor Red
            exit 1
        }

        # Get the full entry info for this version to check for forgeboxStorage
        try {
            $versionJson = Invoke-RestMethod -Uri "$FORGEBOX_API_URL/entry/$ModuleName/versions/$version" -ErrorAction Stop
            if ($versionJson -and $versionJson.data) {
                $downloadUrlTemp = $versionJson.data.downloadURL
                if ($downloadUrlTemp -eq "forgeboxStorage") {
                    $downloadUrl = Resolve-ForgeboxStorageUrl $ModuleName $version
                } elseif ($downloadUrlTemp) {
                    # Use the download URL from API
                    $downloadUrl = $downloadUrlTemp
                } else {
                    # Fallback: build download URL from the artifacts directly
                    $downloadUrl = "https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/$ModuleName/$version/$ModuleName-$version.zip"
                }
            } else {
                # Fallback: build download URL from the artifacts directly
                $downloadUrl = "https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/$ModuleName/$version/$ModuleName-$version.zip"
            }
        } catch {
            # Fallback: build download URL from the artifacts directly
            $downloadUrl = "https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/$ModuleName/$version/$ModuleName-$version.zip"
        }

        return @{
            Version = $version
            DownloadUrl = $downloadUrl
        }
    } catch {
        Write-Host "❌ Error: Failed to fetch version information from FORGEBOX: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Get-SnapshotVersionFromForgebox {
    param([string]$ModuleName)

    Write-Host "🔍 Getting latest snapshot version from FORGEBOX..." -ForegroundColor Yellow

    try {
        # Store versions JSON From ForgeBox (versions only)
        $versionsJson = Invoke-RestMethod -Uri "$FORGEBOX_API_URL/entry/$ModuleName/versions" -ErrorAction Stop

        # Validate API response
        if (-not $versionsJson -or -not $versionsJson.data) {
            Write-Host "❌ Error: Failed to fetch version information from FORGEBOX" -ForegroundColor Red
            exit 1
        }

        # Find the first version with "-snapshot" in the versions array
        $version = $versionsJson.data | Where-Object { $_.version -like "*-snapshot*" } | Select-Object -First 1 | Select-Object -ExpandProperty version

        # Validate parsed data
        if (-not $version) {
            Write-Host "❌ Error: No snapshot version(s) found for module '$ModuleName' in FORGEBOX" -ForegroundColor Red
            exit 1
        }

        # Get the full entry info for this version to check for forgeboxStorage
        try {
            $versionJson = Invoke-RestMethod -Uri "$FORGEBOX_API_URL/entry/$ModuleName/$version" -ErrorAction Stop
            if ($versionJson -and $versionJson.data) {
                $downloadUrlTemp = $versionJson.data.downloadURL
                if ($downloadUrlTemp -eq "forgeboxStorage") {
                    $downloadUrl = Resolve-ForgeboxStorageUrl $ModuleName $version
                } elseif ($downloadUrlTemp) {
                    # Use the download URL from API
                    $downloadUrl = $downloadUrlTemp
                } else {
                    # Fallback: build download URL from the artifacts directly
                    $downloadUrl = "https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/$ModuleName/$version/$ModuleName-$version.zip"
                }
            } else {
                # Fallback: build download URL from the artifacts directly
                $downloadUrl = "https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/$ModuleName/$version/$ModuleName-$version.zip"
            }
        } catch {
            # Fallback: build download URL from the artifacts directly
            $downloadUrl = "https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/$ModuleName/$version/$ModuleName-$version.zip"
        }

        return @{
            Version = $version
            DownloadUrl = $downloadUrl
        }
    } catch {
        Write-Host "❌ Error: Failed to fetch version information from FORGEBOX: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Show-Help {
    Write-Host "📦 BoxLang Module Installer" -ForegroundColor Green
    Write-Host ""
    Write-Host "This script installs, removes, and lists BoxLang modules from FORGEBOX." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor DarkYellow
    Write-Host "  install-bx-module.ps1 <module-name>[@<version>] [<module-name>[@<version>] ...] [--local]"
    Write-Host "  install-bx-module.ps1 --remove <module-name> [<module-name> ...] [--force] [--local]"
    Write-Host "  install-bx-module.ps1 --list [--local]"
    Write-Host "  install-bx-module.ps1 --outdated [--local]"
    Write-Host "  install-bx-module.ps1 --update [--force] [--local]"
    Write-Host "  install-bx-module.ps1 --help"
    Write-Host ""
    Write-Host "Arguments:" -ForegroundColor DarkYellow
    Write-Host "  <module-name>     The name(s) of the module(s) to install. (Comma or space delimited)"
    Write-Host "  [@<version>]      (Optional) The specific semantic version of the module to install"
    Write-Host ""
    Write-Host "Options:" -ForegroundColor DarkYellow
    Write-Host "  --local           Install to/remove from local boxlang_modules folder instead of BoxLang HOME. The BoxLang HOME is the default."
    Write-Host "  --remove          Remove specified module(s)"
    Write-Host "  --force           Skip confirmation when removing or updating module(s) (use with --remove or --update)"
    Write-Host "  --list            Show installed module(s)"
    Write-Host "  --outdated        Check installed modules against FORGEBOX and report which are outdated"
    Write-Host "  --update          Update all outdated module(s) to their latest FORGEBOX version"
    Write-Host "  --help, -h        Show this help message"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor DarkYellow
    Write-Host "  install-bx-module.ps1 bx-orm"
    Write-Host "  install-bx-module.ps1 bx-orm@2.5.0"
    Write-Host "  install-bx-module.ps1 bx-orm bx-ai --local"
    Write-Host "  install-bx-module.ps1 bx-orm,bx-ai,bx-esapi"
    Write-Host "  install-bx-module.ps1 `"bx-orm, bx-ai`" --local"
    Write-Host "  install-bx-module.ps1 --remove bx-orm"
    Write-Host "  install-bx-module.ps1 --remove bx-orm,bx-ai --force"
    Write-Host "  install-bx-module.ps1 --remove `"bx-orm, bx-ai`" --local"
    Write-Host "  install-bx-module.ps1 --list"
    Write-Host "  install-bx-module.ps1 --list --local"
    Write-Host "  install-bx-module.ps1 --outdated"
    Write-Host "  install-bx-module.ps1 --outdated --local"
    Write-Host "  install-bx-module.ps1 --update"
    Write-Host "  install-bx-module.ps1 --update --force --local"
    Write-Host ""
    Write-Host "Notes:" -ForegroundColor DarkYellow
    Write-Host "  - If no version is specified, the latest version from FORGEBOX will be installed"
    Write-Host "  - Multiple modules can be specified, separated by spaces or commas"
    Write-Host "  - Module lists can mix spaces and commas: 'bx-orm, bx-ai bx-esapi'"
    Write-Host "  - Use --local to work with modules in current directory's boxlang_modules folder"
    Write-Host "  - Without --local, modules are managed in BoxLang HOME (~/.boxlang/modules)"
    Write-Host "  - Requires PowerShell to be installed"
}

function Set-BoxJsonDependency {
    param([string]$BoxJsonPath, [string]$ModuleName, [string]$ModuleVersion)

    $boxJson = $null
    if (Test-Path $BoxJsonPath) {
        try { $boxJson = Get-Content $BoxJsonPath -Raw | ConvertFrom-Json } catch { $boxJson = $null }
    }
    if (-not $boxJson) { $boxJson = [PSCustomObject]@{} }

    if (-not ($boxJson.PSObject.Properties.Name -contains 'dependencies') -or -not $boxJson.dependencies) {
        $boxJson | Add-Member -MemberType NoteProperty -Name dependencies -Value ([PSCustomObject]@{}) -Force
    }

    $boxJson.dependencies | Add-Member -MemberType NoteProperty -Name $ModuleName -Value $ModuleVersion -Force
    $boxJson | ConvertTo-Json -Depth 10 | Set-Content -Path $BoxJsonPath
}

function Remove-BoxJsonDependency {
    param([string]$BoxJsonPath, [string]$ModuleName)

    if (-not (Test-Path $BoxJsonPath)) { return }
    try { $boxJson = Get-Content $BoxJsonPath -Raw | ConvertFrom-Json } catch { return }
    if (-not $boxJson) { return }

    if (($boxJson.PSObject.Properties.Name -contains 'dependencies') -and $boxJson.dependencies -and
        ($boxJson.dependencies.PSObject.Properties.Name -contains $ModuleName)) {
        $boxJson.dependencies.PSObject.Properties.Remove($ModuleName)
    }
    $boxJson | ConvertTo-Json -Depth 10 | Set-Content -Path $BoxJsonPath
}

function Get-ModulesManifestPath {
    param([string]$ModulesPath)

    $boxJsonPath = Join-Path $ModulesPath "box.json"

    # Backfill: generate the manifest from installed modules if it doesn't exist yet
    # (e.g. modules installed before this feature existed, or by an older script version)
    if (-not (Test-Path $boxJsonPath)) {
        Write-Host "🛠️  No box.json manifest found, generating one from installed modules..." -ForegroundColor Yellow
        $moduleDirectories = Get-ChildItem -Path $ModulesPath -Directory -ErrorAction SilentlyContinue
        foreach ($moduleDir in $moduleDirectories) {
            $moduleName = $moduleDir.Name
            $moduleVersion = "unknown"
            $moduleBoxJsonPath = Join-Path $moduleDir.FullName "box.json"
            if (Test-Path $moduleBoxJsonPath) {
                try {
                    $moduleBoxJson = Get-Content $moduleBoxJsonPath -Raw | ConvertFrom-Json
                    if ($moduleBoxJson.version) { $moduleVersion = $moduleBoxJson.version }
                } catch { }
            }
            Set-BoxJsonDependency $boxJsonPath $moduleName $moduleVersion
        }
        # Ensure the manifest exists even if there were no module directories to backfill
        if (-not (Test-Path $boxJsonPath)) {
            '{"dependencies": {}}' | Set-Content -Path $boxJsonPath
        }
    }

    return $boxJsonPath
}

function List-Modules {
    param(
        [string]$ModulesPath,
        [string]$LocationDesc
    )

    Write-Host "📋 Installed BoxLang Modules ($LocationDesc):" -ForegroundColor Yellow

    # Check if modules directory exists
    if (-not (Test-Path $ModulesPath)) {
        Write-Host "📂 No modules directory found at $ModulesPath" -ForegroundColor Yellow
        return
    }

    $boxJsonPath = Get-ModulesManifestPath $ModulesPath

    # Read installed modules from the manifest
    $dependencies = $null
    if (Test-Path $boxJsonPath) {
        try {
            $manifest = Get-Content $boxJsonPath -Raw | ConvertFrom-Json
            if ($manifest.dependencies) { $dependencies = $manifest.dependencies }
        } catch { }
    }

    $depCount = 0
    if ($dependencies) { $depCount = ($dependencies.PSObject.Properties | Measure-Object).Count }

    if ($depCount -eq 0) {
        Write-Host "📭 No modules installed" -ForegroundColor Yellow
    } else {
        foreach ($prop in $dependencies.PSObject.Properties) {
            Write-Host "✓ $($prop.Name) ($($prop.Value))" -ForegroundColor Green
        }
    }
}

###########################################################################
# Version Comparison Functions
###########################################################################

# Extract semantic version (Major.Minor.Patch) from a version string
function Get-SemanticVersion {
    param([string]$VersionString)

    if ($VersionString -match '(\d+\.\d+\.\d+)') {
        return $matches[1]
    }
    return $null
}

# Compare two semantic versions (Major.Minor.Patch)
# Returns: 0 if equal, 1 if first > second, -1 if first < second
function Compare-Versions {
    param(
        [string]$Version1,
        [string]$Version2
    )

    $v1Parts = $Version1.Split('.')
    $v2Parts = $Version2.Split('.')

    for ($i = 0; $i -lt 3; $i++) {
        $v1Part = if ($i -lt $v1Parts.Length) { [int]$v1Parts[$i] } else { 0 }
        $v2Part = if ($i -lt $v2Parts.Length) { [int]$v2Parts[$i] } else { 0 }

        if ($v1Part -gt $v2Part) { return 1 }
        elseif ($v1Part -lt $v2Part) { return -1 }
    }

    return 0
}

###########################################################################
# Outdated / Update Functions
###########################################################################

# Lean ForgeBox "latest version" lookup (no progress messages, no download URL resolution).
function Get-ForgeboxLatestVersion {
    param([string]$ModuleName)

    try {
        $entryJson = Invoke-RestMethod -Uri "$FORGEBOX_API_URL/entry/$ModuleName/latest" -ErrorAction Stop
        if ($entryJson -and $entryJson.data -and $entryJson.data.version) {
            return $entryJson.data.version
        }
    } catch {
        return $null
    }
    return $null
}

# Returns an array of [PSCustomObject]@{ Name; Current; Latest; Status } for every
# dependency in the manifest. Status is one of: uptodate, ahead, outdated, unreachable.
# Dependencies whose current version isn't a parseable semver are skipped entirely.
function Get-OutdatedReport {
    param([string]$ModulesPath)

    $boxJsonPath = Get-ModulesManifestPath $ModulesPath
    $dependencies = $null
    try {
        $manifest = Get-Content $boxJsonPath -Raw | ConvertFrom-Json
        if ($manifest.dependencies) { $dependencies = $manifest.dependencies }
    } catch { }

    $report = @()
    if (-not $dependencies) { return $report }

    foreach ($prop in $dependencies.PSObject.Properties) {
        $moduleName = $prop.Name
        $currentVersion = $prop.Value

        $currentSemver = Get-SemanticVersion $currentVersion
        if (-not $currentSemver) { continue }

        $latestVersion = Get-ForgeboxLatestVersion $moduleName
        $status = $null
        if (-not $latestVersion) {
            $status = "unreachable"
            $latestVersion = "?"
        } else {
            $latestSemver = Get-SemanticVersion $latestVersion
            if (-not $latestSemver) {
                $status = "unreachable"
            } else {
                $cmp = Compare-Versions -Version1 $currentSemver -Version2 $latestSemver
                switch ($cmp) {
                    0  { $status = "uptodate" }
                    1  { $status = "ahead" }
                    -1 { $status = "outdated" }
                }
            }
        }

        $report += [PSCustomObject]@{
            Name = $moduleName
            Current = $currentVersion
            Latest = $latestVersion
            Status = $status
        }
    }

    return $report
}

function Show-Outdated {
    param(
        [string]$ModulesPath,
        [string]$LocationDesc
    )

    Write-Host "🔎 Checking for outdated BoxLang Modules ($LocationDesc):" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Test-Path $ModulesPath)) {
        Write-Host "📂 No modules directory found at $ModulesPath" -ForegroundColor Yellow
        return
    }

    $report = Get-OutdatedReport $ModulesPath

    if ($report.Count -eq 0) {
        Write-Host "📭 No modules to report on" -ForegroundColor Yellow
        return
    }

    "{0,-25} {1,-15} {2,-15} {3}" -f "DEPENDENCY", "CURRENT", "FORGEBOX", "STATUS" | Write-Host
    "{0,-25} {1,-15} {2,-15} {3}" -f "-------------------------", "---------------", "---------------", "--------------------" | Write-Host

    $outdated = @()
    foreach ($entry in $report) {
        $statusLabel = switch ($entry.Status) {
            "uptodate" { "✅ up to date" }
            "ahead" { "🔄 ahead (dev/snapshot)" }
            "outdated" { $outdated += $entry; "🆙 outdated" }
            default { "⚠️  unable to check" }
        }
        "{0,-25} {1,-15} {2,-15} {3}" -f $entry.Name, $entry.Current, $entry.Latest, $statusLabel | Write-Host
    }

    Write-Host ""
    if ($outdated.Count -eq 0) {
        Write-Host "✅ All modules are up to date" -ForegroundColor Green
        return
    }

    Write-Host "⚠️  $($outdated.Count) module(s) outdated" -ForegroundColor Yellow
    $confirmation = Read-Host "⬆️  Would you like to update $($outdated.Count) outdated module(s) now? [y/N]"
    if ($confirmation -match "^[yY]([eE][sS])?$") {
        foreach ($entry in $outdated) {
            Install-Module "$($entry.Name)@$($entry.Latest)"
        }
    } else {
        Write-Host "Skipping updates." -ForegroundColor Yellow
    }
}

function Update-Modules {
    param(
        [string]$ModulesPath,
        [string]$LocationDesc,
        [bool]$ForceUpdate = $false
    )

    Write-Host "🔎 Checking for outdated BoxLang Modules ($LocationDesc):" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Test-Path $ModulesPath)) {
        Write-Host "📂 No modules directory found at $ModulesPath" -ForegroundColor Yellow
        return
    }

    $report = Get-OutdatedReport $ModulesPath
    $outdated = $report | Where-Object { $_.Status -eq "outdated" }

    foreach ($entry in $outdated) {
        Write-Host "🆙 $($entry.Name): $($entry.Current) → $($entry.Latest)"
    }

    if (-not $outdated -or $outdated.Count -eq 0) {
        Write-Host "✅ All modules are up to date, nothing to update" -ForegroundColor Green
        return
    }

    Write-Host ""
    if (-not $ForceUpdate) {
        $confirmation = Read-Host "⬆️  Update $($outdated.Count) outdated module(s)? [y/N]"
        if ($confirmation -notmatch "^[yY]([eE][sS])?$") {
            Write-Host "❌ Update cancelled" -ForegroundColor Yellow
            return
        }
    }

    foreach ($entry in $outdated) {
        Install-Module "$($entry.Name)@$($entry.Latest)"
    }

    Write-Host "✅ Updated $($outdated.Count) module(s)!" -ForegroundColor Green
}

function Get-LatestVersionFromForgebox {
    param([string]$ModuleName)

    Write-Host "🔍 No version specified, getting latest version from FORGEBOX..." -ForegroundColor Yellow

    try {
        # Store Entry JSON From ForgeBox
        $entryJson = Invoke-RestMethod -Uri "$FORGEBOX_API_URL/entry/$ModuleName/latest" -ErrorAction Stop

        # Validate API response
        if (-not $entryJson -or -not $entryJson.data) {
            Write-Host "❌ Error: Failed to fetch module information from FORGEBOX" -ForegroundColor Red
            exit 1
        }

        $version = $entryJson.data.version
        $downloadUrl = $entryJson.data.downloadURL

        # Validate parsed data
        if (-not $version) {
            Write-Host "❌ Error: Module '$ModuleName' not found in FORGEBOX" -ForegroundColor Red
            exit 1
        }

        if (-not $downloadUrl) {
            Write-Host "❌ Error: No download URL found for module '$ModuleName'" -ForegroundColor Red
            exit 1
        }

        # Check if download URL is forgeboxStorage keyword
        if ($downloadUrl -eq "forgeboxStorage") {
            $downloadUrl = Resolve-ForgeboxStorageUrl $ModuleName
        }

        return @{
            Version = $version
            DownloadUrl = $downloadUrl
        }
    } catch {
        Write-Host "❌ Error: Failed to fetch module information from FORGEBOX: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Install-Module {
    param([string]$moduleName)

    $targetModule = ""
    $targetVersion = ""

    if ($moduleName.Contains("@")) {
        $parts = $moduleName -split "@"
        $targetModule = $parts[0].ToLower()
        $targetVersion = $parts[1]
    } else {
        $targetModule = $moduleName.ToLower()
    }

    # Validate module name
    if (-not $targetModule) {
        Write-Host "❌ Error: You must specify a BoxLang module to install" -ForegroundColor Red
        Write-Host "💡 Usage: install-bx-module.ps1 <module-name>[@<version>] [--local]" -ForegroundColor Yellow
        exit 1
    }

    # Fetch version based on specification
    if (-not $targetVersion) {
        $forgeboxResult = Get-LatestVersionFromForgebox $targetModule
        $targetVersion = $forgeboxResult.Version
        $downloadUrl = $forgeboxResult.DownloadUrl
    } elseif ($targetVersion -eq "be") {
        $forgeboxResult = Get-BeVersionFromForgebox $targetModule
        $targetVersion = $forgeboxResult.Version
        $downloadUrl = $forgeboxResult.DownloadUrl
    } elseif ($targetVersion -eq "snapshot") {
        $forgeboxResult = Get-SnapshotVersionFromForgebox $targetModule
        $targetVersion = $forgeboxResult.Version
        $downloadUrl = $forgeboxResult.DownloadUrl
    } else {
        # We have a targeted version, first try to get it from ForgeBox API to check for forgeboxStorage
        try {
            $versionJson = Invoke-RestMethod -Uri "$FORGEBOX_API_URL/entry/$targetModule/$targetVersion" -ErrorAction Stop
            if ($versionJson -and $versionJson.data) {
                $downloadUrlTemp = $versionJson.data.downloadURL
                if ($downloadUrlTemp -eq "forgeboxStorage") {
                    $downloadUrl = Resolve-ForgeboxStorageUrl $targetModule $targetVersion
                } else {
                    # Use the download URL from API if available
                    $downloadUrl = $downloadUrlTemp
                }
            } else {
                # Fallback: build the download URL from the artifacts directly
                $downloadUrl = "https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/$targetModule/$targetVersion/$targetModule-$targetVersion.zip"
            }
        } catch {
            # Fallback: build the download URL from the artifacts directly
            $downloadUrl = "https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/$targetModule/$targetVersion/$targetModule-$targetVersion.zip"
        }
    }

    # Define paths based on LOCAL_INSTALL flag
    $destination = Join-Path $MODULES_HOME $targetModule

    # Check if module is already installed
    if (Test-Path $destination) {
        Write-Host "⚠️  Module '$targetModule' is already installed at $destination" -ForegroundColor Yellow
        Write-Host "🔄 Proceeding with installation (will overwrite existing)..." -ForegroundColor Yellow
    }

    # Inform the user
    Write-Host "📦 Installing BoxLang® Module: $targetModule@$targetVersion" -ForegroundColor Green
    Write-Host "📍 Destination: $destination" -ForegroundColor Green
    Write-Host ""

    # Ensure module folders exist
    if (-not (Test-Path $MODULES_HOME)) {
        New-Item -Path $MODULES_HOME -ItemType Directory -Force | Out-Null
    }

    # Create secure temporary file
    $tempFile = [System.IO.Path]::GetTempFileName()
    $tempFile = $tempFile -replace "\.tmp$", ".zip"

    try {
        # Download module
        Write-Host "⬇️  Downloading from $downloadUrl..." -ForegroundColor Blue
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -ErrorAction Stop

        # Record installation by calling forgebox at: /api/v1/install/${TARGET_MODULE}/${TARGET_VERSION}
        Write-Host "📊 Recording installation with FORGEBOX..." -ForegroundColor Blue
        try {
            Invoke-RestMethod -Uri "$FORGEBOX_API_URL/install/$targetModule/$targetVersion" -Method Get -ErrorAction Stop | Out-Null
        } catch {
            Write-Host "⚠️  Warning: Failed to record installation with FORGEBOX, but continuing..." -ForegroundColor Yellow
        }

        # Remove existing module folder
        if (Test-Path $destination) {
            Remove-Item -Path $destination -Recurse -Force
        }

        # Extract module
        Write-Host "📦 Extracting module..." -ForegroundColor Blue
        Expand-Archive -Path $tempFile -DestinationPath $destination -Force

        # Verify extraction
        if (-not (Test-Path $destination) -or -not (Get-ChildItem -Path $destination -ErrorAction SilentlyContinue)) {
            Write-Host "❌ Error: Module extraction appears to have failed - destination directory is empty" -ForegroundColor Red
            exit 1
        }

        # Check for executables in box.json and create bin scripts
        $boxJsonPath = Join-Path $destination "box.json"
        if (Test-Path $boxJsonPath) {
            try {
                $boxJson = Get-Content $boxJsonPath | ConvertFrom-Json

                # Get BOXLANG_HOME for bin directory
                $binDir = if ($LOCAL_INSTALL) {
                    Join-Path (Get-Location) "boxlang_modules\.bin"
                } else {
                    if (-not $env:BOXLANG_HOME) {
                        $env:BOXLANG_HOME = Join-Path $env:USERPROFILE ".boxlang"
                    }
                    Join-Path $env:BOXLANG_HOME "bin"
                }

                # Create bin directory if it doesn't exist
                if (-not (Test-Path $binDir)) {
                    New-Item -Path $binDir -ItemType Directory -Force | Out-Null
                }

                # Get the module name to use for execution (check boxlang.moduleName first, fallback to targetModule)
                $moduleName = $targetModule
                if ($boxJson.boxlang -and $boxJson.boxlang.moduleName) {
                    $moduleName = $boxJson.boxlang.moduleName
                }

                # Check for boxlang.executable (single executable)
                if ($boxJson.boxlang -and $boxJson.boxlang.executable) {
                    $executable = $boxJson.boxlang.executable
                    $execScript = Join-Path $binDir "$executable"
                    Write-Host "🔧 Creating executable script: $executable" -ForegroundColor Blue

                    # Create shell script
                    $scriptContent = @"
#!/bin/sh
boxlang module:$moduleName `"`$@`"
"@
                    Set-Content -Path $execScript -Value $scriptContent -NoNewline

                    # Also create .bat for Windows
                    $execBat = Join-Path $binDir "$executable.bat"
                    $batContent = @"
@echo off
boxlang module:$moduleName %*
"@
                    Set-Content -Path $execBat -Value $batContent
                }

                # Check for boxlang.executables (multiple executables)
                if ($boxJson.boxlang -and $boxJson.boxlang.executables) {
                    Write-Host "🔧 Creating executable scripts..." -ForegroundColor Blue
                    $executables = $boxJson.boxlang.executables
                    foreach ($execName in $executables.PSObject.Properties.Name) {
                        $execContent = $executables.$execName
                        if ($execContent) {
                            $execScript = Join-Path $binDir $execName
                            Write-Host "  - Creating: $execName" -ForegroundColor Blue
                            Set-Content -Path $execScript -Value $execContent -NoNewline

                            # Also create .bat version if it's a shell script
                            if ($execContent -match '^#!/') {
                                # It's a shell script, create a .bat wrapper
                                $execBat = Join-Path $binDir "$execName.bat"
                                $batWrapper = "@echo off`r`nbash `"%~dp0$execName`" %*"
                                Set-Content -Path $execBat -Value $batWrapper
                            }
                        }
                    }
                }
            } catch {
                # Silently ignore box.json parsing errors
            }
        }

        # Track this install in the modules manifest
        Set-BoxJsonDependency (Join-Path $MODULES_HOME "box.json") $targetModule $targetVersion

        # Success message
        Write-Host ""
        Write-Host "✅ BoxLang® Module [$targetModule@$targetVersion] installed successfully!" -ForegroundColor Green

    } catch {
        Write-Host "❌ Error: Download failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    } finally {
        # Cleanup temp file
        if (Test-Path $tempFile) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

function Remove-Module {
    param(
        [string]$ModuleName,
        [bool]$ForceRemove = $false
    )

    # Validate module name
    if (-not $ModuleName) {
        Write-Host "❌ Error: You must specify a BoxLang module to remove" -ForegroundColor Red
        exit 1
    }

    # Convert to lowercase to match installation convention
    $ModuleName = $ModuleName.ToLower()

    # Define module path
    $modulePath = Join-Path $MODULES_HOME $ModuleName

    # Check if module exists
    if (-not (Test-Path $modulePath)) {
        Write-Host "📭 Module '$ModuleName' is not installed at $modulePath" -ForegroundColor Yellow
        return
    }

    # Get module version for display if available
    $moduleVersion = "unknown"
    $boxJsonPath = Join-Path $modulePath "box.json"
    if (Test-Path $boxJsonPath) {
        try {
            $boxJson = Get-Content $boxJsonPath | ConvertFrom-Json
            if ($boxJson.version) {
                $moduleVersion = $boxJson.version
            }
        } catch {
            # Keep default "unknown"
        }
    }

    # Show what will be removed
    Write-Host "🔍 Found module: $ModuleName ($moduleVersion) at $modulePath" -ForegroundColor Yellow

    # Ask for confirmation unless --force is used
    if (-not $ForceRemove) {
        $confirmation = Read-Host "⚠️  Are you sure you want to remove this module? [y/N]"
        if ($confirmation -notmatch "^[yY]([eE][sS])?$") {
            Write-Host "❌ Module removal cancelled" -ForegroundColor Yellow
            return
        }
    }

    # Remove the module directory
    Write-Host "🗑️  Removing module $ModuleName..." -ForegroundColor Blue
    try {
        Remove-Item -Path $modulePath -Recurse -Force
        Write-Host "✅ Module '$ModuleName' removed successfully!" -ForegroundColor Green
        # Untrack this module from the modules manifest
        Remove-BoxJsonDependency (Join-Path $MODULES_HOME "box.json") $ModuleName
    } catch {
        Write-Host "❌ Error: Failed to remove module '$ModuleName': $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Main execution starts here

# Check if no arguments are passed
if ($args.Count -eq 0) {
    Write-Host "❌ Error: No module(s) specified" -ForegroundColor Red
    Write-Host "💡 This script installs or removes BoxLang modules." -ForegroundColor Yellow
	Show-Help
    exit 1
}

# Show help if requested
if ($args[0] -eq "--help" -or $args[0] -eq "-h") {
    Show-Help
    exit 0
}

# Handle --list command (can be used with --local)
if ($args[0] -eq "--list") {
    $LIST_MODE = $true
    $remainingArgs = $args[1..($args.Count-1)]

    # Check if --local is specified with --list
    $LOCAL_LIST = $false
    if ($remainingArgs -contains "--local") {
        $LOCAL_LIST = $true
        $remainingArgs = $remainingArgs | Where-Object { $_ -ne "--local" }
    }

    # Ensure no other arguments after --list [--local]
    if ($remainingArgs.Count -gt 1) {
        Write-Host "❌ Error: --list command does not accept additional arguments" -ForegroundColor Red
        Write-Host "💡 Usage: install-bx-module.ps1 --list [--local]" -ForegroundColor Yellow
        exit 1
    }

    # Set up paths for listing
    if ($LOCAL_LIST) {
        $modulesPath = Join-Path (Get-Location) "boxlang_modules"
        $locationDesc = "Local - $(Get-Location)\boxlang_modules"
    } else {
        if (-not $env:BOXLANG_HOME) {
            $env:BOXLANG_HOME = Join-Path $env:USERPROFILE ".boxlang"
        }
        $modulesPath = Join-Path $env:BOXLANG_HOME "modules"
        $locationDesc = "Global - $($env:BOXLANG_HOME)\modules"
    }

    List-Modules $modulesPath $locationDesc
    exit 0
}

# Handle --outdated command (can be used with --local)
if ($args[0] -eq "--outdated") {
    $remainingArgs = @()
    if ($args.Count -gt 1) {
        $remainingArgs = $args[1..($args.Count-1)]
    }

    $OUTDATED_LOCAL = $false
    if ($remainingArgs -contains "--local") {
        $OUTDATED_LOCAL = $true
        $remainingArgs = $remainingArgs | Where-Object { $_ -ne "--local" }
    }

    if ($remainingArgs.Count -gt 0) {
        Write-Host "❌ Error: --outdated command does not accept additional arguments" -ForegroundColor Red
        Write-Host "💡 Usage: install-bx-module.ps1 --outdated [--local]" -ForegroundColor Yellow
        exit 1
    }

    $LOCAL_INSTALL = $OUTDATED_LOCAL
    if ($OUTDATED_LOCAL) {
        $MODULES_HOME = Join-Path (Get-Location) "boxlang_modules"
        $locationDesc = "Local - $(Get-Location)\boxlang_modules"
    } else {
        if (-not $env:BOXLANG_HOME) {
            $env:BOXLANG_HOME = Join-Path $env:USERPROFILE ".boxlang"
        }
        $MODULES_HOME = Join-Path $env:BOXLANG_HOME "modules"
        $locationDesc = "Global - $($env:BOXLANG_HOME)\modules"
    }

    Show-Outdated $MODULES_HOME $locationDesc
    exit 0
}

# Handle --update command (can be used with --force and --local, in any order)
if ($args[0] -eq "--update") {
    $remainingArgs = @()
    if ($args.Count -gt 1) {
        $remainingArgs = $args[1..($args.Count-1)]
    }

    $FORCE_UPDATE = $false
    if ($remainingArgs -contains "--force") {
        $FORCE_UPDATE = $true
        $remainingArgs = $remainingArgs | Where-Object { $_ -ne "--force" }
    }

    $UPDATE_LOCAL = $false
    if ($remainingArgs -contains "--local") {
        $UPDATE_LOCAL = $true
        $remainingArgs = $remainingArgs | Where-Object { $_ -ne "--local" }
    }

    if ($remainingArgs.Count -gt 0) {
        Write-Host "❌ Error: --update command does not accept additional arguments" -ForegroundColor Red
        Write-Host "💡 Usage: install-bx-module.ps1 --update [--force] [--local]" -ForegroundColor Yellow
        exit 1
    }

    $LOCAL_INSTALL = $UPDATE_LOCAL
    if ($UPDATE_LOCAL) {
        $MODULES_HOME = Join-Path (Get-Location) "boxlang_modules"
        $locationDesc = "Local - $(Get-Location)\boxlang_modules"
    } else {
        if (-not $env:BOXLANG_HOME) {
            $env:BOXLANG_HOME = Join-Path $env:USERPROFILE ".boxlang"
        }
        $MODULES_HOME = Join-Path $env:BOXLANG_HOME "modules"
        $locationDesc = "Global - $($env:BOXLANG_HOME)\modules"
    }

    Update-Modules $MODULES_HOME $locationDesc $FORCE_UPDATE
    exit 0
}

# Handle remove command
$currentArgs = $args

# Check if --remove is the first argument
if ($args[0] -eq "--remove") {
    $REMOVE_MODE = $true
    $currentArgs = $args[1..($args.Count-1)]

    # Check for --force flag
    if ($currentArgs -contains "--force") {
        $FORCE_REMOVE = $true
        $currentArgs = $currentArgs | Where-Object { $_ -ne "--force" }
    }
}

# Detect if --local is anywhere in the arguments
if ($currentArgs -contains "--local") {
    $LOCAL_INSTALL = $true
    $currentArgs = $currentArgs | Where-Object { $_ -ne "--local" }
}

# Set module installation path
if ($LOCAL_INSTALL) {
    $MODULES_HOME = Join-Path (Get-Location) "boxlang_modules"
} else {
    if (-not $env:BOXLANG_HOME) {
        $env:BOXLANG_HOME = Join-Path $env:USERPROFILE ".boxlang"
    }
    $MODULES_HOME = Join-Path $env:BOXLANG_HOME "modules"
}

# Handle remove mode
if ($REMOVE_MODE) {
    # Check if no modules specified for removal
    if ($currentArgs.Count -eq 0) {
        Write-Host "❌ Error: No module(s) specified for removal" -ForegroundColor Red
        Write-Host "💡 Usage: install-bx-module.ps1 --remove <module-name> [<module-name> ...] [--force] [--local]" -ForegroundColor Yellow
        exit 1
    }

    # Inform about local removal if applicable
    if ($LOCAL_INSTALL) {
        Write-Host "🗑️  Removing modules from local directory: $(Get-Location)\boxlang_modules" -ForegroundColor Yellow
    } else {
        Write-Host "🗑️  Removing modules from: $MODULES_HOME" -ForegroundColor Yellow
    }

    # Parse comma/space-delimited module list
    $modules = Parse-ModuleList $currentArgs
    foreach ($module in $modules) {
        if ($module) {
            Write-Host "🚀 Starting removal of module: $module" -ForegroundColor Green
            Remove-Module $module $FORCE_REMOVE
        }
    }

    exit 0
}

# Inform about local installation
if ($LOCAL_INSTALL) {
    Write-Host "📍 Installing modules locally in $(Get-Location)\boxlang_modules" -ForegroundColor Yellow
}

# Parse comma/space-delimited module list and install
$modules = Parse-ModuleList $currentArgs
foreach ($module in $modules) {
    if ($module) {
        Write-Host "🚀 Starting installation of module: $module" -ForegroundColor Green
        Install-Module $module
    }
}
