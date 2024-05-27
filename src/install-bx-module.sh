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

	# If we don't have a BOXLANG_HOME set, let's set it
	if [ -z "${BOXLANG_HOME}" ]; then
		export BOXLANG_HOME="$HOME/.boxlang"
	fi

	# BoxLang Module URLS
	local DOWNLOAD_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/${TARGET_MODULE}/${TARGET_VERSION}/${TARGET_MODULE}-${TARGET_VERSION}.zip"
	local MODULES_HOME="${BOXLANG_HOME}/modules"
	local DESTINATION="${MODULES_HOME}/${TARGET_MODULE}"

	# Check curl exists
	command -v curl >/dev/null 2>&1 || {
		echo "Error: curl is not installed and we need it in order for the quick installer to work"
		exit 1
	}

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

main "${1}" "${2:-1.0.0}"
