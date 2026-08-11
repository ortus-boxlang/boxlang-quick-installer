#!/bin/sh
# IMPORTANT: This script intentionally targets POSIX /bin/sh.
# Do not change the shebang back to Bash or reintroduce Bash-only syntax.
# It must remain compatible with Alpine BusyBox ash and standard /bin/sh.

# Global test runner for BoxLang project
# Author: BoxLang Team
# License: Apache License, Version 2.0

# Note: Not using 'set -e' here to allow test failures without stopping the runner

# Get the directory of this script
TEST_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR")"
SPECS_DIR="$TEST_DIR/specs"

# Automatically discover all test files
get_test_files() {
    find "$SPECS_DIR" -name "*_test.sh" -type f | sort
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NORMAL='\033[0m'

# Test results tracking
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
FAILED_SUITE_NAMES=""

###########################################################################
# Helper Functions
###########################################################################

print_banner() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NORMAL}"
    echo -e "${BOLD}${BLUE}🧪 BoxLang Quick Installer - Test Suite Runner${NORMAL}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NORMAL}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${YELLOW}▶️  Running: $1${NORMAL}"
    echo -e "${YELLOW}───────────────────────────────────────────────────────────────────${NORMAL}"
}

run_test_suite() {
    local test_file="$1"
    local suite_name=$(basename "$test_file" .sh)

    TOTAL_SUITES=$((TOTAL_SUITES + 1))

    print_section "$suite_name"

    if [ ! -f "$test_file" ]; then
        echo -e "${RED}❌ Test file not found: $test_file${NORMAL}"
        FAILED_SUITES=$((FAILED_SUITES + 1))
        FAILED_SUITE_NAMES="$FAILED_SUITE_NAMES\n$suite_name (file not found)"
        return 1
    fi

    if [ ! -x "$test_file" ]; then
        echo -e "${YELLOW}⚠️  Making test file executable: $test_file${NORMAL}"
        chmod +x "$test_file"
    fi

    # Run the test suite and capture exit code, but don't let it stop the runner
    echo -e "${BLUE}Starting test suite: $suite_name${NORMAL}"
    if sh "$test_file" 2>&1; then
        echo -e "${GREEN}✅ $suite_name completed successfully${NORMAL}"
        PASSED_SUITES=$((PASSED_SUITES + 1))
        return 0
    else
        local exit_code=$?
        echo -e "${RED}❌ $suite_name failed (exit code: $exit_code)${NORMAL}"
        FAILED_SUITES=$((FAILED_SUITES + 1))
        FAILED_SUITE_NAMES="$FAILED_SUITE_NAMES\n$suite_name"
        return 1
    fi
}

###########################################################################
# Main Test Runner
###########################################################################

