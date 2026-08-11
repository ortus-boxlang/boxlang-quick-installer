#!/bin/sh
# IMPORTANT: This script intentionally targets POSIX /bin/sh.
# Do not change the shebang back to Bash or reintroduce Bash-only syntax.
# It must remain compatible with Alpine BusyBox ash and standard /bin/sh.

# BoxLang Installer Script
# This script helps install BoxLang® runtime and tools on your system.
# Author: BoxLang Team
# Version: @build.version@
# License: Apache License, Version 2.0

# Only enable exit-on-error after the non-critical colorization stuff,
# which may fail on systems lacking tput or terminfo
set -e

# We need this in case the target OS we are installing in does not have a `TERM` implementation declared
# or when TERM is set to problematic values like "unknown" (common in CI environments like GitHub Actions)
if [ -z "$TERM" ] || [ "$TERM" = "unknown" ] || [ "$TERM" = "dumb" ]; then
	export TERM="xterm-256color"
fi

###########################################################################
# Global Variables + Helpers
###########################################################################

# Global Variables
INSTALLER_VERSION="@build.version@"
TEMP_DIR="${TMPDIR:-/tmp}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# prompt = ask, automatic = install, skip = require Java without installing it
INSTALL_COMMANDBOX=""
JAVA_INSTALL_MODE="prompt"
NON_INTERACTIVE=false
# local paths to skip downloads (empty = download from remote)
BOXLANG_PATH=""
MINISERVER_PATH=""
INSTALLER_SCRIPTS_PATH=""

if [ ! -t 0 ]; then
	NON_INTERACTIVE=true
fi

for arg in "$@"; do
	if [ "$arg" = "--non-interactive" ]; then
		NON_INTERACTIVE=true
	fi
done

###########################################################################
# Get current BoxLang install home
###########################################################################
get_boxlang_install_home(){
	# Check common installation locations
	for location in "/usr/local/boxlang" "$HOME/.local/boxlang" "${BOXLANG_INSTALL_HOME:-}"; do
		if [ -n "$location" ] && [ -d "$location" ]; then
			echo "$location"
			return 0
		fi
	done

	# If not found, return empty
	echo ""
	return 0
}

# Check if helpers exist in BoxLang installation directory
boxlang_home=$(get_boxlang_install_home)
if [ -n "$boxlang_home" ] && [ -f "$boxlang_home/scripts/helpers/helpers.sh" ]; then
	. "$boxlang_home/scripts/helpers/helpers.sh"
elif [ -f "$SCRIPT_DIR/helpers/helpers.sh" ]; then
	# Source helpers from relative path (development/local setup)
	. "$SCRIPT_DIR/helpers/helpers.sh"
else
	# Download helpers.sh if it doesn't exist locally
	printf "${BLUE}⬇️ Downloading helper functions...${NORMAL}\n"
	helpers_url="https://downloads.ortussolutions.com/ortussolutions/boxlang-quick-installer/helpers/helpers.sh"
	helpers_file="${TEMP_DIR}/helpers.sh"

	if curl -fsSL "$helpers_url" -o "$helpers_file"; then
		chmod +x "$helpers_file"
		. "$helpers_file"
		print_success "Helper functions downloaded successfully"
	else
		printf "${RED}🔴 Error: Failed to download helper functions from [$helpers_url] to [${TEMP_DIR}]${NORMAL}\n"
		exit 1
	fi
fi


###########################################################################
# Get current installed BoxLang version
###########################################################################
get_current_version() {
	local current_version=""

	# Try to find BoxLang in common locations
	local boxlang_candidates="boxlang /usr/local/bin/boxlang $HOME/.local/bin/boxlang /usr/local/boxlang/bin/boxlang $HOME/.local/boxlang/bin/boxlang"
	if [ -n "${BOXLANG_INSTALL_HOME:-}" ]; then
		boxlang_candidates="$boxlang_candidates $BOXLANG_INSTALL_HOME/bin/boxlang"
	fi

	for candidate in $boxlang_candidates; do
		if command_exists "$candidate" || [ -x "$candidate" ]; then
			local version_output=$("$candidate" --version 2>/dev/null || echo "")
			if [ -n "$version_output" ]; then
				current_version=$(extract_semantic_version "$version_output" | xargs )
				if [ -n "$current_version" ]; then
					echo "$current_version"
					return 0
				fi
			fi
		fi
	done

	return 1
}

###########################################################################
# Get latest available BoxLang version from remote
###########################################################################
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

