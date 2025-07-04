#!/bin/bash
# BoxLang Version Manager (BVM)
# A simple version manager for BoxLang similar to jenv or nvm
# Author: BoxLang Team
# License: Apache License, Version 2.0

set -e

###########################################################################
# Global Variables + Helpers
###########################################################################

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
LATEST_VERSION_URL="$DOWNLOAD_BASE_URL/version-latest.properties"
SNAPSHOT_URL="$DOWNLOAD_BASE_URL/boxlang-snapshot.zip"
SNAPSHOT_VERSION_URL="$DOWNLOAD_BASE_URL/version-snapshot.properties"
LATEST_MINISERVER_URL="$MINISERVER_BASE_URL/boxlang-miniserver-latest.zip"
SNAPSHOT_MINISERVER_URL="$MINISERVER_BASE_URL/boxlang-miniserver-snapshot.zip"
INSTALLER_URL="$INSTALLER_BASE_URL/boxlang-installer.zip"
VERSION_CHECK_URL="$INSTALLER_BASE_URL/version.json"

# Helpers
if [ -f "$(dirname "$0")/helpers/helpers.sh" ]; then
	source "$(dirname "$0")/helpers/helpers.sh"
elif [ -f "${BVM_HOME}/scripts/helpers/helpers.sh" ]; then
    source "${BVM_HOME}/scripts/helpers/helpers.sh"
else
	printf "${RED}Error: BVM helper scripts not found. Please ensure BVM is installed correctly.${NORMAL}\n"
	printf "${YELLOW}You can reinstall BVM using the installer script:${NORMAL}\n"
	printf "curl -fsSL https://install-bvm.boxlang.io | bash"
	exit 1
fi

###########################################################################
# Utility Functions
###########################################################################

# Ensure BVM directories exist
ensure_bvm_dirs() {
    mkdir -p "$BVM_HOME" "$BVM_CACHE_DIR" "$BVM_VERSIONS_DIR" "$BVM_SCRIPTS_DIR"
}

# Resolve version aliases (latest, snapshot) to actual installed versions
resolve_version_alias() {
    local requested_version="$1"

    case "$requested_version" in
        "latest")
            # Check if latest symlink exists
            local latest_link="$BVM_VERSIONS_DIR/latest"
            if [ -L "$latest_link" ] && [ -e "$latest_link" ]; then
                # Follow the symlink to get the actual version
                basename "$(readlink "$latest_link")"
            else
                # Fallback to literal 'latest' if no symlink found
                echo "latest"
            fi
            ;;
        "snapshot")
            # Check if snapshot symlink exists
            local snapshot_link="$BVM_VERSIONS_DIR/snapshot"
            if [ -L "$snapshot_link" ] && [ -e "$snapshot_link" ]; then
                # Follow the symlink to get the actual version
                basename "$(readlink "$snapshot_link")"
            else
                # Fallback to literal 'snapshot' if no symlink found
                echo "snapshot"
            fi
            ;;
        *)
            # Return the version as-is for all other versions
            echo "$requested_version"
            ;;
    esac
}

# Read version from .bvmrc file in current directory or parent directories
read_bvmrc_version() {
    local current_dir="$PWD"
    local bvmrc_file=""

    # Look for .bvmrc starting from current directory, going up to root
    while [ "$current_dir" != "/" ]; do
        if [ -f "$current_dir/.bvmrc" ]; then
            bvmrc_file="$current_dir/.bvmrc"
            break
        fi
        current_dir=$(dirname "$current_dir")
    done

    # If no .bvmrc found, return empty
    if [ -z "$bvmrc_file" ]; then
        return 1
    fi

    # Read the first non-empty, non-comment line from .bvmrc
    local version
    version=$(grep -v '^#' "$bvmrc_file" | grep -v '^[[:space:]]*$' | head -n1 | tr -d '[:space:]')

    if [ -n "$version" ]; then
        echo "$version"
        return 0
    else
        return 1
    fi
}

