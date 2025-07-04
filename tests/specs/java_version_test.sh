#!/bin/bash
# Comprehensive tests for check_java_version() function
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
MOCK_DIR="/tmp/bvm_java_test_mocks_$$"
mkdir -p "$MOCK_DIR"

# Function to create mock Java commands with specific version outputs
create_mock_java() {
    local java_path="$1"
    local version_output="$2"
    local return_code="${3:-0}"

    mkdir -p "$(dirname "$java_path")"
    cat > "$java_path" << EOF
#!/bin/bash
if [ "\$1" = "-version" ]; then
    echo '$version_output' >&2
    exit $return_code
else
    echo "Mock Java command"
    exit 0
fi
EOF
    chmod +x "$java_path"
}

# Function to setup mock environment
setup_mock_environment() {
    export PATH="$MOCK_DIR:$PATH"
    # Clear any existing JAVA_HOME for testing
    export JAVA_HOME_BACKUP="$JAVA_HOME"
    unset JAVA_HOME
}

# Function to cleanup mock environment
cleanup_mock_environment() {
    export PATH="${PATH#$MOCK_DIR:}"
    export JAVA_HOME="$JAVA_HOME_BACKUP"
    unset JAVA_HOME_BACKUP
    rm -rf "$MOCK_DIR"
}

