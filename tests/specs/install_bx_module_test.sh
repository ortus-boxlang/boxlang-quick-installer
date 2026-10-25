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
    set +e
}

test_install_module_dependencies_installs_be_and_snapshot_versions() {
    run_test_group "install_module_dependencies with 'be' and 'snapshot' deps"

    local MODULE_DIR="$TEST_TMP/module-with-be-snapshot-deps"
    mkdir -p "$MODULE_DIR"
    echo '{"dependencies": {"bx-orm": "be", "bx-ai": "snapshot"}}' > "$MODULE_DIR/box.json"

    # Fake jq reporting a bleeding-edge dependency and a snapshot dependency
    local BIN_JQ="$TEST_TMP/bin-jqbesnap"
    mkdir -p "$BIN_JQ"
    cat > "$BIN_JQ/jq" <<'EOF'
#!/bin/sh
case "$*" in
	*length*) echo "2" ;;
	*to_entries*) printf 'bx-orm\tbe\nbx-ai\tsnapshot\n' ;;
	*) echo '{}' ;;
esac
EOF
    chmod +x "$BIN_JQ/jq"

    local INSTALL_CALLS_FILE="$TEST_TMP/install_calls_be_snapshot.txt"
    : > "$INSTALL_CALLS_FILE"
    install_module() {
        printf '%s\n' "$1" >> "$INSTALL_CALLS_FILE"
    }

    PATH="$BIN_JQ:$PATH" install_module_dependencies "$MODULE_DIR" ""

    local calls
    calls=$(cat "$INSTALL_CALLS_FILE")

    assert_contains "bx-orm@be" "$calls" "install_module_dependencies() passes through a 'be' dependency version"
    assert_contains "bx-ai@snapshot" "$calls" "install_module_dependencies() passes through a 'snapshot' dependency version"

    . "$SITE_DIR/install-bx-module.sh"
    set +e
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
    set +e
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
    set +e
}

test_install_module_dependencies_skips_non_forgebox_maven_dependency() {
    run_test_group "install_module_dependencies with a Maven-style dependency"

    local MODULE_DIR="$TEST_TMP/module-maven-dep"
    mkdir -p "$MODULE_DIR"
    echo '{"dependencies": {"org.jline:jline": "maven:org.jline:jline:3.21.0", "bx-orm": "*"}}' > "$MODULE_DIR/box.json"

    # Fake jq reporting a Maven coordinate dependency alongside a normal one
    local BIN_JQ="$TEST_TMP/bin-jqmaven"
    mkdir -p "$BIN_JQ"
    cat > "$BIN_JQ/jq" <<'EOF'
#!/bin/sh
case "$*" in
	*length*) echo "2" ;;
	*to_entries*) printf 'org.jline:jline	maven:org.jline:jline:3.21.0
bx-orm	*
' ;;
	*) echo '{}' ;;
esac
EOF
    chmod +x "$BIN_JQ/jq"

    local INSTALL_CALLS_FILE="$TEST_TMP/install_calls_maven.txt"
    : > "$INSTALL_CALLS_FILE"
    install_module() {
        printf '%s\n' "$1" >> "$INSTALL_CALLS_FILE"
    }

    # A Maven coordinate is not a ForgeBox module slug and must be skipped
    # (with a warning) rather than attempted -- and failed -- as one.
    local output
    output=$(PATH="$BIN_JQ:$PATH" install_module_dependencies "$MODULE_DIR" "" 2>&1)

    assert_contains "Skipping non-ForgeBox dependency" "$output" "install_module_dependencies() reports a skipped Maven dependency"
    assert_not_contains "org.jline:jline" "$(cat "$INSTALL_CALLS_FILE")" "install_module_dependencies() does not attempt to install a Maven coordinate as a ForgeBox module"
    assert_contains "bx-orm" "$(cat "$INSTALL_CALLS_FILE")" "install_module_dependencies() still installs a normal ForgeBox dependency alongside a skipped one"

    . "$SITE_DIR/install-bx-module.sh"
    set +e
}

