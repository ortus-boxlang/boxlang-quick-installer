#!/usr/bin/env bash
# Integration tests for BoxLang compiled binaries.
# Runs inside Docker to verify binaries work in clean environments.
#
# Usage:
#   ./run_tests.sh              # Run all tests (including network-dependent)
#   ./run_tests.sh --no-network # Skip tests that require internet access
#
# Exit code: number of failures (0 = all passed)

set -uo pipefail

BVM_HOME="${BVM_HOME:-$HOME/.bvm}"
BVM_BIN="${BVM_HOME}/bin"
PASS=0
FAIL=0
SKIP=0
NO_NETWORK=false

for arg in "$@"; do
	case "$arg" in
		--no-network|--offline) NO_NETWORK=true ;;
	esac
done

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
pass() { (( PASS++ )) || true; echo -e "  ${GREEN}✓${NC} $1"; }
fail() { (( FAIL++ )) || true; echo -e "  ${RED}✗${NC} $1"; }
skip() { (( SKIP++ )) || true; echo -e "  ${YELLOW}⊘${NC} $1 (skipped)"; }
section() { echo -e "\n${BOLD}${CYAN}── $1 ──${NC}"; }

assert_exit() {
	local desc="$1"; shift
	if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc (exit $?)"; fi
}

assert_output_contains() {
	local desc="$1" local expected="$2"; shift 2
	local output
	output=$("$@" 2>&1) || true
	if echo "$output" | grep -qi "$expected"; then pass "$desc"
	else fail "$desc – expected '$expected' in output"; fi
}

assert_dir_exists()    { [ -d "$1" ] && pass "$2" || fail "$2 – $1 missing"; }
assert_file_exists()   { [ -f "$1" ] && pass "$2" || fail "$2 – $1 missing"; }
assert_link_exists()   { [ -L "$1" ] && pass "$2" || fail "$2 – $1 not a symlink"; }
assert_no_link()       { [ ! -L "$1" ] && pass "$2" || fail "$2 – $1 still exists"; }

# ── Header ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   BoxLang Integration Tests                            ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  BVM_HOME : ${BVM_HOME}"
echo "  Platform : $(uname -s)/$(uname -m)"
echo "  Java     : $(java -version 2>&1 | head -1)"
echo "  Network  : $( $NO_NETWORK && echo 'disabled' || echo 'enabled' )"

# ═══════════════════════════════════════════════════════════════════════════════
section "1. Java 21+ available"
# ═══════════════════════════════════════════════════════════════════════════════
java_ver=$(java -version 2>&1 | head -1)
if echo "$java_ver" | grep -qE '"(2[1-9]|[3-9][0-9])'; then
	pass "Java 21+ detected: $java_ver"
else
	fail "Java 21+ required, got: $java_ver"
fi

# ═══════════════════════════════════════════════════════════════════════════════
section "2. Compiled binaries exist and are executable"
# ═══════════════════════════════════════════════════════════════════════════════
for bin in bvm install-boxlang install-bx-module install-bx-site; do
	assert_file_exists "${BVM_BIN}/${bin}" "${bin} binary exists"
	if [ -x "${BVM_BIN}/${bin}" ]; then pass "${bin} is executable"
	else fail "${bin} is not executable"; fi
done

# ═══════════════════════════════════════════════════════════════════════════════
section "3. Binary execution – help / version"
# ═══════════════════════════════════════════════════════════════════════════════
assert_output_contains "bvm help"              "BoxLang Version Manager" "${BVM_BIN}/bvm" help
assert_output_contains "bvm version"           "BVM version"            "${BVM_BIN}/bvm" version
assert_output_contains "install-boxlang help"   "BoxLang"               "${BVM_BIN}/install-boxlang" --help
assert_output_contains "install-bx-module help" "BoxLang"               "${BVM_BIN}/install-bx-module" --help
assert_output_contains "install-bx-site help"   "BoxLang"               "${BVM_BIN}/install-bx-site" --help

