#!/bin/sh
# Focused UI smoke test for the BVM installer.
# It verifies the Strata-style flow without requiring network access.

set -eu

TEST_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$TEST_DIR")")"
INSTALLER="$PROJECT_ROOT/src/install-bvm.sh"

SANDBOX="$(mktemp -d)"
mkdir -p "$SANDBOX/home"
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

assert_contains 'select_menu()' "$(grep -n '^select_menu()' "$INSTALLER")" 'installer defines a generic menu'
assert_contains 'run_task()' "$(grep -n '^run_task()' "$INSTALLER")" 'installer defines a task runner'
assert_contains 'progress_bar()' "$(grep -n '^progress_bar()' "$INSTALLER")" 'installer defines a layered progress bar'
assert_contains 'Install BVM (recommended)' "$(cat "$INSTALLER")" 'installer offers a recommended install'
assert_contains 'Customize installation' "$(cat "$INSTALLER")" 'installer offers a custom install'
assert_contains '--verbose' "$(cat "$INSTALLER")" 'installer supports verbose output'
assert_contains '--upgrade' "$(cat "$INSTALLER")" 'installer supports the self-update flag'
assert_contains 'exec "$install_script" --upgrade' "$(cat "$PROJECT_ROOT/src/bvm.sh")" 'BVM self-update uses the upgrade flag'
assert_contains 'COLOR_WARNING=$'\''\033[38;5;208m'\''' "$(cat "$INSTALLER")" 'warnings use orange'
assert_contains '  %s!  %s%s\n' "$(grep -n '^    printf .*COLOR_WARNING' "$INSTALLER")" 'the full warning row uses the warning color'

OUTPUT="$(NO_COLOR=1 \
HOME="$SANDBOX/home" \
SHELL=/bin/bash \
bash "$INSTALLER" --non-interactive --local --without-java --without-runtime --bvm-home "$SANDBOX/bvm" 2>&1)"

assert_contains 'B O X L A N G' "$OUTPUT" 'installer shows the branded banner'
assert_contains 'The software productivity platform' "$OUTPUT" 'banner uses the BoxLang tagline'
assert_contains 'www.boxlang.io' "$OUTPUT" 'banner shows the BoxLang URL'
assert_contains 'BoxLang Version Manager (BVM)' "$OUTPUT" 'banner names the version manager'
assert_contains 'shell: bash' "$OUTPUT" 'installer shows the detected system'
assert_contains 'Installation plan' "$OUTPUT" 'installer shows the installation plan'
assert_contains 'BVM launchers and wrappers' "$OUTPUT" 'plan lists BVM launchers'
assert_contains 'Skip Java checks' "$OUTPUT" 'plan reflects the Java opt-out'
assert_contains 'Installing BVM' "$OUTPUT" 'installer announces the install phase'
assert_contains 'Installed BVM launchers and wrappers' "$OUTPUT" 'task runner reports completed tasks'
assert_contains 'Ready to explore' "$OUTPUT" 'installer shows a final summary'
assert_contains 'bvm install latest' "$OUTPUT" 'summary shows the quick start'

[ -x "$SANDBOX/bvm/bin/bvm" ] || fail 'BVM launcher was installed'
[ -f "$SANDBOX/home/.bashrc" ] || fail 'shell profile was updated'
assert_contains 'BVM (BoxLang Version Manager) shell initialization' "$(cat "$SANDBOX/home/.bashrc")" 'profile contains the BVM hook'

HELP_OUTPUT="$(bash "$INSTALLER" --help 2>&1)"
assert_contains 'Usage: install-bvm.sh' "$HELP_OUTPUT" 'help flag works'
assert_contains '--verbose' "$HELP_OUTPUT" 'help documents verbose mode'

if [ "$FAILURES" -ne 0 ]; then
    printf '%s BVM UI assertion(s) failed.\n' "$FAILURES" >&2
    exit 1
fi
printf 'BVM installer UI smoke test passed.\n'
