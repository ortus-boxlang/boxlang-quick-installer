# BoxLang Version Manager (BVM) for Windows
# A version manager for BoxLang similar to jenv or nvm
# Author: BoxLang Team
# Version: @build.version@
# License: Apache License, Version 2.0

# Ensure console supports UTF-8 for emojis
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Set the progress preference to silently continue to avoid cluttering the console
$ProgressPreference = 'SilentlyContinue'

###########################################################################
# Global Variables
###########################################################################

$BVM_VERSION     = "@build.version@"
$BVM_HOME        = if ($env:BVM_HOME) { $env:BVM_HOME } else { Join-Path $env:USERPROFILE ".bvm" }
$BVM_CACHE_DIR   = Join-Path $BVM_HOME "cache"
$BVM_VERSIONS_DIR = Join-Path $BVM_HOME "versions"
$BVM_SCRIPTS_DIR = Join-Path $BVM_HOME "scripts"
$BVM_CURRENT_LINK = Join-Path $BVM_HOME "current"
$BVM_CONFIG_FILE = Join-Path $BVM_HOME "config"

# URLs for BoxLang downloads
$DOWNLOAD_BASE_URL      = "https://downloads.ortussolutions.com/ortussolutions/boxlang"
$MINISERVER_BASE_URL    = "https://downloads.ortussolutions.com/ortussolutions/boxlang-runtimes/boxlang-miniserver"
$INSTALLER_BASE_URL     = "https://downloads.ortussolutions.com/ortussolutions/boxlang-quick-installer"
$LATEST_URL             = "$DOWNLOAD_BASE_URL/boxlang-latest.zip"
$LATEST_VERSION_URL     = "$DOWNLOAD_BASE_URL/version-latest.properties"
$SNAPSHOT_URL           = "$DOWNLOAD_BASE_URL/boxlang-snapshot.zip"
$SNAPSHOT_VERSION_URL   = "$DOWNLOAD_BASE_URL/version-snapshot.properties"
$LATEST_MINISERVER_URL  = "$MINISERVER_BASE_URL/boxlang-miniserver-latest.zip"
$SNAPSHOT_MINISERVER_URL = "$MINISERVER_BASE_URL/boxlang-miniserver-snapshot.zip"
$INSTALLER_URL          = "$INSTALLER_BASE_URL/boxlang-installer.zip"
$VERSION_CHECK_URL      = "$INSTALLER_BASE_URL/version.json"
$BVM_SCRIPT_URL         = "$INSTALLER_BASE_URL/bvm.ps1"

###########################################################################
# Utility Functions
###########################################################################

function Write-BvmInfo    { param([string]$Message) Write-Host -ForegroundColor Blue   "ℹ️  $Message" }
function Write-BvmSuccess { param([string]$Message) Write-Host -ForegroundColor Green  "✅ $Message" }
function Write-BvmWarning { param([string]$Message) Write-Host -ForegroundColor Yellow "⚠️  $Message" }
function Write-BvmError   { param([string]$Message) Write-Host -ForegroundColor Red    "❌ $Message" }
function Write-BvmHeader  { param([string]$Message) Write-Host -ForegroundColor Cyan   $Message }

function Ensure-BvmDirs {
    foreach ($d in @($BVM_HOME, $BVM_CACHE_DIR, $BVM_VERSIONS_DIR, $BVM_SCRIPTS_DIR)) {
        if (-not (Test-Path $d)) {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
        }
    }
}

# Read a semantic version (x.y.z) from a string
function Get-SemanticVersion {
    param([string]$Text)
    if ($Text -match '(\d+\.\d+\.\d+)') { return $matches[1] }
    return $null
}

# Compare two "x.y.z" version strings.
# Returns: 1 if v1 > v2, -1 if v1 < v2, 0 if equal
function Compare-SemanticVersions {
    param([string]$Version1, [string]$Version2)

    $v1 = $Version1.Split('.')
    $v2 = $Version2.Split('.')

    for ($i = 0; $i -lt 3; $i++) {
        $a = if ($i -lt $v1.Length) { [int]$v1[$i] } else { 0 }
        $b = if ($i -lt $v2.Length) { [int]$v2[$i] } else { 0 }
        if ($a -gt $b) { return  1 }
        if ($a -lt $b) { return -1 }
    }
    return 0
}

# Resolve "latest"/"snapshot" aliases to the installed version directory name
function Resolve-VersionAlias {
    param([string]$Version)

    switch ($Version.ToLower()) {
        "latest" {
            $alias = Join-Path $BVM_VERSIONS_DIR "latest"
            if (Test-Path $alias) {
                # Resolve the symlink/junction target
                $target = (Get-Item $alias).Target
                if ($target) { return (Split-Path $target -Leaf) }
            }
            return "latest"
        }
        "snapshot" {
            $alias = Join-Path $BVM_VERSIONS_DIR "snapshot"
            if (Test-Path $alias) {
                $target = (Get-Item $alias).Target
                if ($target) { return (Split-Path $target -Leaf) }
            }
            return "snapshot"
        }
        default { return $Version }
    }
}

# Fetch the actual version number from a remote .properties file
function Fetch-RemoteVersion {
    param([string]$VersionType)  # "latest" or "snapshot"

    $url = if ($VersionType -eq "snapshot") { $SNAPSHOT_VERSION_URL } else { $LATEST_VERSION_URL }
    $tmp = [System.IO.Path]::GetTempFileName()

    try {
        Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop

        $lines = Get-Content $tmp
        foreach ($line in $lines) {
            if ($line -match '^version=(.+)$') {
                $raw = $matches[1].Trim()
                $ver = Get-SemanticVersion -Text $raw
                if ($ver) {
                    if ($VersionType -eq "snapshot" -and $raw -match 'snapshot') {
                        return "$ver-snapshot"
                    }
                    return $ver
                }
            }
        }
    }
    catch {
        Write-BvmWarning "Failed to fetch $VersionType version info from $url"
    }
    finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }

    return $null
}

