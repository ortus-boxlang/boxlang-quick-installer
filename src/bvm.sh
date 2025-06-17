#!/bin/bash
# BoxLang Version Manager (BVM)
# A simple version manager for BoxLang similar to jenv or nvm
# Author: BoxLang Team
# License: Apache License, Version 2.0

set -e

###########################################################################
# Global Variables + Helpers
###########################################################################

# Include the helper functions
source ./helpers/helpers.sh

# Global Variables
BVM_VERSION="@build.version@"
BVM_HOME="${BVM_HOME:-$HOME/.bvm}"
BVM_CACHE_DIR="$BVM_HOME/cache"
BVM_VERSIONS_DIR="$BVM_HOME/versions"
BVM_SCRIPTS_DIR="$BVM_HOME/scripts"
BVM_CURRENT_LINK="$BVM_HOME/current"
BVM_CONFIG_FILE="$BVM_HOME/config"

# URLs for BoxLang downloads
DOWNLOAD_BASE_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang"
MINISERVER_BASE_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang-runtimes/boxlang-miniserver"
INSTALLER_BASE_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang-quick-installer"
LATEST_URL="$DOWNLOAD_BASE_URL/boxlang-latest.zip"
SNAPSHOT_URL="$DOWNLOAD_BASE_URL/boxlang-snapshot.zip"
LATEST_MINISERVER_URL="$MINISERVER_BASE_URL/boxlang-miniserver-latest.zip"
SNAPSHOT_MINISERVER_URL="$MINISERVER_BASE_URL/boxlang-miniserver-snapshot.zip"
INSTALLER_URL="$INSTALLER_BASE_URL/boxlang-installer.zip"

###########################################################################
# Utility Functions
###########################################################################

# Ensure BVM directories exist
ensure_bvm_dirs() {
    mkdir -p "$BVM_HOME" "$BVM_CACHE_DIR" "$BVM_VERSIONS_DIR" "$BVM_SCRIPTS_DIR"
}

###########################################################################
# Core Functions
###########################################################################

# Show help
show_help() {
    print_header "BoxLang Version Manager (BVM) v$BVM_VERSION"
    printf "\n"
    printf "${BOLD}USAGE:${NORMAL}\n"
    printf "  bvm <command> [arguments]\n\n"

    printf "${BOLD}COMMANDS:${NORMAL}\n"
    printf "  ${GREEN}install${NORMAL} <version>     Install a specific BoxLang version\n"
    printf "                         - 'latest': Install latest stable release\n"
    printf "                         - 'snapshot': Install latest development snapshot\n"
    printf "                         - '1.2.0': Install specific version\n"
    printf "  ${GREEN}use${NORMAL} <version>         Switch to a specific BoxLang version\n"
    printf "  ${GREEN}current${NORMAL}               Show currently active BoxLang version\n"
    printf "  ${GREEN}list${NORMAL}                  List all installed BoxLang versions\n"
    printf "  ${GREEN}list-remote${NORMAL}          List available BoxLang versions for download\n"
    printf "  ${GREEN}uninstall${NORMAL} <version>  Uninstall a specific BoxLang version\n"
    printf "  ${GREEN}which${NORMAL}                 Show path to current BoxLang installation\n"
    printf "  ${GREEN}exec${NORMAL} <args>          Execute BoxLang with current version\n"
    printf "  ${GREEN}run${NORMAL} <args>           Alias for exec\n"
    printf "  ${GREEN}miniserver${NORMAL} <args>    Start BoxLang MiniServer\n"
    printf "  ${GREEN}clean${NORMAL}                Clean cache and temporary files\n"
    printf "  ${GREEN}doctor${NORMAL}               Check BVM installation health\n"
    printf "  ${GREEN}version${NORMAL}              Show BVM version\n"
    printf "  ${GREEN}help${NORMAL}                 Show this help message\n\n"

    printf "${BOLD}EXAMPLES:${NORMAL}\n"
    printf "  bvm install latest\n"
    printf "  bvm install 1.2.0\n"
    printf "  bvm use 1.2.0\n"
    printf "  bvm list\n"
    printf "  bvm current\n"
    printf "  bvm exec --version\n"
    printf "  bvm run --help\n"
    printf "  bvm miniserver --port 8080\n"
    printf "  bvm clean\n"
    printf "  bvm doctor\n"
    printf "  bvm uninstall 1.1.0\n\n"

    printf "${BOLD}ENVIRONMENT:${NORMAL}\n"
    printf "  BVM_HOME              BVM installation directory (default: ~/.bvm)\n\n"

    printf "${BOLD}FILES:${NORMAL}\n"
    printf "  ~/.bvm/versions/      Installed BoxLang versions\n"
    printf "  ~/.bvm/current        Symlink to current BoxLang version\n"
    printf "  ~/.bvm/config         BVM configuration file\n\n"
}

