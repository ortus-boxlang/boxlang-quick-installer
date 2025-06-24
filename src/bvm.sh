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
SNAPSHOT_URL="$DOWNLOAD_BASE_URL/boxlang-snapshot.zip"
LATEST_MINISERVER_URL="$MINISERVER_BASE_URL/boxlang-miniserver-latest.zip"
SNAPSHOT_MINISERVER_URL="$MINISERVER_BASE_URL/boxlang-miniserver-snapshot.zip"
INSTALLER_URL="$INSTALLER_BASE_URL/boxlang-installer.zip"

# Helpers
if [ -f "${BVM_HOME}/scripts/helpers/helpers.sh" ]; then
    source "${BVM_HOME}/scripts/helpers/helpers.sh"
else
	printf "${RED}Error: BVM helper scripts not found. Please ensure BVM is installed correctly.${NORMAL}\n"
	printf "${YELLOW}You can reinstall BVM using the installer script:${NORMAL}\n"
	printf "curl -fsSL https://boxlang.io/install-bvm.sh | bash"
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
        *)
            # Return the version as-is for all other versions (including snapshot)
            echo "$requested_version"
            ;;
    esac
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
    printf "  ${GREEN}doctor${NORMAL}               Check BVM installation health\n"
    printf "  ${GREEN}version${NORMAL}              Show BVM version\n"
    printf "  ${GREEN}help${NORMAL}                 Show this help message\n\n"

    printf "${BOLD}EXAMPLES:${NORMAL}\n"
    printf "  bvm install latest\n"
    printf "  bvm install 1.2.0\n"
    printf "  bvm install latest --force\n"
    printf "  bvm use 1.2.0\n"
    printf "  bvm list\n"
    printf "  bvm current\n"
    printf "  bvm exec --version\n"
    printf "  bvm run --help\n"
    printf "  bvm miniserver --port 8080\n"
    printf "  bvm clean\n"
    printf "  bvm doctor\n"
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
    local temp_file="/tmp/bvm_releases.json"

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

    print_info "Installing BoxLang $version..."

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

    # Download BoxLang runtime
    print_info "Downloading BoxLang runtime from $boxlang_url"
    if ! env curl -fsSL --progress-bar -o "$boxlang_cache" "$boxlang_url"; then
        print_error "Failed to download BoxLang runtime"
        rm -rf "$install_dir"
        return 1
    fi

    # Download BoxLang MiniServer
    print_info "Downloading BoxLang MiniServer from $miniserver_url"
    if ! env curl -fsSL --progress-bar -o "$miniserver_cache" "$miniserver_url"; then
        print_error "Failed to download BoxLang MiniServer"
        rm -rf "$install_dir"
        return 1
    fi

    # Extract BoxLang runtime
    print_info "Extracting BoxLang runtime..."
    if ! unzip -q "$boxlang_cache" -d "$install_dir"; then
        print_error "Failed to extract BoxLang runtime"
        rm -rf "$install_dir"
        return 1
    fi

    # Extract BoxLang MiniServer
    print_info "Extracting BoxLang MiniServer..."
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
        print_info "🔎 Version alias requested, detecting actual version number..."

        # Look for boxlang JAR file in lib directory to detect version
        local lib_dir="$install_dir/lib"
		# Find boxlang-*.jar files matching the pattern boxlang-{version}.jar or boxlang-{version}-snapshot.jar
		local jar_file=$(find "$lib_dir" -name "boxlang-*.jar" -type f | head -1)

		if [ -n "$jar_file" ]; then
			# Extract filename and get version from it
			local jar_filename=$(basename "$jar_file")
			# Remove boxlang- prefix and .jar suffix to get version
			local detected_version=$(echo "$jar_filename" | sed 's/^boxlang-//' | sed 's/\.jar$//')

			# Use extract_semantic_version helper to get clean semantic version
			actual_version=$(extract_semantic_version "$detected_version")

			# For snapshot versions, append the snapshot suffix if it's not already there
			if [ "$original_version" = "snapshot" ] && ! isSnapshotVersion "$actual_version"; then
				# Check if the original detected version had snapshot info
				if isSnapshotVersion "$detected_version"; then
					actual_version="$detected_version"
				else
					actual_version="${actual_version}-snapshot"
				fi
			fi

			print_info "Detected version: $actual_version (from $jar_filename)"

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
				print_info "Force reinstalling - removing existing $actual_version..."
				rm -rf "$actual_version_dir"
			fi

			# Move from temporary to actual version directory
			version_dir="$actual_version_dir"
			mkdir -p "$(dirname "$version_dir")"
			mv "$install_dir" "$version_dir"
			version="$actual_version"
		else
			print_error "Could not find BoxLang JAR file in lib directory, using '$original_version'"
			# cleanup and exit, this is a failure
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

    # Create version alias symlink for latest only
    if [ "$original_version" = "latest" ]; then
        local alias_link="$BVM_VERSIONS_DIR/latest"
        print_info "Creating latest symlink to $version..."

        # Remove existing symlink if it exists
        rm -f "$alias_link"

        # Create new symlink pointing to the actual version directory
        ln -sf "$version" "$alias_link"
    fi

    # Clean up cache files for non-latest/snapshot versions
    if [ "$original_version" != "latest" ] && [ "$original_version" != "snapshot" ]; then
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

    # Resolve version alias (latest, snapshot) to actual version
    local resolved_version
    resolved_version=$(resolve_version_alias "$version")

    local version_dir="$BVM_VERSIONS_DIR/$resolved_version"

    if [ ! -d "$version_dir" ]; then
        if [ "$version" = "latest" ] || [ "$version" = "snapshot" ]; then
            print_error "No BoxLang $version version is installed"
            print_info "Install it with: bvm install $version"
        else
            print_error "BoxLang $version is not installed"
            print_info "Install it with: bvm install $version"
        fi
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
        "doctor"|"health")
            check_health
            ;;
        "version"|"--version"|"-v")
            printf "${GREEN}📦 BVM (BoxLang Version Manager) v%s\n" "$BVM_VERSION${NORMAL}"
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