# BoxLang Installation Script
# Description: This script installs the BoxLang miniserver web application on a Windows system.
# Author: BoxLang Team
# Version: @build.version@
# License: Apache License, Version 2.0

$requiredJavaVersion = 21
$installedJavaVersion = $null
$bxName = "BoxLang" + [char]0x00A9;

# Check for help argument early to avoid any setup overhead
if ($args.Count -ge 1 -and ($args[0] -eq "--help" -or $args[0] -eq "-h")) {
    Show-Help
    exit 0
}

# Check for uninstall argument
if ($args.Count -ge 1 -and $args[0] -eq "--uninstall") {
    Uninstall-BoxLang
    exit 0
}

# Check for check-update argument
if ($args.Count -ge 1 -and $args[0] -eq "--check-update") {
    if (-not (Test-Prerequisites)) {
        exit 1
    }
    Test-ForUpdates
    exit 0
}

# Parse arguments to check for --force flag and remove it from args
$FORCE_INSTALL = $false
$newArgs = @()
foreach ($arg in $args) {
    if ($arg -eq "--force") {
        $FORCE_INSTALL = $true
    } else {
        $newArgs += $arg
    }
}

# $TARGET_VERSION = "latest"
$TARGET_VERSION = if ($newArgs.Count -ge 1 -and $newArgs[0] -notmatch "^--") { $newArgs[0] } else { "latest" }
$DOWNLOAD_URL = ""
if ( $null -ne $env:BOXLANG_TARGET_VERSION ) {
    $TARGET_VERSION = $env:BOXLANG_TARGET_VERSION
}

# If the version is "snapshot", always force it
if ($TARGET_VERSION -eq "snapshot") {
    $FORCE_INSTALL = $true
}

$INSTALLER_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang-quick-installer/boxlang-installer.zip"
$SNAPSHOT_URL = "https://downloads.ortussolutions.com/ortussolutions/boxlang/boxlang-snapshot.zip"
$SNAPSHOT_URL_MINISERVER = "https://downloads.ortussolutions.com/ortussolutions/boxlang-runtimes/boxlang-miniserver/boxlang-miniserver-snapshot.zip"
$LATEST_URL = "https://downloads.ortussolutions.com/ortussolutions/boxlang/boxlang-latest.zip"
$LATEST_URL_MINISERVER = "https://downloads.ortussolutions.com/ortussolutions/boxlang-runtimes/boxlang-miniserver/boxlang-miniserver-latest.zip"
$VERSIONED_URL = "https://downloads.ortussolutions.com/ortussolutions/boxlang/${TARGET_VERSION}/boxlang-${TARGET_VERSION}.zip"
$VERSIONED_URL_MINISERVER = "https://downloads.ortussolutions.com/ortussolutions/boxlang-runtimes/boxlang-miniserver/${TARGET_VERSION}/boxlang-miniserver-${TARGET_VERSION}.zip"
$INSTALLATION_FOLDER = "c:\boxlang"
$DESTINATION_LIB = "$INSTALLATION_FOLDER\lib"
$DESTINATION_BIN = "$INSTALLATION_FOLDER\bin"
$DESTINATION_HOME = "$INSTALLATION_FOLDER\home"
$DESTINATION_SCRIPTS = "$INSTALLATION_FOLDER\scripts"

# Set the progress preference to silently continue to avoid cluttering the console
$ProgressPreference = 'SilentlyContinue'

# Determine download URLs based on target version
if ($TARGET_VERSION -eq "snapshot") {
    $DOWNLOAD_URL = $SNAPSHOT_URL
    $DOWNLOAD_URL_MINISERVER = $SNAPSHOT_URL_MINISERVER
}
elseif ($TARGET_VERSION -eq "latest" ) {
    $DOWNLOAD_URL = $LATEST_URL
    $DOWNLOAD_URL_MINISERVER = $LATEST_URL_MINISERVER
}
else {
    $DOWNLOAD_URL = $VERSIONED_URL
    $DOWNLOAD_URL_MINISERVER = $VERSIONED_URL_MINISERVER
}

