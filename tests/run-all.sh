#!/bin/sh

set -eu

repository=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
requested_distribution=${1:-}
docker_repository="$repository"
docker_path_conversion=""

case "$(uname -s)" in
	MINGW*|MSYS*)
		docker_repository=$(cygpath -w "$repository")
		docker_path_conversion="MSYS_NO_PATHCONV=1"
		;;
esac

if [ "$(docker info --format '{{.OSType}}')" != "linux" ]; then
	printf '%s\n' 'Docker must be switched to Linux containers.' >&2
	exit 1
fi

run_suite() {
	name="$1"
	image="$2"
	setup="$3"

	printf '\nRunning complete test suite in %s\n' "$name"
	if [ -n "$docker_path_conversion" ]; then
		MSYS_NO_PATHCONV=1 docker run --rm -v "$docker_repository:/workspace:ro" -w /workspace "$image" sh -c "$setup && sh tests/run.sh"
	else
		docker run --rm -v "$docker_repository:/workspace:ro" -w /workspace "$image" sh -c "$setup && sh tests/run.sh"
	fi
}

run_distribution() {
	case "$1" in
		alpine) run_suite Alpine alpine:3.20 'apk add --no-cache zip unzip >/dev/null' ;;
		debian) run_suite Debian debian:12 'apt-get update >/dev/null && DEBIAN_FRONTEND=noninteractive apt-get install -y zip unzip >/dev/null' ;;
		ubuntu) run_suite Ubuntu ubuntu:24.04 'apt-get update >/dev/null && DEBIAN_FRONTEND=noninteractive apt-get install -y zip unzip >/dev/null' ;;
		fedora) run_suite Fedora fedora:40 'dnf install -y util-linux zip unzip >/dev/null' ;;
		arch) run_suite Arch archlinux:latest 'pacman -Sy --noconfirm util-linux zip unzip >/dev/null' ;;
		*) printf 'Unknown Linux distribution: %s\n' "$1" >&2; exit 1 ;;
	esac

	sh "$repository/tests/run-offline-linux-container-tests.sh" "$1"
}

if [ -n "$requested_distribution" ]; then
	run_distribution "$requested_distribution"
else
	for distribution in alpine debian ubuntu fedora arch; do
		run_distribution "$distribution"
	done
fi

printf '%s\n' 'All Unix-like host test runs passed.'