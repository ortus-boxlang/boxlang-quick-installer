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
	local module_home="$sandbox/module-home"
	local miniserver_home="$sandbox/home-miniserver"
	local mock_bin="$sandbox/mock-bin"
	local launcher_bin="$sandbox/launcher-bin"
	local boxlang_install_home
	local miniserver_install_home
	boxlang_install_home="$(expected_install_home "$sandbox/install-boxlang" "$boxlang_home")"
	miniserver_install_home="$(expected_install_home "$sandbox/install-miniserver" "$miniserver_home")"
	mkdir -p "$scripts_dir" "$boxlang_home" "$miniserver_home" "$mock_bin" "$launcher_bin"
	create_runtime_archive "$sandbox" "$runtime_zip"
	create_runtime_archive "$sandbox" "$miniserver_zip"
	echo 'boxlang jar' > "$boxlang_jar"
	echo 'miniserver jar' > "$miniserver_jar"
	echo '#!/bin/sh' > "$scripts_dir/install-bvm.sh"
	cat > "$mock_bin/java" <<'EOF'
#!/bin/sh
printf '%s\n' "$*"
EOF
	chmod +x "$mock_bin/java"

	local output
	output=$(HOME="$boxlang_home" BOXLANG_INSTALL_HOME="$sandbox/install-boxlang" BOXLANG_HOME="$module_home" TERM="xterm-256color" \
		sh "$INSTALLER_SCRIPT" --force --without-commandbox --without-jre \
			--boxlang-path "$boxlang_jar" \
			--miniserver-path "$miniserver_jar" \
			--installer-scripts-path "$scripts_dir" 2>&1)
	assert_true "[ -f '$boxlang_install_home/lib/boxlang.jar' ]" "local BoxLang JAR is copied directly"
	assert_true "[ -f '$boxlang_install_home/lib/boxlang-miniserver.jar' ]" "local MiniServer JAR is copied directly"
	assert_contains "Installing BoxLang® from local artifacts to [$boxlang_install_home]" "$output" "local artifacts are reported accurately"
	assert_not_contains "Installing BoxLang® [latest]" "$output" "local artifacts are not reported as latest"
	assert_not_contains "Forcing reinstallation of BoxLang" "$output" "fresh forced install is not reported as a reinstallation"
	assert_not_contains "Unzipping Assets" "$output" "local JAR artifacts are not reported as unzipped"
	assert_not_contains "Checking for CommandBox" "$output" "CommandBox is not checked when disabled"
	assert_not_contains "CommandBox installation" "$output" "CommandBox handling is silent when disabled"
	assert_true "[ -d '$module_home/bin' ]" "module executable directory honors BOXLANG_HOME"
	assert_contains "Module executable directory: [$module_home/bin]" "$output" "module executable directory reports its actual location"
	assert_not_contains "[[: not found" "$output" "local JAR verification is POSIX-shell compatible"
	assert_not_contains "grep: ]" "$output" "profile update does not pass a malformed grep argument"
	ln -s "$boxlang_install_home/bin/boxlang" "$launcher_bin/boxlang"
	ln -s "$boxlang_install_home/bin/boxlang-miniserver" "$launcher_bin/boxlang-miniserver"
	local boxlang_launcher_output
	local miniserver_launcher_output
	boxlang_launcher_output=$(PATH="$mock_bin:$PATH" "$launcher_bin/boxlang" --version)
	miniserver_launcher_output=$(PATH="$mock_bin:$PATH" "$launcher_bin/boxlang-miniserver" --version)
	assert_contains "-jar $boxlang_install_home/lib/boxlang.jar --version" "$boxlang_launcher_output" "BoxLang JAR launcher works through a symlink"
	assert_contains "-jar $boxlang_install_home/lib/boxlang-miniserver.jar --version" "$miniserver_launcher_output" "MiniServer JAR launcher works through a symlink"

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

test_module_installer_parses_versions_with_posix_sh() {
	local sandbox
	sandbox="$(mktemp -d)"
	local module_library="$sandbox/install-bx-module-lib.sh"
	local output
	local exit_code=0

	sed '$d' "$MODULE_INSTALLER_SCRIPT" > "$module_library"
	mkdir -p "$sandbox/helpers"
	cp "$PROJECT_ROOT/src/helpers/helpers.sh" "$sandbox/helpers/helpers.sh"
	printf '\ninstall_module "@"\n' >> "$module_library"
	output=$(TERM="xterm-256color" sh "$module_library" 2>&1) || exit_code=$?
	assert_true "[ $exit_code -ne 0 ]" "module installer rejects a missing module name under POSIX sh"
	assert_contains "You must specify a BoxLang module" "$output" "module version parsing works under POSIX sh"
	rm -rf "$sandbox"
}

test_module_installer_preserves_escaped_json_control_characters() {
	local sandbox
	sandbox="$(mktemp -d)"
	local module_library="$sandbox/install-bx-module-lib.sh"
	local mock_bin="$sandbox/mock-bin"
	local output

	sed '$d' "$MODULE_INSTALLER_SCRIPT" > "$module_library"
	mkdir -p "$sandbox/helpers" "$mock_bin"
	cp "$PROJECT_ROOT/src/helpers/helpers.sh" "$sandbox/helpers/helpers.sh"
	cat > "$mock_bin/curl" <<'EOF'
#!/bin/sh
printf '%s\n' '{"data":{"version":"1.2.3","downloadURL":"https://example.test/module.zip","description":"line one\r\nline two"}}'
EOF
	cat > "$mock_bin/jq" <<'EOF'
#!/bin/sh
payload=$(cat)
case "$payload" in
*'\r\n'*) ;;
*)
	printf '%s\n' 'jq: parse error: Invalid string: control characters must be escaped' >&2
	exit 1
	;;
esac
case "$*" in
*.data.version*) printf '%s\n' '1.2.3' ;;
*.data.downloadURL*) printf '%s\n' 'https://example.test/module.zip' ;;
*) exit 1 ;;
esac
EOF
	chmod +x "$mock_bin/curl" "$mock_bin/jq"
	printf '\nget_latest_version_from_forgebox bx-cli\nprintf "%%s|%%s\\n" "$TARGET_VERSION" "$DOWNLOAD_URL"\n' >> "$module_library"
	output=$(PATH="$mock_bin:$PATH" TERM="xterm-256color" sh "$module_library")
	assert_contains "1.2.3|https://example.test/module.zip" "$output" "module installer preserves escaped JSON control characters under POSIX sh"
	assert_not_contains "jq: parse error" "$output" "module installer does not corrupt JSON before jq under POSIX sh"
	rm -rf "$sandbox"
}

test_local_zip_artifacts_install_without_curl
test_local_script_directory_is_copied
test_local_jars_are_copied_without_extraction
test_non_root_install_uses_user_local_paths
test_module_preflight_skips_java_and_requires_jq
test_module_installer_parses_versions_with_posix_sh
test_module_installer_preserves_escaped_json_control_characters

echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
[ "$TESTS_FAILED" -eq 0 ]