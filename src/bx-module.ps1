# BoxLang Module Manager (bx-module)
# Description: This script installs and manages BoxLang modules from FORGEBOX using verbs:
# install, remove, list, outdated, update. The legacy install-bx-module command is a thin
# shim that translates its flags and calls this script.
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
# Nested install state: a module's box.json dependencies are installed as nested modules
# inside "<module>/modules/". NESTED_INSTALL leaves the shared manifest alone while doing so,
# and ROOT_MODULES_HOME remembers the top-level modules directory to flag duplicate installs.
$NESTED_INSTALL = $false
$ROOT_MODULES_HOME = ""

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
    Write-Host "📦 BoxLang Module Manager" -ForegroundColor Green
    Write-Host ""
    Write-Host "Install, remove, list, and update BoxLang modules from FORGEBOX." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor DarkYellow
    Write-Host "  bx-module <command> [arguments] [options]"
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor DarkYellow
    Write-Host "  install [<module>[@<version>] ...]   Install module(s), or a project box.json's dependencies when none are given"
    Write-Host "  remove <module> [<module> ...]       Remove module(s)"
    Write-Host "  list                                 Show installed module(s), including nested dependencies"
    Write-Host "  outdated                             Check installed modules against FORGEBOX and report which are outdated"
    Write-Host "  update [<module> ...]                Update outdated module(s), or only the named ones, to their latest FORGEBOX version"
    Write-Host "  help [<command>]                     Show this help, or help for one command"
    Write-Host ""
    Write-Host "Options:" -ForegroundColor DarkYellow
    Write-Host "  --local           Work with the local boxlang_modules folder instead of BoxLang HOME. The BoxLang HOME is the default."
    Write-Host "  --force           Skip the confirmation prompt (remove and update)"
    Write-Host "  --help, -h        Show help"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor DarkYellow
    Write-Host "  bx-module install bx-orm"
    Write-Host "  bx-module install bx-orm@2.5.0 bx-ai --local"
    Write-Host "  bx-module install bx-orm,bx-ai,bx-esapi"
    Write-Host "  bx-module install                        # install box.json dependencies from the current directory"
    Write-Host "  bx-module remove bx-orm --force"
    Write-Host "  bx-module list --local"
    Write-Host "  bx-module outdated"
    Write-Host "  bx-module update bx-sites"
    Write-Host "  bx-module update --force"
    Write-Host ""
    Write-Host "Notes:" -ForegroundColor DarkYellow
    Write-Host "  - If no version is specified, the latest version from FORGEBOX will be installed"
    Write-Host "  - Multiple modules can be specified, separated by spaces or commas: 'bx-orm, bx-ai bx-esapi'"
    Write-Host "  - Without --local, modules are managed in BoxLang HOME (~/.boxlang/modules)"
    Write-Host "  - Requires PowerShell to be installed"
    Write-Host "  - Dependencies declared in a module's box.json are installed automatically as nested modules inside the module's own modules/ folder (latest version for `"*`", otherwise the version specified, including `"be`" or `"snapshot`")"
    Write-Host "  - Nested dependencies are shown (indented) by list, outdated and update, and are removed together with their parent module"
    Write-Host "  - The legacy install-bx-module command still works and forwards to bx-module"
}

