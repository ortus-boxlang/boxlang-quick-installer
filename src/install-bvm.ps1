# BVM (BoxLang Version Manager) Installer for Windows
# Downloads the native BVM binary bundle from GitHub Releases and sets up the environment.
# Author: BoxLang Team
# Version: @build.version@
# License: Apache License, Version 2.0

# Ensure console supports UTF-8 for emojis
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$BVM_VERSION          = "@build.version@"
$BVM_HOME             = if ($env:BVM_HOME) { $env:BVM_HOME } else { Join-Path $env:USERPROFILE ".bvm" }
$GITHUB_RELEASES_URL  = "https://github.com/ortus-boxlang/boxlang-quick-installer/releases/latest/download"
$TOOLS_ARCHIVE        = "boxlang-tools-windows-x64.zip"

# Set the progress preference to silently continue to avoid cluttering the console
$ProgressPreference = 'SilentlyContinue'

###########################################################################
# Help Function
###########################################################################
function Show-Help {
    Write-Host -ForegroundColor Green "📦 BVM (BoxLang Version Manager) Installer v$BVM_VERSION"
    Write-Host ""
    Write-Host -ForegroundColor Yellow "This script installs BVM (BoxLang Version Manager) on your Windows system."
    Write-Host ""
    Write-Host -ForegroundColor White "Usage:"
    Write-Host "  .\install-bvm.ps1 [options]"
    Write-Host ""
    Write-Host -ForegroundColor White "Options:"
    Write-Host "  --help, -h            Show this help message"
    Write-Host "  --force               Force reinstallation even if BVM is already installed"
    Write-Host "  --yes, -y             Use defaults for all prompts (non-interactive)"
    Write-Host "  --with-jre            Automatically install Java 21 JRE if not found"
    Write-Host "  --without-jre         Skip Java installation check"
    Write-Host ""
    Write-Host -ForegroundColor White "Installation Method:"
    Write-Host ""
    Write-Host -NoNewline "  One-liner: "
    Write-Host -ForegroundColor Green "iwr -useb https://install-bvm.boxlang.io | iex"
    Write-Host ""
    Write-Host -ForegroundColor White "After Installation:"
    Write-Host ""
    Write-Host "  bvm install latest    Install the latest BoxLang version"
    Write-Host "  bvm use latest        Switch to the latest BoxLang version"
    Write-Host "  bvm list              List all installed versions"
    Write-Host "  bvm help              Show full BVM help"
    Write-Host ""
    Write-Host -ForegroundColor White "Requirements:"
    Write-Host "  - PowerShell 5.1+ or PowerShell Core 6+"
    Write-Host "  - Internet connection"
    Write-Host "  - Java 21+ (can be installed automatically with --with-jre)"
    Write-Host ""
    Write-Host -ForegroundColor White "More Information:"
    Write-Host "  Website:       https://boxlang.io"
    Write-Host "  Documentation: https://boxlang.io/docs"
    Write-Host "  GitHub:        https://github.com/ortus-boxlang/boxlang"
}

# Check for help argument
if ($args.Count -ge 1 -and ($args[0] -eq "--help" -or $args[0] -eq "-h")) {
    Show-Help
    exit 0
}

###########################################################################
# Parse Arguments
###########################################################################
$FORCE_INSTALL = $false
$NON_INTERACTIVE = $false
$INSTALL_JRE = ""  # empty = prompt, "true" = yes, "false" = skip

foreach ($arg in $args) {
    switch ($arg) {
        "--force"       { $FORCE_INSTALL = $true }
        "--yes"         { $NON_INTERACTIVE = $true }
        "-y"            { $NON_INTERACTIVE = $true }
        "--with-jre"    { $INSTALL_JRE = "true" }
        "--without-jre" { $INSTALL_JRE = "false" }
    }
}

