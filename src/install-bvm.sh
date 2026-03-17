#!/bin/bash

# BVM (BoxLang Version Manager) Installer
# Downloads the native BVM binary for the current platform from GitHub Releases
# and sets up the BVM environment.
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

INSTALLER_VERSION="@build.version@"
TEMP_DIR="${TMPDIR:-/tmp}"
BVM_HOME="${BVM_HOME:-$HOME/.bvm}"
GITHUB_RELEASES_URL="https://github.com/ortus-boxlang/boxlang-quick-installer/releases/latest/download"

# Helpers
if [ -f "$(dirname "$0")/helpers/helpers.sh" ]; then
	source "$(dirname "$0")/helpers/helpers.sh"
elif [ -f "${BASH_SOURCE%/*}/helpers/helpers.sh" ]; then
	source "${BASH_SOURCE%/*}/helpers/helpers.sh"
elif [ -f "${BVM_HOME}/scripts/helpers.sh" ]; then
	source "${BVM_HOME}/scripts/helpers.sh"
else
	printf "${BLUE}⬇️ Downloading helper functions...${NORMAL}\n"
	helpers_url="https://downloads.ortussolutions.com/ortussolutions/boxlang-quick-installer/helpers/helpers.sh"
	helpers_file="${TEMP_DIR}/helpers.sh"

	if curl -fsSL "$helpers_url" -o "$helpers_file"; then
		source "$helpers_file"
	else
		printf "${RED}Error: Failed to download helper functions from $helpers_url${NORMAL}\n"
		exit 1
	fi
fi

###########################################################################
# Platform Detection
###########################################################################
detect_platform() {
	local os arch
	os="$(uname -s)"
	arch="$(uname -m)"

	case "$os" in
		Linux)
			case "$arch" in
				x86_64|amd64) echo "linux-x64" ;;
				aarch64|arm64) echo "linux-arm64" ;;
				*) print_error "Unsupported Linux architecture: $arch"; exit 1 ;;
			esac
			;;
		Darwin)
			case "$arch" in
				x86_64) echo "macos-x64" ;;
				arm64)  echo "macos-arm64" ;;
				*) print_error "Unsupported macOS architecture: $arch"; exit 1 ;;
			esac
			;;
		*)
			print_error "Unsupported OS: $os (use install-bvm.ps1 on Windows)"
			exit 1
			;;
	esac
}

###########################################################################
# Download and Install Native Binaries
###########################################################################
install_bvm() {
	local platform
	platform="$(detect_platform)"
	local archive_name="boxlang-tools-${platform}.tar.gz"
	local archive_url="${GITHUB_RELEASES_URL}/${archive_name}"
	local archive_path="${TEMP_DIR}/${archive_name}"
	local bin_dir="${BVM_HOME}/bin"

	print_info "Detected platform: ${platform}"
	print_info "Creating BVM directory at [${BVM_HOME}]"
	mkdir -p "${bin_dir}" "${BVM_HOME}/versions" "${BVM_HOME}/cache"

	print_info "Downloading BoxLang tools from: ${archive_url}"
	if ! curl -fsSL --progress-bar -o "${archive_path}" "${archive_url}"; then
		print_error "Failed to download BoxLang tools from ${archive_url}"
		print_info "Ensure you have internet access and the release exists at:"
		print_info "  https://github.com/ortus-boxlang/boxlang-quick-installer/releases/latest"
		exit 1
	fi

	print_info "Extracting binaries to ${bin_dir}..."
	tar -xzf "${archive_path}" -C "${bin_dir}"
	rm -f "${archive_path}"

	print_info "Making binaries executable..."
	chmod -R 755 "${bin_dir}"

	print_success "BVM and tools installed to [${BVM_HOME}/bin]"
}

###########################################################################
# Setup PATH
###########################################################################
setup_path() {
	local bvm_bin="${BVM_HOME}/bin"
	local shell_name="${SHELL##*/}"
	local profile_file

	print_info "Setting up PATH for BVM..."
	profile_file=$(get_shell_profile_file 2>/dev/null || echo "$HOME/.bashrc")

	# Check if BVM is already in PATH
	if echo "$PATH" | grep -q "${bvm_bin}"; then
		print_success "BVM is already in PATH"
		return 0
	fi

	# Check if BVM path is already in profile
	if grep -q "${bvm_bin}" "${profile_file}" 2>/dev/null; then
		print_success "BVM path already configured in ${profile_file}"
		return 0
	fi

	print_info "Adding BVM to PATH in ${profile_file}"
	{
		echo ""
		echo "# Added by BVM (BoxLang Version Manager) installer v${INSTALLER_VERSION}"
		if [ "$shell_name" = "fish" ]; then
			echo "set -gx PATH \"${bvm_bin}\" \$PATH"
			echo "set -gx BVM_HOME \"${BVM_HOME}\""
		else
			echo "export PATH=\"${bvm_bin}:\$PATH\""
			echo "export BVM_HOME=\"${BVM_HOME}\""
		fi
		echo ""
		echo "# Activate the current BoxLang version managed by BVM (if set)"
		if [ "$shell_name" = "fish" ]; then
			echo "if test -L \"\$BVM_HOME/current\""
			echo "    set -gx PATH \"\$BVM_HOME/current/bin\" \$PATH"
			echo "end"
		else
			echo "if [ -L \"\$BVM_HOME/current\" ]; then"
			echo "    export PATH=\"\$BVM_HOME/current/bin:\$PATH\""
			echo "fi"
		fi
	} >> "${profile_file}"

	print_success "Added BVM to PATH in ${profile_file}"

	# Update current session
	export PATH="${bvm_bin}:$PATH"
	export BVM_HOME="${BVM_HOME}"
	if [ -L "${BVM_HOME}/current" ]; then
		export PATH="${BVM_HOME}/current/bin:$PATH"
	fi
}

###########################################################################
# Main installation function
###########################################################################
main() {
	setup_colors

	print_header "📦 BVM (BoxLang Version Manager) Installer v${INSTALLER_VERSION}"
	printf "\n"

	# Install native BVM binary bundle
	if ! install_bvm; then
		exit 1
	fi

	# Setup PATH
	if ! setup_path; then
		exit 1
	fi

	printf "${BLUE}─────────────────────────────────────────────────────────────────────────────${NORMAL}\n"
	print_success "❤️‍🔥 BVM has been installed successfully"
	printf "${BLUE}─────────────────────────────────────────────────────────────────────────────${NORMAL}\n"

	print_info "To start using BVM, either:"
	printf "  1. Restart your terminal, or\n"
	printf "  2. Run: source ~/.bashrc  (or equivalent for your shell)\n"
	printf "\n"
	print_info "Quick start:"
	printf "  ${GREEN}bvm install latest${NORMAL}   # Install latest BoxLang\n"
	printf "  ${GREEN}bvm use latest${NORMAL}       # Activate latest BoxLang\n"
	printf "  ${GREEN}bvm list${NORMAL}             # List installed versions\n"
	printf "  ${GREEN}bvm help${NORMAL}             # Show all BVM commands\n"
	printf "\n"
}

# Run main function
main "$@"
