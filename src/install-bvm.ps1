# BVM (BoxLang Version Manager) Installer
# This script installs BVM and sets up the environment
# Author: BoxLang Team
# Version: @build.version@
# License: Apache License, Version 2.0

# Ensure console supports UTF-8 for emojis
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Global variables
$BVM_HOME = if ($env:BVM_HOME) { 
    $env:BVM_HOME 
} else { 
    $homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
    Join-Path $homeDir ".bvm" 
}
$INSTALLER_URL = "https://downloads.ortussolutions.com/ortussolutions/boxlang-quick-installer/boxlang-installer.zip"

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
    Write-Host -ForegroundColor Cyan "📦 $Message"
}

function Test-Command {
    param([string]$CommandName)
    return [bool](Get-Command $CommandName -ErrorAction SilentlyContinue)
}

###########################################################################
# Preflight Checks
###########################################################################
function Test-Prerequisites {
    Write-Info "Running pre-flight checks..."
    
    $missingDeps = @()
    
    # Check PowerShell version
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
        Write-Warning "Could not verify internet connectivity"
    }
    
    if ($missingDeps.Count -gt 0) {
        Write-Error "Missing required dependencies: $($missingDeps -join ', ')"
        return $false
    }
    
    Write-Success "All prerequisites satisfied"
    return $true
}

###########################################################################
# Install BVM
###########################################################################
function Install-BVM {
    # Create BVM directory structure
    Write-Info "Creating BVM directory at [$BVM_HOME]"
    
    $directories = @(
        "$BVM_HOME\bin",
        "$BVM_HOME\versions", 
        "$BVM_HOME\cache",
        "$BVM_HOME\scripts"
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    
    $scriptsDir = "$BVM_HOME\scripts"
    $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) "boxlang-installer.zip"
    
    ###########################################################################
    # Download BoxLang Installer Scripts
    ###########################################################################
    Write-Info "Downloading BVM from [$INSTALLER_URL]"
    try {
        Invoke-WebRequest -Uri $INSTALLER_URL -OutFile $tempFile
    }
    catch {
        Write-Error "Error: Download of BoxLang® Installer bundle failed"
        Write-Error $_.Exception.Message
        return $false
    }
    
    ###########################################################################
    # Extract installer scripts
    ###########################################################################
    Write-Info "Inflating BoxLang installer scripts..."
    try {
        Expand-Archive -Path $tempFile -DestinationPath $scriptsDir -Force
    }
    catch {
        Write-Error "Error: Failed to extract BoxLang installer scripts"
        Write-Error $_.Exception.Message
        return $false
    }
    finally {
        # Clean up temp file
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
    
    ###########################################################################
    # Create internal links within BVM home
    ###########################################################################
    Write-Info "Creating internal links for BoxLang scripts..."
    
    # Create batch wrappers that call the PowerShell scripts
    $wrapperScripts = @{
        "install-bx-module" = "install-bx-module.ps1"
        "install-bx-site" = "install-bx-site.sh"  # This one stays as shell script for now
        "install-bvm" = "install-bvm.ps1"
        "bvm" = "bvm.ps1"
    }
    
    foreach ($wrapper in $wrapperScripts.GetEnumerator()) {
        $wrapperPath = "$BVM_HOME\bin\$($wrapper.Key).bat"
        $targetScript = "$scriptsDir\$($wrapper.Value)"
        
        if ($wrapper.Value.EndsWith(".ps1")) {
            # Create batch wrapper for PowerShell scripts
            $batchContent = @"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '$targetScript' %*"
"@
        } else {
            # Create batch wrapper for shell scripts (fallback to bash)
            $batchContent = @"
@echo off
bash "$targetScript" %*
"@
        }
        
        Set-Content -Path $wrapperPath -Value $batchContent -Encoding ASCII
    }
    
    ###########################################################################
    # Create convenience wrapper scripts for direct access to BoxLang tools
    ###########################################################################
    Write-Info "Creating convenience wrapper scripts..."
    
    # Create boxlang wrapper
    $boxlangWrapper = @'
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0..\scripts\bvm.ps1' exec %*"
'@
    Set-Content -Path "$BVM_HOME\bin\boxlang.bat" -Value $boxlangWrapper -Encoding ASCII
    
    # Create bx wrapper
    $bxWrapper = @'
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0..\scripts\bvm.ps1' exec %*"
'@
    Set-Content -Path "$BVM_HOME\bin\bx.bat" -Value $bxWrapper -Encoding ASCII
    
    # Create boxlang-miniserver wrapper
    $miniServerWrapper = @'
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0..\scripts\bvm.ps1' miniserver %*"
'@
    Set-Content -Path "$BVM_HOME\bin\boxlang-miniserver.bat" -Value $miniServerWrapper -Encoding ASCII
    
    # Create bx-miniserver wrapper
    $bxMiniServerWrapper = @'
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0..\scripts\bvm.ps1' miniserver %*"  
'@
    Set-Content -Path "$BVM_HOME\bin\bx-miniserver.bat" -Value $bxMiniServerWrapper -Encoding ASCII
    
    Write-Success "BVM script and wrappers installed to [$BVM_HOME]"
    return $true
}

###########################################################################
# Setup PATH
###########################################################################
function Set-BVMPath {
    $bvmBin = "$BVM_HOME\bin"
    
    Write-Info "Setting up PATH for BVM..."
    
    # Check if BVM is already in PATH
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath -like "*$bvmBin*") {
        Write-Success "BVM is already in PATH"
        return $true
    }
    
    Write-Info "Adding BVM to PATH..."
    
    # Add BVM to user PATH
    $newPath = "$bvmBin;$currentPath"
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    
    # Set BVM_HOME environment variable
    [Environment]::SetEnvironmentVariable("BVM_HOME", $BVM_HOME, "User")
    
    # Update current session PATH
    $env:PATH = "$bvmBin;$env:PATH"
    $env:BVM_HOME = $BVM_HOME
    
    # Add current version to PATH if it exists
    if (Test-Path "$BVM_HOME\current") {
        $currentVersionBin = "$BVM_HOME\current\bin"
        $env:PATH = "$currentVersionBin;$env:PATH"
    }
    
    Write-Success "Added BVM to PATH"
    return $true
}