# Get list of available remote versions
list_remote_versions() {
    print_info "Fetching available BoxLang versions from GitHub releases..."

    # Try to fetch from GitHub API
    local github_api="https://api.github.com/repos/ortus-boxlang/boxlang/releases"
    local temp_file="/tmp/bvm_releases.json"

    if curl -s "$github_api" > "$temp_file" 2>/dev/null && [ -s "$temp_file" ]; then
        printf "${BOLD}Available BoxLang versions:${NORMAL}\n"
        printf "  latest (latest stable release)\n"
        printf "  snapshot (development build)\n"

        # Parse GitHub releases
        if command_exists jq; then
            jq -r '.[].tag_name' "$temp_file" 2>/dev/null | head -10 | while read -r version; do
                if [ -n "$version" ] && [ "$version" != "null" ]; then
                    printf "  %s\n" "$version"
                fi
            done
        else
            # Fallback without jq
            grep -o '"tag_name":[^,]*' "$temp_file" | cut -d'"' -f4 | head -10 | while read -r version; do
                if [ -n "$version" ]; then
                    printf "  %s\n" "$version"
                fi
            done
        fi

        rm -f "$temp_file"
    else
        print_warning "Could not fetch remote versions"
        printf "${BOLD}Common BoxLang versions:${NORMAL}\n"
        printf "  latest (latest stable release)\n"
        printf "  snapshot (development build)\n"
        printf "  1.0.0\n"
        printf "  1.1.0\n"
        printf "  1.2.0\n"
    fi
}

