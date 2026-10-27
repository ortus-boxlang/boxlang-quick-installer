#!/bin/bash

# Test suite for the shell completions (bash, zsh, fish, PowerShell) of
# bvm, install-boxlang and bx-module.
# Author: BoxLang Team
# License: Apache License, Version 2.0

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$TEST_DIR")")"
COMPLETIONS="$PROJECT_ROOT/src/completions"

TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=""

assert_contains() {
	case "$2" in
		*"$1"*)
			echo "✅ PASS: $3"
			TESTS_PASSED=$((TESTS_PASSED + 1))
			;;
		*)
			echo "❌ FAIL: $3"
			echo "   Expected '$2' to contain '$1'"
			FAILED_TESTS="$FAILED_TESTS\n$3"
			TESTS_FAILED=$((TESTS_FAILED + 1))
			;;
	esac
}

assert_not_contains() {
	case "$2" in
		*"$1"*)
			echo "❌ FAIL: $3"
			echo "   Expected '$2' not to contain '$1'"
			FAILED_TESTS="$FAILED_TESTS\n$3"
			TESTS_FAILED=$((TESTS_FAILED + 1))
			;;
		*)
			echo "✅ PASS: $3"
			TESTS_PASSED=$((TESTS_PASSED + 1))
			;;
	esac
}

assert_success() {
	if [ "$1" -eq 0 ]; then
		echo "✅ PASS: $2"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		echo "❌ FAIL: $2"
		FAILED_TESTS="$FAILED_TESTS\n$2"
		TESTS_FAILED=$((TESTS_FAILED + 1))
	fi
}

TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

# Fake BVM and BoxLang homes with one installed version and one installed module
mkdir -p "$TEST_TMP/versions/1.2.0" "$TEST_TMP/modules/bx-orm"

# Runs a bash completion function for the given words and prints the candidates
bash_complete() {
	local fn="$1"
	shift
	BVM_HOME="$TEST_TMP" BOXLANG_HOME="$TEST_TMP" bash --norc -c '
		. "'"$COMPLETIONS"'/load.sh"
		fn="$1"; shift
		COMP_WORDS=("$@")
		COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
		COMPREPLY=()
		"$fn"
		echo "${COMPREPLY[*]}"
	' _ "$fn" "$@" 2>&1
}

###########################################################################
echo "Test: every completion file exists"
for cmd in bvm install-boxlang bx-module; do
	for ext in bash zsh fish; do
		[ -f "$COMPLETIONS/$ext/$cmd.$ext" ]
		assert_success $? "$ext completion exists for $cmd"
	done
	[ -f "$COMPLETIONS/powershell/$cmd.ps1" ]
	assert_success $? "powershell completion exists for $cmd"
done

###########################################################################
echo "Test: bash completions"
out="$(bash_complete _bvm_complete bvm "")"
assert_contains "install" "$out" "bvm completes subcommands"
assert_contains "doctor" "$out" "bvm completes doctor"

out="$(bash_complete _bvm_complete bvm use "")"
assert_contains "1.2.0" "$out" "bvm use completes installed versions"
assert_contains "latest" "$out" "bvm use completes latest"

out="$(bash_complete _bvm_complete bvm rm "")"
assert_contains "1.2.0" "$out" "bvm rm completes installed versions"
assert_not_contains "latest" "$out" "bvm rm does not offer latest"

out="$(bash_complete _bvm_complete bvm install --f)"
assert_contains "--force" "$out" "bvm install completes --force"

out="$(bash_complete _install_boxlang_complete install-boxlang --with)"
assert_contains "--with-jre" "$out" "install-boxlang completes --with-jre"
assert_contains "--without-commandbox" "$out" "install-boxlang completes --without-commandbox"

out="$(bash_complete _install_boxlang_complete install-boxlang "")"
assert_contains "snapshot" "$out" "install-boxlang completes snapshot"

out="$(bash_complete _bx_module_complete bx-module "")"
assert_contains "outdated" "$out" "bx-module completes subcommands"

out="$(bash_complete _bx_module_complete bx-module remove "")"
assert_contains "bx-orm" "$out" "bx-module remove completes installed modules"