test_install_module_dependencies_continues_after_a_failed_dependency() {
    run_test_group "install_module_dependencies with a failing dependency install"

    local MODULE_DIR="$TEST_TMP/module-failing-dep"
    mkdir -p "$MODULE_DIR"
    echo '{"dependencies": {"bx-orm": "*", "bx-ai": "2.1.0"}}' > "$MODULE_DIR/box.json"

    local BIN_JQ="$TEST_TMP/bin-jqfailing"
    mkdir -p "$BIN_JQ"
    cat > "$BIN_JQ/jq" <<'EOF'
#!/bin/sh
case "$*" in
	*length*) echo "2" ;;
	*to_entries*) printf 'bx-orm	*
bx-ai	2.1.0
' ;;
	*) echo '{}' ;;
esac
EOF
    chmod +x "$BIN_JQ/jq"

    # Simulate a ForgeBox-looking dependency whose install still fails (e.g. a
    # transient download error): bx-orm exits 1, bx-ai succeeds.
    local INSTALL_CALLS_FILE="$TEST_TMP/install_calls_failing.txt"
    : > "$INSTALL_CALLS_FILE"
    install_module() {
        case "$1" in
            bx-orm) return 1 ;;
            *) printf '%s\n' "$1" >> "$INSTALL_CALLS_FILE" ;;
        esac
    }

    local output
    output=$(PATH="$BIN_JQ:$PATH" install_module_dependencies "$MODULE_DIR" "" 2>&1)
    local rc=$?

    assert_return_code 0 "$rc" "install_module_dependencies() does not abort when a dependency install fails"
    assert_contains "Warning: Failed to install dependency 'bx-orm'" "$output" "install_module_dependencies() warns about the failed dependency"
    assert_contains "bx-ai@2.1.0" "$(cat "$INSTALL_CALLS_FILE")" "install_module_dependencies() still installs the next dependency after a failure"

    . "$SITE_DIR/install-bx-module.sh"
    set +e
}

###########################################################################
# Tests for nested dependency installs
###########################################################################

# Builds a minimal fake jq (CI containers do not reliably ship the real one) that
# understands just what the nested-module code reads from single-line JSON files:
# dependency counts, dependency entries, and a module's "version".
make_fake_jq() {
    local DIR="$1"
    mkdir -p "$DIR"
    cat > "$DIR/jq" <<'FAKEJQ'
#!/bin/sh
for last; do :; done
deps=$(sed -n 's/.*"dependencies": *{\([^}]*\)}.*/\1/p' "$last" 2>/dev/null)
case "$*" in
	*length*)
		if [ -z "$deps" ]; then echo 0; else echo "$deps" | tr ',' '\n' | grep -c .; fi
		;;
	*to_entries*)
		[ -n "$deps" ] && echo "$deps" | tr ',' '\n' | sed 's/[" ]//g' | while IFS=: read -r k v; do
			printf '%s\t%s\n' "$k" "$v"
		done
		;;
	*.version*)
		sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$last" 2>/dev/null
		;;
	*) echo '{}' ;;
esac
FAKEJQ
    chmod +x "$DIR/jq"
}

test_install_module_dependencies_nests_when_requested() {
    run_test_group "install_module_dependencies nests dependencies inside the module"

    local ROOT="$TEST_TMP/nest-root"
    local MODULE_DIR="$ROOT/bx-sites"
    mkdir -p "$MODULE_DIR"
    echo '{"dependencies": {"bx-markdown": "*", "bx-yaml": "1.1.0"}}' > "$MODULE_DIR/box.json"

    local CALLS_FILE="$TEST_TMP/nest_calls.txt"
    : > "$CALLS_FILE"
    install_module() {
        printf '%s|%s|%s\n' "$1" "$MODULES_HOME" "$NESTED_INSTALL" >> "$CALLS_FILE"
    }

    local BIN_JQ="$TEST_TMP/bin-jqnest"
    make_fake_jq "$BIN_JQ"

    MODULES_HOME="$ROOT"
    PATH="$BIN_JQ:$PATH" install_module_dependencies "$MODULE_DIR" "bx-sites" true >/dev/null 2>&1

    local calls
    calls=$(cat "$CALLS_FILE")
    assert_contains "bx-markdown|$MODULE_DIR/modules|true" "$calls" "nested dependency installs into <module>/modules and flags a nested install"
    assert_contains "bx-yaml@1.1.0|$MODULE_DIR/modules|true" "$calls" "nested pinned dependency installs into <module>/modules"
    assert_equals "$ROOT" "$MODULES_HOME" "the caller's MODULES_HOME is not changed by a nested install"
    assert_equals "false" "$NESTED_INSTALL" "the caller's NESTED_INSTALL is not changed by a nested install"

    . "$SITE_DIR/install-bx-module.sh"
    set +e
}

