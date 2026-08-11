#!/bin/sh
# IMPORTANT: This script intentionally targets POSIX /bin/sh.
# Do not change the shebang back to Bash or reintroduce Bash-only syntax.
# It must remain compatible with Alpine BusyBox ash and standard /bin/sh.

# BoxLang Helpers
# A collection of helper functions for BoxLang scripts.
# Author: BoxLang Team
# Version: @build.version@
# License: Apache License, Version 2.0

###########################################################################
# Printing Functions
###########################################################################

print_info() {
    printf "${BLUE}ℹ️  $1${NORMAL}\n"
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
	if command -v "$1" >/dev/null 2>&1; then
		return 0
	fi
	return 1
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
# Verifies dependencies, installs missing command tools, and validates Java.
# With no arguments, retains the legacy prompted Java check and default tools.
# Usage: preflight_check [prompt|automatic|skip] [dep1 dep2 ...]
preflight_check() {
	printf "${BLUE}🔍 Running system requirements checks...${NORMAL}\n"
	local java_install_mode="prompt"
	local use_default_deps=true
	if [ "$1" = "prompt" ] || [ "$1" = "automatic" ] || [ "$1" = "skip" ]; then
		java_install_mode="$1"
		shift
	fi
	if [ "${1:-}" = "--" ]; then
		use_default_deps=false
		shift
	fi
	local missing_deps=""
	local required_deps="$*"

	if [ "$use_default_deps" = true ] && [ -z "$required_deps" ]; then
		required_deps="curl unzip jq"
	fi

	for dep in $required_deps; do
		if ! command_exists "$dep"; then
			missing_deps="$missing_deps $dep"
		fi
	done

	if [ -n "$missing_deps" ]; then
		local package_deps="$missing_deps"

		if [ "$(uname)" = "Darwin" ]; then
			if ! command_exists brew; then
				printf "${RED}❌ Homebrew is not installed. Please install Homebrew first.${NORMAL}\n"
				printf "${BLUE}💡 You can install Homebrew with:${NORMAL}\n"
				printf "${GREEN}   /bin/bash -c '$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)'\n"
				return 1
			fi
			# Install the dependencies using Homebrew
			printf "${BLUE}💡 Installing missing dependencies using Homebrew...${NORMAL}\n"
			for dep in $package_deps; do
				printf "${BLUE}   Installing ${dep}...${NORMAL}\n"
				if ! brew install "$dep"; then
					printf "${RED}❌ Failed to install ${dep}. Please install it manually.${NORMAL}\n"
					return 1
				fi
			done
			printf "${GREEN}✅ All dependencies installed successfully!${NORMAL}\n"
		elif [ "$(uname)" = "Linux" ]; then
			printf "${BLUE}💡 Installing missing dependencies using system package manager...${NORMAL}\n"

			# Determine if we need sudo based on current user privileges
			local use_sudo=""
			if [ "$EUID" -ne 0 ]; then
				use_sudo="sudo"
				printf "${BLUE}🔐 Running as user (EUID=$EUID), will use sudo${NORMAL}\n"
			else
				printf "${BLUE}👑 Running as root (EUID=$EUID), no sudo needed${NORMAL}\n"
			fi

			if command_exists apt-get; then
				printf "${BLUE}   Updating package list...${NORMAL}\n"
				printf "${BLUE}🔍 Executing: $use_sudo apt update${NORMAL}\n"
				if ! $use_sudo apt update; then
					printf "${RED}❌ Failed to update package list with apt.${NORMAL}\n"
					return 1
				fi
				printf "${BLUE}   Installing dependencies: ${package_deps}...${NORMAL}\n"
				printf "${BLUE}🔍 Executing: $use_sudo apt install -y ${package_deps}${NORMAL}\n"
				if ! $use_sudo apt install -y $package_deps; then
					printf "${RED}❌ Failed to install dependencies with apt. Please install them manually.${NORMAL}\n"
					return 1
				fi
			elif command_exists apk; then
				printf "${BLUE}   Updating package list...${NORMAL}\n"
				printf "${BLUE}🔍 Executing: $use_sudo apk update${NORMAL}\n"
				if ! $use_sudo apk update; then
					printf "${RED}❌ Failed to update package list with apk.${NORMAL}\n"
					return 1
				fi
				printf "${BLUE}   Installing dependencies: ${package_deps}...${NORMAL}\n"
				printf "${BLUE}🔍 Executing: $use_sudo apk add ${package_deps}${NORMAL}\n"
				if ! $use_sudo apk add $package_deps; then
					printf "${RED}❌ Failed to install dependencies with apk. Please install them manually.${NORMAL}\n"
					return 1
				fi
			elif command_exists yum; then
				printf "${BLUE}   Installing dependencies with yum...${NORMAL}\n"
				if ! $use_sudo yum install -y $package_deps; then
					printf "${RED}❌ Failed to install dependencies with yum. Please install them manually.${NORMAL}\n"
					return 1
				fi
			elif command_exists dnf; then
				printf "${BLUE}   Installing dependencies with dnf...${NORMAL}\n"
				if ! $use_sudo dnf install -y $package_deps; then
					printf "${RED}❌ Failed to install dependencies with dnf. Please install them manually.${NORMAL}\n"
					return 1
				fi
			elif command_exists pacman; then
				printf "${BLUE}   Installing dependencies with pacman...${NORMAL}\n"
				if ! $use_sudo pacman -S --noconfirm $package_deps; then
					printf "${RED}❌ Failed to install dependencies with pacman. Please install them manually.${NORMAL}\n"
					return 1
				fi
			else
				printf "${RED}❌ No supported package manager found. Please install dependencies manually: ${package_deps}${NORMAL}\n"
				return 1
			fi
			printf "${GREEN}✅ All dependencies installed successfully!${NORMAL}\n"
		fi
	fi

	if [ "$java_install_mode" != "skip" ]; then
		ensure_java "$java_install_mode"
	fi
}

###########################################################################
# Ensure Java 21 is available for BoxLang.
# Mode: prompt (default), automatic, or skip.
###########################################################################
ensure_java() {
	local java_install_mode="${1:-prompt}"

	if check_java_version; then
		return 0
	fi

	printf "${RED}🔴  Error: Java 21 or higher is required to run BoxLang${NORMAL}\n"

	case "$java_install_mode" in
		automatic)
			printf "${BLUE}📥 Proceeding with automatic Java installation...${NORMAL}\n"
			if install_java; then
				printf "${GREEN}✅ Java installation completed successfully!${NORMAL}\n"
				return 0
			fi
			printf "${RED}❌ Automatic Java installation failed.${NORMAL}\n"
			;;
		prompt)
			if [ "${NON_INTERACTIVE:-false}" != true ] && [ -r /dev/tty ]; then
				printf "${YELLOW}Would you like to automatically install Java 21 JRE? (y/N)${NORMAL} "
				read -r response < /dev/tty
				case "$response" in
					[yY][eE][sS]|[yY])
						printf "${BLUE}📥 Proceeding with automatic Java installation...${NORMAL}\n"
						if install_java; then
							printf "${GREEN}✅ Java installation completed successfully!${NORMAL}\n"
							return 0
						fi
						printf "${RED}❌ Automatic Java installation failed.${NORMAL}\n"
						;;
				esac
			fi
			printf "${YELLOW}💡 Java 21 must be installed manually before running BoxLang.${NORMAL}\n"
			;;
		skip)
			printf "${YELLOW}💡 Java 21 must be installed manually before running BoxLang.${NORMAL}\n"
			;;
		*)
			printf "${RED}❌ Invalid Java installation mode: ${java_install_mode}${NORMAL}\n"
			;;
	esac

	return 1
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

	# Try all Java executables on PATH before fixed locations.
	local java_candidates=""
	local path_entry
	local old_ifs="$IFS"
	IFS=:
	for path_entry in $PATH; do
		if [ -x "${path_entry:-.}/java" ]; then
			java_candidates="$java_candidates ${path_entry:-.}/java"
		fi
	done
	IFS="$old_ifs"
	java_candidates="$java_candidates ${JAVA_HOME:-}/bin/java /usr/bin/java /usr/local/bin/java /opt/homebrew/bin/java /Library/Java/JavaVirtualMachines/*/Contents/Home/bin/java /opt/java/openjdk-21-jre/bin/java"

	# If running under sudo, try to get the original user's environment
	if [ -n "${SUDO_USER:-}" ]; then
		printf "${YELLOW}🛡️ Detected sudo execution. Checking Java from original user context...${NORMAL}\n"

		# Try to get Java from the original user's environment
		local user_java_cmd=$(sudo -u "${SUDO_USER}" -i bash -c 'command -v java 2>/dev/null' || echo "")
		if [ -n "$user_java_cmd" ]; then
			java_candidates="$user_java_cmd $java_candidates"
		fi

		# Try to get JAVA_HOME from original user
		local user_java_home=$(sudo -u "${SUDO_USER}" -i bash -c 'echo $JAVA_HOME 2>/dev/null' || echo "")
		if [ -n "$user_java_home" ] && [ -f "$user_java_home/bin/java" ]; then
			java_candidates="$user_java_home/bin/java $java_candidates"
		fi
	fi

	# Test each candidate
	for candidate in $java_candidates; do
		# Handle glob patterns
		case "$candidate" in
		*"*")
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
			;;
		*)
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
			;;
		esac
	done

	return 1
}

