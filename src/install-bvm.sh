#!/bin/bash

# BVM (BoxLang Version Manager) Installer
# This script installs BVM and sets up the environment
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

# Global variables
TEMP_DIR="${TMPDIR:-/tmp}"
BVM_HOME="${BVM_HOME:-$HOME/.bvm}"
BVM_SOURCE_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang-quick-installer/bvm.sh"
INSTALLER_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang-quick-installer/boxlang-installer.zip"
BVM_INIT_FILE="$BVM_HOME/scripts/bvm-init.sh"
BVM_FISH_INIT_FILE="$BVM_HOME/scripts/bvm-init.fish"
BVM_PROFILE_FILE=""
LOCAL_INSTALL=false

# Helpers
if [ -f "$(dirname "$0")/helpers/helpers.sh" ]; then
	source "$(dirname "$0")/helpers/helpers.sh"
elif [ -f "${BASH_SOURCE%/*}/helpers/helpers.sh" ]; then
	source "${BASH_SOURCE%/*}/helpers/helpers.sh"
elif [ -f "${BVM_HOME}/scripts/helpers.sh" ]; then
	source "${BVM_HOME}/scripts/helpers.sh"
else
	# Download helpers.sh if it doesn't exist locally
	printf "${BLUE}⬇️ Downloading helper functions...${NORMAL}\n"
	printf "${BLUE}─────────────────────────────────────────────────────────────────────────────${NORMAL}\n"
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
# Install BVM
###########################################################################
install_bvm() {
    # Create BVM directory
    print_info "Creating BVM directory at [$BVM_HOME]"
    mkdir -p "$BVM_HOME/bin" "$BVM_HOME/versions" "$BVM_HOME/cache" "$BVM_HOME/scripts"
    local bvm_script="$BVM_HOME/bin/bvm"
	local scripts_dir="$BVM_HOME/scripts"

	###########################################################################
	# Download BoxLang Installer Scripts
	###########################################################################
    local installer_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ "$LOCAL_INSTALL" = true ]; then
        print_info "Installing BVM scripts locally from [$installer_dir]"
        cp -R "$installer_dir"/. "$scripts_dir"/
    else
        print_info "Downloading BVM from [${INSTALLER_URL}]"
        env curl -L --progress-bar -o "${TEMP_DIR}"/boxlang-installer.zip "${INSTALLER_URL}" || {
            print_error "Error: Download of BoxLang® Installer bundle failed"
            exit 1
        }

        #######################################################################
        # Inflate them
        #######################################################################
        print_info "Inflating BoxLang installer scripts..."
        unzip -q -o "${TEMP_DIR}"/boxlang-installer.zip -d "${scripts_dir}"
    fi

    # Local installs copy the initialization files directly from the source directory.
    if [ -f "$installer_dir/bvm-init.sh" ]; then
        cp "$installer_dir/bvm-init.sh" "$BVM_INIT_FILE"
    fi
    if [ ! -f "$BVM_INIT_FILE" ]; then
        print_error "BVM initialization file was not found in the installer bundle"
        exit 1
    fi
    if [ -f "$installer_dir/bvm-init.fish" ]; then
        cp "$installer_dir/bvm-init.fish" "$BVM_FISH_INIT_FILE"
    fi
    if [ ! -f "$BVM_FISH_INIT_FILE" ]; then
        print_error "BVM fish initialization file was not found in the installer bundle"
        exit 1
    fi

	###########################################################################
	# Make them executable
	###########################################################################
	print_info "Making BoxLang installer scripts executable..."
	chmod -R 755 "${scripts_dir}"

	###########################################################################
	# Add internal links within BoxLang home
	###########################################################################

	print_info "Creating internal links for BoxLang scripts..."
	# Create symlinks for install-bx-module, install-bx-site, bvm
	ln -sf "$scripts_dir/install-bx-module.sh" "$BVM_HOME/bin/install-bx-module"
	ln -sf "$scripts_dir/install-bx-site.sh" "$BVM_HOME/bin/install-bx-site"
	ln -sf "$scripts_dir/install-bvm.sh" "$BVM_HOME/bin/install-bvm"
	ln -sf "$scripts_dir/bvm.sh" "$BVM_HOME/bin/bvm"

    # Create convenience wrapper scripts for direct access to BoxLang tools
    print_info "Creating convenience wrapper scripts..."

    # Create boxlang wrapper
    cat > "$BVM_HOME/bin/boxlang" << 'EOF'
