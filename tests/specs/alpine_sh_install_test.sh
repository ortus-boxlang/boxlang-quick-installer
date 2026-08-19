#!/bin/sh

set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
install_home="$work/install"
user_home="$work/home"

mkdir -p "$work/scripts" "$user_home"
printf 'boxlang jar\n' > "$work/boxlang.jar"
printf 'miniserver jar\n' > "$work/boxlang-miniserver.jar"
printf '#!/bin/sh\nexit 0\n' > "$work/scripts/install-boxlang.sh"

HOME="$user_home" BOXLANG_INSTALL_HOME="$install_home" \
	"$project_root/src/install-boxlang.sh" \
		--force \
		--without-commandbox \
		--without-jre \
		--non-interactive \
		--boxlang-path "$work/boxlang.jar" \
		--miniserver-path "$work/boxlang-miniserver.jar" \
		--installer-scripts-path "$work/scripts"

if [ "$(id -u)" -eq 0 ]; then
	expected_install_home="$install_home"
else
	expected_install_home="$user_home/.local/boxlang"
fi

test -f "$expected_install_home/lib/boxlang.jar"
test -f "$expected_install_home/lib/boxlang-miniserver.jar"
test -x "$expected_install_home/bin/boxlang"
test -x "$expected_install_home/bin/boxlang-miniserver"

echo 'PASS: Alpine sh local-JAR installation'
