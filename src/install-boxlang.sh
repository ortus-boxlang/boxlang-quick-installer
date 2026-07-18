#!/bin/bash

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
# empty = prompt, true = install, false = skip
INSTALL_COMMANDBOX=""
INSTALL_JRE=""
# Non-verbose by default: routine step-by-step narration is hidden behind an
# animated progress indicator. --verbose/-v shows every step as plain text.
VERBOSE=false

###########################################################################
# Get current BoxLang install home
###########################################################################
get_boxlang_install_home(){
	# Check common installation locations
	local possible_locations=(
		"/usr/local/boxlang"
		"$HOME/.local/boxlang"
	)

	# Add BOXLANG_INSTALL_HOME if set
	if [ -n "$BOXLANG_INSTALL_HOME" ]; then
    	possible_locations+=("$BOXLANG_INSTALL_HOME")
	fi

	for location in "${possible_locations[@]}"; do
		if [ -d "$location" ]; then
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
	source "$boxlang_home/scripts/helpers/helpers.sh"
elif [ -f "$(dirname "$0")/helpers/helpers.sh" ]; then
	# Source helpers from relative path (development/local setup)
	source "$(dirname "$0")/helpers/helpers.sh"
elif [ -f "${BASH_SOURCE%/*}/helpers/helpers.sh" ]; then
	# Source helpers from script directory (when run via symlink)
	source "${BASH_SOURCE%/*}/helpers/helpers.sh"
else
	# Download helpers.sh if it doesn't exist locally
	printf "Downloading helper functions...\n"
	helpers_url="https://downloads.ortussolutions.com/ortussolutions/boxlang-quick-installer/helpers/helpers.sh"
	helpers_file="${TEMP_DIR}/helpers.sh"

	if curl -fsSL "$helpers_url" -o "$helpers_file"; then
		chmod +x "$helpers_file"
		source "$helpers_file"
	else
		printf "${RED}Error: Failed to download helper functions from [$helpers_url] to [${TEMP_DIR}]${NORMAL}\n" >&2
		exit 1
	fi
fi


###########################################################################
# Get current installed BoxLang version
###########################################################################
get_current_version() {
	local current_version=""

	# Try to find BoxLang in common locations
	local boxlang_candidates=(
		"boxlang"                              # In PATH
		"/usr/local/bin/boxlang"               # System install (symbolic link)
		"$HOME/.local/bin/boxlang"             # User install (symbolic link)
		"/usr/local/boxlang/bin/boxlang"       # System BoxLang installation
		"$HOME/.local/boxlang/bin/boxlang"     # User BoxLang installation
	)

	# Add BOXLANG_INSTALL_HOME if set
	if [ -n "$BOXLANG_INSTALL_HOME" ]; then
    	boxlang_candidates+=("$BOXLANG_INSTALL_HOME/bin/boxlang")
	fi

	for candidate in "${boxlang_candidates[@]}"; do
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
	print_logo
	print_info "Checking for BoxLang updates..."

	# Get current version
	local current_version
	current_version=$(get_current_version) || true
	if [ -z "$current_version" ]; then
		print_warning "BoxLang is not currently installed"
		current_version="0.0.0"
	fi

	# Get latest version
	local latest_version
	latest_version=$(get_latest_version) || true
	if [ -z "$latest_version" ]; then
		print_error "Failed to fetch latest version information"
		print_warning "Please check your internet connection and try again"
		return 1
	fi

	printf "Current version: ${BOLD}${current_version}${NORMAL}\n"
	printf "Latest version:  ${BOLD}${latest_version}${NORMAL}\n\n"

	# Compare versions
	local comparison_result=0
	compare_versions "$current_version" "$latest_version" || comparison_result=$?

	case $comparison_result in
		0)
			print_success "You have the latest version of BoxLang"
			return 0
			;;
		1)
			print_info "You have a newer version than the latest release (development or snapshot build)"
			return 0
			;;
		2)
			print_info "🔄 A newer version of BoxLang is available."
			printf "Update to version ${latest_version}? [Y/n] "
			read -r response < /dev/tty
			case "$response" in
				[nN][oO]|[nN])
					print_info "Update cancelled"
					return 0
					;;
				*)
					print_info "Updating to BoxLang ${latest_version}..."
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
	if [ -f "$profile_file" ] && grep -Fq "BOXLANG_INSTALL_HOME" "$profile_file"; then
		install_home_exists=true
	fi

	# If all entries exist, we're done
	if [ "$path_exists" = true ] && [ "$install_home_exists" = true ]; then
		if [ -z "$boxlang_home_bin" ] || [ "$boxlang_home_bin_exists" = true ]; then
			print_verbose "${GREEN}✓${NORMAL} PATH entry and BOXLANG_INSTALL_HOME already exist in $profile_file"
			return 0
		fi
	fi

	# If PATH exists but BOXLANG_INSTALL_HOME doesn't, add only the install home
	if [ "$path_exists" = true ] && [ "$install_home_exists" = false ]; then
		print_verbose "Adding BOXLANG_INSTALL_HOME to $profile_file (upgrade from older installation)..."
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
		print_verbose "Adding [$bin_dir] and [$boxlang_home_bin] to PATH in [$profile_file]..."
	else
		print_verbose "Adding [$bin_dir] to PATH in [$profile_file]..."
	fi
	print_verbose "Adding BOXLANG_INSTALL_HOME [$install_home] in [$profile_file]..."

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
		print_success "Added [$bin_dir] and [$boxlang_home_bin] to PATH in [$profile_file]"
	else
		print_success "Added [$bin_dir] to PATH in [$profile_file]"
	fi

	print_warning "Restart your terminal or run: source $profile_file"

	# Update current session PATH
	if [ -n "$boxlang_home_bin" ]; then
		export PATH="$bin_dir:$boxlang_home_bin:$PATH"
	else
		export PATH="$bin_dir:$PATH"
	fi
	export BOXLANG_INSTALL_HOME="$install_home"
}

