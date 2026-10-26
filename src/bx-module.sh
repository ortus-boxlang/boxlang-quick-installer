#!/bin/sh
# IMPORTANT: This script intentionally targets POSIX /bin/sh.
# Do not change the shebang back to Bash or reintroduce Bash-only syntax.
# It must remain compatible with Alpine BusyBox ash and standard /bin/sh.

# BoxLang Module Manager (bx-module)
# This script installs and manages BoxLang modules from FORGEBOX using verbs:
# install, remove, list, outdated, update. The legacy install-bx-module command
# is a thin shim that translates its flags and calls this script.
# Author: BoxLang Team
# Version: @build.version@
# License: Apache License, Version 2.0

set -e

###########################################################################
# Global Variables + Helpers
###########################################################################

# Configuration
FORGEBOX_API_URL="https://forgebox.io/api/v1"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# A literal tab character for use as an IFS field separator when parsing
# tab-delimited jq output. `$'\t'` is a bash/ksh-ism that POSIX /bin/sh
# (dash, BusyBox ash) does not expand, so it must be built with printf instead.
TAB="$(printf '\t')"
# Nested install state. A module's box.json dependencies are installed as nested
# modules inside "<module>/modules/". While installing one, NESTED_INSTALL is true
# (so the shared modules manifest is left alone) and ROOT_MODULES_HOME remembers the
# top-level modules directory so duplicate installs can be flagged.
NESTED_INSTALL=false
ROOT_MODULES_HOME=""

# We need this in case the target OS we are installing in does not have a `TERM` implementation declared
# or when TERM is set to problematic values like "unknown" (common in CI environments like GitHub Actions or Docker containers)
if [ -z "$TERM" ] || [ "$TERM" = "unknown" ] || [ "$TERM" = "dumb" ]; then
	export TERM="xterm-256color"
fi

# Include the helper functions
# These are installed by the installer script
if [ -f "$SCRIPT_DIR/helpers/helpers.sh" ]; then
	. "$SCRIPT_DIR/helpers/helpers.sh"
elif [ -f "${BOXLANG_INSTALL_HOME}/scripts/helpers/helpers.sh" ]; then
	. "${BOXLANG_INSTALL_HOME}/scripts/helpers/helpers.sh"
elif [ -f "${BVM_HOME}/scripts/helpers/helpers.sh" ]; then
    . "${BVM_HOME}/scripts/helpers/helpers.sh"
else
	printf "${RED}Error: Helper scripts not found. Please verify your installation.${NORMAL}\n"
	exit 1
fi

###########################################################################
# ACTION FUNCTIONS
###########################################################################

parse_module_list() {
	local input=""

	# Concatenate all arguments into a single string
	for arg in "$@"; do
		# Skip flags
		case "$arg" in
		--*) ;;
		*) input="$input $arg" ;;
		esac
	done

	# Replace commas with spaces and normalize whitespace
	input=$(echo "$input" | sed 's/,/ /g' | tr -s ' ')

	# Split by spaces and output each module.
	for module in $input; do
		if [ -n "$module" ]; then
			printf '%s\n' "$module"
		fi
	done
}

show_help() {
	local VERB=${1:-}

	if [ -n "$VERB" ]; then
		show_verb_help "$VERB"
		return $?
	fi

	printf "${GREEN}📦 BoxLang Module Manager${NORMAL}\n\n"
	printf "${YELLOW}Install, remove, list, and update BoxLang modules from FORGEBOX.${NORMAL}\n\n"
	printf "${BOLD}USAGE:${NORMAL}\n"
	printf "  bx-module <command> [arguments] [options]\n\n"
	printf "${BOLD}COMMANDS:${NORMAL}\n"
	printf "  install [<module>[@<version>] ...]   Install module(s), or a project box.json's dependencies when none are given\n"
	printf "  remove <module> [<module> ...]       Remove module(s)\n"
	printf "  list                                 Show installed module(s), including nested dependencies\n"
	printf "  outdated                             Check installed modules against FORGEBOX and report which are outdated\n"
	printf "  update [<module> ...]                Update outdated module(s), or only the named ones, to their latest FORGEBOX version\n"
	printf "  help [<command>]                     Show this help, or help for one command\n\n"
	printf "${BOLD}OPTIONS:${NORMAL}\n"
	printf "  --local           Work with the local boxlang_modules folder instead of BoxLang HOME. The BoxLang HOME is the default.\n"
	printf "  --force           Skip the confirmation prompt (remove and update)\n"
	printf "  --help, -h        Show help\n\n"
	printf "${BOLD}EXAMPLES:${NORMAL}\n"
	printf "  bx-module install bx-orm\n"
	printf "  bx-module install bx-orm@2.5.0 bx-ai --local\n"
	printf "  bx-module install bx-orm,bx-ai,bx-esapi\n"
	printf "  bx-module install                        # install ./box.json dependencies\n"
	printf "  bx-module remove bx-orm --force\n"
	printf "  bx-module list --local\n"
	printf "  bx-module outdated\n"
	printf "  bx-module update bx-sites\n"
	printf "  bx-module update --force\n\n"
	printf "${BOLD}NOTES:${NORMAL}\n"
	printf "  - If no version is specified, the latest version from FORGEBOX will be installed\n"
	printf "  - Multiple modules can be specified, separated by spaces or commas: 'bx-orm, bx-ai bx-esapi'\n"
	printf "  - Without --local, modules are managed in BoxLang HOME (~/.boxlang/modules)\n"
	printf "  - Requires curl and jq to be installed\n"
	printf "  - Dependencies declared in a module's box.json are installed automatically as nested modules inside the module's own modules/ folder (latest version for \"*\", otherwise the version specified, including \"be\" or \"snapshot\")\n"
	printf "  - Nested dependencies are shown (indented) by list, outdated and update, and are removed together with their parent module\n"
	printf "  - A module can declare \"boxlang\": { \"completions\": \"<path-to-bash-completion-script>\" } in its box.json to have a bash completion script installed and auto-loaded in new shells\n"
	printf "  - The legacy install-bx-module command still works and forwards to bx-module\n"
}

# Help for a single command.
show_verb_help() {
	local VERB=${1}

	case "$VERB" in
		install)
			printf "${BOLD}USAGE:${NORMAL}\n"
			printf "  bx-module install <module>[@<version>] [<module>[@<version>] ...] [--local]\n"
			printf "  bx-module install [--local]        (installs the dependencies of ./box.json)\n\n"
			printf "Installs module(s) from FORGEBOX. <version> may be an exact version, \"be\", or \"snapshot\".\n"
			printf "Module dependencies are installed as nested modules inside the module's modules/ folder.\n\n"
			printf "${BOLD}EXAMPLES:${NORMAL}\n"
			printf "  bx-module install bx-orm\n"
			printf "  bx-module install bx-orm@2.5.0 bx-ai --local\n"
			;;
		remove)
			printf "${BOLD}USAGE:${NORMAL}\n"
			printf "  bx-module remove <module> [<module> ...] [--force] [--local]\n\n"
			printf "Removes module(s), including their nested dependencies. Asks for confirmation unless --force is given.\n\n"
			printf "${BOLD}EXAMPLES:${NORMAL}\n"
			printf "  bx-module remove bx-orm\n"
			printf "  bx-module remove bx-orm,bx-ai --force\n"
			;;
		list)
			printf "${BOLD}USAGE:${NORMAL}\n"
			printf "  bx-module list [--local]\n\n"
			printf "Shows installed module(s), with nested dependencies indented under their parent.\n"
			;;
		outdated)
			printf "${BOLD}USAGE:${NORMAL}\n"
			printf "  bx-module outdated [--local]\n\n"
			printf "Checks installed modules (and nested dependencies) against FORGEBOX and reports which are outdated.\n"
			;;
		update)
			printf "${BOLD}USAGE:${NORMAL}\n"
			printf "  bx-module update [<module> ...] [--force] [--local]\n\n"
			printf "Updates outdated module(s) to their latest FORGEBOX version. With module names, only those are updated.\n"
			printf "Asks for confirmation unless --force is given.\n\n"
			printf "${BOLD}EXAMPLES:${NORMAL}\n"
			printf "  bx-module update\n"
			printf "  bx-module update bx-sites --force\n"
			;;
		*)
			printf "${RED}❌ Error: Unknown command '${VERB}'${NORMAL}\n"
			printf "${YELLOW}💡 Commands: install, remove, list, outdated, update, help${NORMAL}\n"
			return 1
			;;
	esac
}

