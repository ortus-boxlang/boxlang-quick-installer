#!/bin/bash

## BOXLANG INSTALLER

###########################################################################
# Global Color Variables
###########################################################################
# Initialize colors globally so all functions can use them
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
	local missing_deps=()

	command -v curl >/dev/null 2>&1 || missing_deps+=("curl")
	command -v unzip >/dev/null 2>&1 || missing_deps+=("unzip")
	command -v jq >/dev/null 2>&1 || missing_deps+=("jq")

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
			if command -v apt-get >/dev/null 2>&1; then
				printf "${BLUE}💡 On Ubuntu/Debian, install with:${NORMAL}\n"
				printf "   sudo apt update && sudo apt install ${missing_deps[*]}\n"
			elif command -v yum >/dev/null 2>&1; then
				printf "${BLUE}💡 On RHEL/CentOS, install with:${NORMAL}\n"
				printf "   sudo yum install ${missing_deps[*]}\n"
			elif command -v dnf >/dev/null 2>&1; then
				printf "${BLUE}💡 On Fedora, install with:${NORMAL}\n"
				printf "   sudo dnf install ${missing_deps[*]}\n"
			elif command -v pacman >/dev/null 2>&1; then
				printf "${BLUE}💡 On Arch Linux, install with:${NORMAL}\n"
				printf "   sudo pacman -S ${missing_deps[*]}\n"
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
		printf "${YELLOW}Detected sudo execution. Checking Java from original user context...${NORMAL}\n"

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
			if command -v "$candidate" >/dev/null 2>&1 || [ -x "$candidate" ]; then
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

# Get current installed BoxLang version
get_current_version() {
	local current_version=""

	# Try to find BoxLang in common locations
	local boxlang_candidates=(
		"boxlang"                    # In PATH
		"/usr/local/bin/boxlang"     # System install
		"$HOME/.local/bin/boxlang"   # User install
	)

	for candidate in "${boxlang_candidates[@]}"; do
		if command -v "$candidate" >/dev/null 2>&1 || [ -x "$candidate" ]; then
			local version_output=$("$candidate" --version 2>/dev/null || echo "")
			if [ -n "$version_output" ]; then
				current_version=$(extract_semantic_version "$version_output")
				if [ -n "$current_version" ]; then
					echo "$current_version"
					return 0
				fi
			fi
		fi
	done

	return 1
}

# Get latest available BoxLang version from remote
get_latest_version() {
	local version_url="https://downloads.ortussolutions.com/ortussolutions/boxlang/version-latest.properties"
	local version_info

	# Download version info
	version_info=$(curl -s "$version_url" 2>/dev/null || echo "")
	if [ -z "$version_info" ]; then
		return 1
	fi

	# Extract version from properties file (format: version=1.2.3+buildId)
	local latest_version=$(echo "$version_info" | grep "^version=" | cut -d'=' -f2 | head -n1)
	if [ -n "$latest_version" ]; then
		extract_semantic_version "$latest_version"
		return 0
	fi

	return 1
}

# Check for updates and optionally prompt for installation
check_for_updates() {
	printf "${BLUE}🔍 Checking for BoxLang updates...${NORMAL}\n"

	# Get current version
	local current_version
	current_version=$(get_current_version)
	if [ $? -ne 0 ] || [ -z "$current_version" ]; then
		printf "${YELLOW}⚠️  BoxLang is not currently installed${NORMAL}\n"
		current_version="0.0.0"
	fi

	# Get latest version
	local latest_version
	latest_version=$(get_latest_version)
	if [ $? -ne 0 ] || [ -z "$latest_version" ]; then
		printf "${RED}❌ Failed to fetch latest version information${NORMAL}\n"
		printf "${YELLOW}Please check your internet connection and try again${NORMAL}\n"
		return 1
	fi

	printf "${GREEN}Current version: ${current_version}${NORMAL}\n"
	printf "${GREEN}Latest version:  ${latest_version}${NORMAL}\n"

	# Compare versions
	compare_versions "$current_version" "$latest_version"
	local comparison_result=$?

	case $comparison_result in
		0)
			printf "${GREEN}✅ You have the latest version of BoxLang${NORMAL}\n"
			return 0
			;;
		1)
			printf "${BLUE}🔄 You have a newer version than the latest release${NORMAL}\n"
			printf "${YELLOW}This might be a development or snapshot build${NORMAL}\n"
			return 0
			;;
		2)
			printf "${YELLOW}🆙 A newer version of BoxLang is available!${NORMAL}\n"
			printf "${BLUE}Would you like to update to version ${latest_version}? [Y/n] ${NORMAL}"
			read -r response < /dev/tty
			case "$response" in
				[nN][oO]|[nN])
					printf "${YELLOW}Update cancelled${NORMAL}\n"
					return 0
					;;
				*)
					printf "${GREEN}Starting update to BoxLang ${latest_version}...${NORMAL}\n"
					# Call main installation function with latest version
					exec "$0" "latest"
					;;
			esac
			;;
	esac
}