###########################################################################
# Help Function
###########################################################################
function Show-Help {
    # Ensure console supports UTF-8 for emojis
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    Write-Host -ForegroundColor Green "📦 BoxLang® Quick Installer"
    Write-Host ""
    Write-Host -ForegroundColor Yellow "This script installs the BoxLang® runtime and tools on your system."
    Write-Host ""
    Write-Host -ForegroundColor White -NoNewline "Usage:"
    Write-Host ""
    Write-Host "  .\install-boxlang.ps1 [version] [options]"
    Write-Host "  .\install-boxlang.ps1 --help"
    Write-Host ""
    Write-Host -ForegroundColor White -NoNewline "Arguments:"
    Write-Host ""
    Write-Host "  [version]         (Optional) Specify which version to install"
    Write-Host "                    - 'latest' (default): Install the latest stable release"
    Write-Host "                    - 'snapshot': Install the latest development snapshot"
    Write-Host "                    - '1.2.0': Install a specific version number"
    Write-Host ""
    Write-Host -ForegroundColor White -NoNewline "Options:"
    Write-Host ""
    Write-Host "  --help, -h        Show this help message"
    Write-Host "  --uninstall       Remove BoxLang from the system"
    Write-Host "  --check-update    Check if a newer version is available"
    Write-Host "  --force           Force reinstallation even if already installed"
    Write-Host ""
    Write-Host -ForegroundColor White -NoNewline "Examples:"
    Write-Host ""
    Write-Host "  .\install-boxlang.ps1"
    Write-Host "  .\install-boxlang.ps1 latest"
    Write-Host "  .\install-boxlang.ps1 snapshot"
    Write-Host "  .\install-boxlang.ps1 1.2.0"
    Write-Host "  .\install-boxlang.ps1 --force"
    Write-Host "  .\install-boxlang.ps1 --uninstall"
    Write-Host "  .\install-boxlang.ps1 --check-update"
    Write-Host ""
    Write-Host -ForegroundColor White -NoNewline "Installation Methods:"
    Write-Host ""
    Write-Host -NoNewline "  🌐 One-liner: "
    Write-Host -ForegroundColor Green "iwr -useb https://boxlang.io/install.ps1 | iex"
    Write-Host -NoNewline "  📦 With version: "
    Write-Host -ForegroundColor Green "`$env:BOXLANG_TARGET_VERSION='snapshot'; iwr -useb https://boxlang.io/install.ps1 | iex"
    Write-Host ""
    Write-Host -ForegroundColor White -NoNewline "Requirements:"
    Write-Host ""
    Write-Host "  - Java 21 or higher (OpenJDK or Oracle JDK)"
    Write-Host "  - PowerShell 5.1+ or PowerShell Core 6+"
    Write-Host "  - Internet connection (for downloading)"
    Write-Host "  - Administrator privileges (recommended)"
    Write-Host ""
    Write-Host -ForegroundColor White -NoNewline "Installation Paths:"
    Write-Host ""
    Write-Host "  📁 Binaries: C:\boxlang\bin\"
    Write-Host "  📁 Libraries: C:\boxlang\lib\"
    Write-Host "  📁 BoxLang Home: C:\boxlang\home\"
    Write-Host ""
    Write-Host -ForegroundColor White -NoNewline "After Installation:"
    Write-Host ""
    Write-Host -NoNewline "  🚀 Start REPL: "
    Write-Host -ForegroundColor Green -NoNewline "boxlang"
    Write-Host -NoNewline " or "
    Write-Host -ForegroundColor Green "bx"
    Write-Host -NoNewline "  🌐 Start MiniServer: "
    Write-Host -ForegroundColor Green -NoNewline "boxlang-miniserver"
    Write-Host -NoNewline " or "
    Write-Host -ForegroundColor Green "bx-miniserver"
    Write-Host -NoNewline "  📦 Install modules: "
    Write-Host -ForegroundColor Green "install-bx-module <module-name>"
    Write-Host -NoNewline "  📦 Package Manager: "
    Write-Host -ForegroundColor Green "box"
    Write-Host " (if CommandBox was installed)"
    Write-Host -NoNewline "  🔄 Update BoxLang: "
    Write-Host -ForegroundColor Green "install-boxlang latest"
    Write-Host -NoNewline "  🔍 Check for updates: "
    Write-Host -ForegroundColor Green ".\install-boxlang.ps1 --check-update"
    Write-Host ""
    Write-Host -ForegroundColor White -NoNewline "Notes:"
    Write-Host ""
    Write-Host -NoNewline "  - Run as Administrator for best results: "
    Write-Host -ForegroundColor Green "Run as Administrator"
    Write-Host "  - Installation adds C:\boxlang\bin to your PATH"
    Write-Host "  - Java detection works in various PowerShell contexts"
    Write-Host "  - Previous versions are automatically removed before installation"
    Write-Host "  - BoxLang® is open-source under Apache 2.0 License"
    Write-Host ""
    Write-Host -ForegroundColor White -NoNewline "More Information:"
    Write-Host ""
    Write-Host "  🌐 Website: https://boxlang.io"
    Write-Host "  📖 Documentation: https://boxlang.io/docs"
    Write-Host "  💾 GitHub: https://github.com/ortus-boxlang/boxlang"
    Write-Host "  💬 Community: https://boxlang.io/community"
}

