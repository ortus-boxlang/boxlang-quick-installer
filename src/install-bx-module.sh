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

# We need this in case the target OS we are installing in does not have a `TERM` implementation declared
# or when TERM is set to problematic values like "unknown" (common in CI environments like GitHub Actions or Docker containers)
if [ -z "$TERM" ] || [ "$TERM" = "unknown" ] || [ "$TERM" = "dumb" ]; then
	export TERM="xterm-256color"
fi

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
	printf "  install-bx-module.sh --outdated [--local]\n"
	printf "  install-bx-module.sh --update [--force] [--local]\n"
	printf "  install-bx-module.sh --help\n\n"
	printf "${BOLD}ARGUMENTS:${NORMAL}\n"
	printf "  <module-name>     The name(s) of the module(s) to install. (Comma or space delimmited)\n"
	printf "  [@<version>]      (Optional) The specific semantic version of the module to install\n\n"
	printf "${BOLD}OPTIONS:${NORMAL}\n"
	printf "  --local           Install to/remove from local boxlang_modules folder instead of BoxLang HOME. The BoxLang HOME is the default.\n"
	printf "  --remove          Remove specified module(s)\n"
	printf "  --force           Skip confirmation when removing or updating module(s) (use with --remove or --update)\n"
	printf "  --list            Show installed module(s)\n"
	printf "  --outdated        Check installed modules against FORGEBOX and report which are outdated\n"
	printf "  --update          Update all outdated module(s) to their latest FORGEBOX version\n"
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
	printf "  install-bx-module --list --local\n"
	printf "  install-bx-module --outdated\n"
	printf "  install-bx-module --outdated --local\n"
	printf "  install-bx-module --update\n"
	printf "  install-bx-module --update --force --local\n\n"
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
	local BOX_JSON_PATH

	printf "${YELLOW}📋 Installed BoxLang Modules (${LOCATION_DESC}):${NORMAL}\n"

	# Check if modules directory exists
	if [ ! -d "${MODULES_PATH}" ]; then
		printf "${YELLOW}📂 No modules directory found at ${MODULES_PATH}${NORMAL}\n"
		return 0
	fi

	BOX_JSON_PATH=$(ensure_modules_manifest "${MODULES_PATH}")

	# Read installed modules from the manifest
	local DEP_COUNT
	DEP_COUNT=$(jq -r '.dependencies // {} | length' "${BOX_JSON_PATH}" 2>/dev/null)

	if [ -z "$DEP_COUNT" ] || [ "$DEP_COUNT" -eq 0 ]; then
		printf "${YELLOW}📭 No modules installed${NORMAL}\n"
	else
		jq -r '.dependencies // {} | to_entries[] | "\(.key)\t\(.value)"' "${BOX_JSON_PATH}" 2>/dev/null |
		while IFS=$'\t' read -r module_name module_version; do
			printf -- "✓ %s (%s)\n" "$module_name" "$module_version"
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

	local SECURE_URL=$(echo "${STORAGE_JSON}" | jq -r '.data')

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
	local VERSION=$(echo "${VERSIONS_JSON}" | jq -r '.data[0].version')

	# Validate parsed data
	if [ "$VERSION" = "null" ] || [ -z "$VERSION" ]; then
		printf "${RED}❌ Error: No version(s) found for module '${MODULE_NAME}' in FORGEBOX${NORMAL}\n"
		exit 1
	fi

	# Get the full entry info for this version to check for forgeboxStorage
	local VERSION_JSON=$(curl -sSL "${FORGEBOX_API_URL}/entry/${MODULE_NAME}/versions/${VERSION}")
	if [ -n "$VERSION_JSON" ] && [ "$VERSION_JSON" != "null" ]; then
		local DOWNLOAD_URL_TEMP=$(echo "${VERSION_JSON}" | jq -r '.data.downloadURL')
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
	local VERSION=$(echo "${VERSIONS_JSON}" | jq -r '.data[] | select(.version | contains("-snapshot")) | .version' | head -n 1)

	# Validate parsed data
	if [ "$VERSION" = "null" ] || [ -z "$VERSION" ]; then
		printf "${RED}❌ Error: No snapshot version(s) found for module '${MODULE_NAME}' in FORGEBOX${NORMAL}\n"
		exit 1
	fi

	# Get the full entry info for this version to check for forgeboxStorage
	local VERSION_JSON=$(curl -sSL "${FORGEBOX_API_URL}/entry/${MODULE_NAME}/${VERSION}")
	if [ -n "$VERSION_JSON" ] && [ "$VERSION_JSON" != "null" ]; then
		local DOWNLOAD_URL_TEMP=$(echo "${VERSION_JSON}" | jq -r '.data.downloadURL')
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
		local VERSION_JSON=$(curl -sSL "${FORGEBOX_API_URL}/entry/${TARGET_MODULE}/${TARGET_VERSION}")
		if [ -n "$VERSION_JSON" ] && [ "$VERSION_JSON" != "null" ]; then
			local DOWNLOAD_URL_TEMP=$(echo "${VERSION_JSON}" | jq -r '.data.downloadURL')
			if [ "$DOWNLOAD_URL_TEMP" = "forgeboxStorage" ]; then
				local DOWNLOAD_URL=$(resolve_forgebox_storage_url "$TARGET_MODULE" "$TARGET_VERSION")
			else
				# Use the download URL from API if available
				local DOWNLOAD_URL="$DOWNLOAD_URL_TEMP"
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
				while IFS= read -r exec_name; do
					if [ -n "${exec_name}" ]; then
						local exec_content=$(echo "${EXECUTABLES}" | jq -r ".\"${exec_name}\"" 2>/dev/null)
						if [ -n "${exec_content}" ] && [ "${exec_content}" != "null" ]; then
							local exec_script="${BIN_DIR}/${exec_name}"
							printf "${BLUE}  - Creating: ${exec_name}${NORMAL}\n"
							echo "${exec_content}" > "${exec_script}"
							chmod +x "${exec_script}"
						fi
					fi
				done <<< "${EXEC_NAMES}"
			fi
		fi
	fi
	# Track this install in the modules manifest
	box_json_set_dependency "${MODULES_HOME}/box.json" "${TARGET_MODULE}" "${TARGET_VERSION}"

	# Success message
	printf "${GREEN}✅ BoxLang® Module [${TARGET_MODULE}@${TARGET_VERSION}] installed!${NORMAL}\n"
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
	VERSION=$(echo "${ENTRY_JSON}" | jq -r '.data.version // empty' 2>/dev/null)
	if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
		return 1
	fi

	echo "$VERSION"
}

