# BoxLang Installation Script
# Description: This script installs the BoxLang miniserver web application on a Windows system.
# Author: BoxLang Team
# Version: @build.version@
# License: Apache License, Version 2.0

$requiredJavaVersion = 21
$installedJavaVersion = $null
$bxName = "BoxLang" + [char]0x00A9;
$installerVersion = "@build.version@"
$INSTALLATION_FOLDER = if ([string]::IsNullOrWhiteSpace($env:BOXLANG_INSTALL_HOME)) {
    "C:\boxlang"
} else {
    $env:BOXLANG_INSTALL_HOME
}
$DESTINATION_LIB = "$($INSTALLATION_FOLDER.TrimEnd('\'))\lib"
$DESTINATION_BIN = "$($INSTALLATION_FOLDER.TrimEnd('\'))\bin"
$DESTINATION_HOME = "$($INSTALLATION_FOLDER.TrimEnd('\'))\home"
$DESTINATION_SCRIPTS = "$($INSTALLATION_FOLDER.TrimEnd('\'))\scripts"
$BOXLANG_HOME_BIN = Join-Path -Path $env:USERPROFILE -ChildPath ".boxlang\bin"

# Command line flags - empty = prompt, true = install, false = skip
$INSTALL_COMMANDBOX = $true
$JAVA_INSTALL_MODE = "prompt"
$NON_INTERACTIVE = $false
$BOXLANG_PATH = ""
$MINISERVER_PATH = ""
$INSTALLER_SCRIPTS_PATH = ""

if ([Console]::IsInputRedirected) {
    $NON_INTERACTIVE = $true
}
if ($args -contains "--non-interactive") {
    $NON_INTERACTIVE = $true
}

###########################################################################
# Strata-style UI helpers
###########################################################################

$script:VERBOSE = $false
$script:KEEP_EXISTING = $false
$script:INTERACTIVE = $false

$esc = [char]27
$RESET = "$esc[0m"; $BOLD = "$esc[1m"; $DIM = "$esc[2m"
$ACCENT = "$esc[36m"; $SUCCESS = "$esc[32m"; $WARNCOLOR = "$esc[33m"; $ORANGE = "$esc[38;5;208m"
if ($env:NO_COLOR -or $Host.Name -ne "ConsoleHost") {
    $RESET = ""; $BOLD = ""; $DIM = ""; $ACCENT = ""; $SUCCESS = ""; $WARNCOLOR = ""; $ORANGE = ""
}

function Write-UiInfo {
    param([string]$Text)
    Write-Host "  ${SUCCESS}✓${RESET}  $Text"
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
        'BoxLang Quick Installer'
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
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()
    Write-Host "  ${DIM}Windows · $arch · shell: PowerShell${RESET}"
}

function Select-Menu {
    param([string]$Title, [string[]]$Labels, [string[]]$Hints, [bool[]]$Choices, [bool]$Multiple = $false)
    $active = 0
    function Draw-Menu {
        Write-Section $Title
        for ($i = 0; $i -lt $Labels.Count; $i++) {
            $marker = " "; $color = $RESET
            if ($Host.Name -eq "ConsoleHost" -and $script:INTERACTIVE -and $i -eq $active) {
                $marker = "›"; $color = "$ACCENT$BOLD"
            } elseif ($Multiple -and $Choices[$i]) { $color = $SUCCESS }
            if ($Multiple) {
                $check = if ($Choices[$i]) { "✓" } else { " " }
                Write-Host ("  01  [2] 34" -f $color,$marker,$check,$Labels[$i],$RESET)
            } else {
                Write-Host ("  01  23" -f $color,$marker,$Labels[$i],$RESET)
            }
        }
        Write-Host ""
        Write-Host "  ${DIM}$($Hints[$active])${RESET}"
        Write-Host ""
        if ($Multiple) { Write-Host "  ${DIM}↑/↓ move · Space toggle · Enter continue · Esc cancel${RESET}" }
        else { Write-Host "  ${DIM}↑/↓ choose · Enter continue · Esc cancel${RESET}" }
    }
    if (-not $script:INTERACTIVE) {
        Draw-Menu
        $answer = Read-Host "Choose [1], or press Enter for 1"
        if ([string]::IsNullOrWhiteSpace($answer)) { $Choices[0] = $true; return $Choices }
        foreach ($part in ($answer -split '[ ,;]+')) {
            if ($part -match '^\d+$') {
                $i = [int]$part - 1
                if ($i -ge 0 -and $i -lt $Labels.Count) { $Choices[$i] = $true }
            }
        }
        return $Choices
    }
    Draw-Menu
    while ($true) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        switch ($key.VirtualKeyCode) {
            38 { $active = ($active + $Labels.Count - 1) % $Labels.Count; Draw-Menu }
            40 { $active = ($active + 1) % $Labels.Count; Draw-Menu }
            32 { if ($Multiple) { $Choices[$active] = -not $Choices[$active]; Draw-Menu } }
            13 { if (-not $Multiple) { $Choices[$active] = $true }; Draw-Menu; return $Choices }
            27 { throw "Installation cancelled." }
        }
    }
}