###########################################################################
# Downloads, extracts, and links the CommandBox binary (run via run_step)
###########################################################################
_install_commandbox_binary() {
	local system_bin="$1" boxlang_bin="$2" commandbox_url="$3" commandbox_filename="$4" temp_dir="$5"
	curl -fsSL -o "${temp_dir}/${commandbox_filename}" "${commandbox_url}"
	unzip -q -o "${temp_dir}/${commandbox_filename}" -d "${temp_dir}/commandbox/"
	mv "${temp_dir}/commandbox/box" "${boxlang_bin}/box"
	chmod 755 "${boxlang_bin}/box"
	ln -sf "${boxlang_bin}/box" "${system_bin}/box"
	rm -rf "${temp_dir}/${commandbox_filename}" "${temp_dir}/commandbox/"
}

###########################################################################
# CommandBox Installation Check and Install Function
###########################################################################
check_and_install_commandbox() {
	local system_bin="$1"
	local boxlang_bin="$2"

	print_verbose "Checking for CommandBox..."

	# Check if CommandBox is already available
	if command_exists box; then
		print_verbose "${GREEN}✓${NORMAL} CommandBox is already installed and available"
		return 0
	fi

	# Determine if we should install CommandBox based on flags
	local should_install=""
	if [ "$INSTALL_COMMANDBOX" = "true" ]; then
		should_install="yes"
	elif [ "$INSTALL_COMMANDBOX" = "false" ]; then
		should_install="no"
		print_verbose "Skipping CommandBox installation (--without-commandbox specified)"
	else
		# Interactive mode - ask user
		print_info "CommandBox is the package manager for BoxLang®, used to manage modules, dependencies, and servlet containers."
		printf "Install CommandBox? [Y/n] "
		read -r response < /dev/tty
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
		print_info "You can install CommandBox later from: https://commandbox.ortusbooks.com/setup/installation"
		return 0
	fi

	# The universal binary for mac/linux is available at the following URL
	local commandbox_url="https://www.ortussolutions.com/parent/download/commandbox/type/bin"
	local commandbox_filename="commandbox.zip"

	if ! run_step "📦 CommandBox installed" -- _install_commandbox_binary "$system_bin" "$boxlang_bin" "$commandbox_url" "$commandbox_filename" "$TEMP_DIR"; then
		print_error "Failed to install CommandBox"
		print_info "Please manually install CommandBox from: https://commandbox.ortusbooks.com/setup/installation"
		return 1
	fi
	return 0
}