###########################################################################
# Check for updates and optionally prompt for installation
###########################################################################
check_for_updates() {
	print_info "🔍 Checking for BoxLang updates..."

	# Get current version
	local current_version
	current_version=$(get_current_version)
	if [ $? -ne 0 ] || [ -z "$current_version" ]; then
		print_warning "⚠️  BoxLang is not currently installed"
		current_version="0.0.0"
	fi

	# Get latest version
	local latest_version
	latest_version=$(get_latest_version)
	if [ $? -ne 0 ] || [ -z "$latest_version" ]; then
		print_error "Failed to fetch latest version information"
		print_warning "Please check your internet connection and try again"
		return 1
	fi

	printf "${GREEN}Current version: ${current_version}${NORMAL}\n"
	printf "${GREEN}Latest version:  ${latest_version}${NORMAL}\n"
	printf "\n"

	# Compare versions
	compare_versions "$current_version" "$latest_version"
	local comparison_result=$?

	case $comparison_result in
		0)
			print_success "You have the latest version of BoxLang"
			return 0
			;;
		1)
			print_info "🔄 You have a newer version than the latest release"
			print_warning "This might be a development or snapshot build"
			return 0
			;;
		2)
			print_warning "🆙 A newer version of BoxLang is available!"
			if [ "$NON_INTERACTIVE" = true ]; then
				response=""
			else
				print_info "Would you like to update to version ${latest_version}? [Y/n]"
				read -r response < /dev/tty
			fi
			case "$response" in
				[nN][oO]|[nN])
					print_warning "Update cancelled"
					return 0
					;;
				*)
					print_info "Starting update to BoxLang ${latest_version}..."
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
	# Incoming args
	local bin_dir="$1"
	local install_home="$2"
	local boxlang_home_bin="${3:-}"
	# Detect the appropriate shell profile file using helper function
	local profile_file=$(get_shell_profile_file)

	# Build PATH string with both bin directories
	local path_value="$bin_dir"
	if [ -n "$boxlang_home_bin" ]; then
		path_value="$bin_dir:$boxlang_home_bin"
	fi

	# Check if the PATH export already exists in the profile
	local path_export="export PATH=\"$path_value:\$PATH\""
	local path_exists=false
	local install_home_exists=false
	local boxlang_home_bin_exists=false

	if [ -f "$profile_file" ]; then
		if grep -Fq "$bin_dir" "$profile_file" 2>/dev/null; then
			path_exists=true
		fi
	fi

	# Check if boxlang home bin is in PATH
	if [ -n "$boxlang_home_bin" ] && [ -f "$profile_file" ]; then
		if grep -Fq "$boxlang_home_bin" "$profile_file" 2>/dev/null; then
			boxlang_home_bin_exists=true
		fi
	fi

	# Check if BOXLANG_INSTALL_HOME is already set in the profile
	if [ -f "$profile_file" ] && grep -Fq "BOXLANG_INSTALL_HOME" "$profile_file" ]; then
		install_home_exists=true
	fi

	# If all entries exist, we're done
	if [ "$path_exists" = true ] && [ "$install_home_exists" = true ]; then
		if [ -z "$boxlang_home_bin" ] || [ "$boxlang_home_bin_exists" = true ]; then
			print_success "PATH entry and BOXLANG_INSTALL_HOME already exist in $profile_file"
			return 0
		fi
	fi

	# If PATH exists but BOXLANG_INSTALL_HOME doesn't, add only the install home
	if [ "$path_exists" = true ] && [ "$install_home_exists" = false ]; then
		print_info "➕ Adding BOXLANG_INSTALL_HOME to $profile_file (upgrade from older installation)..."
		{
			echo ""
			echo "# BoxLang installation environment setup - added on $(date)"
			if [ "$current_shell" = "fish" ]; then
				echo "set -gx BOXLANG_INSTALL_HOME \"$install_home\""
			else
				echo "export BOXLANG_INSTALL_HOME=\"$install_home\""
			fi
		} >> "$profile_file"
		print_success "Successfully added BOXLANG_INSTALL_HOME to [$profile_file]"
		export BOXLANG_INSTALL_HOME="$install_home"
		return 0
	fi

	# Add PATH to the profile file
	if [ -n "$boxlang_home_bin" ]; then
		print_info "➕ Adding [$bin_dir] and [$boxlang_home_bin] to PATH in [$profile_file]..."
	else
		print_info "➕ Adding [$bin_dir] to PATH in [$profile_file]..."
	fi
	print_info "➕ Adding BOXLANG_INSTALL_HOME [$install_home] in [$profile_file]..."

	{
		echo ""
		echo "# Added by BoxLang installer on $(date)"
		if [ "$current_shell" = "fish" ]; then
			if [ -n "$boxlang_home_bin" ]; then
				echo "set -gx PATH $bin_dir $boxlang_home_bin \$PATH"
			else
				echo "set -gx PATH $bin_dir \$PATH"
			fi
		else
			echo "$path_export"
		fi
		echo ""
		echo "# BoxLang installation environment setup"
		if [ "$current_shell" = "fish" ]; then
			echo "set -gx BOXLANG_INSTALL_HOME \"$install_home\""
		else
			echo "export BOXLANG_INSTALL_HOME=\"$install_home\""
		fi
	} >> "$profile_file"

	if [ -n "$boxlang_home_bin" ]; then
		print_success "Successfully added [$bin_dir] and [$boxlang_home_bin] to PATH in [$profile_file]"
	else
		print_success "Successfully added [$bin_dir] to PATH in [$profile_file]"
	fi
	printf "${RED}─────────────────────────────────────────────────────────────────────────────${NORMAL}\n"

	# Special handling for WSL
	if [ "$is_wsl" = true ]; then
		print_warning "IMPORTANT: You may need to restart your terminal or run:"
		if [ "$current_shell" = "fish" ]; then
			printf "${CYAN}source $profile_file${NORMAL}\n"
		else
			printf "${CYAN}source $profile_file${NORMAL}\n"
		fi
	else
		print_warning "IMPORTANT: Restart your terminal or run the following to use the new PATH:"
		if [ "$current_shell" = "fish" ]; then
			printf "${CYAN}source $profile_file${NORMAL}\n"
		else
			printf "${CYAN}source $profile_file${NORMAL}\n"
		fi
	fi

	printf "${RED}─────────────────────────────────────────────────────────────────────────────${NORMAL}\n"

	# Update current session PATH
	if [ -n "$boxlang_home_bin" ]; then
		export PATH="$bin_dir:$boxlang_home_bin:$PATH"
	else
		export PATH="$bin_dir:$PATH"
	fi
	export BOXLANG_INSTALL_HOME="$install_home"
}

