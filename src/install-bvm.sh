#!/bin/bash
# BVM (BoxLang Version Manager) Installer
# This script installs BVM and sets up the environment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NORMAL='\033[0m'

# Initialize colors if terminal supports them
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && tput colors >/dev/null 2>&1; then
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"
    BOLD="$(tput bold)"
    NORMAL="$(tput sgr0)"
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    BOLD=""
    NORMAL=""
fi

# Global variables
BVM_HOME="${BVM_HOME:-$HOME/.bvm}"
BVM_SOURCE_URL="https://raw.githubusercontent.com/ortus-boxlang/boxlang-quick-installer/main/src/bvm.sh"

# Print functions
print_info() {
    printf "${BLUE}ℹ $1${NORMAL}\n"
}

print_success() {
    printf "${GREEN}✅ $1${NORMAL}\n"
}

print_warning() {
    printf "${YELLOW}⚠️  $1${NORMAL}\n"
}

print_error() {
    printf "${RED}❌ $1${NORMAL}\n"
}

print_header() {
    printf "${BOLD}${GREEN}$1${NORMAL}\n"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."

    local missing_deps=()

    command_exists curl || missing_deps+=("curl")
    command_exists unzip || missing_deps+=("unzip")
    command_exists jq || missing_deps+=("jq")

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"

        if [ "$(uname)" = "Darwin" ]; then
            print_info "On macOS, install missing dependencies with Homebrew:"
            for dep in "${missing_deps[@]}"; do
                printf "  brew install %s\n" "$dep"
            done
        elif [ "$(uname)" = "Linux" ]; then
            if command_exists apt-get; then
                print_info "On Ubuntu/Debian, install with:"
                printf "  sudo apt update && sudo apt install %s\n" "${missing_deps[*]}"
            elif command_exists yum; then
                print_info "On RHEL/CentOS, install with:"
                printf "  sudo yum install %s\n" "${missing_deps[*]}"
            elif command_exists pacman; then
                print_info "On Arch Linux, install with:"
                printf "  sudo pacman -S %s\n" "${missing_deps[*]}"
            fi
        fi

        return 1
    fi

    print_success "All prerequisites satisfied"
    return 0
}

# Install BVM
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
exec "$(dirname "$0")/bvm" module "$@"
EOF

    # Create install-bx-site wrapper
    cat > "$BVM_HOME/bin/install-bx-site" << 'EOF'
#!/bin/bash
# BoxLang site installer wrapper script for BVM
exec "$(dirname "$0")/bvm" site "$@"
EOF

    # Make all wrapper scripts executable
    chmod +x "$BVM_HOME/bin"/*

    print_success "BVM script and wrappers installed to $BVM_HOME/bin"
}

# Setup PATH
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

# Show post-install instructions
show_instructions() {
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

# Main installation function
main() {
    print_header "BVM (BoxLang Version Manager) Installer"
    printf "\n"

    # Check prerequisites
    if ! check_prerequisites; then
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
    show_instructions
}

# Run main function
main "$@"
