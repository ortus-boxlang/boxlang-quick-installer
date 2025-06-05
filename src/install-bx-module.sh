#!/bin/bash

## BOXLANG Module Installer

# Configuration
FORGEBOX_API_URL="https://forgebox.io/api/v1"

show_help() {
	printf "${GREEN}BoxLang Module Installer${NORMAL}\n\n"
	printf "${YELLOW}This script installs one or more BoxLang modules from FORGEBOX.${NORMAL}\n\n"
	printf "${BOLD}Usage:${NORMAL}\n"
	printf "  install-bx-module.sh <module-name>[@<version>] [<module-name>[@<version>] ...] [--local]\n"
	printf "  install-bx-module.sh --list\n"
	printf "  install-bx-module.sh --help\n\n"
	printf "${BOLD}Arguments:${NORMAL}\n"
	printf "  <module-name>     The name of the module to install\n"
	printf "  [@<version>]      (Optional) The specific version of the module to install\n\n"
	printf "${BOLD}Options:${NORMAL}\n"
	printf "  --local           Install to local boxlang_modules folder instead of BoxLang HOME\n"
	printf "  --list            Show installed modules\n"
	printf "  --help, -h        Show this help message\n\n"
	printf "${BOLD}Examples:${NORMAL}\n"
	printf "  install-bx-module.sh cborm\n"
	printf "  install-bx-module.sh cborm@2.5.0\n"
	printf "  install-bx-module.sh cborm cbsecurity --local\n"
	printf "  install-bx-module.sh --list\n\n"
	printf "${BOLD}Notes:${NORMAL}\n"
	printf "  - If no version is specified, the latest version from FORGEBOX will be installed\n"
	printf "  - Multiple modules can be specified, separated by spaces\n"
	printf "  - Requires curl and jq to be installed\n"
}

list_modules() {
	if [ -z "${BOXLANG_HOME}" ]; then
		export BOXLANG_HOME="$HOME/.boxlang"
	fi
	MODULES_HOME="${BOXLANG_HOME}/modules"
	printf "${YELLOW}Installed OS BoxLang Modules (${MODULES_HOME}):${NORMAL}\n"

	# Check if modules directory exists
	if [ ! -d "${MODULES_HOME}" ]; then
		printf "${YELLOW}No modules directory found at ${MODULES_HOME}${NORMAL}\n"
		return 0
	fi

	# List all directories in the modules folder
	if [ -z "$(ls -A "${MODULES_HOME}" 2>/dev/null)" ]; then
		printf "${YELLOW}No modules installed${NORMAL}\n"
	else
		ls -1 "${MODULES_HOME}" | sed 's/^/- /'
	fi
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
		printf "${RED}Error: You must specify a BoxLang module to install${NORMAL}\n"
		printf "${YELLOW}Usage: install-bx-module.sh <module-name>[@<version>] [--local]${NORMAL}\n"
		exit 1
	fi

	# Check curl existence
	command -v curl >/dev/null 2>&1 || {
		printf "${RED}Error: curl is required but not installed${NORMAL}\n"
		exit 1
	}

	# Fetch latest version if not specified
	if [ -z "${TARGET_VERSION+x}" ] || [ -z "$TARGET_VERSION" ]; then
		command -v jq >/dev/null 2>&1 || {
			printf "${RED}Error: [jq] binary is not installed and we need it in order to parse JSON from FORGEBOX${NORMAL}\n"
			printf "${YELLOW}Please install jq from https://stedolan.github.io/jq/download/ or via your package manager${NORMAL}\n"
			printf "${YELLOW}For example, on MacOS you can install it via brew with:${NORMAL}\n"
			printf "${BLUE}brew install jq${NORMAL}\n"
			printf "${YELLOW}For example, on Linux you can install it via apt-get with:${NORMAL}\n"
			printf "${BLUE}apt-get install jq${NORMAL}\n"
			printf "${YELLOW}For example, on Windows you can install it via choco or winget with:${NORMAL}\n"
			printf "${BLUE}choco install jq or winget install jqlang.jq${NORMAL}\n"
			exit 1
		}

		printf "${YELLOW}No version specified, getting latest version from FORGEBOX...${NORMAL}\n"

		# Store Entry JSON From ForgeBox
		local ENTRY_JSON=$(curl -s "${FORGEBOX_API_URL}/entry/${TARGET_MODULE}/latest")

		# Validate API response
		if [ -z "$ENTRY_JSON" ] || [ "$ENTRY_JSON" = "null" ]; then
			printf "${RED}Error: Failed to fetch module information from FORGEBOX${NORMAL}\n"
			exit 1
		fi

		TARGET_VERSION=$(echo "${ENTRY_JSON}" | jq -r '.data.version')
		local DOWNLOAD_URL=$(echo "${ENTRY_JSON}" | jq -r '.data.downloadURL')

		# Validate parsed data
		if [ "$TARGET_VERSION" = "null" ] || [ -z "$TARGET_VERSION" ]; then
			printf "${RED}Error: Module '${TARGET_MODULE}' not found in FORGEBOX${NORMAL}\n"
			exit 1
		fi

		if [ "$DOWNLOAD_URL" = "null" ] || [ -z "$DOWNLOAD_URL" ]; then
			printf "${RED}Error: No download URL found for module '${TARGET_MODULE}'${NORMAL}\n"
			exit 1
		fi
	else
		# We have a targeted version, let's build the download URL from the artifacts directly
		local DOWNLOAD_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/${TARGET_MODULE}/${TARGET_VERSION}/${TARGET_MODULE}-${TARGET_VERSION}.zip"
	fi

	# Define paths based on LOCAL_INSTALL flag
	local DESTINATION="${MODULES_HOME}/${TARGET_MODULE}"

	# Check if module is already installed
	if [ -d "${DESTINATION}" ]; then
		printf "${YELLOW}Module '${TARGET_MODULE}' is already installed at ${DESTINATION}${NORMAL}\n"
		printf "${YELLOW}Proceeding with installation (will overwrite existing)...${NORMAL}\n"
	fi

	# Inform the user
	printf "${GREEN}Installing BoxLang® Module: ${TARGET_MODULE}@${TARGET_VERSION}\n"
	printf "Destination: ${DESTINATION}\n${NORMAL}\n"

	# Ensure module folders exist
	mkdir -p "${MODULES_HOME}"

	# Create secure temporary file
	# Cleanup the temp file in case it exists
	if [ -f "/tmp/${TARGET_MODULE}.zip" ]; then
		rm -f "/tmp/${TARGET_MODULE}.zip"
	fi
	local TEMP_FILE=$(mktemp "/tmp/${TARGET_MODULE}.zip")
	# Add a trap to remove the temp file on exit
	trap 'rm -f "${TEMP_FILE}"' EXIT

	# Download module
	printf "${BLUE}Downloading from ${DOWNLOAD_URL}...${NORMAL}\n"
	if ! curl -L --fail -o "${TEMP_FILE}" "${DOWNLOAD_URL}"; then
		printf "${RED}Error: Download failed${NORMAL}\n"
		exit 1
	fi

	# Record installation by calling forgebox at: /api/v1/install/${TARGET_MODULE}/${TARGET_VERSION}
	printf "${BLUE}Recording installation with FORGEBOX...${NORMAL}\n"
	if ! curl -s -o /dev/null "${FORGEBOX_API_URL}/install/${TARGET_MODULE}/${TARGET_VERSION}"; then
		printf "${YELLOW}Warning: Failed to record installation with FORGEBOX, but continuing...${NORMAL}\n"
	fi

	# Remove existing module folder
	rm -rf "${DESTINATION}"

	# Extract module
	printf "${BLUE}Extracting module...${NORMAL}\n"
	if ! unzip -o "${TEMP_FILE}" -d "${DESTINATION}"; then
		printf "${RED}Error: Failed to extract module${NORMAL}\n"
		exit 1
	fi

	# Verify extraction
	if [ ! -d "${DESTINATION}" ] || [ -z "$(ls -A "${DESTINATION}" 2>/dev/null)" ]; then
		printf "${RED}Error: Module extraction appears to have failed - destination directory is empty${NORMAL}\n"
		exit 1
	fi

	# Success message
	printf "${GREEN}\nBoxLang® Module [${TARGET_MODULE}@${TARGET_VERSION}] installed successfully!\n"
	echo ''
	echo '*************************************************************************'
	echo 'BoxLang® - Dynamic : Modular : Productive : https://boxlang.io'
	echo '*************************************************************************'
	echo "BoxLang® is FREE and Open-Source Software under the Apache 2.0 License"
	echo "You can also buy support and enhanced versions at https://boxlang.io/plans"
	echo 'p.s. Follow us at https://x.com/tryboxlang.'
	echo 'p.p.s. Clone us and star us at https://github.com/ortus-boxlang/boxlang'
	echo 'Please support us via Patreon at https://www.patreon.com/ortussolutions'
	echo '*************************************************************************'
	echo "Copyright and Registered Trademarks of Ortus Solutions, Corp"
	printf "${NORMAL}"
}