# Create or update .bvmrc file in current directory
write_bvmrc_version() {
    local version="$1"
    local bvmrc_file=".bvmrc"

    # If no version provided, show current .bvmrc
    if [ -z "$version" ]; then
        if local_version=$(read_bvmrc_version); then
            print_success "Current .bvmrc version: $local_version"
            local bvmrc_path
            local current_dir="$PWD"
            while [ "$current_dir" != "/" ]; do
                if [ -f "$current_dir/.bvmrc" ]; then
                    bvmrc_path="$current_dir/.bvmrc"
                    break
                fi
                current_dir=$(dirname "$current_dir")
            done
            print_info "Found at: $bvmrc_path"
        else
            print_info "No .bvmrc file found in current directory or parent directories"
            print_info "Usage: bvm local <version>"
            print_info "Examples:"
            print_info "  bvm local latest"
            print_info "  bvm local snapshot"
            print_info "  bvm local 1.2.0"
        fi
        return 0
    fi

    # Validate that the version exists (optional - could be a future version)
    local resolved_version
    resolved_version=$(resolve_version_alias "$version")
    local version_dir="$BVM_VERSIONS_DIR/$resolved_version"

    if [ ! -d "$version_dir" ]; then
        print_warning "BoxLang [$version] is not currently installed"
        print_info "You can still create .bvmrc, but install it later with: bvm install $version"
    fi

    echo "$version" > "$bvmrc_file"
    print_success "Created .bvmrc with version: $version"

    if [ -f "$bvmrc_file" ]; then
        print_info "You can now use 'bvm use' (without version) to activate this version"
    fi
}

###########################################################################
# Core Functions
###########################################################################

