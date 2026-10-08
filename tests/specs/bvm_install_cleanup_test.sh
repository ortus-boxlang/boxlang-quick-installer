#!/bin/sh
set -e

TEST_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$TEST_DIR")")"
sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/fixture/helpers" "$sandbox/mock-bin"
sed '$d' "$PROJECT_ROOT/src/bvm.sh" > "$sandbox/fixture/bvm.sh"
cp "$PROJECT_ROOT/src/helpers/helpers.sh" "$sandbox/fixture/helpers/helpers.sh"
cat >> "$sandbox/fixture/bvm.sh" <<'SCRIPT'
check_network_connectivity() { return 0; }
verify_download_with_checksum() { return 0; }
fetch_remote_version() { echo 1.18.9; }
use_version() { return 0; }
curl() { "$TEST_MOCK_BIN/curl" "$@"; }
unzip() { "$TEST_MOCK_BIN/unzip" "$@"; }
install_version "$TEST_VERSION" "$TEST_FORCE"
SCRIPT

cat > "$sandbox/mock-bin/curl" <<'SCRIPT'
#!/bin/sh
while [ "$1" != "-o" ]; do shift; done
out="$2"
phase=runtime
case "$out" in *miniserver*) phase=miniserver ;; esac
printf 'download\n' > "$out"
if [ "$TEST_PHASE" = "$phase" ]; then
    case "$TEST_MODE" in
        INT|TERM) kill "-$TEST_MODE" "$PPID"; exit 1 ;;
        failure) exit 1 ;;
    esac
fi
SCRIPT
cat > "$sandbox/mock-bin/unzip" <<'SCRIPT'
#!/bin/sh
archive="$2"
destination="$4"
mkdir -p "$destination/bin"
case "$archive" in
    *miniserver*) printf 'miniserver\n' > "$destination/bin/boxlang-miniserver" ;;
    *) printf 'runtime\n' > "$destination/bin/boxlang" ;;
esac
if [ "$TEST_PHASE" = extraction ]; then
    case "$TEST_MODE" in
        INT|TERM) kill "-$TEST_MODE" "$PPID"; exit 1 ;;
        failure) exit 1 ;;
    esac
fi
SCRIPT
chmod +x "$sandbox/mock-bin/curl" "$sandbox/mock-bin/unzip"

TESTS_PASSED=0
run_case() {
    local mode="$1" phase="$2" force="$3" version="$4"
    local home="$sandbox/home" code=0
    rm -rf "$home"
    mkdir -p "$home/versions"
    if [ "$force" = "--force" ]; then
        mkdir -p "$home/versions/1.18.9/bin"
        printf 'original\n' > "$home/versions/1.18.9/bin/boxlang"
    fi
    TEST_MODE="$mode" TEST_PHASE="$phase" TEST_FORCE="$force" TEST_VERSION="$version" TEST_MOCK_BIN="$sandbox/mock-bin" \
        BVM_HOME="$home" TERM=dumb PATH="$sandbox/mock-bin:$PATH" \
        sh "$sandbox/fixture/bvm.sh" > "$sandbox/output" 2>&1 || code=$?
    local expected=1
    case "$mode" in INT) expected=130 ;; TERM) expected=143 ;; success) expected=0 ;; esac
    if [ "$code" -ne "$expected" ]; then
        cat "$sandbox/output"
        echo "FAIL: $mode $phase $force $version exited $code instead of $expected"
        exit 1
    fi
    for staging in "$home/cache"/install.*; do
        [ ! -e "$staging" ] || { echo "FAIL: staging folder remains"; exit 1; }
    done
    if [ "$mode" = success ]; then
        [ -f "$home/versions/1.18.9/bin/boxlang" ]
        [ -f "$home/versions/1.18.9/bin/boxlang-miniserver" ]
        [ -L "$home/versions/1.18.9/bin/bx" ]
        [ "$(cat "$home/versions/1.18.9/bin/boxlang")" = runtime ]
        if [ "$version" != 1.18.9 ]; then
            [ -L "$home/versions/$version" ]
        fi
    elif [ "$force" = "--force" ]; then
        [ "$(cat "$home/versions/1.18.9/bin/boxlang")" = original ]
    else
        [ ! -e "$home/versions/1.18.9" ]
        local listing
        listing=$(BVM_HOME="$home" TERM=dumb sh "$PROJECT_ROOT/src/bvm.sh" list)
        case "$listing" in *1.18.9*) echo "FAIL: interrupted version is listed"; exit 1 ;; esac
    fi
    echo "PASS: $mode during $phase ($version $force)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

for phase in runtime miniserver extraction; do
    for mode in INT TERM failure; do
        run_case "$mode" "$phase" "" 1.18.9
        run_case "$mode" "$phase" "--force" 1.18.9
    done
done
run_case INT runtime "" latest
run_case INT extraction "" snapshot
run_case success "" "" 1.18.9
run_case success "" "--force" 1.18.9
run_case success "" "" latest
run_case success "" "" snapshot
echo "Passed: $TESTS_PASSED"
