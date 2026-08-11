#!/bin/sh

set -u

repository=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
requested_distribution=${1:-}
failed_distributions=""
docker_path_conversion=""

case "$(uname -s)" in
	MINGW*|MSYS*)
		repository=$(cygpath -w "$repository")
		docker_path_conversion="MSYS_NO_PATHCONV=1"
		;;
esac

run_offline_test() {
	name="$1"
	image="$2"
	setup="$3"
	prepared_image="boxlang-offline-$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')-$$"

	printf '\nRunning pristine offline test suite in %s\n' "$name"
	if ! printf 'FROM %s\nRUN %s\n' "$image" "$setup" | docker build --quiet --tag "$prepared_image" --file - "$repository"; then
		failed_distributions="${failed_distributions}${failed_distributions:+, }$name"
		printf 'Could not prepare the offline test image for %s.\n' "$name" >&2
		return
	fi
	if [ -n "$docker_path_conversion" ]; then
		MSYS_NO_PATHCONV=1 docker run --rm --network none -v "$repository:/workspace:ro" -w /workspace "$prepared_image" sh -c '
set -eu
if command -v useradd >/dev/null 2>&1; then
	useradd --create-home --shell /bin/sh boxlangtest
else
	adduser -D -h /home/boxlangtest -s /bin/sh boxlangtest
fi
if command -v su >/dev/null 2>&1; then
	HOME=/home/boxlangtest TERM=xterm-256color su boxlangtest -s /bin/sh tests/run.sh
else
	HOME=/home/boxlangtest TERM=xterm-256color runuser -u boxlangtest -- sh tests/run.sh
fi
'
	else
		docker run --rm --network none -v "$repository:/workspace:ro" -w /workspace "$prepared_image" sh -c '
set -eu
if command -v useradd >/dev/null 2>&1; then
	useradd --create-home --shell /bin/sh boxlangtest
else
	adduser -D -h /home/boxlangtest -s /bin/sh boxlangtest
fi
if command -v su >/dev/null 2>&1; then
	HOME=/home/boxlangtest TERM=xterm-256color su boxlangtest -s /bin/sh tests/run.sh
else
	HOME=/home/boxlangtest TERM=xterm-256color runuser -u boxlangtest -- sh tests/run.sh
fi
'
	fi
	status=$?
	docker image rm --force "$prepared_image" >/dev/null
	if [ "$status" -ne 0 ]; then
		failed_distributions="${failed_distributions}${failed_distributions:+, }$name"
		printf 'Offline test suite failed in %s.\n' "$name" >&2
	fi
}

if [ "$(docker info --format '{{.OSType}}')" != "linux" ]; then
	printf '%s\n' 'Docker must be switched to Linux containers.' >&2
	exit 1
fi

run_distribution() {
	case "$1" in
		alpine) run_offline_test Alpine alpine:3.20 'apk add --no-cache zip unzip >/dev/null' ;;
		debian) run_offline_test Debian debian:12 'apt-get update >/dev/null; DEBIAN_FRONTEND=noninteractive apt-get install -y zip unzip >/dev/null' ;;
		ubuntu) run_offline_test Ubuntu ubuntu:24.04 'apt-get update >/dev/null; DEBIAN_FRONTEND=noninteractive apt-get install -y zip unzip >/dev/null' ;;
		fedora) run_offline_test Fedora fedora:40 'dnf install -y util-linux zip unzip >/dev/null' ;;
		arch) run_offline_test Arch archlinux:latest 'pacman -Sy --noconfirm util-linux zip unzip >/dev/null' ;;
		*) printf 'Unknown Linux distribution: %s\n' "$1" >&2; exit 1 ;;
	esac
}

if [ -n "$requested_distribution" ]; then
	run_distribution "$requested_distribution"
else
	for distribution in alpine debian ubuntu fedora arch; do
		run_distribution "$distribution"
	done
fi

if [ -n "$failed_distributions" ]; then
	printf 'Offline test suite failed in: %s.\n' "$failed_distributions" >&2
	exit 1
fi

printf '%s\n' 'All pristine offline Linux test suites passed.'
