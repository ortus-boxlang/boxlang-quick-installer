#!/bin/sh

set -e

TEST_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$TEST_DIR")")"
INSTALLER_SCRIPT="$PROJECT_ROOT/src/install-boxlang.sh"
MODULE_INSTALLER_SCRIPT="$PROJECT_ROOT/src/install-bx-module.sh"

TESTS_PASSED=0
TESTS_FAILED=0

assert_true() {
	local condition="$1"
	local message="$2"
	if eval "$condition"; then
		echo "PASS: $message"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		echo "FAIL: $message"
		TESTS_FAILED=$((TESTS_FAILED + 1))
	fi
}

assert_contains() {
	local expected="$1"
	local actual="$2"
	local message="$3"
	case "$actual" in
	*"$expected"*)
		echo "PASS: $message"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		;;
	*)
		echo "FAIL: $message"
		TESTS_FAILED=$((TESTS_FAILED + 1))
		;;
	esac
}

assert_not_contains() {
	local expected="$1"
	local actual="$2"
	local message="$3"
	case "$actual" in
	*"$expected"*)
		echo "FAIL: $message"
		TESTS_FAILED=$((TESTS_FAILED + 1))
		;;
	*)
		echo "PASS: $message"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		;;
	esac
}

expected_install_home() {
	if [ "$(id -u)" -eq 0 ]; then
		echo "$1"
	else
		echo "$2/.local/boxlang"
	fi
}

create_runtime_archive() {
	local root="$1"
	local archive="$2"
	local runtime="$root/runtime"
	mkdir -p "$runtime/bin"
	cat > "$runtime/bin/boxlang" <<'EOF'
#!/bin/sh
if [ "$1" = "--version" ]; then
    echo "BoxLang 1.0.0"
fi
EOF
	cat > "$runtime/bin/boxlang-miniserver" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$runtime/bin/boxlang" "$runtime/bin/boxlang-miniserver"
	(
		cd "$runtime"
		zip -qr "$archive" .
	)
}

test_local_zip_artifacts_install_without_curl() {
	local sandbox
	sandbox="$(mktemp -d)"
	local runtime_zip="$sandbox/runtime.zip"
	local miniserver_zip="$sandbox/miniserver.zip"
	local scripts_zip="$sandbox/scripts.zip"
	local scripts_dir="$sandbox/scripts"
	local mock_bin="$sandbox/mock-bin"
	mkdir -p "$scripts_dir" "$mock_bin"
	create_runtime_archive "$sandbox" "$runtime_zip"
	create_runtime_archive "$sandbox" "$miniserver_zip"
	echo '#!/bin/sh' > "$scripts_dir/install-boxlang.sh"
	(
		cd "$scripts_dir"
		zip -qr "$scripts_zip" .
	)
	cat > "$mock_bin/curl" <<'EOF'
#!/bin/sh
echo "curl must not be called for local artifacts" >&2
exit 99
EOF
	chmod +x "$mock_bin/curl"

	local output=""
	local exit_code=0
	local home="$sandbox/home"
	local install_home
	install_home="$(expected_install_home "$sandbox/install" "$home")"
	output=$(HOME="$sandbox/home" BOXLANG_INSTALL_HOME="$sandbox/install" TERM="xterm-256color" PATH="$mock_bin:$PATH" \
		sh "$INSTALLER_SCRIPT" --force --without-commandbox --without-jre \
			--boxlang-path "$runtime_zip" \
			--miniserver-path "$miniserver_zip" \
			--installer-scripts-path "$scripts_zip" 2>&1) || exit_code=$?

	assert_true "[ $exit_code -eq 0 ]" "local ZIP installation succeeds without curl"
	assert_true "[ -x '$install_home/bin/boxlang' ]" "BoxLang ZIP extracts its executable"
	assert_true "[ -x '$install_home/bin/boxlang-miniserver' ]" "MiniServer ZIP extracts its executable"
	assert_true "[ -f '$install_home/scripts/install-boxlang.sh' ]" "installer script ZIP extracts into scripts directory"
	assert_not_contains "curl must not be called" "$output" "local artifacts do not download"

	rm -rf "$sandbox"
}