###########################################################################
# Uninstall Function
###########################################################################
function Uninstall-BoxLang {
    Write-Host -ForegroundColor Yellow "🗑️  Uninstalling BoxLang..."

    # Remove from standard Windows program locations
    Write-Host -ForegroundColor Blue "Removing binaries and scripts..."
    Remove-Item -Path "C:\boxlang" -Recurse -Force -ErrorAction SilentlyContinue

    # Remove from PATH
    Write-Host -ForegroundColor Blue "Removing from PATH..."
    $currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
    $newPath = ($currentPath -split ";" | Where-Object { $_ -notlike "*boxlang*" }) -join ";"
    [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)

    # Remove environment variables
    Write-Host -ForegroundColor Blue "Removing environment variables..."
    [Environment]::SetEnvironmentVariable("BOXLANG_HOME", $null, [EnvironmentVariableTarget]::User)

    Write-Host -ForegroundColor Green "✅ BoxLang uninstalled successfully"
    Write-Host -ForegroundColor Blue "💡 BoxLang Home directory was preserved"
    Write-Host -ForegroundColor Blue "💡 To remove it completely, delete the .boxlang folder in your user directory"
}

###########################################################################
# Installation Verification Function
###########################################################################
function Test-Installation {
    param([string]$BinDir)

    Write-Host -ForegroundColor Blue "🔍 Verifying installation..."

    # Test basic functionality
    $boxlangPath = Join-Path $BinDir "boxlang.bat"
    try {
        $version = & $boxlangPath --version 2>$null
        if (-not $version) {
            Write-Host -ForegroundColor Red "❌ BoxLang installation verification failed"
            return $false
        }
    }
    catch {
        Write-Host -ForegroundColor Red "❌ BoxLang installation verification failed: $($_.Exception.Message)"
        return $false
    }

    Write-Host -ForegroundColor Green "✅ Installation verified successfully"
    return $true
}

###########################################################################
# PATH Management Function
###########################################################################
function Update-PathVariable {
    param([string]$BinDir)

    # Check if path is already in PATH
    $currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
    if ($currentPath -like "*$BinDir*") {
        Write-Host -ForegroundColor Green "✅ $BinDir is already in your PATH"
        return
    }

    Write-Host -ForegroundColor Yellow "⚠️  $BinDir is not in your PATH"

    # Ask user for permission to auto-update
    $response = Read-Host "Would you like to automatically add $BinDir to your PATH? [Y/n]"
    if ($response -match "^[nN]") {
        Write-Host -ForegroundColor Yellow "Skipping automatic PATH update"
        Write-Host -ForegroundColor Blue "Manually add $BinDir to your system PATH"
        return
    }

    # Add to PATH
    Write-Host -ForegroundColor Blue "Adding $BinDir to PATH..."
    $newPath = "$currentPath;$BinDir"
    [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)
    Write-Host -ForegroundColor Green "✅ Successfully added $BinDir to PATH"
    Write-Host -ForegroundColor Blue "💡 Restart your terminal to use the new PATH"
}

###########################################################################
# Preflight Checks Function
###########################################################################
function Test-Prerequisites {
    Write-Host -ForegroundColor Blue "🔍 Running pre-flight checks..."

    $missingDeps = @()

    # Check for PowerShell (obviously available, but check version)
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $missingDeps += "PowerShell 5.1+"
    }

    # Check for internet connectivity
    try {
        $testConnection = Test-NetConnection -ComputerName "downloads.ortussolutions.com" -Port 443 -InformationLevel Quiet -ErrorAction SilentlyContinue
        if (-not $testConnection) {
            $missingDeps += "Internet connectivity"
        }
    }
    catch {
        Write-Host -ForegroundColor Yellow "⚠️  Could not verify internet connectivity"
    }

    if ($missingDeps.Count -gt 0) {
        Write-Host -ForegroundColor Red "❌ Missing required dependencies: $($missingDeps -join ', ')"
        Write-Host -ForegroundColor Blue "💡 Please ensure you have:"
        foreach ($dep in $missingDeps) {
            Write-Host "   - $dep"
        }
        return $false
    }

    Write-Host -ForegroundColor Green "✅ Pre-flight checks passed"
    return $true
}