###########################################################################
# PATH Check and Auto-Update Function
###########################################################################
check_or_set_path() {
	local bin_dir="$1"

	# Check if path is already in PATH
	if echo "$PATH" | grep -q "$bin_dir"; then
		printf "${GREEN}✅ $bin_dir is already in your PATH${NORMAL}\n"
		return 0
	fi

	printf "${YELLOW}⚠️  $bin_dir is not in your PATH${NORMAL}\n"

	# Detect the appropriate shell profile file
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
		# Fallback to .profile for other shells
		profile_file="$HOME/.profile"
		touch "$profile_file"
	fi

	# Check if the PATH export already exists in the profile
	local path_export="export PATH=\"$bin_dir:\$PATH\""
	if [ -f "$profile_file" ] && grep -Fq "$bin_dir" "$profile_file"; then
		printf "${GREEN}✅ PATH entry already exists in $profile_file${NORMAL}\n"
		return 0
	fi

	# Ask user for permission to auto-update
	printf "${BLUE}❓Would you like to automatically add $bin_dir to your PATH? [Y/n] ${NORMAL}"
	read -r response < /dev/tty
	case "$response" in
		[nN][oO]|[nN])
			printf "${YELLOW}Skipping automatic PATH update${NORMAL}\n"
			printf "${BLUE}Manually add this to your shell profile ($profile_file):${NORMAL}\n"
			if [ "$current_shell" = "fish" ]; then
				printf "${CYAN}set -gx PATH $bin_dir \$PATH${NORMAL}\n\n"
			else
				printf "${CYAN}$path_export${NORMAL}\n\n"
			fi
			return 0
			;;
		*)
			# Default to yes
			;;
	esac

	# Add PATH to the profile file
	printf "${BLUE}Adding $bin_dir to PATH in $profile_file...${NORMAL}\n"

	{
		echo ""
		echo "# Added by BoxLang installer on $(date)"
		if [ "$current_shell" = "fish" ]; then
			echo "set -gx PATH $bin_dir \$PATH"
		else
			echo "$path_export"
		fi
	} >> "$profile_file"

	printf "${GREEN}✅ Successfully added $bin_dir to PATH in $profile_file${NORMAL}\n"

	# Special handling for WSL
	if [ "$is_wsl" = true ]; then
		printf "${BLUE}💡 WSL Note: You may need to restart your terminal or run:${NORMAL}\n"
		if [ "$current_shell" = "fish" ]; then
			printf "${CYAN}source $profile_file${NORMAL}\n"
		else
			printf "${CYAN}source $profile_file${NORMAL}\n"
		fi
	else
		printf "${BLUE}💡 Restart your terminal or run the following to use the new PATH:${NORMAL}\n"
		if [ "$current_shell" = "fish" ]; then
			printf "${CYAN}source $profile_file${NORMAL}\n"
		else
			printf "${CYAN}source $profile_file${NORMAL}\n"
		fi
	fi

	# Update current session PATH
	export PATH="$bin_dir:$PATH"
	printf "${GREEN}✅ PATH updated for current session${NORMAL}\n"
}

