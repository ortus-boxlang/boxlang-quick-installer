#!/bin/sh
# IMPORTANT: This script intentionally targets POSIX /bin/sh.
# Do not change the shebang back to Bash or reintroduce Bash-only syntax.
# It must remain compatible with Alpine BusyBox ash and standard /bin/sh.

# Test suite for the legacy install-bx-module shim, which translates the old
# flag-style arguments into bx-module commands and forwards to bx-module.sh.
# Author: BoxLang Team
# License: Apache License, Version 2.0

TEST_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$TEST_DIR")")"
SHIM="$PROJECT_ROOT/src/install-bx-module.sh"

TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=""

assert_equals() {
	if [ "$1" = "$2" ]; then
		echo "✅ PASS: $3"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		echo "❌ FAIL: $3"
		echo "   Expected: '$1'"
		echo "   Actual:   '$2'"
		FAILED_TESTS="$FAILED_TESTS\n$3"
		TESTS_FAILED=$((TESTS_FAILED + 1))
	fi
}

assert_contains() {
	case "$2" in
		*"$1"*)
			echo "✅ PASS: $3"
			TESTS_PASSED=$((TESTS_PASSED + 1))
			;;
		*)
			echo "❌ FAIL: $3"
			echo "   Expected '$2' to contain '$1'"
			FAILED_TESTS="$FAILED_TESTS\n$3"
			TESTS_FAILED=$((TESTS_FAILED + 1))
			;;
	esac
}

# Sandbox laid out like an installed scripts directory, with a stand-in
# bx-module.sh that prints the arguments the shim forwards to it.
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

SCRIPTS="$TEST_TMP/scripts"
BIN="$TEST_TMP/bin"
mkdir -p "$SCRIPTS" "$BIN"
cp "$SHIM" "$SCRIPTS/install-bx-module.sh"
cat > "$SCRIPTS/bx-module.sh" <<'FAKE'
#!/bin/sh
printf 'FORWARDED:'
for arg in "$@"; do printf ' [%s]' "$arg"; done
printf '\n'
FAKE
ln -s "$SCRIPTS/install-bx-module.sh" "$BIN/install-bx-module"

# Runs the shim and captures stdout and stderr separately.
run_shim() {
	SHIM_STDOUT="$(sh "$SCRIPTS/install-bx-module.sh" "$@" 2>"$TEST_TMP/stderr")"
	SHIM_RC=$?
	SHIM_STDERR="$(cat "$TEST_TMP/stderr")"
}

echo ""
echo "🧪 Testing: legacy flags are translated into bx-module commands"
echo "────────────────────────────────────────────────────────────"

run_shim bx-orm
assert_equals "FORWARDED: [install] [bx-orm]" "$SHIM_STDOUT" "a module name becomes: install <module>"

run_shim bx-orm@2.5.0 bx-ai --local
assert_equals "FORWARDED: [install] [bx-orm@2.5.0] [bx-ai] [--local]" "$SHIM_STDOUT" "module names and --local are passed to install unchanged"

run_shim "bx-orm, bx-ai"
assert_equals "FORWARDED: [install] [bx-orm, bx-ai]" "$SHIM_STDOUT" "a quoted module list stays one argument"

run_shim
assert_equals "FORWARDED: [install]" "$SHIM_STDOUT" "no arguments becomes: install"

run_shim --local
assert_equals "FORWARDED: [install] [--local]" "$SHIM_STDOUT" "--local alone becomes: install --local"

run_shim --list
assert_equals "FORWARDED: [list]" "$SHIM_STDOUT" "--list becomes: list"

run_shim --list --local
assert_equals "FORWARDED: [list] [--local]" "$SHIM_STDOUT" "--list --local becomes: list --local"

run_shim --outdated --local
assert_equals "FORWARDED: [outdated] [--local]" "$SHIM_STDOUT" "--outdated --local becomes: outdated --local"

run_shim --update --force --local
assert_equals "FORWARDED: [update] [--force] [--local]" "$SHIM_STDOUT" "--update --force --local becomes: update --force --local"

run_shim --remove bx-orm,bx-ai --force
assert_equals "FORWARDED: [remove] [bx-orm,bx-ai] [--force]" "$SHIM_STDOUT" "--remove <modules> --force becomes: remove <modules> --force"

run_shim --help
assert_equals "FORWARDED: [help]" "$SHIM_STDOUT" "--help becomes: help"

run_shim -h
assert_equals "FORWARDED: [help]" "$SHIM_STDOUT" "-h becomes: help"