run_all_tests() {
    print_banner

    echo -e "${BLUE}🔍 Discovering test suites in: $SPECS_DIR${NORMAL}"

    # Check if project files exist
    local helpers_file="$PROJECT_ROOT/src/helpers/helpers.sh"
    if [ ! -f "$helpers_file" ]; then
        echo -e "${RED}❌ Error: helpers.sh not found at $helpers_file${NORMAL}"
        echo -e "${YELLOW}Please ensure you're running this from the BoxLang project root directory.${NORMAL}"
        exit 1
    fi

    echo -e "${GREEN}✅ Project structure validated${NORMAL}"
    echo ""

    # Get test files dynamically
    local test_files
    test_files=$(get_test_files)

    if [ -z "$test_files" ]; then
        echo -e "${RED}❌ No test files found in $SPECS_DIR${NORMAL}"
        echo -e "${YELLOW}Test files should follow the pattern: *_test.sh${NORMAL}"
        exit 1
    fi

    local suite_count=0
    for test_file in $test_files; do
        suite_count=$((suite_count + 1))
        local suite_name=$(basename "$test_file" .sh)
        echo -e "${BLUE}  • $suite_name${NORMAL}"
    done
    echo -e "${BLUE}Found $suite_count test suite(s):${NORMAL}"
    echo ""

    # Run each test suite (continue even if individual tests fail)
    for test_file in $test_files; do
        # Run test suite but don't let failures stop the runner
        run_test_suite "$test_file" || true
    done

    # Print final summary
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NORMAL}"
    echo -e "${BOLD}📊 Final Test Summary${NORMAL}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NORMAL}"
    echo -e "${GREEN}✅ Test Suites Passed: $PASSED_SUITES${NORMAL}"
    echo -e "${RED}❌ Test Suites Failed: $FAILED_SUITES${NORMAL}"
    echo -e "${BLUE}📈 Total Test Suites:  $TOTAL_SUITES${NORMAL}"

    if [ $FAILED_SUITES -eq 0 ]; then
        echo ""
        echo -e "${GREEN}${BOLD}🎉 ALL TEST SUITES PASSED! 🎉${NORMAL}"
        echo -e "${GREEN}The BoxLang project components are working correctly! ✨${NORMAL}"
        echo ""
        exit 0
    else
        echo ""
        echo -e "${RED}${BOLD}💥 SOME TEST SUITES FAILED:${NORMAL}"
        printf '%b\n' "$FAILED_SUITE_NAMES" | while IFS= read -r suite; do
            [ -n "$suite" ] && echo -e "${RED}   • $suite${NORMAL}"
        done
        echo ""
        echo -e "${YELLOW}Please review the failed tests above and fix any issues.${NORMAL}"
        echo ""
        exit 1
    fi
}

###########################################################################
# Command Line Options
###########################################################################

show_help() {
    echo "BoxLang Project Test Runner"
    echo ""
    echo "Automatically discovers and runs all test suites in the project."
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -l, --list     List available test suites"
    echo "  -s, --single   Run a single test suite by name"
    echo ""
    echo "Examples:"
    echo "  $0                           # Run all discovered test suites"
    echo "  $0 --list                    # List available test suites"
    echo "  $0 --single helpers_test     # Run only the helpers_test suite"
    echo ""
    echo "Test Discovery:"
    echo "  • Automatically finds all *_test.sh files in specs/ directory"
    echo "  • Tests run in alphabetical order"
    echo "  • Add new tests by creating *_test.sh files in specs/"
}

list_tests() {
    echo "Available test suites:"
    echo ""

    local test_files
    test_files=$(get_test_files)

    if [ -z "$test_files" ]; then
        echo "  No test files found in $SPECS_DIR"
        echo "  Test files should follow the pattern: *_test.sh"
        return 1
    fi

    for test_file in $test_files; do
        local suite_name=$(basename "$test_file" .sh)
        local description=""

        case "$suite_name" in
            "helpers_test")
                description="Core helper functions (print functions, command_exists, version comparison)"
                ;;
            "preflight_check_test")
                description="Preflight dependency checks with mocked commands"
                ;;
            "java_version_test")
                description="Java version detection and validation"
                ;;
            *)
                description="Test suite for ${suite_name%_test}"
                ;;
        esac

        echo "  $suite_name - $description"
    done
    echo ""
}

run_single_test() {
    local test_name="$1"
    local test_file="$SPECS_DIR/${test_name}.sh"

    if [ ! -f "$test_file" ]; then
        echo -e "${RED}❌ Test suite not found: $test_name${NORMAL}"
        echo -e "${YELLOW}Available test suites:${NORMAL}"
        list_tests
        exit 1
    fi

    print_banner
    echo -e "${BLUE}🏃 Running single test suite: $test_name${NORMAL}"
    echo ""

    run_test_suite "$test_file"
}

###########################################################################
# Main
###########################################################################

main() {
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -l|--list)
            list_tests
            exit 0
            ;;
        -s|--single)
            if [ -z "${2:-}" ]; then
                echo -e "${RED}❌ Error: Test suite name required${NORMAL}"
                echo ""
                show_help
                exit 1
            fi
            run_single_test "$2"
            ;;
        "")
            run_all_tests
            ;;
        *)
            echo -e "${RED}❌ Error: Unknown option: $1${NORMAL}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