function Show-InstallPlan {
    Write-Section "Installation plan"
    Write-Host "  Install to $INSTALLATION_FOLDER"
    Write-Host ""
    Write-Host "  ${ACCENT}+${RESET}  BoxLang runtime: $TARGET_VERSION"
    Write-Host "  ${ACCENT}+${RESET}  BoxLang MiniServer"
    Write-Host "  ${ACCENT}+${RESET}  Shell integration and completions"
    if ($JAVA_INSTALL_MODE -eq "skip") { Write-Host "  ${ACCENT}+${RESET}  Skip Java checks" }
    else { Write-Host "  ${ACCENT}+${RESET}  Java 21+ (install if missing)" }
    if ($INSTALL_COMMANDBOX -eq $true) { Write-Host "  ${ACCENT}+${RESET}  CommandBox" } else { Write-Host "  ${ACCENT}+${RESET}  Skip CommandBox" }
    if ($script:VERBOSE) { Write-Host "  ${ACCENT}+${RESET}  Verbose task output" }
    if (-not $script:INTERACTIVE) { Write-Host ""; Write-Host "  ${DIM}Non-interactive installation.${RESET}" }
}

function Show-InstallSummary {
    Write-Section "Ready to explore"
    Write-UiInfo "BoxLang installed to $DESTINATION_BIN"
    Write-UiInfo "BoxLang JARs installed to $DESTINATION_LIB"
    Write-UiInfo "BoxLang Home set to $DESTINATION_HOME"
    Write-Host ""
    Write-Host "  ${BOLD}Quick start:${RESET}"
    Write-Host "    boxlang --version"
    Write-Host "    boxlang-miniserver --help"
    Write-Host ""
    Write-Host "  ${DIM}Learn more: https://boxlang.io${RESET}"
    Write-Host ""
}

function Choose-InstallerMode {
    if (-not $script:INTERACTIVE) { return }
    $choice = Select-Menu -Title "Choose your setup" -Labels @("Install BoxLang (recommended)", "Customize installation") -Hints @(
        "Install the selected version with MiniServer, Java support, and shell integration."
        "Choose the version and optional components."
    ) -Choices @($false,$false) -Multiple $false
    if (-not $choice[1]) { return }
    $choice = Select-Menu -Title "Choose a BoxLang version" -Labels @("Latest stable", "Snapshot", "Exact version") -Hints @(
        "Install the latest stable BoxLang release."
        "Install the rolling development snapshot."
        "Type an exact version after the installer."
    ) -Choices @($false,$false,$false) -Multiple $false
    if ($choice[1]) { $script:TARGET_VERSION = "snapshot" }
    elseif ($choice[2]) { $script:TARGET_VERSION = Read-Host "Exact version" }
    $choice = Select-Menu -Title "Make BoxLang yours" -Labels @("Install Java 21+ if missing", "Install CommandBox", "Show verbose task output") -Hints @(
        "Download Java automatically when it is missing."
        "Install CommandBox as the BoxLang package manager."
        "Stream detailed command output during installation."
    ) -Choices @($true,$true,$script:VERBOSE) -Multiple $true
    if ($choice[0]) { $script:JAVA_INSTALL_MODE = "automatic" } else { $script:JAVA_INSTALL_MODE = "skip" }
    $INSTALL_COMMANDBOX = [bool]$choice[1]
    $script:VERBOSE = [bool]$choice[2]
}

function Handle-ExistingInstallation {
    param([string]$CurrentVersion)
    Write-Host ""
    Write-Host "  ${ORANGE}!  Existing BoxLang $CurrentVersion detected at [$($script:CurrentInstallPath -or $INSTALLATION_FOLDER)].${RESET}"
    Write-Host ""
    if ($NON_INTERACTIVE -or $FORCE_INSTALL -or $KEEP_EXISTING) {
        if ($KEEP_EXISTING) { return "keep" }
        Write-Host "  Continuing with the requested reinstall."
        return "reinstall"
    }
    $choice = Select-Menu -Title "Existing BoxLang installation" -Labels @("Reinstall / upgrade", "Keep current version and exit", "Uninstall BoxLang") -Hints @(
        "BoxLang $CurrentVersion is installed at $($script:CurrentInstallPath -or $INSTALLATION_FOLDER). Reinstalling is recommended."
        "Leave the current BoxLang installation unchanged."
        "Remove BoxLang and exit."
    ) -Choices @($false,$false,$false) -Multiple $false
    if ($choice[1]) { return "keep" }
    if ($choice[2]) { return "uninstall" }
    return "reinstall"
}

