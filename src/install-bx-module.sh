#!/bin/bash

## BOXLANG Module Installer
main() {
	# Use colors, but only if connected to a terminal, and that terminal
	# supports them.
	if which tput >/dev/null 2>&1; then
		ncolors=$(tput colors)
	fi
	if [ -t 1 ] && [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
		local RED="$(tput setaf 1)"
		local GREEN="$(tput setaf 2)"
		local YELLOW="$(tput setaf 3)"
		local BLUE="$(tput setaf 4)"
		local BOLD="$(tput bold)"
		local NORMAL="$(tput sgr0)"
	else
		local RED=""
		local GREEN=""
		local YELLOW=""
		local BLUE=""
		local BOLD=""
		local NORMAL=""
	fi

	# Only enable exit-on-error after the non-critical colorization stuff,
	# which may fail on systems lacking tput or terminfo
	set -e

	# Setup Global Variables
	local TARGET_MODULE=${1}
	local TARGET_VERSION=${2}

	# Convert module name to lowercase
    TARGET_MODULE=$(echo "$TARGET_MODULE" | tr '[:upper:]' '[:lower:]')

	# Check if we have a target module, else error
	if [ -z "${TARGET_MODULE+x}" ] || [ -z "$TARGET_MODULE" ]; then
		printf "${RED}Error: You must specify a BoxLang module to install${NORMAL}\n"
		exit 1
	fi

	# Check curl exists else error
	command -v curl >/dev/null 2>&1 || {
		printf "${RED}Error: curl is not installed and we need it in order for the quick installer to work${NORMAL}\n"
		exit 1
	}

	# Check if we have a target version, else ask ForgeBox for the latest
	if [ -z "${TARGET_VERSION+x}" ] || [ -z "$TARGET_VERSION" ]; then

		# Check if jq is installed for JSON parsing, if not, request to be installed
		if ! command -v jq >/dev/null 2>&1; then
			printf "${RED}Error: [jq] binary is not installed and we need it in order to parse JSON from FORGEBOX${NORMAL}\n"
			printf "${YELLOW}Please install jq from https://stedolan.github.io/jq/download/ or via your package manager${NORMAL}\n"
			# Show common package managers
			printf "${YELLOW}For example, on MacOS you can install it via brew with:${NORMAL}\n"
			printf "${BLUE}brew install jq${NORMAL}\n"
			printf "${YELLOW}For example, on Linux you can install it via apt-get with:${NORMAL}\n"
			printf "${BLUE}apt-get install jq${NORMAL}\n"
			printf "${YELLOW}For example, on Windows you can install it via choco or winget with:${NORMAL}\n"
			printf "${BLUE}choco install jq or winget install jqlang.jq${NORMAL}\n"
			exit 1
		fi

		# Store Entry JSON From ForgeBox
		local ENTRY_JSON=$(curl -s "https://forgebox.io/api/v1/entry/${TARGET_MODULE}/latest")
		TARGET_VERSION=$(echo ${ENTRY_JSON} | jq -r '.data.version')
		local DOWNLOAD_URL=$(echo ${ENTRY_JSON} | jq -r '.data.downloadURL')
	else
		# We have a targeted version, let's build the download URL from the artifacts directly
		local DOWNLOAD_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/${TARGET_MODULE}/${TARGET_VERSION}/${TARGET_MODULE}-${TARGET_VERSION}.zip"
	fi

	# If we don't have a BOXLANG_HOME set, let's set it
	if [ -z "${BOXLANG_HOME}" ]; then
		export BOXLANG_HOME="$HOME/.boxlang"
	fi

	# BoxLang Module URLS
	local MODULES_HOME="${BOXLANG_HOME}/modules"
	local DESTINATION="${MODULES_HOME}/${TARGET_MODULE}"

	# Tell them where we will install
	printf "${GREEN}"
	echo ''
	echo '*************************************************************************'
	echo 'Welcome to the BoxLang® Module Quick Installer'
	echo '*************************************************************************'
	echo 'This will download and install the requested module into you'
	echo "BoxLang® HOME directory at [${DESTINATION}]"
	echo '*************************************************************************'
	echo 'You can also download the BoxLang® modules from https://forgebox.io'
	echo '*************************************************************************'
	printf "${NORMAL}"

	# Announce it
	printf "${BLUE}Downloading Module [${TARGET_MODULE}] from [${DOWNLOAD_URL}]${NORMAL}\n"
	printf "${RED}Please wait...${NORMAL}\n"

	# Ensure module folders exist
	mkdir -p ${MODULES_HOME}

	# Download
	env curl -Lk -o /tmp/${TARGET_MODULE}.zip "${DOWNLOAD_URL}" || {
		printf "Error: Download of BoxLang® module failed\n"
		exit 1
	}
	printf "\n"
	printf "${GREEN}Module downloaded, continuing installation...${NORMAL}\n"
	printf "\n"

	# Remove the module folder if it exists
	rm -rf ${DESTINATION}

	# Inflate it
	printf "\n"
	printf "${BLUE}Unzipping Module...${NORMAL}\n"
	printf "\n"
	unzip -o /tmp/${TARGET_MODULE}.zip -d "${DESTINATION}"

	printf "${GREEN}"
	echo ''
	echo "BoxLang® Module [${TARGET_MODULE}@${TARGET_VERSION}] installed to [${DESTINATION}]"
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

main "${1}" "${2}"