# Reads the version of an installed module from its own box.json ("unknown" if absent).
read_module_version() {
	local MODULE_DIR=${1}
	local VERSION=""
	if [ -f "${MODULE_DIR}/box.json" ]; then
		VERSION=$(jq -r '.version // empty' "${MODULE_DIR}/box.json" 2>/dev/null || true)
	fi
	if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
		VERSION="unknown"
	fi
	echo "$VERSION"
}

# Prints the modules nested inside a modules/ directory, indented by depth,
# recursing into each nested module's own modules/ folder.
print_nested_modules() {
	local NESTED_DIR=${1}
	local DEPTH=${2:-1}

	[ -d "${NESTED_DIR}" ] || return 0

	local INDENT="" i=0
	while [ "$i" -lt "$DEPTH" ]; do
		INDENT="${INDENT}  "
		i=$((i + 1))
	done

	local dir name
	for dir in "${NESTED_DIR}"/*/; do
		[ -d "$dir" ] || continue
		dir="${dir%/}"
		name="${dir##*/}"
		printf -- "%s↳ %s (%s)\n" "$INDENT" "$name" "$(read_module_version "$dir")"
		print_nested_modules "${dir}/modules" $((DEPTH + 1))
	done
}

list_modules() {
	local MODULES_PATH=${1}
	local LOCATION_DESC=${2}
	local BOX_JSON_PATH

	printf "${YELLOW}📋 Installed BoxLang Modules (${LOCATION_DESC}):${NORMAL}\n"

	# Check if modules directory exists
	if [ ! -d "${MODULES_PATH}" ]; then
		printf "${YELLOW}📂 No modules directory found at ${MODULES_PATH}${NORMAL}\n"
		return 0
	fi

	BOX_JSON_PATH=$(ensure_modules_manifest "${MODULES_PATH}")

	# Read installed modules from the manifest.
	# `|| true` keeps a jq failure (e.g. unreadable manifest) from tripping `set -e`.
	local DEP_COUNT
	DEP_COUNT=$(jq -r '.dependencies // {} | length' "${BOX_JSON_PATH}" 2>/dev/null || true)

	# DEP_COUNT can be empty or non-numeric when jq produced no output, so only
	# run the numeric comparison when it holds a valid integer. Without this
	# guard, POSIX sh (dash / BusyBox ash) raises "Illegal number" on an empty
	# or non-numeric value instead of short-circuiting cleanly.
	if [ -z "$DEP_COUNT" ] || [ "${DEP_COUNT:-0}" -eq 0 ] 2>/dev/null; then
		printf "${YELLOW}📭 No modules installed${NORMAL}\n"
	else
		jq -r '.dependencies // {} | to_entries[] | "\(.key)\t\(.value)"' "${BOX_JSON_PATH}" 2>/dev/null |
		while IFS="$TAB" read -r module_name module_version; do
			printf -- "✓ %s (%s)\n" "$module_name" "$module_version"
			print_nested_modules "${MODULES_PATH}/${module_name}/modules" 1
		done
	fi
}

resolve_forgebox_storage_url() {
	local MODULE_NAME=${1}
	local VERSION=${2:-""}

	local STORAGE_URL
	if [ -z "$VERSION" ]; then
		# Latest version
		STORAGE_URL="${FORGEBOX_API_URL}/storage/${MODULE_NAME}"
	else
		# Specific version
		STORAGE_URL="${FORGEBOX_API_URL}/storage/${MODULE_NAME}/${VERSION}"
	fi

	printf "${BLUE}🔗 Resolving secure download URL from ForgeBox storage...${NORMAL}\n" >&2

	# Get the secure download URL
	local STORAGE_JSON=$(curl -sSL "${STORAGE_URL}")

	if [ -z "$STORAGE_JSON" ] || [ "$STORAGE_JSON" = "null" ]; then
		printf "${RED}❌ Error: Failed to get secure download URL from ForgeBox storage${NORMAL}\n" >&2
		exit 1
	fi

	local SECURE_URL=$(printf '%s\n' "${STORAGE_JSON}" | jq -r '.data')

	if [ "$SECURE_URL" = "null" ] || [ -z "$SECURE_URL" ]; then
		printf "${RED}❌ Error: Invalid response from ForgeBox storage${NORMAL}\n" >&2
		exit 1
	fi

	echo "$SECURE_URL"
}

get_latest_version_from_forgebox() {
	local MODULE_NAME=${1}

	printf "${YELLOW}🔍 No version specified, getting latest version from FORGEBOX...${NORMAL}\n"

	# Store Entry JSON From ForgeBox
	local ENTRY_JSON=$(curl -sSL "${FORGEBOX_API_URL}/entry/${MODULE_NAME}/latest")

	# Validate API response
	if [ -z "$ENTRY_JSON" ] || [ "$ENTRY_JSON" = "null" ]; then
		printf "${RED}❌ Error: Failed to fetch module information from FORGEBOX${NORMAL}\n"
		exit 1
	fi

	local VERSION=$(printf '%s\n' "${ENTRY_JSON}" | jq -r '.data.version')
	local DOWNLOAD_URL_TEMP=$(printf '%s\n' "${ENTRY_JSON}" | jq -r '.data.downloadURL')

	# Validate parsed data
	if [ "$VERSION" = "null" ] || [ -z "$VERSION" ]; then
		printf "${RED}❌ Error: Module '${MODULE_NAME}' not found in FORGEBOX${NORMAL}\n"
		exit 1
	fi

	if [ "$DOWNLOAD_URL_TEMP" = "null" ] || [ -z "$DOWNLOAD_URL_TEMP" ]; then
		printf "${RED}❌ Error: No download URL found for module '${MODULE_NAME}'${NORMAL}\n"
		exit 1
	fi

	# Check if download URL is forgeboxStorage keyword
	if [ "$DOWNLOAD_URL_TEMP" = "forgeboxStorage" ]; then
		DOWNLOAD_URL_TEMP=$(resolve_forgebox_storage_url "$MODULE_NAME")
	fi

	# Return values via global variables
	TARGET_VERSION="$VERSION"
	DOWNLOAD_URL="$DOWNLOAD_URL_TEMP"
}