# Help for a single command. Returns `$false when the command is unknown.
function Show-VerbHelp {
    param([string]$Verb)

    switch ($Verb) {
        "install" {
            Write-Host "Usage:" -ForegroundColor DarkYellow
            Write-Host "  bx-module install <module>[@<version>] [<module>[@<version>] ...] [--local]"
            Write-Host "  bx-module install [--local]        (installs the dependencies of ./box.json)"
            Write-Host ""
            Write-Host "Installs module(s) from FORGEBOX. <version> may be an exact version, `"be`", or `"snapshot`"."
            Write-Host "Module dependencies are installed as nested modules inside the module's modules/ folder."
            Write-Host ""
            Write-Host "Examples:" -ForegroundColor DarkYellow
            Write-Host "  bx-module install bx-orm"
            Write-Host "  bx-module install bx-orm@2.5.0 bx-ai --local"
        }
        "remove" {
            Write-Host "Usage:" -ForegroundColor DarkYellow
            Write-Host "  bx-module remove <module> [<module> ...] [--force] [--local]"
            Write-Host ""
            Write-Host "Removes module(s), including their nested dependencies. Asks for confirmation unless --force is given."
            Write-Host ""
            Write-Host "Examples:" -ForegroundColor DarkYellow
            Write-Host "  bx-module remove bx-orm"
            Write-Host "  bx-module remove bx-orm,bx-ai --force"
        }
        "list" {
            Write-Host "Usage:" -ForegroundColor DarkYellow
            Write-Host "  bx-module list [--local]"
            Write-Host ""
            Write-Host "Shows installed module(s), with nested dependencies indented under their parent."
        }
        "outdated" {
            Write-Host "Usage:" -ForegroundColor DarkYellow
            Write-Host "  bx-module outdated [--local]"
            Write-Host ""
            Write-Host "Checks installed modules (and nested dependencies) against FORGEBOX and reports which are outdated."
        }
        "update" {
            Write-Host "Usage:" -ForegroundColor DarkYellow
            Write-Host "  bx-module update [<module> ...] [--force] [--local]"
            Write-Host ""
            Write-Host "Updates outdated module(s) to their latest FORGEBOX version. With module names, only those are updated."
            Write-Host "Asks for confirmation unless --force is given."
            Write-Host ""
            Write-Host "Examples:" -ForegroundColor DarkYellow
            Write-Host "  bx-module update"
            Write-Host "  bx-module update bx-sites --force"
        }
        default {
            Write-Host "❌ Error: Unknown command '$Verb'" -ForegroundColor Red
            Write-Host "💡 Commands: install, remove, list, outdated, update, help" -ForegroundColor Yellow
            return $false
        }
    }
    return $true
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

# Reads the version of an installed module from its own box.json ("unknown" if absent).
function Get-ModuleVersion {
    param([string]$ModuleDir)

    $boxJsonPath = Join-Path $ModuleDir "box.json"
    if (Test-Path $boxJsonPath) {
        try {
            $boxJson = Get-Content $boxJsonPath -Raw | ConvertFrom-Json
            if ($boxJson.version) { return [string]$boxJson.version }
        } catch { }
    }
    return "unknown"
}

# Prints the modules nested inside a modules/ directory, indented by depth,
# recursing into each nested module's own modules/ folder.
function Write-NestedModules {
    param([string]$NestedDir, [int]$Depth = 1)

    if (-not (Test-Path $NestedDir)) { return }

    $indent = "  " * $Depth
    foreach ($dir in (Get-ChildItem -Path $NestedDir -Directory -ErrorAction SilentlyContinue)) {
        Write-Host "$indent↳ $($dir.Name) ($(Get-ModuleVersion $dir.FullName))" -ForegroundColor Green
        Write-NestedModules (Join-Path $dir.FullName "modules") ($Depth + 1)
    }
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
            Write-NestedModules (Join-Path (Join-Path $ModulesPath $prop.Name) "modules") 1
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

# Builds one outdated-report entry for a single installed module, or $null when its
# current version isn't a parseable semver. Status is one of: uptodate, ahead, outdated, unreachable.
function New-OutdatedEntry {
    param([string]$ModuleName, [string]$CurrentVersion, [string]$ModulesDir, [int]$Depth)

    $currentSemver = Get-SemanticVersion $CurrentVersion
    if (-not $currentSemver) { return $null }

    $latestVersion = Get-ForgeboxLatestVersion $ModuleName
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

    return [PSCustomObject]@{
        Name = $ModuleName
        Current = $CurrentVersion
        Latest = $latestVersion
        Status = $status
        ModulesDir = $ModulesDir
        Depth = $Depth
    }
}

# Returns report entries for every module nested inside a modules/ directory, recursively.
function Get-NestedOutdatedReport {
    param([string]$NestedDir, [int]$Depth = 1)

    $report = @()
    if (-not (Test-Path $NestedDir)) { return $report }

    foreach ($dir in (Get-ChildItem -Path $NestedDir -Directory -ErrorAction SilentlyContinue)) {
        $entry = New-OutdatedEntry $dir.Name (Get-ModuleVersion $dir.FullName) $NestedDir $Depth
        if ($entry) { $report += $entry }
        $report += @(Get-NestedOutdatedReport (Join-Path $dir.FullName "modules") ($Depth + 1))
    }
    return $report
}

# Returns an array of [PSCustomObject]@{ Name; Current; Latest; Status; ModulesDir; Depth } for every
# dependency in the manifest, each followed by the modules nested inside it (Depth > 0).
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
        $entry = New-OutdatedEntry $prop.Name $prop.Value $ModulesPath 0
        if ($entry) { $report += $entry }
        $report += @(Get-NestedOutdatedReport (Join-Path (Join-Path $ModulesPath $prop.Name) "modules") 1)
    }

    return $report
}