# ═══════════════════════════════════════════════════════════════════════════════
section "4. BVM directory structure"
# ═══════════════════════════════════════════════════════════════════════════════
assert_dir_exists "${BVM_HOME}"          "BVM_HOME exists"
assert_dir_exists "${BVM_HOME}/bin"      "bin/ directory exists"
assert_dir_exists "${BVM_HOME}/versions" "versions/ directory exists"
assert_dir_exists "${BVM_HOME}/cache"    "cache/ directory exists"

# ═══════════════════════════════════════════════════════════════════════════════
section "5. bvm list (empty)"
# ═══════════════════════════════════════════════════════════════════════════════
assert_output_contains "bvm list shows no versions" "No versions" "${BVM_BIN}/bvm" list

# ═══════════════════════════════════════════════════════════════════════════════
section "6. bvm current (none active)"
# ═══════════════════════════════════════════════════════════════════════════════
assert_output_contains "bvm current shows no active version" "No version" "${BVM_BIN}/bvm" current

# ═══════════════════════════════════════════════════════════════════════════════
section "7. bvm install / use / list / current / uninstall"
# ═══════════════════════════════════════════════════════════════════════════════
if $NO_NETWORK; then
	skip "bvm install (network disabled)"
	skip "bvm use (depends on install)"
	skip "bvm list with version (depends on install)"
	skip "bvm current after use (depends on use)"
	skip "symlink verification (depends on use)"
	skip "bvm uninstall (depends on install)"
else
	echo "  Installing BoxLang latest (requires network)..."
	install_output=$("${BVM_BIN}/bvm" install latest 2>&1)
	install_rc=$?

	if [ $install_rc -ne 0 ]; then
		fail "bvm install latest (exit ${install_rc})"
		echo "    Output: ${install_output}"
		skip "remaining bvm tests (install failed)"
	else
		pass "bvm install latest"

		installed_ver=$(ls "${BVM_HOME}/versions/" 2>/dev/null | head -1)
		if [ -n "$installed_ver" ]; then
			pass "Version directory created: ${installed_ver}"
		else
			fail "No version directory found in ${BVM_HOME}/versions/"
			installed_ver="unknown"
		fi

		assert_dir_exists "${BVM_HOME}/versions/${installed_ver}" "Version dir exists"

		assert_output_contains "bvm use ${installed_ver}" "using" \
			"${BVM_BIN}/bvm" use "${installed_ver}"

		assert_link_exists "${BVM_HOME}/current" "current symlink created"

		assert_output_contains "bvm list shows version" "${installed_ver}" \
			"${BVM_BIN}/bvm" list

		assert_output_contains "bvm current shows version" "${installed_ver}" \
			"${BVM_BIN}/bvm" current

		assert_output_contains "bvm uninstall ${installed_ver}" "removed" \
			"${BVM_BIN}/bvm" uninstall "${installed_ver}"

		assert_no_link "${BVM_HOME}/current" "current symlink removed after uninstall"
	fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
section "8. bvm use with non-existent version"
# ═══════════════════════════════════════════════════════════════════════════════
use_bad_output=$("${BVM_BIN}/bvm" use 99.99.99 2>&1) || true
if echo "$use_bad_output" | grep -qi "not installed\|error"; then
	pass "bvm use 99.99.99 reports error"
else
	fail "bvm use 99.99.99 should report error"
fi

# ═══════════════════════════════════════════════════════════════════════════════
section "9. bvm help shows subcommands"
# ═══════════════════════════════════════════════════════════════════════════════
help_output=$("${BVM_BIN}/bvm" help 2>&1)
echo "$help_output" | grep -qi "module" && pass "bvm help shows module subcommands" || fail "bvm help missing module subcommands"
echo "$help_output" | grep -qi "site" && pass "bvm help shows site subcommands" || fail "bvm help missing site subcommands"
echo "$help_output" | grep -qi "setup" && pass "bvm help shows setup subcommand" || fail "bvm help missing setup subcommand"

# ═══════════════════════════════════════════════════════════════════════════════
section "10. bvm module list (empty)"
# ═══════════════════════════════════════════════════════════════════════════════
assert_output_contains "bvm module list shows no modules" "No modules" "${BVM_BIN}/bvm" module list

