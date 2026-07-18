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
# Non-verbose by default: routine step-by-step narration is hidden behind an
# animated progress indicator. --verbose/-v shows every step as plain text.
VERBOSE=false

# Helpers
if [ -f "$(dirname "$0")/helpers/helpers.sh" ]; then
	source "$(dirname "$0")/helpers/helpers.sh"
elif [ -f "${BASH_SOURCE%/*}/helpers/helpers.sh" ]; then
	source "${BASH_SOURCE%/*}/helpers/helpers.sh"
elif [ -f "${BVM_HOME}/scripts/helpers.sh" ]; then
	source "${BVM_HOME}/scripts/helpers.sh"
else
	# Download helpers.sh if it doesn't exist locally
	printf "Downloading helper functions...\n"
	helpers_url="https://downloads.ortussolutions.com/ortussolutions/boxlang-quick-installer/helpers/helpers.sh"
	helpers_file="${TEMP_DIR}/helpers.sh"

	if curl -fsSL "$helpers_url" -o "$helpers_file"; then
		source "$helpers_file"
	else
		printf "${RED}Error: Failed to download helper functions from $helpers_url${NORMAL}\n" >&2
		exit 1
	fi
fi

###########################################################################
# Downloads the installer bundle and lays out BVM's directory structure
# (run via run_step)
###########################################################################
_install_bvm_bundle() {
	local bvm_home="$1" temp_dir="$2" installer_url="$3"
	local scripts_dir="$bvm_home/scripts"

	print_verbose "Creating BVM directory at [$bvm_home]"
	mkdir -p "$bvm_home/bin" "$bvm_home/versions" "$bvm_home/cache" "$scripts_dir"

	print_verbose "Downloading BVM from [${installer_url}]"
	curl -fsSL -o "${temp_dir}/boxlang-installer.zip" "${installer_url}"

	print_verbose "Inflating BoxLang installer scripts..."
	unzip -q -o "${temp_dir}/boxlang-installer.zip" -d "${scripts_dir}"
	chmod -R 755 "${scripts_dir}"

	print_verbose "Creating internal links for BoxLang scripts..."
	# Create symlinks for install-bx-module, install-bx-site, bvm
	ln -sf "$scripts_dir/install-bx-module.sh" "$bvm_home/bin/install-bx-module"
	ln -sf "$scripts_dir/install-bx-site.sh" "$bvm_home/bin/install-bx-site"
	ln -sf "$scripts_dir/install-bvm.sh" "$bvm_home/bin/install-bvm"
	ln -sf "$scripts_dir/bvm.sh" "$bvm_home/bin/bvm"

	print_verbose "Creating convenience wrapper scripts..."

	# Create boxlang wrapper
	cat > "$bvm_home/bin/boxlang" << 'EOF'
#!/bin/bash
# BoxLang wrapper script for BVM
exec "$(dirname "$0")/bvm" exec "$@"
EOF

	# Create bx wrapper
	cat > "$bvm_home/bin/bx" << 'EOF'
#!/bin/bash
# BoxLang (bx) wrapper script for BVM
exec "$(dirname "$0")/bvm" exec "$@"
EOF

	# Create boxlang-miniserver wrapper
	cat > "$bvm_home/bin/boxlang-miniserver" << 'EOF'
#!/bin/bash
# BoxLang MiniServer wrapper script for BVM
exec "$(dirname "$0")/bvm" miniserver "$@"
EOF

	# Create bx-miniserver wrapper
	cat > "$bvm_home/bin/bx-miniserver" << 'EOF'
#!/bin/bash
# BoxLang MiniServer (bx-miniserver) wrapper script for BVM
exec "$(dirname "$0")/bvm" miniserver "$@"
EOF

	# Make all wrapper scripts executable
	chmod -R 755 "$bvm_home/bin"/*
}

###########################################################################
# Install BVM
###########################################################################
install_bvm() {
	run_step "BVM installed to [$BVM_HOME]" -- _install_bvm_bundle "$BVM_HOME" "$TEMP_DIR" "$INSTALLER_URL"
}

###########################################################################
# Setup PATH
###########################################################################
setup_path() {
    local bvm_bin="$BVM_HOME/bin"
    local shell_name="${SHELL##*/}"

    print_verbose "Setting up PATH for BVM..."

    # Use helper function to detect shell profile file
    # Intentionally not `local` - show_help() reads this after we return
    profile_file=$(get_shell_profile_file)

    # Check if BVM is already in PATH
    if echo "$PATH" | grep -q "$bvm_bin"; then
        print_verbose "${GREEN}✓${NORMAL} BVM is already in PATH"
        return 0
    fi

    # Check if BVM path is already in profile
    if grep -q "$bvm_bin" "$profile_file" 2>/dev/null; then
        print_verbose "${GREEN}✓${NORMAL} BVM path already configured in $profile_file"
        return 0
    fi

    print_verbose "Adding BVM to PATH in $profile_file"

    # Add BVM to PATH
    {
        echo ""
        echo "# Added by BVM (BoxLang Version Manager) installer"
        if [ "$shell_name" = "fish" ]; then
            echo "set -gx PATH $bvm_bin \$PATH"
        else
            echo "export PATH=\"$bvm_bin:\$PATH\""
        fi
        echo ""
        echo "# BVM environment setup"
        if [ "$shell_name" = "fish" ]; then
            echo "set -gx BVM_HOME $BVM_HOME"
        else
            echo "export BVM_HOME=\"$BVM_HOME\""
        fi
        echo ""
        echo "# BVM provides BoxLang binaries through wrappers when no version is active"
        echo "# Current version takes precedence when available"
        if [ "$shell_name" = "fish" ]; then
            echo "if test -L \"\$BVM_HOME/current\""
            echo "    set -gx PATH \"\$BVM_HOME/current/bin\" \$PATH"
            echo "end"
        else
            echo "if [ -L \"\$BVM_HOME/current\" ]; then"
            echo "    export PATH=\"\$BVM_HOME/current/bin:\$PATH\""
            echo "fi"
        fi
    } >> "$profile_file"

    print_success "Added BVM to PATH in $profile_file"

    # Update current session PATH
    export PATH="$bvm_bin:$PATH"
    export BVM_HOME="$BVM_HOME"
    if [ -L "$BVM_HOME/current" ]; then
        export PATH="$BVM_HOME/current/bin:$PATH"
    fi
}

###########################################################################
# Help and Instructions
###########################################################################
show_help() {
    print_info "To start using BVM, either:"
    printf "  1. Restart your terminal, or\n"
    printf "  2. Run: source %s\n" "$profile_file"
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

	# Parse arguments
	for arg in "$@"; do
		case "$arg" in
			"--verbose"|"-v")
				VERBOSE=true
				;;
		esac
	done

	print_logo
	print_header "BVM (BoxLang Version Manager) Installer"
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

	printf "\n"
	print_success "🎉 BVM was installed successfully."
	printf "\n"

	# Show instructions
	show_help
}

# Run main function
main "$@"
