# BVM (BoxLang Version Manager) Installer for Windows
# Description: This script installs BVM and sets up the environment on Windows.
# Author: BoxLang Team
# Version: @build.version@
# License: Apache License, Version 2.0

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$BVM_VERSION = "@build.version@"
$BVM_HOME = if ($env:BVM_HOME) { $env:BVM_HOME } else { Join-Path $env:USERPROFILE ".bvm" }
$INSTALLER_URL = "https://downloads.ortussolutions.com/ortussolutions/boxlang-quick-installer/boxlang-installer.zip"
$BVM_SCRIPT_URL = "https://downloads.ortussolutions.com/ortussolutions/boxlang-quick-installer/bvm.ps1"
$PRODUCT_URL = "https://boxlang.io/"

$script:NonInteractive = $false
$script:Verbose = $false
$script:Force = $false
$script:Upgrade = $false
$script:WithJava = "auto"
$script:WithShell = $true
$script:Runtime = "latest"
$script:Interactive = $false
$script:WarningCount = 0
$script:LogFile = ""
$script:TempDir = ""
$script:JavaOk = $false

$RESET = ""; $BOLD = ""; $DIM = ""; $ACCENT = ""; $SUCCESS = ""; $WARNING = ""; $ERROR_COLOR = ""
$LAYER_ONE = ""; $LAYER_TWO = ""
if (-not $env:NO_COLOR -and $Host.Name -eq "ConsoleHost") {
    $esc = [char]27
    $RESET = "$esc[0m"; $BOLD = "$esc[1m"; $DIM = "$esc[2m"
    $ACCENT = "$esc[36m"; $SUCCESS = "$esc[32m"; $WARNING = "$esc[33m"; $ERROR_COLOR = "$esc[31m"
    $LAYER_ONE = "$esc[34m"; $LAYER_TWO = "$esc[35m"
}

###########################################################################
# Output helpers
###########################################################################

function Write-Info {
    param([string]$Text)
    Write-Host "  ${SUCCESS}✓${RESET}  $Text"
}

function Write-Note {
    param([string]$Text)
    Write-Host "  ${WARNING}!${RESET}  $Text"
}

function Write-Warn {
    param([string]$Text)
    $script:WarningCount++
    Write-Note $Text
    if ($script:LogFile) { Add-Content -Path $script:LogFile -Value "warning: $Text" }
}

function Write-Die {
    param([string]$Text)
    Write-Host "  ${ERROR_COLOR}×${RESET}  $Text" -ErrorAction Continue
    if ($script:LogFile) { Add-Content -Path $script:LogFile -Value "error: $Text" }
    throw $Text
}

function Write-Section {
    param([string]$Text)
    Write-Host ""
    Write-Host "  ${ACCENT}${BOLD}${Text}${RESET}"
    Write-Host ""
}