# Show help
show_help() {
	printf "${GREEN}📦 BoxLang Version Manager (BVM) v${BVM_VERSION}${NORMAL}\n\n"
    printf "${YELLOW}This script manages BoxLang versions and installations.${NORMAL}\n\n"
    printf "${BOLD}USAGE:${NORMAL}\n"
    printf "  bvm <command> [arguments]\n\n"
    printf "${BOLD}COMMANDS:${NORMAL}\n"
    printf "  ${GREEN}install${NORMAL} <version>     Install a specific BoxLang version\n"
    printf "                         - 'latest': Install latest stable release\n"
    printf "                         - 'snapshot': Install latest development snapshot\n"
    printf "                         - '1.2.0': Install specific version\n"
    printf "                         Use --force to reinstall an existing version\n"
    printf "  ${GREEN}use${NORMAL} <version>         Switch to a specific BoxLang version\n"
    printf "                         Use without version to read from .bvmrc\n"
    printf "  ${GREEN}local${NORMAL} <version>       Set local BoxLang version for current directory (.bvmrc)\n"
    printf "                         Use without version to show current .bvmrc\n"
    printf "  ${GREEN}current${NORMAL}               Show currently active BoxLang version\n"
    printf "  ${GREEN}list${NORMAL}                  List all installed BoxLang versions\n"
    printf "  ${GREEN}list-remote${NORMAL}          List available BoxLang versions for download\n"
    printf "  ${GREEN}remove${NORMAL} <version>  Remove a specific BoxLang version\n"
    printf "  ${GREEN}uninstall${NORMAL}             Completely uninstall BVM and all BoxLang versions\n"
    printf "  ${GREEN}which${NORMAL}                 Show path to current BoxLang installation\n"
    printf "  ${GREEN}exec${NORMAL} <args>          Execute BoxLang with current version\n"
    printf "  ${GREEN}run${NORMAL} <args>           Alias for exec\n"
    printf "  ${GREEN}miniserver${NORMAL} <args>    Start BoxLang MiniServer\n"
    printf "  ${GREEN}clean${NORMAL}                Clean cache and temporary files\n"
    printf "  ${GREEN}stats${NORMAL}                Show performance and usage statistics\n"
    printf "  ${GREEN}doctor${NORMAL}               Check BVM installation health\n"
    printf "  ${GREEN}check-update${NORMAL}         Check for BVM updates\n"
    printf "  ${GREEN}version${NORMAL}              Show BVM version\n"
    printf "  ${GREEN}help${NORMAL}                 Show this help message\n\n"

    printf "${BOLD}EXAMPLES:${NORMAL}\n"
    printf "  bvm install latest\n"
    printf "  bvm install 1.2.0\n"
    printf "  bvm install latest --force\n"
    printf "  bvm use 1.2.0\n"
    printf "  bvm use                # Read version from .bvmrc\n"
    printf "  bvm local latest       # Set .bvmrc to 'latest'\n"
    printf "  bvm local              # Show current .bvmrc\n"
    printf "  bvm list\n"
    printf "  bvm current\n"
    printf "  bvm exec --version\n"
    printf "  bvm run --help\n"
    printf "  bvm miniserver --port 8080\n"
    printf "  bvm clean\n"
    printf "  bvm stats\n"
    printf "  bvm doctor\n"
    printf "  bvm check-update\n"
    printf "  bvm remove 1.1.0\n"
    printf "  bvm uninstall\n\n"

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
    local temp_file=$(mktemp "/tmp/bvm_releases.XXXXXX.json")
    trap 'rm -f "$temp_file"' EXIT

    if curl -s "$github_api" > "$temp_file" 2>/dev/null && [ -s "$temp_file" ]; then
        printf "${BOLD}Available BoxLang versions:${NORMAL}\n"
        printf "  latest (latest stable release)\n"
        printf "  snapshot (development build)\n"

        # Parse GitHub releases
		jq -r '.[].tag_name' "$temp_file" 2>/dev/null | head -10 | while read -r version; do
			if [ -n "$version" ] && [ "$version" != "null" ]; then
				printf "  %s\n" "$version"
			fi
		done
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
        if [ -d "$version_dir" ] || [ -L "$version_dir" ]; then
            local version=$(basename "$version_dir")

            # Handle symlinks (latest/snapshot aliases)
            if [ -L "$version_dir" ]; then
                local target_version=$(basename "$(readlink "$version_dir")")
                if [ "$target_version" = "$current_version" ]; then
                    printf "  ${GREEN}* %s${NORMAL} -> %s (current)\n" "$version" "$target_version"
                else
                    printf "    %s -> %s\n" "$version" "$target_version"
                fi
            else
                # Handle regular version directories
                if [ "$version" = "$current_version" ]; then
                    printf "  ${GREEN}* %s${NORMAL} (current)\n" "$version"
                else
                    printf "    %s\n" "$version"
                fi
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
    local force_install="$2"

    if [ -z "$version" ]; then
        print_error "Please specify a version to install"
        print_info "Example: bvm install latest"
        return 1
    fi

    ensure_bvm_dirs

    local version_dir="$BVM_VERSIONS_DIR/$version"

    # Check if version is already installed (unless force is used)
    if [ -d "$version_dir" ] && [ "$force_install" != "--force" ]; then
        print_warning "BoxLang $version is already installed"
        print_info "Use 'bvm use $version' to switch to this version"
        print_info "Use 'bvm install $version --force' to reinstall"
        return 0
    fi

    # If force install and version exists, remove it first
    if [ -d "$version_dir" ] && [ "$force_install" = "--force" ]; then
        print_info "Force reinstalling BoxLang $version..."
        print_info "Removing existing installation..."
        rm -rf "$version_dir"
    fi

    print_info "Installing BoxLang [$version]..."

    # Track installation for cleanup
    INSTALLING_VERSION="$version"

    # Determine download URLs
    local boxlang_url=""
    local miniserver_url=""
    local boxlang_cache=""
    local miniserver_cache=""
    local install_dir="$version_dir"
    local original_version="$version"

    case "$version" in
        "latest")
            boxlang_url="$LATEST_URL"
            miniserver_url="$LATEST_MINISERVER_URL"
            boxlang_cache="$BVM_CACHE_DIR/boxlang-latest.zip"
            miniserver_cache="$BVM_CACHE_DIR/boxlang-miniserver-latest.zip"
            # Use temporary directory for latest/snapshot to detect actual version
            install_dir="$BVM_CACHE_DIR/temp-$version-$$"
            ;;
        "snapshot")
            boxlang_url="$SNAPSHOT_URL"
            miniserver_url="$SNAPSHOT_MINISERVER_URL"
            boxlang_cache="$BVM_CACHE_DIR/boxlang-snapshot.zip"
            miniserver_cache="$BVM_CACHE_DIR/boxlang-miniserver-snapshot.zip"
            # Use temporary directory for latest/snapshot to detect actual version
            install_dir="$BVM_CACHE_DIR/temp-$version-$$"
			force_install="--force"  # Force install for snapshot to ensure fresh download
            ;;
        *)
            boxlang_url="$DOWNLOAD_BASE_URL/$version/boxlang-$version.zip"
            miniserver_url="$MINISERVER_BASE_URL/$version/boxlang-miniserver-$version.zip"
            boxlang_cache="$BVM_CACHE_DIR/boxlang-$version.zip"
            miniserver_cache="$BVM_CACHE_DIR/boxlang-miniserver-$version.zip"
            ;;
    esac

    # Create installation directory
    mkdir -p "$install_dir"

    # Check network connectivity before attempting downloads
    if ! check_network_connectivity; then
        print_warning "Network connectivity issues detected - downloads may fail"
    fi

    # Download BoxLang runtime
    print_info "⬇️  Downloading BoxLang runtime... (this may take a moment)"
    if ! curl -fL --progress-bar -o "$boxlang_cache" "$boxlang_url"; then
        print_error "Failed to download BoxLang runtime"
        rm -rf "$install_dir"
        return 1
    fi

    # Verify download with SHA-256 checksum
    if ! verify_download_with_checksum "$boxlang_cache" "$(dirname "$boxlang_url")" 5000000; then  # Expect at least 5MB
        print_error "BoxLang runtime download verification failed"
        rm -rf "$install_dir"
        rm -f "$boxlang_cache"
        return 1
    fi

    # Download BoxLang MiniServer
	printf "\n"
    print_info "⬇️  Downloading BoxLang MiniServer... (this may take a moment)"
    if ! curl -fL --progress-bar -o "$miniserver_cache" "$miniserver_url"; then
        print_error "Failed to download BoxLang MiniServer"
        rm -rf "$install_dir"
        return 1
    fi

    # Verify download with SHA-256 checksum
    if ! verify_download_with_checksum "$miniserver_cache" "$(dirname "$miniserver_url")" 8000000; then  # Expect at least 8 MB
        print_error "BoxLang MiniServer download verification failed"
        rm -rf "$install_dir"
        rm -f "$miniserver_cache"
        return 1
    fi

    # Extract BoxLang runtime
	printf "\n"
    print_info "📦 Extracting BoxLang runtime..."
    if ! unzip -q "$boxlang_cache" -d "$install_dir"; then
        print_error "Failed to extract BoxLang runtime"
        rm -rf "$install_dir"
        return 1
    fi

    # Extract BoxLang MiniServer
    print_info "📦 Extracting BoxLang MiniServer..."
    if ! unzip -q "$miniserver_cache" -d "$install_dir"; then
        print_error "Failed to extract BoxLang MiniServer"
        rm -rf "$install_dir"
        return 1
    fi

    # Make all executables in bin directory executable
    if [ -d "$install_dir/bin" ]; then
        find "$install_dir/bin" -type f -exec chmod +x {} \; 2>/dev/null || true
    fi

    # Detect actual version for latest/snapshot installations
    local actual_version="$version"
    if [ "$original_version" = "latest" ] || [ "$original_version" = "snapshot" ]; then
        print_info "🔎 Version alias requested, fetching actual version from remote..."

        # Fetch version from remote property file
        if actual_version=$(fetch_remote_version "$original_version"); then
            # Clean up version string - remove any build metadata after +
            actual_version=$(echo "$actual_version" | sed 's/+.*//')
            print_info "Detected version: $actual_version"

            # Check if this version already exists
            local actual_version_dir="$BVM_VERSIONS_DIR/$actual_version"
            if [ -d "$actual_version_dir" ] && [ "$force_install" != "--force" ]; then
                print_warning "BoxLang $actual_version is already installed"
                print_info "Use 'bvm use $actual_version' to switch to this version"
                print_info "Use 'bvm install $original_version --force' to reinstall"
                rm -rf "$install_dir"
                return 0
            fi

            # If force install and version exists, remove it first
            if [ -d "$actual_version_dir" ] && [ "$force_install" = "--force" ]; then
                print_warning "Force reinstalling - removing existing $actual_version..."
                rm -rf "$actual_version_dir"
            fi

            # Move from temporary to actual version directory
            version_dir="$actual_version_dir"
            mkdir -p "$(dirname "$version_dir")"
            mv "$install_dir" "$version_dir"
            version="$actual_version"
        else
            print_error "Failed to fetch version info from remote"
            print_info "This is required for $original_version installations to determine the actual version number"
            print_info "Please check your internet connection and try again"
            rm -rf "$install_dir"
            return 1
        fi
    fi

    # Create internal symlinks (bx -> boxlang, bx-miniserver -> boxlang-miniserver)
    print_info "Creating internal symlinks..."
    if [ -f "$version_dir/bin/boxlang" ]; then
        ln -sf "boxlang" "$version_dir/bin/bx"
    fi
    if [ -f "$version_dir/bin/boxlang-miniserver" ]; then
        ln -sf "boxlang-miniserver" "$version_dir/bin/bx-miniserver"
    fi

    # Create version alias symlinks
    if [ "$original_version" = "latest" ]; then
        local alias_link="$BVM_VERSIONS_DIR/latest"
        print_info "Creating latest symlink to $version..."

        # Remove existing symlink if it exists
        rm -f "$alias_link"

        # Create new symlink pointing to the actual version directory
        ln -sf "$version" "$alias_link"
    elif [ "$original_version" = "snapshot" ]; then
        local alias_link="$BVM_VERSIONS_DIR/snapshot"
        print_info "Creating snapshot symlink to $version..."

        # Remove existing symlink if it exists
        rm -f "$alias_link"

        # Create new symlink pointing to the actual version directory
        ln -sf "$version" "$alias_link"
    fi

    # Clean up cache files for non-latest/snapshot versions
    if [ "$original_version" != "latest" ] && [ "$original_version" != "snapshot" ]; then
        rm -f "$boxlang_cache" "$miniserver_cache"
    fi

    # Clear installation tracking
    print_success "BoxLang $version installed successfully"
    unset INSTALLING_VERSION
    print_info "Use 'bvm use $version' to switch to this version"
}

