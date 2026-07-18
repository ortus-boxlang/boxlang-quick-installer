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
    printf "%s\n" "$1"
}

# Only prints when VERBOSE=true - use for routine step-by-step narration
print_verbose() {
    [ "${VERBOSE:-false}" = "true" ] && printf "%s\n" "$1"
    return 0
}

print_success() {
    printf "${GREEN}✓${NORMAL} %s\n" "$1"
}

print_warning() {
    printf "${YELLOW}%s${NORMAL}\n" "$1"
}

print_error() {
    printf "${RED}✗ %s${NORMAL}\n" "$1" >&2
}

print_header() {
    printf "${BOLD}%s${NORMAL}\n" "$1"
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
		DIM="$(tput dim)"
		# BoxLang brand teal - use a truer teal on 256-color terminals, cyan otherwise
		if [ "$ncolors" -ge 256 ]; then
			TEAL="$(tput setaf 37)"
		else
			TEAL="$CYAN"
		fi
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
		DIM=""
		TEAL=""
	fi
}

###########################################################################
# BoxLang Logo
###########################################################################
BOXLANG_LOGO=' ██████   ██████  ██   ██ ██       █████  ███    ██  ██████
 ██   ██ ██    ██  ██ ██  ██      ██   ██ ████   ██ ██
 ██████  ██    ██   ███   ██      ███████ ██ ██  ██ ██   ███
 ██   ██ ██    ██  ██ ██  ██      ██   ██ ██  ██ ██ ██    ██
 ██████   ██████  ██   ██ ███████ ██   ██ ██   ████  ██████'

# Prints the teal BoxLang wordmark on real, unicode-capable terminals.
# Silently does nothing on dumb terminals or piped/redirected output.
print_logo() {
	if [ -t 1 ] && [ "${TERM:-}" != "dumb" ] && terminal_supports_unicode; then
		printf "${TEAL}${BOLD}%s${NORMAL}\n\n" "$BOXLANG_LOGO"
	fi
}

###########################################################################
# Spinner / animated progress bar (non-verbose mode on a real terminal)
###########################################################################
terminal_supports_unicode() {
	local locale="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
	case "$locale" in
		*UTF-8*|*utf-8*|*UTF8*|*utf8*) return 0 ;;
	esac
	case "${TERM_PROGRAM:-}" in
		Apple_Terminal|iTerm.app|vscode|WezTerm) return 0 ;;
	esac
	return 1
}

spinner_frame() {
	local step="$1"
	if terminal_supports_unicode; then
		case $((step % 10)) in
			0) printf '⠋' ;; 1) printf '⠙' ;; 2) printf '⠹' ;; 3) printf '⠸' ;; 4) printf '⠼' ;;
			5) printf '⠴' ;; 6) printf '⠦' ;; 7) printf '⠧' ;; 8) printf '⠇' ;; *) printf '⠏' ;;
		esac
	else
		case $((step % 4)) in
			0) printf -- '-' ;; 1) printf '\\' ;; 2) printf '|' ;; *) printf '/' ;;
		esac
	fi
}

# run_step "<label>" -- command [args...]
# On a real, non-verbose terminal: runs the command in the background behind
# an animated spinner + progress bar, then prints a single "✓ <label>" line.
# In --verbose mode, or when not attached to a real terminal (piped installs,
# CI logs): runs the command directly with no animation - the command's own
# print_verbose() calls (if any) provide the detail instead.
run_step() {
	local label="$1"; shift
	[ "${1:-}" = "--" ] && shift

	if [ "${VERBOSE:-false}" = "true" ] || [ ! -t 1 ] || [ "${TERM:-}" = "dumb" ]; then
		"$@"
		local status=$?
		if [ $status -eq 0 ]; then
			print_success "$label"
		fi
		return $status
	fi

	_run_step_animated "$label" "$@"
}