echo ""
echo "🧪 Testing: deprecation notice"
echo "────────────────────────────────────────────────────────────"

run_shim --list --local
assert_contains "deprecated" "$SHIM_STDERR" "the shim prints a deprecation notice"
assert_contains "bx-module list --local" "$SHIM_STDERR" "the notice shows the equivalent bx-module command"
assert_equals "FORWARDED: [list] [--local]" "$SHIM_STDOUT" "the notice goes to stderr, leaving stdout untouched"

echo ""
echo "🧪 Testing: running through a symlink"
echo "────────────────────────────────────────────────────────────"

OUTPUT="$(PATH="$BIN:$PATH" install-bx-module --outdated 2>/dev/null)"
assert_equals "FORWARDED: [outdated]" "$OUTPUT" "a symlinked install-bx-module finds bx-module.sh next to the real script"

echo ""
echo "🧪 Testing: missing bx-module.sh"
echo "────────────────────────────────────────────────────────────"

BROKEN="$TEST_TMP/broken"
mkdir -p "$BROKEN"
cp "$SHIM" "$BROKEN/install-bx-module.sh"
OUTPUT="$(sh "$BROKEN/install-bx-module.sh" --list 2>&1)"
RC=$?
assert_equals "1" "$RC" "the shim exits 1 when bx-module.sh is missing"
assert_contains "bx-module.sh not found" "$OUTPUT" "the shim explains that bx-module.sh is missing"

echo ""
echo "🧪 Testing: installers link both bx-module and the legacy alias"
echo "────────────────────────────────────────────────────────────"

assert_file_has() {
	if grep -q -- "$2" "$1"; then
		echo "✅ PASS: $3"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		echo "❌ FAIL: $3"
		echo "   Expected $1 to contain: $2"
		FAILED_TESTS="$FAILED_TESTS\n$3"
		TESTS_FAILED=$((TESTS_FAILED + 1))
	fi
}

SRC="$PROJECT_ROOT/src"
assert_file_has "$SRC/install-boxlang.sh" 'ln -sf "${DESTINATION_SCRIPTS}/bx-module.sh" "${SYSTEM_BIN}/bx-module"' "install-boxlang links bx-module"
assert_file_has "$SRC/install-boxlang.sh" 'ln -sf "${DESTINATION_SCRIPTS}/install-bx-module.sh" "${SYSTEM_BIN}/install-bx-module"' "install-boxlang still links the legacy install-bx-module"
assert_file_has "$SRC/install-boxlang.sh" 'rm -f "${SYSTEM_BIN}/bx-module"' "install-boxlang removes the bx-module link when reinstalling"
assert_file_has "$SRC/install-boxlang.sh" 'rm -fv /usr/local/bin/bx-module' "uninstall removes the system bx-module link"
assert_file_has "$SRC/install-boxlang.sh" 'rm -fv "$HOME/.local/bin/bx-module"' "uninstall removes the user bx-module link"
assert_file_has "$SRC/install-bvm.sh" 'ln -sf "$scripts_dir/bx-module.sh" "$BVM_HOME/bin/bx-module"' "install-bvm links bx-module"
assert_file_has "$SRC/install-bvm.sh" 'ln -sf "$scripts_dir/install-bx-module.sh" "$BVM_HOME/bin/install-bx-module"' "install-bvm still links the legacy install-bx-module"
assert_file_has "$SRC/bvm.sh" 'expected_bvm_scripts="bx-module.sh install-bx-module.sh' "bvm doctor expects bx-module.sh"
assert_file_has "$SRC/install-bvm.ps1" 'bx-module.bat' "install-bvm.ps1 writes bx-module.bat"
assert_file_has "$SRC/install-bvm.ps1" 'install-bx-module.bat' "install-bvm.ps1 still writes the legacy install-bx-module.bat"
assert_file_has "$SRC/bvm.ps1" '"bx-module.ps1", "install-bx-module.ps1"' "bvm doctor on Windows expects bx-module.ps1"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "📊 Test Summary"
echo "═══════════════════════════════════════════════════════════════════"
echo "✅ Tests Passed: $TESTS_PASSED"
echo "❌ Tests Failed: $TESTS_FAILED"
echo "📈 Total Tests:  $((TESTS_PASSED + TESTS_FAILED))"

if [ "$TESTS_FAILED" -eq 0 ]; then
	echo ""
	echo "🎉 All tests passed! ✨"
	exit 0
fi

echo ""
echo "💥 Some tests failed:"
printf '%b\n' "$FAILED_TESTS" | while IFS= read -r test; do
	[ -n "$test" ] && echo "   • $test"
done
exit 1