###########################################################################
# CommandBox Installation Check and Install Function
###########################################################################
check_and_install_commandbox() {
	local bin_dir="$1"

	printf "${BLUE}🔍 Checking for CommandBox...${NORMAL}\n"

	# Check if CommandBox is already available
	if command -v box >/dev/null 2>&1; then
		printf "${GREEN}✅ CommandBox is already installed and available${NORMAL}\n"
		return 0
	fi

	printf "${YELLOW}⚠️  CommandBox is not installed${NORMAL}\n"
	printf "${BLUE}💡 CommandBox is the Package Manager for BoxLang®${NORMAL}\n"
	printf "${BLUE}💡 It allows you to easily manage BoxLang modules, dependencies, start servlet containers, and more${NORMAL}\n\n"

	# Ask user if they want to install CommandBox
	printf "${BLUE}❓ Would you like to install CommandBox? [Y/n] ${NORMAL}"
	read -r response < /dev/tty
	case "$response" in
		[nN][oO]|[nN])
			printf "${YELLOW}Skipping CommandBox installation${NORMAL}\n"
			printf "${BLUE}💡 You can install CommandBox later from: https://commandbox.ortusbooks.com/setup/installation${NORMAL}\n"
			return 0
			;;
		*)
			# Default to yes
			;;
	esac

	printf "${BLUE}📦 Installing CommandBox...${NORMAL}\n"

	# The universal binary for mac/linux is available at the following URL
	local commandbox_url="https://www.ortussolutions.com/parent/download/commandbox/type/bin"
	local commandbox_filename="commandbox.zip"

	# Download CommandBox
	printf "${BLUE}Downloading CommandBox from ${commandbox_url}...${NORMAL}\n"
	if ! env curl -L --progress-bar -o "/tmp/${commandbox_filename}" "${commandbox_url}"; then
		printf "${RED}❌ Failed to download CommandBox${NORMAL}\n"
		printf "${BLUE}💡 Please manually install CommandBox from: https://commandbox.ortusbooks.com/setup/installation${NORMAL}\n"
		return 1
	fi

	# Extract CommandBox
	printf "${BLUE}Extracting CommandBox...${NORMAL}\n"
	if ! unzip -o "/tmp/${commandbox_filename}" -d "/tmp/commandbox/"; then
		printf "${RED}❌ Failed to extract CommandBox${NORMAL}\n"
		return 1
	fi

	# Install CommandBox
	printf "${BLUE}Installing CommandBox to ${bin_dir}/box...${NORMAL}\n"
	mv "/tmp/commandbox/box" "${bin_dir}/box"
	chmod 755 "${bin_dir}/box"


	# Cleanup
	rm -rf "/tmp/${commandbox_filename}" "/tmp/commandbox/"

	printf "${GREEN}✅ CommandBox installed successfully${NORMAL}\n"
	return 0
}

###########################################################################
# Installation Verification Function
###########################################################################
verify_installation() {
	local bin_dir="$1"
	printf "${BLUE}🔍 Verifying installation...${NORMAL}\n"

	# Test basic functionality
	if ! "${bin_dir}/boxlang" --version >/dev/null 2>&1; then
		printf "${RED}❌ BoxLang installation verification failed${NORMAL}\n"
		return 1
	fi

	# Check symlinks
	if [ ! -L "${bin_dir}/bx" ]; then
		printf "${YELLOW}⚠️  Symbolic link 'bx' was not created properly${NORMAL}\n"
	fi

	if [ ! -L "${bin_dir}/bx-miniserver" ]; then
		printf "${YELLOW}⚠️  Symbolic link 'bx-miniserver' was not created properly${NORMAL}\n"
	fi

	# Check helper scripts
	if [ ! -x "${bin_dir}/install-bx-module" ]; then
		printf "${YELLOW}⚠️  Helper script 'install-bx-module' was not installed properly${NORMAL}\n"
	fi

	printf "${GREEN}✅ Installation verified successfully${NORMAL}"
	return 0
}

