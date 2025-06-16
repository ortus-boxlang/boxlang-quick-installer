#!/bin/bash

# Exit on any error, undefined variables, and pipe failures
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Download URL Prefixes
DOWNLOAD_URL_PRODUCTION="https://downloads.ortussolutions.com/ortussolutions/boxlang-quick-installer"
DOWNLOAD_URL_SNAPSHOT="https://downloads.ortussolutions.com/ortussolutions/boxlang-quick-installer/snapshot"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Cleanup function for error handling
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Build failed with exit code $exit_code"
        log_info "Cleaning up partial build artifacts..."
        rm -rf build .tmp 2>/dev/null || true
    fi
    exit $exit_code
}

# Set trap for cleanup on exit
trap cleanup EXIT

# Function to detect platform and set hash commands
detect_platform() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        MD5_CMD="md5 -r"
        SHA256_CMD="shasum -a 256"
        log_info "Detected macOS platform"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        MD5_CMD="md5sum"
        SHA256_CMD="sha256sum"
        log_info "Detected Linux platform"
    else
        log_error "Unsupported platform: $OSTYPE"
        exit 1
    fi
}

# Function to check required dependencies
check_dependencies() {
    local deps=("zip" "find" "cp" "jq")

    # Add platform-specific hash commands
    if [[ "$OSTYPE" == "darwin"* ]]; then
        deps+=("md5" "shasum")
    else
        deps+=("md5sum" "sha256sum")
    fi

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Required dependency '$dep' not found"
            exit 1
        fi
    done
    log_success "All dependencies verified"
}

# Function to validate source files
validate_sources() {
    if [ ! -d "src" ]; then
        log_error "Source directory 'src' not found"
        exit 1
    fi

    if [ ! -f "version.json" ]; then
        log_error "version.json not found"
        exit 1
    fi

    if [ ! -f "changelog.md" ]; then
        log_error "changelog.md not found"
        exit 1
    fi

    # Validate version.json format
    if ! jq empty version.json 2>/dev/null; then
        log_error "version.json is not valid JSON"
        exit 1
    fi

    log_success "Source files validated"
}

# Function to generate checksums with platform detection
generate_checksums() {
    local build_dir="$1"
    local tmp_dir="$2"

    log_info "Generating checksums for build files..."

    # Generate MD5 hashes
    find "$build_dir" -type f -not -name "*.md5" -not -name "*.sha256" -exec $MD5_CMD {} + > "$tmp_dir/boxlang-installer.md5"

    # Generate SHA-256 hashes
    find "$build_dir" -type f -not -name "*.md5" -not -name "*.sha256" -exec $SHA256_CMD {} + > "$tmp_dir/boxlang-installer.sha256"

    log_success "Checksums generated"
}

# Main build function
main() {
    log_info "Starting BoxLang Installer build process..."

    # Detect platform and set commands
    detect_platform

    # Check dependencies
    check_dependencies

    # Validate source files
    validate_sources

    # Get version from version.json
    local version=$(jq -r '.INSTALLER_VERSION' version.json)
    log_info "Building version: $version"

    # Cleanup previous builds
    log_info "Cleaning up previous builds..."
    rm -rf build .tmp

    # Create directories
    log_info "Creating build directories..."
    mkdir -p build .tmp

    # Copy source files to build directory
    log_info "Copying source files..."
    if ! cp -r src/* build/; then
        log_error "Failed to copy source files"
        exit 1
    fi

    # Copy additional files
    log_info "Copying additional files..."
    cp -v changelog.md build/changelog.md
    cp -v version.json build/version.json

	# If there is a --snapshot incoming?
	if [[ "$1" == "--snapshot" ]]; then
		log_info "Using snapshot download URL"
		DOWNLOAD_URL="$DOWNLOAD_URL_SNAPSHOT"
	else
		log_info "Using production download URL"
		DOWNLOAD_URL="$DOWNLOAD_URL_PRODUCTION"
	fi

	# Replace @REPO_URL_PREFIX@ in files
	log_info "Replacing @REPO_URL_PREFIX@ in files..."
	find build -type f -exec sed -i "s|@REPO_URL_PREFIX@|$DOWNLOAD_URL|g" {} +

	# Ensure the replacement was successful
	if grep -r "@REPO_URL_PREFIX@" build/; then
		log_error "Replacement of @REPO_URL_PREFIX@ failed"
		exit 1
	fi
	# Replace @REPO_URL_PREFIX@ in all files in the build directory

    # Generate checksums (excluding checksum files themselves)
    generate_checksums "build" ".tmp"

    # Copy checksums to build directory
    log_info "Adding checksums to build..."
    cp -v .tmp/* build/

    # Create zip archive
    log_info "Creating zip archive..."
    local zip_name="boxlang-installer-${version}.zip"

    if ! (cd build && zip -r "$zip_name" ./* > /dev/null); then
        log_error "Failed to create zip archive"
        exit 1
    fi

    # Move zip to build root and create generic name
    mv "build/$zip_name" "build/boxlang-installer.zip"

    # Validate build
    log_info "Validating build..."
    if [ ! -f "build/boxlang-installer.zip" ]; then
        log_error "Build validation failed: zip file not created"
        exit 1
    fi

    # Display build summary
    local zip_size=$(du -h "build/boxlang-installer.zip" | cut -f1 | xargs)
    local file_count=$(find build -type f | wc -l | tr -d ' ')

    log_success "Build completed successfully!"
    echo
    echo "📦 Build Summary:"
    echo "  Version: $version"
    echo "  Archive: boxlang-installer.zip ($zip_size)"
    echo "  Files: $file_count"
    echo "  Location: $(pwd)/build/"
    echo
    echo "🔐 Checksums generated:"
    echo "  MD5: boxlang-installer.md5"
    echo "  SHA256: boxlang-installer.sha256"

    # Clean up temporary files
    rm -rf .tmp

    log_success "Build process completed!"
}

# Run main function
main "$@"