###########################################################################
# CommandBox Installation Check and Install Function
###########################################################################
check_and_install_commandbox() {
	local system_bin="$1"
	local boxlang_bin="$2"

	print_info "🔍 Checking for CommandBox..."

	# Check if CommandBox is already available
	if command_exists box; then
		print_success "CommandBox is already installed and available"
		return 0
	fi

	print_warning "CommandBox is not installed"
	print_info "💡 CommandBox is the Package Manager for BoxLang®"
	print_info "💡 It allows you to easily manage BoxLang modules, dependencies, start servlet containers, and more${NORMAL}"

	# Determine if we should install CommandBox based on flags
	local should_install=""
	if [ "$INSTALL_COMMANDBOX" = "true" ]; then
		should_install="yes"
		print_info "📦 Installing CommandBox (auto-install enabled)..."
	elif [ "$INSTALL_COMMANDBOX" = "false" ]; then
		should_install="no"
		print_info "⏭️  Skipping CommandBox installation (--without-commandbox specified)"
	else
		# Interactive mode - ask user
		if [ "$NON_INTERACTIVE" = true ]; then
			response=""
		else
			print_info "❓ Would you like to install CommandBox? [Y/n]"
			read -r response < /dev/tty
		fi
		case "$response" in
			[nN][oO]|[nN])
				should_install="no"
				;;
			*)
				should_install="yes"
				;;
		esac
	fi

	if [ "$should_install" != "yes" ]; then
		print_info "💡 You can install CommandBox later from: https://commandbox.ortusbooks.com/setup/installation"
		return 0
	fi

	print_info "📦 Installing CommandBox..."

	# The universal binary for mac/linux is available at the following URL
	local commandbox_url="https://www.ortussolutions.com/parent/download/commandbox/type/bin"
	local commandbox_filename="commandbox.zip"

	# Download CommandBox
	print_info "Downloading CommandBox from ${commandbox_url}..."
	if ! env curl -L --progress-bar -o "${TEMP_DIR}/${commandbox_filename}" "${commandbox_url}"; then
		print_error "Failed to download CommandBox"
		print_info "💡 Please manually install CommandBox from: https://commandbox.ortusbooks.com/setup/installation"
		return 1
	fi

	# Extract CommandBox
	print_info "Extracting CommandBox..."
	if ! unzip -o "${TEMP_DIR}/${commandbox_filename}" -d "${TEMP_DIR}/commandbox/"; then
		print_error "Failed to extract CommandBox"
		return 1
	fi

	# Install CommandBox to BoxLang bin directory
	print_info "Installing CommandBox to ${boxlang_bin}/box..."
	mv "${TEMP_DIR}/commandbox/box" "${boxlang_bin}/box"
	chmod 755 "${boxlang_bin}/box"

	# Create symbolic link in system bin directory
	print_info "Creating CommandBox symbolic link in ${system_bin}..."
	ln -sf "${boxlang_bin}/box" "${system_bin}/box"

	# Cleanup
	rm -rf "${TEMP_DIR}/${commandbox_filename}" "${TEMP_DIR}/commandbox/"

	print_success "CommandBox installed successfully"
	return 0
}

