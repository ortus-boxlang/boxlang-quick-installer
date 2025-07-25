#!/bin/bash

# BoxLang Module Installer Script
# This script helps install and manage BoxLang modules from FORGEBOX.
# Author: BoxLang Team
# Version: @build.version@
# License: Apache License, Version 2.0

set -e

###########################################################################
# Global Variables + Helpers
###########################################################################

# Configuration
FORGEBOX_API_URL="https://forgebox.io/api/v1"

# Include the helper functions
# These are installed by the installer script
if [ -f "$(dirname "$0")/helpers/helpers.sh" ]; then
	source "$(dirname "$0")/helpers/helpers.sh"
elif [ -f "${BASH_SOURCE%/*}/helpers/helpers.sh" ]; then
	source "${BASH_SOURCE%/*}/helpers/helpers.sh"
elif [ -f "${BOXLANG_INSTALL_HOME}/scripts/helpers/helpers.sh" ]; then
	source "${BOXLANG_INSTALL_HOME}/scripts/helpers/helpers.sh"
elif [ -f "${BVM_HOME}/scripts/helpers/helpers.sh" ]; then
    source "${BVM_HOME}/scripts/helpers/helpers.sh"
else
	printf "${RED}Error: Helper scripts not found. Please verify your installation.${NORMAL}\n"
	exit 1
fi

###########################################################################
# ACTION FUNCTIONS
###########################################################################

parse_module_list() {
	local modules=()
	local input=""

	# Concatenate all arguments into a single string
	for arg in "$@"; do
		# Skip flags
		if [[ "$arg" == --* ]]; then
			continue
		fi
		input="$input $arg"
	done

	# Replace commas with spaces and normalize whitespace
	input=$(echo "$input" | sed 's/,/ /g' | tr -s ' ')

	# Split by spaces and add to array
	for module in $input; do
		if [ -n "$module" ]; then
			modules+=("$module")
		fi
	done

	# Output modules one per line
	printf '%s\n' "${modules[@]}"
}

show_help() {
	printf "${GREEN}📦 BoxLang Module Installer${NORMAL}\n\n"
	printf "${YELLOW}This script installs, removes, and lists BoxLang modules from FORGEBOX.${NORMAL}\n\n"
	printf "${BOLD}USAGE:${NORMAL}\n"
	printf "  install-bx-module.sh <module-name>[@<version>] [<module-name>[@<version>] ...] [--local]\n"
	printf "  install-bx-module.sh --remove <module-name> [<module-name> ...] [--force] [--local]\n"
	printf "  install-bx-module.sh --list [--local]\n"
	printf "  install-bx-module.sh --help\n\n"
	printf "${BOLD}ARGUMENTS:${NORMAL}\n"
	printf "  <module-name>     The name(s) of the module(s) to install. (Comma or space delimmited)\n"
	printf "  [@<version>]      (Optional) The specific semantic version of the module to install\n\n"
	printf "${BOLD}OPTIONS:${NORMAL}\n"
	printf "  --local           Install to/remove from local boxlang_modules folder instead of BoxLang HOME. The BoxLang HOME is the default.\n"
	printf "  --remove          Remove specified module(s)\n"
	printf "  --force           Skip confirmation when removing modules(s)(use with --remove)\n"
	printf "  --list            Show installed module(s)\n"
	printf "  --help, -h        Show this help message\n\n"
	printf "${BOLD}EXAMPLES:${NORMAL}\n"
	printf "  install-bx-module bx-orm\n"
	printf "  install-bx-module bx-orm@2.5.0\n"
	printf "  install-bx-module bx-orm bx-ai --local\n"
	printf "  install-bx-module bx-orm,bx-ai,bx-esapi\n"
	printf "  install-bx-module \"bx-orm, bx-ai\" --local\n"
	printf "  install-bx-module --remove bx-orm\n"
	printf "  install-bx-module --remove bx-orm,bx-ai --force\n"
	printf "  install-bx-module --remove \"bx-orm, bx-ai\" --local\n"
	printf "  install-bx-module --list\n"
	printf "  install-bx-module --list --local\n\n"
	printf "${BOLD}NOTES:${NORMAL}\n"
	printf "  - If no version is specified, the latest version from FORGEBOX will be installed\n"
	printf "  - Multiple modules can be specified, separated by spaces or commas\n"
	printf "  - Module lists can mix spaces and commas: 'bx-orm, bx-ai bx-esapi'\n"
	printf "  - Use --local to work with modules in current directory's boxlang_modules folder\n"
	printf "  - Without --local, modules are managed in BoxLang HOME (~/.boxlang/modules)\n"
	printf "  - Requires curl and jq to be installed\n"
}

