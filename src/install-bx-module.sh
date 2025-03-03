#!/bin/bash

## BOXLANG Module Installer
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
		printf "${YELLOW}Usage: install-bx-module.sh <module-name>[@<version>]${NORMAL}\n"
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
		local ENTRY_JSON=$(curl -s "https://forgebox.io/api/v1/entry/${TARGET_MODULE}/latest")
		TARGET_VERSION=$(echo ${ENTRY_JSON} | jq -r '.data.version')
		local DOWNLOAD_URL=$(echo ${ENTRY_JSON} | jq -r '.data.downloadURL')
	else
		# We have a targeted version, let's build the download URL from the artifacts directly
		local DOWNLOAD_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/${TARGET_MODULE}/${TARGET_VERSION}/${TARGET_MODULE}-${TARGET_VERSION}.zip"
	fi

	# Set BOXLANG_HOME if not already defined
	if [ -z "${BOXLANG_HOME}" ]; then
		export BOXLANG_HOME="$HOME/.boxlang"
	fi

	# Define paths
	local MODULES_HOME="${BOXLANG_HOME}/modules"
	local DESTINATION="${MODULES_HOME}/${TARGET_MODULE}"

	# Inform the user
	printf "${GREEN}Installing BoxLang® Module: ${TARGET_MODULE}@${TARGET_VERSION}\n"
	printf "Destination: ${DESTINATION}\n${NORMAL}\n"

	# Ensure module folders exist
	mkdir -p ${MODULES_HOME}

	# Download module
	printf "${BLUE}Downloading from ${DOWNLOAD_URL}...${NORMAL}\n"
	curl -Lk -o /tmp/${TARGET_MODULE}.zip "${DOWNLOAD_URL}" || {
		printf "${RED}Error: Download failed${NORMAL}\n"
		exit 1
	}

	# Remove existing module folder
	rm -rf ${DESTINATION}

	# Extract module
	printf "${BLUE}Extracting module...${NORMAL}\n"
	unzip -o /tmp/${TARGET_MODULE}.zip -d "${DESTINATION}"

	# Success message
	printf "${GREEN}\nBoxLang® Module [${TARGET_MODULE}@${TARGET_VERSION}] installed successfully!\n"
	echo ''
	echo '*************************************************************************'
	echo 'BoxLang® - Dynamic : Modular : Productive : https://boxlang.io'
	echo '*************************************************************************'
	echo "BoxLang® is FREE and Open-Source Software under the Apache 2.0 License"
	echo "You can also buy support and enhanced versions at https://boxlang.io/plans"
	echo 'p.s. Follow us at https://twitter.com/ortussolutions.'
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
		printf "${YELLOW}Usage: install-bx-module.sh <module-name>[@<version>] [<module-name>[@<version>] ...]${NORMAL}\n"
		printf "${YELLOW}- <module-name>: The name of the module to install.${NORMAL}\n"
		printf "${YELLOW}- [@<version>]: (Optional) The specific version of the module to install.${NORMAL}\n"
		printf "${YELLOW}- Multiple modules can be specified, separated by a space.${NORMAL}\n"
		printf "${YELLOW}- If no version is specified we will ask FORGEBOX for the latest version${NORMAL}\n"
		exit 1
	fi

	# Loop through all provided arguments
	for module in "$@"; do
		printf "${GREEN}Starting installation of module: ${module}${NORMAL}\n"
		install_module "$module"
	done
}

main "$@"
