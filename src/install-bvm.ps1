# BVM (BoxLang Version Manager) Installer for Windows
# Description: This script installs BVM and sets up the environment on Windows.
# Author: BoxLang Team
# Version: @build.version@
# License: Apache License, Version 2.0

# Ensure console supports UTF-8 for emojis
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$BVM_VERSION = "@build.version@"
$BVM_HOME = if ($env:BVM_HOME) { $env:BVM_HOME } else { Join-Path $env:USERPROFILE ".bvm" }
$INSTALLER_URL = "https://downloads.ortussolutions.com/ortussolutions/boxlang-quick-installer/boxlang-installer.zip"
$BVM_SCRIPT_URL = "https://downloads.ortussolutions.com/ortussolutions/boxlang-quick-installer/bvm.ps1"

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
# Create Wrapper Batch Files in BVM bin
###########################################################################
function New-WrapperScript {
    param(
        [string]$BinDir,
        [string]$Name,
        [string]$BvmCommand
    )

    $batContent = @"
@echo off
setlocal
if not defined BVM_HOME set "BVM_HOME=%USERPROFILE%\.bvm"
set "BVM_PS1=%BVM_HOME%\scripts\bvm.ps1"
if not exist "%BVM_PS1%" (
    echo Error: BVM not found. Please reinstall BVM.
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%BVM_PS1%' $BvmCommand %*"
"@

    $batPath = Join-Path $BinDir "$Name.bat"
    Set-Content -Path $batPath -Value $batContent -Encoding ASCII
}

###########################################################################
# Install BVM
###########################################################################
function Install-BVM {
    $binDir     = Join-Path $BVM_HOME "bin"
    $versionsDir = Join-Path $BVM_HOME "versions"
    $cacheDir   = Join-Path $BVM_HOME "cache"
    $scriptsDir = Join-Path $BVM_HOME "scripts"
    $tempDir    = [System.IO.Path]::GetTempPath()
    $zipPath    = Join-Path $tempDir "boxlang-installer.zip"

    # Create BVM directories
    Write-Host -ForegroundColor Blue "📁 Creating BVM directories at [$BVM_HOME]..."
    foreach ($dir in @($binDir, $versionsDir, $cacheDir, $scriptsDir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    # Download BoxLang installer bundle (contains all helper scripts)
    Write-Host -ForegroundColor Blue "⬇️  Downloading BVM installer bundle from [$INSTALLER_URL]..."
    try {
        Invoke-WebRequest -Uri $INSTALLER_URL -OutFile $zipPath -ErrorAction Stop
    }
    catch {
        Write-Host -ForegroundColor Red "❌ Failed to download installer bundle: $($_.Exception.Message)"
        return $false
    }

    # Extract scripts to ~/.bvm/scripts/
    Write-Host -ForegroundColor Blue "📦 Extracting helper scripts to [$scriptsDir]..."
    try {
        Expand-Archive -Path $zipPath -DestinationPath $scriptsDir -Force -ErrorAction Stop
    }
    catch {
        Write-Host -ForegroundColor Red "❌ Failed to extract installer bundle: $($_.Exception.Message)"
        return $false
    }

    # Download bvm.ps1 directly to ~/.bvm/scripts/
    Write-Host -ForegroundColor Blue "⬇️  Downloading bvm.ps1 from [$BVM_SCRIPT_URL]..."
    $bvmPs1Path = Join-Path $scriptsDir "bvm.ps1"
    try {
        Invoke-WebRequest -Uri $BVM_SCRIPT_URL -OutFile $bvmPs1Path -ErrorAction Stop
    }
    catch {
        Write-Host -ForegroundColor Red "❌ Failed to download bvm.ps1: $($_.Exception.Message)"
        return $false
    }

    # Create bvm.bat in bin dir (main entry point)
    Write-Host -ForegroundColor Blue "🔗 Creating BVM entry point scripts in [$binDir]..."
    $bvmBatContent = @"
@echo off
setlocal
if not defined BVM_HOME set "BVM_HOME=%USERPROFILE%\.bvm"
set "BVM_PS1=%BVM_HOME%\scripts\bvm.ps1"
if not exist "%BVM_PS1%" (
    echo Error: BVM script not found at %BVM_PS1%
    echo Please reinstall BVM using: iwr -useb https://install-bvm.boxlang.io/install-bvm.ps1 ^| iex
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%BVM_PS1%'" -- %*
"@
    Set-Content -Path (Join-Path $binDir "bvm.bat") -Value $bvmBatContent -Encoding ASCII

    # Create direct bvm.ps1 wrapper in bin (for PS users who call bvm.ps1 directly)
    $bvmPs1Wrapper = @"
# BVM Wrapper - redirects to the actual bvm.ps1
`$BvmHome = if (`$env:BVM_HOME) { `$env:BVM_HOME } else { Join-Path `$env:USERPROFILE ".bvm" }
`$BvmScript = Join-Path `$BvmHome "scripts\bvm.ps1"
if (-not (Test-Path `$BvmScript)) {
    Write-Host -ForegroundColor Red "Error: BVM script not found at `$BvmScript"
    Write-Host -ForegroundColor Blue "Please reinstall BVM using: iwr -useb https://install-bvm.boxlang.io | iex"
    exit 1
}
& `$BvmScript @args
"@
    Set-Content -Path (Join-Path $binDir "bvm.ps1") -Value $bvmPs1Wrapper -Encoding UTF8

    # Create convenience wrapper batch files for direct tool access
    Write-Host -ForegroundColor Blue "🔗 Creating convenience wrapper scripts..."

    # boxlang.bat / bx.bat - run BoxLang via BVM
    $boxlangBat = @"
@echo off
setlocal
if not defined BVM_HOME set "BVM_HOME=%USERPROFILE%\.bvm"
set "BVM_PS1=%BVM_HOME%\scripts\bvm.ps1"
if not exist "%BVM_PS1%" (
    echo Error: BVM not found. Please reinstall BVM.
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%BVM_PS1%' exec %*"
"@
    Set-Content -Path (Join-Path $binDir "boxlang.bat") -Value $boxlangBat -Encoding ASCII
    Set-Content -Path (Join-Path $binDir "bx.bat") -Value $boxlangBat -Encoding ASCII

    # boxlang-miniserver.bat / bx-miniserver.bat - run MiniServer via BVM
    $miniServerBat = @"
@echo off
setlocal
if not defined BVM_HOME set "BVM_HOME=%USERPROFILE%\.bvm"
set "BVM_PS1=%BVM_HOME%\scripts\bvm.ps1"
if not exist "%BVM_PS1%" (
    echo Error: BVM not found. Please reinstall BVM.
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%BVM_PS1%' miniserver %*"
"@
    Set-Content -Path (Join-Path $binDir "boxlang-miniserver.bat") -Value $miniServerBat -Encoding ASCII
    Set-Content -Path (Join-Path $binDir "bx-miniserver.bat") -Value $miniServerBat -Encoding ASCII

    # install-bx-module.bat - link to helper script
    $installModuleBat = @"
@echo off
setlocal
if not defined BVM_HOME set "BVM_HOME=%USERPROFILE%\.bvm"
set "PS1_SCRIPT=%BVM_HOME%\scripts\install-bx-module.ps1"
if not exist "%PS1_SCRIPT%" (
    echo Error: install-bx-module.ps1 not found. Please reinstall BVM.
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%PS1_SCRIPT%' %*"
"@
    Set-Content -Path (Join-Path $binDir "install-bx-module.bat") -Value $installModuleBat -Encoding ASCII

    # install-bvm.bat - self-updater
    $installBvmBat = @"
@echo off
setlocal
if not defined BVM_HOME set "BVM_HOME=%USERPROFILE%\.bvm"
set "PS1_SCRIPT=%BVM_HOME%\scripts\install-bvm.ps1"
if not exist "%PS1_SCRIPT%" (
    echo Error: install-bvm.ps1 not found. Please reinstall BVM.
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%PS1_SCRIPT%' %*"
"@
    Set-Content -Path (Join-Path $binDir "install-bvm.bat") -Value $installBvmBat -Encoding ASCII

    # Clean up temp zip
    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue

    Write-Host -ForegroundColor Green "✅ BVM scripts and wrappers installed to [$BVM_HOME]"
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
if ((Test-Path (Join-Path $BVM_HOME "bin\bvm.bat")) -and -not $FORCE_INSTALL) {
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