_run_step_animated() {
	local label="$1"; shift
	local log_file
	log_file="$(mktemp)"

	"$@" >"$log_file" 2>&1 &
	local cmd_pid=$!

	local full empty
	if terminal_supports_unicode; then full="█"; empty="░"; else full="#"; empty="-"; fi

	printf '\033[?25l'
	local step=0 width=22 trail=6
	while kill -0 "$cmd_pid" 2>/dev/null; do
		local frame
		frame=$(spinner_frame "$step")
		local head=$(( step % (width + trail) )) bar="" i=0
		while [ "$i" -lt "$width" ]; do
			local age=$(( head - i ))
			if [ "$age" -ge 0 ] && [ "$age" -lt "$trail" ]; then
				bar="${bar}${TEAL}${full}${NORMAL}"
			else
				bar="${bar}${DIM}${empty}${NORMAL}"
			fi
			i=$((i + 1))
		done
		printf '\r\033[K  %s %s  %s' "$frame" "$bar" "$label"
		step=$((step + 1))
		sleep 0.08
	done

	local status=0
	wait "$cmd_pid" || status=$?
	printf '\r\033[K\033[?25h'

	if [ "$status" -eq 0 ]; then
		print_success "$label"
	else
		print_error "${label} - failed"
		cat "$log_file" >&2
	fi
	rm -f "$log_file"
	return "$status"
}