###########################################################################
# Installation Verification Function
###########################################################################
verify_installation() {
	local bin_dir="$1"
	local system_bin="$2"
	print_info "🔍 Verifying installation..."

	# Make sure BoxLang binary can emit version information
	if [ ! -x "${bin_dir}/boxlang" ]; then
		print_error "BoxLang installation verification failed"
		return 1
	fi
	if [ "$JAVA_INSTALL_MODE" != "skip" ] || [[ "$BOXLANG_PATH" != *.jar ]]; then
		if ! "${bin_dir}/boxlang" --version >/dev/null 2>&1; then
			print_error "BoxLang installation verification failed"
			return 1
		fi
	fi

	# Check system symbolic links
	if [ ! -L "${system_bin}/boxlang" ]; then
		print_warning "System symbolic link 'boxlang' was not created properly"
	fi

	if [ ! -L "${system_bin}/bx" ]; then
		print_warning "System symbolic link 'bx' was not created properly"
	fi

	if [ ! -L "${system_bin}/boxlang-miniserver" ]; then
		print_warning "System symbolic link 'boxlang-miniserver' was not created properly"
	fi

	if [ ! -L "${system_bin}/bx-miniserver" ]; then
		print_warning "System symbolic link 'bx-miniserver' was not created properly"
	fi

	# Check helper scripts
	if [ ! -L "${system_bin}/install-bx-module" ]; then
		print_warning "System symbolic link 'install-bx-module' was not created properly"
	fi
	if [ ! -L "${system_bin}/install-boxlang" ]; then
		print_warning "System symbolic link 'install-boxlang' was not created properly"
	fi

	# Check CommandBox installation (optional)
	if [ -x "${bin_dir}/box" ]; then
		if [ ! -L "${system_bin}/box" ]; then
			print_warning "CommandBox symbolic link was not created properly"
		else
			print_success "👊 CommandBox is installed and linked"
		fi
	fi

	print_success "👊 Installation verified successfully"
	return 0
}

###########################################################################
# Uninstall BoxLang
###########################################################################
uninstall_boxlang() {
	print_warning "🗑️  Uninstalling BoxLang..."

	# Remove symbolic links from system bin directories
	print_info "🔗 Removing system symbolic links..."
	rm -fv /usr/local/bin/boxlang
	rm -fv /usr/local/bin/bx
	rm -fv /usr/local/bin/boxlang-miniserver
	rm -fv /usr/local/bin/bx-miniserver
	rm -fv /usr/local/bin/install-bx-module
	rm -fv /usr/local/bin/install-boxlang
	rm -fv /usr/local/bin/install-bvm

	# Remove BoxLang installation directory
	print_info "📁 Removing previous BoxLang installation directory..."
	rm -rfv /usr/local/boxlang

	# Remove legacy JAR files if they exist
	print_info "🫙 Removing legacy JAR files (if any)..."
	rm -fv /usr/local/lib/boxlang-*.jar

	# Also check user-local installation
	if [ -d "$HOME/.local/bin" ]; then
		print_info "👤 Checking user-local installation..."
		rm -fv "$HOME/.local/bin/boxlang"
		rm -fv "$HOME/.local/bin/bx"
		rm -fv "$HOME/.local/bin/boxlang-miniserver"
		rm -fv "$HOME/.local/bin/bx-miniserver"
		rm -fv "$HOME/.local/bin/install-bx-module"
		rm -fv "$HOME/.local/bin/install-boxlang"
		rm -fv "$HOME/.local/bin/install-boxlang"
	fi

	# Remove user-local BoxLang installation directory
	if [ -d "$HOME/.local/boxlang" ]; then
		print_info "📁 Removing user-local BoxLang installation directory..."
		rm -rfv "$HOME/.local/boxlang"
	fi

	# Remove legacy user lib files if they exist
	if [ -d "$HOME/.local/lib" ]; then
		rm -fv "$HOME/.local/lib/boxlang-*.jar"
	fi

	print_success "✅ BoxLang uninstalled successfully"
	print_info "💡 BoxLang Home directory (~/.boxlang) was preserved"
	print_info "💡 To remove it completely, run: rm -rf ~/.boxlang"
}