function Show-Banner {
    $logo = @(
        '             ⠈⠑⠲⣤⡀      '
        '        ⢀⣴⣿⣿⣷⣦⣄ ⠈⠻⣷⣄    '
        '      ⢠⣾⣿⣿⣿⣿⣿⣿⣿⣷⡄ ⠈⢿⣷⡄  '
        '        ⠈⠙⠻⣿⣿⣿⣿⣿⣿⡆ ⠘⣿⣿⡄ '
        '           ⠈⢿⣿⣿⣿⣿⣿  ⢻⣿⣿ '
        '            ⠸⣿⣿⣿⣿⣿  ⣸⣿⣿⡆'
        '            ⢠⣿⣿⣿⣿⡏  ⣿⣿⣿⠇'
        '            ⣼⣿⣿⣿⠏  ⣼⣿⣿⡿ '
        '         ⢀⣠⣾⣿⡿⠟⠁ ⢀⣾⣿⣿⣿⠃ '
        '⢠⣿⣿⠄    ⠚⠛⠛⠉⠁ ⢀⣠⣶⣿⣿⣿⡿⠁  '
        ' ⠉⠉⢾⣿⣶⣦⣤⣤⣤⣤⣤⣶⣾⣿⣿⣿⣿⠿⠋    '
        '    ⠈⠛⠻⠿⣿⣿⣿⣿⣿⣿⠿⠟⠋⠁      '
    )
    $text = @(
        ''
        'B O X L A N G'
        ''
        'The software productivity platform'
        ''
        'www.boxlang.io'
        ''
        ''
        'BoxLang Version Manager (BVM)'
        ''
        ''
        ''
    )

    Write-Host ""
    if (-not $env:NO_COLOR -and $Host.Name -eq "ConsoleHost") {
        $esc = [char]27
        $gradient = @(
    "${esc}[38;2;0;219;255m"
    "${esc}[38;2;0;221;249m"
    "${esc}[38;2;0;222;243m"
    "${esc}[38;2;0;224;237m"
    "${esc}[38;2;0;225;231m"
    "${esc}[38;2;0;227;225m"
    "${esc}[38;2;0;228;219m"
    "${esc}[38;2;0;230;213m"
    "${esc}[38;2;0;232;207m"
    "${esc}[38;2;0;233;201m"
    "${esc}[38;2;0;235;195m"
    "${esc}[38;2;0;236;189m"
    "${esc}[38;2;0;238;183m"
    "${esc}[38;2;0;239;177m"
    "${esc}[38;2;0;241;171m"
    "${esc}[38;2;0;242;165m"
    "${esc}[38;2;0;244;159m"
    "${esc}[38;2;0;246;153m"
    "${esc}[38;2;0;247;147m"
    "${esc}[38;2;0;249;141m"
    "${esc}[38;2;0;250;135m"
    "${esc}[38;2;0;252;129m"
    "${esc}[38;2;0;253;123m"
    "${esc}[38;2;0;255;117m"
        )
        for ($y = 0; $y -lt $logo.Count; $y++) {
            $line = ""
            $plain = $logo[$y]
            for ($x = 0; $x -lt $plain.Length; $x++) {
                $ch = $plain[$x]
                if ($ch -eq ' ') { $line += ' ' } else { $line += $gradient[$x] + $ch }
            }
            if ($text[$y]) {
                if ($y -eq 1) { $label = "  ${BOLD}${ACCENT}$($text[$y])${RESET}" }
                else { $label = "  ${SUCCESS}$($text[$y])${RESET}" }
            } else { $label = "" }
            Write-Host "$line$RESET$label"
        }
    } else {
        for ($y = 0; $y -lt $logo.Count; $y++) {
            if ($text[$y]) { Write-Host "$($logo[$y])  $($text[$y])" } else { Write-Host $logo[$y] }
        }
    }
    Write-Host ""
}

function Show-SystemLine {
    $architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    $assetArchitecture = if ($architecture -eq "Arm64") { "arm64" } else { "x64" }
    Write-Host "  ${DIM}Windows · windows-$assetArchitecture${RESET}"
}

###########################################################################
# Menus
###########################################################################