###########################################################################
# Preflight Checks
###########################################################################
function Test-Prerequisites {
    Write-Host -ForegroundColor Blue "🔍 Running pre-flight checks..."

    $allPassed = $true

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Host -ForegroundColor Red "❌ PowerShell 5.1 or higher is required (found $($PSVersionTable.PSVersion))"
        $allPassed = $false
    } else {
        Write-Host -ForegroundColor Green "✅ PowerShell $($PSVersionTable.PSVersion) found"
    }

    # Check internet connectivity
    try {
        $null = Invoke-WebRequest -Uri "https://downloads.ortussolutions.com" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        Write-Host -ForegroundColor Green "✅ Internet connectivity confirmed"
    }
    catch {
        Write-Host -ForegroundColor Yellow "⚠️  Could not verify internet connectivity - downloads may fail"
    }

    return $allPassed
}

###########################################################################
# Java Check
###########################################################################
function Test-JavaVersion {
    param([bool]$AutoInstall = $false)

    Write-Host -ForegroundColor Blue "🔍 Checking Java installation..."

    $requiredVersion = 21
    $javaCandidates = @(
        "java",
        "$env:JAVA_HOME\bin\java.exe",
        "C:\Program Files\Java\*\bin\java.exe",
        "$env:ProgramFiles\Eclipse Adoptium\*\bin\java.exe",
        "$env:ProgramFiles\Microsoft\jdk-*\bin\java.exe"
    )

    foreach ($candidate in $javaCandidates) {
        try {
            if (Get-Command $candidate -ErrorAction SilentlyContinue) {
                $versionOutput = & $candidate -version 2>&1 | Out-String
                if ($versionOutput -match '(\d+)\.') {
                    $majorVersion = [int]$matches[1]
                } elseif ($versionOutput -match '1\.(\d+)\.') {
                    $majorVersion = [int]$matches[1]
                } else {
                    continue
                }

                if ($majorVersion -ge $requiredVersion) {
                    Write-Host -ForegroundColor Green "✅ Java $majorVersion found"
                    return $true
                } else {
                    Write-Host -ForegroundColor Yellow "⚠️  Java $majorVersion found but Java $requiredVersion+ is required"
                }
            }
        }
        catch { }
    }

    Write-Host -ForegroundColor Yellow "⚠️  Java $requiredVersion+ not found"
    Write-Host -ForegroundColor Blue "💡 Java $requiredVersion+ is required to run BoxLang"
    Write-Host "   Download from: https://adoptium.net/ or https://www.microsoft.com/openjdk"
    return $false
}

###########################################################################
# Install BVM – downloads native binary bundle from GitHub Releases
###########################################################################
function Install-BVM {
    $binDir      = Join-Path $BVM_HOME "bin"
    $versionsDir = Join-Path $BVM_HOME "versions"
    $cacheDir    = Join-Path $BVM_HOME "cache"
    $tempDir     = [System.IO.Path]::GetTempPath()
    $zipPath     = Join-Path $tempDir $TOOLS_ARCHIVE
    $downloadUrl = "$GITHUB_RELEASES_URL/$TOOLS_ARCHIVE"

    # Create BVM directories
    Write-Host -ForegroundColor Blue "📁 Creating BVM directories at [$BVM_HOME]..."
    foreach ($dir in @($binDir, $versionsDir, $cacheDir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    # Download native tool binaries archive
    Write-Host -ForegroundColor Blue "⬇️  Downloading BoxLang tools from [$downloadUrl]..."
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
    }
    catch {
        Write-Host -ForegroundColor Red "❌ Failed to download tools archive: $($_.Exception.Message)"
        Write-Host -ForegroundColor Blue "   Check: https://github.com/ortus-boxlang/boxlang-quick-installer/releases/latest"
        return $false
    }

    # Extract native binaries to ~/.bvm/bin/
    Write-Host -ForegroundColor Blue "📦 Extracting native binaries to [$binDir]..."
    try {
        Expand-Archive -Path $zipPath -DestinationPath $binDir -Force -ErrorAction Stop
    }
    catch {
        Write-Host -ForegroundColor Red "❌ Extraction failed: $($_.Exception.Message)"
        return $false
    }

    # Clean up temp archive
    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue

    Write-Host -ForegroundColor Green "✅ BVM and tools installed to [$BVM_HOME\bin]"
    return $true
}

###########################################################################
# Setup PATH
###########################################################################
function Add-BvmToPath {
    $binDir = Join-Path $BVM_HOME "bin"

    Write-Host -ForegroundColor Blue "🔧 Setting up PATH for BVM..."

    $currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)

    if ($currentPath -like "*$binDir*") {
        Write-Host -ForegroundColor Green "✅ $binDir is already in your PATH"
        return
    }

    Write-Host -ForegroundColor Yellow "⚠️  $binDir is not in your PATH"

    $shouldAdd = $false
    if ($NON_INTERACTIVE) {
        $shouldAdd = $true
    } else {
        $response = Read-Host "Would you like to add BVM to your PATH automatically? [Y/n]"
        $shouldAdd = ($response -notmatch "^[nN]")
    }

    if ($shouldAdd) {
        $newPath = if ($currentPath) { "$currentPath;$binDir" } else { $binDir }
        [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)
        # Also update the current session
        $env:Path = "$env:Path;$binDir"
        Write-Host -ForegroundColor Green "✅ Added [$binDir] to User PATH"
        Write-Host -ForegroundColor Blue "💡 Restart your terminal for the PATH change to take effect"
    } else {
        Write-Host -ForegroundColor Yellow "Skipped automatic PATH update"
        Write-Host -ForegroundColor Blue "💡 Manually add the following to your PATH:"
        Write-Host "   $binDir"
    }
}