###########################################################################
# Help Function
###########################################################################
show_help() {
	printf "${GREEN}📦 BoxLang® Quick Installer v${INSTALLER_VERSION}${NORMAL}\n\n"
	printf "${YELLOW}This script installs the BoxLang® runtime, MiniServer and tools on your system.${NORMAL}\n\n"
	printf "${BOLD}USAGE:${NORMAL}\n"
	printf "  install-boxlang [version] [options]\n"
	printf "  install-boxlang --help\n\n"
	printf "${BOLD}ARGUMENTS:${NORMAL}\n"
	printf "  [version]         (Optional) Specify which version to install\n"
	printf "                    - ${BOLD}'latest' (default)${NORMAL}: Install the latest stable release\n"
	printf "                    - ${BOLD}'snapshot'${NORMAL}: Install the latest development snapshot\n"
	printf "                    - ${BOLD}'1.2.0'${NORMAL}: Install a specific version number\n\n"
	printf "${BOLD}OPTIONS:${NORMAL}\n"
	printf "  --help, -h        	Show this help message\n"
	printf "  --uninstall       	Remove BoxLang from the system\n"
	printf "  --check-update    	Check if a newer version is available\n"
	printf "  --system          	Force system-wide installation (requires sudo)\n"
	printf "  --force           	Force reinstallation even if already installed\n"
	printf "  --with-commandbox 	Install CommandBox without prompting\n"
	printf "  --without-commandbox 	Skip CommandBox installation\n"
	printf "  --non-interactive 	Never prompt for input (also enabled when input is redirected)\n"
	printf "  --with-jre        	Automatically install Java 21 JRE if not found\n"
	printf "  --without-jre     	Skip Java installation (manual installation required)\n"
	printf "  --yes, -y         	Use defaults for all prompts (installs CommandBox and Java)\n"
	printf "  --boxlang-path <path>	Use local BoxLang zip instead of downloading\n"
	printf "  --miniserver-path <path>	Use local MiniServer zip instead of downloading\n"
	printf "  --installer-scripts-path <path>	Use local scripts zip or folder instead of downloading\n\n"
	printf "${BOLD}EXAMPLES:${NORMAL}\n"
	printf "  install-boxlang\n"
	printf "  install-boxlang latest\n"
	printf "  install-boxlang snapshot\n"
	printf "  install-boxlang 1.2.0\n"
	printf "  install-boxlang --force\n"
	printf "  install-boxlang --with-commandbox\n"
	printf "  install-boxlang --without-commandbox\n"
	printf "  install-boxlang --with-jre\n"
	printf "  install-boxlang --without-jre\n"
	printf "  install-boxlang --with-commandbox --with-jre\n"
	printf "  install-boxlang --yes\n"
	printf "  install-boxlang --uninstall\n"
	printf "  install-boxlang --check-update\n"
	printf "  sudo install-boxlang --system\n"
	printf "  install-boxlang --boxlang-path ./boxlang.zip --miniserver-path ./miniserver.zip --installer-scripts-path ./scripts/\n\n"
	printf "${BOLD}NON-INTERACTIVE USAGE:${NORMAL}\n"
	printf "  🌐 Install with CommandBox: ${GREEN}curl -fsSL https://boxlang.io/install.sh | bash -s -- --with-commandbox${NORMAL}\n"
	printf "  🌐 Install without CommandBox: ${GREEN}curl -fsSL https://boxlang.io/install.sh | bash -s -- --without-commandbox${NORMAL}\n"
	printf "  🌐 Install with Java auto-install: ${GREEN}curl -fsSL https://boxlang.io/install.sh | bash -s -- --with-jre${NORMAL}\n"
	printf "  🌐 Full auto-install (Java + CommandBox): ${GREEN}curl -fsSL https://boxlang.io/install.sh | bash -s -- --yes${NORMAL}\n"
	printf "  🌐 Install with defaults: ${GREEN}curl -fsSL https://boxlang.io/install.sh | bash -s -- --yes${NORMAL}\n\n"
	# ... rest of help text remains the same
}

###########################################################################
# Remove Previous Installation Function
###########################################################################
remove_previous_installation() {
	# Remove previous BoxLang installation if it exists
	if [ -d "${SYSTEM_HOME}" ]; then
		print_warning "🗑️ Removing previous BoxLang installation..."
		rm -rf "${SYSTEM_HOME}"

		# Remove old symbolic links from system bin
		rm -f "${SYSTEM_BIN}/boxlang"
		rm -f "${SYSTEM_BIN}/bx"
		rm -f "${SYSTEM_BIN}/boxlang-miniserver"
		rm -f "${SYSTEM_BIN}/bx-miniserver"
		rm -f "${SYSTEM_BIN}/install-bx-module"
		rm -f "${SYSTEM_BIN}/install-boxlang"
		rm -f "${SYSTEM_BIN}/install-bx-site"
	fi
	# Remove $HOME/.boxlang/classes directory to make sure no old classes remain
	if [ -d "$HOME/.boxlang/classes" ]; then
		print_warning "🗑️ Removing old BoxLang classes from home directory..."
		rm -rf "$HOME/.boxlang/classes"
	fi
}