test_install_module_dependencies_default_is_not_nested() {
    run_test_group "install_module_dependencies without NEST keeps the shared modules dir"

    local ROOT="$TEST_TMP/flat-root"
    local PROJECT_DIR="$TEST_TMP/flat-project"
    mkdir -p "$ROOT" "$PROJECT_DIR"
    echo '{"dependencies": {"bx-markdown": "*"}}' > "$PROJECT_DIR/box.json"

    local CALLS_FILE="$TEST_TMP/flat_calls.txt"
    : > "$CALLS_FILE"
    install_module() {
        printf '%s|%s|%s\n' "$1" "$MODULES_HOME" "$NESTED_INSTALL" >> "$CALLS_FILE"
    }

    local BIN_JQ="$TEST_TMP/bin-jqflat"
    make_fake_jq "$BIN_JQ"

    MODULES_HOME="$ROOT"
    PATH="$BIN_JQ:$PATH" install_module_dependencies "$PROJECT_DIR" "" >/dev/null 2>&1

    assert_contains "bx-markdown|$ROOT|false" "$(cat "$CALLS_FILE")" "project box.json dependencies still install into the shared modules dir"

    . "$SITE_DIR/install-bx-module.sh"
    set +e
}

test_install_module_dependencies_warns_about_duplicates() {
    run_test_group "install_module_dependencies warns when a nested dependency is a duplicate"

    local ROOT="$TEST_TMP/dup-root"
    local MODULE_DIR="$ROOT/bx-sites"
    mkdir -p "$MODULE_DIR" "$ROOT/bx-markdown"
    echo '{"version": "1.0.0"}' > "$ROOT/bx-markdown/box.json"
    echo '{"dependencies": {"bx-markdown": "*", "bx-yaml": "*"}}' > "$MODULE_DIR/box.json"

    install_module() { :; }

    local BIN_JQ="$TEST_TMP/bin-jqdup"
    make_fake_jq "$BIN_JQ"

    MODULES_HOME="$ROOT"
    local output
    output=$(PATH="$BIN_JQ:$PATH" install_module_dependencies "$MODULE_DIR" "bx-sites" true 2>&1)

    assert_contains "Dependency 'bx-markdown' is also installed at $ROOT/bx-markdown" "$output" "warns that the dependency already exists elsewhere"
    assert_not_contains "Dependency 'bx-yaml' is also installed" "$output" "does not warn about a dependency that is not duplicated"

    . "$SITE_DIR/install-bx-module.sh"
    set +e
}

test_list_modules_shows_nested_modules() {
    run_test_group "list_modules shows nested modules"

    local ROOT="$TEST_TMP/list-nested"
    mkdir -p "$ROOT/bx-sites/modules/bx-markdown/modules/bx-deep"
    echo '{"dependencies": {"bx-sites": "1.0.0"}}' > "$ROOT/box.json"
    echo '{"version": "1.0.0"}' > "$ROOT/bx-sites/box.json"
    echo '{"version": "2.0.0"}' > "$ROOT/bx-sites/modules/bx-markdown/box.json"
    echo '{"version": "3.0.0"}' > "$ROOT/bx-sites/modules/bx-markdown/modules/bx-deep/box.json"

    local BIN_JQ="$TEST_TMP/bin-jqlist"
    make_fake_jq "$BIN_JQ"

    local output
    output=$(PATH="$BIN_JQ:$PATH" list_modules "$ROOT" "Test" 2>&1)

    assert_contains "✓ bx-sites (1.0.0)" "$output" "lists the top-level module"
    assert_contains "  ↳ bx-markdown (2.0.0)" "$output" "lists a nested module indented under its parent"
    assert_contains "    ↳ bx-deep (3.0.0)" "$output" "lists a deeper nested module with a deeper indent"
}

