# Legacy BoxLang Module Installer (install-bx-module)
# Description: This is a thin shim kept for backwards compatibility. It translates the legacy
# flag-style arguments into bx-module commands and runs bx-module.ps1, which lives next to
# this script. Use bx-module directly going forward.
# Author: BoxLang Team
# Version: @build.version@
# License: Apache License, Version 2.0

$bxModule = Join-Path $PSScriptRoot "bx-module.ps1"
if (-not (Test-Path $bxModule)) {
    [Console]::Error.WriteLine("Error: bx-module.ps1 not found next to install-bx-module.ps1. Please verify your installation.")
    exit 1
}

# Translate the legacy first argument into a bx-module command:
#   (no args) / <module> ...  -> install
#   --list / --outdated / --update / --remove -> list / outdated / update / remove
#   --help / -h               -> help
$first = ""
$rest = @()
if ($args.Count -gt 0) { $first = [string]$args[0] }
if ($args.Count -gt 1) { $rest = @($args[1..($args.Count - 1)]) }

if ($first -in @("--help", "-h")) {
    $forward = @("help") + $rest
} elseif ($first -in @("--list", "--outdated", "--update", "--remove")) {
    $forward = @($first.Substring(2)) + $rest
} else {
    $forward = @("install") + $args
}

[Console]::Error.WriteLine("⚠️  'install-bx-module' is deprecated and now forwards to bx-module. Use: bx-module $($forward -join ' ')")

& $bxModule @forward
exit $LASTEXITCODE