test_local_script_directory_is_copied() {
	local sandbox
	sandbox="$(mktemp -d)"
	local runtime_zip="$sandbox/runtime.zip"
	local miniserver_zip="$sandbox/miniserver.zip"
	local scripts_dir="$sandbox/scripts"
	local home="$sandbox/home"
	local install_home
	install_home="$(expected_install_home "$sandbox/install" "$home")"
	mkdir -p "$scripts_dir"
	create_runtime_archive "$sandbox" "$runtime_zip"
	create_runtime_archive "$sandbox" "$miniserver_zip"
	echo '#!/bin/sh' > "$scripts_dir/install-bvm.sh"

	HOME="$sandbox/home" BOXLANG_INSTALL_HOME="$sandbox/install" TERM="xterm-256color" \
		sh "$INSTALLER_SCRIPT" --force --without-commandbox --without-jre \
			--boxlang-path "$runtime_zip" \
			--miniserver-path "$miniserver_zip" \
			--installer-scripts-path "$scripts_dir" >/dev/null

	assert_true "[ -f '$install_home/scripts/install-bvm.sh' ]" "local installer script directory is copied"
	rm -rf "$sandbox"
}

test_local_jars_are_copied_without_extraction() {
	local sandbox
	sandbox="$(mktemp -d)"
	local runtime_zip="$sandbox/runtime.zip"
	local miniserver_zip="$sandbox/miniserver.zip"
	local scripts_dir="$sandbox/scripts"
	local boxlang_jar="$sandbox/boxlang.jar"
	local miniserver_jar="$sandbox/boxlang-miniserver.jar"
	local boxlang_home="$sandbox/home-boxlang"
	local miniserver_home="$sandbox/home-miniserver"
	local boxlang_install_home
	local miniserver_install_home
	boxlang_install_home="$(expected_install_home "$sandbox/install-boxlang" "$boxlang_home")"
	miniserver_install_home="$(expected_install_home "$sandbox/install-miniserver" "$miniserver_home")"
	mkdir -p "$scripts_dir"
	create_runtime_archive "$sandbox" "$runtime_zip"
	create_runtime_archive "$sandbox" "$miniserver_zip"
	echo 'boxlang jar' > "$boxlang_jar"
	echo 'miniserver jar' > "$miniserver_jar"
	echo '#!/bin/sh' > "$scripts_dir/install-bvm.sh"

	HOME="$boxlang_home" BOXLANG_INSTALL_HOME="$sandbox/install-boxlang" TERM="xterm-256color" \
		sh "$INSTALLER_SCRIPT" --force --without-commandbox --without-jre \
			--boxlang-path "$boxlang_jar" \
			--miniserver-path "$miniserver_zip" \
			--installer-scripts-path "$scripts_dir" >/dev/null 2>&1
	assert_true "[ -f '$boxlang_install_home/lib/boxlang.jar' ]" "local BoxLang JAR is copied directly"

	HOME="$miniserver_home" BOXLANG_INSTALL_HOME="$sandbox/install-miniserver" TERM="xterm-256color" \
		sh "$INSTALLER_SCRIPT" --force --without-commandbox --without-jre \
			--boxlang-path "$runtime_zip" \
			--miniserver-path "$miniserver_jar" \
			--installer-scripts-path "$scripts_dir" >/dev/null 2>&1
	assert_true "[ -f '$miniserver_install_home/lib/boxlang-miniserver.jar' ]" "local MiniServer JAR is copied directly"

	rm -rf "$sandbox"
}