test_nested_outdated_report_includes_nested_modules() {
    run_test_group "compute_outdated_report includes nested modules"

    local ROOT="$TEST_TMP/outdated-nested"
    mkdir -p "$ROOT/bx-sites/modules/bx-markdown"
    echo '{"dependencies": {"bx-sites": "1.0.0"}}' > "$ROOT/box.json"
    echo '{"version": "1.0.0"}' > "$ROOT/bx-sites/box.json"
    echo '{"version": "1.1.0"}' > "$ROOT/bx-sites/modules/bx-markdown/box.json"

    # Stub the network lookup: everything is at 2.0.0 on ForgeBox
    fetch_forgebox_latest_version() { echo "2.0.0"; }

    local BIN_JQ="$TEST_TMP/bin-jqreport"
    make_fake_jq "$BIN_JQ"

    local report
    report=$(PATH="$BIN_JQ:$PATH" compute_outdated_report "$ROOT")

    assert_contains "bx-sites${TAB}1.0.0${TAB}2.0.0${TAB}outdated${TAB}$ROOT${TAB}0" "$report" "reports the top-level module at depth 0"
    assert_contains "bx-markdown${TAB}1.1.0${TAB}2.0.0${TAB}outdated${TAB}$ROOT/bx-sites/modules${TAB}1" "$report" "reports the nested module at depth 1 with its parent modules dir"

    . "$SITE_DIR/install-bx-module.sh"
    set +e
}

test_apply_outdated_updates_reinstalls_nested_modules_in_place() {
    run_test_group "apply_outdated_updates reinstalls nested modules in their parent"

    local ROOT="$TEST_TMP/update-nested"
    mkdir -p "$ROOT/bx-sites/modules/bx-markdown" "$ROOT/bx-sites/modules/bx-yaml"
    echo '{"version": "1.0.0"}' > "$ROOT/bx-sites/modules/bx-markdown/box.json"
    echo '{"version": "2.0.0"}' > "$ROOT/bx-sites/modules/bx-yaml/box.json"

    local CALLS_FILE="$TEST_TMP/update_calls.txt"
    : > "$CALLS_FILE"
    install_module() {
        printf '%s|%s|%s\n' "$1" "$MODULES_HOME" "$NESTED_INSTALL" >> "$CALLS_FILE"
    }

    local BIN_JQ="$TEST_TMP/bin-jqapply"
    make_fake_jq "$BIN_JQ"

    MODULES_HOME="$ROOT"
    PATH="$BIN_JQ:$PATH" apply_outdated_updates "bx-sites|3.0.0|$ROOT|0
bx-markdown|2.0.0|$ROOT/bx-sites/modules|1
bx-yaml|2.0.0|$ROOT/bx-sites/modules|1
" >/dev/null 2>&1

    local calls
    calls=$(cat "$CALLS_FILE")
    assert_contains "bx-sites@3.0.0|$ROOT|false" "$calls" "updates a top-level module into the shared modules dir"
    assert_contains "bx-markdown@2.0.0|$ROOT/bx-sites/modules|true" "$calls" "updates a stale nested module inside its parent"
    assert_not_contains "bx-yaml@" "$calls" "skips a nested module that is already current"

    . "$SITE_DIR/install-bx-module.sh"
    set +e
}

###########################################################################
# Tests for install_module_completions / remove_module_completions
###########################################################################

test_install_module_completions_copies_declared_script() {
    run_test_group "install_module_completions with a declared completions script"

    local MODULE_DIR="$TEST_TMP/module-with-completions"
    mkdir -p "$MODULE_DIR/completions"
    echo '{"boxlang": {"completions": "completions/bx-demo.bash"}}' > "$MODULE_DIR/box.json"
    printf '#!/usr/bin/env bash\ncomplete -F _bx_demo_complete bx-demo\n' > "$MODULE_DIR/completions/bx-demo.bash"

    local BIN_JQ="$TEST_TMP/bin-jqcompl"
    mkdir -p "$BIN_JQ"
    cat > "$BIN_JQ/jq" <<'EOF'
#!/bin/sh
case "$*" in
	*completions*) echo "completions/bx-demo.bash" ;;
	*) echo "" ;;
esac
EOF
    chmod +x "$BIN_JQ/jq"

    local BOXLANG_HOME="$TEST_TMP/boxlang-home-completions"
    mkdir -p "$BOXLANG_HOME"

    (
        LOCAL_INSTALL=false
        BOXLANG_HOME="$BOXLANG_HOME"
        PATH="$BIN_JQ:$PATH"
        install_module_completions "$MODULE_DIR" "bx-demo"
    )

    local installed_file="$BOXLANG_HOME/completions/bx-demo.sh"
    assert_equals "1" "$([ -f "$installed_file" ] && echo 1 || echo 0)" "install_module_completions() copies the declared script into BOXLANG_HOME/completions"
    assert_contains "_bx_demo_complete" "$(cat "$installed_file" 2>/dev/null)" "install_module_completions() preserves the completion script's content"
}