get_be_version_from_forgebox() {
	local MODULE_NAME=${1}

	printf "${YELLOW}🔍 Getting latest bleeding edge version from FORGEBOX...${NORMAL}\n"

	# Store versions JSON From ForgeBox (versions only)
	local VERSIONS_JSON=$(curl -sSL "${FORGEBOX_API_URL}/entry/${MODULE_NAME}/versions")

	# Validate API response
	if [ -z "$VERSIONS_JSON" ] || [ "$VERSIONS_JSON" = "null" ]; then
		printf "${RED}❌ Error: Failed to fetch version information from FORGEBOX${NORMAL}\n"
		exit 1
	fi

	# Take the first (latest) version regardless of stable/pre-release status
	# The ForgeBox API returns versions in newest-first order
	local VERSION=$(printf '%s\n' "${VERSIONS_JSON}" | jq -r '.data[0].version')

	# Validate parsed data
	if [ "$VERSION" = "null" ] || [ -z "$VERSION" ]; then
		printf "${RED}❌ Error: No version(s) found for module '${MODULE_NAME}' in FORGEBOX${NORMAL}\n"
		exit 1
	fi

	# Get the full entry info for this version to check for forgeboxStorage
	local VERSION_JSON=$(curl -sSL "${FORGEBOX_API_URL}/entry/${MODULE_NAME}/versions/${VERSION}")
	if [ -n "$VERSION_JSON" ] && [ "$VERSION_JSON" != "null" ]; then
		local DOWNLOAD_URL_TEMP=$(printf '%s\n' "${VERSION_JSON}" | jq -r '.data.downloadURL')
		if [ "$DOWNLOAD_URL_TEMP" = "forgeboxStorage" ]; then
			DOWNLOAD_URL_TEMP=$(resolve_forgebox_storage_url "$MODULE_NAME" "$VERSION")
		elif [ "$DOWNLOAD_URL_TEMP" != "null" ] && [ -n "$DOWNLOAD_URL_TEMP" ]; then
			# Use the download URL from API
			DOWNLOAD_URL_TEMP="$DOWNLOAD_URL_TEMP"
		else
			# Fallback: build download URL from the artifacts directly
			DOWNLOAD_URL_TEMP="https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/${MODULE_NAME}/${VERSION}/${MODULE_NAME}-${VERSION}.zip"
		fi
	else
		# Fallback: build download URL from the artifacts directly
		DOWNLOAD_URL_TEMP="https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/${MODULE_NAME}/${VERSION}/${MODULE_NAME}-${VERSION}.zip"
	fi

	# Return values via global variables
	TARGET_VERSION="$VERSION"
	DOWNLOAD_URL="$DOWNLOAD_URL_TEMP"
}

get_snapshot_version_from_forgebox() {
	local MODULE_NAME=${1}

	printf "${YELLOW}🔍 Getting latest snapshot version from FORGEBOX...${NORMAL}\n"

	# Store versions JSON From ForgeBox (versions only)
	local VERSIONS_JSON=$(curl -sSL "${FORGEBOX_API_URL}/entry/${MODULE_NAME}/versions")

	#echo "${VERSIONS_JSON}" | jq -e '.data'

	# Validate API response
	if [ -z "$VERSIONS_JSON" ] || [ "$VERSIONS_JSON" = "null" ]; then
		printf "${RED}❌ Error: Failed to fetch version information from FORGEBOX${NORMAL}\n"
		exit 1
	fi

	# Find the first version with "-snapshot" in the versions array
	local VERSION=$(printf '%s\n' "${VERSIONS_JSON}" | jq -r '.data[] | select(.version | contains("-snapshot")) | .version' | head -n 1)

	# Validate parsed data
	if [ "$VERSION" = "null" ] || [ -z "$VERSION" ]; then
		printf "${RED}❌ Error: No snapshot version(s) found for module '${MODULE_NAME}' in FORGEBOX${NORMAL}\n"
		exit 1
	fi

	# Get the full entry info for this version to check for forgeboxStorage
	local VERSION_JSON=$(curl -sSL "${FORGEBOX_API_URL}/entry/${MODULE_NAME}/${VERSION}")
	if [ -n "$VERSION_JSON" ] && [ "$VERSION_JSON" != "null" ]; then
		local DOWNLOAD_URL_TEMP=$(printf '%s\n' "${VERSION_JSON}" | jq -r '.data.downloadURL')
		if [ "$DOWNLOAD_URL_TEMP" = "forgeboxStorage" ]; then
			DOWNLOAD_URL_TEMP=$(resolve_forgebox_storage_url "$MODULE_NAME" "$VERSION")
		elif [ "$DOWNLOAD_URL_TEMP" != "null" ] && [ -n "$DOWNLOAD_URL_TEMP" ]; then
			# Use the download URL from API
			DOWNLOAD_URL_TEMP="$DOWNLOAD_URL_TEMP"
		else
			# Fallback: build download URL from the artifacts directly
			DOWNLOAD_URL_TEMP="https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/${MODULE_NAME}/${VERSION}/${MODULE_NAME}-${VERSION}.zip"
		fi
	else
		# Fallback: build download URL from the artifacts directly
		DOWNLOAD_URL_TEMP="https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/${MODULE_NAME}/${VERSION}/${MODULE_NAME}-${VERSION}.zip"
	fi

	# Return values via global variables
	TARGET_VERSION="$VERSION"
	DOWNLOAD_URL="$DOWNLOAD_URL_TEMP"
}