###########################################################################
# Pre-flight Checks
###########################################################################
# Verifies required dependencies are installed: curl, unzip and jq
preflight_check() {
	local auto_install="${1:-false}"
	print_verbose "Checking system requirements..."
	local missing_deps=()

	# Check required commands dependencies
	if [ "$(uname)" = "Darwin" ]; then
		# If brew is not installed, then quit, but only if we are on macOS
		if ! command_exists brew; then
			print_error "Homebrew is not installed. Please install Homebrew first."
			printf "Install it with:\n"
			printf "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"\n"
			return 1
		fi
	fi
	command_exists bash || missing_deps+=( "bash" )
	command_exists curl || missing_deps+=( "curl" )
	command_exists unzip || missing_deps+=( "unzip" )
	command_exists jq || missing_deps+=( "jq" )

	if [ ${#missing_deps[@]} -ne 0 ]; then
		print_warning "Missing required dependencies: ${missing_deps[*]}"

		if [ "$(uname)" = "Darwin" ]; then
			# Install the dependencies using Homebrew
			print_info "Installing missing dependencies with Homebrew..."
			for dep in "${missing_deps[@]}"; do
				print_info "Installing ${dep}..."
				if ! brew install "$dep"; then
					print_error "Failed to install ${dep}. Please install it manually."
					return 1
				fi
			done
			print_success "All dependencies installed"
		elif [ "$(uname)" = "Linux" ]; then
			print_info "Installing missing dependencies with the system package manager..."

			# Determine if we need sudo based on current user privileges
			local use_sudo=""
			if [ "$EUID" -ne 0 ]; then
				use_sudo="sudo"
			fi

			if command_exists apt-get; then
				print_info "Updating package list..."
				if ! $use_sudo apt update; then
					print_error "Failed to update package list with apt."
					return 1
				fi
				print_info "Installing dependencies: ${missing_deps[*]}..."
				if ! $use_sudo apt install -y ${missing_deps[*]}; then
					print_error "Failed to install dependencies with apt. Please install them manually."
					return 1
				fi
			elif command_exists apk; then
				print_info "Updating package list..."
				if ! $use_sudo apk update; then
					print_error "Failed to update package list with apk."
					return 1
				fi
				print_info "Installing dependencies: ${missing_deps[*]}..."
				if ! $use_sudo apk add ${missing_deps[*]}; then
					print_error "Failed to install dependencies with apk. Please install them manually."
					return 1
				fi
			elif command_exists yum; then
				print_info "Installing dependencies with yum..."
				if ! $use_sudo yum install -y ${missing_deps[*]}; then
					print_error "Failed to install dependencies with yum. Please install them manually."
					return 1
				fi
			elif command_exists dnf; then
				print_info "Installing dependencies with dnf..."
				if ! $use_sudo dnf install -y ${missing_deps[*]}; then
					print_error "Failed to install dependencies with dnf. Please install them manually."
					return 1
				fi
			elif command_exists pacman; then
				print_info "Installing dependencies with pacman..."
				if ! $use_sudo pacman -S --noconfirm ${missing_deps[*]}; then
					print_error "Failed to install dependencies with pacman. Please install them manually."
					return 1
				fi
			else
				print_error "No supported package manager found. Please install dependencies manually: ${missing_deps[*]}"
				return 1
			fi
			print_success "All dependencies installed"
		fi
	fi

	###########################################################################
	# Java Version Check
	###########################################################################
	if ! check_java_version "$auto_install"; then
		print_error "Java 21 or higher is required to run BoxLang"

		# Otherwise, prompt user for manual installation choice
		printf "☕ Install it automatically now? (y/N) "
		read -r response
		case "$response" in
			[yY][eE][sS]|[yY])
				if install_java; then
					return 0
				else
					print_error "Automatic Java installation failed."
					return 1
				fi
				;;
			*)
				printf "Install Java manually with:\n"
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
	print_verbose "Checking for Java 21..."
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
		"/Library/Java/JavaVirtualMachines/*/Contents/Home/bin/java"  # macOS Oracle/OpenJDK,
		"/opt/java/openjdk-21-jre/bin/java"                # Custom install location (Linux
	)

	# If running under sudo, try to get the original user's environment
	if [ -n "${SUDO_USER}" ]; then
		print_verbose "Detected sudo execution, checking Java from original user context..."

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
							print_verbose "${GREEN}✓${NORMAL} ☕ Found Java ${JAVA_VERSION} at ${JAVA_CMD}"
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
						print_verbose "${GREEN}✓${NORMAL} ☕ Found Java ${JAVA_VERSION} at ${JAVA_CMD}"
						return 0
					elif [ -n "$JAVA_VERSION" ]; then
						print_warning "Found Java ${JAVA_VERSION} at ${candidate}, but Java 21+ is required"
					fi
				fi
			fi
		fi
	done

	# If auto_install is true, attempt automatic installation
	if [ "$auto_install" = "true" ]; then
		print_verbose "Java 21+ not found, installing automatically..."
		if install_java; then
			return 0
		else
			print_error "Automatic Java installation failed."
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
	local JRE_VERSION="21.0.8+9"
	local INSTALL_BASE=""
	local JRE_URL=""
	local JRE_FILENAME=""
	local JAVA_INSTALL_DIR=""

	print_verbose "Installing Java ${JRE_VERSION}..."

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
				print_verbose "Detected Alpine Linux (musl libc)"
			elif command_exists ldd && ldd --version 2>&1 | grep -q musl; then
				LIBC_TYPE="musl"
				print_verbose "Detected musl libc"
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

	print_verbose "Detected: ${OS} (${ARCH}), installing to ${JAVA_INSTALL_DIR}"

	# Create temporary directory
	local TEMP_DIR=$(mktemp -d)
	local DOWNLOAD_PATH="$TEMP_DIR/$JRE_FILENAME"

	# Download JRE
	if ! run_step "☕ Downloaded Java ${JRE_VERSION}" -- curl -fsSL "$JRE_URL" -o "$DOWNLOAD_PATH"; then
		print_error "Failed to download JRE"
		rm -rf "$TEMP_DIR"
		return 1
	fi

	# Create installation directory (requires elevated privileges on most systems)
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
	if ! run_step "Extracted Java runtime" -- tar -xzf "$DOWNLOAD_PATH" -C "$TEMP_DIR"; then
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
		$use_sudo rm -rf "$JAVA_INSTALL_DIR"
	fi

	# Move extracted content to final location
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
		# Add new environment variables
		echo "" >> "$PROFILE_FILE"
		echo "# Java JRE installed by BoxLang installer" >> "$PROFILE_FILE"
		echo "export JAVA_HOME=\"$JAVA_INSTALL_DIR\"" >> "$PROFILE_FILE"
		echo "export PATH=\"\$JAVA_HOME/bin:\$PATH\"" >> "$PROFILE_FILE"
		print_success "Updated shell profile: $PROFILE_FILE"
		print_warning "Run 'source $PROFILE_FILE' or restart your terminal to use the new Java installation"
	else
		print_warning "Could not determine shell profile file. Please manually add:"
		printf "   export JAVA_HOME=\"$JAVA_INSTALL_DIR\"\n"
		printf "   export PATH=\"\$JAVA_HOME/bin:\$PATH\"\n"
	fi

	# Set for current session
	export JAVA_HOME="$JAVA_INSTALL_DIR"
	export PATH="$JAVA_HOME/bin:$PATH"

	# Verify installation
	if "$JAVA_BIN/java" -version >/dev/null 2>&1; then
		print_success "Java JRE installed"
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
		print_verbose "WSL environment detected" >&2
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