function Select-Menu {
    param(
        [string]$Title,
        [string[]]$Labels,
        [string[]]$Hints,
        [bool]$Multiple = $false,
        [bool[]]$Choices
    )

    if (-not $Choices -or $Choices.Count -ne $Labels.Count) {
        $Choices = @(for ($i = 0; $i -lt $Labels.Count; $i++) { $false })
    }

    if (-not $script:Interactive) {
        Write-Section $Title
        for ($i = 0; $i -lt $Labels.Count; $i++) {
            Write-Host "  $($i + 1): $($Labels[$i])"
            Write-Host "      $($Hints[$i])"
        }
        if ($Multiple) {
            $answer = Read-Host "Toggle an option by number; Enter to continue, q to cancel"
        } else {
            $answer = Read-Host "Choose [1], or q to cancel"
        }
        if ($answer -match '^[qQ]') { throw "Installation cancelled. No changes made." }
        if ([string]::IsNullOrWhiteSpace($answer)) {
            if (-not $Multiple) { $Choices[0] = $true }
            return $Choices
        }
        foreach ($part in ($answer -split '[ ,;]+')) {
            if ($part -match '^\d+$') {
                $index = [int]$part - 1
                if ($index -ge 0 -and $index -lt $Labels.Count) {
                    if ($Multiple) { $Choices[$index] = -not $Choices[$index] } else { $Choices[$index] = $true; return $Choices }
                }
            }
        }
        return $Choices
    }

    $active = 0
    $origin = $Host.UI.RawUI.CursorPosition
    function Draw-Menu {
        $Host.UI.RawUI.CursorPosition = $origin
        $lines = @("  ${BOLD}${ACCENT}${Title}${RESET}", "")
        for ($i = 0; $i -lt $Labels.Count; $i++) {
            $marker = " "
            $color = $RESET
            if ($i -eq $active) { $marker = "›"; $color = "$ACCENT$BOLD" }
            elseif ($Multiple -and $Choices[$i]) { $color = $SUCCESS }
            if ($Multiple) {
                $check = if ($Choices[$i]) { "✓" } else { " " }
                $lines += ("  {0}{1}  [{2}] {3}{4}" -f $color, $marker, $check, $Labels[$i], $RESET)
            } else {
                $lines += ("  {0}{1}  {2}{3}" -f $color, $marker, $Labels[$i], $RESET)
            }
        }
        $lines += ""
        $lines += "  ${DIM}$($Hints[$active])${RESET}"
        $lines += ""
        if ($Multiple) {
            $lines += "  ${DIM}↑/↓ move · Space toggle · Enter install · Esc cancel${RESET}"
        } else {
            $lines += "  ${DIM}↑/↓ choose · Enter continue · Esc cancel${RESET}"
        }
        foreach ($line in $lines) { Write-Host $line.PadRight(72) }
    }

    Draw-Menu
    while ($true) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        switch ($key.VirtualKeyCode) {
            38 { $active = ($active + $Labels.Count - 1) % $Labels.Count; Draw-Menu }
            40 { $active = ($active + 1) % $Labels.Count; Draw-Menu }
            32 { if ($Multiple) { $Choices[$active] = -not $Choices[$active]; Draw-Menu } }
            13 { if (-not $Multiple) { $Choices[$active] = $true }; Draw-Menu; return $Choices }
            27 { Draw-Menu; throw "Installation cancelled. No changes made." }
        }
    }
}

###########################################################################
# Task runner
###########################################################################

function Invoke-Step {
    param([string]$Label, [scriptblock]$Command)
    Write-Host "  ${ACCENT}→${RESET}  $Label"
    if ($script:LogFile) { Add-Content -Path $script:LogFile -Value "`n--- $Label ---" }
    $global:LASTEXITCODE = 0
    $output = & $Command 2>&1 | Out-String
    if ($output.Trim()) {
        if ($script:LogFile) { Add-Content -Path $script:LogFile -Value $output }
        if ($script:Verbose) { Write-Host $output }
    }
    if ($global:LASTEXITCODE -and $global:LASTEXITCODE -ne 0) {
        Write-Host $output -ErrorAction Continue
        Write-Die "Failed: $Label"
    }
    Write-Info $Label
}

###########################################################################
# Help and arguments
###########################################################################

function Show-Help {
    Write-Host "📦 BVM (BoxLang Version Manager) Installer v$BVM_VERSION"
    Write-Host ""
    Write-Host "Without options, choose a recommended install or customize BVM setup."
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\install-bvm.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  --non-interactive          Never prompt; install the recommended set"
    Write-Host "  --yes, -y                  Alias for --non-interactive"
    Write-Host "  --verbose                  Show detailed task output"
    Write-Host "  --bvm-home PATH            Install BVM to PATH"
    Write-Host "  --with-java, --with-jre    Install Java 21+ automatically when missing"
    Write-Host "  --without-java, --without-jre  Skip Java detection and installation"
    Write-Host "  --with-shell               Configure shell initialization and PATH"
    Write-Host "  --without-shell            Leave shell profiles and PATH unchanged"
    Write-Host "  --with-runtime VERSION     Install latest, snapshot, or an exact version"
    Write-Host "  --without-runtime          Skip the BoxLang runtime install"
    Write-Host "  --force                    Force reinstallation even if BVM is installed"
    Write-Host "  --upgrade                  Internal self-update flow"
    Write-Host "  -h, --help                 Show this help"
    Write-Host ""
    Write-Host "One-liner: iwr -useb https://install-bvm.boxlang.io | iex"
    Write-Host "Requirements: PowerShell 5.1+, internet access, Java 21+ (auto-install available)"
    Write-Host "More information: https://boxlang.io"
}