# Read the .bvmrc version from the current or parent directories
function Read-BvmrcVersion {
    $dir = $PWD.Path

    while ($dir -ne (Split-Path $dir -Qualifier) + "\") {
        $bvmrc = Join-Path $dir ".bvmrc"
        if (Test-Path $bvmrc) {
            $version = (Get-Content $bvmrc | Where-Object { $_ -notmatch '^\s*#' -and $_ -match '\S' } | Select-Object -First 1).Trim()
            if ($version) { return $version }
        }
        $parent = Split-Path $dir -Parent
        if ($parent -eq $dir) { break }
        $dir = $parent
    }

    return $null
}

# Write a .bvmrc version in the current directory
function Write-BvmrcVersion {
    param([string]$Version)

    if (-not $Version) {
        # Show current .bvmrc if no version specified
        $existing = Read-BvmrcVersion
        if ($existing) {
            Write-BvmSuccess "Current .bvmrc version: $existing"
        } else {
            Write-BvmWarning "No .bvmrc found in current or parent directories"
            Write-BvmInfo "Create one with: bvm local <version>"
            Write-BvmInfo "Example: bvm local 1.2.0"
        }
        return
    }

    $resolved = Resolve-VersionAlias -Version $Version
    $versionDir = Join-Path $BVM_VERSIONS_DIR $resolved
    if (-not (Test-Path $versionDir)) {
        Write-BvmWarning "BoxLang [$Version] is not currently installed"
        Write-BvmInfo "You can still create .bvmrc, but install it later with: bvm install $Version"
    }

    Set-Content -Path ".bvmrc" -Value $Version -Encoding UTF8
    Write-BvmSuccess "Created .bvmrc with version: $Version"
    Write-BvmInfo "Use 'bvm use' (without version) to activate this version"
}

###########################################################################
# Network Connectivity Check
###########################################################################
function Test-NetworkConnectivity {
    try {
        $null = Invoke-WebRequest -Uri $DOWNLOAD_BASE_URL -UseBasicParsing -TimeoutSec 10 -Method Head -ErrorAction Stop
        return $true
    }
    catch {
        Write-BvmWarning "Network connectivity issues detected - downloads may fail"
        return $false
    }
}

###########################################################################
# SHA-256 Verification
###########################################################################
function Verify-DownloadChecksum {
    param(
        [string]$FilePath,
        [string]$BaseUrl,
        [long]$MinSize = 1000
    )

    if (-not (Test-Path $FilePath)) {
        Write-BvmError "File not found: $FilePath"
        return $false
    }

    # Basic size check
    $fileSize = (Get-Item $FilePath).Length
    if ($fileSize -lt $MinSize) {
        Write-BvmError "Downloaded file is too small ($fileSize bytes, expected at least $MinSize bytes)"
        return $false
    }

    # Basic ZIP validation
    if ($FilePath -like "*.zip") {
        try {
            $zip = [System.IO.Compression.ZipFile]::OpenRead($FilePath)
            $zip.Dispose()
        }
        catch {
            Write-BvmError "Downloaded file is not a valid ZIP archive"
            return $false
        }
    }

    # Attempt SHA-256 checksum verification
    $filename = Split-Path $FilePath -Leaf
    $checksumUrl = "$BaseUrl/$filename.sha-256"
    $checksumFile = "$FilePath.sha-256"

    Write-BvmInfo "🔒 Attempting SHA-256 checksum verification..."

    try {
        Invoke-WebRequest -Uri $checksumUrl -OutFile $checksumFile -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop

        $expectedChecksum = (Get-Content $checksumFile).Trim().ToLower() -replace '\s+.*$', ''
        $actualChecksum   = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.ToLower()

        if ($actualChecksum -eq $expectedChecksum) {
            Write-BvmSuccess "SHA-256 checksum verified"
        } else {
            Write-BvmError "SHA-256 checksum mismatch!"
            Write-BvmError "  Expected: $expectedChecksum"
            Write-BvmError "  Actual:   $actualChecksum"
            Remove-Item $checksumFile -Force -ErrorAction SilentlyContinue
            return $false
        }
        Remove-Item $checksumFile -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-BvmWarning "SHA-256 checksum file not available (OK for versions before 1.3.0)"
        Write-BvmInfo "SHA-256 checksums were introduced in BoxLang 1.3.0. Earlier versions do not have checksums."
    }

    return $true
}

###########################################################################
# Get current active version name
###########################################################################
function Get-CurrentVersion {
    if (Test-Path $BVM_CURRENT_LINK) {
        $target = (Get-Item $BVM_CURRENT_LINK).Target
        if ($target) { return Split-Path $target -Leaf }
    }
    # Fall back to config file
    if (Test-Path $BVM_CONFIG_FILE) {
        $lines = Get-Content $BVM_CONFIG_FILE
        foreach ($line in $lines) {
            if ($line -match '^CURRENT_VERSION=(.+)$') { return $matches[1].Trim() }
        }
    }
    return $null
}

