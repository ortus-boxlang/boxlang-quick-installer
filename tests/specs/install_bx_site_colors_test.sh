#!/bin/sh
# IMPORTANT: This script intentionally targets POSIX /bin/sh.
# Do not change the shebang back to Bash or reintroduce Bash-only syntax.
# It must remain compatible with Alpine BusyBox ash and standard /bin/sh.

# Test suite for the setup_colors() copy inside install-bx-site.sh
# install-bx-site.sh cannot simply be sourced, because it starts running work at the top
# level, so its setup_colors() is extracted and evaluated in isolation.
# Author: BoxLang Team
# License: Apache License, Version 2.0

TEST_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$TEST_DIR")")"
SITE_FILE="$PROJECT_ROOT/src/install-bx-site.sh"

if [ ! -f "$SITE_FILE" ]; then
    echo "❌ Error: install-bx-site.sh not found at $SITE_FILE"
    exit 1
fi

# Pull out the `setup_colors() { ... }` block, from its opening line to the first
# closing brace in column 0.
SETUP_COLORS_SRC="$(awk '/^setup_colors\(\) \{/{found=1} found{print} found && /^\}$/{exit}' "$SITE_FILE")"

if [ -z "$SETUP_COLORS_SRC" ]; then
    echo "❌ Error: could not extract setup_colors() from $SITE_FILE"
    exit 1
fi

TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=""

###########################################################################
# Test Framework Functions
###########################################################################

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
        echo "   Did not expect '$substring'"
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

run_test_group() {
    local group_name="$1"
    echo ""
    echo "🧪 Testing: $group_name"
    echo "────────────────────────────────────────────────────────────"
}

###########################################################################
# Tests
###########################################################################

test_setup_colors_without_term() {
    run_test_group "install-bx-site.sh setup_colors() Without TERM"

    # Regression: `tput colors` used to run whenever the tput binary existed, with no
    # check on TERM. install-bx-site.sh runs under `set -e`, so the failing substitution
    # aborted the whole script.
    local no_term_output
    no_term_output=$(sh -c 'unset TERM; set -e; eval "$1"; setup_colors; echo "SURVIVED"' sh "$SETUP_COLORS_SRC" 2>&1)
    assert_contains "SURVIVED" "$no_term_output" "setup_colors() completes with TERM unset under set -e"
    assert_not_contains "No value for \$TERM" "$no_term_output" "setup_colors() does not invoke tput when TERM is unset"

    # ncolors must always be defined, otherwise the `[ -n "$ncolors" ]` check errors
    # out under `set -u`.
    local defined_output
    defined_output=$(sh -c 'unset TERM; set -eu; eval "$1"; setup_colors; echo "ncolors=${ncolors-UNSET}"' sh "$SETUP_COLORS_SRC" 2>&1)
    assert_not_contains "ncolors=UNSET" "$defined_output" "setup_colors() defines ncolors when TERM is unset"

    # Colours must fall back to empty strings with no usable terminal.
    local fallback_output
    fallback_output=$(sh -c 'unset TERM; set -eu; eval "$1"; setup_colors; echo "RED=[${RED}]"' sh "$SETUP_COLORS_SRC" 2>&1)
    assert_contains "RED=[]" "$fallback_output" "setup_colors() leaves colors empty when TERM is unset"

    # A TERM that supports no colours must not break it either.
    local dumb_term_output
    dumb_term_output=$(sh -c 'TERM=dumb; set -e; eval "$1"; setup_colors; echo "SURVIVED"' sh "$SETUP_COLORS_SRC" 2>&1)
    assert_contains "SURVIVED" "$dumb_term_output" "setup_colors() completes with TERM=dumb under set -e"
}

###########################################################################
# Test Runner
###########################################################################

run_all_tests() {
    echo "🧪 BoxLang install-bx-site.sh Color Test Suite"
    echo "═══════════════════════════════════════════════════════════════════"

    test_setup_colors_without_term

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
