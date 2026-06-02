#!/bin/bash
# Test suite for bvm.sh use command behavior

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$TEST_DIR")")"
BVM_SCRIPT="$PROJECT_ROOT/src/bvm.sh"

TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

assert_return_code() {
    local expected_code="$1"
    local actual_code="$2"
    local test_name="$3"

    if [ "$expected_code" -eq "$actual_code" ]; then
        echo "✅ PASS: $test_name"
        ((TESTS_PASSED+=1))
    else
        echo "❌ FAIL: $test_name"
        echo "   Expected return code: $expected_code"
        echo "   Actual return code:   $actual_code"
        FAILED_TESTS+=("$test_name")
        ((TESTS_FAILED+=1))
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    if [ "$expected" = "$actual" ]; then
        echo "✅ PASS: $test_name"
        ((TESTS_PASSED+=1))
    else
        echo "❌ FAIL: $test_name"
        echo "   Expected: '$expected'"
        echo "   Actual:   '$actual'"
        FAILED_TESTS+=("$test_name")
        ((TESTS_FAILED+=1))
    fi
}

assert_true() {
    local condition="$1"
    local test_name="$2"

    if eval "$condition"; then
        echo "✅ PASS: $test_name"
        ((TESTS_PASSED+=1))
    else
        echo "❌ FAIL: $test_name"
        FAILED_TESTS+=("$test_name")
        ((TESTS_FAILED+=1))
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
#!/bin/bash
echo "MINGW64_NT-10.0"
EOF
    chmod +x "$mock_bin/uname"

    # Mock powershell to emulate junction creation
    cat > "$mock_bin/powershell" <<'EOF'
#!/bin/bash
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
        bash "$BVM_SCRIPT" use 1.12.0 2>&1
    ) || exit_code=$?
    exit_code="${exit_code:-0}"

    assert_return_code 0 "$exit_code" "bvm use exits successfully"
    assert_true "[ -L \"$test_bvm_home/current\" ]" "current is a link (not a plain directory)"
    local linked_version=""
    if [ -L "$test_bvm_home/current" ]; then
        linked_version="$(basename "$(readlink "$test_bvm_home/current")")"
    fi
    assert_equals "1.12.0" "$linked_version" "current points to selected version"
    assert_true "[[ \"$output\" == *\"Now using BoxLang 1.12.0\"* ]]" "bvm use reports selected version"

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
        for test in "${FAILED_TESTS[@]}"; do
            echo "   • $test"
        done
        return 1
    fi
}

main() {
    echo "🧪 BVM use command test suite"
    echo "═══════════════════════════════════════════════════════════════"

    test_use_replaces_directory_current_on_windows_shell

    print_test_summary
}

main "$@"