main() {
	# Use colors if the terminal supports them
	if which tput >/dev/null 2>&1; then
		ncolors=$(tput colors)
	fi
	if [ -t 1 ] && [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
		RED="$(tput setaf 1)"
		GREEN="$(tput setaf 2)"
		YELLOW="$(tput setaf 3)"
		BLUE="$(tput setaf 4)"
		BOLD="$(tput bold)"
		NORMAL="$(tput sgr0)"
	else
		RED=""
		GREEN=""
		YELLOW=""
		BLUE=""
		BOLD=""
		NORMAL=""
	fi

	# Enable exit-on-error
	set -e

	# Check if no arguments are passed
	if [ $# -eq 0 ]; then
		printf "${RED}Error: No module(s) specified${NORMAL}\n"
		printf "${YELLOW}This script installs one or more BoxLang modules.${NORMAL}\n"
		printf "${YELLOW}Usage: install-bx-module.sh <module-name>[@<version>] [<module-name>[@<version>] ...] [--local]${NORMAL}\n"
		printf "${YELLOW}- <module-name>: The name of the module to install.${NORMAL}\n"
		printf "${YELLOW}- [@<version>]: (Optional) The specific version of the module to install.${NORMAL}\n"
		printf "${YELLOW}- Multiple modules can be specified, separated by a space.${NORMAL}\n"
		printf "${YELLOW}- If no version is specified we will ask FORGEBOX for the latest version${NORMAL}\n"
		printf "${YELLOW}- Use --local to install to a local boxlang_modules folder instead of the BoxLang HOME${NORMAL}\n"
		printf "${YELLOW}- Use --list to show installed modules${NORMAL}\n"
		printf "${YELLOW}- Use --help to show this message${NORMAL}\n"
		exit 1
	fi

	# Show help if requested
	if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
		show_help
		exit 0
	fi

	# Detect if a single --list argument is passed
	if [ "$1" == "--list" ] && [ $# -eq 1 ]; then
		list_modules
		exit 0
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

	# Inform about local installation
	if [ "$LOCAL_INSTALL" = true ]; then
		printf "${YELLOW}Installing modules locally in $(pwd)/boxlang_modules${NORMAL}\n"
	fi

	# Loop through all provided arguments
	for module in "$@"; do
		printf "${GREEN}Starting installation of module: ${module}${NORMAL}\n"
		install_module "$module"
	done
}

main "$@"
