#!/bin/sh
# IMPORTANT: This script intentionally targets POSIX /bin/sh.
# Do not change the shebang back to Bash or reintroduce Bash-only syntax.
# It must remain compatible with Alpine BusyBox ash and standard /bin/sh.

# Test suite for install-bx-module.sh (list_modules manifest handling)
# Author: BoxLang Team
# License: Apache License, Version 2.0

# Get the directory of this script
TEST_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$TEST_DIR")")"
INSTALL_BX_MODULE="$PROJECT_ROOT/src/install-bx-module.sh"

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=""

###########################################################################
# Test Framework Functions
###########################################################################

assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    if [ "$expected" = "$actual" ]; then
        echo "✅ PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo "❌ FAIL: $test_name"
        echo "   Expected: '$expected'"
        echo "   Actual:   '$actual'"
        FAILED_TESTS="$FAILED_TESTS\n$test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_contains() {
    local substring="$1"
    local string="$2"
    local test_name="$3"

    case "$string" in
    *"$substring"*)
        echo "✅ PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
        ;;
    *)
        echo "❌ FAIL: $test_name"
        echo "   Expected '$string' to contain '$substring'"
        FAILED_TESTS="$FAILED_TESTS\n$test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
        ;;
    esac
}

assert_not_contains() {
    local substring="$1"
    local string="$2"
    local test_name="$3"

    case "$string" in
    *"$substring"*)
        echo "❌ FAIL: $test_name"
        echo "   Expected '$string' NOT to contain '$substring'"
        FAILED_TESTS="$FAILED_TESTS\n$test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
        ;;
    *)
        echo "✅ PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
        ;;
    esac
}

assert_return_code() {
    local expected_code="$1"
    local actual_code="$2"
    local test_name="$3"

    if [ "$expected_code" -eq "$actual_code" ]; then
        echo "✅ PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo "❌ FAIL: $test_name"
        echo "   Expected return code: $expected_code"
        echo "   Actual return code:   $actual_code"
        FAILED_TESTS="$FAILED_TESTS\n$test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

run_test_group() {
    local group_name="$1"
    echo ""
    echo "🧪 Testing: $group_name"
    echo "────────────────────────────────────────────────────────────"
}

###########################################################################
# Setup
###########################################################################
# install-bx-module.sh ends with `main "$@"`, which would execute immediately
# if the file were sourced. Copy it to a temp location with the final line
# stripped so its functions can be exercised directly. The script resolves
# helpers.sh via SCRIPT_DIR ($0-based, i.e. this test's directory), so we also
# expose them through the BOXLANG_INSTALL_HOME lookup branch.
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

SITE_DIR="$TEST_TMP/site"
mkdir -p "$SITE_DIR/scripts/helpers"
cp "$PROJECT_ROOT/src/helpers/helpers.sh" "$SITE_DIR/scripts/helpers/helpers.sh"
# Strip the final `main "$@"` line so sourcing doesn't run it
sed '$d' "$INSTALL_BX_MODULE" > "$SITE_DIR/install-bx-module.sh"

export BOXLANG_INSTALL_HOME="$SITE_DIR"
. "$SITE_DIR/install-bx-module.sh"
# The sourced script enables `set -e`; turn it back off so an assertion
# failure does not kill the whole suite before it can report.
set +e

MODULES_DIR="$TEST_TMP/modules"
mkdir -p "$MODULES_DIR"

###########################################################################
# Tests for list_modules manifest handling
###########################################################################

test_list_modules_jq_failure() {
    run_test_group "list_modules with failing jq"

    # Fake jq that fails (e.g. unreadable/corrupt manifest). A failing jq in
    # the command substitution would otherwise trip `set -e` and kill the
    # script; the `|| true` makes DEP_COUNT empty, and the guarded numeric
    # comparison must handle that without the POSIX sh "Illegal number" error.
    local BIN_JQ="$TEST_TMP/bin-jqfail"
    mkdir -p "$BIN_JQ"
    cat > "$BIN_JQ/jq" <<'EOF'
#!/bin/sh
exit 1
EOF
    chmod +x "$BIN_JQ/jq"

    echo '{"dependencies": {}}' > "$MODULES_DIR/box.json"

    local output
    output=$(PATH="$BIN_JQ" list_modules "$MODULES_DIR" "Test" 2>&1)
    local rc=$?

    assert_return_code 0 "$rc" "list_modules() returns 0 when jq fails"
    assert_contains "No modules installed" "$output" "list_modules() degrades gracefully when jq fails"
    assert_not_contains "Illegal number" "$output" "list_modules() never emits 'Illegal number'"
}

test_list_modules_empty_manifest() {
    run_test_group "list_modules with empty manifest"

    # Fake jq reporting zero dependencies
    local BIN_JQ="$TEST_TMP/bin-jq0"
    mkdir -p "$BIN_JQ"
    cat > "$BIN_JQ/jq" <<'EOF'
#!/bin/sh
case "$*" in
	*length*) echo "0" ;;
	*) echo '{}' ;;