# Indents a module name by its nesting depth for report output.
function Get-ReportLabel {
    param([string]$Name, [int]$Depth = 0)
    return ("  " * $Depth) + $Name
}

# Installs one outdated report entry. Nested entries are reinstalled into their parent's
# modules/ folder. A parent update reinstalls its own nested dependencies, so nested entries
# that are already current (or no longer present) are skipped.
function Invoke-OutdatedUpdate {
    param([PSCustomObject]$Entry)

    if ($Entry.Depth -gt 0) {
        $moduleDir = Join-Path $Entry.ModulesDir $Entry.Name
        if (-not (Test-Path $moduleDir)) { return }
        if ((Get-ModuleVersion $moduleDir) -eq $Entry.Latest) { return }
        Install-NestedModule -NestedHome $Entry.ModulesDir -ModuleName "$($Entry.Name)@$($Entry.Latest)"
    } else {
        Install-Module "$($Entry.Name)@$($Entry.Latest)"
    }
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
        "{0,-25} {1,-15} {2,-15} {3}" -f (Get-ReportLabel $entry.Name $entry.Depth), $entry.Current, $entry.Latest, $statusLabel | Write-Host
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
            Invoke-OutdatedUpdate $entry
        }
    } else {
        Write-Host "Skipping updates." -ForegroundColor Yellow
    }
}

function Update-Modules {
    param(
        [string]$ModulesPath,
        [string]$LocationDesc,
        [bool]$ForceUpdate = $false,
        [string[]]$Filter = @()
    )

    Write-Host "🔎 Checking for outdated BoxLang Modules ($LocationDesc):" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Test-Path $ModulesPath)) {
        Write-Host "📂 No modules directory found at $ModulesPath" -ForegroundColor Yellow
        return
    }

    $report = Get-OutdatedReport $ModulesPath

    # When module names were given, only update those (at any nesting depth)
    if ($Filter -and $Filter.Count -gt 0) {
        foreach ($requested in $Filter) {
            if (-not ($report | Where-Object { $_.Name -eq $requested })) {
                Write-Host "⚠️  Module '$requested' was not found among the installed modules (or has no parseable version)" -ForegroundColor Yellow
            }
        }
        $report = @($report | Where-Object { $Filter -contains $_.Name })
    }

    $outdated = $report | Where-Object { $_.Status -eq "outdated" }

    foreach ($entry in $outdated) {
        Write-Host "🆙 $(Get-ReportLabel $entry.Name $entry.Depth): $($entry.Current) → $($entry.Latest)"
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
        Invoke-OutdatedUpdate $entry
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

# Runs Install-Module with MODULES_HOME pointed at a parent module's modules/ folder,
# restoring the previous install state afterwards.
function Install-NestedModule {
    param(
        [string]$NestedHome,
        [string]$ModuleName,
        [string[]]$Visited = @()
    )

    $previousHome = $script:MODULES_HOME
    $previousNested = $script:NESTED_INSTALL
    $previousRoot = $script:ROOT_MODULES_HOME
    try {
        if (-not $script:ROOT_MODULES_HOME) { $script:ROOT_MODULES_HOME = $script:MODULES_HOME }
        $script:MODULES_HOME = $NestedHome
        $script:NESTED_INSTALL = $true
        Install-Module -moduleName $ModuleName -Visited $Visited
    } finally {
        $script:MODULES_HOME = $previousHome
        $script:NESTED_INSTALL = $previousNested
        $script:ROOT_MODULES_HOME = $previousRoot
    }
}

# Warns when a module about to be nested is already installed somewhere else
# under the top-level modules directory (top level or inside another module).
function Write-DuplicateModuleWarning {
    param([string]$DepName, [string]$Destination)

    $root = if ($script:ROOT_MODULES_HOME) { $script:ROOT_MODULES_HOME } else { $script:MODULES_HOME }
    if (-not $root -or -not (Test-Path $root)) { return }

    $destinationFull = [System.IO.Path]::GetFullPath($Destination)
    $found = Get-ChildItem -Path $root -Directory -Recurse -Filter $DepName -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq $DepName -and $_.FullName -ine $destinationFull -and (Test-Path (Join-Path $_.FullName "box.json")) }
    foreach ($dir in $found) {
        Write-Host "⚠️  Dependency '$DepName' is also installed at $($dir.FullName), installing another copy at $destinationFull" -ForegroundColor Yellow
    }
}