# Emits one tab-separated line per dependency: name<TAB>current<TAB>latest<TAB>status
# status is one of: uptodate, ahead, outdated, unreachable
# Dependencies whose current version isn't a parseable semver are skipped entirely.
compute_outdated_report() {
	local MODULES_PATH=${1}
	local BOX_JSON_PATH
	BOX_JSON_PATH=$(ensure_modules_manifest "${MODULES_PATH}")

	jq -r '.dependencies // {} | to_entries[] | "\(.key)\t\(.value)"' "${BOX_JSON_PATH}" 2>/dev/null |
	while IFS=$'\t' read -r module_name current_version; do
		local current_semver
		current_semver=$(extract_semantic_version "$current_version")
		[ -z "$current_semver" ] && continue

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
		printf '%s\t%s\t%s\t%s\n' "$module_name" "$current_version" "$latest_version" "$status"
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

	local OUTDATED_NAMES=() OUTDATED_VERSIONS=()
	while IFS=$'\t' read -r module_name current_version latest_version status; do
		local status_label
		case "$status" in
			uptodate) status_label="✅ up to date" ;;
			ahead) status_label="🔄 ahead (dev/snapshot)" ;;
			outdated)
				status_label="🆙 outdated"
				OUTDATED_NAMES+=("$module_name")
				OUTDATED_VERSIONS+=("$latest_version")
				;;
			*) status_label="⚠️  unable to check" ;;
		esac
		printf "%-25s %-15s %-15s %s\n" "$module_name" "$current_version" "$latest_version" "$status_label"
	done < "${REPORT_FILE}"
	rm -f "${REPORT_FILE}"

	printf "\n"
	local OUTDATED_COUNT=${#OUTDATED_NAMES[@]}
	if [ "$OUTDATED_COUNT" -eq 0 ]; then
		printf "${GREEN}✅ All modules are up to date${NORMAL}\n"
		return 0
	fi

	printf "${YELLOW}⚠️  %d module(s) outdated${NORMAL}\n" "$OUTDATED_COUNT"
	printf "${RED}⬆️  Would you like to update ${OUTDATED_COUNT} outdated module(s) now? [y/N]: ${NORMAL}"
	read -r confirmation < /dev/tty
	case "$confirmation" in
		[yY]|[yY][eE][sS])
			local i
			for (( i=0; i<OUTDATED_COUNT; i++ )); do
				install_module "${OUTDATED_NAMES[$i]}@${OUTDATED_VERSIONS[$i]}"
			done
			;;
		*)
			printf "${YELLOW}Skipping updates.${NORMAL}\n"
			;;
	esac
}

