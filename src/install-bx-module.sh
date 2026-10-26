#!/bin/sh
# IMPORTANT: This script intentionally targets POSIX /bin/sh.
# Do not change the shebang back to Bash or reintroduce Bash-only syntax.
# It must remain compatible with Alpine BusyBox ash and standard /bin/sh.

# Legacy BoxLang Module Installer (install-bx-module)
# This is a thin shim kept for backwards compatibility. It translates the legacy
# flag-style arguments into bx-module commands and runs bx-module.sh, which
# lives next to this script. Use bx-module directly going forward.
# Author: BoxLang Team
# Version: @build.version@
# License: Apache License, Version 2.0

# Resolve this script's real location (it is usually run through a symlink in a
# bin directory) without relying on `readlink -f`, which is not portable.
SELF="$0"
while [ -L "$SELF" ]; do
	LINK_TARGET="$(readlink "$SELF")"
	case "$LINK_TARGET" in
		/*) SELF="$LINK_TARGET" ;;
		*)
			case "$SELF" in
				*/*) SELF="${SELF%/*}/$LINK_TARGET" ;;
				*) SELF="$LINK_TARGET" ;;
			esac
			;;
	esac
done
case "$SELF" in
	*/*) SCRIPT_DIR="${SELF%/*}" ;;
	*) SCRIPT_DIR="." ;;
esac

BX_MODULE="${SCRIPT_DIR}/bx-module.sh"
if [ ! -f "$BX_MODULE" ]; then
	printf 'Error: bx-module.sh not found next to install-bx-module. Please verify your installation.\n' >&2
	exit 1
fi

# Translate the legacy first argument into a bx-module command:
#   (no args) / <module> ...  -> install
#   --list / --outdated / --update / --remove -> list / outdated / update / remove
#   --help / -h               -> help
case "${1:-}" in
	--help | -h)
		shift
		set -- help "$@"
		;;
	--list | --outdated | --update | --remove)
		COMMAND="${1#--}"
		shift
		set -- "$COMMAND" "$@"
		;;
	*)
		set -- install "$@"
		;;
esac

printf "⚠️  'install-bx-module' is deprecated and now forwards to bx-module. Use: bx-module %s\n" "$*" >&2

exec /bin/sh "$BX_MODULE" "$@"