esac
EOF
    chmod +x "$BIN_JQ/jq"

    echo '{"dependencies": {}}' > "$MODULES_DIR/box.json"

    local output
    output=$(PATH="$BIN_JQ" list_modules "$MODULES_DIR" "Test" 2>&1)
    local rc=$?

    assert_return_code 0 "$rc" "list_modules() returns 0 for empty manifest"
    assert_contains "No modules installed" "$output" "list_modules() reports no modules for empty manifest"
    assert_not_contains "Illegal number" "$output" "list_modules() never emits 'Illegal number'"
}

test_list_modules_with_installed_modules() {
    run_test_group "list_modules with installed modules"

    # Fake jq reporting one dependency and its manifest entry
    local BIN_JQ="$TEST_TMP/bin-jq1"
    mkdir -p "$BIN_JQ"
    cat > "$BIN_JQ/jq" <<'EOF'
#!/bin/sh
case "$*" in
	*length*) echo "1" ;;
	*to_entries*) printf 'bx-cli\t1.0.0\n' ;;
	*) echo '{}' ;;
esac
EOF
    chmod +x "$BIN_JQ/jq"

    echo '{"dependencies": {"bx-cli": "1.0.0"}}' > "$MODULES_DIR/box.json"

    local output
    output=$(PATH="$BIN_JQ" list_modules "$MODULES_DIR" "Test" 2>&1)
    local rc=$?

    assert_return_code 0 "$rc" "list_modules() returns 0 with installed modules"
    assert_contains "bx-cli" "$output" "list_modules() lists installed modules"
    assert_not_contains "Illegal number" "$output" "list_modules() never emits 'Illegal number'"
}

###########################################################################
# Tests for install_module_dependencies (box.json dependency installation)
###########################################################################

test_install_module_dependencies_installs_wildcard_and_pinned_versions() {
    run_test_group "install_module_dependencies with wildcard and pinned deps"

    local MODULE_DIR="$TEST_TMP/module-with-deps"
    mkdir -p "$MODULE_DIR"
    echo '{"dependencies": {"bx-orm": "*", "bx-ai": "2.1.0"}}' > "$MODULE_DIR/box.json"

    # Fake jq reporting two dependencies: one wildcard, one pinned
    local BIN_JQ="$TEST_TMP/bin-jqdeps"
    mkdir -p "$BIN_JQ"
    cat > "$BIN_JQ/jq" <<'EOF'
#!/bin/sh
case "$*" in
	*length*) echo "2" ;;
	*to_entries*) printf 'bx-orm\t*\nbx-ai\t2.1.0\n' ;;
	*) echo '{}' ;;