# List installed versions
list_installed_versions() {
    ensure_bvm_dirs

    printf "${BOLD}Installed BoxLang versions:${NORMAL}\n"

    if [ ! -d "$BVM_VERSIONS_DIR" ] || [ -z "$(ls -A "$BVM_VERSIONS_DIR" 2>/dev/null)" ]; then
        print_warning "No BoxLang versions installed"
        print_info "Install a version with: bvm install latest"
        return 0
    fi

    local current_version=""
    if [ -L "$BVM_CURRENT_LINK" ]; then
        current_version=$(basename "$(readlink "$BVM_CURRENT_LINK")")
    fi

    for version_dir in "$BVM_VERSIONS_DIR"/*; do
        if [ -d "$version_dir" ]; then
            local version=$(basename "$version_dir")
            if [ "$version" = "$current_version" ]; then
                printf "  ${GREEN}* %s${NORMAL} (current)\n" "$version"
            else
                printf "    %s\n" "$version"
            fi
        fi
    done
}

# Show current version
show_current_version() {
    if [ -L "$BVM_CURRENT_LINK" ] && [ -e "$BVM_CURRENT_LINK" ]; then
        local current_version=$(basename "$(readlink "$BVM_CURRENT_LINK")")
        printf "${GREEN}Current BoxLang version: %s${NORMAL}\n" "$current_version"

        # Show version info if available
        local boxlang_bin="$BVM_CURRENT_LINK/bin/boxlang"
        if [ -x "$boxlang_bin" ]; then
            printf "${BLUE}Version info: ${NORMAL}"
            "$boxlang_bin" --version 2>/dev/null || printf "Unable to get version info\n"
        fi
    else
        print_warning "No BoxLang version currently active"
        print_info "Install and use a version with: bvm install latest && bvm use latest"
    fi
}

# Show path to current BoxLang
show_which() {
    if [ -L "$BVM_CURRENT_LINK" ] && [ -e "$BVM_CURRENT_LINK" ]; then
        printf "%s\n" "$BVM_CURRENT_LINK/bin/boxlang"
    else
        print_error "No BoxLang version currently active"
        return 1
    fi
}

# Install a BoxLang version
install_version() {
    local version="$1"

    if [ -z "$version" ]; then
        print_error "Please specify a version to install"
        print_info "Example: bvm install latest"
        return 1
    fi

    ensure_bvm_dirs

    local version_dir="$BVM_VERSIONS_DIR/$version"

    # Check if version is already installed
    if [ -d "$version_dir" ]; then
        print_warning "BoxLang $version is already installed"
        print_info "Use 'bvm use $version' to switch to this version"
        return 0
    fi

    print_info "Installing BoxLang $version..."

    # Determine download URLs
    local boxlang_url=""
    local miniserver_url=""
    local boxlang_cache=""
    local miniserver_cache=""

    case "$version" in
        "latest")
            boxlang_url="$LATEST_URL"
            miniserver_url="$LATEST_MINISERVER_URL"
            boxlang_cache="$BVM_CACHE_DIR/boxlang-latest.zip"
            miniserver_cache="$BVM_CACHE_DIR/boxlang-miniserver-latest.zip"
            ;;
        "snapshot")
            boxlang_url="$SNAPSHOT_URL"
            miniserver_url="$SNAPSHOT_MINISERVER_URL"
            boxlang_cache="$BVM_CACHE_DIR/boxlang-snapshot.zip"
            miniserver_cache="$BVM_CACHE_DIR/boxlang-miniserver-snapshot.zip"
            ;;
        *)
            boxlang_url="$DOWNLOAD_BASE_URL/$version/boxlang-$version.zip"
            miniserver_url="$MINISERVER_BASE_URL/$version/boxlang-miniserver-$version.zip"
            boxlang_cache="$BVM_CACHE_DIR/boxlang-$version.zip"
            miniserver_cache="$BVM_CACHE_DIR/boxlang-miniserver-$version.zip"
            ;;
    esac

    # Create version directory
    mkdir -p "$version_dir"

    # Download BoxLang runtime
    print_info "Downloading BoxLang runtime from $boxlang_url"
    if ! curl -fsSL "$boxlang_url" -o "$boxlang_cache"; then
        print_error "Failed to download BoxLang runtime"
        rm -rf "$version_dir"
        return 1
    fi

    # Download BoxLang MiniServer
    print_info "Downloading BoxLang MiniServer from $miniserver_url"
    if ! curl -fsSL "$miniserver_url" -o "$miniserver_cache"; then
        print_error "Failed to download BoxLang MiniServer"
        rm -rf "$version_dir"
        return 1
    fi

    # Extract BoxLang runtime
    print_info "Extracting BoxLang runtime..."
    if ! unzip -q "$boxlang_cache" -d "$version_dir"; then
        print_error "Failed to extract BoxLang runtime"
        rm -rf "$version_dir"
        return 1
    fi

    # Extract BoxLang MiniServer
    print_info "Extracting BoxLang MiniServer..."
    if ! unzip -q "$miniserver_cache" -d "$version_dir"; then
        print_error "Failed to extract BoxLang MiniServer"
        rm -rf "$version_dir"
        return 1
    fi

    # Make all executables in bin directory executable
    if [ -d "$version_dir/bin" ]; then
        find "$version_dir/bin" -type f -exec chmod +x {} \; 2>/dev/null || true
    fi

    # Create internal symlinks (bx -> boxlang, bx-miniserver -> boxlang-miniserver)
    print_info "Creating internal symlinks..."
    if [ -f "$version_dir/bin/boxlang" ]; then
        ln -sf "boxlang" "$version_dir/bin/bx"
    fi
    if [ -f "$version_dir/bin/boxlang-miniserver" ]; then
        ln -sf "boxlang-miniserver" "$version_dir/bin/bx-miniserver"
    fi

    # Clean up cache files for non-latest/snapshot versions
    if [ "$version" != "latest" ] && [ "$version" != "snapshot" ]; then
        rm -f "$boxlang_cache" "$miniserver_cache"
    fi

    print_success "BoxLang $version installed successfully"
    print_info "Components installed:"
    print_info "  - BoxLang runtime (boxlang, bx)"
    print_info "  - BoxLang MiniServer (boxlang-miniserver, bx-miniserver)"
    print_info "Helper scripts are managed by BVM and available globally"
    print_info "Use 'bvm use $version' to switch to this version"
}

# Use a specific BoxLang version
use_version() {
    local version="$1"

    if [ -z "$version" ]; then
        print_error "Please specify a version to use"
        print_info "Example: bvm use latest"
        return 1
    fi

    local version_dir="$BVM_VERSIONS_DIR/$version"

    if [ ! -d "$version_dir" ]; then
        print_error "BoxLang $version is not installed"
        print_info "Install it with: bvm install $version"
        return 1
    fi

    # Remove existing current link
    rm -f "$BVM_CURRENT_LINK"

    # Create new symlink
    ln -s "$version_dir" "$BVM_CURRENT_LINK"

    print_success "Now using BoxLang $version"

    # Update config
    echo "CURRENT_VERSION=$version" > "$BVM_CONFIG_FILE"
}

# Uninstall a BoxLang version
uninstall_version() {
    local version="$1"

    if [ -z "$version" ]; then
        print_error "Please specify a version to uninstall"
        print_info "Example: bvm uninstall 1.1.0"
        return 1
    fi

    local version_dir="$BVM_VERSIONS_DIR/$version"

    if [ ! -d "$version_dir" ]; then
        print_error "BoxLang $version is not installed"
        return 1
    fi

    # Check if it's the current version
    if [ -L "$BVM_CURRENT_LINK" ]; then
        local current_version=$(basename "$(readlink "$BVM_CURRENT_LINK")")
        if [ "$current_version" = "$version" ]; then
            print_warning "Cannot uninstall currently active version ($version)"
            print_info "Switch to another version first with: bvm use <other-version>"
            return 1
        fi
    fi

    # Confirm uninstall
    printf "${YELLOW}Are you sure you want to uninstall BoxLang $version? [y/N]: ${NORMAL}"
    read -r confirmation
    case "$confirmation" in
        [yY][eE][sS]|[yY])
            rm -rf "$version_dir"
            print_success "BoxLang $version uninstalled successfully"
            ;;
        *)
            print_info "Uninstall cancelled"
            ;;
    esac
}

# Execute BoxLang with current version
exec_boxlang() {
    if [ ! -L "$BVM_CURRENT_LINK" ] || [ ! -e "$BVM_CURRENT_LINK" ]; then
        print_error "No BoxLang version currently active"
        print_info "Install and use a version with: bvm install latest && bvm use latest"
        return 1
    fi

    local boxlang_bin="$BVM_CURRENT_LINK/bin/boxlang"
    if [ ! -x "$boxlang_bin" ]; then
        print_error "BoxLang executable not found or not executable"
        return 1
    fi

    exec "$boxlang_bin" "$@"
}

# Execute BoxLang MiniServer with current version
exec_miniserver() {
    if [ ! -L "$BVM_CURRENT_LINK" ] || [ ! -e "$BVM_CURRENT_LINK" ]; then
        print_error "No BoxLang version currently active"
        print_info "Install and use a version with: bvm install latest && bvm use latest"
        return 1
    fi

    local miniserver_bin="$BVM_CURRENT_LINK/bin/boxlang-miniserver"
    if [ ! -x "$miniserver_bin" ]; then
        print_error "BoxLang MiniServer executable not found or not executable"
        return 1
    fi

    exec "$miniserver_bin" "$@"
}

# Clean cache and temporary files
clean_cache() {
    print_info "Cleaning BVM cache and temporary files..."

    if [ -d "$BVM_CACHE_DIR" ]; then
        rm -rf "$BVM_CACHE_DIR"/*
        print_success "Cache cleaned"
    else
        print_info "No cache to clean"
    fi

    # Clean any temporary files
    rm -f /tmp/bvm_* 2>/dev/null || true

    print_success "Cleanup complete"
}

###########################################################################
# Check BVM installation health
###########################################################################
check_health() {
	printf "${RED}─────────────────────────────────────────────────────────────────────────────${NORMAL}\n"
    print_header "❤️‍🔥 BVM Health Check ❤️‍🔥"
	printf "${RED}─────────────────────────────────────────────────────────────────────────────${NORMAL}\n"
    printf "\n"

    local issues=0

	# Check prerequisites
    print_info "Checking prerequisites..."
    local missing_deps=()
    command_exists curl || missing_deps+=("curl")
    command_exists unzip || missing_deps+=("unzip")
    command_exists jq || missing_deps+=("jq")

    if [ ${#missing_deps[@]} -eq 0 ]; then
        print_success "All prerequisites satisfied"
    else
        print_warning "Missing optional dependencies: ${missing_deps[*]}"
        print_info "Some features may not work optimally"
    fi

    # Check Java installation
    if command_exists java; then
        local java_version=$(java -version 2>&1 | head -1)
        print_success "Java is available: $java_version"
    else
        print_warning "Java not found in PATH"
        print_info "Java 21+ is required to run BoxLang"
    fi

    # Check BVM home directory
    if [ -d "$BVM_HOME" ]; then
        print_success "BVM home directory exists: $BVM_HOME"
    else
        print_error "BVM home directory missing: $BVM_HOME"
        ((issues++))
    fi

    # Check versions directory
    if [ -d "$BVM_VERSIONS_DIR" ]; then
        print_success "Versions directory exists: $BVM_VERSIONS_DIR"
        local version_count=$(find "$BVM_VERSIONS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
        print_info "Installed versions: $version_count"
    else
        print_warning "Versions directory missing: $BVM_VERSIONS_DIR"
        mkdir -p "$BVM_VERSIONS_DIR"
        print_info "📁 Created versions directory"
    fi

    # Check cache directory
    if [ -d "$BVM_CACHE_DIR" ]; then
        print_success "Cache directory exists: $BVM_CACHE_DIR"
    else
        print_warning "Cache directory missing: $BVM_CACHE_DIR"
        mkdir -p "$BVM_CACHE_DIR"
        print_info "📁 Created cache directory"
    fi

    # Check current version link
    if [ -L "$BVM_CURRENT_LINK" ]; then
        if [ -e "$BVM_CURRENT_LINK" ]; then
            local current_version=$(basename "$(readlink "$BVM_CURRENT_LINK")")
            print_success "⚡ Current version link is valid: $current_version"

            # Check if BoxLang executable exists
            local boxlang_bin="$BVM_CURRENT_LINK/bin/boxlang"
            if [ -x "$boxlang_bin" ]; then
                print_success "⚡ BoxLang executable is accessible"

                # Try to get version
                if "$boxlang_bin" --version >/dev/null 2>&1; then
                    print_success "⚡ BoxLang executable works correctly"
                else
                    print_warning "⚡ BoxLang executable may have issues"
                    ((issues++))
                fi
            else
                print_error "⚡ BoxLang executable not found or not executable"
                ((issues++))
            fi

            # Check other expected binaries
            local expected_binaries=(
                "bx"
                "boxlang-miniserver"
                "bx-miniserver"
            )

            local missing_binaries=()
            for binary in "${expected_binaries[@]}"; do
                if [ ! -e "$BVM_CURRENT_LINK/bin/$binary" ]; then
                    missing_binaries+=("$binary")
                fi
            done

            if [ ${#missing_binaries[@]} -eq 0 ]; then
                print_success "👊 All expected binaries are present"
            else
                print_warning "Missing binaries: ${missing_binaries[*]}"
                print_info "Some features may not be available"
            fi
        else
            print_error "Current version link is broken"
            rm -f "$BVM_CURRENT_LINK"
            print_info "Removed broken link"
            ((issues++))
        fi
    else
        print_warning "No current version set"
        print_info "Use 'bvm use <version>' to set a current version"
    fi

    # Check BVM helper scripts
	if [ -d "$BVM_SCRIPTS_DIR" ]; then
        print_success "Scripts directory exists: $BVM_SCRIPTS_DIR"
    else
        print_warning "Scripts directory missing: $BVM_SCRIPTS_DIR"
        mkdir -p "$BVM_SCRIPTS_DIR"
        print_info "📁 Created scripts directory"
    fi
    print_info "Checking BVM helper scripts..."
    local bvm_scripts_dir="${BVM_SCRIPTS_DIR}"
    local expected_bvm_scripts=(
        "install-bx-module.sh"
        "install-bx-site.sh"
		"install-bvm.sh"
		"bvm.sh"
    )

    local missing_bvm_scripts=()
    for script in "${expected_bvm_scripts[@]}"; do
        if [ ! -x "$bvm_scripts_dir/$script" ]; then
            missing_bvm_scripts+=("$script")
        fi
    done

    if [ ${#missing_bvm_scripts[@]} -eq 0 ]; then
        print_success "👊 All BVM helper scripts are present"
    else
        print_warning "Missing BVM helper scripts: ${missing_bvm_scripts[*]}"
        print_info "Reinstall BVM to get the latest helper scripts"
    fi

    printf "\n"
	printf "${RED}─────────────────────────────────────────────────────────────────────────────${NORMAL}\n"
    if [ $issues -eq 0 ]; then
        print_success "❤️‍🔥 BVM installation is healthy!"
    else
        print_warning "Found [$issues] issue(s) - some functionality may be limited"
    fi
	printf "${RED}─────────────────────────────────────────────────────────────────────────────${NORMAL}\n"
}

###########################################################################
# Main Function
###########################################################################

main() {
    local command="$1"
    shift || true

	setup_colors

    case "$command" in
        "install")
            install_version "$1"
            ;;
        "use")
            use_version "$1"
            ;;
        "current")
            show_current_version
            ;;
        "list"|"ls")
            list_installed_versions
            ;;
        "list-remote"|"ls-remote")
            list_remote_versions
            ;;
        "uninstall"|"remove"|"rm")
            uninstall_version "$1"
            ;;
        "which")
            show_which
            ;;
        "exec"|"run")
            exec_boxlang "$@"
            ;;
        "miniserver"|"mini-server"|"ms")
            exec_miniserver "$@"
            ;;
        "clean")
            clean_cache
            ;;
        "doctor"|"health")
            check_health
            ;;
        "version"|"--version"|"-v")
            printf "BVM (BoxLang Version Manager) v%s\n" "$BVM_VERSION"
            ;;
        "help"|"--help"|"-h"|"")
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            printf "\n"
            show_help
            exit 1
            ;;
    esac
}

# Initialize BVM
ensure_bvm_dirs

# Run main function with all arguments
main "$@"