###########################################################################
# Java Installation Function
###########################################################################
install_java() {

	# Detect OS and architecture
	local OS=$(uname -s)
	local ARCH=$(uname -m)
	local JRE_VERSION="21.0.8+9"
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

	# Convert JRE_VERSION to URL format (replace + with %2B for URL encoding)
	local JRE_URL_VERSION=$(echo "$JRE_VERSION" | sed 's/+/%2B/g')
	# Convert JRE_VERSION to filename format (replace + with _ for filenames)
	local JRE_FILE_VERSION=$(echo "$JRE_VERSION" | sed 's/+/_/g')

	# Set URLs and paths based on OS
	case "$OS" in
		Darwin)
			INSTALL_BASE="/Library/Java/JavaVirtualMachines"
			if [ "$ARCH" = "aarch64" ]; then
				JRE_URL="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${JRE_URL_VERSION}/OpenJDK21U-jre_aarch64_mac_hotspot_${JRE_FILE_VERSION}.tar.gz"
				JRE_FILENAME="OpenJDK21U-jre_aarch64_mac_hotspot_${JRE_FILE_VERSION}.tar.gz"
			else
				JRE_URL="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${JRE_URL_VERSION}/OpenJDK21U-jre_x64_mac_hotspot_${JRE_FILE_VERSION}.tar.gz"
				JRE_FILENAME="OpenJDK21U-jre_x64_mac_hotspot_${JRE_FILE_VERSION}.tar.gz"
			fi
			JAVA_INSTALL_DIR="$INSTALL_BASE/openjdk-21-jre"
			;;
		Linux)
			INSTALL_BASE="/opt/java"

			# Detect if this is Alpine Linux (musl-based)
			local LIBC_TYPE="glibc"
			if [ -f /etc/alpine-release ]; then
				LIBC_TYPE="musl"
				printf "${BLUE}🏔️  Detected Alpine Linux (musl libc)${NORMAL}\n"
			elif command_exists ldd && ldd --version 2>&1 | grep -q musl; then
				LIBC_TYPE="musl"
				printf "${BLUE}🔍 Detected musl libc${NORMAL}\n"
			fi

			# Set JRE URLs based on architecture and libc
			if [ "$ARCH" = "aarch64" ]; then
				if [ "$LIBC_TYPE" = "musl" ]; then
					JRE_URL="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${JRE_URL_VERSION}/OpenJDK21U-jre_aarch64_alpine-linux_hotspot_${JRE_FILE_VERSION}.tar.gz"
					JRE_FILENAME="OpenJDK21U-jre_aarch64_alpine-linux_hotspot_${JRE_FILE_VERSION}.tar.gz"
				else
					JRE_URL="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${JRE_URL_VERSION}/OpenJDK21U-jre_aarch64_linux_hotspot_${JRE_FILE_VERSION}.tar.gz"
					JRE_FILENAME="OpenJDK21U-jre_aarch64_linux_hotspot_${JRE_FILE_VERSION}.tar.gz"
				fi
			else
				if [ "$LIBC_TYPE" = "musl" ]; then
					JRE_URL="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${JRE_URL_VERSION}/OpenJDK21U-jre_x64_alpine-linux_hotspot_${JRE_FILE_VERSION}.tar.gz"
					JRE_FILENAME="OpenJDK21U-jre_x64_alpine-linux_hotspot_${JRE_FILE_VERSION}.tar.gz"
				else
					JRE_URL="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${JRE_URL_VERSION}/OpenJDK21U-jre_x64_linux_hotspot_${JRE_FILE_VERSION}.tar.gz"
					JRE_FILENAME="OpenJDK21U-jre_x64_linux_hotspot_${JRE_FILE_VERSION}.tar.gz"
				fi
			fi
			JAVA_INSTALL_DIR="$INSTALL_BASE/openjdk-21-jre"
			;;
		*)
			print_error "Unsupported operating system: $OS"
			return 1
			;;
	esac

	printf "%s📍 Detected: %s (%s)%s\n" "${BLUE}" "${OS}" "${ARCH}" "${NORMAL}"
	printf "📥 JRE URL [%s]\n" "${JRE_URL}"
	printf "📦 JRE Filename [%s]\n" "${JRE_FILENAME}"
	printf "📂 Installing to [%s]\n" "${JAVA_INSTALL_DIR}"
	printf "${NORMAL}\n"

	# Create temporary directory
	local TEMP_DIR=$(mktemp -d)
	local DOWNLOAD_PATH="$TEMP_DIR/$JRE_FILENAME"

	# Download JRE
	printf "${BLUE}📥 Downloading JRE...${NORMAL}\n"
	if ! curl -L --progress-bar "$JRE_URL" -o "$DOWNLOAD_PATH"; then
		print_error "Failed to download JRE"
		rm -rf "$TEMP_DIR"
		return 1
	fi

	printf "${GREEN}✅ Downloaded JRE successfully${NORMAL}\n"

	# Create installation directory (requires elevated privileges on most systems)
	printf "${BLUE}📁 Creating installation directory: $JAVA_INSTALL_DIR${NORMAL}\n"
	if [ "$OS" = "Darwin" ] || [ "$OS" = "Linux" ]; then
		# Check if we need sudo or if running as root
		local use_sudo=""
		if [ "$EUID" -ne 0 ] && command_exists sudo; then
			use_sudo="sudo"
		fi

		if ! $use_sudo mkdir -p "$JAVA_INSTALL_DIR"; then
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
		$use_sudo rm -rf "$JAVA_INSTALL_DIR"
	fi

	# Move extracted content to final location
	printf "${BLUE}📋 Installing JRE to $JAVA_INSTALL_DIR...${NORMAL}\n"
	if ! $use_sudo mv "$EXTRACTED_DIR" "$JAVA_INSTALL_DIR"; then
		print_error "Failed to move JRE to installation directory"
		rm -rf "$TEMP_DIR"
		return 1
	fi

	# Set permissions
	$use_sudo chmod -R 755 "$JAVA_INSTALL_DIR"

	# Clean up temporary files
	rm -rf "$TEMP_DIR"

	# Set up environment variables
	local JAVA_BIN="$JAVA_INSTALL_DIR/bin"
	local PROFILE_FILE=$(get_shell_profile_file)

	if [ -n "$PROFILE_FILE" ]; then
		printf "${BLUE}⚙️  Updating shell profile: $PROFILE_FILE${NORMAL}\n"

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
# Shell Profile Detection Helper
###########################################################################
# Detects and returns the appropriate shell profile file for the current environment
# Creates the profile file if it doesn't exist
# Returns the profile file path via echo
get_shell_profile_file() {
	local profile_file=""
	local current_shell="${SHELL##*/}"

	# Detect if running in WSL
	local is_wsl=false
	if [ -f /proc/version ] && grep -q Microsoft /proc/version; then
		is_wsl=true
		printf "${BLUE}💡 WSL environment detected${NORMAL}\n"
	fi

	# Determine the profile file based on shell and system
	if [ "$current_shell" = "zsh" ]; then
		if [ -f "$HOME/.zshrc" ]; then
			profile_file="$HOME/.zshrc"
		else
			profile_file="$HOME/.zshrc"
			touch "$profile_file"
		fi
	elif [ "$current_shell" = "bash" ]; then
		if [ -f "$HOME/.bash_profile" ]; then
			profile_file="$HOME/.bash_profile"
		elif [ -f "$HOME/.bashrc" ]; then
			profile_file="$HOME/.bashrc"
		else
			# Create .bashrc for new installations
			profile_file="$HOME/.bashrc"
			touch "$profile_file"
			# On macOS, also ensure .bash_profile sources .bashrc
			if [ "$(uname)" = "Darwin" ] && [ ! -f "$HOME/.bash_profile" ]; then
				echo '# Source .bashrc if it exists' > "$HOME/.bash_profile"
				echo '[ -f ~/.bashrc ] && source ~/.bashrc' >> "$HOME/.bash_profile"
			fi
		fi
	elif [ "$current_shell" = "fish" ]; then
		profile_file="$HOME/.config/fish/config.fish"
		mkdir -p "$HOME/.config/fish"
		touch "$profile_file"
	else
		# Fallback to .profile for other shells (including Alpine's ash)
		profile_file="$HOME/.profile"
		touch "$profile_file"
	fi

	# Return the profile file path
	echo "$profile_file"
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
	case "$version_string" in
		*snapshot*|*beta*|*alpha*|*rc*|*SNAPSHOT*|*BETA*|*ALPHA*|*RC*) return 0 ;;
		*) return 1 ;;
	esac
}

# Compare two semantic versions (Major.Minor.Patch)
# Returns: 0 if equal, 1 if first > second, 2 if first < second
compare_versions() {
	local version1="$1"
	local version2="$2"

	# Compare major, minor, patch
	for i in 0 1 2; do
		local field=$((i + 1))
		local v1_part=$(printf '%s\n' "$version1" | awk -F. -v field="$field" '{ print ($field == "" ? 0 : $field) }')
		local v2_part=$(printf '%s\n' "$version2" | awk -F. -v field="$field" '{ print ($field == "" ? 0 : $field) }')

		if [ "$v1_part" -gt "$v2_part" ]; then
			return 1  # version1 > version2
		elif [ "$v1_part" -lt "$v2_part" ]; then
			return 2  # version1 < version2
		fi
	done

	return 0  # versions are equal
}