install_module() {
	local INPUT=${1}
	# Space-delimited list of modules already being installed up the dependency
	# chain (including the module currently being processed). Used to guard
	# against circular dependencies when recursively installing box.json deps.
	local VISITED=${2:-""}
	local TARGET_MODULE=""
	local TARGET_VERSION=""

	case "$INPUT" in
		*@*)
			TARGET_MODULE=$(echo "$INPUT" | cut -d'@' -f1 | tr '[:upper:]' '[:lower:]')
			TARGET_VERSION=$(echo "$INPUT" | cut -d'@' -f2)
			;;
		*) TARGET_MODULE=$(echo "$INPUT" | tr '[:upper:]' '[:lower:]') ;;
	esac

	# Validate module name
	if [ -z "$TARGET_MODULE" ]; then
		printf "${RED}❌ Error: You must specify a BoxLang module to install${NORMAL}\n"
		printf "${YELLOW}💡 Usage: bx-module install <module-name>[@<version>] [--local]${NORMAL}\n"
		exit 1
	fi

	# Check curl existence
	command_exists curl || {
		printf "${RED}❌ Error: curl is required but not installed${NORMAL}\n"
		exit 1
	}

	# Fetch version based on specification
	if [ -z "${TARGET_VERSION+x}" ] || [ -z "$TARGET_VERSION" ]; then
		get_latest_version_from_forgebox "$TARGET_MODULE"
		# Use the global variables set by the function
		local DOWNLOAD_URL="$DOWNLOAD_URL"
	elif [ "$TARGET_VERSION" = "be" ]; then
		get_be_version_from_forgebox "$TARGET_MODULE"
		# Use the global variables set by the function
		local DOWNLOAD_URL="$DOWNLOAD_URL"
	elif [ "$TARGET_VERSION" = "snapshot" ]; then
		get_snapshot_version_from_forgebox "$TARGET_MODULE"
		# Use the global variables set by the function
		local DOWNLOAD_URL="$DOWNLOAD_URL"
	else
		# We have a targeted version, first try to get it from ForgeBox API to check for forgeboxStorage
		local VERSION_JSON=$(curl -sSL "${FORGEBOX_API_URL}/entry/${TARGET_MODULE}/versions/${TARGET_VERSION}")
		if [ -n "$VERSION_JSON" ] && [ "$VERSION_JSON" != "null" ]; then
			local DOWNLOAD_URL_TEMP=$(printf '%s\n' "${VERSION_JSON}" | jq -r '.data.downloadURL')
			if [ "$DOWNLOAD_URL_TEMP" = "forgeboxStorage" ]; then
				local DOWNLOAD_URL=$(resolve_forgebox_storage_url "$TARGET_MODULE" "$TARGET_VERSION")
			elif [ "$DOWNLOAD_URL_TEMP" != "null" ] && [ -n "$DOWNLOAD_URL_TEMP" ]; then
				# Use the download URL from API if available
				local DOWNLOAD_URL="$DOWNLOAD_URL_TEMP"
			else
				# Fallback: build the download URL from the artifacts directly
				local DOWNLOAD_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/${TARGET_MODULE}/${TARGET_VERSION}/${TARGET_MODULE}-${TARGET_VERSION}.zip"
			fi
		else
			# Fallback: build the download URL from the artifacts directly
			local DOWNLOAD_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/${TARGET_MODULE}/${TARGET_VERSION}/${TARGET_MODULE}-${TARGET_VERSION}.zip"
		fi
	fi

	# Define paths based on LOCAL_INSTALL flag
	local DESTINATION="${MODULES_HOME}/${TARGET_MODULE}"

	# Check if module is already installed
	if [ -d "${DESTINATION}" ]; then
		printf "${YELLOW}⚠️  Module '${TARGET_MODULE}' is already installed at ${DESTINATION}${NORMAL}\n"
		printf "${YELLOW}🔄 Proceeding with installation (will overwrite existing)...${NORMAL}\n"
		rm -rf "${DESTINATION}"
	fi

	# Inform the user
	printf "${GREEN}📦 Installing BoxLang® Module: ${TARGET_MODULE}@${TARGET_VERSION}\n"
	printf "📍 Destination: ${DESTINATION}\n${NORMAL}\n"

	# Ensure module folders exist
	mkdir -p "${MODULES_HOME}"

	# Create secure temporary file
	local TEMP_FILE="$(mktemp -t "${TARGET_MODULE}.XXXXXX")"
	TEMP_FILE="${TEMP_FILE}.zip"
	# Add a trap to remove the temp file on exit
	trap 'rm -f "${TEMP_FILE}"' EXIT

	# Download module
	printf "${BLUE}⬇️  Downloading...${NORMAL}\n"
	if ! curl -L --fail --progress-bar -o "${TEMP_FILE}" "${DOWNLOAD_URL}"; then
		printf "${RED}❌ Error: Download failed${NORMAL}\n"
		exit 1
	fi

	# Record installation by calling forgebox at: /api/v1/install/${TARGET_MODULE}/${TARGET_VERSION}
	printf "${BLUE}📊 Recording installation with FORGEBOX...${NORMAL}\n"
	if ! curl -s -o /dev/null "${FORGEBOX_API_URL}/install/${TARGET_MODULE}/${TARGET_VERSION}"; then
		printf "${YELLOW}⚠️  Warning: Failed to record installation with FORGEBOX, but continuing...${NORMAL}\n"
	fi

	# Remove existing module folder
	rm -rf "${DESTINATION}"

	# Extract module
	printf "${BLUE}📦 Extracting module...${NORMAL}\n"
	if ! unzip -q -o "${TEMP_FILE}" -d "${DESTINATION}"; then
		printf "${RED}❌ Error: Failed to extract module${NORMAL}\n"
		exit 1
	fi

	# Verify extraction
	if [ ! -d "${DESTINATION}" ] || [ -z "$(ls -A "${DESTINATION}" 2>/dev/null)" ]; then
		printf "${RED}❌ Error: Module extraction appears to have failed - destination directory is empty${NORMAL}\n"
		exit 1
	fi
	# Check for executables in box.json and create bin scripts
	local BOX_JSON_PATH="${DESTINATION}/box.json"
	if [ -f "${BOX_JSON_PATH}" ]; then
		# Get BOXLANG_HOME for bin directory
		local BIN_DIR
		if [ "$LOCAL_INSTALL" = true ]; then
			BIN_DIR="$(pwd)/boxlang_modules/.bin"
		else
			if [ -z "${BOXLANG_HOME}" ]; then
				export BOXLANG_HOME="$HOME/.boxlang"
			fi
			BIN_DIR="${BOXLANG_HOME}/bin"
		fi

		# Create bin directory if it doesn't exist
		mkdir -p "${BIN_DIR}"

		# Get the module name to use for execution (check boxlang.moduleName first, fallback to TARGET_MODULE)
		local MODULE_NAME=$(jq -r '.boxlang.moduleName // empty' "${BOX_JSON_PATH}" 2>/dev/null)
		if [ -z "${MODULE_NAME}" ]; then
			MODULE_NAME="${TARGET_MODULE}"
		fi

		# Check for boxlang.executable (single executable)
		local EXECUTABLE=$(jq -r '.boxlang.executable // empty' "${BOX_JSON_PATH}" 2>/dev/null)
		if [ -n "${EXECUTABLE}" ]; then
			local EXEC_SCRIPT="${BIN_DIR}/${EXECUTABLE}"
			printf "${BLUE}🔧 Creating executable script: ${EXECUTABLE}${NORMAL}\n"
			cat > "${EXEC_SCRIPT}" << EOF
#!/bin/sh
boxlang module:${MODULE_NAME} "\$@"
EOF
			chmod +x "${EXEC_SCRIPT}"
		fi

		# Check for boxlang.executables (multiple executables)
		local EXECUTABLES=$(jq -r '.boxlang.executables // empty' "${BOX_JSON_PATH}" 2>/dev/null)
		if [ -n "${EXECUTABLES}" ] && [ "${EXECUTABLES}" != "null" ]; then
			# Get all executable names (keys)
			local EXEC_NAMES=$(echo "${EXECUTABLES}" | jq -r 'keys[]' 2>/dev/null)
			if [ -n "${EXEC_NAMES}" ]; then
				printf "${BLUE}🔧 Creating executable scripts...${NORMAL}\n"
				printf '%s\n' "${EXEC_NAMES}" | while IFS= read -r exec_name; do
					if [ -n "${exec_name}" ]; then
						local exec_content=$(echo "${EXECUTABLES}" | jq -r ".\"${exec_name}\"" 2>/dev/null)
						if [ -n "${exec_content}" ] && [ "${exec_content}" != "null" ]; then
							local exec_script="${BIN_DIR}/${exec_name}"
							printf "${BLUE}  - Creating: ${exec_name}${NORMAL}\n"
							echo "${exec_content}" > "${exec_script}"
							chmod +x "${exec_script}"
						fi
					fi
				done
			fi
		fi

		# Check for boxlang.completions (a bash completion script shipped with the module)
		install_module_completions "${DESTINATION}" "${TARGET_MODULE}"
	fi

	# Install any module dependencies declared in the extracted module's box.json
	# as nested modules inside this module's own modules/ folder
	install_module_dependencies "${DESTINATION}" "${VISITED} ${TARGET_MODULE}" true

	# Track this install in the modules manifest. Nested dependencies are tracked by
	# their parent module's own box.json, so they never touch the shared manifest.
	if [ "$NESTED_INSTALL" != true ]; then
		box_json_set_dependency "${MODULES_HOME}/box.json" "${TARGET_MODULE}" "${TARGET_VERSION}"
	fi

	# Success message
	printf "${GREEN}✅ BoxLang® Module [${TARGET_MODULE}@${TARGET_VERSION}] installed!${NORMAL}\n"
}

# Resolves the shared completions directory for the current install mode
# (global BoxLang HOME, or the local boxlang_modules folder with --local).
completions_dir() {
	if [ "$LOCAL_INSTALL" = true ]; then
		echo "$(pwd)/boxlang_modules/.completions"
	else
		echo "${BOXLANG_HOME}/completions"
	fi
}

