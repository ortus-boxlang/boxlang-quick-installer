#!/bin/sh
# IMPORTANT: This script intentionally targets POSIX /bin/sh.
# Do not change the shebang back to Bash or reintroduce Bash-only syntax.
# It must remain compatible with Alpine BusyBox ash and standard /bin/sh.

# Test suite for bvm.sh use command behavior

set -e

TEST_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$TEST_DIR")")"
BVM_SCRIPT="$PROJECT_ROOT/src/bvm.sh"

TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=""

assert_return_code() {
    local expected_code="$1"
    local actual_code="$2"
    local test_name="$3"

    if [ "$expected_code" -eq "$actual_code" ]; then
        echo "✅ PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "❌ FAIL: $test_name"
        echo "   Expected return code: $expected_code"
        echo "   Actual return code:   $actual_code"
        FAILED_TESTS="$FAILED_TESTS\n$test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    if [ "$expected" = "$actual" ]; then
        echo "✅ PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "❌ FAIL: $test_name"
        echo "   Expected: '$expected'"
        echo "   Actual:   '$actual'"
        FAILED_TESTS="$FAILED_TESTS\n$test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_true() {
    local condition="$1"
    local test_name="$2"

    if eval "$condition"; then
        echo "✅ PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "❌ FAIL: $test_name"
        FAILED_TESTS="$FAILED_TESTS\n$test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

run_test_group() {
    local group_name="$1"
    echo ""
    echo "🧪 Testing: $group_name"
    echo "────────────────────────────────────────────────────────────"
}

test_use_replaces_directory_current_on_windows_shell() {
    run_test_group "bvm use replaces directory current in Windows shell"

    local sandbox
    sandbox="$(mktemp -d)"
    local test_home="$sandbox/home"
    local test_bvm_home="$test_home/.bvm"
    local mock_bin="$sandbox/mock-bin"
    mkdir -p "$test_bvm_home/versions/1.12.0/bin" "$mock_bin"

    # Create an existing directory at ~/.bvm/current to reproduce the reported issue
    mkdir -p "$test_bvm_home/current"
    echo "stale" > "$test_bvm_home/current/stale.txt"

    # Mock uname to simulate Git Bash on Windows
    cat > "$mock_bin/uname" <<'EOF'
#!/bin/sh
echo "MINGW64_NT-10.0"
EOF
    chmod +x "$mock_bin/uname"

    # Mock powershell to emulate junction creation
    cat > "$mock_bin/powershell" <<'EOF'
#!/bin/sh
rm -rf "$BVM_HOME/current"
ln -s "$BVM_HOME/versions/1.12.0" "$BVM_HOME/current"
EOF
    chmod +x "$mock_bin/powershell"

    local output
    local exit_code
    output=$(
        HOME="$test_home" \
        BVM_HOME="$test_bvm_home" \
        TERM="xterm-256color" \
        PATH="$mock_bin:$PATH" \
        sh "$BVM_SCRIPT" use 1.12.0 2>&1
    ) || exit_code=$?
    exit_code="${exit_code:-0}"
	if [ "$exit_code" -ne 0 ]; then
		echo "$output"
	fi

    assert_return_code 0 "$exit_code" "bvm use exits successfully"
    assert_true "[ -L \"$test_bvm_home/current\" ]" "current is a link (not a plain directory)"
    local linked_version=""
    if [ -L "$test_bvm_home/current" ]; then
        linked_version="$(basename "$(readlink "$test_bvm_home/current")")"
    fi
    assert_equals "1.12.0" "$linked_version" "current points to selected version"
    case "$output" in
        *"Now using BoxLang 1.12.0"*) assert_true true "bvm use reports selected version" ;;
        *) assert_true false "bvm use reports selected version" ;;
    esac

    rm -rf "$sandbox"
}

test_checksum_verifies_zip_under_posix_sh() {
    run_test_group "BVM ZIP verification under POSIX sh"

    local sandbox
    sandbox="$(mktemp -d)"
    local fixture_dir="$sandbox/bvm"
    local fixture_script="$fixture_dir/bvm.sh"
    local archive="$sandbox/runtime.zip"
    local output
    local exit_code=0
    mkdir -p "$fixture_dir/helpers"
    sed '$d' "$BVM_SCRIPT" > "$fixture_script"
    cp "$PROJECT_ROOT/src/helpers/helpers.sh" "$fixture_dir/helpers/helpers.sh"
    printf 'test archive\n' > "$sandbox/archive-content"
    zip -q "$archive" "$sandbox/archive-content"

    printf '\nverify_download_with_checksum "%s" "https://invalid.example" 1\n' "$archive" >> "$fixture_script"
    output=$(BVM_HOME="$sandbox/home" sh "$fixture_script" 2>&1) || exit_code=$?
    assert_return_code 0 "$exit_code" "BVM ZIP checksum verification runs under POSIX sh"
    case "$output" in
        *"[[: not found"*) assert_true false "BVM ZIP verification does not use Bash conditionals" ;;
        *) assert_true true "BVM ZIP verification does not use Bash conditionals" ;;
    esac

    rm -rf "$sandbox"
}

print_test_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "📊 Test Summary"
    echo "═══════════════════════════════════════════════════════════════"
    echo "✅ Passed: $TESTS_PASSED"
    echo "❌ Failed: $TESTS_FAILED"
    echo "📈 Total:  $((TESTS_PASSED + TESTS_FAILED))"

    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo ""
        echo "🎉 All tests passed!"
        return 0
    else
        echo ""
        echo "💥 Failed tests:"
        printf '%b\n' "$FAILED_TESTS" | while IFS= read -r test; do
            [ -n "$test" ] && echo "   • $test"
        done
        return 1
    fi
}

main() {
    echo "🧪 BVM use command test suite"
    echo "═══════════════════════════════════════════════════════════════"

    test_use_replaces_directory_current_on_windows_shell
    test_checksum_verifies_zip_under_posix_sh

    print_test_summary
}

main "$@"