# Use a specific BoxLang version
use_version() {
    local version="$1"

    # If no version specified, try to read from .bvmrc
    if [ -z "$version" ]; then
        if version=$(read_bvmrc_version); then
            print_info "Reading version from .bvmrc: $version"
        else
            print_error "No version specified and no .bvmrc file found"
            print_info "Usage:"
            print_info "  bvm use <version>        # Use specific version"
            print_info "  bvm use                  # Use version from .bvmrc"
            print_info "  echo 'latest' > .bvmrc   # Create .bvmrc file"
            return 1
        fi
    fi

    # Resolve version alias (latest) to actual version
    local resolved_version
    resolved_version=$(resolve_version_alias "$version")
    local version_dir="$BVM_VERSIONS_DIR/$resolved_version"

    if [ ! -d "$version_dir" ]; then
		print_error "BoxLang $version is not installed"
		print_info "Install it with: bvm install $version"
        return 1
    fi

    # Remove existing current link
    rm -f "$BVM_CURRENT_LINK"

    # Create new symlink
    ln -s "$version_dir" "$BVM_CURRENT_LINK"

    if [ "$version" != "$resolved_version" ]; then
        print_success "Now using BoxLang $resolved_version (resolved from '$version')"
    else
        print_success "Now using BoxLang $version"
    fi

    # Update config
    echo "CURRENT_VERSION=$resolved_version" > "$BVM_CONFIG_FILE"
}