# Reads a module's own box.json (as extracted to MODULE_DIR) and, if it
# declares a `boxlang.completions` path (a bash completion script shipped
# inside the module, relative to its root), copies that script into the
# shared completions directory as "<module-name>.sh". bvm-init.sh sources
# every script in that directory on shell startup, so the completion script
# is expected to register itself (e.g. via `complete -F ... <command>`).
install_module_completions() {
	local MODULE_DIR=${1}
	local MODULE_NAME=${2}
	local BOX_JSON_PATH="${MODULE_DIR}/box.json"

	[ -f "${BOX_JSON_PATH}" ] || return 0

	local COMPLETIONS_REL
	COMPLETIONS_REL=$(jq -r '.boxlang.completions // empty' "${BOX_JSON_PATH}" 2>/dev/null)
	if [ -z "${COMPLETIONS_REL}" ] || [ "${COMPLETIONS_REL}" = "null" ]; then
		return 0
	fi

	local COMPLETIONS_SRC="${MODULE_DIR}/${COMPLETIONS_REL}"
	if [ ! -f "${COMPLETIONS_SRC}" ]; then
		printf "${YELLOW}⚠️  Warning: box.json declares completions at '${COMPLETIONS_REL}' but the file was not found in the module${NORMAL}\n"
		return 0
	fi

	local COMPLETIONS_DIR
	COMPLETIONS_DIR=$(completions_dir)
	mkdir -p "${COMPLETIONS_DIR}"
	printf "${BLUE}⌨️  Installing bash completions for: ${MODULE_NAME}${NORMAL}\n"
	cp "${COMPLETIONS_SRC}" "${COMPLETIONS_DIR}/${MODULE_NAME}.sh"
	chmod 644 "${COMPLETIONS_DIR}/${MODULE_NAME}.sh"
}

# Removes any bash completion script previously installed for MODULE_NAME.
remove_module_completions() {
	local MODULE_NAME=${1}
	local COMPLETIONS_DIR
	COMPLETIONS_DIR=$(completions_dir)
	rm -f "${COMPLETIONS_DIR}/${MODULE_NAME}.sh"
}

# Runs install_module with MODULES_HOME pointed at a parent module's modules/
# folder. Runs in a subshell so the override (and a hard `exit 1` on failure)
# never leaks back to the caller.
install_nested_module() {
	local NESTED_HOME=${1}
	local INPUT=${2}
	local VISITED=${3:-""}
	(
		ROOT_MODULES_HOME="${ROOT_MODULES_HOME:-$MODULES_HOME}"
		MODULES_HOME="${NESTED_HOME}"
		NESTED_INSTALL=true
		install_module "$INPUT" "$VISITED"
	)
}

# Warns when a module about to be nested is already installed somewhere else
# under the top-level modules directory (top level or inside another module).
warn_duplicate_module() {
	local DEP_NAME=${1}
	local DEST=${2}
	local ROOT="${ROOT_MODULES_HOME:-$MODULES_HOME}"

	[ -d "${ROOT}" ] || return 0

	find "${ROOT}" -type d -name "${DEP_NAME}" 2>/dev/null | while IFS= read -r found; do
		[ "$found" = "$DEST" ] && continue
		[ -f "${found}/box.json" ] || continue
		printf "${YELLOW}⚠️  Dependency '${DEP_NAME}' is also installed at ${found}, installing another copy at ${DEST}${NORMAL}\n"
	done
	return 0
}

# Reads a module's own box.json (as extracted to MODULE_DIR) and installs any
# declared dependencies. A dependency version of "*" (or empty/null) installs
# the latest version from FORGEBOX; any other value is installed as-is
# (e.g. an exact version, "be", or "snapshot").
# When NEST is "true", dependencies are installed as nested modules inside
# "${MODULE_DIR}/modules"; otherwise they go to the current MODULES_HOME
# (used for a project box.json that is not itself a module).
install_module_dependencies() {
	local MODULE_DIR=${1}
	local VISITED=${2:-""}
	local NEST=${3:-false}
	local BOX_JSON_PATH="${MODULE_DIR}/box.json"

	[ -f "${BOX_JSON_PATH}" ] || return 0

	# `|| true` keeps a jq failure (e.g. malformed box.json) from tripping `set -e`.
	local DEP_COUNT
	DEP_COUNT=$(jq -r '.dependencies // {} | length' "${BOX_JSON_PATH}" 2>/dev/null || true)

	# Guard against a non-numeric DEP_COUNT (see list_modules() for why).
	if [ -z "$DEP_COUNT" ] || [ "${DEP_COUNT:-0}" -eq 0 ] 2>/dev/null; then
		return 0
	fi

	printf "${BLUE}🔗 Found %s module dependenc%s, installing...${NORMAL}\n" \
		"$DEP_COUNT" "$([ "$DEP_COUNT" -eq 1 ] && echo "y" || echo "ies")"

	jq -r '.dependencies // {} | to_entries[] | "\(.key)\t\(.value)"' "${BOX_JSON_PATH}" 2>/dev/null |
	while IFS="$TAB" read -r dep_name dep_version; do
		[ -z "$dep_name" ] && continue

		# Skip dependencies already being installed up the chain to avoid
		# infinite recursion on circular module dependencies.
		case " ${VISITED} " in
			*" ${dep_name} "*)
				printf "${YELLOW}⚠️  Skipping circular dependency: ${dep_name}${NORMAL}\n"
				continue
				;;
		esac

		# This installer only knows how to resolve plain ForgeBox module slugs.
		# A box.json dependencies entry can also be a CommandBox-style Maven,
		# URL, or git dependency (e.g. "org.jline:jline": "maven:org.jline:jline:3.21.0"),
		# which this script cannot install. Detect those and skip them instead
		# of attempting -- and always failing -- a ForgeBox lookup for them.
		case "$dep_name" in
			*:*)
				printf "${YELLOW}⚠️  Skipping non-ForgeBox dependency '${dep_name}': not a plain module slug${NORMAL}\n"
				continue
				;;
		esac
		case "$dep_version" in
			maven:*|http://*|https://*|git+*|file:*)
				printf "${YELLOW}⚠️  Skipping non-ForgeBox dependency '${dep_name}': unsupported source '${dep_version}'${NORMAL}\n"
				continue
				;;
		esac

		local dep_input
		if [ -z "$dep_version" ] || [ "$dep_version" = "null" ] || [ "$dep_version" = "*" ]; then
			dep_input="${dep_name}"
		else
			dep_input="${dep_name}@${dep_version}"
		fi

		printf "${GREEN}📦 Installing dependency: ${dep_input}${NORMAL}\n"
		# Run in a subshell so a hard `exit 1` inside install_module (e.g. a
		# failed download) only ends this one dependency attempt, not the
		# whole module installation.
		local install_ok=true
		if [ "$NEST" = true ]; then
			local dep_slug
			dep_slug=$(echo "$dep_name" | tr '[:upper:]' '[:lower:]')
			warn_duplicate_module "$dep_slug" "${MODULE_DIR}/modules/${dep_slug}"
			install_nested_module "${MODULE_DIR}/modules" "$dep_input" "${VISITED}" || install_ok=false
		else
			( install_module "$dep_input" "${VISITED}" ) || install_ok=false
		fi
		if [ "$install_ok" != true ]; then
			printf "${YELLOW}⚠️  Warning: Failed to install dependency '${dep_input}', continuing...${NORMAL}\n"
		fi
	done
}