###########################################################################
# Completions Function
###########################################################################
function Register-PowerShellCompletions {
    param([string]$LoaderPath)

    if (-not (Test-Path $LoaderPath)) {
        Write-Host -ForegroundColor Yellow "⚠️  PowerShell completions were not found at [$LoaderPath], skipping"
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
            Write-Host -ForegroundColor Green "⌨️  Added PowerShell completions to [$profilePath]"
        }
    }
    catch {
        Write-Host -ForegroundColor Yellow "⚠️  Could not update your PowerShell profile: $($_.Exception.Message)"
        Write-Host -ForegroundColor Blue "💡 Add this line to your profile to enable completions: . `"$LoaderPath`""
    }
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
    Write-Host "  --with-commandbox Install the CommandBox module (default)"
    Write-Host "  --without-commandbox Skip the CommandBox module"
    Write-Host "  --with-jre        Require Java 21 or higher"
    Write-Host "  --without-jre     Skip the Java check for a local artifact installation"
	Write-Host "  --boxlang-path <path> Use a local BoxLang JAR or ZIP"
	Write-Host "  --miniserver-path <path> Use a local MiniServer JAR or ZIP"
	Write-Host "  --installer-scripts-path <path> Use a local installer scripts ZIP or directory"
    Write-Host "  --non-interactive  Never prompt; upgrade existing installs automatically"
    Write-Host "  --verbose          Show detailed task output"
    Write-Host "  --keep-existing    Exit cleanly when BoxLang is already installed"
    Write-Host "  --interactive      Force the interactive installer"
    Write-Host "  --yes, -y          Use defaults for all prompts (installs CommandBox)"
    Write-Host ""
    Write-Host -ForegroundColor White -NoNewline "Examples:"
    Write-Host ""
    Write-Host "  .\install-boxlang.ps1"
    Write-Host "  .\install-boxlang.ps1 latest"
    Write-Host "  .\install-boxlang.ps1 snapshot"
    Write-Host "  .\install-boxlang.ps1 1.2.0"
    Write-Host "  .\install-boxlang.ps1 --force"
    Write-Host "  .\install-boxlang.ps1 --with-commandbox"
    Write-Host "  .\install-boxlang.ps1 --without-commandbox"
    Write-Host "  .\install-boxlang.ps1 --yes"
    Write-Host "  .\install-boxlang.ps1 --uninstall"
    Write-Host "  .\install-boxlang.ps1 --check-update"
    Write-Host ""
    Write-Host -ForegroundColor White -NoNewline "Installation Methods:"
    Write-Host ""
    Write-Host -NoNewline "  🌐 One-liner: "
    Write-Host -ForegroundColor Green "iwr -useb https://boxlang.io/install.ps1 | iex"
    Write-Host -NoNewline "  📦 With version: "
    Write-Host -ForegroundColor Green "`$env:BOXLANG_TARGET_VERSION='snapshot'; iwr -useb https://boxlang.io/install.ps1 | iex"
    Write-Host -NoNewline "  📦 With CommandBox: "
    Write-Host -ForegroundColor Green "iwr -useb https://boxlang.io/install.ps1 | iex --with-commandbox"
    Write-Host -NoNewline "  📦 Without CommandBox: "
    Write-Host -ForegroundColor Green "iwr -useb https://boxlang.io/install.ps1 | iex --without-commandbox"
    Write-Host -NoNewline "  📦 Use defaults: "
    Write-Host -ForegroundColor Green "iwr -useb https://boxlang.io/install.ps1 | iex --yes"
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
    Write-Host "  📁 Binaries: $DESTINATION_BIN\"
    Write-Host "  📁 Libraries: $DESTINATION_LIB\"
    Write-Host "  📁 BoxLang Home: $DESTINATION_HOME\"
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
    Write-Host -ForegroundColor Green "bx-module install <module-name>"
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
    Write-Host "  - Installation adds $DESTINATION_BIN to your PATH"
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

# Check for help argument early to avoid any setup overhead
if ($args.Count -ge 1 -and ($args[0] -eq "--help" -or $args[0] -eq "-h")) {
    Show-Help
    exit 0
}

###########################################################################
# Uninstall Function
###########################################################################
function Uninstall-BoxLang {
    Write-Host -ForegroundColor Yellow "🗑️  Uninstalling BoxLang..."

    # Remove from standard Windows program locations
    Write-Host -ForegroundColor Blue "Removing binaries and scripts..."
    Remove-Item -Path $INSTALLATION_FOLDER -Recurse -Force -ErrorAction SilentlyContinue

    # Remove from PATH
    Write-Host -ForegroundColor Blue "Removing from PATH..."
    $currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
    $pathsToRemove = @($DESTINATION_BIN, $BOXLANG_HOME_BIN)
    $newPath = ($currentPath -split ";" | Where-Object {
        $pathsToRemove -notcontains $_
    }) -join ";"
    [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)

    # Remove environment variables
    Write-Host -ForegroundColor Blue "Removing environment variables..."
    [Environment]::SetEnvironmentVariable("BOXLANG_HOME", $null, [EnvironmentVariableTarget]::User)

    Write-Host -ForegroundColor Green "✅ BoxLang uninstalled successfully"
    Write-Host -ForegroundColor Blue "💡 BoxLang Home directory was preserved"
    Write-Host -ForegroundColor Blue "💡 To remove it completely, delete the .boxlang folder in your user directory"
}

# Check for uninstall argument
if ($args.Count -ge 1 -and $args[0] -eq "--uninstall") {
    Uninstall-BoxLang
    exit 0
}

###########################################################################
# Preflight Checks Function
###########################################################################
function Test-Prerequisites {
    param([bool]$RequireInternet = $true)

    Write-Host -ForegroundColor Blue "🔍 Running pre-flight checks..."

    $missingDeps = @()

    # Check for PowerShell (obviously available, but check version)
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $missingDeps += "PowerShell 5.1+"
    }

    if ($RequireInternet) {
        try {
            if (Get-Command Test-NetConnection -ErrorAction SilentlyContinue) {
                $testConnection = Test-NetConnection -ComputerName "downloads.ortussolutions.com" -Port 443 -InformationLevel Quiet -ErrorAction Stop
            } else {
                $null = Invoke-WebRequest -Uri "https://downloads.ortussolutions.com" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
                $testConnection = $true
            }
			if (-not $testConnection) {
				$missingDeps += "Internet connectivity to downloads.ortussolutions.com"
			}
        }
        catch {
            $missingDeps += "Internet connectivity to downloads.ortussolutions.com"
        }
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

# Get current installed BoxLang version
$script:CurrentInstallPath = ""
function Get-InstalledVersionAt {
    param([string]$BinDir, [string]$InstallHome)

    $script:CurrentInstallPath = ""
    $candidates = @(
        (Join-Path $BinDir "boxlang.bat"),
        (Join-Path $BinDir "boxlang.exe"),
        (Join-Path (Join-Path $InstallHome "bin") "boxlang.bat"),
        (Join-Path (Join-Path $InstallHome "bin") "boxlang.exe")
    )

    foreach ($candidate in $candidates) {
        if (-not (Test-Path $candidate)) { continue }
        try {
            $versionOutput = & $candidate --version 2>$null | Out-String
            $version = Get-SemanticVersion -VersionString $versionOutput
            if ($version) {
                $script:CurrentInstallPath = $candidate
                return $version
            }
        } catch { }
    }
    return $null
}

function Get-CurrentBoxLangVersion {
    # Try to find BoxLang in common locations
    $boxlangCandidates = @(
        "boxlang",                                    # In PATH
        (Join-Path -Path $DESTINATION_BIN -ChildPath "boxlang.bat"), # Standard Windows install
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
        $versionLines = $versionInfo -split "`n"
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

# Check for updates and optionally prompt for installation
function Test-ForUpdates {
    Write-Host -ForegroundColor Blue "🔍 Checking for BoxLang updates..."

    # Get current version
    $currentVersion = Get-InstalledVersionAt -BinDir $DESTINATION_BIN -InstallHome $INSTALLATION_FOLDER
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
            if ($NON_INTERACTIVE) {
                $response = ""
            } else {
                $response = Read-Host "Would you like to update to version $latestVersion? [Y/n]"
            }
            if ($response -notmatch "^[nN]") {
                Write-Host -ForegroundColor Green "Starting update to BoxLang $latestVersion..."
                # Call the script again with latest version
                & $PSCommandPath @("latest","--force")
                exit 0
            }
            else {
                Write-Host -ForegroundColor Yellow "Update cancelled"
            }
        }
    }
}

# Check for check-update argument
if ($args.Count -ge 1 -and $args[0] -eq "--check-update") {
    if (-not (Test-Prerequisites)) {
        exit 1
    }
    Test-ForUpdates
    exit 0
}

# Parse arguments to check for flags and remove them from args
$FORCE_INSTALL = $false
$newArgs = @()
for ($argIndex = 0; $argIndex -lt $args.Count; $argIndex++) {
    $arg = $args[$argIndex]
    switch ($arg) {
        "--force" {
            $FORCE_INSTALL = $true
        }
        "--with-commandbox" {
            $INSTALL_COMMANDBOX = $true
        }
        "--without-commandbox" {
            $INSTALL_COMMANDBOX = $false
        }
        "--with-jre" {
            $JAVA_INSTALL_MODE = "automatic"
        }
        "--without-jre" {
            $JAVA_INSTALL_MODE = "skip"
        }
        "--boxlang-path" {
            $argIndex++
            if ($argIndex -ge $args.Count) { throw "--boxlang-path requires a path" }
            $BOXLANG_PATH = $args[$argIndex]
        }
        "--miniserver-path" {
            $argIndex++
            if ($argIndex -ge $args.Count) { throw "--miniserver-path requires a path" }
            $MINISERVER_PATH = $args[$argIndex]
        }
        "--installer-scripts-path" {
            $argIndex++
            if ($argIndex -ge $args.Count) { throw "--installer-scripts-path requires a path" }
            $INSTALLER_SCRIPTS_PATH = $args[$argIndex]
        }
        { $_ -eq "--yes" -or $_ -eq "-y" } {
            # Setup all defaults here - install CommandBox by default
            $INSTALL_COMMANDBOX = $true
			$JAVA_INSTALL_MODE = "automatic"
            $NON_INTERACTIVE = $true
        }
        "--non-interactive" {
            $NON_INTERACTIVE = $true
        }
        "--verbose" {
            $script:VERBOSE = $true
        }
        "--keep-existing" {
            $script:KEEP_EXISTING = $true
        }
        "--interactive" {
            $script:NON_INTERACTIVE = $false
        }
        default {
            $newArgs += $arg
        }
    }
}

# $TARGET_VERSION = "latest"
$TARGET_VERSION = if ($newArgs.Count -ge 1 -and $newArgs[0] -notmatch "^--") { $newArgs[0] } else { "latest" }
$DOWNLOAD_URL = ""
if ( $null -ne $env:BOXLANG_TARGET_VERSION ) {
    $TARGET_VERSION = $env:BOXLANG_TARGET_VERSION
}

$script:INTERACTIVE = -not $NON_INTERACTIVE -and [Environment]::UserInteractive -and -not [Console]::IsInputRedirected
Show-Banner
Show-SystemLine
if ($INTERACTIVE) { Choose-InstallerMode }

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
    param(
        [string]$BinDir,
        [string]$BoxLangHomeBin = ""
    )

    # Build list of directories to check/add
    $dirsToAdd = @($BinDir)
    if ($BoxLangHomeBin -ne "") {
        $dirsToAdd += $BoxLangHomeBin
    }

    # Check if paths are already in PATH
    $currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
    $missingDirs = @()
    $alreadyInPath = @()

    foreach ($dir in $dirsToAdd) {
        if ($currentPath -like "*$dir*") {
            $alreadyInPath += $dir
        } else {
            $missingDirs += $dir
        }
    }

    # Report already present paths
    if ($alreadyInPath.Count -gt 0) {
        foreach ($dir in $alreadyInPath) {
            Write-Host -ForegroundColor Green "✅ $dir is already in your PATH"
        }
    }

    # If all paths are present, we're done
    if ($missingDirs.Count -eq 0) {
        return
    }

    # Report missing paths
    foreach ($dir in $missingDirs) {
        Write-Host -ForegroundColor Yellow "⚠️  $dir is not in your PATH"
    }

    # If non-interactive mode is enabled, auto-update PATH
    if ($NON_INTERACTIVE) {
        Write-Host -ForegroundColor Green "Adding directories to PATH (automatic mode)..."
    } else {
        # Ask user for permission to auto-update
        $dirList = $missingDirs -join ", "
        $response = Read-Host "Would you like to automatically add these directories to your PATH? [Y/n]"
        if ($response -match "^[nN]") {
            Write-Host -ForegroundColor Yellow "Skipping automatic PATH update"
            Write-Host -ForegroundColor Blue "Manually add the following to your system PATH:"
            foreach ($dir in $missingDirs) {
                Write-Host -ForegroundColor Blue "  - $dir"
            }
            return
        }
    }

    # Add missing directories to PATH
    $newPath = $currentPath
    foreach ($dir in $missingDirs) {
        Write-Host -ForegroundColor Blue "Adding $dir to PATH..."
        $newPath = "$newPath;$dir"
    }
    try {
        [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)
        Write-Host -ForegroundColor Green "✅ Successfully updated PATH"
        Write-Host -ForegroundColor Blue "💡 Restart your terminal to use the new PATH"
    }
    catch {
        Write-Host -ForegroundColor Yellow "⚠️  BoxLang was installed, but Windows blocked the PATH update."
        Write-Host -ForegroundColor Blue "💡 Add these directories to your User PATH manually: $($missingDirs -join '; ')"
    }
}

Show-InstallPlan

# Perform preflight checks
$needsDownload = -not $BOXLANG_PATH -or -not $MINISERVER_PATH -or -not $INSTALLER_SCRIPTS_PATH -or $INSTALL_COMMANDBOX -ne $false
if (-not (Test-Prerequisites -RequireInternet $needsDownload)) {
    exit 1
}

###########################################################################
# Enhanced Java Version Check Function
###########################################################################
function Test-JavaVersion {
    Write-Host -ForegroundColor Blue "🔍 Checking Java installation..."

    $pathJavaCandidates = @(Get-Command java -All -ErrorAction SilentlyContinue |
        Where-Object { $_.Source } |
        ForEach-Object { $_.Source })
    $javaCandidates = @(
        $pathJavaCandidates
        "java"                                    # Standard PATH fallback
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
                if ($versionOutput -match '(\d+)\.') {
                    $majorVersion = [int]$matches[1]
                } elseif ($versionOutput -match '1\.(\d+)\.') {
                    $majorVersion = [int]$matches[1]  # Handle legacy 1.8 format
                } elseif ($versionOutput -match 'version (\d+)\.') {
                    $majorVersion = [int]$matches[1] # Handle Adoptium version format
				} elseif ($versionOutput -match 'openjdk (\d+)\.') {
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

# Perform Java version check unless a local artifact installation explicitly skips it.
if ($JAVA_INSTALL_MODE -ne "skip" -and -not (Test-JavaVersion)) {
    exit 1
}

# CommandBox Installation Check and Install
function Install-CommandBoxModule {
    param([string]$ScriptsDir)
    if ($INSTALL_COMMANDBOX -eq $false) { return $false }

    $moduleScript = Join-Path $ScriptsDir "bx-module.ps1"
    if (-not (Test-Path $moduleScript)) {
        Write-Note "bx-module was not found; skipping CommandBox module install."
        return $false
    }

    try {
        & $moduleScript bx-cli
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "bx-module exited with $LASTEXITCODE" }
        return $true
    } catch {
        Write-Note "CommandBox module install failed. Retry with: bx-module bx-cli"
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

    # Remove old BoxLang classes from user home to avoid stale artifacts
    $boxlangClassesPath = Join-Path $env:USERPROFILE ".boxlang\classes"
    if (Test-Path $boxlangClassesPath) {
        Write-Host -ForegroundColor Yellow "🗑️ Removing old BoxLang classes from home directory..."
        Remove-Item -Path $boxlangClassesPath -Force -Recurse -ErrorAction SilentlyContinue
    }

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
if (-not $KEEP_EXISTING) {
    Write-Host -ForegroundColor Blue "[..] Checking for existing BoxLang installation..."
    $currentVersion = Get-CurrentBoxLangVersion
    if ($currentVersion) {
        $decision = Handle-ExistingInstallation -CurrentVersion $currentVersion
        if ($decision -eq "keep") { exit 0 }
        if ($decision -eq "uninstall") { Uninstall-BoxLang; exit 0 }
        $FORCE_INSTALL = $true
    }
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
try {
    New-Item -Type Directory -Path $tmp -Force -ErrorAction Stop | Out-Null
    New-Item -Type Directory -Path $INSTALLATION_FOLDER -Force -ErrorAction Stop | Out-Null
    New-Item -Type Directory -Path $DESTINATION_HOME -Force -ErrorAction Stop | Out-Null
}
catch {
    Write-Host -ForegroundColor Red "❌ Cannot create the BoxLang installation directory [$INSTALLATION_FOLDER]."
    Write-Host -ForegroundColor Yellow "💡 Run PowerShell as Administrator, or set BOXLANG_INSTALL_HOME to a directory you can write to and rerun the installer."
    exit 1
}

# Get BoxLang
if ($BOXLANG_PATH) {
    if (-not (Test-Path $BOXLANG_PATH -PathType Leaf)) {
        throw "BoxLang path does not exist: $BOXLANG_PATH"
    }
    if ([System.IO.Path]::GetExtension($BOXLANG_PATH) -ieq ".jar") {
        Write-Host -ForegroundColor Blue "📦 Using local BoxLang JAR: $BOXLANG_PATH"
        New-Item -Type Directory -Path $DESTINATION_LIB -Force | Out-Null
        Copy-Item -Path $BOXLANG_PATH -Destination $DESTINATION_LIB -Force
    } else {
        Write-Host -ForegroundColor Blue "📦 Using local BoxLang ZIP: $BOXLANG_PATH"
        Copy-Item -Path $BOXLANG_PATH -Destination $tmp\boxlang.zip -Force
    }
} else {
    Write-Host -ForegroundColor Blue "📥 Downloading BoxLang® binary from $DOWNLOAD_URL"
    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $tmp\boxlang.zip -ErrorAction Stop
}

# Get MiniServer
if ($MINISERVER_PATH) {
    if (-not (Test-Path $MINISERVER_PATH -PathType Leaf)) {
        throw "MiniServer path does not exist: $MINISERVER_PATH"
    }
    if ([System.IO.Path]::GetExtension($MINISERVER_PATH) -ieq ".jar") {
        Write-Host -ForegroundColor Blue "📦 Using local MiniServer JAR: $MINISERVER_PATH"
        New-Item -Type Directory -Path $DESTINATION_LIB -Force | Out-Null
        Copy-Item -Path $MINISERVER_PATH -Destination $DESTINATION_LIB -Force
    } else {
        Write-Host -ForegroundColor Blue "📦 Using local MiniServer ZIP: $MINISERVER_PATH"
        Copy-Item -Path $MINISERVER_PATH -Destination $tmp\boxlang-miniserver.zip -Force
    }
} else {
    Write-Host -ForegroundColor Blue "📥 Downloading BoxLang® MiniServer binary from $DOWNLOAD_URL_MINISERVER"
    Invoke-WebRequest -Uri $DOWNLOAD_URL_MINISERVER -OutFile $tmp\boxlang-miniserver.zip -ErrorAction Stop
}

# Get installer scripts
if ($INSTALLER_SCRIPTS_PATH) {
    if (-not (Test-Path $INSTALLER_SCRIPTS_PATH)) {
        throw "Installer scripts path does not exist: $INSTALLER_SCRIPTS_PATH"
    }
    if (-not (Test-Path $INSTALLER_SCRIPTS_PATH -PathType Container)) {
        Write-Host -ForegroundColor Blue "📦 Using local installer scripts ZIP: $INSTALLER_SCRIPTS_PATH"
        Copy-Item -Path $INSTALLER_SCRIPTS_PATH -Destination $tmp\boxlang-installer.zip -Force
    }
} else {
    Write-Host -ForegroundColor Blue "📥 Downloading BoxLang® Quick Installer from $INSTALLER_URL"
    Invoke-WebRequest -Uri $INSTALLER_URL -OutFile $tmp\boxlang-installer.zip -ErrorAction Stop
}

# Unpack ZIP assets and copy local script directories.
if (Test-Path $tmp\boxlang.zip) {
    Write-Host -ForegroundColor Green "📦 Unzipping BoxLang"
    Expand-Archive -Path $tmp\boxlang.zip -DestinationPath $INSTALLATION_FOLDER -Force -ErrorAction Stop
}
if (Test-Path $tmp\boxlang-miniserver.zip) {
    Write-Host -ForegroundColor Green "📦 Unzipping BoxLang MiniServer"
    Expand-Archive -Path $tmp\boxlang-miniserver.zip -DestinationPath $INSTALLATION_FOLDER -Force -ErrorAction Stop
}
if ($INSTALLER_SCRIPTS_PATH -and (Test-Path $INSTALLER_SCRIPTS_PATH -PathType Container)) {
    Write-Host -ForegroundColor Green "📋 Copying local installer scripts"
    New-Item -Type Directory -Path $DESTINATION_BIN -Force | Out-Null
    Copy-Item -Path (Join-Path $INSTALLER_SCRIPTS_PATH "*") -Destination $DESTINATION_BIN -Recurse -Force
} elseif (Test-Path $tmp\boxlang-installer.zip) {
    Write-Host -ForegroundColor Green "📦 Unzipping BoxLang Quick Installer"
    Expand-Archive -Path $tmp\boxlang-installer.zip -DestinationPath $DESTINATION_BIN -Force -ErrorAction Stop
}

# Local JARs need launchers because they do not contain the ZIP runtime scripts.
if ([System.IO.Path]::GetExtension($BOXLANG_PATH) -ieq ".jar") {
    Set-Content -Path (Join-Path $DESTINATION_BIN "boxlang.bat") -Encoding ASCII -Value "@echo off`r`njava -jar `"$DESTINATION_LIB\boxlang.jar`" %*"
}
if ([System.IO.Path]::GetExtension($MINISERVER_PATH) -ieq ".jar") {
    Set-Content -Path (Join-Path $DESTINATION_BIN "boxlang-miniserver.bat") -Encoding ASCII -Value "@echo off`r`njava -jar `"$DESTINATION_LIB\boxlang-miniserver.jar`" %*"
}

# Create Aliases
Write-Host -ForegroundColor Blue "🔗 Creating symbolic links for executables..."
try {
    $boxLangBin = Join-Path -Path $INSTALLATION_FOLDER -ChildPath "bin"
    $boxLangPath = Join-Path -Path $boxLangBin -ChildPath "boxlang.bat"
    $boxLangAliasPath = Join-Path -Path $boxLangBin -ChildPath "bx.bat"
    Remove-Item -Force -ErrorAction SilentlyContinue -Path $boxLangAliasPath | Out-Null
    New-Item -ItemType SymbolicLink -Target $boxLangPath -Path $boxLangAliasPath -ErrorAction Stop | Out-Null

    $miniServerPath = Join-Path -Path $boxLangBin -ChildPath "boxlang-miniserver.bat"
    $miniServerAliasPath = Join-Path -Path $boxLangBin -ChildPath "bx-miniserver.bat"
    Remove-Item -Force -ErrorAction SilentlyContinue -Path $miniServerAliasPath | Out-Null
    New-Item -ItemType SymbolicLink -Target $miniServerPath -Path $miniServerAliasPath -ErrorAction Stop | Out-Null
}
catch {
    Write-Host -ForegroundColor Red "Oh no! We weren't able to setup symlinks for the executables."
    Write-Host -ForegroundColor Red "BoxLang will still run but you will not have the 'bx' and 'bx-miniserver' aliases."
}

# Install CommandBox
$null = Install-CommandBoxModule -ScriptsDir $DESTINATION_SCRIPTS

# Create bin directory in BoxLang home for module executables
Write-Host -ForegroundColor Blue "📁 Creating BoxLang home bin directory..."
if (-not (Test-Path $BOXLANG_HOME_BIN)) {
    New-Item -Path $BOXLANG_HOME_BIN -ItemType Directory -Force | Out-Null
}
Write-Host -ForegroundColor Green "✅ BoxLang home bin directory created at [$BOXLANG_HOME_BIN]"

## Add the bin folder and BoxLang home bin to the path
Update-PathVariable -BinDir $DESTINATION_BIN -BoxLangHomeBin $BOXLANG_HOME_BIN

## Install PowerShell completions into BoxLang home and load them from the profile
$completionsSource = Join-Path $DESTINATION_BIN "completions"
if (Test-Path $completionsSource) {
    $completionsDest = Join-Path (Split-Path -Parent $BOXLANG_HOME_BIN) "completions"
    New-Item -ItemType Directory -Path $completionsDest -Force | Out-Null
    Copy-Item -Path (Join-Path $completionsSource "*") -Destination $completionsDest -Recurse -Force
    Register-PowerShellCompletions -LoaderPath (Join-Path $completionsDest "load.ps1")
}

## Create a BOXLANG_HOME env variable that points to the $DESTINATION_HOME
Write-Host -ForegroundColor Green "🏠 Setting the BOXLANG_HOME environment variable to [$DESTINATION_HOME]"
try {
    [Environment]::SetEnvironmentVariable(
        "BOXLANG_HOME",
        $DESTINATION_HOME,
        [EnvironmentVariableTarget]::User) | Out-Null
}
catch {
    Write-Host -ForegroundColor Yellow "⚠️  BoxLang was installed, but Windows blocked setting BOXLANG_HOME."
    Write-Host -ForegroundColor Blue "💡 Set BOXLANG_HOME to [$DESTINATION_HOME] in your User environment variables."
}

## Clean up
Write-Host -ForegroundColor Green "🧹 Cleaning up..."
Remove-Item -Force -ErrorAction SilentlyContinue -Path $tmp -Recurse | Out-Null

## Verify installation
if (-not (Test-Installation -BinDir $DESTINATION_BIN)) {
    exit 1
}

## Finalization
Show-InstallSummary