###########################################################################
# List installed versions
###########################################################################
function List-InstalledVersions {
    Ensure-BvmDirs

    Write-Host -ForegroundColor White "Installed BoxLang versions:"
    Write-Host ""

    $entries = Get-ChildItem -Path $BVM_VERSIONS_DIR -ErrorAction SilentlyContinue
    if (-not $entries) {
        Write-BvmWarning "No BoxLang versions installed"
        Write-BvmInfo "Install a version with: bvm install latest"
        return
    }

    $currentVersion = Get-CurrentVersion

    foreach ($entry in $entries) {
        $name = $entry.Name
        $isAlias = $entry.LinkType -ne $null
        $isCurrent = ($name -eq $currentVersion)

        if ($isAlias) {
            $aliasTarget = Split-Path $entry.Target -Leaf
            $marker = if ($isCurrent) { "* " } else { "  " }
            Write-Host -ForegroundColor $(if ($isCurrent) { "Green" } else { "Gray" }) "  $marker$name => $aliasTarget"
        } else {
            $marker = if ($isCurrent) { "* " } else { "  " }
            Write-Host -ForegroundColor $(if ($isCurrent) { "Green" } else { "White" }) "  $marker$name$(if ($isCurrent) { ' (current)' })"
        }
    }

    Write-Host ""
}