esac
EOF
    chmod +x "$BIN_JQ/jq"

    # Stub install_module so we assert on what would be installed instead of
    # performing a real network install.
    local INSTALL_CALLS_FILE="$TEST_TMP/install_calls_wildcard.txt"
    : > "$INSTALL_CALLS_FILE"
    install_module() {
        printf '%s\n' "$1" >> "$INSTALL_CALLS_FILE"
    }

    PATH="$BIN_JQ:$PATH" install_module_dependencies "$MODULE_DIR" ""

    local calls
    calls=$(cat "$INSTALL_CALLS_FILE")

    assert_contains "bx-orm" "$calls" "install_module_dependencies() installs a '*' dependency by name only (latest)"
    assert_not_contains "bx-orm@" "$calls" "install_module_dependencies() does not pin a '*' dependency to a version"
    assert_contains "bx-ai@2.1.0" "$calls" "install_module_dependencies() installs a pinned dependency with its exact version"

    # Restore the real install_module for subsequent tests
    . "$SITE_DIR/install-bx-module.sh"
}

test_install_module_dependencies_no_box_json() {
    run_test_group "install_module_dependencies with no box.json"

    local MODULE_DIR="$TEST_TMP/module-without-box-json"
    mkdir -p "$MODULE_DIR"

    local INSTALL_CALLS_FILE="$TEST_TMP/install_calls_none.txt"
    : > "$INSTALL_CALLS_FILE"
    install_module() {
        printf '%s\n' "$1" >> "$INSTALL_CALLS_FILE"
    }

    install_module_dependencies "$MODULE_DIR" ""
    local rc=$?

    assert_return_code 0 "$rc" "install_module_dependencies() returns 0 when box.json is missing"
    assert_equals "" "$(cat "$INSTALL_CALLS_FILE")" "install_module_dependencies() installs nothing when box.json is missing"

    . "$SITE_DIR/install-bx-module.sh"
}

test_install_module_dependencies_skips_circular_dependency() {
    run_test_group "install_module_dependencies with a circular dependency"

    local MODULE_DIR="$TEST_TMP/module-circular"
    mkdir -p "$MODULE_DIR"
    echo '{"dependencies": {"bx-orm": "*"}}' > "$MODULE_DIR/box.json"

    local BIN_JQ="$TEST_TMP/bin-jqcircular"
    mkdir -p "$BIN_JQ"
    cat > "$BIN_JQ/jq" <<'EOF'
#!/bin/sh
case "$*" in
	*length*) echo "1" ;;
	*to_entries*) printf 'bx-orm\t*\n' ;;
	*) echo '{}' ;;
esac
EOF
    chmod +x "$BIN_JQ/jq"

    local INSTALL_CALLS_FILE="$TEST_TMP/install_calls_circular.txt"
    : > "$INSTALL_CALLS_FILE"
    install_module() {
        printf '%s\n' "$1" >> "$INSTALL_CALLS_FILE"
    }

    # "bx-orm" is already in the VISITED chain, so it must be skipped rather
    # than recursively re-installed.
    local output
    output=$(PATH="$BIN_JQ:$PATH" install_module_dependencies "$MODULE_DIR" "bx-root bx-orm" 2>&1)

    assert_contains "Skipping circular dependency" "$output" "install_module_dependencies() reports a skipped circular dependency"
    assert_equals "" "$(cat "$INSTALL_CALLS_FILE")" "install_module_dependencies() does not install an already-visited dependency"

    . "$SITE_DIR/install-bx-module.sh"
}

run_all_tests() {
    test_list_modules_jq_failure
    test_list_modules_empty_manifest
    test_list_modules_with_installed_modules
    test_install_module_dependencies_installs_wildcard_and_pinned_versions
    test_install_module_dependencies_no_box_json
    test_install_module_dependencies_skips_circular_dependency

    # Print summary
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "📊 Test Summary"
    echo "═══════════════════════════════════════════════════════════════════"
    echo "✅ Tests Passed: $TESTS_PASSED"
    echo "❌ Tests Failed: $TESTS_FAILED"
    echo "📈 Total Tests:  $((TESTS_PASSED + TESTS_FAILED))"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo ""
        echo "🎉 All tests passed! ✨"
        echo ""
        exit 0
    else
        echo ""
        echo "💥 Some tests failed:"
        printf '%b\n' "$FAILED_TESTS" | while IFS= read -r test; do
            [ -n "$test" ] && echo "   • $test"
        done
        echo ""
        exit 1
    fi
}

run_all_tests
