#!/bin/bash

# BVM (BoxLang Version Manager) Installer
# This script installs BVM and sets up the environment
# Author: BoxLang Team
# Version: @build.version@
# License: Apache License, Version 2.0

# Only enable exit-on-error after the non-critical colorization stuff,
# which may fail on systems lacking tput or terminfo
set -e

###########################################################################
# Global Variables + Helpers
###########################################################################

# Global variables
BVM_HOME="${BVM_HOME:-$HOME/.bvm}"
BVM_SOURCE_URL="https://raw.githubusercontent.com/ortus-boxlang/boxlang-quick-installer/main/src/bvm.sh"

# Helpers
if [ -f "$(dirname "$0")/helpers/helpers.sh" ]; then
	source "$(dirname "$0")/helpers/helpers.sh"
elif [ -f "${BASH_SOURCE%/*}/helpers/helpers.sh" ]; then
	source "${BASH_SOURCE%/*}/helpers/helpers.sh"
else
	# Download helpers.sh if it doesn't exist locally
	printf "${BLUE}⬇️ Downloading helper functions...${NORMAL}\n"
	helpers_url="https://raw.githubusercontent.com/ortus-boxlang/boxlang-quick-installer/refs/heads/development/src/helpers/helpers.sh"
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
    print_header "Installing BoxLang Version Manager (BVM)"

    # Create BVM directory
    print_info "Creating BVM directory at $BVM_HOME"
    mkdir -p "$BVM_HOME/bin" "$BVM_HOME/versions" "$BVM_HOME/cache"

    # Download BVM script
    local bvm_script="$BVM_HOME/bin/bvm"
    print_info "Downloading BVM script..."

    # For now, copy from local source since we're in development
    if [ -f "$(dirname "$0")/bvm.sh" ]; then
        cp "$(dirname "$0")/bvm.sh" "$bvm_script"
    else
        # Fallback to curl if we're installing from remote
        if ! curl -fsSL "$BVM_SOURCE_URL" -o "$bvm_script"; then
            print_error "Failed to download BVM script"
            return 1
        fi
    fi

    # Make BVM executable
    chmod +x "$bvm_script"

    # Install helper scripts that are part of BVM project
    print_info "Installing BVM helper scripts..."
    local scripts_dir="$BVM_HOME/scripts"
    mkdir -p "$scripts_dir"

    # Copy helper scripts from project if available locally
    local project_dir="$(dirname "$0")"
    if [ -f "$project_dir/install-bx-module.sh" ]; then
        cp "$project_dir/install-bx-module.sh" "$scripts_dir/"
        chmod +x "$scripts_dir/install-bx-module.sh"
        print_info "Installed install-bx-module.sh"
    fi

    if [ -f "$project_dir/install-bx-site.sh" ]; then
        cp "$project_dir/install-bx-site.sh" "$scripts_dir/"
        chmod +x "$scripts_dir/install-bx-site.sh"
        print_info "Installed install-bx-site.sh"
    fi

    # If scripts weren't found locally, download them (for remote installation)
    if [ ! -f "$scripts_dir/install-bx-module.sh" ] || [ ! -f "$scripts_dir/install-bx-site.sh" ]; then
        print_info "Downloading helper scripts from remote..."
        local base_url="https://raw.githubusercontent.com/ortus-boxlang/boxlang-quick-installer/main/src"

        if [ ! -f "$scripts_dir/install-bx-module.sh" ]; then
            if curl -fsSL "$base_url/install-bx-module.sh" -o "$scripts_dir/install-bx-module.sh"; then
                chmod +x "$scripts_dir/install-bx-module.sh"
                print_info "Downloaded install-bx-module.sh"
            else
                print_warning "Failed to download install-bx-module.sh"
            fi
        fi

        if [ ! -f "$scripts_dir/install-bx-site.sh" ]; then
            if curl -fsSL "$base_url/install-bx-site.sh" -o "$scripts_dir/install-bx-site.sh"; then
                chmod +x "$scripts_dir/install-bx-site.sh"
                print_info "Downloaded install-bx-site.sh"
            else
                print_warning "Failed to download install-bx-site.sh"
            fi
        fi
    fi

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

    # Create install-bx-module wrapper
    cat > "$BVM_HOME/bin/install-bx-module" << 'EOF'
#!/bin/bash
# BoxLang module installer wrapper script for BVM
BVM_HOME="${BVM_HOME:-$HOME/.bvm}"
if [ -x "$BVM_HOME/scripts/install-bx-module.sh" ]; then
    exec "$BVM_HOME/scripts/install-bx-module.sh" "$@"
else
    echo "Error: install-bx-module.sh not found in BVM installation"
    exit 1
fi
EOF

    # Create install-bx-site wrapper
    cat > "$BVM_HOME/bin/install-bx-site" << 'EOF'
#!/bin/bash
# BoxLang site installer wrapper script for BVM
BVM_HOME="${BVM_HOME:-$HOME/.bvm}"
if [ -x "$BVM_HOME/scripts/install-bx-site.sh" ]; then
    exec "$BVM_HOME/scripts/install-bx-site.sh" "$@"
else
    echo "Error: install-bx-site.sh not found in BVM installation"
    exit 1
fi
EOF

    # Make all wrapper scripts executable
    chmod +x "$BVM_HOME/bin"/*

    print_success "BVM script and wrappers installed to $BVM_HOME/bin"
}

###########################################################################
# Setup PATH
###########################################################################
setup_path() {
    local bvm_bin="$BVM_HOME/bin"
    local profile_file=""
    local shell_name="${SHELL##*/}"

    print_info "Setting up PATH for BVM..."

    # Detect shell profile file
    case "$shell_name" in
        "bash")
            if [ -f "$HOME/.bash_profile" ]; then
                profile_file="$HOME/.bash_profile"
            elif [ -f "$HOME/.bashrc" ]; then
                profile_file="$HOME/.bashrc"
            else
                profile_file="$HOME/.bash_profile"
                touch "$profile_file"
            fi
            ;;
        "zsh")
            profile_file="$HOME/.zshrc"
            [ ! -f "$profile_file" ] && touch "$profile_file"
            ;;
        "fish")
            profile_file="$HOME/.config/fish/config.fish"
            mkdir -p "$(dirname "$profile_file")"
            [ ! -f "$profile_file" ] && touch "$profile_file"
            ;;
        *)
            profile_file="$HOME/.profile"
            [ ! -f "$profile_file" ] && touch "$profile_file"
            ;;
    esac

    # Check if BVM is already in PATH
    if echo "$PATH" | grep -q "$bvm_bin"; then
        print_success "BVM is already in PATH"
        return 0
    fi

    # Check if BVM path is already in profile
    if grep -q "$bvm_bin" "$profile_file" 2>/dev/null; then
        print_success "BVM path already configured in $profile_file"
        return 0
    fi

    print_info "Adding BVM to PATH in $profile_file"

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
    print_header "Installation Complete!"
    printf "\n"
    print_success "BVM has been installed successfully"
    printf "\n"
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

    print_header "BVM (BoxLang Version Manager) Installer"
    printf "\n"

    ###########################################################################
	# Pre-flight Checks
	# This function checks for necessary tools and environment
	###########################################################################
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

    # Show instructions
    show_help
}

# Run main function
main "$@"
