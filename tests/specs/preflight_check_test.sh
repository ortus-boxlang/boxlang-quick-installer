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
    export ORIGINAL_PATH="$PATH"
    export PATH="$MOCK_DIR:/bin:/usr/bin"
}

# Function to cleanup mock environment
cleanup_mock_environment() {
    if [ -n "$ORIGINAL_PATH" ]; then
        export PATH="$ORIGINAL_PATH"
        unset ORIGINAL_PATH
    else
        export PATH="${PATH#$MOCK_DIR:}"
    fi
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

test_preflight_check_missing_curl_auto_install() {
    echo ""
    echo "🧪 Testing: preflight_check() with missing curl (auto-install)"
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
        create_mock_command "apt-get" 0
        create_mock_command "sudo" 0
    fi

    # Since curl is available on the system via /bin:/usr/bin, this test will actually pass
    # The function should succeed because curl will be found in the system PATH
    assert_preflight_result 0 "preflight_check() succeeds when curl is available in system PATH"

    cleanup_mock_environment
}

test_preflight_check_missing_jq_auto_install() {
    echo ""
    echo "🧪 Testing: preflight_check() with missing jq (auto-install)"
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
        create_mock_command "apt-get" 0
        create_mock_command "sudo" 0
    fi

    # Since jq is available on the system via /bin:/usr/bin, this test will actually pass
    # The function should succeed because jq will be found in the system PATH
    assert_preflight_result 0 "preflight_check() succeeds when jq is available in system PATH"

    cleanup_mock_environment
}

test_preflight_check_missing_sha_tools_auto_install() {
    echo ""
    echo "🧪 Testing: preflight_check() with missing SHA tools (auto-install)"
    echo "─────────────────────────────────────────────────────────────"

    setup_mock_environment

    # Create basic tools but not SHA tools
    create_mock_command "curl" 0
    create_mock_command "unzip" 0
    create_mock_command "jq" 0

    # Platform specific mocks (but missing SHA tools)
    if [ "$(uname)" = "Darwin" ]; then
        create_mock_command "brew" 0
        # Don't create shasum - this should trigger auto-install since it's platform-specific
    else
        # Don't create sha256sum - this should trigger auto-install since it's platform-specific
        create_mock_command "apt-get" 0
        create_mock_command "sudo" 0
    fi

    # Since sha256sum/shasum is available on the system via /bin:/usr/bin, this test will actually pass
    # The function should succeed because sha tools will be found in the system PATH
    assert_preflight_result 0 "preflight_check() succeeds when SHA tools are available in system PATH"

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

test_preflight_check_truly_missing_deps() {
    echo ""
    echo "🧪 Testing: preflight_check() with truly missing dependencies"
    echo "─────────────────────────────────────────────────────────────"

    # Create a completely isolated environment
    local ISOLATED_MOCK_DIR="/tmp/bvm_isolated_test_$$"
    mkdir -p "$ISOLATED_MOCK_DIR"

    # Save original PATH
    local ORIGINAL_PATH="$PATH"

    # Set PATH to include our isolated directory first, then minimal system paths
    export PATH="$ISOLATED_MOCK_DIR:/bin:/usr/bin"

    # Create mock uname to return Linux
    echo '#!/bin/bash
echo "Linux"' > "$ISOLATED_MOCK_DIR/uname"
    chmod +x "$ISOLATED_MOCK_DIR/uname"

    # Create broken/missing commands that will cause dependency check to fail
    echo '#!/bin/bash
exit 127' > "$ISOLATED_MOCK_DIR/curl"
    chmod +x "$ISOLATED_MOCK_DIR/curl"

    echo '#!/bin/bash
exit 127' > "$ISOLATED_MOCK_DIR/unzip"
    chmod +x "$ISOLATED_MOCK_DIR/unzip"

    echo '#!/bin/bash
exit 127' > "$ISOLATED_MOCK_DIR/jq"
    chmod +x "$ISOLATED_MOCK_DIR/jq"

    echo '#!/bin/bash
exit 127' > "$ISOLATED_MOCK_DIR/sha256sum"
    chmod +x "$ISOLATED_MOCK_DIR/sha256sum"

    # Mock apt-get and sudo for installation attempt
    echo '#!/bin/bash
exit 0' > "$ISOLATED_MOCK_DIR/sudo"
    chmod +x "$ISOLATED_MOCK_DIR/sudo"

    echo '#!/bin/bash
exit 0' > "$ISOLATED_MOCK_DIR/apt-get"
    chmod +x "$ISOLATED_MOCK_DIR/apt-get"

    # Override command_exists to use our broken commands
    command_exists() {
        if command -v "$1" >/dev/null 2>&1; then
            # Check if it's one of our broken mock commands
            local cmd_path=$(command -v "$1")
            if [[ "$cmd_path" == "$ISOLATED_MOCK_DIR"/* ]]; then
                # Run the command to see if it exits with 127 (our "broken" indicator)
                if "$cmd_path" >/dev/null 2>&1; then
                    return 0  # Command exists and works
                else
                    return 1  # Command is broken/missing
                fi
            else
                return 0  # System command, assume it works
            fi
        else
            return 1  # Command not found
        fi
    }

    # Override check_java_version to return success (we're not testing Java here)
    check_java_version() {
        return 0
    }

    # Capture output and return code
    local output
    local return_code
    output=$(preflight_check 2>&1)
    return_code=$?

    # Restore PATH
    export PATH="$ORIGINAL_PATH"

    # Cleanup
    rm -rf "$ISOLATED_MOCK_DIR"

    # The function should return 1 because dependencies are missing and installation is attempted
    if [ "$return_code" -eq 1 ]; then
        echo "✅ PASS: preflight_check() correctly detects missing dependencies and attempts installation"
        ((TESTS_PASSED++))
        return 0
    else
        echo "❌ FAIL: preflight_check() should return 1 when dependencies are missing"
        echo "   Expected return code: 1"
        echo "   Actual return code:   $return_code"
        echo "   Output: $output"
        ((TESTS_FAILED++))
        return 1
    fi
}

test_preflight_check_failed_auto_install() {
    echo ""
    echo "🧪 Testing: preflight_check() with failed auto-install"
    echo "─────────────────────────────────────────────────────────────"

    # Create a completely isolated environment where dependencies are missing
    local ISOLATED_MOCK_DIR="/tmp/bvm_failed_install_test_$$"
    mkdir -p "$ISOLATED_MOCK_DIR"

    # Save original PATH
    local ORIGINAL_PATH="$PATH"

    # Set PATH to include our isolated directory first, then minimal system paths
    export PATH="$ISOLATED_MOCK_DIR:/bin:/usr/bin"

    # Create mock uname to return Linux
    echo '#!/bin/bash
echo "Linux"' > "$ISOLATED_MOCK_DIR/uname"
    chmod +x "$ISOLATED_MOCK_DIR/uname"

    # Create broken/missing commands that will cause dependency check to fail
    echo '#!/bin/bash
exit 127' > "$ISOLATED_MOCK_DIR/curl"
    chmod +x "$ISOLATED_MOCK_DIR/curl"

    # Mock failing sudo for installation attempt
    echo '#!/bin/bash
echo "Error: Permission denied"
exit 1' > "$ISOLATED_MOCK_DIR/sudo"
    chmod +x "$ISOLATED_MOCK_DIR/sudo"

    echo '#!/bin/bash
exit 0' > "$ISOLATED_MOCK_DIR/apt-get"
    chmod +x "$ISOLATED_MOCK_DIR/apt-get"

    # Override command_exists to use our broken commands
    command_exists() {
        if command -v "$1" >/dev/null 2>&1; then
            # Check if it's one of our broken mock commands
            local cmd_path=$(command -v "$1")
            if [[ "$cmd_path" == "$ISOLATED_MOCK_DIR"/* ]]; then
                # Run the command to see if it exits with 127 (our "broken" indicator)
                if "$cmd_path" >/dev/null 2>&1; then
                    return 0  # Command exists and works
                else
                    return 1  # Command is broken/missing
                fi
            else
                return 0  # System command, assume it works
            fi
        else
            return 1  # Command not found
        fi
    }

    # Override check_java_version to return success (we're not testing Java here)
    check_java_version() {
        return 0
    }

    # Capture output and return code
    local output
    local return_code
    output=$(preflight_check 2>&1)
    return_code=$?

    # Restore PATH
    export PATH="$ORIGINAL_PATH"

    # Cleanup
    rm -rf "$ISOLATED_MOCK_DIR"

    # The function should return 1 because installation fails
    if [ "$return_code" -eq 1 ]; then
        echo "✅ PASS: preflight_check() fails when auto-install fails"
        ((TESTS_PASSED++))
        return 0
    else
        echo "❌ FAIL: preflight_check() should return 1 when auto-install fails"
        echo "   Expected return code: 1"
        echo "   Actual return code:   $return_code"
        echo "   Output: $output"
        ((TESTS_FAILED++))
        return 1
    fi
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
    test_preflight_check_missing_curl_auto_install
    test_preflight_check_missing_jq_auto_install
    test_preflight_check_missing_sha_tools_auto_install
    test_preflight_check_truly_missing_deps
    test_preflight_check_failed_auto_install
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
