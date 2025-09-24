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
    printf "${BLUE}ℹ️ $1${NORMAL}\n"
}

print_success() {
    printf "${GREEN}✅ $1${NORMAL}\n"
}

print_warning() {
    printf "${YELLOW}⚠️  $1${NORMAL}\n"
}

print_error() {
    printf "${RED}🔴  $1${NORMAL}\n"
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
	local auto_install="${1:-false}"
	printf "${BLUE}🔍 Running system requirements checks...${NORMAL}\n"
	local missing_deps=()

	# Check required commands dependencies
	if [ "$(uname)" = "Darwin" ]; then
		# If brew is not installed, then quit, but only if we are on macOS
		if ! command_exists brew; then
			printf "${RED}❌ Homebrew is not installed. Please install Homebrew first.${NORMAL}\n"
			printf "${BLUE}💡 You can install Homebrew with:${NORMAL}\n"
			printf "${GREEN}   /bin/bash -c '$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)'\n"
			return 1
		fi
	fi
	command_exists curl || missing_deps+=( "curl" )
	command_exists unzip || missing_deps+=( "unzip" )
	command_exists jq || missing_deps+=( "jq" )

	if [ ${#missing_deps[@]} -ne 0 ]; then
		printf "${RED}❌ Missing required dependencies: ${missing_deps[*]}${NORMAL}\n"

		if [ "$(uname)" = "Darwin" ]; then
			# Install the dependencies using Homebrew
			printf "${BLUE}💡 Installing missing dependencies using Homebrew...${NORMAL}\n"
			for dep in "${missing_deps[@]}"; do
				printf "${BLUE}   Installing ${dep}...${NORMAL}\n"
				if ! brew install "$dep"; then
					printf "${RED}❌ Failed to install ${dep}. Please install it manually.${NORMAL}\n"
					return 1
				fi
			done
			printf "${GREEN}✅ All dependencies installed successfully!${NORMAL}\n"
		elif [ "$(uname)" = "Linux" ]; then
			printf "${BLUE}💡 Installing missing dependencies using system package manager...${NORMAL}\n"
			if command_exists apt-get; then
				printf "${BLUE}   Updating package list and installing dependencies...${NORMAL}\n"
				if ! sudo apt update && sudo apt install -y ${missing_deps[*]}; then
					printf "${RED}❌ Failed to install dependencies with apt. Please install them manually.${NORMAL}\n"
					return 1
				fi
			elif command_exists yum; then
				printf "${BLUE}   Installing dependencies with yum...${NORMAL}\n"
				if ! sudo yum install -y ${missing_deps[*]}; then
					printf "${RED}❌ Failed to install dependencies with yum. Please install them manually.${NORMAL}\n"
					return 1
				fi
			elif command_exists dnf; then
				printf "${BLUE}   Installing dependencies with dnf...${NORMAL}\n"
				if ! sudo dnf install -y ${missing_deps[*]}; then
					printf "${RED}❌ Failed to install dependencies with dnf. Please install them manually.${NORMAL}\n"
					return 1
				fi
			elif command_exists pacman; then
				printf "${BLUE}   Installing dependencies with pacman...${NORMAL}\n"
				if ! sudo pacman -S --noconfirm ${missing_deps[*]}; then
					printf "${RED}❌ Failed to install dependencies with pacman. Please install them manually.${NORMAL}\n"
					return 1
				fi
			else
				printf "${RED}❌ No supported package manager found. Please install dependencies manually: ${missing_deps[*]}${NORMAL}\n"
				return 1
			fi
			printf "${GREEN}✅ All dependencies installed successfully!${NORMAL}\n"
		fi
	fi

	###########################################################################
	# Java Version Check
	###########################################################################
	if ! check_java_version "$auto_install"; then
		printf "${RED}🔴  Error: Java 21 or higher is required to run BoxLang${NORMAL}\n"

		# Otherwise, prompt user for manual installation choice
		printf "${YELLOW}Would you like to automatically install Java 21 JRE? (y/N)${NORMAL} "
		read -r response
		case "$response" in
			[yY][eE][sS]|[yY])
				printf "${BLUE}📥 Proceeding with automatic Java installation...${NORMAL}\n"
				if install_java; then
					printf "${GREEN}✅ Java installation completed successfully!${NORMAL}\n"
					return 0
				else
					printf "${RED}❌ Automatic Java installation failed.${NORMAL}\n"
					return 1
				fi
				;;
			*)
				printf "${YELLOW}💡 You can install Java manually using:${NORMAL}\n"
				if [ "$(uname)" = "Darwin" ]; then
					printf "   brew install openjdk@21\n"
					printf "   or download from: https://adoptium.net/\n"
					if command_exists sdk; then
						printf "   or with SDKMAN: sdk install java 21-tem\n"
					fi
				elif [ "$(uname)" = "Linux" ]; then
					if command_exists apt-get; then
						printf "   sudo apt update && sudo apt install openjdk-21-jre\n"
					elif command_exists yum; then
						printf "   sudo yum install java-21-openjdk\n"
					elif command_exists dnf; then
						printf "   sudo dnf install java-21-openjdk\n"
					else
						printf "   Download from: https://adoptium.net/\n"
					fi
					if command_exists sdk; then
						printf "   or with SDKMAN: sdk install java 21-tem\n"
					fi
				fi
				exit 1
				;;
		esac
	fi

	return 0
}

