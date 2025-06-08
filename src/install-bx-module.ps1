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
    $input = ""

    # Concatenate all arguments into a single string, skipping flags
    foreach ($arg in $Arguments) {
        if (-not $arg.StartsWith("--")) {
            $input += " $arg"
        }
    }

    # Replace commas with spaces and normalize whitespace
    $input = $input -replace ",", " " -replace "\s+", " "
    $input = $input.Trim()

    # Split by spaces and add to array
    if ($input) {
        $modules = $input -split " " | Where-Object { $_ -ne "" }
    }

    return $modules
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
    Write-Host "  install-bx-module.ps1 --help"
    Write-Host ""
    Write-Host "Arguments:" -ForegroundColor DarkYellow
    Write-Host "  <module-name>     The name(s) of the module(s) to install. (Comma or space delimited)"
    Write-Host "  [@<version>]      (Optional) The specific semantic version of the module to install"
    Write-Host ""
    Write-Host "Options:" -ForegroundColor DarkYellow
    Write-Host "  --local           Install to/remove from local boxlang_modules folder instead of BoxLang HOME. The BoxLang HOME is the default."
    Write-Host "  --remove          Remove specified module(s)"
    Write-Host "  --force           Skip confirmation when removing modules(s)(use with --remove)"
    Write-Host "  --list            Show installed module(s)"
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
    Write-Host ""
    Write-Host "Notes:" -ForegroundColor DarkYellow
    Write-Host "  - If no version is specified, the latest version from FORGEBOX will be installed"
    Write-Host "  - Multiple modules can be specified, separated by spaces or commas"
    Write-Host "  - Module lists can mix spaces and commas: 'bx-orm, bx-ai bx-esapi'"
    Write-Host "  - Use --local to work with modules in current directory's boxlang_modules folder"
    Write-Host "  - Without --local, modules are managed in BoxLang HOME (~/.boxlang/modules)"
    Write-Host "  - Requires PowerShell to be installed"
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

    # List all directories in the modules folder
    $moduleDirectories = Get-ChildItem -Path $ModulesPath -Directory -ErrorAction SilentlyContinue

    if (-not $moduleDirectories) {
        Write-Host "📭 No modules installed" -ForegroundColor Yellow
    } else {
        # List modules with version information from box.json
        foreach ($moduleDir in $moduleDirectories) {
            $moduleName = $moduleDir.Name
            $boxJsonPath = Join-Path $moduleDir.FullName "box.json"

            if (Test-Path $boxJsonPath) {
                try {
                    $boxJson = Get-Content $boxJsonPath | ConvertFrom-Json
                    $version = $boxJson.version
                    if ($version) {
                        Write-Host "✓ $moduleName ($version)" -ForegroundColor Green
                    } else {
                        Write-Host "✓ $moduleName (version unknown)" -ForegroundColor Green
                    }
                } catch {
                    Write-Host "✓ $moduleName (version unknown)" -ForegroundColor Green
                }
            } else {
                Write-Host "✓ $moduleName (no box.json)" -ForegroundColor Green
            }
        }
    }
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
    param([string]$Input)

    $targetModule = ""
    $targetVersion = ""

    if ($Input.Contains("@")) {
        $parts = $Input -split "@"
        $targetModule = $parts[0].ToLower()
        $targetVersion = $parts[1]
    } else {
        $targetModule = $Input.ToLower()
    }

    # Validate module name
    if (-not $targetModule) {
        Write-Host "❌ Error: You must specify a BoxLang module to install" -ForegroundColor Red
        Write-Host "💡 Usage: install-bx-module.ps1 <module-name>[@<version>] [--local]" -ForegroundColor Yellow
        exit 1
    }

    # Fetch latest version if not specified
    if (-not $targetVersion) {
        $forgeboxResult = Get-LatestVersionFromForgebox $targetModule
        $targetVersion = $forgeboxResult.Version
        $downloadUrl = $forgeboxResult.DownloadUrl
    } else {
        # We have a targeted version, let's build the download URL from the artifacts directly
        $downloadUrl = "https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/$targetModule/$targetVersion/$targetModule-$targetVersion.zip"
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

        # Success message
        Write-Host ""
        Write-Host "✅ BoxLang® Module [$targetModule@$targetVersion] installed successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "*************************************************************************"
        Write-Host "BoxLang® - Dynamic : Modular : Productive : https://boxlang.io"
        Write-Host "*************************************************************************"
        Write-Host "BoxLang® is FREE and Open-Source Software under the Apache 2.0 License"
        Write-Host "You can also buy support and enhanced versions at https://boxlang.io/plans"
        Write-Host "p.s. Follow us at https://x.com/tryboxlang."
        Write-Host "p.p.s. Clone us and star us at https://github.com/ortus-boxlang/boxlang"
        Write-Host "Please support us via Patreon at https://www.patreon.com/ortussolutions"
        Write-Host "*************************************************************************"
        Write-Host "Copyright and Registered Trademarks of Ortus Solutions, Corp"

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
    Write-Host "Usage: install-bx-module.ps1 <module-name>[@<version>] [<module-name>[@<version>] ...] [--local]" -ForegroundColor Yellow
    Write-Host "   or: install-bx-module.ps1 --remove <module-name> [<module-name> ...] [--force] [--local]" -ForegroundColor Yellow
    Write-Host "- <module-name>: The name of the module to install or remove." -ForegroundColor Yellow
    Write-Host "- [@<version>]: (Optional) The specific version of the module to install." -ForegroundColor Yellow
    Write-Host "- Multiple modules can be specified, separated by spaces or commas." -ForegroundColor Yellow
    Write-Host "- If no version is specified we will ask FORGEBOX for the latest version" -ForegroundColor Yellow
    Write-Host "- Use --remove to remove modules instead of installing them" -ForegroundColor Yellow
    Write-Host "- Use --force with --remove to skip confirmation prompts" -ForegroundColor Yellow
    Write-Host "- Use --local to install to/remove from a local boxlang_modules folder instead of the BoxLang HOME" -ForegroundColor Yellow
    Write-Host "- Use --list to show installed modules (can be combined with --local)" -ForegroundColor Yellow
    Write-Host "- Use --help to show this message" -ForegroundColor Yellow
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
    if ($remainingArgs.Count -gt 0) {
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