# Test assertion function
assert_java_check_result() {
    local expected_code="$1"
    local test_name="$2"

    # Capture output and return code
    local output
    local return_code
    output=$(check_java_version 2>&1)
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
# Tests for Java Version Detection
###########################################################################

test_java_version_21() {
    echo "🧪 Testing: Java 21 detection"
    echo "─────────────────────────────────────────────────────────────"

    setup_mock_environment

    # Create Java 21 mock
    create_mock_java "$MOCK_DIR/java" 'openjdk version "21.0.1" 2023-10-17
OpenJDK Runtime Environment (build 21.0.1+12-29)
OpenJDK 64-Bit Server VM (build 21.0.1+12-29, mixed mode, sharing)'

    assert_java_check_result 0 "check_java_version() detects Java 21 successfully"

    cleanup_mock_environment
}

test_java_version_17_insufficient() {
    echo ""
    echo "🧪 Testing: Java 17 detection (insufficient)"
    echo "─────────────────────────────────────────────────────────────"

    setup_mock_environment

    # Create Java 17 mock (should fail as it's < 21)
    create_mock_java "$MOCK_DIR/java" 'openjdk version "17.0.5" 2022-10-18
OpenJDK Runtime Environment (build 17.0.5+8-Ubuntu-1ubuntu1)
OpenJDK 64-Bit Server VM (build 17.0.5+8-Ubuntu-1ubuntu1, mixed mode, sharing)'

    assert_java_check_result 1 "check_java_version() fails for Java 17 (insufficient version)"

    cleanup_mock_environment
}

test_java_version_8_old_format() {
    echo ""
    echo "🧪 Testing: Java 8 detection (old 1.x format)"
    echo "─────────────────────────────────────────────────────────────"

    setup_mock_environment

    # Create Java 8 mock with old 1.x format
    create_mock_java "$MOCK_DIR/java" 'openjdk version "1.8.0_345" 2022-08-11
OpenJDK Runtime Environment (build 1.8.0_345-b01)
OpenJDK 64-Bit Server VM (build 25.345-b01, mixed mode)'

    assert_java_check_result 1 "check_java_version() fails for Java 8 (insufficient version)"

    cleanup_mock_environment
}

test_java_version_25_future() {
    echo ""
    echo "🧪 Testing: Java 25 detection (future version)"
    echo "─────────────────────────────────────────────────────────────"

    setup_mock_environment

    # Create Java 25 mock (future version, should pass)
    create_mock_java "$MOCK_DIR/java" 'openjdk version "25.0.0" 2025-03-15
OpenJDK Runtime Environment (build 25.0.0+10-ea)
OpenJDK 64-Bit Server VM (build 25.0.0+10-ea, mixed mode)'

    assert_java_check_result 0 "check_java_version() accepts future Java versions (25)"

    cleanup_mock_environment
}

test_java_no_command() {
    echo ""
    echo "🧪 Testing: No Java command available"
    echo "─────────────────────────────────────────────────────────────"

    setup_mock_environment

    # Don't create any Java mock - should fail

    assert_java_check_result 1 "check_java_version() fails when no Java command is available"

    cleanup_mock_environment
}

test_java_broken_command() {
    echo ""
    echo "🧪 Testing: Broken Java command"
    echo "─────────────────────────────────────────────────────────────"

    setup_mock_environment

    # Create broken Java mock that returns non-zero exit code
    create_mock_java "$MOCK_DIR/java" "Error: could not find Java runtime" 1

    assert_java_check_result 1 "check_java_version() fails when Java command is broken"

    cleanup_mock_environment
}

test_java_home_detection() {
    echo ""
    echo "🧪 Testing: JAVA_HOME detection"
    echo "─────────────────────────────────────────────────────────────"

    setup_mock_environment

    # Create Java in JAVA_HOME location
    export JAVA_HOME="$MOCK_DIR/java_home"
    create_mock_java "$JAVA_HOME/bin/java" 'openjdk version "21.0.2" 2024-01-16
OpenJDK Runtime Environment (build 21.0.2+13-58)
OpenJDK 64-Bit Server VM (build 21.0.2+13-58, mixed mode)'

    assert_java_check_result 0 "check_java_version() detects Java from JAVA_HOME"

    cleanup_mock_environment
}

test_java_system_location() {
    echo ""
    echo "🧪 Testing: System Java location detection"
    echo "─────────────────────────────────────────────────────────────"

    setup_mock_environment

    # Create Java in system location
    mkdir -p "$MOCK_DIR/usr/bin"
    create_mock_java "$MOCK_DIR/usr/bin/java" 'openjdk version "21.0.3" 2024-04-16
OpenJDK Runtime Environment (build 21.0.3+9-Ubuntu-1ubuntu1)
OpenJDK 64-Bit Server VM (build 21.0.3+9-Ubuntu-1ubuntu1, mixed mode)'

    # Add system path to mock candidates by modifying PATH
    export PATH="$MOCK_DIR/usr/bin:$PATH"

    assert_java_check_result 0 "check_java_version() detects Java from system location"

    cleanup_mock_environment
}

test_java_oracle_format() {
    echo ""
    echo "🧪 Testing: Oracle Java version format"
    echo "─────────────────────────────────────────────────────────────"

    setup_mock_environment

    # Create Oracle Java mock
    create_mock_java "$MOCK_DIR/java" 'java version "21.0.1" 2023-10-17 LTS
Java(TM) SE Runtime Environment (build 21.0.1+12-LTS-29)
Java HotSpot(TM) 64-Bit Server VM (build 21.0.1+12-LTS-29, mixed mode, sharing)'

    assert_java_check_result 0 "check_java_version() detects Oracle Java 21 successfully"

    cleanup_mock_environment
}

test_java_multiple_candidates() {
    echo ""
    echo "🧪 Testing: Multiple Java candidates (picks first valid)"
    echo "─────────────────────────────────────────────────────────────"

    setup_mock_environment

    # Create multiple Java installations
    # First one is Java 8 (insufficient)
    mkdir -p "$MOCK_DIR/usr/bin"
    create_mock_java "$MOCK_DIR/usr/bin/java" 'openjdk version "1.8.0_345" 2022-08-11'

    # Second one is Java 21 (sufficient) - in PATH
    create_mock_java "$MOCK_DIR/java" 'openjdk version "21.0.1" 2023-10-17'

    # Make sure both are in PATH, with the Java 8 one first
    export PATH="$MOCK_DIR/usr/bin:$MOCK_DIR:$PATH"

    assert_java_check_result 0 "check_java_version() finds valid Java among multiple candidates"

    cleanup_mock_environment
}

###########################################################################
# Tests for Java Version Extraction Function
###########################################################################

test_extract_java_version_function() {
    echo ""
    echo "🧪 Testing: Java version extraction function"
    echo "─────────────────────────────────────────────────────────────"

    # Define the extraction function (copy from helpers.sh)
    extract_java_version() {
        local version_output="$1"
        echo "$version_output" | awk -F '"' '/version/ {print $2}' | sed 's/^1\.//' | cut -d'.' -f1
    }

    # Test various version formats
    local test_cases=(
        'openjdk version "21.0.1" 2023-10-17|21'
        'openjdk version "17.0.5" 2022-10-18|17'
        'openjdk version "1.8.0_345" 2022-08-11|8'
        'java version "21.0.1" 2023-10-17 LTS|21'
        'openjdk version "11.0.16" 2022-07-19|11'
        'java version "1.8.0_333" 2022-04-22|8'
    )

    local passed=0
    local failed=0

    for test_case in "${test_cases[@]}"; do
        local input="${test_case%|*}"
        local expected="${test_case#*|}"
        local actual=$(extract_java_version "$input")

        if [ "$actual" = "$expected" ]; then
            echo "✅ PASS: extract_java_version('$input') = '$actual'"
            ((passed++))
            ((TESTS_PASSED++))
        else
            echo "❌ FAIL: extract_java_version('$input') = '$actual' (expected '$expected')"
            ((failed++))
            ((TESTS_FAILED++))
        fi
    done

    echo "   Extraction tests: $passed passed, $failed failed"
}

###########################################################################
# Test Runner
###########################################################################

run_java_tests() {
    echo "🧪 BoxLang Helpers Java Version Check Test Suite"
    echo "═══════════════════════════════════════════════════════════════════"

    # Run all test cases
    test_java_version_21
    test_java_version_17_insufficient
    test_java_version_8_old_format
    test_java_version_25_future
    test_java_no_command
    test_java_broken_command
    test_java_home_detection
    test_java_system_location
    test_java_oracle_format
    test_java_multiple_candidates
    test_extract_java_version_function

    # Print summary
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "📊 Java Version Test Summary"
    echo "═══════════════════════════════════════════════════════════════════"
    echo "✅ Tests Passed: $TESTS_PASSED"
    echo "❌ Tests Failed: $TESTS_FAILED"
    echo "📈 Total Tests:  $((TESTS_PASSED + TESTS_FAILED))"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo ""
        echo "🎉 All Java version tests passed! ✨"
        echo ""
        exit 0
    else
        echo ""
        echo "💥 Some Java version tests failed!"
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
    run_java_tests
fi