list_modules() {
	local MODULES_PATH=${1}
	local LOCATION_DESC=${2}

	printf "${YELLOW}📋 Installed BoxLang Modules (${LOCATION_DESC}):${NORMAL}\n"

	# Check if modules directory exists
	if [ ! -d "${MODULES_PATH}" ]; then
		printf "${YELLOW}📂 No modules directory found at ${MODULES_PATH}${NORMAL}\n"
		return 0
	fi

	# List all directories in the modules folder
	if [ -z "$(ls -A "${MODULES_PATH}" 2>/dev/null)" ]; then
		printf "${YELLOW}📭 No modules installed${NORMAL}\n"
	else
		# List modules with version information from box.json
		for module_dir in "${MODULES_PATH}"/*; do
			if [ -d "$module_dir" ]; then
				module_name=$(basename "$module_dir")
				box_json_path="$module_dir/box.json"

				if [ -f "$box_json_path" ]; then
					# Extract version from box.json
					version=$(jq -r '.version // "unknown"' "$box_json_path" 2>/dev/null)
					if [ "$version" != "null" ] && [ -n "$version" ]; then
						printf -- "✓ %s (%s)\n" "$module_name" "$version"
					else
						printf -- "✓ %s (version unknown)\n" "$module_name"
					fi
				else
					printf -- "✓ %s (no box.json)\n" "$module_name"
				fi
			fi
		done
	fi
}

get_latest_version_from_forgebox() {
	local MODULE_NAME=${1}

	printf "${YELLOW}🔍 No version specified, getting latest version from FORGEBOX...${NORMAL}\n"

	# Store Entry JSON From ForgeBox
	local ENTRY_JSON=$(curl -s "${FORGEBOX_API_URL}/entry/${MODULE_NAME}/latest")

	# Validate API response
	if [ -z "$ENTRY_JSON" ] || [ "$ENTRY_JSON" = "null" ]; then
		printf "${RED}❌ Error: Failed to fetch module information from FORGEBOX${NORMAL}\n"
		exit 1
	fi

	local VERSION=$(echo "${ENTRY_JSON}" | jq -r '.data.version')
	local DOWNLOAD_URL_TEMP=$(echo "${ENTRY_JSON}" | jq -r '.data.downloadURL')

	# Validate parsed data
	if [ "$VERSION" = "null" ] || [ -z "$VERSION" ]; then
		printf "${RED}❌ Error: Module '${MODULE_NAME}' not found in FORGEBOX${NORMAL}\n"
		exit 1
	fi

	if [ "$DOWNLOAD_URL_TEMP" = "null" ] || [ -z "$DOWNLOAD_URL_TEMP" ]; then
		printf "${RED}❌ Error: No download URL found for module '${MODULE_NAME}'${NORMAL}\n"
		exit 1
	fi

	# Return values via global variables
	TARGET_VERSION="$VERSION"
	DOWNLOAD_URL="$DOWNLOAD_URL_TEMP"
}

get_snapshot_version_from_forgebox() {
	local MODULE_NAME=${1}

	printf "${YELLOW}🔍 Getting latest snapshot version from FORGEBOX...${NORMAL}\n"

	# Store versions JSON From ForgeBox (versions only)
	local VERSIONS_JSON=$(curl -s "${FORGEBOX_API_URL}/entry/${MODULE_NAME}/versions")

	#echo "${VERSIONS_JSON}" | jq -e '.data'

	# Validate API response
	if [ -z "$VERSIONS_JSON" ] || [ "$VERSIONS_JSON" = "null" ]; then
		printf "${RED}❌ Error: Failed to fetch version information from FORGEBOX${NORMAL}\n"
		exit 1
	fi

	# Find the first version with "-snapshot" in the versions array
	local VERSION=$(echo "${VERSIONS_JSON}" | jq -r '.data[] | select(.version | contains("-snapshot")) | .version' | head -n 1)

	# Validate parsed data
	if [ "$VERSION" = "null" ] || [ -z "$VERSION" ]; then
		printf "${RED}❌ Error: No snapshot version(s) found for module '${MODULE_NAME}' in FORGEBOX${NORMAL}\n"
		exit 1
	fi

	# Build download URL from the version (following the same pattern as specific versions)
	local DOWNLOAD_URL_TEMP="https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/${MODULE_NAME}/${VERSION}/${MODULE_NAME}-${VERSION}.zip"

	# Return values via global variables
	TARGET_VERSION="$VERSION"
	DOWNLOAD_URL="$DOWNLOAD_URL_TEMP"
}

install_module() {
	local INPUT=${1}
	local TARGET_MODULE=""
	local TARGET_VERSION=""

	if [[ "$INPUT" =~ @ ]]; then
		TARGET_MODULE=$(echo "$INPUT" | cut -d'@' -f1 | tr '[:upper:]' '[:lower:]')
		TARGET_VERSION=$(echo "$INPUT" | cut -d'@' -f2)
	else
		TARGET_MODULE=$(echo "$INPUT" | tr '[:upper:]' '[:lower:]')
	fi

	# Validate module name
	if [ -z "$TARGET_MODULE" ]; then
		printf "${RED}❌ Error: You must specify a BoxLang module to install${NORMAL}\n"
		printf "${YELLOW}💡 Usage: install-bx-module.sh <module-name>[@<version>] [--local]${NORMAL}\n"
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
	elif [ "$TARGET_VERSION" = "be" ] || [ "$TARGET_VERSION" = "snapshot" ]; then
		get_snapshot_version_from_forgebox "$TARGET_MODULE"
		# Use the global variables set by the function
		local DOWNLOAD_URL="$DOWNLOAD_URL"
	else
		# We have a targeted version, let's build the download URL from the artifacts directly
		local DOWNLOAD_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/${TARGET_MODULE}/${TARGET_VERSION}/${TARGET_MODULE}-${TARGET_VERSION}.zip"
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
	printf "${BLUE}⬇️  Downloading from ${DOWNLOAD_URL}...${NORMAL}\n"
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
	if ! unzip -o "${TEMP_FILE}" -d "${DESTINATION}"; then
		printf "${RED}❌ Error: Failed to extract module${NORMAL}\n"
		exit 1
	fi

	# Verify extraction
	if [ ! -d "${DESTINATION}" ] || [ -z "$(ls -A "${DESTINATION}" 2>/dev/null)" ]; then
		printf "${RED}❌ Error: Module extraction appears to have failed - destination directory is empty${NORMAL}\n"
		exit 1
	fi

	# Success message
	printf "${GREEN}\n✅ BoxLang® Module [${TARGET_MODULE}@${TARGET_VERSION}] installed successfully!${NORMAL}\n"
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
	else
		printf "${RED}❌ Error: Failed to remove module '${MODULE_NAME}'${NORMAL}\n"
		exit 1
	fi
}

main() {
	setup_colors

	# Check if no arguments are passed
	if [ $# -eq 0 ]; then
		printf "${RED}❌ Error: No module(s) specified${NORMAL}\n"
		printf "${YELLOW}💡 This script installs or removes BoxLang modules.${NORMAL}\n"
		show_help
		exit 1
	fi

	# Show help if requested
	if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
		show_help
		exit 0
	fi

	# Handle --list command (can be used with --local)
	LIST_MODE=false
	if [ "$1" = "--list" ]; then
		LIST_MODE=true
		shift # Remove --list from arguments

		# Check if --local is specified with --list
		LOCAL_LIST=false
		if [ "$1" = "--local" ]; then
			LOCAL_LIST=true
			shift # Remove --local from arguments
		fi

		# Ensure no other arguments after --list [--local]
		if [ $# -gt 0 ]; then
			printf "${RED}❌ Error: --list command does not accept additional arguments${NORMAL}\n"
			printf "${YELLOW}💡 Usage: install-bx-module.sh --list [--local]${NORMAL}\n"
			exit 1
		fi

		# Set up paths for listing
		if [ "$LOCAL_LIST" = true ]; then
			MODULES_PATH="$(pwd)/boxlang_modules"
			LOCATION_DESC="Local - $(pwd)/boxlang_modules"
		else
			if [ -z "${BOXLANG_HOME}" ]; then
				export BOXLANG_HOME="$HOME/.boxlang"
			fi
			MODULES_PATH="${BOXLANG_HOME}/modules"
			LOCATION_DESC="Global - ${BOXLANG_HOME}/modules"
		fi

		list_modules "$MODULES_PATH" "$LOCATION_DESC"
		exit 0
	fi

	# Handle remove command
	REMOVE_MODE=false
	FORCE_REMOVE=false

	# Check if --remove is the first argument
	if [ "$1" = "--remove" ]; then
		REMOVE_MODE=true
		shift # Remove --remove from arguments

		# Check for --force flag
		for arg in "$@"; do
			if [ "$arg" = "--force" ]; then
				FORCE_REMOVE=true
				break
			fi
		done

		# Remove --force from arguments if present
		if [ "$FORCE_REMOVE" = true ]; then
			set -- $(printf '%s\n' "$@" | grep -v '^--force$')
		fi
	fi

	# Detect if --local is anywhere in the arguments (not just last)
	LOCAL_INSTALL=false
	for arg in "$@"; do
		if [ "$arg" = "--local" ]; then
			LOCAL_INSTALL=true
			break
		fi
	done

	# Remove --local from arguments if present
	if [ "$LOCAL_INSTALL" = true ]; then
		set -- $(printf '%s\n' "$@" | grep -v '^--local$')
	fi

	# Set module installation path
	if [ "$LOCAL_INSTALL" = true ]; then
		MODULES_HOME="$(pwd)/boxlang_modules"
	else
		if [ -z "${BOXLANG_HOME}" ]; then
			export BOXLANG_HOME="$HOME/.boxlang"
		fi
		MODULES_HOME="${BOXLANG_HOME}/modules"
	fi

	# Handle remove mode
	if [ "$REMOVE_MODE" = true ]; then
		# Check if no modules specified for removal
		if [ $# -eq 0 ]; then
			printf "${RED}❌ Error: No module(s) specified for removal${NORMAL}\n"
			printf "${YELLOW}💡 Usage: install-bx-module.sh --remove <module-name> [<module-name> ...] [--force] [--local]${NORMAL}\n"
			exit 1
		fi

		# Inform about local removal if applicable
		if [ "$LOCAL_INSTALL" = true ]; then
			printf "${YELLOW}🗑️  Removing modules from local directory: $(pwd)/boxlang_modules${NORMAL}\n"
		else
			printf "${YELLOW}🗑️  Removing modules from: ${MODULES_HOME}${NORMAL}\n"
		fi

		# Parse comma/space-delimited module list
		while IFS= read -r module; do
			if [ -n "$module" ]; then
				printf "${GREEN}🚀 Starting removal of module: ${module}${NORMAL}\n"
				remove_module "$module" "$FORCE_REMOVE"
			fi
		done < <(parse_module_list "$@")

		exit 0
	fi

	# Inform about local installation
	if [ "$LOCAL_INSTALL" = true ]; then
		printf "${YELLOW}📍 Installing modules locally in $(pwd)/boxlang_modules${NORMAL}\n"
	fi

	# Parse comma/space-delimited module list and install
	while IFS= read -r module; do
		if [ -n "$module" ]; then
			printf "${GREEN}🚀 Starting installation of module: ${module}${NORMAL}\n"
			install_module "$module"
		fi
	done < <(parse_module_list "$@")
}

main "$@"