# Installs the dependencies declared in a box.json. When NestedHome is given, they are
# installed as nested modules inside that folder (a module's own "modules" directory);
# otherwise they go to the current MODULES_HOME (used for a project box.json).
function Install-ModuleDependencies {
    param(
        [PSCustomObject]$BoxJson,
        [string[]]$Visited,
        [string]$NestedHome = ""
    )

    if (-not $BoxJson -or -not $BoxJson.dependencies) { return }

    $depNames = $BoxJson.dependencies.PSObject.Properties.Name
    if (-not $depNames -or $depNames.Count -eq 0) { return }

    $depNoun = if ($depNames.Count -eq 1) { "dependency" } else { "dependencies" }
    Write-Host "🔗 Found $($depNames.Count) module $depNoun, installing..." -ForegroundColor Blue

    foreach ($depName in $depNames) {
        if ($Visited -contains $depName) {
            Write-Host "⚠️  Skipping circular dependency: $depName" -ForegroundColor Yellow
            continue
        }

        $depVersion = $BoxJson.dependencies.$depName
        $depInput = if (-not $depVersion -or $depVersion -eq "*" -or $depVersion -eq "null") {
            $depName
        } else {
            "$depName@$depVersion"
        }

        Write-Host "📦 Installing dependency: $depInput" -ForegroundColor Green
        if ($NestedHome) {
            $depSlug = $depName.ToLower()
            Write-DuplicateModuleWarning $depSlug (Join-Path $NestedHome $depSlug)
            Install-NestedModule -NestedHome $NestedHome -ModuleName $depInput -Visited $Visited
        } else {
            Install-Module -moduleName $depInput -Visited $Visited
        }
    }
}

function Install-Module {
    param(
        [string]$moduleName,
        [string[]]$Visited = @()
    )

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
        Write-Host "💡 Usage: bx-module install <module-name>[@<version>] [--local]" -ForegroundColor Yellow
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
            $versionJson = Invoke-RestMethod -Uri "$FORGEBOX_API_URL/entry/$targetModule/versions/$targetVersion" -ErrorAction Stop
            if ($versionJson -and $versionJson.data -and $versionJson.data.downloadURL) {
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

                # Install any module dependencies declared in box.json as nested modules
                # inside this module's own modules/ folder
                Install-ModuleDependencies -BoxJson $boxJson -Visited ($Visited + $targetModule) -NestedHome (Join-Path $destination "modules")
            } catch {
                # Silently ignore box.json parsing errors
            }
        }

        # Track this install in the modules manifest. Nested dependencies are tracked by
        # their parent module's own box.json, so they never touch the shared manifest.
        if (-not $NESTED_INSTALL) {
            Set-BoxJsonDependency (Join-Path $MODULES_HOME "box.json") $targetModule $targetVersion
        }

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