function Parse-Arguments {
    param([object[]]$Arguments)
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        $arg = [string]$Arguments[$i]
        switch ($arg) {
            "--non-interactive" { $script:NonInteractive = $true }
            "--yes" { $script:NonInteractive = $true; $script:WithJava = "auto" }
            "-y" { $script:NonInteractive = $true; $script:WithJava = "auto" }
            "--verbose" { $script:Verbose = $true }
            "--force" { $script:Force = $true }
            "--upgrade" { $script:Upgrade = $true; $script:NonInteractive = $true }
            "--with-java" { $script:WithJava = "auto"; $script:NonInteractive = $true }
            "--with-jre" { $script:WithJava = "auto"; $script:NonInteractive = $true }
            "--without-java" { $script:WithJava = "skip"; $script:NonInteractive = $true }
            "--without-jre" { $script:WithJava = "skip"; $script:NonInteractive = $true }
            "--with-shell" { $script:WithShell = $true; $script:NonInteractive = $true }
            "--without-shell" { $script:WithShell = $false; $script:NonInteractive = $true }
            "--without-runtime" { $script:Runtime = "none"; $script:NonInteractive = $true }
            "-h" { Show-Help; exit 0 }
            "--help" { Show-Help; exit 0 }
            "--bvm-home" {
                if ($i + 1 -lt $Arguments.Count) { $script:BvmHomeOverride = [string]$Arguments[++$i] }
            }
            "--with-runtime" {
                if ($i + 1 -lt $Arguments.Count) { $script:Runtime = [string]$Arguments[++$i]; $script:NonInteractive = $true }
            }
            default {
                if ($arg -like "--bvm-home=*") { $script:BvmHomeOverride = $arg.Substring("--bvm-home=".Length) }
                elseif ($arg -like "--with-runtime=*") { $script:Runtime = $arg.Substring("--with-runtime=".Length); $script:NonInteractive = $true }
                else { throw "Unknown option: $arg (run with --help for usage)." }
            }
        }
    }
    if ($script:BvmHomeOverride) { $script:BVM_HOME = $script:BvmHomeOverride }
}

###########################################################################
# Installation choices and plan
###########################################################################

function Choose-Installation {
    if ($script:NonInteractive -or $script:Upgrade) { return }
    $choices = Select-Menu -Title "Choose your setup" -Labels @("Install BVM (recommended)", "Customize installation") -Hints @(
        "Everything this system supports: launchers, shell integration, Java 21+, and the latest BoxLang runtime.",
        "Choose shell integration, Java behavior, and the runtime to install."
    ) -Multiple $false
    if (-not $choices[1]) { return }

    $choices = Select-Menu -Title "Make BVM yours" -Labels @(
        "Configure shell integration and PATH",
        "Install Java 21+ if missing",
        "Install a BoxLang runtime"
    ) -Hints @(
        "Update your PowerShell profile so BVM is available in new sessions.",
        "Download a Java 21 runtime automatically when one is not installed.",
        "Install and activate a BoxLang runtime after BVM is ready."
    ) -Multiple $true -Choices @($true, $true, $true)
    $script:WithShell = [bool]$choices[0]
    $script:WithJava = if ($choices[1]) { "auto" } else { "skip" }
    $installRuntime = [bool]$choices[2]

    if (-not $installRuntime) { $script:Runtime = "none"; return }
    $choices = Select-Menu -Title "Choose a BoxLang runtime" -Labels @("Latest stable", "Snapshot", "Do not install a runtime") -Hints @(
        "Install and activate the latest stable BoxLang release.",
        "Install and activate the rolling development snapshot.",
        "Install BVM only; choose a runtime later with 'bvm install latest'."
    ) -Multiple $false
    if ($choices[1]) { $script:Runtime = "snapshot" }
    elseif ($choices[2]) { $script:Runtime = "none" }
    else { $script:Runtime = "latest" }
}