remove_module() {
	local MODULE_NAME=${1}
	local FORCE_REMOVE=${2:-false}

	# Validate module name
	if [ -z "$MODULE_NAME" ]; then
		printf "${RED}❌ Error: You must specify a BoxLang module to remove${NORMAL}\n"
		exit 1
	fi

	# Convert to lowercase to match installation convention
	MODULE_NAME=$(echo "$MODULE_NAME" | tr '[:upper:]' '[:lower:]')

	# Define module path
	local MODULE_PATH="${MODULES_HOME}/${MODULE_NAME}"

	# Check if module exists
	if [ ! -d "${MODULE_PATH}" ]; then
		printf "${YELLOW}📭 Module '${MODULE_NAME}' is not installed at ${MODULE_PATH}${NORMAL}\n"
		return 0
	fi

	# Get module version for display if available
	local MODULE_VERSION="unknown"
	local BOX_JSON_PATH="${MODULE_PATH}/box.json"
	if [ -f "$BOX_JSON_PATH" ]; then
		MODULE_VERSION=$(jq -r '.version // "unknown"' "$BOX_JSON_PATH" 2>/dev/null)
		if [ "$MODULE_VERSION" = "null" ] || [ -z "$MODULE_VERSION" ]; then
			MODULE_VERSION="unknown"
		fi
	fi

	# Show what will be removed
	printf "${YELLOW}🔍 Found module: ${MODULE_NAME} (${MODULE_VERSION}) at ${MODULE_PATH}${NORMAL}\n"

	# Ask for confirmation unless --force is used
	if [ "$FORCE_REMOVE" != "true" ]; then
		printf "${RED}⚠️  Are you sure you want to remove this module? [y/N]: ${NORMAL}"
		read -r confirmation < /dev/tty
		case "$confirmation" in
			[yY]|[yY][eE][sS])
				# Continue with removal
				;;
			*)
				printf "${YELLOW}❌ Module removal cancelled${NORMAL}\n"
				return 0
				;;
		esac
	fi

	# Remove the module directory
	printf "${BLUE}🗑️  Removing module ${MODULE_NAME}...${NORMAL}\n"
	if rm -rf "${MODULE_PATH}"; then
		printf "${GREEN}✅ Module '${MODULE_NAME}' removed successfully!${NORMAL}\n"
		# Untrack this module from the modules manifest
		box_json_remove_dependency "${MODULES_HOME}/box.json" "${MODULE_NAME}"
		# Remove any bash completions installed for this module
		remove_module_completions "${MODULE_NAME}"
	else
		printf "${RED}❌ Error: Failed to remove module '${MODULE_NAME}'${NORMAL}\n"
		exit 1
	fi
}

###########################################################################
# box.json Manifest Helpers
###########################################################################

# Set (add or update) a dependency entry in the modules manifest box.json.
# Creates the file (and/or the dependencies struct) if it doesn't already exist.
box_json_set_dependency() {
	local BOX_JSON_PATH=${1}
	local MODULE_NAME=${2}
	local MODULE_VERSION=${3}

	[ -f "${BOX_JSON_PATH}" ] || echo '{}' > "${BOX_JSON_PATH}"

	local TMP_FILE
	TMP_FILE=$(mktemp)
	if jq --arg name "${MODULE_NAME}" --arg version "${MODULE_VERSION}" \
		'.dependencies = ((.dependencies // {}) + {($name): $version})' \
		"${BOX_JSON_PATH}" > "${TMP_FILE}"; then
		mv "${TMP_FILE}" "${BOX_JSON_PATH}"
	else
		rm -f "${TMP_FILE}"
		printf "${YELLOW}⚠️  Warning: Failed to update box.json dependencies${NORMAL}\n" >&2
	fi
}

# Remove a dependency entry from the modules manifest box.json.
# Creates the file (and/or the dependencies struct) if it doesn't already exist.
box_json_remove_dependency() {
	local BOX_JSON_PATH=${1}
	local MODULE_NAME=${2}

	[ -f "${BOX_JSON_PATH}" ] || echo '{}' > "${BOX_JSON_PATH}"

	local TMP_FILE
	TMP_FILE=$(mktemp)
	if jq --arg name "${MODULE_NAME}" \
		'.dependencies = (.dependencies // {}) | del(.dependencies[$name])' \
		"${BOX_JSON_PATH}" > "${TMP_FILE}"; then
		mv "${TMP_FILE}" "${BOX_JSON_PATH}"
	else
		rm -f "${TMP_FILE}"
		printf "${YELLOW}⚠️  Warning: Failed to update box.json dependencies${NORMAL}\n" >&2
	fi
}

# Ensures ${MODULES_PATH}/box.json exists (backfilling it from installed module directories
# if missing), and prints its path.
ensure_modules_manifest() {
	local MODULES_PATH=${1}
	local BOX_JSON_PATH="${MODULES_PATH}/box.json"

	if [ ! -f "${BOX_JSON_PATH}" ]; then
		printf "${YELLOW}🛠️  No box.json manifest found, generating one from installed modules...${NORMAL}\n" >&2
		for module_dir in "${MODULES_PATH}"/*; do
			if [ -d "$module_dir" ]; then
				local module_name module_version module_box_json
				module_name=$(basename "$module_dir")
				module_box_json="$module_dir/box.json"
				module_version="unknown"
				if [ -f "$module_box_json" ]; then
					module_version=$(jq -r '.version // "unknown"' "$module_box_json" 2>/dev/null)
					[ "$module_version" = "null" ] && module_version="unknown"
				fi
				box_json_set_dependency "${BOX_JSON_PATH}" "${module_name}" "${module_version}"
			fi
		done
		# Ensure the manifest exists even if there were no module directories to backfill
		[ -f "${BOX_JSON_PATH}" ] || echo '{"dependencies": {}}' > "${BOX_JSON_PATH}"
	fi

	echo "${BOX_JSON_PATH}"
}

###########################################################################
# Outdated / Update Helpers
###########################################################################

# Lean ForgeBox "latest version" lookup (no progress messages, no download URL resolution).
fetch_forgebox_latest_version() {
	local MODULE_NAME=${1}
	local ENTRY_JSON
	ENTRY_JSON=$(curl -sSL "${FORGEBOX_API_URL}/entry/${MODULE_NAME}/latest" 2>/dev/null)
	if [ -z "$ENTRY_JSON" ] || [ "$ENTRY_JSON" = "null" ]; then
		return 1
	fi

	local VERSION
	VERSION=$(printf '%s\n' "${ENTRY_JSON}" | jq -r '.data.version // empty' 2>/dev/null)
	if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
		return 1
	fi

	echo "$VERSION"
}

# Emits one tab-separated report line for a single installed module:
# name<TAB>current<TAB>latest<TAB>status<TAB>modules_dir<TAB>depth
# status is one of: uptodate, ahead, outdated, unreachable
# Modules whose current version isn't a parseable semver emit nothing.
outdated_report_line() {
	local module_name=${1}
	local current_version=${2}
	local modules_dir=${3}
	local depth=${4}

	local current_semver
	current_semver=$(extract_semantic_version "$current_version")
	[ -z "$current_semver" ] && return 0

	local latest_version status latest_semver
	# `|| true` keeps a failed lookup (e.g. module removed from FORGEBOX, network
	# hiccup) from tripping `set -e` and silently truncating the rest of the report.
	latest_version=$(fetch_forgebox_latest_version "$module_name") || true
	if [ -z "$latest_version" ]; then
		status="unreachable"
		latest_version="?"
	else
		latest_semver=$(extract_semantic_version "$latest_version")
		if [ -z "$latest_semver" ]; then
			status="unreachable"
		else
			local cmp_result
			compare_versions "$current_semver" "$latest_semver" && cmp_result=0 || cmp_result=$?
			case "$cmp_result" in
				0) status="uptodate" ;;
				1) status="ahead" ;;
				2) status="outdated" ;;
			esac
		fi
	fi
	printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$module_name" "$current_version" "$latest_version" "$status" "$modules_dir" "$depth"
}

# Emits report lines for every module nested inside a modules/ directory, recursively.
nested_outdated_report() {
	local NESTED_DIR=${1}
	local DEPTH=${2:-1}

	[ -d "${NESTED_DIR}" ] || return 0

	local dir name
	for dir in "${NESTED_DIR}"/*/; do
		[ -d "$dir" ] || continue
		dir="${dir%/}"
		name="${dir##*/}"
		outdated_report_line "$name" "$(read_module_version "$dir")" "${NESTED_DIR}" "$DEPTH"
		nested_outdated_report "${dir}/modules" $((DEPTH + 1))
	done
}

