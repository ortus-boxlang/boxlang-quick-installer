#!/bin/sh
# Focused UI regression test for install-boxlang.sh.
# Uses local artifacts and a disposable HOME so no system state is changed.

set -eu

TEST_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$TEST_DIR")")"
INSTALLER="$PROJECT_ROOT/src/install-boxlang.sh"

SANDBOX="$(mktemp -d)"
mkdir -p "$SANDBOX/home" "$SANDBOX/runtime/bin" "$SANDBOX/mock-bin"
trap 'rm -rf "$SANDBOX"' EXIT

FAILURES=0
fail() {
    printf 'FAIL: %s\n' "$1"
    FAILURES=$((FAILURES + 1))
}
assert_contains() {
    case "$2" in
        *"$1"*) : ;;
        *) fail "$3 (expected: $1)" ;;
    esac
}
assert_not_contains() {
    case "$2" in
        *"$1"*) fail "$3 (unexpected: $1)" ;;
        *) : ;;
    esac
}

create_artifacts() {
    local name="$1"
    cat > "$SANDBOX/runtime/bin/boxlang" <<EOF
#!/bin/sh
if [ "\$1" = "--version" ]; then echo "BoxLang $name"; fi
EOF
    printf '#!/bin/sh\nexit 0\n' > "$SANDBOX/runtime/bin/boxlang-miniserver"
    chmod +x "$SANDBOX/runtime/bin/"*
    (cd "$SANDBOX/runtime" && zip -qr "$SANDBOX/$name.zip" .)
    printf '#!/bin/sh\nexit 99\n' > "$SANDBOX/mock-bin/curl"
    chmod +x "$SANDBOX/mock-bin/curl"
}

run_installer() {
    local home_dir="$1" output_file="$2"; shift 2
    env -u BOXLANG_HOME \
        HOME="$home_dir" SHELL=/bin/bash TERM=xterm-256color \
        PATH="$SANDBOX/mock-bin:/usr/bin:/bin" \
        sh "$INSTALLER" "$@" \
            --without-commandbox --without-jre \
            --boxlang-path "$SANDBOX/new.zip" \
            --miniserver-path "$SANDBOX/new.zip" \
            --installer-scripts-path "$PROJECT_ROOT/src" > "$output_file" 2>&1
}

create_artifacts new

# Fresh non-interactive install
run_installer "$SANDBOX/home" "$SANDBOX/fresh.log" \
    new --non-interactive
FRESH="$(cat "$SANDBOX/fresh.log")"
assert_contains 'B O X L A N G' "$FRESH" 'banner is rendered'
assert_contains 'The software productivity platform' "$FRESH" 'BoxLang tagline is rendered'
assert_contains 'BoxLang Quick Installer' "$FRESH" 'installer label is rendered'
assert_contains 'Installation plan' "$FRESH" 'installation plan is rendered'
assert_contains 'Install to ' "$FRESH" 'plan shows the install path'
assert_contains 'Non-interactive installation.' "$FRESH" 'non-interactive state is shown'
assert_contains 'Installed BoxLang runtime and tools' "$FRESH" 'task runner reports installation'
assert_contains 'Ready to explore' "$FRESH" 'summary is rendered'
assert_not_contains 'Choose your setup' "$FRESH" 'non-interactive mode does not show the menu'

# Existing install in non-interactive mode continues
EXISTING_HOME="$SANDBOX/existing-home"
mkdir -p "$EXISTING_HOME/.local/bin"
printf '#!/bin/sh\nif [ "$1" = "--version" ]; then echo "BoxLang 1.0.0-existing"; fi\n' > "$EXISTING_HOME/.local/bin/boxlang"
chmod +x "$EXISTING_HOME/.local/bin/boxlang"
run_installer "$EXISTING_HOME" "$SANDBOX/existing.log" \
    new --non-interactive --force
EXISTING="$(cat "$SANDBOX/existing.log")"
assert_contains 'Existing BoxLang' "$EXISTING" 'existing installation is detected'
assert_contains 'Continuing with the requested reinstall.' "$EXISTING" 'non-interactive reinstall continues'
assert_contains 'Ready to explore' "$EXISTING" 'non-interactive reinstall completes'

# --keep-existing exits cleanly
KEEP_HOME="$SANDBOX/keep-home"
mkdir -p "$KEEP_HOME/.local/bin"
printf '#!/bin/sh\nif [ "$1" = "--version" ]; then echo "BoxLang 1.0.0-existing"; fi\n' > "$KEEP_HOME/.local/bin/boxlang"
chmod +x "$KEEP_HOME/.local/bin/boxlang"
run_installer "$KEEP_HOME" "$SANDBOX/keep.log" \
    new --non-interactive --keep-existing || true
KEEP="$(cat "$SANDBOX/keep.log")"
assert_contains 'Existing BoxLang' "$KEEP" 'keep-existing detects the install'
assert_not_contains 'Ready to explore' "$KEEP" 'keep-existing does not reinstall'

# Help documents new flags
HELP="$(NO_COLOR=1 sh "$INSTALLER" --help 2>&1)"
assert_contains -- '--non-interactive' "$HELP" 'help documents --non-interactive'
assert_contains -- '--verbose' "$HELP" 'help documents --verbose'
assert_contains -- '--keep-existing' "$HELP" 'help documents --keep-existing'
assert_contains 'Show verbose task output' "$(cat "$INSTALLER")" 'custom mode offers verbose output'
assert_contains 'INSTALL_COMMANDBOX=true' "$(cat "$INSTALLER")" 'CommandBox module installs by default'
assert_contains 'bx-module.sh" bx-cli' "$(cat "$INSTALLER")" 'installer uses bx-module bx-cli'
assert_contains '& $moduleScript bx-cli' "$(cat "$PROJECT_ROOT/src/install-boxlang.ps1")" 'PowerShell installer uses bx-module bx-cli'

if [ "$FAILURES" -ne 0 ]; then
    printf '%s BoxLang installer UI assertion(s) failed.\n' "$FAILURES" >&2
    exit 1
fi
printf 'BoxLang installer UI smoke test passed.\n'