###########################################################################
# Installation Verification Function
###########################################################################
verify_installation() {
	local bin_dir="$1"
	local system_bin="$2"
	print_verbose "Verifying installation..."

	# Make sure BoxLang binary can emit version information
	if ! "${bin_dir}/boxlang" --version >/dev/null 2>&1; then
		print_error "BoxLang installation verification failed"
		return 1
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
			print_verbose "${GREEN}✓${NORMAL} CommandBox is installed and linked"
		fi
	fi

	print_verbose "${GREEN}✓${NORMAL} Installation verified"
	return 0
}

###########################################################################
# Uninstall BoxLang
###########################################################################
uninstall_boxlang() {
	print_logo
	print_warning "🗑️  Uninstalling BoxLang..."

	# Remove symbolic links from system bin directories
	print_verbose "Removing system symbolic links..."
	rm -fv /usr/local/bin/boxlang
	rm -fv /usr/local/bin/bx
	rm -fv /usr/local/bin/boxlang-miniserver
	rm -fv /usr/local/bin/bx-miniserver
	rm -fv /usr/local/bin/install-bx-module
	rm -fv /usr/local/bin/install-boxlang
	rm -fv /usr/local/bin/install-bvm

	# Remove BoxLang installation directory
	print_verbose "Removing previous BoxLang installation directory..."
	rm -rfv /usr/local/boxlang

	# Remove legacy JAR files if they exist
	print_verbose "Removing legacy JAR files (if any)..."
	rm -fv /usr/local/lib/boxlang-*.jar

	# Also check user-local installation
	if [ -d "$HOME/.local/bin" ]; then
		print_verbose "Checking user-local installation..."
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
		print_verbose "Removing user-local BoxLang installation directory..."
		rm -rfv "$HOME/.local/boxlang"
	fi

	# Remove legacy user lib files if they exist
	if [ -d "$HOME/.local/lib" ]; then
		rm -fv "$HOME/.local/lib/boxlang-*.jar"
	fi

	print_success "BoxLang uninstalled successfully"
	print_info "BoxLang Home directory (~/.boxlang) was preserved. To remove it completely, run: rm -rf ~/.boxlang"
}

###########################################################################
# Help Function
###########################################################################
show_help() {
	printf "${BOLD}BoxLang® Quick Installer${NORMAL} v${INSTALLER_VERSION}\n"
	printf "Installs the BoxLang® runtime, MiniServer, and tools.\n\n"
	printf "${BOLD}Usage:${NORMAL}\n"
	printf "  install-boxlang [version] [options]\n\n"
	printf "${BOLD}Arguments:${NORMAL}\n"
	printf "  [version]              'latest' (default), 'snapshot', or a specific version like '1.2.0'\n\n"
	printf "${BOLD}Options:${NORMAL}\n"
	printf "  --help, -h             Show this help message\n"
	printf "  --uninstall            Remove BoxLang from the system\n"
	printf "  --check-update         Check if a newer version is available\n"
	printf "  --system               Force system-wide installation (requires sudo)\n"
	printf "  --force                Force reinstallation even if already installed\n"
	printf "  --with-commandbox      Install CommandBox without prompting\n"
	printf "  --without-commandbox   Skip CommandBox installation\n"
	printf "  --with-jre             Automatically install Java 21 JRE if not found\n"
	printf "  --without-jre          Skip Java installation (manual installation required)\n"
	printf "  --yes, -y              Use defaults for all prompts (installs CommandBox and Java)\n"
	printf "  --verbose, -v          Show every step instead of the progress indicator\n\n"
	printf "${BOLD}Examples:${NORMAL}\n"
	printf "  install-boxlang\n"
	printf "  install-boxlang snapshot\n"
	printf "  install-boxlang 1.2.0 --force\n"
	printf "  install-boxlang --yes\n"
	printf "  install-boxlang --uninstall\n"
	printf "  install-boxlang --check-update\n"
	printf "  sudo install-boxlang --system\n\n"
	printf "${BOLD}Non-interactive:${NORMAL}\n"
	printf "  curl -fsSL https://boxlang.io/install.sh | bash -s -- --yes\n"
	printf "  curl -fsSL https://boxlang.io/install.sh | bash -s -- --with-jre --with-commandbox\n"
}