###########################################################################
# Main
###########################################################################

Write-Host -ForegroundColor Blue "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host -ForegroundColor Green "📦 BVM (BoxLang Version Manager) Installer v$BVM_VERSION"
Write-Host -ForegroundColor Blue "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""

# Check if already installed (unless force)
if ((Test-Path (Join-Path $BVM_HOME "bin\bvm.exe")) -and -not $FORCE_INSTALL) {
    Write-Host -ForegroundColor Yellow "⚠️  BVM is already installed at [$BVM_HOME]"
    Write-Host -ForegroundColor Blue "💡 Use --force to reinstall, or run 'bvm check-update' to update."
    exit 0
}

# Preflight checks
if (-not (Test-Prerequisites)) {
    exit 1
}

# Java check
if ($INSTALL_JRE -ne "false") {
    $javaOk = Test-JavaVersion
    if (-not $javaOk) {
        if ($INSTALL_JRE -eq "true" -or $NON_INTERACTIVE) {
            Write-Host -ForegroundColor Blue "💡 Java not found. Please install Java 21+ manually and re-run this installer."
            Write-Host "   Download: https://adoptium.net/"
        } else {
            Write-Host -ForegroundColor Yellow "⚠️  Continuing without Java - BoxLang will not run until Java 21+ is installed"
        }
    }
} else {
    Write-Host -ForegroundColor Yellow "⏩ Skipping Java check (--without-jre specified)"
}

# Install BVM
Write-Host ""
if (-not (Install-BVM)) {
    Write-Host -ForegroundColor Red "❌ BVM installation failed"
    exit 1
}

# Setup PATH
Write-Host ""
Add-BvmToPath

# Done
Write-Host ""
Write-Host -ForegroundColor Blue "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host -ForegroundColor Green "❤️‍🔥 BVM has been installed successfully!"
Write-Host -ForegroundColor Blue "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
Write-Host -ForegroundColor White "To start using BVM:"
Write-Host "  1. Restart your PowerShell/terminal, or"
Write-Host "  2. Run: `$env:Path = `"$BVM_HOME\bin;`$env:Path`""
Write-Host ""
Write-Host -ForegroundColor White "Common BVM commands:"
Write-Host -ForegroundColor Green "  bvm install latest" -NoNewline; Write-Host "      # Install latest BoxLang"
Write-Host -ForegroundColor Green "  bvm use latest" -NoNewline;     Write-Host "          # Use latest BoxLang"
Write-Host -ForegroundColor Green "  bvm list" -NoNewline;           Write-Host "               # List installed versions"
Write-Host -ForegroundColor Green "  bvm current" -NoNewline;        Write-Host "            # Show current version"
Write-Host -ForegroundColor Green "  bvm help" -NoNewline;           Write-Host "               # Show full help"
Write-Host ""
Write-Host -ForegroundColor White "Quick start:"
Write-Host -ForegroundColor Blue "  bvm install latest && bvm use latest"
Write-Host ""
Write-Host -ForegroundColor Green "BoxLang© - Dynamic : Modular : Productive : https://boxlang.io"