# Perform preflight checks
if (-not (Test-Prerequisites)) {
    exit 1
}

###########################################################################
# Enhanced Java Version Check Function
###########################################################################
function Test-JavaVersion {
    Write-Host -ForegroundColor Blue "🔍 Checking Java installation..."

    $javaCandidates = @(
        "java",                                    # Standard PATH
        "$env:JAVA_HOME\bin\java.exe",            # JAVA_HOME if set
        "C:\Program Files\Java\*\bin\java.exe",   # Common Windows Oracle location
        "C:\Program Files (x86)\Java\*\bin\java.exe", # 32-bit Java location
        "$env:ProgramFiles\Eclipse Adoptium\*\bin\java.exe", # Eclipse Temurin
        "$env:ProgramFiles\Microsoft\jdk-*\bin\java.exe"     # Microsoft OpenJDK
    )

    foreach ($candidate in $javaCandidates) {
        try {
            # Handle glob patterns for Program Files
            if ($candidate -like "*\*\*") {
                $expandedPaths = Get-ChildItem -Path ($candidate -replace "\\\*.*", "") -Directory -ErrorAction SilentlyContinue |
                    ForEach-Object { $candidate -replace "\*", $_.Name }
                foreach ($expandedPath in $expandedPaths) {
                    if (Test-Path $expandedPath) {
                        $candidate = $expandedPath
                        break
                    }
                }
            }

            if (Get-Command $candidate -ErrorAction SilentlyContinue) {
                $versionOutput = & $candidate --version 2>&1 | Out-String
                if ($versionOutput -match '"(\d+)\.') {
                    $majorVersion = [int]$matches[1]
                } elseif ($versionOutput -match '"1\.(\d+)\.') {
                    $majorVersion = [int]$matches[1]  # Handle legacy 1.8 format
                } elseif ($versionOutput -match 'version (\d+)\.') {
                    $majorVersion = [int]$matches[1]
                } else {
                    continue
                }

                if ($majorVersion -ge $requiredJavaVersion) {
                    Write-Host -ForegroundColor Green "✅ Found Java $majorVersion at: $candidate"
                    return $true
                } else {
                    Write-Host -ForegroundColor Yellow "⚠️  Found Java $majorVersion at $candidate, but Java $requiredJavaVersion+ is required"
                }
            }
        }
        catch {
            # Silent continue to next candidate
        }
    }

    # If we get here, no suitable Java was found
    Write-Host -ForegroundColor Red "❌ Error: Java $requiredJavaVersion or higher is required to run BoxLang"
    Write-Host -ForegroundColor Yellow "Please install Java $requiredJavaVersion+ and ensure it's in your PATH."
    Write-Host -ForegroundColor Yellow "Recommended: OpenJDK $requiredJavaVersion+ or Oracle JRE $requiredJavaVersion+"
    Write-Host -ForegroundColor Blue "💡 You can download Java from:"
    Write-Host "   https://adoptium.net/ (Eclipse Temurin)"
    Write-Host "   https://www.microsoft.com/openjdk (Microsoft OpenJDK)"
    Write-Host "   https://www.oracle.com/java/technologies/downloads/"
    return $false
}

# Perform Java version check
if (-not (Test-JavaVersion)) {
    exit 1
}

###########################################################################
# Version Comparison Functions
###########################################################################

# Extract semantic version (Major.Minor.Patch) from version string
function Get-SemanticVersion {
    param([string]$VersionString)

    # Extract version like "1.2.3" from strings like "BoxLang v1.2.3+20241201.120000" or "1.2.3+buildId"
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

    # Compare major, minor, patch
    for ($i = 0; $i -lt 3; $i++) {
        $v1Part = if ($i -lt $v1Parts.Length) { [int]$v1Parts[$i] } else { 0 }
        $v2Part = if ($i -lt $v2Parts.Length) { [int]$v2Parts[$i] } else { 0 }

        if ($v1Part -gt $v2Part) {
            return 1  # version1 > version2
        }
        elseif ($v1Part -lt $v2Part) {
            return -1  # version1 < version2
        }
    }

    return 0  # versions are equal
}

# Get current installed BoxLang version
function Get-CurrentBoxLangVersion {
    # Try to find BoxLang in common locations
    $boxlangCandidates = @(
        "boxlang",                                    # In PATH
        "C:\boxlang\bin\boxlang.bat",                # Standard Windows install
        "$env:USERPROFILE\.local\bin\boxlang.bat"    # User install
    )

    foreach ($candidate in $boxlangCandidates) {
        try {
            if (Get-Command $candidate -ErrorAction SilentlyContinue) {
                $versionOutput = & $candidate --version 2>$null
                if ($versionOutput) {
                    $currentVersion = Get-SemanticVersion -VersionString ($versionOutput | Out-String)
                    if ($currentVersion) {
                        return $currentVersion
                    }
                }
            }
        }
        catch {
            # Continue to next candidate
        }
    }

    return $null
}