function Show-InstallationPlan {
    Write-Section "Installation plan"
    Write-Host "  Install to $script:BVM_HOME"
    Write-Host ""
    Write-Host "  ${ACCENT}+${RESET}  BVM launchers and wrappers"
    if ($script:WithShell) {
        Write-Host "  ${ACCENT}+${RESET}  Shell integration for PowerShell"
        Write-Host "  ${ACCENT}+${RESET}  Add $script:BVM_HOME\bin to PATH"
    } else {
        Write-Host ""
        Write-Host "  ${DIM}Your shell profile and PATH will stay unchanged.${RESET}"
    }
    if ($script:WithJava -eq "auto") {
        Write-Host "  ${ACCENT}+${RESET}  Install Java 21+ if missing"
    } else {
        Write-Host "  ${DIM}+  Skip Java checks${RESET}"
    }
    if ($script:Runtime -ne "none" -and -not $script:Upgrade) {
        Write-Host "  ${ACCENT}+${RESET}  Install and activate BoxLang $script:Runtime"
    }
}

###########################################################################
# Prerequisites and Java
###########################################################################

function Test-Prerequisites {
    Write-Host "Running pre-flight checks..."
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Die "PowerShell 5.1 or higher is required (found $($PSVersionTable.PSVersion))"
    }
    try {
        $null = Invoke-WebRequest -Uri "https://downloads.ortussolutions.com" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    } catch {
        Write-Die "Cannot reach downloads.ortussolutions.com. BVM requires an internet connection."
    }
}

function Get-JavaMajorVersion {
    param([string]$Command)
    try {
        $versionOutput = & $Command -version 2>&1 | Out-String
        if ($versionOutput -match '(\d+)\.') { return [int]$matches[1] }
        if ($versionOutput -match '1\.(\d+)\.') { return [int]$matches[1] }
    } catch { }
    return 0
}

function Test-JavaVersion {
    Write-Host "Checking Java installation..."
    $candidates = @(
        "java",
        "$env:JAVA_HOME\bin\java.exe",
        "C:\Program Files\Java\*\bin\java.exe",
        "$env:ProgramFiles\Eclipse Adoptium\*\bin\java.exe",
        "$env:ProgramFiles\Microsoft\jdk-*\bin\java.exe"
    )
    foreach ($candidate in $candidates) {
        if ($candidate -like "**") {
            $resolved = Get-ChildItem -Path $candidate -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $resolved) { continue }
            $command = $resolved.FullName
        } else {
            if (-not (Get-Command $candidate -ErrorAction SilentlyContinue)) { continue }
            $command = $candidate
        }
        $major = Get-JavaMajorVersion -Command $command
        if ($major -ge 21) { return $true }
    }
    Write-Host "Java not found"
    return $false
}

