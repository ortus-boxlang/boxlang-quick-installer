#!/bin/bash
# Regression tests for the Windows BoxLang installer path resolution.

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$TEST_DIR")")"
INSTALLER_SCRIPT="$PROJECT_ROOT/src/install-boxlang.ps1"
POWERSHELL_CMD="$(command -v powershell.exe || command -v powershell || true)"

if [ -z "$POWERSHELL_CMD" ]; then
    echo "Skipping Windows installer tests: PowerShell was not found"
    exit 0
fi

export INSTALLER_SCRIPT

run_help() {
    "$POWERSHELL_CMD" -NoProfile -Command "$1 & \$env:INSTALLER_SCRIPT --help"
}

default_output="$(run_help 'Remove-Item Env:BOXLANG_INSTALL_HOME -ErrorAction SilentlyContinue')"
custom_output="$(run_help "\$env:BOXLANG_INSTALL_HOME = 'C:\\boxlang-custom'")"

for expected in \
    '📁 Binaries: C:\boxlang\bin\' \
    '📁 Libraries: C:\boxlang\lib\' \
    '📁 BoxLang Home: C:\boxlang\home\'; do
    [[ "$default_output" == *"$expected"* ]] || {
        echo "FAIL: default installation path missing: $expected"
        exit 1
    }
done

for expected in \
    '📁 Binaries: C:\boxlang-custom\bin\' \
    '📁 Libraries: C:\boxlang-custom\lib\' \
    '📁 BoxLang Home: C:\boxlang-custom\home\'; do
    [[ "$custom_output" == *"$expected"* ]] || {
        echo "FAIL: custom installation path missing: $expected"
        exit 1
    }
done

echo "Windows installer path tests passed"