#!/bin/bash
# BoxLang wrapper script for BVM
exec "$(dirname "$0")/bvm" exec "$@"
EOF

    # Create bx wrapper
    cat > "$BVM_HOME/bin/bx" << 'EOF'
#!/bin/bash
# BoxLang (bx) wrapper script for BVM
exec "$(dirname "$0")/bvm" exec "$@"
EOF

    # Create boxlang-miniserver wrapper
    cat > "$BVM_HOME/bin/boxlang-miniserver" << 'EOF'
#!/bin/bash
# BoxLang MiniServer wrapper script for BVM
exec "$(dirname "$0")/bvm" miniserver "$@"
EOF

    # Create bx-miniserver wrapper
    cat > "$BVM_HOME/bin/bx-miniserver" << 'EOF'
#!/bin/bash
# BoxLang MiniServer (bx-miniserver) wrapper script for BVM
exec "$(dirname "$0")/bvm" miniserver "$@"
EOF

    # Make all wrapper scripts executable
    chmod -R 755 "$BVM_HOME/bin"/*
    print_success "BVM script and wrappers installed to [$BVM_HOME]"
}

###########################################################################
# Setup PATH
###########################################################################
setup_path() {
    local shell_name="${SHELL##*/}"
    local profile_init_marker="BVM (BoxLang Version Manager) shell initialization"

    # Use helper function to detect shell profile file
    BVM_PROFILE_FILE=$(get_shell_profile_file)

    if [ "$shell_name" = "fish" ]; then
        if ! grep -Fq "$profile_init_marker" "$BVM_PROFILE_FILE" 2>/dev/null; then
            {
                printf "\n# BVM (BoxLang Version Manager) shell initialization\n"
                printf "set -q BVM_HOME; or set -gx BVM_HOME \$HOME/.bvm\n"
                printf "test -s \"\$BVM_HOME/scripts/bvm-init.fish\"; and source \"\$BVM_HOME/scripts/bvm-init.fish\"\n"
            } >> "$BVM_PROFILE_FILE"
        fi
    elif ! grep -Fq "$profile_init_marker" "$BVM_PROFILE_FILE" 2>/dev/null; then
        {
            printf "\n# BVM (BoxLang Version Manager) shell initialization\n"
            printf "export BVM_HOME=\"\${BVM_HOME:-\$HOME/.bvm}\"\n"
            printf "[ -s \"\$BVM_HOME/scripts/bvm-init.sh\" ] && . \"\$BVM_HOME/scripts/bvm-init.sh\"\n"
        } >> "$BVM_PROFILE_FILE"
    fi

    print_success "Added BVM initialization to $BVM_PROFILE_FILE"

    # Update the current installer process as well.
    . "$BVM_INIT_FILE"
}

###########################################################################
# Help and Instructions
###########################################################################
show_help() {
    print_info "To start using BVM, either:"
    printf "  1. Restart your terminal, or\n"
    printf "  2. Run: source \"%s\"\n" "$BVM_PROFILE_FILE"
    printf "\n"
    print_info "Common BVM commands:"
    printf "  ${GREEN}bvm install latest${NORMAL}      # Install latest BoxLang\n"
    printf "  ${GREEN}bvm use latest${NORMAL}          # Use latest BoxLang\n"
    printf "  ${GREEN}bvm list${NORMAL}                # List installed versions\n"
    printf "  ${GREEN}bvm current${NORMAL}             # Show current version\n"
    printf "  ${GREEN}bvm help${NORMAL}                # Show help\n"
    printf "\n"
    print_info "Direct BoxLang commands (after setup):"
    printf "  ${GREEN}boxlang${NORMAL} or ${GREEN}bx${NORMAL}              # Run BoxLang REPL\n"
    printf "  ${GREEN}boxlang-miniserver${NORMAL}      # Start MiniServer\n"
    printf "  ${GREEN}install-bx-module${NORMAL}       # Install BoxLang modules\n"
    printf "  ${GREEN}install-bx-site${NORMAL}         # Install BoxLang site templates\n"
    printf "\n"
    print_info "Quick start:"
    printf "  ${BLUE}bvm install latest && bvm use latest${NORMAL}\n"
    printf "\n"
}

###########################################################################
# Main installation function
###########################################################################
main() {
	setup_colors

    if [ "${1:-}" = "--local" ]; then
        LOCAL_INSTALL=true
    fi

    print_header "📦 BVM (BoxLang Version Manager) Installer"
    printf "\n"

	# Pre-flight Checks
	if ! preflight_check; then
		exit 1
	fi

    # Install BVM
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

    # Show instructions
    show_help
}

# Run main function
main "$@"
