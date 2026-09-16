#!/bin/sh
# IMPORTANT: This script intentionally targets POSIX /bin/sh.
# Do not change the shebang back to Bash or reintroduce Bash-only syntax.
# It must remain compatible with Alpine BusyBox ash and standard /bin/sh.

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

assert_contains() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    case "$actual" in
        *"$expected"*)
            echo "✅ PASS: $test_name"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            ;;
        *)
            echo "❌ FAIL: $test_name"
            echo "   Expected to find: '$expected'"
            FAILED_TESTS="$FAILED_TESTS\n$test_name"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            ;;
    esac
}

assert_not_contains() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    case "$actual" in
        *"$expected"*)
            echo "❌ FAIL: $test_name"
            echo "   Did not expect to find: '$expected'"
            FAILED_TESTS="$FAILED_TESTS\n$test_name"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            ;;
        *)
            echo "✅ PASS: $test_name"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            ;;
    esac
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

create_runtime_archive() {
    local root="$1"
    local archive="$2"
    local runtime="$root/runtime"

    mkdir -p "$runtime/bin"
    cat > "$runtime/bin/boxlang" <<'SCRIPT'
#!/bin/sh
exit 0
SCRIPT
    chmod +x "$runtime/bin/boxlang"
    dd if=/dev/zero of="$runtime/runtime-payload.bin" bs=1M count=9 >/dev/null 2>&1

    (
        cd "$runtime"
        zip -0qr "$archive" .
    )
}

create_miniserver_archive() {
    local root="$1"
    local archive="$2"
    local miniserver="$root/miniserver"

    mkdir -p "$miniserver/bin"
    cat > "$miniserver/bin/boxlang-miniserver" <<'SCRIPT'
#!/bin/sh
exit 0
SCRIPT
    chmod +x "$miniserver/bin/boxlang-miniserver"
    dd if=/dev/zero of="$miniserver/miniserver-payload.bin" bs=1M count=9 >/dev/null 2>&1

    (
        cd "$miniserver"
        zip -0qr "$archive" .
    )
}

test_latest_install_uses_versioned_checksum_urls() {
    local sandbox
    sandbox="$(mktemp -d)"
    local fixture_dir="$sandbox/bvm"
    local fixture_script="$fixture_dir/bvm.sh"
    local mock_bin="$sandbox/mock-bin"
    local runtime_zip="$sandbox/runtime.zip"
    local miniserver_zip="$sandbox/miniserver.zip"
    local runtime_sha="$sandbox/runtime.sha"
    local miniserver_sha="$sandbox/miniserver.sha"
    local curl_log="$sandbox/curl.log"
    local output=""
    local curl_calls=""
    local exit_code=0

    mkdir -p "$fixture_dir/helpers" "$mock_bin" "$sandbox/home/.bvm/versions/existing"

    sed '$d' "$BVM_SCRIPT" > "$fixture_script"
    cp "$PROJECT_ROOT/src/helpers/helpers.sh" "$fixture_dir/helpers/helpers.sh"

    create_runtime_archive "$sandbox" "$runtime_zip"
    create_miniserver_archive "$sandbox" "$miniserver_zip"

    printf '%s  boxlang-1.17.1.zip\n' "$(sha256sum "$runtime_zip" | cut -d' ' -f1)" > "$runtime_sha"
    printf '%s  boxlang-miniserver-1.17.1.zip\n' "$(sha256sum "$miniserver_zip" | cut -d' ' -f1)" > "$miniserver_sha"

    cat > "$mock_bin/curl" <<'SCRIPT'
#!/bin/sh
out=""
url=""
prev=""
for arg in "$@"; do
    if [ "$prev" = "-o" ]; then
        out="$arg"
        prev=""
        continue
    fi

    if [ "$arg" = "-o" ]; then
        prev="-o"
        continue
    fi

    case "$arg" in
        http://*|https://*)
            url="$arg"
            ;;
    esac
done

if [ -n "$MOCK_CURL_LOG" ] && [ -n "$url" ]; then
    printf '%s\n' "$url" >> "$MOCK_CURL_LOG"
fi

case "$url" in
    */version-latest.properties)
        printf 'version=1.17.1\n' > "$out"
        exit 0
        ;;
    */1.17.1/boxlang-1.17.1.zip)
        cp "$MOCK_RUNTIME_ZIP" "$out"
        exit 0
        ;;
    */1.17.1/boxlang-miniserver-1.17.1.zip)
        cp "$MOCK_MINISERVER_ZIP" "$out"
        exit 0
        ;;
    */1.17.1/boxlang-1.17.1.zip.sha-256)
        cp "$MOCK_RUNTIME_SHA" "$out"
        exit 0
        ;;
    */1.17.1/boxlang-miniserver-1.17.1.zip.sha-256)
        cp "$MOCK_MINISERVER_SHA" "$out"
        exit 0
        ;;
    */boxlang-latest.zip.sha-256|*/boxlang-miniserver-latest.zip.sha-256)
        echo "latest checksum URL should not be used" >&2
        exit 99
        ;;
    *)
        echo "unexpected url: $url" >&2
        exit 98
        ;;
esac
SCRIPT
    chmod +x "$mock_bin/curl"

    printf '\ninstall_version latest\n' >> "$fixture_script"

    output=$(MOCK_CURL_LOG="$curl_log" MOCK_RUNTIME_ZIP="$runtime_zip" MOCK_MINISERVER_ZIP="$miniserver_zip" MOCK_RUNTIME_SHA="$runtime_sha" MOCK_MINISERVER_SHA="$miniserver_sha" HOME="$sandbox/home" BVM_HOME="$sandbox/home/.bvm" TERM="xterm-256color" PATH="$mock_bin:$PATH" sh "$fixture_script" 2>&1) || exit_code=$?

    if [ -f "$curl_log" ]; then
        curl_calls="$(cat "$curl_log")"
    fi

    assert_return_code 0 "$exit_code" "bvm install latest succeeds with versioned artifacts"
    assert_contains "/1.17.1/boxlang-1.17.1.zip.sha-256" "$curl_calls" "runtime checksum uses resolved latest version"
    assert_contains "/1.17.1/boxlang-miniserver-1.17.1.zip.sha-256" "$curl_calls" "miniserver checksum uses resolved latest version"
    assert_not_contains "boxlang-latest.zip.sha-256" "$curl_calls" "runtime latest checksum alias is not used"
    assert_not_contains "boxlang-miniserver-latest.zip.sha-256" "$curl_calls" "miniserver latest checksum alias is not used"

    if [ "$exit_code" -ne 0 ]; then
        echo "$output"
    fi

    rm -rf "$sandbox"
}

main() {
    echo "🧪 BVM latest install checksum test suite"
    echo "═══════════════════════════════════════════════════════════════"

    test_latest_install_uses_versioned_checksum_urls

    print_test_summary
}

main "$@"