###########################################################################
# Handle the main installation
###########################################################################
install_boxlang() {
	# Check for --force flag in any position and remove it from args
	local FORCE_INSTALL=false
	local TARGET_VERSION="latest"
	local has_system=false
	for arg in "$@"; do
		if [ "$arg" = "--force" ]; then
			FORCE_INSTALL=true
		elif [ "$arg" = "--system" ]; then
			has_system=true
		elif [ "$TARGET_VERSION" = "latest" ]; then
			TARGET_VERSION="$arg"
		fi
	done

	# Check target version argument, this could be "latest", "snapshot", or a specific version like "1.2.0" or empty for latest
	# If the version is "snapshot", always force it
	if [ "$TARGET_VERSION" = "snapshot" ]; then
		FORCE_INSTALL=true
	fi

	###########################################################################
	# Pre-flight Checks
	# Build dependency list based on what's actually needed
	###########################################################################
	local preflight_deps=""
	# curl: only if any download will happen
	if [ -z "$BOXLANG_PATH" ] || [ -z "$MINISERVER_PATH" ] || [ -z "$INSTALLER_SCRIPTS_PATH" ]; then
		preflight_deps="curl"
	elif [ "$INSTALL_COMMANDBOX" != "false" ] || [ "$JAVA_INSTALL_MODE" != "skip" ]; then
		preflight_deps="curl"
	fi
	# unzip: only if any zip will be extracted
	local need_unzip=false
	case "$BOXLANG_PATH" in ""|*.zip) need_unzip=true;; esac
	case "$MINISERVER_PATH" in ""|*.zip) need_unzip=true;; esac
	if [ -z "$INSTALLER_SCRIPTS_PATH" ] || ( [ -n "$INSTALLER_SCRIPTS_PATH" ] && [ ! -d "$INSTALLER_SCRIPTS_PATH" ] ); then need_unzip=true; fi
	if [ "$INSTALL_COMMANDBOX" != "false" ]; then need_unzip=true; fi
	if $need_unzip; then preflight_deps="$preflight_deps unzip"; fi

	if ! preflight_check "$JAVA_INSTALL_MODE" -- $preflight_deps; then
		exit 1
	fi

	###########################################################################
	# Setup Installation Directories
	###########################################################################
	# These are the system-wide installation directories
	local SYSTEM_HOME="${BOXLANG_INSTALL_HOME:-/usr/local/boxlang}"
	local SYSTEM_BIN="/usr/local/bin"

	###########################################################################
	# Verify if BoxLang is already installed
	# If it is, we will exit early unless --force is used
	# If --force is used, we will remove the existing installation first
	###########################################################################

	if [ "$FORCE_INSTALL" = false ]; then
		print_info "🔍 Checking for existing BoxLang installation..."
		local CURRENT_VERSION=$(get_current_version)
		if [ $? -eq 0 ] && [ -n "$CURRENT_VERSION" ]; then
			print_warning "⚠️  BoxLang is already installed at [${SYSTEM_HOME}] with version[${CURRENT_VERSION}]"
			print_info "💡 Use ${GREEN}'install-boxlang.sh --uninstall'${BLUE} to remove the existing version before reinstalling."
			print_info "💡 Or use ${GREEN}'--force'${BLUE} to do a forced reinstall."
			print_info "💡 Or use ${GREEN}'--help'${BLUE} for more information."
			exit 0;
		else
			print_success "No previous BoxLang installation found, proceeding with fresh install..."
		fi
	else
		print_warning "🔄 Forcing reinstallation of BoxLang..."
		remove_previous_installation || {
			print_error "❌ Failed to remove previous installation, please see log for more information"
			exit 1
		}
	fi

	###########################################################################
	# Support user-local installation if not running as root and not explicitly system install
	###########################################################################
	if [ "$(id -u)" -ne 0 ] && [ "$has_system" = false ]; then
		printf "${BLUE}─────────────────────────────────────────────────────────────────────────────${NORMAL}\n"
		print_warning "🥸 Installing to user directory (~/.local) since not running as root"
		print_info "💡 Use ${GREEN}'sudo install-boxlang.sh'${BLUE} for system-wide installation"
		printf "${BLUE}─────────────────────────────────────────────────────────────────────────────${NORMAL}\n"
		printf "\n"
		SYSTEM_HOME="$HOME/.local/boxlang"
		SYSTEM_BIN="$HOME/.local/bin"
	fi

	###########################################################################
	# Setup Global Variables
	###########################################################################
	local INSTALLER_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang-quick-installer/boxlang-installer.zip"
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
	# BoxLang installation structure
	###########################################################################
	local DESTINATION_BIN="${SYSTEM_HOME}/bin"
	local DESTINATION_LIB="${SYSTEM_HOME}/lib"
	local DESTINATION_ASSETS="${SYSTEM_HOME}/assets"
	local DESTINATION_SCRIPTS="${SYSTEM_HOME}/scripts"
	mkdir -p "$DESTINATION_BIN" "$DESTINATION_LIB" "$DESTINATION_ASSETS" "$DESTINATION_SCRIPTS" "$SYSTEM_BIN" "${TEMP_DIR}"

	###########################################################################
	# Start the installation
	###########################################################################
	print_info "🎯 Installing BoxLang® ${GREEN}[${TARGET_VERSION}]${BLUE} to ${GREEN}[${SYSTEM_HOME}]"

	###########################################################################
	# Get BoxLang (local path or download)
	###########################################################################
	if [ -n "$BOXLANG_PATH" ]; then
		case "$BOXLANG_PATH" in
		*.jar)
			print_info "📦 Using local BoxLang JAR: ${BOXLANG_PATH}"
			mkdir -p "${DESTINATION_LIB}"
			cp "$BOXLANG_PATH" "${DESTINATION_LIB}/"
			;;
		*)
			print_info "📦 Using local BoxLang zip: ${BOXLANG_PATH}"
			cp "$BOXLANG_PATH" "${TEMP_DIR}/boxlang.zip"
			;;
		esac
	else
		print_warning "⌛ Downloading BoxLang..."
		print_info "${DOWNLOAD_URL}"
		rm -f "${TEMP_DIR}"/boxlang.zip
		env curl -L --progress-bar -o "${TEMP_DIR}"/boxlang.zip "${DOWNLOAD_URL}" || {
			print_error "Error: Download of BoxLang® binary failed"
			exit 1
		}
	fi

	###########################################################################
	# Get BoxLang MiniServer (local path or download)
	###########################################################################
	if [ -n "$MINISERVER_PATH" ]; then
		case "$MINISERVER_PATH" in
		*.jar)
			print_info "📦 Using local MiniServer JAR: ${MINISERVER_PATH}"
			mkdir -p "${DESTINATION_LIB}"
			cp "$MINISERVER_PATH" "${DESTINATION_LIB}/"
			;;
		*)
			print_info "📦 Using local MiniServer zip: ${MINISERVER_PATH}"
			cp "$MINISERVER_PATH" "${TEMP_DIR}/boxlang-miniserver.zip"
			;;
		esac
	else
		print_warning "⌛ Downloading BoxLang MiniServer..."
		print_info "${DOWNLOAD_URL_MINISERVER}"
		rm -f "${TEMP_DIR}"/boxlang-miniserver.zip
		env curl -L --progress-bar -o "${TEMP_DIR}"/boxlang-miniserver.zip "${DOWNLOAD_URL_MINISERVER}" || {
			print_error "Error: Download of BoxLang® MiniServer binary failed"
			exit 1
		}
	fi

	###########################################################################
	# Get Installer Scripts (local path or download)
	###########################################################################
	if [ -n "$INSTALLER_SCRIPTS_PATH" ]; then
		print_info "📦 Using local installer scripts: ${INSTALLER_SCRIPTS_PATH}"
		if [ -d "$INSTALLER_SCRIPTS_PATH" ]; then
			# Already extracted directory - will copy directly later
			:
		else
			# Zip file - copy to temp for extraction
			cp "$INSTALLER_SCRIPTS_PATH" "${TEMP_DIR}/boxlang-installer.zip"
		fi
	else
		print_warning "⌛ Downloading installer scripts..."
		print_info "${INSTALLER_URL}"
		rm -f "${TEMP_DIR}"/boxlang-installer.zip
		env curl -L --progress-bar -o "${TEMP_DIR}"/boxlang-installer.zip "${INSTALLER_URL}" || {
			print_error "Error: Download of BoxLang® Installer bundle failed"
			exit 1
		}
	fi

	###########################################################################
	# Inflate them
	###########################################################################
	printf "\n"
	print_info "🛺 Unzipping Assets to ${SYSTEM_HOME}..."
	if [ -f "${TEMP_DIR}/boxlang.zip" ]; then
		unzip -q -o "${TEMP_DIR}"/boxlang.zip -d "${SYSTEM_HOME}"
	fi
	if [ -f "${TEMP_DIR}/boxlang-miniserver.zip" ]; then
		unzip -q -o "${TEMP_DIR}"/boxlang-miniserver.zip -d "${SYSTEM_HOME}"
	fi
	if [ -n "$INSTALLER_SCRIPTS_PATH" ] && [ -d "$INSTALLER_SCRIPTS_PATH" ]; then
		print_info "📋 Copying installer scripts from directory..."
		mkdir -p "${SYSTEM_HOME}/scripts"
		cp -r "${INSTALLER_SCRIPTS_PATH}/"* "${SYSTEM_HOME}/scripts/"
	else
		unzip -q -o "${TEMP_DIR}"/boxlang-installer.zip -d "${SYSTEM_HOME}/scripts"
	fi
	case "$BOXLANG_PATH" in
	*.jar)
		cat > "${DESTINATION_BIN}/boxlang" <<'EOF'