###########################################################################
# List remote available versions
###########################################################################
function List-RemoteVersions {
    Write-BvmInfo "Fetching available BoxLang versions from GitHub releases..."

    $githubApi = "https://api.github.com/repos/ortus-boxlang/boxlang/releases"
    $tmp = [System.IO.Path]::GetTempFileName()

    try {
        Invoke-WebRequest -Uri $githubApi -OutFile $tmp -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
        $releases = Get-Content $tmp | ConvertFrom-Json

        Write-Host ""
        Write-Host -ForegroundColor White "Available BoxLang versions:"
        Write-Host ""
        Write-Host "  latest (always points to the newest stable release)"
        Write-Host "  snapshot (always points to the latest development build)"
        Write-Host ""

        foreach ($release in $releases) {
            $tagName = $release.tag_name -replace '^v', ''
            $prerelease = if ($release.prerelease) { " (pre-release)" } else { "" }
            Write-Host -ForegroundColor $(if ($release.prerelease) { "Yellow" } else { "White" }) "  $tagName$prerelease"
        }
    }
    catch {
        Write-BvmWarning "Could not fetch releases from GitHub API"
        Write-BvmInfo "Check available versions at: https://github.com/ortus-boxlang/boxlang/releases"
        Write-Host ""
        Write-Host "  latest"
        Write-Host "  snapshot"
        Write-Host "  1.2.0"
    }
    finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

###########################################################################
# Show current version
###########################################################################
function Show-CurrentVersion {
    $current = Get-CurrentVersion
    if ($current) {
        $versionDir = Join-Path $BVM_VERSIONS_DIR $current
        $boxlangBin = Join-Path $versionDir "bin\boxlang.bat"
        Write-Host -ForegroundColor Green "Current BoxLang version: $current"

        if (Test-Path $boxlangBin) {
            try {
                $versionOut = & $boxlangBin --version 2>$null | Out-String
                $semver = Get-SemanticVersion -Text $versionOut
                if ($semver) {
                    Write-Host -ForegroundColor Green "BoxLang runtime version: $semver"
                }
            }
            catch { }
        }
    } else {
        Write-BvmWarning "No BoxLang version is currently active"
        Write-BvmInfo "Install and use a version with: bvm install latest && bvm use latest"
    }
}

###########################################################################
# Show path to current BoxLang
###########################################################################
function Show-Which {
    if (Test-Path $BVM_CURRENT_LINK) {
        Write-Host (Join-Path $BVM_CURRENT_LINK "bin\boxlang.bat")
    } else {
        Write-BvmError "No active BoxLang version"
        exit 1
    }
}

###########################################################################
# Install a BoxLang version
###########################################################################
function Install-Version {
    param(
        [string]$Version,
        [bool]$Force = $false
    )

    if (-not $Version) {
        Write-BvmError "Please specify a version to install (e.g., bvm install latest)"
        exit 1
    }

    Ensure-BvmDirs

    $versionDir = Join-Path $BVM_VERSIONS_DIR $Version

    # Already installed?
    if ((Test-Path $versionDir) -and -not $Force) {
        Write-BvmSuccess "BoxLang [$Version] is already installed"
        Write-BvmInfo "Use 'bvm use $Version' to switch to it, or add --force to reinstall"
        return
    }

    if ((Test-Path $versionDir) -and $Force) {
        Write-BvmInfo "Removing existing installation of [$Version]..."
        Remove-Item -Path $versionDir -Recurse -Force
    }

    Write-BvmInfo "Installing BoxLang [$Version]..."

    $originalVersion = $Version
    $boxlangUrl     = ""
    $miniserverUrl  = ""

    switch ($Version.ToLower()) {
        "latest" {
            $boxlangUrl    = $LATEST_URL
            $miniserverUrl = $LATEST_MINISERVER_URL
        }
        "snapshot" {
            $boxlangUrl    = $SNAPSHOT_URL
            $miniserverUrl = $SNAPSHOT_MINISERVER_URL
        }
        default {
            $boxlangUrl    = "$DOWNLOAD_BASE_URL/$Version/boxlang-$Version.zip"
            $miniserverUrl = "$MINISERVER_BASE_URL/$Version/boxlang-miniserver-$Version.zip"
        }
    }

    $boxlangCache    = Join-Path $BVM_CACHE_DIR "boxlang-$Version.zip"
    $miniserverCache = Join-Path $BVM_CACHE_DIR "boxlang-miniserver-$Version.zip"

    # Network check
    Test-NetworkConnectivity | Out-Null

    # Create install dir
    New-Item -ItemType Directory -Path $versionDir -Force | Out-Null

    # Download BoxLang runtime
    Write-BvmInfo "⬇️  Downloading BoxLang runtime..."
    try {
        Invoke-WebRequest -Uri $boxlangUrl -OutFile $boxlangCache -UseBasicParsing -ErrorAction Stop
    }
    catch {
        Write-BvmError "Failed to download BoxLang runtime: $($_.Exception.Message)"
        Remove-Item $versionDir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    # Verify checksum
    if (-not (Verify-DownloadChecksum -FilePath $boxlangCache -BaseUrl (Split-Path $boxlangUrl -Parent) -MinSize 5000000)) {
        Write-BvmError "Checksum verification failed for BoxLang runtime"
        Remove-Item $versionDir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    # Download MiniServer
    Write-Host ""
    Write-BvmInfo "⬇️  Downloading BoxLang MiniServer..."
    try {
        Invoke-WebRequest -Uri $miniserverUrl -OutFile $miniserverCache -UseBasicParsing -ErrorAction Stop
    }
    catch {
        Write-BvmError "Failed to download BoxLang MiniServer: $($_.Exception.Message)"
        Remove-Item $versionDir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    # Verify MiniServer checksum
    if (-not (Verify-DownloadChecksum -FilePath $miniserverCache -BaseUrl (Split-Path $miniserverUrl -Parent) -MinSize 8000000)) {
        Write-BvmError "Checksum verification failed for BoxLang MiniServer"
        Remove-Item $versionDir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    # Extract BoxLang runtime
    Write-Host ""
    Write-BvmInfo "📦 Extracting BoxLang runtime..."
    try {
        Expand-Archive -Path $boxlangCache -DestinationPath $versionDir -Force -ErrorAction Stop
    }
    catch {
        Write-BvmError "Failed to extract BoxLang runtime: $($_.Exception.Message)"
        Remove-Item $versionDir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    # Extract BoxLang MiniServer
    Write-BvmInfo "📦 Extracting BoxLang MiniServer..."
    try {
        Expand-Archive -Path $miniserverCache -DestinationPath $versionDir -Force -ErrorAction Stop
    }
    catch {
        Write-BvmError "Failed to extract BoxLang MiniServer: $($_.Exception.Message)"
        Remove-Item $versionDir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    # Detect actual version for latest/snapshot
    $actualVersion = $Version
    if ($originalVersion -eq "latest" -or $originalVersion -eq "snapshot") {
        $detected = Fetch-RemoteVersion -VersionType $originalVersion
        if ($detected) {
            $actualVersion = $detected
            $actualVersionDir = Join-Path $BVM_VERSIONS_DIR $actualVersion

            # If the detected version dir already exists in versions, remove it
            if ((Test-Path $actualVersionDir) -and $Force) {
                Remove-Item $actualVersionDir -Recurse -Force -ErrorAction SilentlyContinue
            }

            # Rename the install dir to the actual version
            if (-not (Test-Path $actualVersionDir)) {
                Move-Item -Path $versionDir -Destination $actualVersionDir
                $versionDir = $actualVersionDir
            } else {
                # Just keep current place but update alias
                $versionDir = $actualVersionDir
            }

            Write-BvmInfo "Detected actual version: $actualVersion"

            # Create alias symlink: versions/latest -> versions/1.x.x or versions/snapshot -> versions/1.x.x-snapshot
            $aliasDir = Join-Path $BVM_VERSIONS_DIR $originalVersion
            if (Test-Path $aliasDir) {
                Remove-Item $aliasDir -Force -Recurse -ErrorAction SilentlyContinue
            }
            try {
                New-Item -ItemType Junction -Path $aliasDir -Target $versionDir | Out-Null
                Write-BvmInfo "Created version alias: $originalVersion => $actualVersion"
            }
            catch {
                Write-BvmWarning "Could not create version alias (may require admin privileges)"
            }
        }
    }

    # Clean up cache for specific versions
    if ($originalVersion -ne "latest" -and $originalVersion -ne "snapshot") {
        Remove-Item $boxlangCache -Force -ErrorAction SilentlyContinue
        Remove-Item $miniserverCache -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-BvmSuccess "BoxLang $actualVersion installed successfully"
    Write-BvmInfo "Use 'bvm use $originalVersion' to switch to this version"
}

###########################################################################
# Use a specific BoxLang version
###########################################################################
function Use-Version {
    param([string]$Version)

    # If no version, try .bvmrc
    if (-not $Version) {
        $Version = Read-BvmrcVersion
        if (-not $Version) {
            Write-BvmError "No version specified and no .bvmrc found"
            Write-BvmInfo "Specify a version: bvm use <version>"
            Write-BvmInfo "Or create a .bvmrc: bvm local <version>"
            exit 1
        }
        Write-BvmInfo "Using version from .bvmrc: $Version"
    }

    $resolved  = Resolve-VersionAlias -Version $Version
    $versionDir = Join-Path $BVM_VERSIONS_DIR $resolved

    if (-not (Test-Path $versionDir)) {
        Write-BvmError "BoxLang [$resolved] is not installed"
        Write-BvmInfo "Install it with: bvm install $Version"
        exit 1
    }

    # Remove existing current junction
    if (Test-Path $BVM_CURRENT_LINK) {
        Remove-Item -Path $BVM_CURRENT_LINK -Force -Recurse
    }

    # Create new junction to the version directory
    try {
        New-Item -ItemType Junction -Path $BVM_CURRENT_LINK -Target $versionDir | Out-Null
    }
    catch {
        Write-BvmError "Could not create current version junction: $($_.Exception.Message)"
        Write-BvmInfo "Try running as Administrator"
        exit 1
    }

    if ($Version -ne $resolved) {
        Write-BvmSuccess "Now using BoxLang $resolved (resolved from '$Version')"
    } else {
        Write-BvmSuccess "Now using BoxLang $Version"
    }

    # Save current version to config
    Set-Content -Path $BVM_CONFIG_FILE -Value "CURRENT_VERSION=$resolved" -Encoding UTF8

    # Ensure BoxLang home bin is in PATH
    Write-Host ""
    Ensure-BoxLangHomeBinInPath
}

###########################################################################
# Ensure ~/.boxlang/bin is in PATH (for module executables)
###########################################################################
function Ensure-BoxLangHomeBinInPath {
    $boxlangHomeBin = Join-Path $env:USERPROFILE ".boxlang\bin"

    if (-not (Test-Path $boxlangHomeBin)) {
        New-Item -ItemType Directory -Path $boxlangHomeBin -Force | Out-Null
        Write-BvmInfo "Created BoxLang home bin directory: $boxlangHomeBin"
    }

    $currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
    if ($currentPath -like "*$boxlangHomeBin*") {
        return  # Already in PATH
    }

    Write-BvmInfo "Adding $boxlangHomeBin to User PATH..."
    $newPath = if ($currentPath) { "$currentPath;$boxlangHomeBin" } else { $boxlangHomeBin }
    [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)
    Write-BvmSuccess "Added BoxLang home bin to PATH"
    Write-BvmInfo "Restart your terminal to apply PATH changes"
}

###########################################################################
# Remove a specific BoxLang version
###########################################################################
function Remove-Version {
    param([string]$Version)

    if (-not $Version) {
        Write-BvmError "Please specify a version to remove (e.g., bvm remove 1.2.0)"
        exit 1
    }

    $versionDir = Join-Path $BVM_VERSIONS_DIR $Version
    if (-not (Test-Path $versionDir)) {
        Write-BvmError "BoxLang [$Version] is not installed"
        exit 1
    }

    # Check if it's current
    $currentVersion = Get-CurrentVersion
    if ($Version -eq $currentVersion) {
        Write-BvmWarning "BoxLang [$Version] is currently active"
        Write-BvmInfo "Switch to another version first: bvm use <other-version>"
        exit 1
    }

    $response = Read-Host "Are you sure you want to remove BoxLang $Version? [y/N]"
    if ($response -notmatch '^[yY]') {
        Write-BvmInfo "Removal cancelled"
        return
    }

    Remove-Item -Path $versionDir -Recurse -Force
    Write-BvmSuccess "BoxLang $Version removed successfully"
}

###########################################################################
# Completely uninstall BVM
###########################################################################
function Uninstall-BVM {
    Write-Host -ForegroundColor Red "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host -ForegroundColor Red "⚠️  COMPLETE BVM UNINSTALL ⚠️"
    Write-Host -ForegroundColor Red "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host ""
    Write-BvmWarning "This will completely remove BVM and ALL installed BoxLang versions from your system!"
    Write-Host ""

    if (-not (Test-Path $BVM_HOME)) {
        Write-BvmWarning "BVM does not appear to be installed at [$BVM_HOME]"
        return
    }

    Write-Host "The following will be removed:"
    Write-Host "  $BVM_HOME (all BVM data, versions, and scripts)"
    Write-Host ""
    Write-Host -ForegroundColor Red "This action cannot be undone!"
    $response = Read-Host "Are you absolutely sure you want to completely uninstall BVM? [y/N]"

    if ($response -notmatch '^[yY]') {
        Write-BvmInfo "Uninstall cancelled"
        return
    }

    # Remove BVM from PATH
    Write-BvmInfo "Removing BVM from PATH..."
    $binDir = Join-Path $BVM_HOME "bin"
    $currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
    $newPath = ($currentPath -split ";" | Where-Object { $_ -notlike "*$BVM_HOME*" -and $_ -ne "" }) -join ";"
    [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)

    # Remove BVM home directory
    Write-BvmInfo "Removing BVM home directory..."
    Remove-Item -Path $BVM_HOME -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-BvmSuccess "BVM has been completely uninstalled"
    Write-BvmInfo "Your ~/.boxlang directory (BoxLang home) was preserved"
    Write-BvmInfo "Remove it manually if desired: Remove-Item -Path '$env:USERPROFILE\.boxlang' -Recurse -Force"
}

###########################################################################
# Execute BoxLang with current version
###########################################################################
function Exec-BoxLang {
    param([string[]]$Arguments)

    if (-not (Test-Path $BVM_CURRENT_LINK)) {
        Write-BvmError "No active BoxLang version"
        Write-BvmInfo "Install and use a version: bvm install latest && bvm use latest"
        exit 1
    }

    $boxlangBin = Join-Path $BVM_CURRENT_LINK "bin\boxlang.bat"
    if (-not (Test-Path $boxlangBin)) {
        Write-BvmError "BoxLang binary not found: $boxlangBin"
        exit 1
    }

    & $boxlangBin @Arguments
    exit $LASTEXITCODE
}

###########################################################################
# Execute BoxLang MiniServer with current version
###########################################################################
function Exec-MiniServer {
    param([string[]]$Arguments)

    if (-not (Test-Path $BVM_CURRENT_LINK)) {
        Write-BvmError "No active BoxLang version"
        Write-BvmInfo "Install and use a version: bvm install latest && bvm use latest"
        exit 1
    }

    $miniserverBin = Join-Path $BVM_CURRENT_LINK "bin\boxlang-miniserver.bat"
    if (-not (Test-Path $miniserverBin)) {
        Write-BvmError "BoxLang MiniServer binary not found: $miniserverBin"
        exit 1
    }

    & $miniserverBin @Arguments
    exit $LASTEXITCODE
}

###########################################################################
# Clean cache
###########################################################################
function Invoke-CleanCache {
    Write-BvmInfo "Cleaning BVM cache and temporary files..."

    if (Test-Path $BVM_CACHE_DIR) {
        $cacheFiles = Get-ChildItem -Path $BVM_CACHE_DIR -File
        $count = $cacheFiles.Count
        Remove-Item -Path (Join-Path $BVM_CACHE_DIR "*") -Recurse -Force -ErrorAction SilentlyContinue
        Write-BvmSuccess "Removed $count cached file(s)"
    } else {
        Write-BvmInfo "No cache to clean"
    }

    # Clean temp files
    Get-ChildItem -Path $env:TEMP -Filter "bvm_*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-BvmSuccess "Cleanup complete"
}

###########################################################################
# Show statistics
###########################################################################
function Show-Stats {
    Write-Host -ForegroundColor Red "─────────────────────────────────────────────────────────────────────────────"
    Write-BvmHeader "📊 BVM Performance & Usage Statistics"
    Write-Host -ForegroundColor Red "─────────────────────────────────────────────────────────────────────────────"
    Write-Host ""

    if (Test-Path $BVM_HOME) {
        $bvmSize = [math]::Round((Get-ChildItem $BVM_HOME -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
        Write-BvmInfo "BVM home directory size: ${bvmSize} MB"
    }

    if (Test-Path $BVM_VERSIONS_DIR) {
        $versions = Get-ChildItem $BVM_VERSIONS_DIR -Directory -ErrorAction SilentlyContinue
        Write-BvmInfo "Installed versions: $($versions.Count)"
        foreach ($v in $versions) {
            $vSize = [math]::Round((Get-ChildItem $v.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
            Write-Host "    $($v.Name): ${vSize} MB"
        }
    }

    if (Test-Path $BVM_CACHE_DIR) {
        $cacheFiles = Get-ChildItem $BVM_CACHE_DIR -File -ErrorAction SilentlyContinue
        $cacheSize  = [math]::Round(($cacheFiles | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
        Write-BvmInfo "Cache: ${cacheSize} MB ($($cacheFiles.Count) files)"
    }

    $current = Get-CurrentVersion
    if ($current) {
        Write-BvmInfo "Current version: $current"
        $versionDir = Join-Path $BVM_VERSIONS_DIR $current
        $boxlangBin = Join-Path $versionDir "bin\boxlang.bat"
        if (Test-Path $boxlangBin) {
            try {
                $startTime = [DateTime]::Now
                $versionOut = & $boxlangBin --version 2>$null | Out-String
                $elapsed = ([DateTime]::Now - $startTime).TotalMilliseconds
                $semver = Get-SemanticVersion -Text $versionOut
                if ($semver) { Write-BvmInfo "BoxLang runtime version: $semver" }
                Write-BvmInfo "BoxLang startup time: ${elapsed}ms"
            }
            catch { }
        }
    }

    Write-Host ""
    Write-Host -ForegroundColor Red "─────────────────────────────────────────────────────────────────────────────"
}

###########################################################################
# Doctor - health check
###########################################################################
function Invoke-Doctor {
    Write-Host -ForegroundColor Red "─────────────────────────────────────────────────────────────────────────────"
    Write-BvmHeader "❤️‍🔥 BVM Health Check ❤️‍🔥"
    Write-Host -ForegroundColor Red "─────────────────────────────────────────────────────────────────────────────"
    Write-Host ""

    $issues = 0

    # Prerequisites
    Write-BvmInfo "Checking prerequisites..."
    $missing = @()
    if ($PSVersionTable.PSVersion.Major -lt 5) { $missing += "PowerShell 5.1+" }
    if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue) -and
        -not (Get-Command curl -ErrorAction SilentlyContinue)) { $missing += "curl" }
    if (-not (Get-Command jq -ErrorAction SilentlyContinue)) { $missing += "jq (optional, used for JSON parsing)" }

    if ($missing.Count -eq 0) {
        Write-BvmSuccess "All prerequisites satisfied"
    } else {
        foreach ($m in $missing) { Write-BvmWarning "Missing: $m" }
    }

    # Java check
    $javaOk = $false
    try {
        $v = & java -version 2>&1 | Out-String
        if ($v -match '(\d+)\.') {
            $major = [int]$matches[1]
        } elseif ($v -match '1\.(\d+)\.') {
            $major = [int]$matches[1]
        }
        if ($major -ge 21) {
            Write-BvmSuccess "Java $major is available"
            $javaOk = $true
        } else {
            Write-BvmWarning "Java $major found but Java 21+ is required"
            $issues++
        }
    }
    catch {
        Write-BvmWarning "Java not found - required to run BoxLang"
        $issues++
    }

    # BVM home
    if (Test-Path $BVM_HOME) {
        Write-BvmSuccess "BVM home directory exists: $BVM_HOME"
    } else {
        Write-BvmError "BVM home directory missing: $BVM_HOME"
        $issues++
    }

    # Versions directory
    if (Test-Path $BVM_VERSIONS_DIR) {
        $vCount = (Get-ChildItem $BVM_VERSIONS_DIR -Directory -ErrorAction SilentlyContinue).Count
        Write-BvmSuccess "Versions directory exists ($vCount version(s) installed)"
    } else {
        Write-BvmWarning "Versions directory missing: $BVM_VERSIONS_DIR"
        New-Item -ItemType Directory -Path $BVM_VERSIONS_DIR -Force | Out-Null
        Write-BvmInfo "Created versions directory"
    }

    # Cache directory
    if (Test-Path $BVM_CACHE_DIR) {
        Write-BvmSuccess "Cache directory exists: $BVM_CACHE_DIR"
    } else {
        Write-BvmWarning "Cache directory missing: $BVM_CACHE_DIR"
        New-Item -ItemType Directory -Path $BVM_CACHE_DIR -Force | Out-Null
        Write-BvmInfo "Created cache directory"
    }

    # Current link
    if (Test-Path $BVM_CURRENT_LINK) {
        $target  = (Get-Item $BVM_CURRENT_LINK).Target
        $curName = Split-Path $target -Leaf
        Write-BvmSuccess "Active version: $curName"

        $boxlangBin = Join-Path $BVM_CURRENT_LINK "bin\boxlang.bat"
        if (Test-Path $boxlangBin) {
            Write-BvmSuccess "BoxLang binary found: $boxlangBin"
        } else {
            Write-BvmError "BoxLang binary missing at: $boxlangBin"
            $issues++
        }

        $miniserverBin = Join-Path $BVM_CURRENT_LINK "bin\boxlang-miniserver.bat"
        if (Test-Path $miniserverBin) {
            Write-BvmSuccess "BoxLang MiniServer binary found"
        } else {
            Write-BvmWarning "BoxLang MiniServer binary missing"
        }
    } else {
        Write-BvmWarning "No active BoxLang version set"
        Write-BvmInfo "Use 'bvm use <version>' to activate one"
    }

    # BVM bin in PATH
    $binDir = Join-Path $BVM_HOME "bin"
    $userPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
    if ($userPath -like "*$binDir*") {
        Write-BvmSuccess "BVM bin is in User PATH"
    } else {
        Write-BvmWarning "BVM bin ($binDir) is not in User PATH"
        $issues++
        Write-BvmInfo "Add it manually or run: bvm doctor --fix"
    }

    # BoxLang home bin in PATH
    Ensure-BoxLangHomeBinInPath

    # Helper scripts
    Write-BvmInfo "Checking BVM helper scripts..."
    $expectedScripts = @("bvm.ps1", "install-bx-module.ps1", "install-bvm.ps1", "helpers\helpers.sh")
    $missingScripts = @()
    foreach ($script in $expectedScripts) {
        if (-not (Test-Path (Join-Path $BVM_SCRIPTS_DIR $script))) {
            $missingScripts += $script
        }
    }
    if ($missingScripts.Count -eq 0) {
        Write-BvmSuccess "All BVM helper scripts are present"
    } else {
        foreach ($s in $missingScripts) { Write-BvmWarning "Missing script: $s" }
        Write-BvmInfo "Reinstall BVM to get the latest helper scripts"
    }

    Write-Host ""
    Write-Host -ForegroundColor Red "─────────────────────────────────────────────────────────────────────────────"
    if ($issues -eq 0) {
        Write-BvmSuccess "❤️‍🔥 BVM installation is healthy!"
    } else {
        Write-BvmWarning "Found [$issues] issue(s) - some functionality may be limited"
    }
    Write-Host -ForegroundColor Red "─────────────────────────────────────────────────────────────────────────────"
}

###########################################################################
# Check for BVM Updates
###########################################################################
function Check-BvmUpdates {
    Write-Host -ForegroundColor Red "─────────────────────────────────────────────────────────────────────────────"
    Write-BvmHeader "🔄 BVM Update Checker"
    Write-Host -ForegroundColor Red "─────────────────────────────────────────────────────────────────────────────"
    Write-Host ""

    Write-BvmInfo "🔍 Checking for BVM updates..."

    # Read current version
    $currentVersion = ""
    $versionFile = Join-Path $BVM_SCRIPTS_DIR "version.json"
    if (Test-Path $versionFile) {
        try {
            $json = Get-Content $versionFile | ConvertFrom-Json
            $currentVersion = $json.INSTALLER_VERSION
        }
        catch { }
    }

    # Fetch latest version from remote
    $latestVersion = ""
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        Invoke-WebRequest -Uri $VERSION_CHECK_URL -OutFile $tmp -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
        $json = Get-Content $tmp | ConvertFrom-Json
        $latestVersion = $json.INSTALLER_VERSION
    }
    catch {
        Write-BvmError "Failed to fetch latest version information"
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        return
    }
    finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }

    Write-Host -ForegroundColor Green "Current BVM version: $currentVersion"
    Write-Host -ForegroundColor Green "Latest BVM version:  $latestVersion"
    Write-Host ""

    if ($currentVersion -and $latestVersion) {
        $cmp = Compare-SemanticVersions -Version1 $latestVersion -Version2 $currentVersion
        switch ($cmp) {
            0  { Write-BvmSuccess "You have the latest version of BVM" }
            -1 { Write-BvmInfo "You have a newer version than the latest release (development build?)" }
            1  {
                Write-BvmWarning "A newer version of BVM is available!"
                $response = Read-Host "Would you like to update BVM now? [Y/n]"
                if ($response -notmatch '^[nN]') {
                    Write-BvmInfo "Updating BVM..."
                    $installScript = Join-Path $BVM_SCRIPTS_DIR "install-bvm.ps1"
                    if (Test-Path $installScript) {
                        & $installScript --force
                    } else {
                        Write-BvmInfo "Run the following to update BVM:"
                        Write-Host -ForegroundColor Green "  iwr -useb https://install-bvm.boxlang.io | iex"
                    }
                } else {
                    Write-BvmInfo "Update cancelled"
                }
            }
        }
    }

    Write-Host ""
    Write-Host -ForegroundColor Red "─────────────────────────────────────────────────────────────────────────────"
}

###########################################################################
# Help
###########################################################################
function Show-Help {
    Write-Host -ForegroundColor Green "📦 BoxLang Version Manager (BVM) v$BVM_VERSION"
    Write-Host ""
    Write-Host -ForegroundColor Yellow "This script manages BoxLang versions and installations."
    Write-Host ""
    Write-Host -ForegroundColor White "USAGE:"
    Write-Host "  bvm <command> [arguments]"
    Write-Host ""
    Write-Host -ForegroundColor White "COMMANDS:"
    $cmds = @(
        @{ name = "install <version>";    desc = "Install a specific BoxLang version (latest, snapshot, 1.2.0)" },
        @{ name = "use <version>";         desc = "Switch to a specific BoxLang version (reads .bvmrc if no version)" },
        @{ name = "local <version>";       desc = "Set local BoxLang version for current directory (.bvmrc)" },
        @{ name = "current";               desc = "Show currently active BoxLang version" },
        @{ name = "list";                  desc = "List all installed BoxLang versions" },
        @{ name = "list-remote";           desc = "List available BoxLang versions for download" },
        @{ name = "remove <version>";      desc = "Remove a specific BoxLang version" },
        @{ name = "uninstall";             desc = "Completely uninstall BVM and all BoxLang versions" },
        @{ name = "which";                 desc = "Show path to current BoxLang installation" },
        @{ name = "exec <args>";           desc = "Execute BoxLang with current version" },
        @{ name = "run <args>";            desc = "Alias for exec" },
        @{ name = "miniserver <args>";     desc = "Start BoxLang MiniServer" },
        @{ name = "clean";                 desc = "Clean cache and temporary files" },
        @{ name = "stats";                 desc = "Show performance and usage statistics" },
        @{ name = "doctor";                desc = "Check BVM installation health" },
        @{ name = "check-update";          desc = "Check for BVM updates" },
        @{ name = "version";               desc = "Show BVM version" },
        @{ name = "help";                  desc = "Show this help message" }
    )
    foreach ($cmd in $cmds) {
        Write-Host -ForegroundColor Green "  $($cmd.name.PadRight(24))" -NoNewline
        Write-Host $cmd.desc
    }
    Write-Host ""
    Write-Host -ForegroundColor White "EXAMPLES:"
    Write-Host "  bvm install latest"
    Write-Host "  bvm install 1.2.0"
    Write-Host "  bvm install latest --force"
    Write-Host "  bvm use 1.2.0"
    Write-Host "  bvm use                # Read version from .bvmrc"
    Write-Host "  bvm local latest       # Set .bvmrc to 'latest'"
    Write-Host "  bvm list"
    Write-Host "  bvm current"
    Write-Host "  bvm exec --version"
    Write-Host "  bvm run --help"
    Write-Host "  bvm miniserver --port 8080"
    Write-Host "  bvm clean"
    Write-Host "  bvm stats"
    Write-Host "  bvm doctor"
    Write-Host "  bvm check-update"
    Write-Host "  bvm remove 1.1.0"
    Write-Host "  bvm uninstall"
    Write-Host ""
    Write-Host -ForegroundColor White "ENVIRONMENT:"
    Write-Host "  BVM_HOME    BVM installation directory (default: %USERPROFILE%\.bvm)"
    Write-Host ""
    Write-Host -ForegroundColor White "FILES:"
    Write-Host "  %BVM_HOME%\versions\   Installed BoxLang versions"
    Write-Host "  %BVM_HOME%\current     Junction to current BoxLang version"
    Write-Host "  %BVM_HOME%\config      BVM configuration file"
    Write-Host ""
    Write-Host -ForegroundColor White "INSTALLATION:"
    Write-Host -NoNewline "  One-liner: "
    Write-Host -ForegroundColor Green "iwr -useb https://install-bvm.boxlang.io | iex"
    Write-Host ""
}

###########################################################################
# Main Command Dispatcher
###########################################################################

# Need to add System.IO.Compression for ZIP validation
Add-Type -AssemblyName System.IO.Compression.FileSystem

$command = if ($args.Count -gt 0) { $args[0] } else { "" }
$restArgs = if ($args.Count -gt 1) { $args[1..($args.Count - 1)] } else { @() }

switch ($command.ToLower()) {

    { $_ -in @("install", "i") } {
        $version = if ($restArgs.Count -gt 0) { $restArgs[0] } else { "" }
        $force   = $restArgs -contains "--force"
        Install-Version -Version $version -Force $force
    }

    { $_ -in @("use", "switch") } {
        $version = if ($restArgs.Count -gt 0) { $restArgs[0] } else { "" }
        Use-Version -Version $version
    }

    "local" {
        $version = if ($restArgs.Count -gt 0) { $restArgs[0] } else { "" }
        Write-BvmrcVersion -Version $version
    }

    { $_ -in @("current", "cur") } {
        Show-CurrentVersion
    }

    { $_ -in @("list", "ls") } {
        List-InstalledVersions
    }

    { $_ -in @("list-remote", "ls-remote") } {
        List-RemoteVersions
    }

    { $_ -in @("remove", "rm", "uninstall-version") } {
        $version = if ($restArgs.Count -gt 0) { $restArgs[0] } else { "" }
        Remove-Version -Version $version
    }

    "uninstall" {
        Uninstall-BVM
    }

    "which" {
        Show-Which
    }

    { $_ -in @("exec", "run") } {
        Exec-BoxLang -Arguments $restArgs
    }

    { $_ -in @("miniserver", "ms") } {
        Exec-MiniServer -Arguments $restArgs
    }

    "clean" {
        Invoke-CleanCache
    }

    { $_ -in @("stats", "performance", "usage") } {
        Show-Stats
    }

    { $_ -in @("doctor", "health") } {
        Invoke-Doctor
    }

    "check-update" {
        Check-BvmUpdates
    }

    { $_ -in @("version", "--version", "-v") } {
        Write-Host "BVM v$BVM_VERSION"
    }

    { $_ -in @("help", "--help", "-h") } {
        Show-Help
    }

    "" {
        Show-Help
    }

    default {
        Write-BvmError "Unknown command: $command"
        Write-Host ""
        Show-Help
        exit 1
    }
}