update_modules() {
	local MODULES_HOME=${1}
	local LOCATION_DESC=${2}
	local FORCE_UPDATE=${3:-false}

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

	local OUTDATED_NAMES=() OUTDATED_VERSIONS=()
	while IFS=$'\t' read -r module_name current_version latest_version status; do
		if [ "$status" = "outdated" ]; then
			printf -- "🆙 %s: %s → %s\n" "$module_name" "$current_version" "$latest_version"
			OUTDATED_NAMES+=("$module_name")
			OUTDATED_VERSIONS+=("$latest_version")
		fi
	done < "${REPORT_FILE}"
	rm -f "${REPORT_FILE}"

	local OUTDATED_COUNT=${#OUTDATED_NAMES[@]}
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

	local i
	for (( i=0; i<OUTDATED_COUNT; i++ )); do
		install_module "${OUTDATED_NAMES[$i]}@${OUTDATED_VERSIONS[$i]}"
	done

	printf "${GREEN}✅ Updated ${OUTDATED_COUNT} module(s)!${NORMAL}\n"
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

	# Handle --outdated command (can be used with --local)
	if [ "$1" = "--outdated" ]; then
		shift # Remove --outdated from arguments

		OUTDATED_LOCAL=false
		if [ "$1" = "--local" ]; then
			OUTDATED_LOCAL=true
			shift # Remove --local from arguments
		fi

		# Ensure no other arguments after --outdated [--local]
		if [ $# -gt 0 ]; then
			printf "${RED}❌ Error: --outdated command does not accept additional arguments${NORMAL}\n"
			printf "${YELLOW}💡 Usage: install-bx-module.sh --outdated [--local]${NORMAL}\n"
			exit 1
		fi

		LOCAL_INSTALL=$OUTDATED_LOCAL
		if [ "$OUTDATED_LOCAL" = true ]; then
			MODULES_HOME="$(pwd)/boxlang_modules"
			LOCATION_DESC="Local - $(pwd)/boxlang_modules"
		else
			if [ -z "${BOXLANG_HOME}" ]; then
				export BOXLANG_HOME="$HOME/.boxlang"
			fi
			MODULES_HOME="${BOXLANG_HOME}/modules"
			LOCATION_DESC="Global - ${BOXLANG_HOME}/modules"
		fi

		outdated_modules "$MODULES_HOME" "$LOCATION_DESC"
		exit 0
	fi

	# Handle --update command (can be used with --force and --local, in any order)
	if [ "$1" = "--update" ]; then
		shift # Remove --update from arguments

		FORCE_UPDATE=false
		for arg in "$@"; do
			if [ "$arg" = "--force" ]; then
				FORCE_UPDATE=true
				break
			fi
		done
		if [ "$FORCE_UPDATE" = true ]; then
			set -- $(printf '%s\n' "$@" | grep -v '^--force$')
		fi

		UPDATE_LOCAL=false
		for arg in "$@"; do
			if [ "$arg" = "--local" ]; then
				UPDATE_LOCAL=true
				break
			fi
		done
		if [ "$UPDATE_LOCAL" = true ]; then
			set -- $(printf '%s\n' "$@" | grep -v '^--local$')
		fi

		# Ensure no other arguments remain
		if [ $# -gt 0 ]; then
			printf "${RED}❌ Error: --update command does not accept additional arguments${NORMAL}\n"
			printf "${YELLOW}💡 Usage: install-bx-module.sh --update [--force] [--local]${NORMAL}\n"
			exit 1
		fi

		LOCAL_INSTALL=$UPDATE_LOCAL
		if [ "$UPDATE_LOCAL" = true ]; then
			MODULES_HOME="$(pwd)/boxlang_modules"
			LOCATION_DESC="Local - $(pwd)/boxlang_modules"
		else
			if [ -z "${BOXLANG_HOME}" ]; then
				export BOXLANG_HOME="$HOME/.boxlang"
			fi
			MODULES_HOME="${BOXLANG_HOME}/modules"
			LOCATION_DESC="Global - ${BOXLANG_HOME}/modules"
		fi

		update_modules "$MODULES_HOME" "$LOCATION_DESC" "$FORCE_UPDATE"
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