###########################################################################
# Java Version Check Function (Enhanced for sudo compatibility)
###########################################################################
check_java_version() {
	local auto_install="${1:-false}"
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

	# If auto_install is true, attempt automatic installation
	if [ "$auto_install" = "true" ]; then
		printf "${YELLOW}Java 21+ not found. Attempting automatic installation...${NORMAL}\n"
		if install_java; then
			printf "${GREEN}✅ Java installation completed successfully!${NORMAL}\n"
			return 0
		else
			printf "${RED}❌ Automatic Java installation failed.${NORMAL}\n"
			return 1
		fi
	fi

	return 1
}

###########################################################################
# Java Installation Function
###########################################################################
install_java() {

	# Detect OS and architecture
	local OS=$(uname -s)
	local ARCH=$(uname -m)
	local JRE_VERSION="21.0.8+9 "
	local INSTALL_BASE=""
	local JRE_URL=""
	local JRE_FILENAME=""
	local JAVA_INSTALL_DIR=""

	printf "${BLUE}☕ Installing Java ${JRE_VERSION} ...${NORMAL}\n"

	# Normalize architecture names
	case "$ARCH" in
		x86_64|amd64) ARCH="x64" ;;
		aarch64|arm64) ARCH="aarch64" ;;
		*)
			print_error "Unsupported architecture: $ARCH"
			return 1
			;;
	esac

	# Convert JRE_VERSION to URL format (replace . with %)
	local JRE_URL_VERSION=$(echo "$JRE_VERSION" | sed 's/\./%2B/g')

	# Set URLs and paths based on OS
	case "$OS" in
		Darwin)
			INSTALL_BASE="/Library/Java/JavaVirtualMachines"
			if [ "$ARCH" = "aarch64" ]; then
				JRE_URL="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${JRE_URL_VERSION}/OpenJDK21U-jre_aarch64_mac_hotspot_${JRE_VERSION}.tar.gz"
				JRE_FILENAME="OpenJDK21U-jre_aarch64_mac_hotspot_${JRE_VERSION}.tar.gz"
			else
				JRE_URL="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${JRE_URL_VERSION}/OpenJDK21U-jre_x64_mac_hotspot_${JRE_VERSION}.tar.gz"
				JRE_FILENAME="OpenJDK21U-jre_x64_mac_hotspot_${JRE_VERSION}.tar.gz"
			fi
			JAVA_INSTALL_DIR="$INSTALL_BASE/openjdk-21-jre"
			;;
		Linux)
			INSTALL_BASE="/opt/java"
			if [ "$ARCH" = "aarch64" ]; then
				JRE_URL="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${JRE_URL_VERSION}/OpenJDK21U-jre_aarch64_linux_hotspot_${JRE_VERSION}.tar.gz"
				JRE_FILENAME="OpenJDK21U-jre_aarch64_linux_hotspot_${JRE_VERSION}.tar.gz"
			else
				JRE_URL="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${JRE_URL_VERSION}/OpenJDK21U-jre_x64_linux_hotspot_${JRE_VERSION}.tar.gz"
				JRE_FILENAME="OpenJDK21U-jre_x64_linux_hotspot_${JRE_VERSION}.tar.gz"
			fi
			JAVA_INSTALL_DIR="$INSTALL_BASE/openjdk-21-jre"
			;;
		*)
			print_error "Unsupported operating system: $OS"
			return 1
			;;
	esac

	printf "${BLUE}📍 Detected: $OS ($ARCH)${NORMAL}\n"
	printf "${BLUE}📥 Downloading JRE from: $JRE_URL${NORMAL}\n"
	printf "${BLUE}📂 Installing to: $JAVA_INSTALL_DIR${NORMAL}\n"

	# Create temporary directory
	local TEMP_DIR=$(mktemp -d)
	local DOWNLOAD_PATH="$TEMP_DIR/$JRE_FILENAME"

	# Download JRE
	if ! curl -fsSL "$JRE_URL" -o "$DOWNLOAD_PATH"; then
		print_error "Failed to download JRE"
		rm -rf "$TEMP_DIR"
		return 1
	fi

	printf "${GREEN}✅ Downloaded JRE successfully${NORMAL}\n"

	# Create installation directory (requires sudo on most systems)
	printf "${BLUE}📁 Creating installation directory: $JAVA_INSTALL_DIR${NORMAL}\n"
	if [ "$OS" = "Darwin" ] || [ "$OS" = "Linux" ]; then
		if ! sudo mkdir -p "$JAVA_INSTALL_DIR"; then
			print_error "Failed to create installation directory"
			rm -rf "$TEMP_DIR"
			return 1
		fi
	fi

	# Extract JRE
	printf "${BLUE}📦 Extracting JRE...${NORMAL}\n"
	if ! tar -xzf "$DOWNLOAD_PATH" -C "$TEMP_DIR"; then
		print_error "Failed to extract JRE archive"
		rm -rf "$TEMP_DIR"
		return 1
	fi

	# Find the extracted directory (it should contain the JRE)
	local EXTRACTED_DIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)
	if [ -z "$EXTRACTED_DIR" ]; then
		print_error "Could not find extracted JRE directory"
		rm -rf "$TEMP_DIR"
		return 1
	fi

	# Remove existing installation if it exists
	if [ -d "$JAVA_INSTALL_DIR" ]; then
		printf "${BLUE}🧹 Removing existing Java installation...${NORMAL}\n"
		sudo rm -rf "$JAVA_INSTALL_DIR"
	fi

	# Move extracted content to final location
	printf "${BLUE}📋 Installing JRE to $JAVA_INSTALL_DIR...${NORMAL}\n"
	if ! sudo mv "$EXTRACTED_DIR" "$JAVA_INSTALL_DIR"; then
		print_error "Failed to move JRE to installation directory"
		rm -rf "$TEMP_DIR"
		return 1
	fi

	# Set permissions
	sudo chmod -R 755 "$JAVA_INSTALL_DIR"

	# Clean up temporary files
	rm -rf "$TEMP_DIR"

	# Set up environment variables
	local JAVA_BIN="$JAVA_INSTALL_DIR/bin"
	local PROFILE_FILE=""

	# Determine shell profile file
	if [ -n "$ZSH_VERSION" ] && [ -f "$HOME/.zshrc" ]; then
		PROFILE_FILE="$HOME/.zshrc"
	elif [ -f "$HOME/.bashrc" ]; then
		PROFILE_FILE="$HOME/.bashrc"
	elif [ -f "$HOME/.bash_profile" ]; then
		PROFILE_FILE="$HOME/.bash_profile"
	elif [ -f "$HOME/.profile" ]; then
		PROFILE_FILE="$HOME/.profile"
	fi

	if [ -n "$PROFILE_FILE" ]; then
		printf "${BLUE}⚙️  Updating shell profile: $PROFILE_FILE${NORMAL}\n"

		# Remove any existing JAVA_HOME exports for our installation
		if [ "$OS" = "Darwin" ]; then
			sed -i '' '/export JAVA_HOME.*\/Library\/Java\/JavaVirtualMachines\/openjdk-21-jre/d' "$PROFILE_FILE" 2>/dev/null || true
			sed -i '' '/export PATH.*\/Library\/Java\/JavaVirtualMachines\/openjdk-21-jre/d' "$PROFILE_FILE" 2>/dev/null || true
		else
			sed -i '/export JAVA_HOME.*\/opt\/java\/openjdk-21-jre/d' "$PROFILE_FILE" 2>/dev/null || true
			sed -i '/export PATH.*\/opt\/java\/openjdk-21-jre/d' "$PROFILE_FILE" 2>/dev/null || true
		fi

		# Add new environment variables
		echo "" >> "$PROFILE_FILE"
		echo "# Java JRE installed by BoxLang installer" >> "$PROFILE_FILE"
		echo "export JAVA_HOME=\"$JAVA_INSTALL_DIR\"" >> "$PROFILE_FILE"
		echo "export PATH=\"\$JAVA_HOME/bin:\$PATH\"" >> "$PROFILE_FILE"

		printf "${GREEN}✅ Updated shell profile${NORMAL}\n"
		printf "${YELLOW}⚠️  Please run 'source $PROFILE_FILE' or restart your terminal to use the new Java installation${NORMAL}\n"
	else
		printf "${YELLOW}⚠️  Could not determine shell profile file. Please manually add:${NORMAL}\n"
		printf "   export JAVA_HOME=\"$JAVA_INSTALL_DIR\"\n"
		printf "   export PATH=\"\$JAVA_HOME/bin:\$PATH\"\n"
	fi

	# Set for current session
	export JAVA_HOME="$JAVA_INSTALL_DIR"
	export PATH="$JAVA_HOME/bin:$PATH"

	# Verify installation
	printf "${BLUE}🔍 Verifying Java installation...${NORMAL}\n"
	if "$JAVA_BIN/java" -version >/dev/null 2>&1; then
		local java_version_output=$("$JAVA_BIN/java" -version 2>&1)
		printf "${GREEN}✅ Java JRE installed successfully!${NORMAL}\n"
		printf "${BLUE}📋 Version info:${NORMAL}\n"
		echo "$java_version_output" | head -3
		return 0
	else
		print_error "Java installation verification failed"
		return 1
	fi
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

# Check if a version string represents a snapshot version
isSnapshotVersion() {
	local version_string="$1"
	# Check if version contains snapshot, beta, alpha, or other pre-release indicators
	if [[ "$version_string" =~ (snapshot|beta|alpha|rc|SNAPSHOT|BETA|ALPHA|RC) ]]; then
		return 0  # true - is snapshot
	else
		return 1  # false - is not snapshot
	fi
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