# Get latest available BoxLang version from remote
function Get-LatestBoxLangVersion {
    $versionUrl = "https://downloads.ortussolutions.com/ortussolutions/boxlang/version-latest.properties"

    try {
        # Download version info
        $versionInfo = Invoke-WebRequest -Uri $versionUrl -UseBasicParsing -ErrorAction Stop
        if (-not $versionInfo.Content) {
            return $null
        }

        # Extract version from properties file (format: version=1.2.3+buildId)
        $versionLines = $versionInfo.Content -split "`n"
        foreach ($line in $versionLines) {
            if ($line -match "^version=(.+)$") {
                $latestVersion = Get-SemanticVersion -VersionString $matches[1]
                if ($latestVersion) {
                    return $latestVersion
                }
            }
        }
    }
    catch {
        Write-Host -ForegroundColor Red "❌ Failed to fetch version information: $($_.Exception.Message)"
        return $null
    }

    return $null
}

# Check for updates and optionally prompt for installation
function Test-ForUpdates {
    Write-Host -ForegroundColor Blue "🔍 Checking for BoxLang updates..."

    # Get current version
    $currentVersion = Get-CurrentBoxLangVersion
    if (-not $currentVersion) {
        Write-Host -ForegroundColor Yellow "⚠️  BoxLang is not currently installed"
        Write-Host -ForegroundColor Blue "💡 Run '.\install-boxlang.ps1' to install the latest version"
        return
    }

    # Get latest version
    $latestVersion = Get-LatestBoxLangVersion
    if (-not $latestVersion) {
        Write-Host -ForegroundColor Red "❌ Failed to fetch latest version information"
        Write-Host -ForegroundColor Yellow "Please check your internet connection and try again"
        return
    }

    Write-Host -ForegroundColor Green "Current version: $currentVersion"
    Write-Host -ForegroundColor Green "Latest version:  $latestVersion"

    # Compare versions
    $comparisonResult = Compare-Versions -Version1 $currentVersion -Version2 $latestVersion

    switch ($comparisonResult) {
        0 {
            Write-Host -ForegroundColor Green "✅ You have the latest version of BoxLang"
        }
        1 {
            Write-Host -ForegroundColor Blue "🔄 You have a newer version than the latest release"
            Write-Host -ForegroundColor Yellow "This might be a development or snapshot build"
        }
        -1 {
            Write-Host -ForegroundColor Yellow "🆙 A newer version of BoxLang is available!"
            $response = Read-Host "Would you like to update to version $latestVersion? [Y/n]"
            if ($response -notmatch "^[nN]") {
                Write-Host -ForegroundColor Green "Starting update to BoxLang $latestVersion..."
                # Call the script again with latest version
                & $PSCommandPath "latest"
                exit 0
            }
            else {
                Write-Host -ForegroundColor Yellow "Update cancelled"
            }
        }
    }
}