test_install_module_completions_warns_when_declared_file_missing() {
    run_test_group "install_module_completions with a missing declared script"

    local MODULE_DIR="$TEST_TMP/module-with-missing-completions"
    mkdir -p "$MODULE_DIR"
    echo '{"boxlang": {"completions": "completions/does-not-exist.bash"}}' > "$MODULE_DIR/box.json"

    local BIN_JQ="$TEST_TMP/bin-jqcomplmissing"
    mkdir -p "$BIN_JQ"
    cat > "$BIN_JQ/jq" <<'EOF'
#!/bin/sh
case "$*" in
	*completions*) echo "completions/does-not-exist.bash" ;;
	*) echo "" ;;
esac
EOF
    chmod +x "$BIN_JQ/jq"

    local BOXLANG_HOME="$TEST_TMP/boxlang-home-completions-missing"
    mkdir -p "$BOXLANG_HOME"

    local output rc
    output=$(
        LOCAL_INSTALL=false
        BOXLANG_HOME="$BOXLANG_HOME"
        PATH="$BIN_JQ:$PATH"
        install_module_completions "$MODULE_DIR" "bx-demo" 2>&1
    )
    rc=$?

    assert_return_code 0 "$rc" "install_module_completions() does not fail when the declared file is missing"
    assert_contains "was not found in the module" "$output" "install_module_completions() warns when the declared completions file is missing"
    assert_equals "0" "$([ -f "$BOXLANG_HOME/completions/bx-demo.sh" ] && echo 1 || echo 0)" "install_module_completions() installs nothing when the declared file is missing"
}

test_install_module_completions_noop_without_declaration() {
    run_test_group "install_module_completions without a boxlang.completions declaration"

    local MODULE_DIR="$TEST_TMP/module-without-completions"
    mkdir -p "$MODULE_DIR"
    echo '{"name": "bx-demo"}' > "$MODULE_DIR/box.json"

    local BIN_JQ="$TEST_TMP/bin-jqcomplnone"
    mkdir -p "$BIN_JQ"
    cat > "$BIN_JQ/jq" <<'EOF'
#!/bin/sh
echo ""
EOF
    chmod +x "$BIN_JQ/jq"

    local BOXLANG_HOME="$TEST_TMP/boxlang-home-completions-none"
    mkdir -p "$BOXLANG_HOME"

    (
        LOCAL_INSTALL=false
        BOXLANG_HOME="$BOXLANG_HOME"
        PATH="$BIN_JQ:$PATH"
        install_module_completions "$MODULE_DIR" "bx-demo"
    )

    assert_equals "0" "$([ -d "$BOXLANG_HOME/completions" ] && echo 1 || echo 0)" "install_module_completions() creates no completions directory without a declaration"
}

test_remove_module_completions_deletes_installed_script() {
    run_test_group "remove_module_completions"

    local BOXLANG_HOME="$TEST_TMP/boxlang-home-completions-remove"
    mkdir -p "$BOXLANG_HOME/completions"
    echo 'complete -F _bx_demo_complete bx-demo' > "$BOXLANG_HOME/completions/bx-demo.sh"

    (
        LOCAL_INSTALL=false
        BOXLANG_HOME="$BOXLANG_HOME"
        remove_module_completions "bx-demo"
    )

    assert_equals "0" "$([ -f "$BOXLANG_HOME/completions/bx-demo.sh" ] && echo 1 || echo 0)" "remove_module_completions() deletes the installed completion script"
}

###########################################################################
# Tests for `main` with no arguments (project box.json auto-install)
###########################################################################