out="$(bash_complete _bx_module_complete bx-module update --)"
assert_contains "--force" "$out" "bx-module update completes --force"
assert_contains "--local" "$out" "bx-module update completes --local"

out="$(bash_complete _bx_module_complete bx-module list --)"
assert_not_contains "--force" "$out" "bx-module list does not offer --force"

###########################################################################
echo "Test: completions stay in sync with the scripts"
for flag in $(grep -oE '"--[a-z-]+"' "$PROJECT_ROOT/src/install-boxlang.sh" | tr -d '"' | sort -u); do
	for ext in bash fish; do
		name="${flag#--}"
		case "$ext" in
			bash) needle="$flag" ;;
			fish) needle="-l $name" ;;
		esac
		grep -qF -- "$needle" "$COMPLETIONS/$ext/install-boxlang.$ext"
		assert_success $? "install-boxlang.$ext handles $flag"
	done
done

for cmd in $(sed -n '/^main()/,/^}/p' "$PROJECT_ROOT/src/bvm.sh" | grep -oE '^\s+"[a-z-]+"(\|"[a-z-]+")*\)' | grep -oE '"[a-z][a-z-]*"' | tr -d '"' | sort -u); do
	grep -qw -- "$cmd" "$COMPLETIONS/bash/bvm.bash"
	assert_success $? "bvm.bash handles the $cmd command"
done

###########################################################################
echo "Test: loader is idempotent and wired into the init scripts"
out="$(BVM_HOME="$TEST_TMP" bash --norc -c '. "'"$COMPLETIONS"'/load.sh"; . "'"$COMPLETIONS"'/load.sh"; complete -p bvm install-boxlang bx-module install-bx-module' 2>&1)"
assert_contains "_bvm_complete bvm" "$out" "bvm completion is registered"
assert_contains "_install_boxlang_complete install-boxlang" "$out" "install-boxlang completion is registered"
assert_contains "_bx_module_complete bx-module" "$out" "bx-module completion is registered"
assert_contains "_bx_module_complete install-bx-module" "$out" "install-bx-module legacy alias completion is registered"

grep -q 'completions/load.sh' "$PROJECT_ROOT/src/bvm-init.sh"
assert_success $? "bvm-init.sh loads completions/load.sh"
grep -q 'completions/load.fish' "$PROJECT_ROOT/src/bvm-init.fish"
assert_success $? "bvm-init.fish loads completions/load.fish"

###########################################################################
echo "Test: syntax of the shell specific files"
for f in "$COMPLETIONS"/bash/*.bash "$COMPLETIONS/load.sh"; do
	bash -n "$f"
	assert_success $? "bash syntax ok: ${f#"$PROJECT_ROOT"/}"
done
if command -v zsh >/dev/null 2>&1; then
	for f in "$COMPLETIONS"/zsh/*.zsh; do
		zsh -n "$f"
		assert_success $? "zsh syntax ok: ${f#"$PROJECT_ROOT"/}"
	done
else
	echo "⚠️  SKIP: zsh not installed"
fi
if command -v fish >/dev/null 2>&1; then
	for f in "$COMPLETIONS"/fish/*.fish "$COMPLETIONS/load.fish"; do
		fish --no-execute "$f"
		assert_success $? "fish syntax ok: ${f#"$PROJECT_ROOT"/}"
	done
	out="$(BVM_HOME="$TEST_TMP" fish -c 'source "'"$COMPLETIONS"'/load.fish"; complete -C "bvm use "' 2>&1)"
	assert_contains "1.2.0" "$out" "fish bvm use completes installed versions"
	out="$(BOXLANG_HOME="$TEST_TMP" fish -c 'source "'"$COMPLETIONS"'/load.fish"; complete -C "bx-module remove "' 2>&1)"
	assert_contains "bx-orm" "$out" "fish bx-module remove completes installed modules"
else
	echo "⚠️  SKIP: fish not installed"
fi

###########################################################################
echo ""
echo "Completions tests: $TESTS_PASSED passed, $TESTS_FAILED failed"
if [ "$TESTS_FAILED" -gt 0 ]; then
	printf "Failed tests:%b\n" "$FAILED_TESTS"
	exit 1
fi
exit 0
