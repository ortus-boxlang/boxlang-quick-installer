#!/bin/bash

# BoxLang Helpers
# A collection of helper functions for BoxLang scripts.
# Author: BoxLang Team
# Version: @build.version@
# License: Apache License, Version 2.0

###########################################################################
# Printing Functions
###########################################################################

print_info() {
    printf "${BLUE}ℹ $1${NORMAL}\n"
}

print_success() {
    printf "${GREEN}✅ $1${NORMAL}\n"
}

print_warning() {
    printf "${YELLOW}⚠️  $1${NORMAL}\n"
}

print_error() {
    printf "${RED}❌ $1${NORMAL}\n"
}

print_header() {
    printf "${BOLD}${CYAN}$1${NORMAL}\n"
}

###########################################################################
# Check if command exists
###########################################################################
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

###########################################################################
# Setup Colors
###########################################################################
setup_colors() {
	# Use colors, but only if connected to a terminal, and that terminal supports them.
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
		MAGENTA="$(tput setaf 5)"
		CYAN="$(tput setaf 6)"
		WHITE="$(tput setaf 7)"
		BLACK="$(tput setaf 0)"
		UNDERLINE="$(tput smul)"
	else
		RED=""
		GREEN=""
		YELLOW=""
		BLUE=""
		BOLD=""
		NORMAL=""
		MAGENTA=""
		CYAN=""
		WHITE=""
		BLACK=""
		UNDERLINE=""
	fi
}