#!/bin/sh
exec java -jar "$(dirname "$0")/../lib/boxlang.jar" "$@"
EOF
		;;
	esac
	case "$MINISERVER_PATH" in
	*.jar)
		cat > "${DESTINATION_BIN}/boxlang-miniserver" <<'EOF'
#!/bin/sh
exec java -jar "$(dirname "$0")/../lib/boxlang-miniserver.jar" "$@"
EOF
		;;
	esac

	###########################################################################
	# Make them executable
	###########################################################################
	print_info "⚡Making Assets Executable..."
	chmod -R 755 "${SYSTEM_HOME}"

	###########################################################################
	# Add internal links within BoxLang home
	###########################################################################
	print_info "🔗 Adding system symbolic links..."
	# BoxLang Binaries with aliases
	ln -sf "${DESTINATION_BIN}/boxlang" "${SYSTEM_BIN}/boxlang"
	ln -sf "${SYSTEM_BIN}/boxlang" "${SYSTEM_BIN}/bx"
	# MiniServer Binaries with aliases
	ln -sf "${DESTINATION_BIN}/boxlang-miniserver" "${SYSTEM_BIN}/boxlang-miniserver"
	ln -sf "${SYSTEM_BIN}/boxlang-miniserver" "${SYSTEM_BIN}/bx-miniserver"
	# Helper scripts
	ln -sf "${DESTINATION_SCRIPTS}/install-boxlang.sh" "${SYSTEM_BIN}/install-boxlang"
	ln -sf "${DESTINATION_SCRIPTS}/install-bx-module.sh" "${SYSTEM_BIN}/install-bx-module"
	ln -sf "${DESTINATION_SCRIPTS}/install-bx-site.sh" "${SYSTEM_BIN}/install-bx-site"
	ln -sf "${DESTINATION_SCRIPTS}/install-bvm.sh" "${SYSTEM_BIN}/install-bvm"
	ln -sf "${DESTINATION_SCRIPTS}/bvm.sh" "${SYSTEM_BIN}/bvm"

	# CommandBox Installation
	# In the future this will be part of BoxLang
	check_and_install_commandbox "$SYSTEM_BIN" "$DESTINATION_BIN"

	# Cleanup
	printf "\n"
	print_info "🗑️  Cleaning up..."
	rm -f "${TEMP_DIR}"/boxlang*.zip
	# Remove Windows-specific files that may have been downloaded
	rm -f "${DESTINATION_BIN}"/*.bat "${DESTINATION_BIN}"/*.ps1
	rm -f "${DESTINATION_SCRIPTS}"/*.bat "${DESTINATION_SCRIPTS}"/*.ps1

	# Verify installation
	verify_installation "$DESTINATION_BIN" "$SYSTEM_BIN"

	# Create bin directory in BoxLang home for module executables
	local BOXLANG_HOME_BIN="$HOME/.boxlang/bin"
	print_info "📁 Creating BoxLang home bin directory..."
	mkdir -p "$BOXLANG_HOME_BIN"
	print_success "BoxLang home bin directory created at [$BOXLANG_HOME_BIN]"

	# Check PATH for local user execution mostly.
	check_or_set_path "$SYSTEM_BIN" "$SYSTEM_HOME" "$BOXLANG_HOME_BIN"

	printf "${GREEN}"
	printf "─────────────────────────────────────────────────────────────────────────────\n"
	echo "🥊 BoxLang® Installation Directory: [${SYSTEM_HOME}]"
	echo "🔗 System Links: [${SYSTEM_BIN}]"
	echo "🏠 BoxLang® Home is now set to your user home [~/.boxlang] by default"
	echo "${MAGENTA}✅ Remember you can check for updates at any time with: ${GREEN}install-boxlang --check-update${NORMAL}"
	printf "${GREEN}"
	printf "─────────────────────────────────────────────────────────────────────────────\n"
	echo 'BoxLang® - Dynamic : Modular : Productive : https://boxlang.io'
	printf "─────────────────────────────────────────────────────────────────────────────\n"
	echo "BoxLang® is FREE and Open-Source Software under the Apache 2.0 License"
	echo "You can also buy support and enhanced versions at https://boxlang.io/plans"
	echo 'p.s. Follow us at https://x.com/tryboxlang.'
	echo 'p.p.s. Clone us and star us at https://github.com/ortus-boxlang/boxlang'
	echo 'Please support us via Patreon at https://www.patreon.com/ortussolutions'
	printf "─────────────────────────────────────────────────────────────────────────────\n"
	echo "Copyright and Registered Trademarks of Ortus Solutions, Corp"
	printf "${NORMAL}"
}

###########################################################################
# Main Function
###########################################################################
main() {
	local command=""
	local install_argument=""

	# Initialize colors at script startup
	setup_colors

	# Parse arguments to identify command and options
	while [ $# -gt 0 ]; do
		case "$1" in
			"--help"|"-h")
				command="help"
				break
				;;
			"--uninstall")
				command="uninstall"
				break
				;;
			"--check-update")
				command="check-update"
				break
				;;
			"--version"|"-v")
				command="version"
				break
				;;
			"--with-commandbox")
				INSTALL_COMMANDBOX=true
				;;
			"--without-commandbox")
				INSTALL_COMMANDBOX=false
				;;
			"--with-jre")
				JAVA_INSTALL_MODE="automatic"
				;;
			"--without-jre")
				JAVA_INSTALL_MODE="skip"
				;;
			"--boxlang-path")
				BOXLANG_PATH="$2"
				shift
				;;
			"--miniserver-path")
				MINISERVER_PATH="$2"
				shift
				;;
			"--installer-scripts-path")
				INSTALLER_SCRIPTS_PATH="$2"
				shift
				;;
			"--yes"|"-y")
				# Setup all defaults here.
				INSTALL_COMMANDBOX=true
				JAVA_INSTALL_MODE="automatic"
				;;
			"--non-interactive")
				NON_INTERACTIVE=true
				;;
			*)
				install_argument="$1"
				;;
		esac
		shift
	done

	# If no command was specified, it's an install operation
	if [ -z "$command" ]; then
		command="install"
	fi

	# Handle commands
	case "$command" in
		"help")
			show_help
			;;
		"uninstall")
			uninstall_boxlang
			;;
		"check-update")
			check_for_updates
			;;
		"install")
			if [ -n "$install_argument" ]; then
				install_boxlang "$install_argument"
			else
				install_boxlang
			fi
			;;
		"version")
			# Print the installer version
			printf "${GREEN}🥊 BoxLang Installer Version v%s\n" "$INSTALLER_VERSION${NORMAL}"
			;;
		*)
			print_error "Unknown command: $command"
			printf "\n"
			show_help
			exit 1
			;;
	esac
}

# Run main function
main "$@"