# Emits one report line per module in the manifest, each followed by the modules
# nested inside it (see outdated_report_line for the format).
compute_outdated_report() {
	local MODULES_PATH=${1}
	local BOX_JSON_PATH
	BOX_JSON_PATH=$(ensure_modules_manifest "${MODULES_PATH}")

	jq -r '.dependencies // {} | to_entries[] | "\(.key)\t\(.value)"' "${BOX_JSON_PATH}" 2>/dev/null |
	while IFS="$TAB" read -r module_name current_version; do
		outdated_report_line "$module_name" "$current_version" "${MODULES_PATH}" 0
		nested_outdated_report "${MODULES_PATH}/${module_name}/modules" 1
	done
}

# Indents a module name by its nesting depth for report output.
report_label() {
	local NAME=${1}
	local DEPTH=${2:-0}
	local INDENT="" i=0
	while [ "$i" -lt "$DEPTH" ]; do
		INDENT="${INDENT}  "
		i=$((i + 1))
	done
	printf '%s%s' "$INDENT" "$NAME"
}

# Installs the outdated modules collected as "name|latest|modules_dir|depth" lines.
# Nested entries are reinstalled into their parent's modules/ folder. A parent update
# reinstalls its own nested dependencies, so nested entries that are already current
# (or no longer present) are skipped.
apply_outdated_updates() {
	local ENTRIES=${1}

	printf '%s' "$ENTRIES" | while IFS='|' read -r module_name latest_version modules_dir depth; do
		[ -z "$module_name" ] && continue
		if [ "${depth:-0}" -gt 0 ]; then
			[ -d "${modules_dir}/${module_name}" ] || continue
			[ "$(read_module_version "${modules_dir}/${module_name}")" = "$latest_version" ] && continue
			install_nested_module "${modules_dir}" "${module_name}@${latest_version}" ||
				printf "${YELLOW}⚠️  Warning: Failed to update nested module '${module_name}' in ${modules_dir}${NORMAL}\n"
		else
			install_module "${module_name}@${latest_version}"
		fi
	done
}

outdated_modules() {
	local MODULES_HOME=${1}
	local LOCATION_DESC=${2}

	printf "${YELLOW}🔎 Checking for outdated BoxLang Modules (${LOCATION_DESC}):${NORMAL}\n\n"

	if [ ! -d "${MODULES_HOME}" ]; then
		printf "${YELLOW}📂 No modules directory found at ${MODULES_HOME}${NORMAL}\n"
		return 0
	fi

	command_exists curl || {
		printf "${RED}❌ Error: curl is required but not installed${NORMAL}\n"
		exit 1
	}

	local REPORT_FILE
	REPORT_FILE=$(mktemp)
	compute_outdated_report "${MODULES_HOME}" > "${REPORT_FILE}"

	if [ ! -s "${REPORT_FILE}" ]; then
		printf "${YELLOW}📭 No modules to report on${NORMAL}\n"
		rm -f "${REPORT_FILE}"
		return 0
	fi

	printf "%-25s %-15s %-15s %s\n" "DEPENDENCY" "CURRENT" "FORGEBOX" "STATUS"
	printf "%-25s %-15s %-15s %s\n" "-------------------------" "---------------" "---------------" "--------------------"

	local OUTDATED_MODULES=""
	local OUTDATED_COUNT=0
	while IFS="$TAB" read -r module_name current_version latest_version status modules_dir depth; do
		local status_label
		case "$status" in
			uptodate) status_label="✅ up to date" ;;
			ahead) status_label="🔄 ahead (dev/snapshot)" ;;
			outdated)
				status_label="🆙 outdated"
				OUTDATED_MODULES="${OUTDATED_MODULES}${module_name}|${latest_version}|${modules_dir}|${depth}
"
				OUTDATED_COUNT=$((OUTDATED_COUNT + 1))
				;;
			*) status_label="⚠️  unable to check" ;;
		esac
		printf "%-25s %-15s %-15s %s\n" "$(report_label "$module_name" "$depth")" "$current_version" "$latest_version" "$status_label"
	done < "${REPORT_FILE}"
	rm -f "${REPORT_FILE}"

	printf "\n"
	if [ "$OUTDATED_COUNT" -eq 0 ]; then
		printf "${GREEN}✅ All modules are up to date${NORMAL}\n"
		return 0
	fi

	printf "${YELLOW}⚠️  %d module(s) outdated${NORMAL}\n" "$OUTDATED_COUNT"
	printf "${RED}⬆️  Would you like to update ${OUTDATED_COUNT} outdated module(s) now? [y/N]: ${NORMAL}"
	read -r confirmation < /dev/tty
	case "$confirmation" in
		[yY]|[yY][eE][sS])
			apply_outdated_updates "$OUTDATED_MODULES"
			;;
		*)
			printf "${YELLOW}Skipping updates.${NORMAL}\n"
			;;
	esac
}

# FILTER is an optional space-delimited list of module names; when given, only
# those modules (at any nesting depth) are updated.
update_modules() {
	local MODULES_HOME=${1}
	local LOCATION_DESC=${2}
	local FORCE_UPDATE=${3:-false}
	local FILTER=${4:-}

	printf "${YELLOW}🔎 Checking for outdated BoxLang Modules (${LOCATION_DESC}):${NORMAL}\n\n"

	if [ ! -d "${MODULES_HOME}" ]; then
		printf "${YELLOW}📂 No modules directory found at ${MODULES_HOME}${NORMAL}\n"
		return 0
	fi

	command_exists curl || {
		printf "${RED}❌ Error: curl is required but not installed${NORMAL}\n"
		exit 1
	}

	local REPORT_FILE
	REPORT_FILE=$(mktemp)
	compute_outdated_report "${MODULES_HOME}" > "${REPORT_FILE}"

	local OUTDATED_MODULES=""
	local OUTDATED_COUNT=0
	if [ -n "$FILTER" ]; then
		local requested
		for requested in $FILTER; do
			if ! cut -f1 "${REPORT_FILE}" | grep -qx "$requested"; then
				printf "${YELLOW}⚠️  Module '${requested}' was not found among the installed modules (or has no parseable version)${NORMAL}\n"
			fi
		done
	fi

	while IFS="$TAB" read -r module_name current_version latest_version status modules_dir depth; do
		if [ -n "$FILTER" ]; then
			case " ${FILTER} " in
				*" ${module_name} "*) ;;
				*) continue ;;
			esac
		fi
		if [ "$status" = "outdated" ]; then
			printf -- "🆙 %s: %s → %s\n" "$(report_label "$module_name" "$depth")" "$current_version" "$latest_version"
			OUTDATED_MODULES="${OUTDATED_MODULES}${module_name}|${latest_version}|${modules_dir}|${depth}
"
			OUTDATED_COUNT=$((OUTDATED_COUNT + 1))
		fi
	done < "${REPORT_FILE}"
	rm -f "${REPORT_FILE}"

	if [ "$OUTDATED_COUNT" -eq 0 ]; then
		printf "${GREEN}✅ All modules are up to date, nothing to update${NORMAL}\n"
		return 0
	fi

	printf "\n"
	if [ "$FORCE_UPDATE" != "true" ]; then
		printf "${RED}⬆️  Update ${OUTDATED_COUNT} outdated module(s)? [y/N]: ${NORMAL}"
		read -r confirmation < /dev/tty
		case "$confirmation" in
			[yY]|[yY][eE][sS]) ;;
			*)
				printf "${YELLOW}❌ Update cancelled${NORMAL}\n"
				return 0
				;;
		esac
	fi

	apply_outdated_updates "$OUTDATED_MODULES"

	printf "${GREEN}✅ Updated ${OUTDATED_COUNT} module(s)!${NORMAL}\n"
}