###########################################################################
# Help and Instructions  
###########################################################################
function Show-Help {
    Write-Info "To start using BVM, either:"
    Write-Host "  1. Restart your command prompt/PowerShell, or"
    Write-Host "  2. Run: `$env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'User')"
    Write-Host ""
    Write-Info "Common BVM commands:"
    Write-Host -ForegroundColor Green "  bvm install latest" -NoNewline
    Write-Host "      # Install latest BoxLang"
    Write-Host -ForegroundColor Green "  bvm use latest" -NoNewline  
    Write-Host "          # Use latest BoxLang"
    Write-Host -ForegroundColor Green "  bvm list" -NoNewline
    Write-Host "                # List installed versions"
    Write-Host -ForegroundColor Green "  bvm current" -NoNewline
    Write-Host "             # Show current version"
    Write-Host -ForegroundColor Green "  bvm help" -NoNewline
    Write-Host "                # Show help"
    Write-Host ""
    Write-Info "Direct BoxLang commands (after setup):"
    Write-Host -ForegroundColor Green "  boxlang" -NoNewline
    Write-Host " or " -NoNewline
    Write-Host -ForegroundColor Green "bx" -NoNewline
    Write-Host "              # Run BoxLang REPL"
    Write-Host -ForegroundColor Green "  boxlang-miniserver" -NoNewline
    Write-Host "      # Start MiniServer"
    Write-Host -ForegroundColor Green "  install-bx-module" -NoNewline
    Write-Host "       # Install BoxLang modules"
    Write-Host -ForegroundColor Green "  install-bx-site" -NoNewline
    Write-Host "         # Install BoxLang site templates"
    Write-Host ""
    Write-Info "Quick start:"
    Write-Host -ForegroundColor Blue "  bvm install latest && bvm use latest"
    Write-Host ""
}

###########################################################################
# Main installation function
###########################################################################
function Main {
    Write-Header "BVM (BoxLang Version Manager) Installer"
    Write-Host ""
    
    # Preflight checks
    if (-not (Test-Prerequisites)) {
        exit 1
    }
    
    # Install BVM
    if (-not (Install-BVM)) {
        exit 1
    }
    
    # Setup PATH
    if (-not (Set-BVMPath)) {
        exit 1
    }
    
    Write-Host -ForegroundColor Blue "─────────────────────────────────────────────────────────────────────────────"
    Write-Success "❤️‍🔥 BVM has been installed successfully"
    Write-Host -ForegroundColor Blue "─────────────────────────────────────────────────────────────────────────────"
    
    # Show instructions
    Show-Help
}

# Run main function
Main