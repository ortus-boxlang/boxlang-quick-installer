#!/bin/bash

## BOXLANG WEB INSTALLER
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

	# Set the target version
	local TARGET_VERSION=${1}

	# Setup Global Variables
	local SNAPSHOT_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang/boxlang-snapshot.zip"
	local SNAPSHOT_URL_MINISERVER="https://downloads.ortussolutions.com/ortussolutions/boxlang-runtimes/boxlang-miniserver/boxlang-miniserver-snapshot.zip"
	local VERSIONED_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang/${TARGET_VERSION}/boxlang-${TARGET_VERSION}.zip"
	local VERSIONED_URL_MINISERVER="https://downloads.ortussolutions.com/ortussolutions/boxlang-runtimes/boxlang-miniserver/${TARGET_VERSION}/boxlang-miniserver-${TARGET_VERSION}.zip"
	local DESTINATION="/usr/local/"
	local DESTINATION_LIB="/usr/local/lib"
	local DESTINATION_BIN="/usr/local/bin"

	# Determine which URL to use
	if [ "${TARGET_VERSION}" = "snapshot" ]; then
		local DOWNLOAD_URL=${SNAPSHOT_URL}
		local DOWNLOAD_URL_MINISERVER=${SNAPSHOT_URL_MINISERVER}
	else
		local DOWNLOAD_URL=${VERSIONED_URL}
		local DOWNLOAD_URL_MINISERVER=${VERSIONED_URL_MINISERVER}
	fi

	# Check java exists
	command -v java >/dev/null 2>&1 || {
		echo "Error: Java is not installed and we need it for BoxLang to work. Please download JDK 17+ from https://adoptopenjdk.net/ and install it."
		exit 1
	}

	# Check java version is 17 or higher
	local JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
	if [ "${JAVA_VERSION}" \< "21" ]; then
		echo "Error: Java 21 or higher is required to run BoxLang"
		exit 1
	fi

	# Check curl exists
	command -v curl >/dev/null 2>&1 || {
		echo "Error: curl is not installed and we need it in order for the quick installer to work"
		exit 1
	}

	# Tell them where we will install
	printf "${GREEN}"
	echo ''
	echo '*************************************************************************'
	echo 'Welcome to the BoxLang® Quick Installer'
	echo '*************************************************************************'
	echo 'This will download and install the latest version of BoxLang® and the'
	echo 'BoxLang® MiniServer into your system.'
	echo '*************************************************************************'
	echo 'You can also download the BoxLang® runtimes from https://boxlang.io'
	echo '*************************************************************************'
	printf "${NORMAL}"

	# Announce it
	printf "${BLUE}Downloading BoxLang® [${TARGET_VERSION}] from [${DOWNLOAD_URL}]${NORMAL}\n"
	printf "${RED}Please wait...${NORMAL}\n"

	# Ensure destination folders
	mkdir -p /tmp
	mkdir -p /usr/local/bin
	mkdir -p /usr/local/lib

	# Download
	env curl -Lk -o /tmp/boxlang.zip "${DOWNLOAD_URL}" || {
		printf "Error: Download of BoxLang® binary failed\n"
		exit 1
	}
	env curl -Lk -o /tmp/boxlang-miniserver.zip "${DOWNLOAD_URL_MINISERVER}" || {
		printf "Error: Download of BoxLang® MiniServer binary failed\n"
		exit 1
	}
	printf "\n"
	printf "${GREEN}BoxLang® downloaded to [/tmp/boxlang.zip, /tmp/boxlang-miniserver.zip], continuing installation...${NORMAL}\n"
	printf "\n"

	# Inflate it
	printf "\n"
	printf "${BLUE}Unzipping BoxLang®...${NORMAL}\n"
	printf "\n"
	unzip -o /tmp/boxlang.zip -d "${DESTINATION}"
	unzip -o /tmp/boxlang-miniserver.zip -d "${DESTINATION}"

	# Make it executable
	printf "\n"
	printf "${BLUE}Making BoxLang® Executable...${NORMAL}\n"
	chmod +x "${DESTINATION_BIN}/boxlang"
	chmod +x "${DESTINATION_BIN}/boxlang-miniserver"

	# Add links
	printf "\n"
	printf "${BLUE}Adding symbolic links...${NORMAL}\n"
	ln -sf "${DESTINATION_BIN}/boxlang" "${DESTINATION_BIN}/bx"
	ln -sf "${DESTINATION_BIN}/boxlang-miniserver" "${DESTINATION_BIN}/bx-miniserver"

	# Install the Installer scripts
	printf "\n"
	printf "${BLUE}Installing BoxLang® Module & Core Installer Scripts [install-bx-module, install-boxlang]...${NORMAL}\n"
	env curl -Lk -o "${DESTINATION_BIN}/install-bx-module" "https://raw.githubusercontent.com/ortus-boxlang/boxlang-quick-installer/development/src/install-bx-module.sh"
	chmod +x "${DESTINATION_BIN}/install-bx-module"
	env curl -Lk -o "${DESTINATION_BIN}/install-boxlang" "https://raw.githubusercontent.com/ortus-boxlang/boxlang-quick-installer/development/src/install-boxlang.sh"
	chmod +x "${DESTINATION_BIN}/install-boxlang"

	# Cleanup
	printf "\n"
	printf "${BLUE}Cleaning up...${NORMAL}\n"
	rm -fv /tmp/boxlang.zip
	rm -fv /tmp/boxlang-miniserver.zip
	rm -fv ${DESTINATION_BIN}/boxlang.bat
	rm -fv ${DESTINATION_BIN}/boxlang-miniserver.bat

	# Run it
	printf "\n"
	printf "${RED}Testing BoxLang®...${NORMAL}\n"
	printf "\n"
	"${DESTINATION_BIN}/boxlang" --version

	printf "${GREEN}"
	echo ''
	echo "BoxLang® Binaries are now installed to [$DESTINATION_BIN]"
	echo "BoxLang® JARs are now installed to [$DESTINATION_LIB]"
	echo "BoxLang® Home is now set to [~/.boxlang]"
	echo ''
	echo 'Your [BOXLANG_HOME] is set by default to your user home directory.'
	echo 'You can change this by setting the [BOXLANG_HOME] environment variable in your shell profile'
	echo 'Just copy the following line to override the location if you want'
	echo ''
	echo "EXPORT BOXLANG_HOME=/opt/boxlang"
	echo ''
	echo "You can start a MiniServer by running: boxlang-miniserver"
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

main "${1:-snapshot}"