# Uninstall a BoxLang version
remove_version() {
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
            # Remove the version directory
            rm -rf "$version_dir"

            # Clean up the latest symlink if it points to this version
            local latest_link="$BVM_VERSIONS_DIR/latest"
            if [ -L "$latest_link" ]; then
                local target_version=$(basename "$(readlink "$latest_link")" 2>/dev/null || echo "")
                if [ "$target_version" = "$version" ]; then
                    print_info "Removing latest symlink that pointed to $version"
                    rm -f "$latest_link"
                fi
            fi

            # Clean up the snapshot symlink if it points to this version
            local snapshot_link="$BVM_VERSIONS_DIR/snapshot"
            if [ -L "$snapshot_link" ]; then
                local target_version=$(basename "$(readlink "$snapshot_link")" 2>/dev/null || echo "")
                if [ "$target_version" = "$version" ]; then
                    print_info "Removing snapshot symlink that pointed to $version"
                    rm -f "$snapshot_link"
                fi
            fi

            print_success "BoxLang $version uninstalled successfully"
            ;;
        *)
            print_info "Uninstall cancelled"
            ;;
    esac
}

# Completely uninstall BVM and all BoxLang versions
uninstall_bvm() {
    printf "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NORMAL}\n"
    printf "${BOLD}${RED}⚠️  COMPLETE BVM UNINSTALL ⚠️${NORMAL}\n"
    printf "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NORMAL}\n"
    printf "\n"
    print_warning "This will completely remove BVM and ALL installed BoxLang versions from your system!"
    printf "\n"

    if [ -d "$BVM_HOME" ]; then
        printf "${BOLD}The following will be permanently deleted:${NORMAL}\n\n"
        printf "  📁 BVM home directory: %s\n" "$BVM_HOME"

        # Show installed versions if any
        if [ -d "$BVM_VERSIONS_DIR" ] && [ -n "$(ls -A "$BVM_VERSIONS_DIR" 2>/dev/null)" ]; then
            printf "  📦 Installed BoxLang versions:\n"
            for version_dir in "$BVM_VERSIONS_DIR"/*; do
                if [ -d "$version_dir" ] || [ -L "$version_dir" ]; then
                    local version=$(basename "$version_dir")
                    if [ -L "$version_dir" ]; then
                        local target_version=$(basename "$(readlink "$version_dir")")
                        printf "     - %s -> %s\n" "$version" "$target_version"
                    else
                        printf "     - %s\n" "$version"
                    fi
                fi
            done
        else
            printf "  📦 No BoxLang versions currently installed\n"
        fi

        # Show cache size if exists
        if [ -d "$BVM_CACHE_DIR" ]; then
            local cache_size=$(du -sh "$BVM_CACHE_DIR" 2>/dev/null | cut -f1 | xargs)
            printf "  💽 Cache directory: %s (%s)\n" "$BVM_CACHE_DIR" "$cache_size"
        fi

        printf "  🗒️ Configuration and scripts\n"
    else
        printf "${YELLOW}BVM doesn't appear to be installed (no directory found at %s)${NORMAL}\n" "$BVM_HOME"
        return 0
    fi

    printf "\n"
    printf "${BOLD}${RED}This action cannot be undone!${NORMAL}\n"
    printf "${YELLOW}Are you absolutely sure you want to completely uninstall BVM? [y/N]: ${NORMAL}"
    read -r confirmation

    case "$confirmation" in
        [yY][eE][sS]|[yY])
            printf "\n"
            print_info "Uninstalling BVM..."

            # Remove the entire BVM home directory
            if [ -d "$BVM_HOME" ]; then
                rm -rf "$BVM_HOME"
                print_success "✅ Removed BVM home directory: $BVM_HOME"
            fi

            # Clean up any temporary files
            rm -f /tmp/bvm_* 2>/dev/null || true
            print_success "✅ Cleaned up temporary files"

            printf "\n"
            printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NORMAL}\n"
            print_success "🎉 BVM has been completely uninstalled!"
            printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NORMAL}\n"
            printf "\n"
            printf "${BOLD}Next steps:${NORMAL}\n"
            printf "  • Remove any BVM-related entries from your shell profile (~/.bashrc, ~/.zshrc, etc.)\n"
            printf "  • Remove the BVM binary from your PATH if you installed it system-wide\n"
            printf "  • Close this terminal and open a new one to complete the cleanup\n"
            printf "\n"
            printf "${BOLD}Thank you for using BVM! 👋${NORMAL}\n"
            printf "\n"
            ;;
        *)
            printf "\n"
            print_info "Uninstall cancelled - BVM remains installed"
            printf "\n"
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

# Show performance and usage statistics
show_stats() {
    printf "${RED}─────────────────────────────────────────────────────────────────────────────${NORMAL}\n"
    print_header "📊 BVM Performance & Usage Statistics"
    printf "${RED}─────────────────────────────────────────────────────────────────────────────${NORMAL}\n"
    printf "\n"

    # BVM installation stats
    if [ -d "$BVM_HOME" ]; then
        local bvm_size=$(du -sh "$BVM_HOME" 2>/dev/null | cut -f1 | xargs)
        print_info "BVM home directory size: $bvm_size"
    fi

    # Versions stats
    if [ -d "$BVM_VERSIONS_DIR" ]; then
        local version_count=$(find "$BVM_VERSIONS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
        local versions_size=$(du -sh "$BVM_VERSIONS_DIR" 2>/dev/null | cut -f1 | xargs)
        print_info "Installed versions: $version_count (total size: $versions_size)"

        # Show size breakdown by version
        printf "\n${BOLD}Version breakdown:${NORMAL}\n"
        find "$BVM_VERSIONS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while read -r version_dir; do
            if [ -d "$version_dir" ]; then
                local version=$(basename "$version_dir")
                local size=$(du -sh "$version_dir" 2>/dev/null | cut -f1 | xargs)
                printf "  %s: %s\n" "$version" "$size"
            fi
        done
    fi

    # Cache stats
    if [ -d "$BVM_CACHE_DIR" ]; then
        local cache_size=$(du -sh "$BVM_CACHE_DIR" 2>/dev/null | cut -f1 | xargs)
        local cache_files=$(find "$BVM_CACHE_DIR" -type f 2>/dev/null | wc -l)
        print_info "Cache directory: $cache_size ($cache_files files)"
    fi

    # Current version performance
    if [ -L "$BVM_CURRENT_LINK" ] && [ -e "$BVM_CURRENT_LINK" ]; then
        local current_version=$(basename "$(readlink "$BVM_CURRENT_LINK")")
        printf "\n${BOLD}Current version performance:${NORMAL}\n"

        local boxlang_bin="$BVM_CURRENT_LINK/bin/boxlang"
        if [ -x "$boxlang_bin" ]; then
            # Quick startup time test
            print_info "Testing BoxLang startup time..."
            local start_time=$(date +%s%3N)
            if "$boxlang_bin" --version >/dev/null 2>&1; then
                local end_time=$(date +%s%3N)
                local duration=$((end_time - start_time))
                printf "  Startup time: %sms\n" "$duration"
            else
                printf "  Startup test: Failed\n"
            fi
        fi
    fi

    printf "\n"
    printf "${RED}─────────────────────────────────────────────────────────────────────────────${NORMAL}\n"
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

	if [ "$(uname)" = "Darwin" ]; then
		command_exists shasum || missing_deps+=( "shasum" )
	elif [ "$(uname)" = "Linux" ]; then
		command_exists sha256sum || missing_deps+=( "sha256sum" )
	fi

    command_exists curl || missing_deps+=( "curl" )
    command_exists unzip || missing_deps+=( "unzip" )
    command_exists jq || missing_deps+=( "jq" )

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
# Check for BVM Updates
###########################################################################
check_bvm_updates() {
    printf "${RED}─────────────────────────────────────────────────────────────────────────────${NORMAL}\n"
    print_header "🔄 BVM Update Checker"
    printf "${RED}─────────────────────────────────────────────────────────────────────────────${NORMAL}\n"
    printf "\n"

    print_info "🔍 Checking for BVM updates...\n"

    # Get current version from local version.json in scripts directory
    local current_version=""
    local version_file="$BVM_SCRIPTS_DIR/version.json"
    if [ -f "$version_file" ]; then
		current_version=$(jq -r '.INSTALLER_VERSION' "$version_file" 2>/dev/null || echo "")
    fi

    # Get latest version from remote
    local latest_version=""
    local temp_file=$(mktemp "/tmp/bvm_version_check.XXXXXX.json")
    trap 'rm -f "$temp_file"' EXIT INT

    if curl -s "$VERSION_CHECK_URL" > "$temp_file" 2>/dev/null && [ -s "$temp_file" ]; then
        latest_version=$(jq -r '.INSTALLER_VERSION' "$temp_file" 2>/dev/null || echo "")
        rm -f "$temp_file"
    fi

    if [ -z "$latest_version" ] || [ "$latest_version" = "null" ]; then
        print_error "Failed to fetch latest version information"
        print_warning "Please check your internet connection and try again"
        printf "\n"
        printf "${RED}─────────────────────────────────────────────────────────────────────────────${NORMAL}\n"
        return 1
    fi

	# Print current and latest versions
    printf "${GREEN}Current BVM version: %s${NORMAL}\n" "$current_version"
    printf "${GREEN}Latest BVM version:  %s${NORMAL}\n" "$latest_version"
    printf "\n"

	# Compare versions now
	if compare_versions "$latest_version" "$current_version"; then
		local comparison_result=0
	else
		local comparison_result=$?
	fi

	case $comparison_result in
		0)
			print_success "🦾 You have the latest version of BVM!"
			;;
		1)
			print_warning "🆙 A newer version of BVM is available!"
			printf "\n"
			printf "${BOLD}Would you like to upgrade to version [%s]? [Y/n]: ${NORMAL}" "$latest_version"
			read -r upgrade_response

			case "$upgrade_response" in
				[nN][oO]|[nN])
					print_info "Update cancelled"
					;;
				*)
					print_info "🚀 Starting BVM upgrade to version [$latest_version]..."
					local install_script="$BVM_SCRIPTS_DIR/install-bvm.sh"
					if [ -x "$install_script" ]; then
						print_info "⚡Executing upgrade using: $install_script"
						exec "$install_script"
					else
						print_error "BVM installer script not found at: $install_script"
						print_info "Please reinstall BVM manually using:"
						print_info "curl -fsSL https://install-bvm.boxlang.io | bash"
					fi
					;;
			esac
			;;
		2)
			print_info "🧑‍💻 Your BVM version is newer than the latest release, hmm, how did that happen?"
			;;
		*)
			print_error "Failed to compare versions"
			;;
	esac

    printf "\n"
    printf "${RED}─────────────────────────────────────────────────────────────────────────────${NORMAL}\n"
}

###########################################################################
# Check network connectivity
###########################################################################
check_network_connectivity() {
    # Test connectivity to main download server
    if ! curl -s --max-time 10 --head "$DOWNLOAD_BASE_URL" >/dev/null 2>&1; then
        print_warning "Network connectivity check failed"
        print_info "Attempting to continue anyway..."
        return 1
    fi
    return 0
}

###########################################################################
# Verify file integrity with SHA-256 checksum
###########################################################################
verify_download_with_checksum() {
    local file_path="$1"
    local base_url="$2"
    local min_size="${3:-1000}"  # Minimum expected file size in bytes

    if [ ! -f "$file_path" ]; then
        print_error "Downloaded file does not exist: $file_path"
        return 1
    fi

    # Basic size check
    local file_size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo 0)
    if [ "$file_size" -lt "$min_size" ]; then
        print_error "Downloaded file appears corrupted (size: $file_size bytes)"
        return 1
    fi

    # Basic ZIP file validation
    if [[ "$file_path" == *.zip ]]; then
        if ! unzip -t "$file_path" >/dev/null 2>&1; then
            print_error "Downloaded ZIP file is corrupted"
            return 1
        fi
    fi

    # Try to download and verify SHA-256 checksum
    local filename=$(basename "$file_path")
    local checksum_url="${base_url}/${filename}.sha-256"
    local checksum_file="${file_path}.sha-256"

    print_info "🔒 Attempting to verify SHA-256 checksum..."

    if curl -s --fail -o "$checksum_file" "$checksum_url" 2>/dev/null; then
        # Checksum file exists, verify it
        if command_exists sha256sum; then
            local actual_checksum=$(sha256sum "$file_path" | cut -d' ' -f1)
            local expected_checksum=$(cat "$checksum_file" | cut -d' ' -f1)

            if [ "$actual_checksum" = "$expected_checksum" ]; then
                print_success "SHA-256 checksum verification passed"
                rm -f "$checksum_file"
                return 0
            else
                print_error "SHA-256 checksum verification failed!"
                print_error "Expected: $expected_checksum"
                print_error "Actual:   $actual_checksum"
                rm -f "$checksum_file"
                return 1
            fi
        elif command_exists shasum; then
            local actual_checksum=$(shasum -a 256 "$file_path" | cut -d' ' -f1)
            local expected_checksum=$(cat "$checksum_file" | cut -d' ' -f1)

            if [ "$actual_checksum" = "$expected_checksum" ]; then
                print_success "SHA-256 checksum verification passed"
                rm -f "$checksum_file"
                return 0
            else
                print_error "SHA-256 checksum verification failed!"
                print_error "Expected: $expected_checksum"
                print_error "Actual:   $actual_checksum"
                rm -f "$checksum_file"
                return 1
            fi
        else
            print_warning "⚠️  No SHA-256 utility found (sha256sum or shasum), skipping checksum verification"
            rm -f "$checksum_file"
        fi
    else
        # Checksum file doesn't exist - this is expected for versions < 1.3.0
        print_warning "⚠️  No SHA-256 checksum available for this BoxLang version"
        print_info "SHA-256 checksums were introduced in BoxLang 1.3.0. Earlier versions do not have checksums."
    fi

    return 0
}

###########################################################################
# Fetch version from remote property file
###########################################################################
fetch_remote_version() {
    local version_type="$1"  # "latest" or "snapshot"
    local version_url=""

    case "$version_type" in
        "latest")
            version_url="$LATEST_VERSION_URL"
            ;;
        "snapshot")
            version_url="$SNAPSHOT_VERSION_URL"
            ;;
        *)
            print_error "Invalid version type: $version_type"
            return 1
            ;;
    esac

    # Create temporary file for version properties
    local temp_version_file=$(mktemp "/tmp/bvm_version.XXXXXX.properties")
    trap 'rm -f "$temp_version_file"' EXIT

    # Download version properties file with shorter timeout for responsiveness
    if curl -fsSL --connect-timeout 5 --max-time 15 "$version_url" -o "$temp_version_file" 2>/dev/null; then
        # Parse version from properties file
        local remote_version=""
        if [ -f "$temp_version_file" ] && [ -s "$temp_version_file" ]; then
            # Extract version line and get the value after the equals sign
            remote_version=$(grep "^version=" "$temp_version_file" | cut -d'=' -f2 | tr -d '[:space:]')

            if [ -n "$remote_version" ]; then
                echo "$remote_version"
                rm -f "$temp_version_file"
                return 0
            else
                print_warning "Could not parse version from properties file"
            fi
        else
            print_warning "Properties file is empty or corrupted"
        fi
    else
        print_warning "Failed to download version properties from $version_url"
    fi

    # If we get here, the remote fetch failed
    print_warning "Failed to fetch $version_type version info from remote"
    print_info "This could be due to network issues or server unavailability"
    rm -f "$temp_version_file"
    return 1
}

###########################################################################
# Global error handler
###########################################################################
cleanup_on_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        print_error "An error occurred. Cleaning up..."
        # Clean up any temporary files
        rm -f /tmp/bvm_* 2>/dev/null || true
        # Clean up any incomplete installations
        if [ -n "${INSTALLING_VERSION:-}" ]; then
            print_info "Cleaning up incomplete installation of $INSTALLING_VERSION..."
            rm -rf "$BVM_VERSIONS_DIR/$INSTALLING_VERSION" 2>/dev/null || true
        fi
    fi
}

# Set up error trap
trap 'cleanup_on_error' ERR

###########################################################################
# Main Function
###########################################################################

main() {
    local command="$1"
    shift || true

	setup_colors

    case "$command" in
        "install")
            # Handle --force flag for install command
            local version="$1"
            local force_flag=""

            # Check if second argument is --force
            if [ "$2" = "--force" ]; then
                force_flag="--force"
            # Check if first argument is --force (version comes second)
            elif [ "$1" = "--force" ]; then
                force_flag="--force"
                version="$2"
            fi

            install_version "$version" "$force_flag"
            ;;
        "use")
            use_version "$1"
            ;;
        "local")
            write_bvmrc_version "$1"
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
        "remove"|"rm")
            remove_version "$1"
            ;;
        "uninstall")
            uninstall_bvm
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
        "stats"|"performance"|"usage")
            show_stats
            ;;
        "doctor"|"health")
            check_health
            ;;
        "check-update")
            check_bvm_updates
            ;;
        "version"|"--version"|"-v")
            printf "${GREEN}🥊 BVM (BoxLang Version Manager) v%s\n" "$BVM_VERSION${NORMAL}"
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

# Run main function with all arguments
main "$@"