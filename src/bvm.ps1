# BoxLang Version Manager (BVM)
# A simple version manager for BoxLang similar to jenv or nvm
# Author: BoxLang Team
# Version: @build.version@
# License: Apache License, Version 2.0

param(
    [string]$Command = "help",
    [string[]]$Arguments = @()
)

# Ensure console supports UTF-8 for emojis
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

###########################################################################
# Global Variables
###########################################################################

$BVM_VERSION = "@build.version@"
$BVM_HOME = if ($env:BVM_HOME) { 
    $env:BVM_HOME 
} else { 
    $homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
    Join-Path $homeDir ".bvm" 
}
$BVM_CACHE_DIR = Join-Path $BVM_HOME "cache"
$BVM_VERSIONS_DIR = Join-Path $BVM_HOME "versions"
$BVM_SCRIPTS_DIR = Join-Path $BVM_HOME "scripts"
$BVM_CURRENT_LINK = Join-Path $BVM_HOME "current"
$BVM_CONFIG_FILE = Join-Path $BVM_HOME "config"

# URLs for BoxLang downloads
$DOWNLOAD_BASE_URL = "https://downloads.ortussolutions.com/ortussolutions/boxlang"
$MINISERVER_BASE_URL = "https://downloads.ortussolutions.com/ortussolutions/boxlang-runtimes/boxlang-miniserver"
$INSTALLER_BASE_URL = "https://downloads.ortussolutions.com/ortussolutions/boxlang-quick-installer"
$LATEST_URL = "$DOWNLOAD_BASE_URL/boxlang-latest.zip"
$LATEST_VERSION_URL = "$DOWNLOAD_BASE_URL/version-latest.properties"
$SNAPSHOT_URL = "$DOWNLOAD_BASE_URL/boxlang-snapshot.zip"
$SNAPSHOT_VERSION_URL = "$DOWNLOAD_BASE_URL/version-snapshot.properties"
$LATEST_MINISERVER_URL = "$MINISERVER_BASE_URL/boxlang-miniserver-latest.zip"
$SNAPSHOT_MINISERVER_URL = "$MINISERVER_BASE_URL/boxlang-miniserver-snapshot.zip"
$INSTALLER_URL = "$INSTALLER_BASE_URL/boxlang-installer.zip"
$VERSION_CHECK_URL = "$INSTALLER_BASE_URL/version.json"

###########################################################################
# Helper Functions
###########################################################################

function Write-Info {
    param([string]$Message)
    Write-Host -ForegroundColor Blue "ℹ️  $Message"
}

function Write-Success {
    param([string]$Message)
    Write-Host -ForegroundColor Green "✅ $Message"
}

function Write-Warning {
    param([string]$Message)
    Write-Host -ForegroundColor Yellow "⚠️  $Message"
}

function Write-Error {
    param([string]$Message)
    Write-Host -ForegroundColor Red "🔴 $Message"
}

function Write-Header {
    param([string]$Message)
    Write-Host -ForegroundColor Cyan $Message
}

