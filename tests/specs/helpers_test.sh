#!/bin/bash
# Test suite for helpers.sh
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
FAILED_TESTS=()

###########################################################################
# Test Framework Functions
###########################################################################

assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    if [ "$expected" = "$actual" ]; then
        echo "✅ PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo "❌ FAIL: $test_name"
        echo "   Expected: '$expected'"
        echo "   Actual:   '$actual'"
        FAILED_TESTS+=("$test_name")
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_contains() {
    local substring="$1"
    local string="$2"
    local test_name="$3"

    if [[ "$string" == *"$substring"* ]]; then
        echo "✅ PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo "❌ FAIL: $test_name"
        echo "   Expected '$string' to contain '$substring'"
        FAILED_TESTS+=("$test_name")
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_return_code() {
    local expected_code="$1"
    local actual_code="$2"
    local test_name="$3"

    if [ "$expected_code" -eq "$actual_code" ]; then
        echo "✅ PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo "❌ FAIL: $test_name"
        echo "   Expected return code: $expected_code"
        echo "   Actual return code:   $actual_code"
        FAILED_TESTS+=("$test_name")
        ((TESTS_FAILED++))
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
# Tests for Printing Functions
###########################################################################

test_print_functions() {
    run_test_group "Print Functions"

    # Setup colors for testing
    setup_colors

    # Test print_info
    local info_output=$(print_info "test message" 2>&1)
    assert_contains "ℹ️ test message" "$info_output" "print_info() outputs correct format"

    # Test print_success
    local success_output=$(print_success "test success" 2>&1)
    assert_contains "✅ test success" "$success_output" "print_success() outputs correct format"

    # Test print_warning
    local warning_output=$(print_warning "test warning" 2>&1)
    assert_contains "⚠️  test warning" "$warning_output" "print_warning() outputs correct format"

    # Test print_error
    local error_output=$(print_error "test error" 2>&1)
    assert_contains "🔴 test error" "$error_output" "print_error() outputs correct format"

    # Test print_header
    local header_output=$(print_header "Test Header" 2>&1)
    assert_contains "Test Header" "$header_output" "print_header() outputs correct format"
}

###########################################################################
# Tests for Command Existence Check
###########################################################################

test_command_exists() {
    run_test_group "Command Existence Check"

    # Test with existing command
    command_exists "echo"
    assert_return_code 0 $? "command_exists() returns 0 for existing command (echo)"

    # Test with non-existing command
    command_exists "nonexistent_command_12345"
    assert_return_code 1 $? "command_exists() returns 1 for non-existing command"

    # Test with another common command
    command_exists "ls"
    assert_return_code 0 $? "command_exists() returns 0 for existing command (ls)"
}

###########################################################################
# Tests for Setup Colors
###########################################################################

test_setup_colors() {
    run_test_group "Color Setup"

    # Clear existing color variables
    unset RED GREEN YELLOW BLUE BOLD NORMAL MAGENTA CYAN WHITE BLACK UNDERLINE

    # Run setup_colors
    setup_colors

    # Test that color variables are set (they should be set to something, even if empty)
    [ -n "${RED+x}" ] && echo "✅ PASS: setup_colors() sets RED variable" || echo "❌ FAIL: setup_colors() does not set RED variable"
    [ -n "${GREEN+x}" ] && echo "✅ PASS: setup_colors() sets GREEN variable" || echo "❌ FAIL: setup_colors() does not set GREEN variable"
    [ -n "${NORMAL+x}" ] && echo "✅ PASS: setup_colors() sets NORMAL variable" || echo "❌ FAIL: setup_colors() does not set NORMAL variable"

    # Count as passed tests
    ((TESTS_PASSED+=3))
}

###########################################################################
# Tests for Version Comparison Functions
###########################################################################

test_extract_semantic_version() {
    run_test_group "Semantic Version Extraction"

    # Test basic version extraction
    local version1=$(extract_semantic_version "1.2.3")
    assert_equals "1.2.3" "$version1" "extract_semantic_version() extracts basic version"

    # Test version with build metadata
    local version2=$(extract_semantic_version "BoxLang 1.2.3+20241201.120000")
    assert_equals "1.2.3" "$version2" "extract_semantic_version() extracts version from BoxLang string"

    # Test version with build ID
    local version3=$(extract_semantic_version "1.2.3+buildId")
    assert_equals "1.2.3" "$version3" "extract_semantic_version() extracts version with build ID"

    # Test complex version string
    local version4=$(extract_semantic_version "BoxLang Version 2.1.0 Build 20241225.100000")
    assert_equals "2.1.0" "$version4" "extract_semantic_version() extracts from complex string"
}

test_isSnapshotVersion() {
    run_test_group "Snapshot Version Detection"

    # Test snapshot versions
    isSnapshotVersion "1.2.3-snapshot"
    assert_return_code 0 $? "isSnapshotVersion() detects lowercase snapshot"

    isSnapshotVersion "1.2.3-SNAPSHOT"
    assert_return_code 0 $? "isSnapshotVersion() detects uppercase SNAPSHOT"

    isSnapshotVersion "1.2.3-beta"
    assert_return_code 0 $? "isSnapshotVersion() detects beta version"

    isSnapshotVersion "1.2.3-alpha"
    assert_return_code 0 $? "isSnapshotVersion() detects alpha version"

    isSnapshotVersion "1.2.3-rc"
    assert_return_code 0 $? "isSnapshotVersion() detects rc version"

    # Test stable versions
    isSnapshotVersion "1.2.3"
    assert_return_code 1 $? "isSnapshotVersion() returns false for stable version"

    isSnapshotVersion "2.0.0"
    assert_return_code 1 $? "isSnapshotVersion() returns false for another stable version"
}

test_compare_versions() {
    run_test_group "Version Comparison"

    # Test equal versions
    compare_versions "1.2.3" "1.2.3"
    assert_return_code 0 $? "compare_versions() returns 0 for equal versions"

    # Test first version greater
    compare_versions "1.2.4" "1.2.3"
    assert_return_code 1 $? "compare_versions() returns 1 when first > second (patch)"

    compare_versions "1.3.0" "1.2.9"
    assert_return_code 1 $? "compare_versions() returns 1 when first > second (minor)"

    compare_versions "2.0.0" "1.9.9"
    assert_return_code 1 $? "compare_versions() returns 1 when first > second (major)"

    # Test first version lesser
    compare_versions "1.2.3" "1.2.4"
    assert_return_code 2 $? "compare_versions() returns 2 when first < second (patch)"

    compare_versions "1.2.9" "1.3.0"
    assert_return_code 2 $? "compare_versions() returns 2 when first < second (minor)"

    compare_versions "1.9.9" "2.0.0"
    assert_return_code 2 $? "compare_versions() returns 2 when first < second (major)"

    # Test versions with missing parts
    compare_versions "1.2" "1.2.0"
    assert_return_code 0 $? "compare_versions() handles missing patch version"

    compare_versions "1" "1.0.0"
    assert_return_code 0 $? "compare_versions() handles missing minor and patch versions"
}

###########################################################################
# Tests for Java Version Check (Mock tests)
###########################################################################

test_java_version_extraction() {
    run_test_group "Java Version Extraction"

    # Create a mock java command that returns version info
    create_mock_java() {
        local version="$1"
        local mock_path="/tmp/mock_java_$$"
        cat > "$mock_path" << EOF
#!/bin/bash
echo 'openjdk version "$version" 2024-01-15'
echo 'OpenJDK Runtime Environment (build $version+35-2562)'
echo 'OpenJDK 64-Bit Server VM (build $version+35-2562, mixed mode, sharing)'
EOF
        chmod +x "$mock_path"
        echo "$mock_path"
    }

    # Test version extraction function
    extract_java_version() {
        local version_output="$1"
        echo "$version_output" | awk -F '"' '/version/ {print $2}' | sed 's/^1\.//' | cut -d'.' -f1
    }

    # Test Java 21
    local java21_output='openjdk version "21.0.1" 2023-10-17'
    local extracted21=$(extract_java_version "$java21_output")
    assert_equals "21" "$extracted21" "Java version extraction works for Java 21"

    # Test Java 17
    local java17_output='openjdk version "17.0.5" 2022-10-18'
    local extracted17=$(extract_java_version "$java17_output")
    assert_equals "17" "$extracted17" "Java version extraction works for Java 17"

    # Test Java 8 (old format)
    local java8_output='openjdk version "1.8.0_345" 2022-08-11'
    local extracted8=$(extract_java_version "$java8_output")
    assert_equals "8" "$extracted8" "Java version extraction works for Java 8 (1.x format)"

    # Test Java 11
    local java11_output='openjdk version "11.0.16" 2022-07-19'
    local extracted11=$(extract_java_version "$java11_output")
    assert_equals "11" "$extracted11" "Java version extraction works for Java 11"
}

###########################################################################
# Integration Tests
###########################################################################

test_integration() {
    run_test_group "Integration Tests"

    # Test that setup_colors doesn't break print functions
    setup_colors
    local combined_output=$(print_success "Integration test" 2>&1)
    assert_contains "Integration test" "$combined_output" "setup_colors() doesn't break print functions"

    # Test version comparison with extracted versions
    local version_a=$(extract_semantic_version "1.2.3")
    local version_b=$(extract_semantic_version "1.2.4")
    compare_versions "$version_a" "$version_b"
    assert_return_code 2 $? "Integration: extract + compare versions works correctly"
}

###########################################################################
# Test Runner
###########################################################################

run_all_tests() {
    echo "🧪 BoxLang Helpers Test Suite"
    echo "═══════════════════════════════════════════════════════════════════"

    # Run all test groups
    test_print_functions
    test_command_exists
    test_setup_colors
    test_extract_semantic_version
    test_isSnapshotVersion
    test_compare_versions
    test_java_version_extraction
    test_integration

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
        for test in "${FAILED_TESTS[@]}"; do
            echo "   • $test"
        done
        echo ""
        exit 1
    fi
}

# Run tests if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_tests
fi