# Parses the options and positional arguments that follow a command.
function Read-VerbArgs {
    param([string[]]$VerbArgs)

    $parsed = @{ Local = $false; Force = $false; Positionals = @(); Unknown = @() }
    foreach ($arg in $VerbArgs) {
        if ($arg -eq "--local") { $parsed.Local = $true }
        elseif ($arg -eq "--force") { $parsed.Force = $true }
        elseif ($arg.StartsWith("-")) { $parsed.Unknown += $arg }
        else { $parsed.Positionals += $arg }
    }
    return $parsed
}

# Sets MODULES_HOME and LOCAL_INSTALL, and returns the location description.
function Set-ModulesHome {
    param([bool]$Local)

    $script:LOCAL_INSTALL = $Local
    if ($Local) {
        $script:MODULES_HOME = Join-Path (Get-Location) "boxlang_modules"
        return "Local - $(Get-Location)\boxlang_modules"
    }

    if (-not $env:BOXLANG_HOME) {
        $env:BOXLANG_HOME = Join-Path $env:USERPROFILE ".boxlang"
    }
    $script:MODULES_HOME = Join-Path $env:BOXLANG_HOME "modules"
    return "Global - $($env:BOXLANG_HOME)\modules"
}

# Main execution starts here

$verb = ""
$verbArgs = @()
if ($args.Count -gt 0) { $verb = [string]$args[0] }
if ($args.Count -gt 1) { $verbArgs = @($args[1..($args.Count - 1)]) }

if ($verb -eq "") {
    Show-Help
    exit 0
}

if ($verb -in @("help", "--help", "-h")) {
    if ($verbArgs.Count -gt 0) {
        if (-not (Show-VerbHelp $verbArgs[0])) { exit 1 }
    } else {
        Show-Help
    }
    exit 0
}

if ($verb -notin @("install", "remove", "list", "outdated", "update")) {
    Write-Host "❌ Error: Unknown command '$verb'" -ForegroundColor Red
    if ($verb -in @("--list", "--outdated", "--update", "--remove")) {
        Write-Host "💡 Did you mean: bx-module $($verb.Substring(2))?" -ForegroundColor Yellow
    } elseif (-not $verb.StartsWith("-")) {
        Write-Host "💡 Did you mean: bx-module install ${verb}?" -ForegroundColor Yellow
    }
    Write-Host "💡 Commands: install, remove, list, outdated, update, help (run 'bx-module help' for details)" -ForegroundColor Yellow
    exit 1
}

if (($verbArgs -contains "--help") -or ($verbArgs -contains "-h")) {
    Show-VerbHelp $verb | Out-Null
    exit 0
}

$parsed = Read-VerbArgs $verbArgs
$unknownText = ($parsed.Unknown -join " ")