###########################################################################
# Uninstall Function
###########################################################################
uninstall_boxlang() {
	printf "${YELLOW}🗑️  Uninstalling BoxLang...${NORMAL}\n"

	# Remove binaries and symlinks
	printf "${BLUE}Removing binaries and symlinks...${NORMAL}\n"
	rm -fv /usr/local/bin/boxlang
	rm -fv /usr/local/bin/bx
	rm -fv /usr/local/bin/boxlang-miniserver
	rm -fv /usr/local/bin/bx-miniserver
	rm -fv /usr/local/bin/install-bx-module
	rm -fv /usr/local/bin/install-boxlang

	# Remove JAR files
	printf "${BLUE}Removing JAR files...${NORMAL}\n"
	rm -fv /usr/local/lib/boxlang-*.jar

	# Also check user-local installation
	if [ -d "$HOME/.local/bin" ]; then
		printf "${BLUE}Checking user-local installation...${NORMAL}\n"
		rm -fv "$HOME/.local/bin/boxlang"
		rm -fv "$HOME/.local/bin/bx"
		rm -fv "$HOME/.local/bin/boxlang-miniserver"
		rm -fv "$HOME/.local/bin/bx-miniserver"
		rm -fv "$HOME/.local/bin/install-bx-module"
		rm -fv "$HOME/.local/bin/install-boxlang"
	fi

	if [ -d "$HOME/.local/lib" ]; then
		rm -fv "$HOME/.local/lib/boxlang-*.jar"
	fi

	printf "${GREEN}✅ BoxLang uninstalled successfully${NORMAL}\n"
	printf "${BLUE}💡 BoxLang Home directory (~/.boxlang) was preserved${NORMAL}\n"
	printf "${BLUE}💡 To remove it completely, run: rm -rf ~/.boxlang${NORMAL}\n"
}

###########################################################################
# Help Function
###########################################################################
show_help() {
	printf "${GREEN}📦 BoxLang® Quick Installer${NORMAL}\n\n"
	printf "${YELLOW}This script installs the BoxLang® runtime and tools on your system.${NORMAL}\n\n"
	printf "${BOLD}Usage:${NORMAL}\n"
	printf "  install-boxlang.sh [version] [options]\n"
	printf "  install-boxlang.sh --help\n\n"
	printf "${BOLD}Arguments:${NORMAL}\n"
	printf "  [version]         (Optional) Specify which version to install\n"
	printf "                    - 'latest' (default): Install the latest stable release\n"
	printf "                    - 'snapshot': Install the latest development snapshot\n"
	printf "                    - '1.2.0': Install a specific version number\n\n"
	printf "${BOLD}Options:${NORMAL}\n"
	printf "  --help, -h        Show this help message\n"
	printf "  --uninstall       Remove BoxLang from the system\n"
	printf "  --check-update    Check if a newer version is available\n"
	printf "  --system          Force system-wide installation (requires sudo)\n\n"
	printf "${BOLD}Examples:${NORMAL}\n"
	printf "  install-boxlang.sh\n"
	printf "  install-boxlang.sh latest\n"
	printf "  install-boxlang.sh snapshot\n"
	printf "  install-boxlang.sh 1.2.0\n"
	printf "  install-boxlang.sh --uninstall\n"
	printf "  install-boxlang.sh --check-update\n"
	printf "  sudo install-boxlang.sh --system\n\n"
	printf "${BOLD}Installation Methods:${NORMAL}\n"
	printf "  🌐 One-liner: ${GREEN}curl -fsSL https://boxlang.io/install.sh | bash${NORMAL}\n"
	printf "  📦 With version: ${GREEN}curl -fsSL https://boxlang.io/install.sh | bash -s -- snapshot${NORMAL}\n\n"
	printf "${BOLD}What this installer does:${NORMAL}\n"
	printf "  ✅ Checks for Java 21+ requirement\n"
	printf "  ✅ Downloads BoxLang® runtime and MiniServer\n"
	printf "  ✅ Installs to /usr/local/bin and /usr/local/lib (or ~/.local/ for user install)\n"
	printf "  ✅ Creates symbolic links: bx → boxlang, bx-miniserver → boxlang-miniserver\n"
	printf "  ✅ Installs helper scripts: install-bx-module, install-boxlang\n"
	printf "  ✅ Optionally installs CommandBox (BoxLang Package Manager)\n"
	printf "  ✅ Sets up BoxLang® Home at ~/.boxlang\n"
	printf "  ✅ Removes any previous versions\n"
	printf "  ✅ Verifies installation\n"
	printf "  ✅ Checks for updates with --check-update flag\n\n"
	printf "${BOLD}Requirements:${NORMAL}\n"
	printf "  - Java 21 or higher (OpenJDK or Oracle JDK)\n"
	printf "  - curl (for downloading)\n"
	printf "  - unzip (for extracting)\n"
	printf "  - sudo privileges (for system-wide installation)\n\n"
	printf "${BOLD}Installation Paths:${NORMAL}\n"
	printf "  📁 System: /usr/local/bin/ and /usr/local/lib/\n"
	printf "  📁 User: ~/.local/bin/ and ~/.local/lib/\n"
	printf "  📁 BoxLang Home: ~/.boxlang/\n\n"
	printf "${BOLD}After Installation:${NORMAL}\n"
	printf "  🚀 Start REPL: ${GREEN}boxlang${NORMAL} or ${GREEN}bx${NORMAL}\n"
	printf "  🌐 Start MiniServer: ${GREEN}boxlang-miniserver${NORMAL} or ${GREEN}bx-miniserver${NORMAL}\n"
	printf "  📦 Install modules: ${GREEN}install-bx-module <module-name>${NORMAL}\n"
	printf "  📦 Package Manager: ${GREEN}box${NORMAL} (if CommandBox was installed)\n"
	printf "  🔄 Update BoxLang: ${GREEN}install-boxlang latest${NORMAL}\n"
	printf "  🔍 Check for updates: ${GREEN}install-boxlang --check-update${NORMAL}\n\n"
	printf "${BOLD}Notes:${NORMAL}\n"
	printf "  - Run with sudo for system-wide installation: ${GREEN}sudo install-boxlang.sh${NORMAL}\n"
	printf "  - User installation doesn't require sudo and installs to ~/.local/\n"
	printf "  - Java detection works even when run with sudo\n"
	printf "  - Previous versions are automatically removed before installation\n"
	printf "  - BoxLang® is open-source under Apache 2.0 License\n\n"
	printf "${BOLD}More Information:${NORMAL}\n"
	printf "  🌐 Website: https://boxlang.io\n"
	printf "  📖 Documentation: https://boxlang.io/docs\n"
	printf "  💾 GitHub: https://github.com/ortus-boxlang/boxlang\n"
	printf "  💬 Community: https://boxlang.io/community\n"
}