###########################################################################
# Pre-flight Checks
###########################################################################
# Verifies required dependencies are installed: curl, unzip and jq
preflight_check() {
	printf "${BLUE}🔍 Running system requirements checks...${NORMAL}\n"
	local missing_deps=()

	command_exists curl || missing_deps+=("curl")
	command_exists unzip || missing_deps+=("unzip")
	command_exists jq || missing_deps+=("jq")

	if [ ${#missing_deps[@]} -ne 0 ]; then
		printf "${RED}❌ Missing required dependencies: ${missing_deps[*]}${NORMAL}\n"

		if [ "$(uname)" = "Darwin" ]; then
			printf "${BLUE}💡 On macOS, you can install missing dependencies using:${NORMAL}\n"
			for dep in "${missing_deps[@]}"; do
				if [ "$dep" = "curl" ]; then
					printf "   curl is usually pre-installed, try: xcode-select --install\n"
				elif [ "$dep" = "unzip" ]; then
					printf "   unzip is usually pre-installed, try: xcode-select --install\n"
				fi
			done
		elif [ "$(uname)" = "Linux" ]; then
			if command_exists apt-get; then
				printf "${BLUE}💡 On Ubuntu/Debian, install with:${NORMAL}\n"
				printf "   sudo apt update && sudo apt install ${missing_deps[*]}\n"
			elif command_exists yum; then
				printf "${BLUE}💡 On RHEL/CentOS, install with:${NORMAL}\n"
				printf "   sudo yum install ${missing_deps[*]}\n"
			elif command_exists dnf; then
				printf "${BLUE}💡 On Fedora, install with:${NORMAL}\n"
				printf "   sudo dnf install ${missing_deps[*]}\n"
			elif command_exists pacman; then
				printf "${BLUE}💡 On Arch Linux, install with:${NORMAL}\n"
				printf "   sudo pacman -S ${missing_deps[*]}\n"
			fi
		fi
		return 1
	fi

	###########################################################################
	# Java Version Check
	###########################################################################
	if ! check_java_version; then
		printf "${RED}🔴  Error: Java 21 or higher is required to run BoxLang${NORMAL}\n"
		printf "${YELLOW}Please install Java 21+ and ensure it's in your PATH.${NORMAL}\n"
		printf "${YELLOW}Recommended: OpenJDK 21+ or Oracle JRE 21+${NORMAL}\n"

		if [ "$(uname)" = "Darwin" ]; then
			printf "${BLUE}💡 On macOS, you can install Java using:${NORMAL}\n"
			printf "   brew install openjdk@21\n"
			printf "   or download from: https://adoptium.net/\n"
			if command_exists sdk; then
				printf "   or with SDKMAN: sdk install java 21-tem\n"
			fi
		elif [ "$(uname)" = "Linux" ]; then
			if command_exists apt-get; then
				printf "${BLUE}💡 On Ubuntu/Debian, you can install Java using:${NORMAL}\n"
				printf "   sudo apt update && sudo apt install openjdk-21-jre\n"
			elif command_exists yum; then
				printf "${BLUE}💡 On RHEL/CentOS/Fedora, you can install Java using:${NORMAL}\n"
				printf "   sudo yum install java-21-openjdk\n"
			elif command_exists dnf; then
				printf "${BLUE}💡 On Fedora, you can install Java using:${NORMAL}\n"
				printf "   sudo dnf install java-21-openjdk\n"
			else
				printf "${BLUE}💡 On Linux, you can install Java using your package manager or:${NORMAL}\n"
				printf "   Download from: https://adoptium.net/\n"
			fi
			if command_exists sdk; then
				printf "   or with SDKMAN: sdk install java 21-tem\n"
			fi
		fi
		return 1
	fi

	return 0
}

###########################################################################
# Java Version Check Function (Enhanced for sudo compatibility)
###########################################################################
check_java_version() {
	printf "${BLUE}🔍 Checking Java 21 installation...${NORMAL}\n"
	local JAVA_CMD=""
	local JAVA_VERSION=""

	# Function to extract version from java output
	extract_java_version() {
		local version_output="$1"
		# Handle both old (1.8.0_xxx) and new (11.x.x, 17.x.x, 21.x.x) version formats
		echo "$version_output" | awk -F '"' '/version/ {print $2}' | sed 's/^1\.//' | cut -d'.' -f1
	}

	# Try multiple approaches to find Java, especially when running under sudo
	local java_candidates=(
		"java"                                          # Standard PATH
		"$JAVA_HOME/bin/java"                          # JAVA_HOME if set
		"/usr/bin/java"                                # Common system location
		"/usr/local/bin/java"                          # Homebrew location
		"/opt/homebrew/bin/java"                       # Apple Silicon Homebrew
		"/Library/Java/JavaVirtualMachines/*/Contents/Home/bin/java"  # macOS Oracle/OpenJDK
	)

	# If running under sudo, try to get the original user's environment
	if [ -n "${SUDO_USER}" ]; then
		printf "${YELLOW}🛡️ Detected sudo execution. Checking Java from original user context...${NORMAL}\n"

		# Try to get Java from the original user's environment
		local user_java_cmd=$(sudo -u "${SUDO_USER}" -i bash -c 'command -v java 2>/dev/null' || echo "")
		if [ -n "$user_java_cmd" ]; then
			java_candidates=("$user_java_cmd" "${java_candidates[@]}")
		fi

		# Try to get JAVA_HOME from original user
		local user_java_home=$(sudo -u "${SUDO_USER}" -i bash -c 'echo $JAVA_HOME 2>/dev/null' || echo "")
		if [ -n "$user_java_home" ] && [ -f "$user_java_home/bin/java" ]; then
			java_candidates=("$user_java_home/bin/java" "${java_candidates[@]}")
		fi
	fi

	# Test each candidate
	for candidate in "${java_candidates[@]}"; do
		# Handle glob patterns
		if [[ "$candidate" == *"*"* ]]; then
			for expanded_path in $candidate; do
				if [ -x "$expanded_path" ]; then
					local version_output=$("$expanded_path" -version 2>&1)
					if [ $? -eq 0 ]; then
						JAVA_VERSION=$(extract_java_version "$version_output")
						if [ -n "$JAVA_VERSION" ] && [ "$JAVA_VERSION" -ge 21 ] 2>/dev/null; then
							JAVA_CMD="$expanded_path"
							printf "${GREEN}✅ Found Java ${JAVA_VERSION} at: ${JAVA_CMD}${NORMAL}\n"
							return 0
						fi
					fi
				fi
			done
		else
			if command_exists "$candidate" || [ -x "$candidate" ]; then
				local version_output=$("$candidate" -version 2>&1)
				if [ $? -eq 0 ]; then
					JAVA_VERSION=$(extract_java_version "$version_output")
					if [ -n "$JAVA_VERSION" ] && [ "$JAVA_VERSION" -ge 21 ] 2>/dev/null; then
						JAVA_CMD="$candidate"
						printf "${GREEN}✅ Found Java ${JAVA_VERSION} at: ${JAVA_CMD}${NORMAL}\n"
						return 0
					elif [ -n "$JAVA_VERSION" ]; then
						printf "${YELLOW}⚠️  Found Java ${JAVA_VERSION} at ${candidate}, but Java 21+ is required${NORMAL}\n"
					fi
				fi
			fi
		fi
	done

	return 1
}

###########################################################################
# Version Comparison Functions
###########################################################################
# Extract semantic version (Major.Minor.Patch) from version string
extract_semantic_version() {
	local version_string="$1"
	# Extract version like "1.2.3" from strings like "BoxLang 1.2.3+20241201.120000" or "1.2.3+buildId"
	echo "$version_string" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1
}

# Compare two semantic versions (Major.Minor.Patch)
# Returns: 0 if equal, 1 if first > second, 2 if first < second
compare_versions() {
	local version1="$1"
	local version2="$2"

	# Split versions into arrays
	IFS='.' read -ra V1 <<< "$version1"
	IFS='.' read -ra V2 <<< "$version2"

	# Compare major, minor, patch
	for i in 0 1 2; do
		local v1_part=${V1[i]:-0}
		local v2_part=${V2[i]:-0}

		if [ "$v1_part" -gt "$v2_part" ]; then
			return 1  # version1 > version2
		elif [ "$v1_part" -lt "$v2_part" ]; then
			return 2  # version1 < version2
		fi
	done

	return 0  # versions are equal
}