###########################################################################
# Remove Previous Installation Function
###########################################################################
remove_previous_installation() {
	# Remove previous BoxLang installation if it exists
	if [ -d "${SYSTEM_HOME}" ]; then
		print_warning "Removing previous BoxLang installation..."
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
		print_warning "Removing old BoxLang classes from home directory..."
		rm -rf "$HOME/.boxlang/classes"
	fi
}

###########################################################################
# Downloads the BoxLang runtime, MiniServer, and installer bundle (run via run_step)
###########################################################################
_download_boxlang_assets() {
	local temp_dir="$1" download_url="$2" download_url_miniserver="$3" installer_url="$4"
	rm -f "${temp_dir}/boxlang.zip"
	curl -fsSL -o "${temp_dir}/boxlang.zip" "${download_url}"
	rm -f "${temp_dir}/boxlang-miniserver.zip"
	curl -fsSL -o "${temp_dir}/boxlang-miniserver.zip" "${download_url_miniserver}"
	rm -f "${temp_dir}/boxlang-installer.zip"
	curl -fsSL -o "${temp_dir}/boxlang-installer.zip" "${installer_url}"
}

###########################################################################
# Unzips assets, sets permissions, and links binaries (run via run_step)
###########################################################################
_setup_boxlang_assets() {
	local system_home="$1" system_bin="$2" destination_bin="$3" destination_scripts="$4" temp_dir="$5"
	unzip -q -o "${temp_dir}/boxlang.zip" -d "${system_home}"
	unzip -q -o "${temp_dir}/boxlang-miniserver.zip" -d "${system_home}"
	unzip -q -o "${temp_dir}/boxlang-installer.zip" -d "${system_home}/scripts"
	chmod -R 755 "${system_home}"

	# BoxLang binaries with aliases
	ln -sf "${destination_bin}/boxlang" "${system_bin}/boxlang"
	ln -sf "${system_bin}/boxlang" "${system_bin}/bx"
	# MiniServer binaries with aliases
	ln -sf "${destination_bin}/boxlang-miniserver" "${system_bin}/boxlang-miniserver"
	ln -sf "${system_bin}/boxlang-miniserver" "${system_bin}/bx-miniserver"
	# Helper scripts
	ln -sf "${destination_scripts}/install-boxlang.sh" "${system_bin}/install-boxlang"
	ln -sf "${destination_scripts}/install-bx-module.sh" "${system_bin}/install-bx-module"
	ln -sf "${destination_scripts}/install-bx-site.sh" "${system_bin}/install-bx-site"
	ln -sf "${destination_scripts}/install-bvm.sh" "${system_bin}/install-bvm"
	ln -sf "${destination_scripts}/bvm.sh" "${system_bin}/bvm"

	# Cleanup
	rm -f "${temp_dir}"/boxlang*.zip
	# Remove Windows-specific files that may have been downloaded
	rm -f "${destination_bin}"/*.bat "${destination_bin}"/*.ps1
	rm -f "${destination_scripts}"/*.bat "${destination_scripts}"/*.ps1
}

###########################################################################
# Handle the main installation
###########################################################################
install_boxlang() {
	local args=("$@")

	# Check for --force flag in any position and remove it from args
	local FORCE_INSTALL=false
	local new_args=()
	for arg in "${args[@]}"; do
		if [ "$arg" = "--force" ]; then
			FORCE_INSTALL=true
		elif [ "$arg" = "--system" ]; then
			new_args+=("$arg")
		else
			new_args+=("$arg")
		fi
	done

	# Check target version argument, this could be "latest", "snapshot", or a specific version like "1.2.0" or empty for latest
	local TARGET_VERSION=${new_args[0]:-latest}
	# If the version is "snapshot", always force it
	if [ "$TARGET_VERSION" = "snapshot" ]; then
		FORCE_INSTALL=true
	fi

	print_logo

	###########################################################################
	# Pre-flight Checks
	# This function checks for necessary tools and environment
	###########################################################################
	if ! preflight_check "$INSTALL_JRE"; then
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
		print_verbose "Checking for existing BoxLang installation..."
		local CURRENT_VERSION=$(get_current_version)
		if [ $? -eq 0 ] && [ -n "$CURRENT_VERSION" ]; then
			print_warning "BoxLang is already installed at [${SYSTEM_HOME}] with version [${CURRENT_VERSION}]"
			printf "Use 'install-boxlang --uninstall' to remove it, '--force' to reinstall, or '--help' for more options.\n"
			exit 0;
		else
			print_verbose "${GREEN}✓${NORMAL} No previous BoxLang installation found, proceeding with fresh install..."
		fi
	else
		print_warning "Forcing reinstallation of BoxLang..."
		remove_previous_installation || {
			print_error "Failed to remove previous installation, please see log for more information"
			exit 1
		}
	fi

	###########################################################################
	# Support user-local installation if not running as root and not explicitly system install
	###########################################################################
	if [ "$EUID" -ne 0 ] && [[ ! " ${new_args[@]} " =~ " --system " ]]; then
		print_warning "Installing to user directory (~/.local) since not running as root. Use 'sudo install-boxlang' for system-wide installation."
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
	print_info "Installing BoxLang® [${TARGET_VERSION}] to [${SYSTEM_HOME}]"

	# Download the runtime, MiniServer, and installer bundle
	if ! run_step "Downloaded BoxLang®" -- _download_boxlang_assets "$TEMP_DIR" "$DOWNLOAD_URL" "$DOWNLOAD_URL_MINISERVER" "$INSTALLER_URL"; then
		print_error "Download of BoxLang® failed"
		exit 1
	fi

	# Unzip, set permissions, and link binaries
	if ! run_step "BoxLang® is set up" -- _setup_boxlang_assets "$SYSTEM_HOME" "$SYSTEM_BIN" "$DESTINATION_BIN" "$DESTINATION_SCRIPTS" "$TEMP_DIR"; then
		print_error "Setting up BoxLang® failed"
		exit 1
	fi

	# CommandBox Installation
	# In the future this will be part of BoxLang
	check_and_install_commandbox "$SYSTEM_BIN" "$DESTINATION_BIN"

	# Verify installation
	verify_installation "$DESTINATION_BIN" "$SYSTEM_BIN"

	# Create bin directory in BoxLang home for module executables
	local BOXLANG_HOME_BIN="$HOME/.boxlang/bin"
	mkdir -p "$BOXLANG_HOME_BIN"

	# Check PATH for local user execution mostly.
	check_or_set_path "$SYSTEM_BIN" "$SYSTEM_HOME" "$BOXLANG_HOME_BIN"

	printf "\n"
	print_success "🎉 BoxLang® was installed successfully."
	printf "\n"
	printf "Installed to:  ${BOLD}${SYSTEM_HOME}${NORMAL}\n"
	printf "System links:  ${BOLD}${SYSTEM_BIN}${NORMAL}\n"
	printf "BoxLang Home:  ${BOLD}~/.boxlang${NORMAL}\n"
	printf "\n"
	printf "Run it with: ${BOLD}boxlang${NORMAL} (or ${BOLD}bx${NORMAL})\n"
	printf "Check for updates any time with: ${BOLD}install-boxlang --check-update${NORMAL}\n"
	printf "\n"
	printf "BoxLang® is free and open-source under the Apache 2.0 License.\n"
	printf "Docs: https://boxlang.io  •  Support: https://boxlang.io/plans  •  GitHub: https://github.com/ortus-boxlang/boxlang\n"
}

###########################################################################
# Main Function
###########################################################################
main() {
	local command=""
	local args=()

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
			"--version")
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
				INSTALL_JRE=true
				;;
			"--without-jre")
				INSTALL_JRE=false
				;;
			"--verbose"|"-v")
				VERBOSE=true
				;;
			"--yes"|"-y")
				# Setup all defaults here.
				INSTALL_COMMANDBOX=true
				INSTALL_JRE=true
				;;
			*)
				args+=("$1")
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
			install_boxlang "${args[@]}"
			;;
		"version")
			printf "BoxLang Installer v%s\n" "$INSTALLER_VERSION"
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