###########################################################################
# Parse command line arguments before main execution
###########################################################################

# Initialize colors at script startup
setup_colors

# Check for help argument early to avoid any setup overhead
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
	show_help
	exit 0
fi

# Check for uninstall argument
if [ "$1" = "--uninstall" ]; then
	uninstall_boxlang
	exit 0
fi

# Check for check-update argument
if [ "$1" = "--check-update" ]; then
	if ! preflight_check; then
		exit 1
	fi
	check_for_updates
	exit 0
fi

main() {
	# Only enable exit-on-error after the non-critical colorization stuff,
	# which may fail on systems lacking tput or terminfo
	set -e

	# Set the target version
	local TARGET_VERSION=${1}

	###########################################################################
	# Setup Installation Directories
	###########################################################################
	local DESTINATION="/usr/local/"
	local DESTINATION_LIB="/usr/local/lib"
	local DESTINATION_BIN="/usr/local/bin"

	# Support user-local installation if not running as root and not explicitly system install
	if [ "$EUID" -ne 0 ] && [ "$1" != "--system" ]; then
		printf "${YELLOW}Installing to user directory (~/.local) since not running as root${NORMAL}\n"
		printf "${BLUE}💡 Use 'sudo install-boxlang.sh' for system-wide installation${NORMAL}\n\n"
		DESTINATION="$HOME/.local/"
		DESTINATION_BIN="$HOME/.local/bin"
		DESTINATION_LIB="$HOME/.local/lib"
		mkdir -p "$DESTINATION_BIN" "$DESTINATION_LIB"
	fi

	###########################################################################
	# Pre-flight Checks
	###########################################################################
	printf "${BLUE}🔍 Running pre-flight checks...${NORMAL}\n"

	if ! preflight_check; then
		exit 1
	fi

	###########################################################################
	# Setup Global Variables
	###########################################################################
	local SNAPSHOT_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang/boxlang-snapshot.zip"
	local SNAPSHOT_URL_MINISERVER="https://downloads.ortussolutions.com/ortussolutions/boxlang-runtimes/boxlang-miniserver/boxlang-miniserver-snapshot.zip"
    local LATEST_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang/boxlang-latest.zip"
	local LATEST_URL_MINISERVER="https://downloads.ortussolutions.com/ortussolutions/boxlang-runtimes/boxlang-miniserver/boxlang-miniserver-latest.zip"
	local VERSIONED_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang/${TARGET_VERSION}/boxlang-${TARGET_VERSION}.zip"
	local VERSIONED_URL_MINISERVER="https://downloads.ortussolutions.com/ortussolutions/boxlang-runtimes/boxlang-miniserver/${TARGET_VERSION}/boxlang-miniserver-${TARGET_VERSION}.zip"

	###########################################################################
	# Determine which URL to use
	###########################################################################
	if [ "${TARGET_VERSION}" = "snapshot" ]; then
		local DOWNLOAD_URL=${SNAPSHOT_URL}
		local DOWNLOAD_URL_MINISERVER=${SNAPSHOT_URL_MINISERVER}
	elif [ "${TARGET_VERSION}" = "latest" ]; then
        local DOWNLOAD_URL=${LATEST_URL}
        local DOWNLOAD_URL_MINISERVER=${LATEST_URL_MINISERVER}
    else
		local DOWNLOAD_URL=${VERSIONED_URL}
		local DOWNLOAD_URL_MINISERVER=${VERSIONED_URL_MINISERVER}
	fi

	###########################################################################
	# Java Version Check
	###########################################################################
	printf "${BLUE}🔍 Checking Java installation...${NORMAL}\n"

	if ! check_java_version; then
		printf "${RED}❌ Error: Java 21 or higher is required to run BoxLang${NORMAL}\n"
		printf "${YELLOW}Please install Java 21+ and ensure it's in your PATH.${NORMAL}\n"
		printf "${YELLOW}Recommended: OpenJDK 21+ or Oracle JRE 21+${NORMAL}\n"

		if [ "$(uname)" = "Darwin" ]; then
			printf "${BLUE}💡 On macOS, you can install Java using:${NORMAL}\n"
			printf "   brew install openjdk@21\n"
			printf "   or download from: https://adoptium.net/\n"
			if command -v sdk >/dev/null 2>&1; then
				printf "   or with SDKMAN: sdk install java 21-tem\n"
			fi
		elif [ "$(uname)" = "Linux" ]; then
			if command -v apt-get >/dev/null 2>&1; then
				printf "${BLUE}💡 On Ubuntu/Debian, you can install Java using:${NORMAL}\n"
				printf "   sudo apt update && sudo apt install openjdk-21-jre\n"
			elif command -v yum >/dev/null 2>&1; then
				printf "${BLUE}💡 On RHEL/CentOS/Fedora, you can install Java using:${NORMAL}\n"
				printf "   sudo yum install java-21-openjdk\n"
			elif command -v dnf >/dev/null 2>&1; then
				printf "${BLUE}💡 On Fedora, you can install Java using:${NORMAL}\n"
				printf "   sudo dnf install java-21-openjdk\n"
			else
				printf "${BLUE}💡 On Linux, you can install Java using your package manager or:${NORMAL}\n"
				printf "   Download from: https://adoptium.net/\n"
			fi
			if command -v sdk >/dev/null 2>&1; then
				printf "   or with SDKMAN: sdk install java 21-tem\n"
			fi
		fi

		exit 1
	fi

	# Start the installation
	printf "${GREEN}"
	echo ''
	echo '*************************************************************************'
	echo 'Welcome to the BoxLang® Quick Installer'
	echo '*************************************************************************'
	printf "${NORMAL}"
	printf "${BLUE}Downloading BoxLang® [${TARGET_VERSION}] from [${DOWNLOAD_URL}]${NORMAL}\n"
	printf "${RED}Please wait...${NORMAL}\n"

	# Ensure destination folders
	mkdir -p /tmp
	mkdir -p "$DESTINATION_BIN"
	mkdir -p "$DESTINATION_LIB"

	# Uninstall previous versions
    printf "${YELLOW}Removing previous versions (if any)...${NORMAL}\n"
	rm -fv "${DESTINATION_LIB}"/boxlang-*.jar

	# Download with progress bar
	rm -f /tmp/boxlang.zip
	env curl -L --progress-bar -o /tmp/boxlang.zip "${DOWNLOAD_URL}" || {
		printf "${RED}Error: Download of BoxLang® binary failed${NORMAL}\n"
		exit 1
	}
	rm -f /tmp/boxlang-miniserver.zip
	env curl -L --progress-bar -o /tmp/boxlang-miniserver.zip "${DOWNLOAD_URL_MINISERVER}" || {
		printf "${RED}Error: Download of BoxLang® MiniServer binary failed${NORMAL}\n"
		exit 1
	}

	# Inflate it
	printf "\n"
	printf "${BLUE}Unzipping BoxLang®...${NORMAL}\n"
	printf "\n"
	unzip -o /tmp/boxlang.zip -d "${DESTINATION}"
	unzip -o /tmp/boxlang-miniserver.zip -d "${DESTINATION}"

	# Make it executable
	printf "\n"
	printf "${BLUE}Making BoxLang® Executable...${NORMAL}\n"
	chmod 755 "${DESTINATION_BIN}/boxlang"
	chmod 755 "${DESTINATION_BIN}/boxlang-miniserver"

	# Add links
	printf "\n"
	printf "${BLUE}Adding symbolic links...${NORMAL}\n"
	ln -sf "${DESTINATION_BIN}/boxlang" "${DESTINATION_BIN}/bx"
	ln -sf "${DESTINATION_BIN}/boxlang-miniserver" "${DESTINATION_BIN}/bx-miniserver"

	# Install the Installer scripts
	printf "\n"
	printf "${BLUE}Installing BoxLang® Module & Core Installer Scripts [install-bx-module, install-boxlang]...${NORMAL}\n"
	env curl -Lk --progress-bar -o "${DESTINATION_BIN}/install-bx-module" "https://raw.githubusercontent.com/ortus-boxlang/boxlang-quick-installer/master/src/install-bx-module.sh"
	chmod 755 "${DESTINATION_BIN}/install-bx-module"
	env curl -Lk --progress-bar -o "${DESTINATION_BIN}/install-boxlang" "https://raw.githubusercontent.com/ortus-boxlang/boxlang-quick-installer/master/src/install-boxlang.sh"
	chmod 755 "${DESTINATION_BIN}/install-boxlang"

	# CommandBox Install Checks
	printf "\n"
	check_and_install_commandbox "$DESTINATION_BIN"

	# Cleanup
	printf "${BLUE}🗑️ Cleaning up...${NORMAL}\n"
	rm -f /tmp/boxlang*.zip
	# Remove Windows-specific files that may have been downloaded
	rm -f "${DESTINATION_BIN}"/*.bat "${DESTINATION_BIN}"/*.ps1

	# Verify installation
	verify_installation "$DESTINATION_BIN"

	# Check PATH for local user execution mostly.
	printf "\n"
	check_or_set_path "$DESTINATION_BIN"

	printf "${GREEN}"
	echo ''
	echo "♨ BoxLang® Binaries are now installed to [$DESTINATION_BIN]"
	echo "☕ BoxLang® JARs are now installed to [$DESTINATION_LIB]"
	echo "🏠 BoxLang® Home is now set to your user home [~/.boxlang]"
	echo ""
	echo 'You can change the BoxLang Home by setting the [BOXLANG_HOME] environment variable in your shell profile'
	echo 'Just copy the following line to override the location if you want'
	echo ''
	printf "${BLUE}${BOLD}"
	echo "export BOXLANG_HOME=~/.boxlang"
	echo "${NORMAL}"
	echo ''
	echo "${MAGENTA}✅ Remember you can check for updates at any time with: install-boxlang --check-update${NORMAL}"
	printf "${GREEN}"
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

main "${1:-latest}"