# CommandBox Installation Check and Install
function Check-And-Install-CommandBox {
    param(
        [string]$BinDir
    )

    Write-Host -ForegroundColor Blue "🔍 Checking for CommandBox..."

    # Check if CommandBox is already available
    $boxCommand = Get-Command "box" -ErrorAction SilentlyContinue
    if ($boxCommand) {
        Write-Host -ForegroundColor Green "✅ CommandBox is already installed and available"
        return $true
    }

    Write-Host -ForegroundColor Yellow "⚠️  CommandBox is not installed"
    Write-Host -ForegroundColor Blue "💡 CommandBox is the Package Manager for BoxLang®"
    Write-Host -ForegroundColor Blue "💡 It allows you to easily manage BoxLang modules, dependencies, start servlet containers, and more"
    Write-Host ""

    # Ask user if they want to install CommandBox
    $response = Read-Host "Would you like to install CommandBox? [Y/n]"
    if ($response -match "^[nN]") {
        Write-Host -ForegroundColor Yellow "Skipping CommandBox installation"
        Write-Host -ForegroundColor Blue "💡 You can install CommandBox later from: https://commandbox.ortusbooks.com/setup/installation"
        return $false
    }

    # The universal binary for Windows is available at the following URL
    $commandboxUrl = "https://www.ortussolutions.com/parent/download/commandbox/type/windows"
    $commandboxTempPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "commandbox.zip"
    $commandboxExtractPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "commandbox"

    try {
        # Download CommandBox
		Write-Host -ForegroundColor Blue "📥  Downloading CommandBox from $commandboxUrl..."
        Invoke-WebRequest -Uri $commandboxUrl -OutFile $commandboxTempPath

        # Extract CommandBox
        Write-Host -ForegroundColor Blue "📦 Unzipping CommandBox..."
        if (Test-Path $commandboxExtractPath) {
            Remove-Item -Path $commandboxExtractPath -Recurse -Force
        }
        Expand-Archive -Path $commandboxTempPath -DestinationPath $commandboxExtractPath -Force

        # Install CommandBox - copy the executable to the bin directory
        Write-Host -ForegroundColor Blue "🗂️ Installing CommandBox to $BinDir\box.exe..."
        $boxExePath = Get-ChildItem -Path $commandboxExtractPath -Name "box.exe" -Recurse | Select-Object -First 1
        if ($boxExePath) {
            $sourceBoxPath = Join-Path -Path $commandboxExtractPath -ChildPath $boxExePath.Name
            $destBoxPath = Join-Path -Path $BinDir -ChildPath "box.exe"
            Copy-Item -Path $sourceBoxPath -Destination $destBoxPath -Force
        } else {
            # Look for box.bat as fallback
            $boxBatPath = Get-ChildItem -Path $commandboxExtractPath -Name "box.bat" -Recurse | Select-Object -First 1
            if ($boxBatPath) {
                $sourceBoxPath = Join-Path -Path $commandboxExtractPath -ChildPath $boxBatPath.Name
                $destBoxPath = Join-Path -Path $BinDir -ChildPath "box.bat"
                Copy-Item -Path $sourceBoxPath -Destination $destBoxPath -Force
            } else {
                throw "Could not find box.exe or box.bat in the extracted CommandBox archive"
            }
        }

        # Create commandbox.properties file to configure home directory
        Write-Host -ForegroundColor Blue "⚙️ Creating CommandBox configuration..."
        $commandboxPropertiesPath = Join-Path -Path $BinDir -ChildPath "commandbox.properties"
        $commandboxPropertiesContent = "commandbox_home=../.commandbox"
        Set-Content -Path $commandboxPropertiesPath -Value $commandboxPropertiesContent -Encoding UTF8

        # Create .commandbox directory
        $commandboxHomeDir = Join-Path -Path (Split-Path $BinDir -Parent) -ChildPath ".commandbox"
        New-Item -Type Directory -Path $commandboxHomeDir -Force | Out-Null
        Write-Host -ForegroundColor Blue "🏠 Created CommandBox HOME directory at $commandboxHomeDir"

        # Cleanup
        Remove-Item -Path $commandboxTempPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $commandboxExtractPath -Recurse -Force -ErrorAction SilentlyContinue

        Write-Host -ForegroundColor Green "✅ CommandBox installed successfully"
        return $true
    }
    catch {
        Write-Host -ForegroundColor Red "❌ Failed to install CommandBox: $($_.Exception.Message)"
        Write-Host -ForegroundColor Blue "💡 Please manually install CommandBox from: https://commandbox.ortusbooks.com/setup/installation"
        return $false
    }
}

# Function to remove previous BoxLang installations
function Remove-PreviousInstallation {
    Write-Host -ForegroundColor Yellow "🗑️ Removing previous BoxLang installation..."

    # Remove installation directories
    Remove-Item -Path "$DESTINATION_LIB" -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path "$DESTINATION_BIN" -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path "$DESTINATION_SCRIPTS" -Force -Recurse -ErrorAction SilentlyContinue

    Write-Host -ForegroundColor Green "✅ Previous installation removed successfully"
}

# Tell them where we will install
Write-Host -ForegroundColor Green ''
Write-Host -ForegroundColor Green '*************************************************************************'
Write-Host -ForegroundColor Green "Welcome to the $bxName Quick Installer"
Write-Host -ForegroundColor Green "*************************************************************************"
Write-Host -ForegroundColor Green "This will download and install the latest version of $bxName and the"
Write-Host -ForegroundColor Green "$bxName MiniServer into your system."
Write-Host -ForegroundColor Green "It will also optionally install CommandBox (BoxLang Package Manager)."
Write-Host -ForegroundColor Green "*************************************************************************"
Write-Host -ForegroundColor Green "You can also download the $bxName runtimes from https://boxlang.io"
Write-Host -ForegroundColor Green "*************************************************************************"