function Test-IsAdministrator {
    if ($IsLinux -or $IsMacOS) { return $false }
    try {
        $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Get-JreInstallerPath {
    if ($env:BVM_JRE_INSTALLER) { return $env:BVM_JRE_INSTALLER }
    $local = Join-Path $PSScriptRoot 'helpers\install-jre.ps1'
    if (Test-Path -LiteralPath $local) { return $local }
    return (Join-Path $script:BVM_HOME 'scripts\helpers\install-jre.ps1')
}

function Install-JavaRuntime {
    $installer = Get-JreInstallerPath
    if (-not (Test-Path -LiteralPath $installer)) {
        Write-Die "Java installer helper was not found at [$installer]."
    }
    $scope = if (Test-IsAdministrator) { "Machine" } else { "User" }
    & $installer -Scope $scope
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "Java installation failed with exit code $LASTEXITCODE" }
}

###########################################################################
# BVM installation
###########################################################################

function Register-PowerShellCompletions {
    param([string]$LoaderPath)
    if (-not (Test-Path $LoaderPath)) {
        Write-Note "PowerShell completions were not found at [$LoaderPath], skipping"
        return
    }
    $marker = "# BoxLang shell completions"
    try {
        $profilePath = $PROFILE.CurrentUserAllHosts
        $profileDir = Split-Path -Parent $profilePath
        if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
        if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Path $profilePath -Force | Out-Null }
        if (-not (Select-String -Path $profilePath -SimpleMatch $marker -Quiet)) {
            Add-Content -Path $profilePath -Value "`n$marker`nif (Test-Path `"$LoaderPath`") { . `"$LoaderPath`" }"
            Write-Info "Added PowerShell completions to [$profilePath]"
        }
    } catch {
        Write-Warn "Could not update your PowerShell profile: $($_.Exception.Message)"
        Write-Host "  Add this line to your profile to enable completions: . `"$LoaderPath`""
    }
}

function Install-BVM {
    $binDir = Join-Path $script:BVM_HOME "bin"
    $versionsDir = Join-Path $script:BVM_HOME "versions"
    $cacheDir = Join-Path $script:BVM_HOME "cache"
    $scriptsDir = Join-Path $script:BVM_HOME "scripts"
    $zipPath = Join-Path $script:TempDir "boxlang-installer.zip"

    foreach ($dir in @($binDir, $versionsDir, $cacheDir, $scriptsDir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    Invoke-WebRequest -Uri $INSTALLER_URL -OutFile $zipPath -UseBasicParsing
    Expand-Archive -Path $zipPath -DestinationPath $scriptsDir -Force
    Invoke-WebRequest -Uri $BVM_SCRIPT_URL -OutFile (Join-Path $scriptsDir "bvm.ps1") -UseBasicParsing

    $bvmBat = @"
@echo off
setlocal
if not defined BVM_HOME set "BVM_HOME=%USERPROFILE%\.bvm"
set "BVM_PS1=%BVM_HOME%\scripts\bvm.ps1"
if not exist "%BVM_PS1%" (
    echo Error: BVM not found. Please reinstall BVM.
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%BVM_PS1%' %*"
"@
    Set-Content -Path (Join-Path $binDir "bvm.bat") -Value $bvmBat -Encoding ASCII

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

    $bxModuleBat = @"
@echo off
setlocal
if not defined BVM_HOME set "BVM_HOME=%USERPROFILE%\.bvm"
set "PS1_SCRIPT=%BVM_HOME%\scripts\bx-module.ps1"
if not exist "%PS1_SCRIPT%" (
    echo Error: bx-module.ps1 not found. Please reinstall BVM.
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%PS1_SCRIPT%' %*"
"@
    Set-Content -Path (Join-Path $binDir "bx-module.bat") -Value $bxModuleBat -Encoding ASCII

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

    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
}

function Add-BvmToPath {
    if (-not $script:WithShell) {
        $env:Path = "$($script:BVM_HOME)\bin;$env:Path"
        return
    }
    $binDir = Join-Path $script:BVM_HOME "bin"
    $currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
    if (($currentPath -split ";") -contains $binDir) {
        Write-Info "$binDir is already in your PATH"
    } else {
        $newPath = if ($currentPath) { "$currentPath;$binDir" } else { $binDir }
        [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)
        Write-Info "Added [$binDir] to User PATH"
    }
    if (($env:Path -split ";") -notcontains $binDir) { $env:Path = "$binDir;$env:Path" }

    $env:BVM_HOME = $script:BVM_HOME
    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileDir = Split-Path -Parent $profilePath
    if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
    if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Path $profilePath -Force | Out-Null }
    $marker = "# BVM (BoxLang Version Manager) shell initialization"
    if (-not (Select-String -Path $profilePath -SimpleMatch $marker -Quiet)) {
        Add-Content -Path $profilePath -Value "`n$marker`n`$env:BVM_HOME = '$($script:BVM_HOME)'"
    }
    Register-PowerShellCompletions -LoaderPath (Join-Path $script:BVM_HOME "scripts\completions\load.ps1")
}