test_non_root_install_uses_user_local_paths() {
	local sandbox
	sandbox="$(mktemp -d)"
	local runtime_zip="$sandbox/runtime.zip"
	local miniserver_zip="$sandbox/miniserver.zip"
	local scripts_dir="$sandbox/scripts"
	local user_home="$sandbox/home"
	local test_user="boxlangtest$$"
	local run_as_user=1
	local exit_code=0
	local output=""
	mkdir -p "$scripts_dir" "$user_home" "$sandbox/tmp"
	create_runtime_archive "$sandbox" "$runtime_zip"
	create_runtime_archive "$sandbox" "$miniserver_zip"
	echo '#!/bin/sh' > "$scripts_dir/install-bvm.sh"
	if [ "$(id -u)" -eq 0 ] && command -v useradd >/dev/null 2>&1; then
		useradd --create-home --home-dir "$user_home" --shell /bin/sh "$test_user"
	elif [ "$(id -u)" -eq 0 ]; then
		adduser -D -h "$user_home" -s /bin/sh "$test_user"
	else
		test_user="$(id -un)"
		run_as_user=0
	fi
	if [ "$run_as_user" -eq 1 ]; then
		chown -R "$test_user" "$sandbox"
		output=$(su "$test_user" -s /bin/sh -c "HOME='$user_home' TMPDIR='$sandbox/tmp' TERM=xterm-256color sh '$INSTALLER_SCRIPT' --force --without-commandbox --without-jre --boxlang-path '$runtime_zip' --miniserver-path '$miniserver_zip' --installer-scripts-path '$scripts_dir'" 2>&1) || exit_code=$?
	else
		output=$(HOME="$user_home" TMPDIR="$sandbox/tmp" TERM=xterm-256color sh "$INSTALLER_SCRIPT" --force --without-commandbox --without-jre --boxlang-path "$runtime_zip" --miniserver-path "$miniserver_zip" --installer-scripts-path "$scripts_dir" 2>&1) || exit_code=$?
	fi
	if [ "$exit_code" -ne 0 ]; then
		echo "$output"
	fi

	assert_true "[ $exit_code -eq 0 ]" "non-root local installation succeeds"
	assert_true "[ -x '$user_home/.local/boxlang/bin/boxlang' ]" "non-root installation uses the user BoxLang directory"
	assert_true "[ -L '$user_home/.local/bin/boxlang' ]" "non-root installation uses the user bin directory"

	if [ "$run_as_user" -eq 1 ] && command -v userdel >/dev/null 2>&1; then
		userdel "$test_user" >/dev/null 2>&1 || true
	elif [ "$run_as_user" -eq 1 ]; then
		deluser "$test_user" >/dev/null 2>&1 || true
	fi
	rm -rf "$sandbox"
}

test_module_preflight_skips_java_and_requires_jq() {
	local sandbox
	sandbox="$(mktemp -d)"
	local mock_bin="$sandbox/mock-bin"
	mkdir -p "$mock_bin"
	for command in curl unzip jq; do
		cat > "$mock_bin/$command" <<'EOF'
#!/bin/sh
exit 0
EOF
		chmod +x "$mock_bin/$command"
	done
	cat > "$mock_bin/dirname" <<'EOF'
#!/bin/sh
path="$1"
if [ "$path" = "--" ]; then
	path="$2"
fi
case "$path" in
	*/*) printf '%s\n' "${path%/*}" ;;
	*) printf '.\n' ;;
esac
EOF
	cat > "$mock_bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' 'Linux'
EOF
	chmod +x "$mock_bin/dirname" "$mock_bin/uname"

	output=$(PATH="$mock_bin:/bin:/usr/bin" TERM="xterm-256color" sh "$MODULE_INSTALLER_SCRIPT" 2>&1 || true)
	assert_contains "No module(s) specified" "$output" "module installer skips Java when dependencies are present"

	rm -f "$mock_bin/jq"
	output=$(PATH="$mock_bin" TERM="xterm-256color" /bin/sh "$MODULE_INSTALLER_SCRIPT" 2>&1 || true)
	assert_contains "jq" "$output" "module installer still requires jq"
	rm -rf "$sandbox"
}

test_local_zip_artifacts_install_without_curl
test_local_script_directory_is_copied
test_local_jars_are_copied_without_extraction
test_non_root_install_uses_user_local_paths
test_module_preflight_skips_java_and_requires_jq

echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
[ "$TESTS_FAILED" -eq 0 ]