test_main_no_args_installs_project_box_json_dependencies() {
    run_test_group "main() with no arguments and a project box.json"

    local PROJECT_DIR="$TEST_TMP/project-with-box-json"
    mkdir -p "$PROJECT_DIR"
    echo '{"name": "my-app", "dependencies": {"bx-orm": "*"}}' > "$PROJECT_DIR/box.json"

    local CALLS_FILE="$TEST_TMP/main_no_args_calls.txt"
    : > "$CALLS_FILE"

    local output rc
    output=$(
        # main() starts with a real preflight_check, which may try to
        # apt-install curl/unzip/jq on a container lacking them - stub it out
        # since these tests only exercise the box.json dispatch logic.
        preflight_check() { return 0; }
        install_module_dependencies() {
            printf '%s\t%s\n' "$1" "$2" >> "$CALLS_FILE"
        }
        cd "$PROJECT_DIR" && main 2>&1
    )
    rc=$?

    assert_return_code 0 "$rc" "main() with no args and a box.json exits 0"
    assert_contains "Found box.json" "$output" "main() reports finding the project box.json"
    assert_contains "$PROJECT_DIR" "$(cat "$CALLS_FILE")" "main() installs dependencies from the project's box.json directory"
}

test_main_no_args_without_box_json_shows_usage_error() {
    run_test_group "main() with no arguments and no box.json"

    local EMPTY_DIR="$TEST_TMP/project-without-box-json"
    mkdir -p "$EMPTY_DIR"

    local output rc
    output=$(
        preflight_check() { return 0; }
        cd "$EMPTY_DIR" && main 2>&1
    )
    rc=$?

    assert_return_code 1 "$rc" "main() with no args and no box.json exits 1"
    assert_contains "No module(s) specified" "$output" "main() falls back to the usage error when no box.json exists"
}

test_main_local_flag_only_installs_project_box_json_dependencies_locally() {
    run_test_group "main() with only --local and a project box.json"

    local PROJECT_DIR="$TEST_TMP/project-local-box-json"
    mkdir -p "$PROJECT_DIR"
    echo '{"dependencies": {"bx-orm": "*"}}' > "$PROJECT_DIR/box.json"

    # Fake jq reporting one dependency, used by the real install_module_dependencies
    local BIN_JQ="$TEST_TMP/bin-jqlocal"
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

    local CALLS_FILE="$TEST_TMP/main_local_calls.txt"
    : > "$CALLS_FILE"

    local output rc
    output=$(
        preflight_check() { return 0; }
        install_module() {
            printf 'module=%s MODULES_HOME=%s LOCAL_INSTALL=%s\n' "$1" "$MODULES_HOME" "$LOCAL_INSTALL" >> "$CALLS_FILE"
        }
        cd "$PROJECT_DIR" && PATH="$BIN_JQ:$PATH" main --local 2>&1
    )
    rc=$?

    assert_return_code 0 "$rc" "main() with --local only and a box.json exits 0"
    assert_contains "Found box.json" "$output" "main() reports finding the project box.json under --local"
    assert_contains "MODULES_HOME=$PROJECT_DIR/boxlang_modules" "$(cat "$CALLS_FILE")" "main() installs project dependencies into the local boxlang_modules directory"
    assert_contains "LOCAL_INSTALL=true" "$(cat "$CALLS_FILE")" "main() keeps LOCAL_INSTALL true when installing project dependencies via --local"
}

run_all_tests() {
    test_list_modules_jq_failure
    test_list_modules_empty_manifest
    test_list_modules_with_installed_modules
    test_install_module_dependencies_installs_wildcard_and_pinned_versions
    test_install_module_dependencies_installs_be_and_snapshot_versions
    test_install_module_dependencies_no_box_json
    test_install_module_dependencies_skips_circular_dependency
    test_install_module_dependencies_skips_non_forgebox_maven_dependency
    test_install_module_dependencies_continues_after_a_failed_dependency
    test_install_module_dependencies_nests_when_requested
    test_install_module_dependencies_default_is_not_nested
    test_install_module_dependencies_warns_about_duplicates
    test_list_modules_shows_nested_modules
    test_nested_outdated_report_includes_nested_modules
    test_apply_outdated_updates_reinstalls_nested_modules_in_place
    test_install_module_completions_copies_declared_script
    test_install_module_completions_warns_when_declared_file_missing
    test_install_module_completions_noop_without_declaration
    test_remove_module_completions_deletes_installed_script
    test_main_no_args_installs_project_box_json_dependencies
    test_main_no_args_without_box_json_shows_usage_error
    test_main_local_flag_only_installs_project_box_json_dependencies_locally

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
