#!/bin/bash
# Mock tests for preflight_check() function
# Author: BoxLang Team
# License: Apache License, Version 2.0

set -e

# Get the directory of this script
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$TEST_DIR")")"
HELPERS_FILE="$PROJECT_ROOT/src/helpers/helpers.sh"

# Source the helpers file
if [ -f "$HELPERS_FILE" ]; then
    source "$HELPERS_FILE"
else
    echo "❌ Error: helpers.sh not found at $HELPERS_FILE"
    exit 1
fi

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0

###########################################################################
# Mock Testing Framework
###########################################################################

# Create mock command directory
MOCK_DIR="/tmp/bvm_test_mocks_$$"
mkdir -p "$MOCK_DIR"

# Function to create mock commands
create_mock_command() {
    local command_name="$1"
    local return_code="${2:-0}"
    local output="${3:-}"

    cat > "$MOCK_DIR/$command_name" << EOF
#!/bin/bash
if [ -n "$output" ]; then
    echo "$output"
fi
exit $return_code
EOF
    chmod +x "$MOCK_DIR/$command_name"
}

# Function to setup mock environment
setup_mock_environment() {
    export PATH="$MOCK_DIR:$PATH"
}

# Function to cleanup mock environment
cleanup_mock_environment() {
    export PATH="${PATH#$MOCK_DIR:}"
    rm -rf "$MOCK_DIR"
}

# Test assertion function
assert_preflight_result() {
    local expected_code="$1"
    local test_name="$2"

    # Capture output and return code
    local output
    local return_code
    output=$(preflight_check 2>&1)
    return_code=$?

    if [ "$return_code" -eq "$expected_code" ]; then
        echo "✅ PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo "❌ FAIL: $test_name"
        echo "   Expected return code: $expected_code"
        echo "   Actual return code:   $return_code"
        echo "   Output: $output"
        ((TESTS_FAILED++))
        return 1
    fi
}

###########################################################################
# Tests for preflight_check() function
###########################################################################

test_preflight_check_all_deps_present() {
    echo "🧪 Testing: preflight_check() with all dependencies present"
    echo "─────────────────────────────────────────────────────────────"

    setup_mock_environment

    # Create all required mock commands
    create_mock_command "curl" 0
    create_mock_command "unzip" 0
    create_mock_command "jq" 0

    # Platform specific mocks
    if [ "$(uname)" = "Darwin" ]; then
        create_mock_command "brew" 0
        create_mock_command "shasum" 0
    else
        create_mock_command "sha256sum" 0
    fi

    # Create mock Java that returns version 21
    create_mock_command "java" 0 'openjdk version "21.0.1" 2023-10-17'

    # Override check_java_version to return success
    check_java_version() {
        return 0
    }

    assert_preflight_result 0 "preflight_check() passes with all dependencies present"

    cleanup_mock_environment
}

test_preflight_check_missing_curl() {
    echo ""
    echo "🧪 Testing: preflight_check() with missing curl"
    echo "─────────────────────────────────────────────────────────────"

    setup_mock_environment

    # Create all required mock commands except curl
    create_mock_command "unzip" 0
    create_mock_command "jq" 0

    # Platform specific mocks
    if [ "$(uname)" = "Darwin" ]; then
        create_mock_command "brew" 0
        create_mock_command "shasum" 0
    else
        create_mock_command "sha256sum" 0
    fi

    assert_preflight_result 1 "preflight_check() fails with missing curl"

    cleanup_mock_environment
}

test_preflight_check_missing_jq() {
    echo ""
    echo "🧪 Testing: preflight_check() with missing jq"
    echo "─────────────────────────────────────────────────────────────"

    setup_mock_environment

    # Create all required mock commands except jq
    create_mock_command "curl" 0
    create_mock_command "unzip" 0

    # Platform specific mocks
    if [ "$(uname)" = "Darwin" ]; then
        create_mock_command "brew" 0
        create_mock_command "shasum" 0
    else
        create_mock_command "sha256sum" 0
    fi

    assert_preflight_result 1 "preflight_check() fails with missing jq"

    cleanup_mock_environment
}

test_preflight_check_missing_sha_tools() {
    echo ""
    echo "🧪 Testing: preflight_check() with missing SHA tools"
    echo "─────────────────────────────────────────────────────────────"

    setup_mock_environment

    # Create basic tools but not SHA tools
    create_mock_command "curl" 0
    create_mock_command "unzip" 0
    create_mock_command "jq" 0

    # Platform specific mocks (but missing SHA tools)
    if [ "$(uname)" = "Darwin" ]; then
        create_mock_command "brew" 0
        # Don't create shasum
    else
        # Don't create sha256sum
        true
    fi

    assert_preflight_result 1 "preflight_check() fails with missing SHA tools"

    cleanup_mock_environment
}

test_preflight_check_macos_missing_brew() {
    if [ "$(uname)" != "Darwin" ]; then
        echo ""
        echo "⏭️  Skipping macOS-specific test (not running on macOS)"
        return 0
    fi

    echo ""
    echo "🧪 Testing: preflight_check() on macOS with missing Homebrew"
    echo "─────────────────────────────────────────────────────────────"

    setup_mock_environment

    # Create all other tools but not brew
    create_mock_command "curl" 0
    create_mock_command "unzip" 0
    create_mock_command "jq" 0
    create_mock_command "shasum" 0

    # Don't create brew command

    assert_preflight_result 1 "preflight_check() fails on macOS without Homebrew"

    cleanup_mock_environment
}

test_preflight_check_java_failure() {
    echo ""
    echo "🧪 Testing: preflight_check() with Java check failure"
    echo "─────────────────────────────────────────────────────────────"

    setup_mock_environment

    # Create all required mock commands
    create_mock_command "curl" 0
    create_mock_command "unzip" 0
    create_mock_command "jq" 0

    # Platform specific mocks
    if [ "$(uname)" = "Darwin" ]; then
        create_mock_command "brew" 0
        create_mock_command "shasum" 0
    else
        create_mock_command "sha256sum" 0
    fi

    # Override check_java_version to return failure
    check_java_version() {
        return 1
    }

    assert_preflight_result 1 "preflight_check() fails when Java check fails"

    cleanup_mock_environment
}

###########################################################################
# Test Runner
###########################################################################

run_preflight_tests() {
    echo "🧪 BoxLang Helpers Preflight Check Test Suite"
    echo "═══════════════════════════════════════════════════════════════════"

    # Run all test cases
    test_preflight_check_all_deps_present
    test_preflight_check_missing_curl
    test_preflight_check_missing_jq
    test_preflight_check_missing_sha_tools
    test_preflight_check_macos_missing_brew
    test_preflight_check_java_failure

    # Print summary
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "📊 Preflight Test Summary"
    echo "═══════════════════════════════════════════════════════════════════"
    echo "✅ Tests Passed: $TESTS_PASSED"
    echo "❌ Tests Failed: $TESTS_FAILED"
    echo "📈 Total Tests:  $((TESTS_PASSED + TESTS_FAILED))"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo ""
        echo "🎉 All preflight tests passed! ✨"
        echo ""
        exit 0
    else
        echo ""
        echo "💥 Some preflight tests failed!"
        echo ""
        exit 1
    fi
}

# Cleanup function
cleanup() {
    cleanup_mock_environment 2>/dev/null || true
}

# Set up cleanup trap
trap cleanup EXIT

# Run tests if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_preflight_tests
fi