function Test-Command {
    param([string]$CommandName)
    return [bool](Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Test-NetworkConnectivity {
    try {
        $testConnection = Test-NetConnection -ComputerName "downloads.ortussolutions.com" -Port 443 -InformationLevel Quiet -ErrorAction SilentlyContinue
        return $testConnection
    }
    catch {
        return $false
    }
}

function Get-RemoteVersion {
    param([string]$VersionType)
    
    $versionUrl = switch ($VersionType) {
        "latest" { $LATEST_VERSION_URL }
        "snapshot" { $SNAPSHOT_VERSION_URL }
        default { return $null }
    }
    
    try {
        $response = Invoke-WebRequest -Uri $versionUrl -ErrorAction Stop
        $content = $response.Content
        
        # Parse version from properties file
        $lines = $content -split "`n"
        foreach ($line in $lines) {
            if ($line -match "^version=(.+)$") {
                return $matches[1].Trim()
            }
        }
        return $null
    }
    catch {
        return $null
    }
}

function Test-DownloadWithChecksum {
    param(
        [string]$FilePath,
        [string]$BaseUrl,
        [int]$MinSize
    )
    
    if (-not (Test-Path $FilePath)) {
        return $false
    }
    
    $fileInfo = Get-Item $FilePath
    if ($fileInfo.Length -lt $MinSize) {
        Write-Warning "Downloaded file is smaller than expected ($($fileInfo.Length) < $MinSize bytes)"
        return $false
    }
    
    # For BoxLang 1.3.0+, try to verify with SHA-256 checksum
    $checksumUrl = "$BaseUrl.sha256"
    try {
        $checksumResponse = Invoke-WebRequest -Uri $checksumUrl -ErrorAction Stop
        $expectedHash = ($checksumResponse.Content -split "`n")[0].Split()[0].Trim()
        
        $actualHash = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash
        
        if ($actualHash -eq $expectedHash) {
            Write-Success "✓ Download verified with SHA-256 checksum"
            return $true
        } else {
            Write-Warning "⚠️  SHA-256 checksum mismatch - file may be corrupted"
            return $false
        }
    }
    catch {
        Write-Warning "⚠️  SHA-256 checksum not available - skipping verification"
        return $true  # Continue without verification for older versions
    }
}

###########################################################################
# Core BVM Functions
###########################################################################

function Install-Version {
    param(
        [string]$Version = "latest",
        [bool]$Force = $false
    )
    
    if (-not $Version) {
        $Version = "latest"
    }
    
    $originalVersion = $Version
    
    Write-Info "Installing BoxLang version: $Version"
    
    # Validate version
    if (-not ($Version -match "^(latest|snapshot|\d+\.\d+\.\d+.*)$")) {
        Write-Error "Invalid version format: $Version"
        Write-Info "Valid formats: latest, snapshot, 1.2.0, 1.2.0-beta"
        return $false
    }
    
    # Create cache directory if it doesn't exist
    if (-not (Test-Path $BVM_CACHE_DIR)) {
        New-Item -ItemType Directory -Path $BVM_CACHE_DIR -Force | Out-Null
    }
    
    # Set up URLs and paths
    $versionDir = Join-Path $BVM_VERSIONS_DIR $Version
    $tempInstallDir = Join-Path $BVM_VERSIONS_DIR "installing-$Version"
    
    switch ($Version) {
        "latest" {
            $boxlangUrl = $LATEST_URL
            $miniServerUrl = $LATEST_MINISERVER_URL
        }
        "snapshot" {
            $boxlangUrl = $SNAPSHOT_URL
            $miniServerUrl = $SNAPSHOT_MINISERVER_URL
        }
        default {
            $boxlangUrl = "$DOWNLOAD_BASE_URL/boxlang-$Version.zip"
            $miniServerUrl = "$MINISERVER_BASE_URL/boxlang-miniserver-$Version.zip"
        }
    }
    
    $boxlangCache = Join-Path $BVM_CACHE_DIR "boxlang-$Version.zip"
    $miniServerCache = Join-Path $BVM_CACHE_DIR "boxlang-miniserver-$Version.zip"
    
    # Check if version already exists
    if ((Test-Path $versionDir) -and (-not $Force)) {
        Write-Warning "BoxLang $Version is already installed"
        Write-Info "Use 'bvm use $Version' to switch to this version"
        Write-Info "Use 'bvm install $Version --force' to reinstall"
        return $true
    }
    
    # Create installation directory
    if (Test-Path $tempInstallDir) {
        Remove-Item -Path $tempInstallDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempInstallDir -Force | Out-Null
    
    # Check network connectivity
    if (-not (Test-NetworkConnectivity)) {
        Write-Warning "Network connectivity issues detected - downloads may fail"
    }
    
    # Download BoxLang runtime
    Write-Info "⬇️  Downloading BoxLang runtime... (this may take a moment)"
    try {
        Invoke-WebRequest -Uri $boxlangUrl -OutFile $boxlangCache -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to download BoxLang runtime"
        Remove-Item -Path $tempInstallDir -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }
    
    # Verify download
    if (-not (Test-DownloadWithChecksum -FilePath $boxlangCache -BaseUrl $boxlangUrl -MinSize 5000000)) {
        Write-Error "BoxLang runtime download verification failed"
        Remove-Item -Path $tempInstallDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $boxlangCache -Force -ErrorAction SilentlyContinue
        return $false
    }
    
    # Download BoxLang MiniServer
    Write-Host ""
    Write-Info "⬇️  Downloading BoxLang MiniServer... (this may take a moment)"
    try {
        Invoke-WebRequest -Uri $miniServerUrl -OutFile $miniServerCache -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to download BoxLang MiniServer"
        Remove-Item -Path $tempInstallDir -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }
    
    # Verify download
    if (-not (Test-DownloadWithChecksum -FilePath $miniServerCache -BaseUrl $miniServerUrl -MinSize 8000000)) {
        Write-Error "BoxLang MiniServer download verification failed"
        Remove-Item -Path $tempInstallDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $miniServerCache -Force -ErrorAction SilentlyContinue
        return $false
    }
    
    # Extract BoxLang runtime
    Write-Host ""
    Write-Info "📦 Extracting BoxLang runtime..."
    try {
        Expand-Archive -Path $boxlangCache -DestinationPath $tempInstallDir -Force -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to extract BoxLang runtime"
        Remove-Item -Path $tempInstallDir -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }
    
    # Extract BoxLang MiniServer
    Write-Info "📦 Extracting BoxLang MiniServer..."
    try {
        Expand-Archive -Path $miniServerCache -DestinationPath $tempInstallDir -Force -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to extract BoxLang MiniServer"
        Remove-Item -Path $tempInstallDir -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }
    
    # Detect actual version for latest/snapshot installations
    $actualVersion = $Version
    if ($originalVersion -eq "latest" -or $originalVersion -eq "snapshot") {
        Write-Info "🔎 Version alias requested, fetching actual version from remote..."
        
        $actualVersion = Get-RemoteVersion -VersionType $originalVersion
        if ($actualVersion) {
            # Clean up version string - remove any build metadata after +
            $actualVersion = $actualVersion -replace '\+.*$', ''
            Write-Info "Detected version: $actualVersion"
            
            # Check if this version already exists
            $actualVersionDir = Join-Path $BVM_VERSIONS_DIR $actualVersion
            if ((Test-Path $actualVersionDir) -and (-not $Force)) {
                Write-Warning "BoxLang $actualVersion is already installed"
                Write-Info "Use 'bvm use $actualVersion' to switch to this version"
                Write-Info "Use 'bvm install $originalVersion --force' to reinstall"
                Remove-Item -Path $tempInstallDir -Recurse -Force -ErrorAction SilentlyContinue
                return $true
            }
            
            # If force install and version exists, remove it first
            if ((Test-Path $actualVersionDir) -and $Force) {
                Write-Warning "Force reinstalling - removing existing $actualVersion..."
                Remove-Item -Path $actualVersionDir -Recurse -Force
            }
            
            # Move from temporary to actual version directory
            $versionDir = $actualVersionDir
            if (-not (Test-Path (Split-Path $versionDir))) {
                New-Item -ItemType Directory -Path (Split-Path $versionDir) -Force | Out-Null
            }
            Move-Item -Path $tempInstallDir -Destination $versionDir
            $Version = $actualVersion
        } else {
            Write-Error "Failed to fetch version info from remote"
            Remove-Item -Path $tempInstallDir -Recurse -Force -ErrorAction SilentlyContinue
            return $false
        }
    } else {
        # For specific versions, just move to the version directory
        if ((Test-Path $versionDir) -and $Force) {
            Write-Warning "Force reinstalling - removing existing $Version..."
            Remove-Item -Path $versionDir -Recurse -Force
        }
        
        if (-not (Test-Path (Split-Path $versionDir))) {
            New-Item -ItemType Directory -Path (Split-Path $versionDir) -Force | Out-Null
        }
        Move-Item -Path $tempInstallDir -Destination $versionDir
    }
    
    Write-Success "Successfully installed BoxLang $Version"
    
    # Automatically use the newly installed version if no current version is set
    if (-not (Test-Path $BVM_CURRENT_LINK)) {
        Write-Info "Setting $Version as the current version"
        Use-Version -Version $Version
    }
    
    return $true
}

function Use-Version {
    param([string]$Version)
    
    if (-not $Version) {
        Write-Error "Please specify a version to use"
        return $false
    }
    
    $versionDir = Join-Path $BVM_VERSIONS_DIR $Version
    
    if (-not (Test-Path $versionDir)) {
        Write-Error "BoxLang $Version is not installed"
        Write-Info "Available versions:"
        Get-InstalledVersions
        Write-Info "Install with: bvm install $Version"
        return $false
    }
    
    # Remove existing current link if it exists
    if (Test-Path $BVM_CURRENT_LINK) {
        Remove-Item -Path $BVM_CURRENT_LINK -Force
    }
    
    # Create symbolic link (or junction on Windows)
    try {
        # Try to create a symbolic link first
        New-Item -ItemType SymbolicLink -Path $BVM_CURRENT_LINK -Target $versionDir -ErrorAction Stop | Out-Null
    }
    catch {
        # Fallback to junction if symbolic link fails
        try {
            cmd /c "mklink /J `"$BVM_CURRENT_LINK`" `"$versionDir`"" | Out-Null
        }
        catch {
            Write-Error "Failed to create link to $Version"
            return $false
        }
    }
    
    Write-Success "Now using BoxLang $Version"
    
    # Update PATH for current session if BVM is in path
    $bvmBin = Join-Path $BVM_HOME "bin"
    if ($env:PATH -like "*$bvmBin*") {
        $currentVersionBin = Join-Path $BVM_CURRENT_LINK "bin"
        if (Test-Path $currentVersionBin) {
            # Remove any existing current version from PATH and add the new one
            $pathParts = $env:PATH -split ";"
            $filteredPath = $pathParts | Where-Object { $_ -notlike "*\.bvm\current\bin*" }
            $env:PATH = ($currentVersionBin, $filteredPath) -join ";"
        }
    }
    
    return $true
}

function Get-InstalledVersions {
    if (-not (Test-Path $BVM_VERSIONS_DIR)) {
        Write-Info "No versions installed"
        return
    }
    
    $versions = Get-ChildItem -Path $BVM_VERSIONS_DIR -Directory | Sort-Object Name
    
    if ($versions.Count -eq 0) {
        Write-Info "No versions installed"
        return
    }
    
    $currentVersion = Get-CurrentVersion
    
    Write-Info "Installed BoxLang versions:"
    foreach ($version in $versions) {
        $marker = if ($version.Name -eq $currentVersion) { " * " } else { "   " }
        Write-Host "$marker$($version.Name)"
    }
}

function Get-CurrentVersion {
    if (Test-Path $BVM_CURRENT_LINK) {
        try {
            $target = (Get-Item $BVM_CURRENT_LINK).Target
            if ($target) {
                return Split-Path $target -Leaf
            }
        }
        catch {
            # Fallback for junction links
            $junction = cmd /c "dir `"$BVM_CURRENT_LINK`"" 2>$null | Select-String "JUNCTION"
            if ($junction) {
                $targetPath = ($junction -split '\[')[1] -replace '\]', ''
                return Split-Path $targetPath -Leaf
            }
        }
    }
    return $null
}

function Show-CurrentVersion {
    $currentVersion = Get-CurrentVersion
    if ($currentVersion) {
        Write-Success "Current BoxLang version: $currentVersion"
    } else {
        Write-Info "No current version set"
        Write-Info "Use 'bvm use <version>' to set a current version"
    }
}

function Remove-Version {
    param([string]$Version)
    
    if (-not $Version) {
        Write-Error "Please specify a version to remove"
        return $false
    }
    
    $versionDir = Join-Path $BVM_VERSIONS_DIR $Version
    
    if (-not (Test-Path $versionDir)) {
        Write-Error "BoxLang $Version is not installed"
        return $false
    }
    
    # Check if it's the current version
    $currentVersion = Get-CurrentVersion
    if ($currentVersion -eq $Version) {
        Write-Warning "Cannot remove the currently active version: $Version"
        Write-Info "Switch to another version first with 'bvm use <version>'"
        return $false
    }
    
    # Confirm removal
    $response = Read-Host "Are you sure you want to remove BoxLang $Version? (y/N)"
    if ($response -notmatch "^[Yy]") {
        Write-Info "Removal cancelled"
        return $false
    }
    
    Remove-Item -Path $versionDir -Recurse -Force
    Write-Success "Removed BoxLang $Version"
    
    return $true
}

function Invoke-BoxLang {
    param([string[]]$Arguments)
    
    $currentVersion = Get-CurrentVersion
    if (-not $currentVersion) {
        Write-Error "No current BoxLang version set"
        Write-Info "Install and use a version first:"
        Write-Info "  bvm install latest"
        Write-Info "  bvm use latest"
        return $false
    }
    
    $boxlangExe = Join-Path $BVM_CURRENT_LINK "bin\boxlang.bat"
    if (-not (Test-Path $boxlangExe)) {
        $boxlangExe = Join-Path $BVM_CURRENT_LINK "bin\boxlang"
    }
    
    if (-not (Test-Path $boxlangExe)) {
        Write-Error "BoxLang executable not found in current version"
        return $false
    }
    
    & $boxlangExe @Arguments
}

function Invoke-MiniServer {
    param([string[]]$Arguments)
    
    $currentVersion = Get-CurrentVersion
    if (-not $currentVersion) {
        Write-Error "No current BoxLang version set"
        Write-Info "Install and use a version first:"
        Write-Info "  bvm install latest"
        Write-Info "  bvm use latest"
        return $false
    }
    
    $miniServerExe = Join-Path $BVM_CURRENT_LINK "bin\boxlang-miniserver.bat"
    if (-not (Test-Path $miniServerExe)) {
        $miniServerExe = Join-Path $BVM_CURRENT_LINK "bin\boxlang-miniserver"
    }
    
    if (-not (Test-Path $miniServerExe)) {
        Write-Error "BoxLang MiniServer executable not found in current version"
        return $false
    }
    
    & $miniServerExe @Arguments
}

function Clear-Cache {
    if (Test-Path $BVM_CACHE_DIR) {
        $cacheSize = (Get-ChildItem -Path $BVM_CACHE_DIR -Recurse | Measure-Object -Property Length -Sum).Sum
        Remove-Item -Path "$BVM_CACHE_DIR\*" -Recurse -Force
        Write-Success "Cache cleared ($([math]::Round($cacheSize / 1MB, 2)) MB freed)"
    } else {
        Write-Info "Cache is already empty"
    }
}

function Show-Health {
    Write-Header "🏥 BVM Health Check"
    Write-Host ""
    
    $issues = 0
    
    # Check prerequisites
    Write-Info "Checking prerequisites..."
    
    $missingDeps = @()
    
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $missingDeps += "PowerShell 5.1+"
        $issues++
    }
    
    if (-not (Test-Command "java")) {
        $missingDeps += "Java"
        $issues++
    }
    
    if ($missingDeps.Count -eq 0) {
        Write-Success "All prerequisites satisfied"
    } else {
        Write-Warning "Missing dependencies: $($missingDeps -join ', ')"
    }
    
    # Check Java installation
    if (Test-Command "java") {
        try {
            $javaVersion = & java -version 2>&1 | Select-Object -First 1
            Write-Success "Java is available: $javaVersion"
        }
        catch {
            Write-Warning "Java command failed"
        }
    } else {
        Write-Warning "Java not found in PATH"
        Write-Info "Java 21+ is required to run BoxLang"
    }
    
    # Check BVM home directory
    if (Test-Path $BVM_HOME) {
        Write-Success "BVM home directory exists: $BVM_HOME"
    } else {
        Write-Error "BVM home directory missing: $BVM_HOME"
        $issues++
    }
    
    # Check current version
    if (Test-Path $BVM_CURRENT_LINK) {
        $currentVersion = Get-CurrentVersion
        if ($currentVersion) {
            Write-Success "Current version set: $currentVersion"
            
            # Check if current version directory exists
            $currentVersionDir = Join-Path $BVM_VERSIONS_DIR $currentVersion
            if (Test-Path $currentVersionDir) {
                Write-Success "Current version directory exists: $currentVersionDir"
                
                # Check for expected binaries
                $expectedBinaries = @("boxlang.bat", "boxlang", "boxlang-miniserver.bat", "boxlang-miniserver")
                $missingBinaries = @()
                foreach ($binary in $expectedBinaries) {
                    $binaryPath = Join-Path $BVM_CURRENT_LINK "bin\$binary"
                    if (-not (Test-Path $binaryPath)) {
                        $missingBinaries += $binary
                    }
                }
                
                if ($missingBinaries.Count -eq 0) {
                    Write-Success "👊 All expected binaries are present"
                } else {
                    Write-Warning "Missing binaries: $($missingBinaries -join ', ')"
                    Write-Info "Some features may not be available"
                }
            } else {
                Write-Error "Current version directory missing"
                $issues++
            }
        } else {
            Write-Error "Current version link is broken"
            Remove-Item -Path $BVM_CURRENT_LINK -Force -ErrorAction SilentlyContinue
            Write-Info "Removed broken link"
            $issues++
        }
    } else {
        Write-Warning "No current version set"
        Write-Info "Use 'bvm use <version>' to set a current version"
    }
    
    Write-Host ""
    Write-Host -ForegroundColor Blue "─────────────────────────────────────────────────────────────────────────────"
    
    if ($issues -eq 0) {
        Write-Success "❤️‍🔥 BVM installation is healthy!"
    } else {
        Write-Warning "Found $issues issue$(if ($issues -ne 1) { 's' }). Please address the issues above."
    }
}

function Show-Help {
    Write-Header "🥊 BVM (BoxLang Version Manager) v$BVM_VERSION"
    Write-Host ""
    Write-Host -ForegroundColor Yellow "A simple version manager for BoxLang similar to jenv or nvm"
    Write-Host ""
    Write-Host -ForegroundColor White "Usage:"
    Write-Host "  bvm <command> [arguments]"
    Write-Host ""
    Write-Host -ForegroundColor White "Commands:"
    Write-Host "  install <version>     Install a BoxLang version (latest, snapshot, 1.2.0)"
    Write-Host "  use <version>         Use a specific BoxLang version"
    Write-Host "  current               Show current BoxLang version"  
    Write-Host "  list, ls              List installed BoxLang versions"
    Write-Host "  remove <version>      Remove a BoxLang version"
    Write-Host "  exec, run [args]      Execute BoxLang REPL with current version"
    Write-Host "  miniserver [args]     Execute BoxLang MiniServer with current version"
    Write-Host "  clean                 Clean download cache"
    Write-Host "  doctor, health        Check BVM installation health"
    Write-Host "  version               Show BVM version"
    Write-Host "  help                  Show this help message"
    Write-Host ""
    Write-Host -ForegroundColor White "Examples:"
    Write-Host "  bvm install latest    # Install latest stable version"
    Write-Host "  bvm install snapshot  # Install latest development snapshot"
    Write-Host "  bvm install 1.2.0     # Install specific version"
    Write-Host "  bvm use 1.2.0         # Switch to version 1.2.0"
    Write-Host "  bvm exec --version    # Check BoxLang version"
    Write-Host "  bvm miniserver --port 8080  # Start MiniServer on port 8080"
    Write-Host ""
    Write-Host -ForegroundColor White "Installation Paths:"
    Write-Host "  BVM Home:    $BVM_HOME"
    Write-Host "  Versions:    $BVM_VERSIONS_DIR"
    Write-Host "  Cache:       $BVM_CACHE_DIR"
    Write-Host "  Current:     $BVM_CURRENT_LINK"
    Write-Host ""
}

###########################################################################
# Main Command Handler
###########################################################################

function Main {
    param(
        [string]$Command,
        [string[]]$Arguments
    )
    
    # Create BVM directories if they don't exist
    @($BVM_HOME, $BVM_CACHE_DIR, $BVM_VERSIONS_DIR, $BVM_SCRIPTS_DIR) | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
    }
    
    switch ($Command.ToLower()) {
        "install" {
            $version = if ($Arguments.Count -gt 0) { $Arguments[0] } else { "latest" }
            $force = $Arguments -contains "--force"
            Install-Version -Version $version -Force $force
        }
        "use" {
            if ($Arguments.Count -eq 0) {
                Write-Error "Please specify a version to use"
                return
            }
            Use-Version -Version $Arguments[0]
        }
        "current" {
            Show-CurrentVersion
        }
        { $_ -in @("list", "ls") } {
            Get-InstalledVersions
        }
        { $_ -in @("remove", "rm") } {
            if ($Arguments.Count -eq 0) {
                Write-Error "Please specify a version to remove"
                return
            }
            Remove-Version -Version $Arguments[0]
        }
        { $_ -in @("exec", "run") } {
            Invoke-BoxLang -Arguments $Arguments
        }
        { $_ -in @("miniserver", "mini-server", "ms") } {
            Invoke-MiniServer -Arguments $Arguments
        }
        "clean" {
            Clear-Cache
        }
        { $_ -in @("doctor", "health") } {
            Show-Health
        }
        { $_ -in @("version", "--version", "-v") } {
            Write-Host -ForegroundColor Green "🥊 BVM (BoxLang Version Manager) v$BVM_VERSION"
        }
        { $_ -in @("help", "--help", "-h", "") } {
            Show-Help
        }
        default {
            Write-Error "Unknown command: $Command"
            Write-Host ""
            Show-Help
        }
    }
}

# Run main function
Main -Command $Command -Arguments $Arguments