# Check for existing BoxLang installation
if (-not $FORCE_INSTALL) {
    Write-Host -ForegroundColor Blue "🔍 Checking for existing BoxLang installation..."

    $currentVersion = Get-CurrentBoxLangVersion
    if ($currentVersion) {
        Write-Host -ForegroundColor Yellow "⚠️  BoxLang is already installed at [C:\boxlang] with version [$currentVersion]"
        Write-Host -ForegroundColor Blue "💡 Use '.\install-boxlang.ps1 --uninstall' to remove the existing version before reinstalling."
        Write-Host -ForegroundColor Blue "💡 Or use '--force' to do a forced reinstall."
        exit 0
    } else {
        Write-Host -ForegroundColor Green "✅ No previous BoxLang installation found, proceeding with fresh install..."
        Write-Host ""
    }
} else {
    Write-Host -ForegroundColor Yellow "🔄 Forcing reinstallation of BoxLang..."
    Remove-PreviousInstallation
    Write-Host ""
}

# Uninstall previous versions (if not already done by force install)
if (-not $FORCE_INSTALL) {
    Write-Host -ForegroundColor Yellow "🗑️ Removing previous versions (if any)..."
    Remove-Item -Path "$DESTINATION_LIB" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$DESTINATION_BIN" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$DESTINATION_SCRIPTS" -Force -ErrorAction SilentlyContinue
}

# Prepare directories for installation
Write-Host -ForegroundColor Blue "📁 Creating installation folders..."
$tmp = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "/boxlang"
$INSTALLATION_FOLDER = "c:\boxlang"
New-Item -Type Directory -Path $tmp -Force | Out-Null
New-Item -Type Directory -Path $INSTALLATION_FOLDER -Force | Out-Null
New-Item -Type Directory -Path $DESTINATION_HOME -Force | Out-Null

# Download BoxLang
Write-Host -ForegroundColor Blue "📥 Downloading BoxLang® binary from $DOWNLOAD_URL"
Remove-Item -Path $tmp\boxlang.zip -ErrorAction SilentlyContinue -Force
try {
    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $tmp\boxlang.zip -ErrorAction Stop
}
catch {
    Write-Host -ForegroundColor Red "❌ Error: Download of BoxLang® binary failed"
    Write-Host -ForegroundColor Red $_.Exception.Message
    exit 1
}

# download miniserver
Write-Host -ForegroundColor Blue "📥 Downloading BoxLang® MiniServer binary from $DOWNLOAD_URL_MINISERVER"
Remove-Item -Path $tmp\boxlang-miniserver.zip -ErrorAction SilentlyContinue -Force
try {
    Invoke-WebRequest -Uri $DOWNLOAD_URL_MINISERVER -OutFile $tmp\boxlang-miniserver.zip -ErrorAction Stop
}
catch {
    Write-Host -ForegroundColor Red "❌ Error: Download of BoxLang® MiniServer binary failed"
    Write-Host -ForegroundColor Red $_.Exception.Message
    exit 1
}

# download quick-installer
Write-Host -ForegroundColor Blue "📥 Downloading BoxLang® Quick Installer from $INSTALLER_URL"
Remove-Item -Path $tmp\boxlang-installer.zip -ErrorAction SilentlyContinue -Force
try {
	Invoke-WebRequest -Uri $INSTALLER_URL -OutFile $tmp\boxlang-installer.zip -ErrorAction Stop
}
catch {
	Write-Host -ForegroundColor Red "❌ Error: Download of BoxLang® Quick Installer failed"
	Write-Host -ForegroundColor Red $_.Exception.Message
	exit 1
}

# Unpacking the Assets
Write-Host -ForegroundColor Green "📦 Unzipping BoxLang"
try {
    Expand-Archive -Path $tmp\boxlang.zip -DestinationPath $INSTALLATION_FOLDER -Force -ErrorAction Stop
}
catch {
    Write-Host -ForegroundColor Red "❌ Error: Failed to extract BoxLang archive"
    Write-Host -ForegroundColor Red $_.Exception.Message
    exit 1
}
Write-Host -ForegroundColor Green "📦 Unzipping BoxLang MiniServer"
try {
    Expand-Archive -Path $tmp\boxlang-miniserver.zip -DestinationPath $INSTALLATION_FOLDER -Force -ErrorAction Stop
}
catch {
    Write-Host -ForegroundColor Red "❌ Error: Failed to extract BoxLang MiniServer archive"
    Write-Host -ForegroundColor Red $_.Exception.Message
    exit 1
}
Write-Host -ForegroundColor Green "📦 Unzipping BoxLang Quick Installer"
try {
    Expand-Archive -Path $tmp\boxlang-installer.zip -DestinationPath $DESTINATION_BIN -Force -ErrorAction Stop
}
catch {
    Write-Host -ForegroundColor Red "❌ Error: Failed to extract BoxLang Quick Installer archive"
    Write-Host -ForegroundColor Red $_.Exception.Message
    exit 1
}