# ═══════════════════════════════════════════════════════════════════════════════
section "11. bvm module install / list / remove"
# ═══════════════════════════════════════════════════════════════════════════════
if $NO_NETWORK; then
	skip "bvm module install (network disabled)"
	skip "bvm module list with module (depends on install)"
	skip "bvm module remove (depends on install)"
else
	echo "  Installing test module (requires network)..."
	module_output=$("${BVM_BIN}/bvm" module install bx-orm 2>&1)
	module_rc=$?

	if [ $module_rc -ne 0 ]; then
		fail "bvm module install bx-orm (exit ${module_rc})"
		echo "    Output: ${module_output}"
		skip "remaining module tests (install failed)"
	else
		pass "bvm module install bx-orm"

		assert_output_contains "bvm module list shows module" "bx-orm" \
			"${BVM_BIN}/bvm" module list

		assert_output_contains "bvm module remove bx-orm" "removed" \
			"${BVM_BIN}/bvm" module remove bx-orm
	fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
section "12. bvm site create"
# ═══════════════════════════════════════════════════════════════════════════════
SITE_TEST_DIR=$(mktemp -d)
cd "$SITE_TEST_DIR" || fail "Cannot cd to temp dir"

site_output=$("${BVM_BIN}/bvm" site create --name=testsite --port=9999 2>&1)
site_rc=$?

if [ $site_rc -ne 0 ]; then
	fail "bvm site create (exit ${site_rc})"
	echo "    Output: ${site_output}"
else
	pass "bvm site create"

	if [ -f "${SITE_TEST_DIR}/.boxlang/server.json" ]; then
		pass "server.json created"
	else
		fail "server.json not created"
	fi

	if grep -q "9999" "${SITE_TEST_DIR}/.boxlang/server.json" 2>/dev/null; then
		pass "server.json has correct port"
	else
		fail "server.json missing correct port"
	fi

	if [ -f "${SITE_TEST_DIR}/index.bxm" ]; then
		pass "index.bxm created"
	else
		fail "index.bxm not created"
	fi
fi

cd / || true
rm -rf "$SITE_TEST_DIR"

# ═══════════════════════════════════════════════════════════════════════════════
section "13. bvm setup (system-wide install)"
# ═══════════════════════════════════════════════════════════════════════════════
if $NO_NETWORK; then
	skip "bvm setup (requires installed version)"
else
	echo "  Installing BoxLang for setup test..."
	"${BVM_BIN}/bvm" install latest >/dev/null 2>&1
	installed_ver=$(ls "${BVM_HOME}/versions/" 2>/dev/null | head -1)

	if [ -n "$installed_ver" ]; then
		"${BVM_BIN}/bvm" use "$installed_ver" >/dev/null 2>&1

		setup_output=$("${BVM_BIN}/bvm" setup 2>&1)
		setup_rc=$?

		if [ $setup_rc -ne 0 ]; then
			fail "bvm setup (exit ${setup_rc})"
			echo "    Output: ${setup_output}"
		else
			pass "bvm setup"

			if echo "$setup_output" | grep -qi "Linked.*boxlang"; then
				pass "bvm setup created boxlink symlink"
			else
				fail "bvm setup missing boxlang symlink"
			fi
		fi

		"${BVM_BIN}/bvm" uninstall "$installed_ver" >/dev/null 2>&1
	else
		fail "Could not install BoxLang for setup test"
	fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}──────────────────────────────────────────────────────────────${NC}"
TOTAL=$(( PASS + FAIL + SKIP ))
echo -e "${BOLD}Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${SKIP} skipped${NC} / ${TOTAL} total"
echo -e "${BOLD}──────────────────────────────────────────────────────────────${NC}"

if [ $FAIL -gt 0 ]; then
	echo -e "${RED}INTEGRATION TESTS FAILED${NC}"
	exit 1
fi

echo -e "${GREEN}ALL TESTS PASSED${NC}"
exit 0