# Parses the options and positional arguments that follow a command.
# Sets LOCAL_INSTALL, FORCE_FLAG, POSITIONALS (space-delimited) and UNKNOWN_OPTIONS.
parse_verb_args() {
	LOCAL_INSTALL=false
	FORCE_FLAG=false
	POSITIONALS=""
	UNKNOWN_OPTIONS=""

	local arg
	for arg in "$@"; do
		case "$arg" in
			--local) LOCAL_INSTALL=true ;;
			--force) FORCE_FLAG=true ;;
			-*) UNKNOWN_OPTIONS="${UNKNOWN_OPTIONS} ${arg}" ;;
			*) POSITIONALS="${POSITIONALS} ${arg}" ;;
		esac
	done
}

# Sets MODULES_HOME and LOCATION_DESC from LOCAL_INSTALL.
set_modules_home() {
	if [ "$LOCAL_INSTALL" = true ]; then
		MODULES_HOME="$(pwd)/boxlang_modules"
		LOCATION_DESC="Local - $(pwd)/boxlang_modules"
	else
		if [ -z "${BOXLANG_HOME}" ]; then
			export BOXLANG_HOME="$HOME/.boxlang"
		fi
		MODULES_HOME="${BOXLANG_HOME}/modules"
		LOCATION_DESC="Global - ${BOXLANG_HOME}/modules"
	fi
}

# Fails with a usage error when a command that takes no module names was given
# module names or options it does not understand.
reject_extra_arguments() {
	local VERB=${1}
	local USAGE=${2}

	if [ -n "$UNKNOWN_OPTIONS" ] || [ -n "$POSITIONALS" ]; then
		printf "${RED}❌ Error: '${VERB}' does not accept additional arguments:${UNKNOWN_OPTIONS}${POSITIONALS}${NORMAL}\n"
		printf "${YELLOW}💡 Usage: ${USAGE}${NORMAL}\n"
		exit 1
	fi
}

cmd_install() {
	parse_verb_args "$@"
	set_modules_home

	# --force has no effect on install (modules are always overwritten) and is
	# accepted so existing scripts keep working; other unknown options are ignored
	# with a warning for the same reason.
	if [ -n "$UNKNOWN_OPTIONS" ]; then
		printf "${YELLOW}⚠️  Ignoring unknown option(s):${UNKNOWN_OPTIONS}${NORMAL}\n"
	fi

	# No module names were given (either no arguments at all, or only
	# --local). If a box.json exists in the current directory, treat it as a
	# project manifest and install the dependencies it declares (similar to
	# running `npm install` with no arguments), honoring --local/BoxLang HOME
	# just like a normal install would.
	local MODULE_LIST
	MODULE_LIST=$(parse_module_list "$POSITIONALS")
	if [ -z "$MODULE_LIST" ]; then
		if [ -f "$(pwd)/box.json" ]; then
			printf "${YELLOW}📄 Found box.json in $(pwd), installing its declared dependencies...${NORMAL}\n"
			install_module_dependencies "$(pwd)" ""
			exit 0
		fi

		printf "${RED}❌ Error: No module(s) specified${NORMAL}\n"
		printf "${YELLOW}💡 Usage: bx-module install <module-name>[@<version>] [<module-name> ...] [--local]${NORMAL}\n"
		show_help
		exit 1
	fi

	# Inform about local installation
	if [ "$LOCAL_INSTALL" = true ]; then
		printf "${YELLOW}📍 Installing modules locally in $(pwd)/boxlang_modules${NORMAL}\n"
	fi

	# Install the parsed comma/space-delimited module list
	printf '%s\n' "$MODULE_LIST" | while IFS= read -r module; do
		if [ -n "$module" ]; then
			printf "${GREEN}🚀 Starting installation of module: ${module}${NORMAL}\n"
			install_module "$module"
		fi
	done
}

cmd_remove() {
	parse_verb_args "$@"
	set_modules_home

	if [ -n "$UNKNOWN_OPTIONS" ]; then
		printf "${RED}❌ Error: Unknown option(s) for 'remove':${UNKNOWN_OPTIONS}${NORMAL}\n"
		printf "${YELLOW}💡 Usage: bx-module remove <module-name> [<module-name> ...] [--force] [--local]${NORMAL}\n"
		exit 1
	fi

	local MODULE_LIST
	MODULE_LIST=$(parse_module_list "$POSITIONALS")

	# Check if no modules specified for removal
	if [ -z "$MODULE_LIST" ]; then
		printf "${RED}❌ Error: No module(s) specified for removal${NORMAL}\n"
		printf "${YELLOW}💡 Usage: bx-module remove <module-name> [<module-name> ...] [--force] [--local]${NORMAL}\n"
		exit 1
	fi

	# Inform about local removal if applicable
	if [ "$LOCAL_INSTALL" = true ]; then
		printf "${YELLOW}🗑️  Removing modules from local directory: $(pwd)/boxlang_modules${NORMAL}\n"
	else
		printf "${YELLOW}🗑️  Removing modules from: ${MODULES_HOME}${NORMAL}\n"
	fi

	printf '%s\n' "$MODULE_LIST" | while IFS= read -r module; do
		if [ -n "$module" ]; then
			printf "${GREEN}🚀 Starting removal of module: ${module}${NORMAL}\n"
			remove_module "$module" "$FORCE_FLAG"
		fi
	done
}

cmd_list() {
	parse_verb_args "$@"
	if [ "$FORCE_FLAG" = true ]; then UNKNOWN_OPTIONS="${UNKNOWN_OPTIONS} --force"; fi
	reject_extra_arguments "list" "bx-module list [--local]"
	set_modules_home

	list_modules "$MODULES_HOME" "$LOCATION_DESC"
}

cmd_outdated() {
	parse_verb_args "$@"
	if [ "$FORCE_FLAG" = true ]; then UNKNOWN_OPTIONS="${UNKNOWN_OPTIONS} --force"; fi
	reject_extra_arguments "outdated" "bx-module outdated [--local]"
	set_modules_home

	outdated_modules "$MODULES_HOME" "$LOCATION_DESC"
}

cmd_update() {
	parse_verb_args "$@"
	if [ -n "$UNKNOWN_OPTIONS" ]; then
		printf "${RED}❌ Error: Unknown option(s) for 'update':${UNKNOWN_OPTIONS}${NORMAL}\n"
		printf "${YELLOW}💡 Usage: bx-module update [<module-name> ...] [--force] [--local]${NORMAL}\n"
		exit 1
	fi
	set_modules_home

	# Module names to limit the update to (lowercased, space-delimited)
	local FILTER
	FILTER=$(parse_module_list "$POSITIONALS" | tr '[:upper:]' '[:lower:]' | tr '\n' ' ')

	update_modules "$MODULES_HOME" "$LOCATION_DESC" "$FORCE_FLAG" "${FILTER%% }"
}

main() {
	setup_colors

	# Module manager dependencies
	if ! preflight_check skip curl unzip jq; then
		exit 1
	fi

	local VERB="${1:-}"
	if [ $# -gt 0 ]; then
		shift
	fi

	case "$VERB" in
		"")
			show_help
			exit 0
			;;
		help | --help | -h)
			show_help "${1:-}"
			exit $?
			;;
		install | remove | list | outdated | update)
			local arg
			for arg in "$@"; do
				case "$arg" in
					--help | -h)
						show_verb_help "$VERB"
						exit 0
						;;
				esac
			done
			"cmd_${VERB}" "$@"
			;;
		*)
			printf "${RED}❌ Error: Unknown command '${VERB}'${NORMAL}\n"
			case "$VERB" in
				--list | --outdated | --update | --remove) printf "${YELLOW}💡 Did you mean: bx-module ${VERB#--}?${NORMAL}\n" ;;
				-*) ;;
				*) printf "${YELLOW}💡 Did you mean: bx-module install ${VERB}?${NORMAL}\n" ;;
			esac
			printf "${YELLOW}💡 Commands: install, remove, list, outdated, update, help (run 'bx-module help' for details)${NORMAL}\n"
			exit 1
			;;
	esac
}

main "$@"