# Create Aliases
Write-Host -ForegroundColor Blue "🔗 Creating symbolic links for executables..."
try {
    Remove-Item -Force -ErrorAction SilentlyContinue -Path $INSTALLATION_FOLDER\bin\bx.bat | Out-Null
    New-Item -ItemType SymbolicLink -Target $INSTALLATION_FOLDER\bin\boxlang.bat -Path $INSTALLATION_FOLDER\bin\bx.bat | Out-Null

    Remove-Item -Force -ErrorAction SilentlyContinue -Path $INSTALLATION_FOLDER\bin\bx-miniserver.bat | Out-Null
    New-Item -ItemType SymbolicLink -Target $INSTALLATION_FOLDER\bin\boxlang-miniserver.bat -Path $INSTALLATION_FOLDER\bin\bx-miniserver.bat | Out-Null
}
catch {
    Write-Host -ForegroundColor Red "Oh no! We weren't able to setup symlinks for the executables."
    Write-Host -ForegroundColor Red "BoxLang will still run but you will not have the 'bx' and 'bx-miniserver' aliases."
}

# Install CommandBox
Check-And-Install-CommandBox -BinDir $DESTINATION_BIN

## Add the bin folder to the path
Update-PathVariable -BinDir $DESTINATION_BIN

## Create a BOXLANG_HOME env variable that points to the $DESTINATION_HOME
Write-Host -ForegroundColor Green "🏠 Setting the BOXLANG_HOME environment variable to [$DESTINATION_HOME]"
[Environment]::SetEnvironmentVariable(
	"BOXLANG_HOME",
	$DESTINATION_HOME,
	[EnvironmentVariableTarget]::User) | Out-Null

## Clean up
Write-Host -ForegroundColor Green "🧹 Cleaning up..."
Remove-Item -Force -ErrorAction SilentlyContinue -Path $tmp -Recurse | Out-Null

## Verify installation
Test-Installation -BinDir $DESTINATION_BIN

## Finalization
Write-Host -ForegroundColor Green ''
Write-Host -ForegroundColor Green "$bxName Binaries are now installed to [$DESTINATION_BIN]"
Write-Host -ForegroundColor Green "$bxName JARs are now installed to [$DESTINATION_LIB]"
Write-Host -ForegroundColor Green "$bxName Home is now set to [$DESTINATION_HOME]"
Write-Host -ForegroundColor Green ''
Write-Host -ForegroundColor Green 'Your [BOXLANG_HOME] is set to the BoxLang installation directory.'
Write-Host -ForegroundColor Green 'You can change this by setting the [BOXLANG_HOME] environment variable in your shell profile'
Write-Host -ForegroundColor Green 'Just copy the following line to override the location if you want'
Write-Host -ForegroundColor Green ''
Write-Host -ForegroundColor Green "`$env:BOXLANG_HOME=`"C:\new\home`""
Write-Host -ForegroundColor Green ''
Write-Host -ForegroundColor Green "You can start a MiniServer by running: boxlang-miniserver"
Write-Host -ForegroundColor Green "You can use the Package Manager by running: box (if CommandBox was installed)"
Write-Host -ForegroundColor Green '*************************************************************************'
Write-Host -ForegroundColor Green "$bxName - Dynamic : Modular : Productive : https://boxlang.io"
Write-Host -ForegroundColor Green '*************************************************************************'
Write-Host -ForegroundColor Green "$bxName is FREE and Open-Source Software under the Apache 2.0 License"
Write-Host -ForegroundColor Green "You can also buy support and enhanced versions at https://boxlang.io/plans"
Write-Host -ForegroundColor Green 'p.s. Follow us at https://x.com/tryboxlang'
Write-Host -ForegroundColor Green 'p.p.s. Clone us and star us at https://github.com/ortus-boxlang/boxlang'
Write-Host -ForegroundColor Green 'Please support us via Patreon at https://www.patreon.com/ortussolutions'
Write-Host -ForegroundColor Green '*************************************************************************'
Write-Host -ForegroundColor Green "Copyright and Registered Trademarks of Ortus Solutions, Corp"