function Install-Runtime {
    $scriptPath = Join-Path $script:BVM_HOME "scripts\bvm.ps1"
    & $scriptPath install $script:Runtime
    & $scriptPath use $script:Runtime
}

function Show-Summary {
    Write-Info "BVM $BVM_VERSION is installed."
    Write-Host ""
    Write-Host "  ${BOLD}To use BVM in this terminal:${RESET}"
    Write-Host "    . `$PROFILE"
    Write-Host ""
    Write-Host "  ${BOLD}Quick start:${RESET}"
    Write-Host "    bvm install latest"
    Write-Host "    bvm use latest"
    Write-Host "    boxlang --version"
    Write-Host ""
    Write-Host "  ${DIM}Learn more: ${PRODUCT_URL}${RESET}"
    Write-Host ""
}

###########################################################################
# Main
###########################################################################

function Invoke-Main {
    param([object[]]$ScriptArgs)
    Parse-Arguments -Arguments $ScriptArgs
    $script:Interactive = -not $script:NonInteractive -and [Environment]::UserInteractive -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected

    Show-Banner
    Show-SystemLine

    if ((Test-Path (Join-Path $script:BVM_HOME "bin\bvm.bat")) -and -not $script:Force -and -not $script:Upgrade) {
        Write-Note "BVM is already installed at [$script:BVM_HOME]"
        Write-Host "  Use --force to reinstall, or run 'bvm check-update' to update."
        exit 0
    }

    Choose-Installation
    Show-InstallationPlan

    $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("bvm-install-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    $script:LogFile = Join-Path $script:TempDir "install.log"
    New-Item -ItemType File -Path $script:LogFile -Force | Out-Null

    Write-Section "Installing BVM"

    Invoke-Step "Verified installer prerequisites" { Test-Prerequisites }

    if ($script:WithJava -eq "skip") {
        Write-Note "Skipping Java check. BoxLang will not run until Java 21+ is installed."
    } else {
        Invoke-Step "Verified Java 21+" { $script:JavaOk = Test-JavaVersion }
        if (-not $script:JavaOk) {
            Invoke-Step "Installed Java 21+" { Install-JavaRuntime }
            $script:JavaOk = $true
        }
        if (-not $script:JavaOk) { throw "Java 21+ is unavailable." }
    }

    Invoke-Step "Installed BVM scripts and wrappers" { Install-BVM }
    Invoke-Step "Configured shell integration" { Add-BvmToPath }

    if ($script:Runtime -ne "none" -and -not $script:Upgrade) {
        if ($script:JavaOk) {
            Invoke-Step "Downloaded and installed BoxLang $script:Runtime" { Install-Runtime }
        } else {
            Write-Warn "Java 21+ is unavailable; skipped the BoxLang runtime install."
            Write-Host "  Install it later with: bvm install latest && bvm use latest"
        }
    }

    if ($script:WarningCount -gt 0) { Write-Section "Installed with warnings" }
    else { Write-Section "Ready to explore" }
    Show-Summary

    if ($script:WarningCount -eq 0) {
        Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "  ${DIM}Detailed output: $($script:LogFile)${RESET}"
    }
    exit 0
}

if ($env:BVM_INSTALLER_TESTING -ne "1") {
    try {
        Invoke-Main -ScriptArgs $args
    } catch {
    Write-Host "  ${ERROR_COLOR}×${RESET}  Installation did not finish." -ErrorAction Continue
    Write-Host "  $($_.Exception.Message)" -ErrorAction Continue
    if ($script:LogFile -and (Test-Path $script:LogFile)) {
        Write-Host "  Detailed output: $($script:LogFile)" -ErrorAction Continue
    }
        exit 1
    }
}