switch ($verb) {
    "list" {
        if ($parsed.Force) { $parsed.Unknown += "--force" }
        if ($parsed.Unknown.Count -gt 0 -or $parsed.Positionals.Count -gt 0) {
            Write-Host "❌ Error: 'list' does not accept additional arguments: $(($parsed.Unknown + $parsed.Positionals) -join ' ')" -ForegroundColor Red
            Write-Host "💡 Usage: bx-module list [--local]" -ForegroundColor Yellow
            exit 1
        }
        $locationDesc = Set-ModulesHome $parsed.Local
        List-Modules $MODULES_HOME $locationDesc
        exit 0
    }

    "outdated" {
        if ($parsed.Force) { $parsed.Unknown += "--force" }
        if ($parsed.Unknown.Count -gt 0 -or $parsed.Positionals.Count -gt 0) {
            Write-Host "❌ Error: 'outdated' does not accept additional arguments: $(($parsed.Unknown + $parsed.Positionals) -join ' ')" -ForegroundColor Red
            Write-Host "💡 Usage: bx-module outdated [--local]" -ForegroundColor Yellow
            exit 1
        }
        $locationDesc = Set-ModulesHome $parsed.Local
        Show-Outdated $MODULES_HOME $locationDesc
        exit 0
    }

    "update" {
        if ($parsed.Unknown.Count -gt 0) {
            Write-Host "❌ Error: Unknown option(s) for 'update': $unknownText" -ForegroundColor Red
            Write-Host "💡 Usage: bx-module update [<module-name> ...] [--force] [--local]" -ForegroundColor Yellow
            exit 1
        }
        $locationDesc = Set-ModulesHome $parsed.Local

        # Module names to limit the update to (lowercased)
        $filter = @(Parse-ModuleList $parsed.Positionals | ForEach-Object { $_.ToLower() })

        Update-Modules $MODULES_HOME $locationDesc $parsed.Force $filter
        exit 0
    }

    "remove" {
        if ($parsed.Unknown.Count -gt 0) {
            Write-Host "❌ Error: Unknown option(s) for 'remove': $unknownText" -ForegroundColor Red
            Write-Host "💡 Usage: bx-module remove <module-name> [<module-name> ...] [--force] [--local]" -ForegroundColor Yellow
            exit 1
        }
        $null = Set-ModulesHome $parsed.Local

        $modules = @(Parse-ModuleList $parsed.Positionals)

        # Check if no modules specified for removal
        if ($modules.Count -eq 0) {
            Write-Host "❌ Error: No module(s) specified for removal" -ForegroundColor Red
            Write-Host "💡 Usage: bx-module remove <module-name> [<module-name> ...] [--force] [--local]" -ForegroundColor Yellow
            exit 1
        }

        # Inform about local removal if applicable
        if ($LOCAL_INSTALL) {
            Write-Host "🗑️  Removing modules from local directory: $(Get-Location)\boxlang_modules" -ForegroundColor Yellow
        } else {
            Write-Host "🗑️  Removing modules from: $MODULES_HOME" -ForegroundColor Yellow
        }

        foreach ($module in $modules) {
            if ($module) {
                Write-Host "🚀 Starting removal of module: $module" -ForegroundColor Green
                Remove-Module $module $parsed.Force
            }
        }
        exit 0
    }

    "install" {
        $null = Set-ModulesHome $parsed.Local

        # --force has no effect on install (modules are always overwritten) and is
        # accepted so existing scripts keep working; other unknown options are
        # ignored with a warning for the same reason.
        $ignored = @($parsed.Unknown)
        if ($ignored.Count -gt 0) {
            Write-Host "⚠️  Ignoring unknown option(s): $($ignored -join ' ')" -ForegroundColor Yellow
        }

        # No module names were given (either no modules at all, or only --local).
        # If a box.json exists in the current directory, treat it as a project
        # manifest and install the dependencies it declares (similar to running
        # `npm install` with no arguments), honoring --local/BoxLang HOME just like
        # a normal install would.
        $modules = @(Parse-ModuleList $parsed.Positionals)
        if ($modules.Count -eq 0) {
            $projectBoxJsonPath = Join-Path (Get-Location) "box.json"
            if (Test-Path $projectBoxJsonPath) {
                Write-Host "📄 Found box.json in $(Get-Location), installing its declared dependencies..." -ForegroundColor Yellow
                try {
                    $projectBoxJson = Get-Content $projectBoxJsonPath -Raw | ConvertFrom-Json
                    Install-ModuleDependencies -BoxJson $projectBoxJson -Visited @()
                } catch {
                    Write-Host "❌ Error: Failed to parse box.json: $($_.Exception.Message)" -ForegroundColor Red
                    exit 1
                }
                exit 0
            }

            Write-Host "❌ Error: No module(s) specified" -ForegroundColor Red
            Write-Host "💡 Usage: bx-module install <module-name>[@<version>] [<module-name> ...] [--local]" -ForegroundColor Yellow
            Show-Help
            exit 1
        }

        # Inform about local installation
        if ($LOCAL_INSTALL) {
            Write-Host "📍 Installing modules locally in $(Get-Location)\boxlang_modules" -ForegroundColor Yellow
        }

        # Install the parsed comma/space-delimited module list
        foreach ($module in $modules) {
            if ($module) {
                Write-Host "🚀 Starting installation of module: $module" -ForegroundColor Green
                Install-Module $module
            }
        }
        exit 0
    }
}
