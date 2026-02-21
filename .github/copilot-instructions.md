# BoxLang Quick Installer - AI Agent Instructions

## Project Overview

This project provides cross-platform installation scripts for BoxLang, a next-generation JVM language. It offers two installation approaches: a simple single-version installer and BVM (BoxLang Version Manager) for advanced version management.

## Architecture & Core Components

### Dual Installation Strategy
- **Single-version installer** (`src/install-boxlang.sh`): Simple, production-focused installation
- **BVM** (`src/bvm.sh`): Advanced version manager similar to nvm/jenv for development workflows
- **BVM installer** (`src/install-bvm.sh`): Dedicated script to install BVM itself and configure the shell environment
- Both installer and BVM share core functionality but differ in version management capabilities

### Modular Helper System
- **`src/helpers/helpers.sh`**: Centralized utility functions for printing, color setup, command detection, and version comparison
- **`src/helpers/install-jre.ps1`**: PowerShell helper for installing a JRE on Windows systems
- All scripts source helpers either locally or download them dynamically from CDN
- Helpers are versioned and replaceable via `@build.version@` token replacement

### Cross-Platform Support
- **Unix scripts** (`.sh`): macOS and Linux with bash/zsh compatibility
- **Windows scripts** (`.bat`, `.ps1`): Batch and PowerShell variants
- Platform detection and tool-specific commands (shasum vs sha256sum, etc.)

### Assets
- **`src/assets/`**: Static assets used by the installer web UI
  - `index.bxm`: BoxLang template served by the miniserver installer
  - `boxlang-logo.png`, `boxlang-miniserver.png`, `boxlang.jpeg`: Branding images

### Documentation
- **`README.md`**: Main project documentation
- **`BVM-README.md`**: BVM-specific documentation and usage guide

## Key Development Patterns

### Version Token System
- Use `@build.version@` placeholders in source files
- `build.sh` performs token replacement during build process
- `version.json` contains the authoritative version number

### Error Handling Strategy
- `set -e` for strict error handling in most scripts
- Test runner deliberately avoids `set -e` to continue on test failures
- Graceful fallbacks for missing dependencies (jq, color support, etc.)

### Testing Framework
- Custom bash testing framework in `tests/` with automatic test discovery
- Test files follow `*_test.sh` naming pattern in `tests/specs/`
- `tests/run.sh` automatically discovers and runs all test suites
- Mock-based testing for external dependencies

## Critical Workflows

### Building & Versioning
```bash
# Build all artifacts with version replacement
./build.sh

# Bump version (updates version.json and creates git tag)
./bump.sh [patch|minor|major]
```

Build output lands in `build/` and includes:
- Shell scripts (`install-boxlang.sh`, `install-bx-module.sh`, `install-bx-site.sh`)
- Windows scripts (`install-boxlang.bat`, `install-boxlang.ps1`, `install-bx-module.bat`, `install-bx-module.ps1`, `install-jre.ps1`)
- `boxlang-installer.zip` bundling all artifacts
- `boxlang-installer.md5` and `boxlang-installer.sha256` checksums
- `version.json` and `changelog.md`

### Cross-Platform Linux Testing (Docker)
Convenience scripts at the repo root launch Docker containers with `src/` mounted for local testing:
```bash
./alpine.sh   # Opens sh shell in Alpine Linux container
./ubuntu.sh   # Opens bash shell in Ubuntu container
```

### Testing
```bash
# Run all tests with auto-discovery
cd tests && ./run.sh

# Run specific test suite
cd tests && ./run.sh specs/helpers_test.sh

# List available test suites
cd tests && ./run.sh --list
```

Current test suites in `tests/specs/`:
- `helpers_test.sh`: Unit tests for helper functions
- `java_version_test.sh`: Tests for Java version detection logic
- `preflight_check_test.sh`: Tests for system pre-flight checks

### Installation Testing
- Use `--force` flag for reinstalling during development
- Test both installer paths: direct installation and BVM workflows
- Use `alpine.sh` / `ubuntu.sh` for quick Linux compatibility testing
- Verify cross-platform compatibility, especially path handling and tool detection

## Project-Specific Conventions

### Script Sourcing Pattern
Scripts check multiple locations for helpers in priority order:
1. Local relative path (development)
2. Installation path (deployed)
3. Dynamic download from CDN (fallback)

### Color & Terminal Handling
- Graceful handling of missing `TERM` or unsupported terminals
- Color setup detection via `tput` with fallbacks
- CI-friendly defaults (`TERM="xterm-256color"` for unknown environments)

### URL Structure
- Base URLs defined as constants for different artifact types
- Consistent naming: `latest`, `snapshot`, version-specific downloads
- SHA-256 checksum verification for BoxLang 1.3.0+ releases

## Integration Points

### External Dependencies
- **BoxLang downloads**: downloads.ortussolutions.com with version-specific URLs
- **ForgeBox modules**: Modules installed via `install-bx-module` scripts
- **Java detection**: Platform-specific Java version checking and JAVA_HOME handling
- **Package managers**: Homebrew (macOS), apt/dnf (Linux) for prerequisite installation

### BVM Directory Structure
```
~/.bvm/
├── versions/          # Installed BoxLang versions
├── current -> versions/X.Y.Z  # Symlink to active version
├── cache/            # Download cache
├── scripts/          # Helper scripts
└── config            # BVM configuration
```

## Key Files for Understanding

- **`src/helpers/helpers.sh`**: Core utility functions and patterns
- **`src/bvm.sh`**: Complete version management implementation
- **`src/install-bvm.sh`**: BVM installer and shell environment setup
- **`src/install-bx-site.sh`**: BoxLang miniserver website installer (in progress)
- **`src/helpers/install-jre.ps1`**: Windows JRE installation helper
- **`src/assets/index.bxm`**: BoxLang template for miniserver installer UI
- **`tests/run.sh`**: Test framework architecture
- **`build.sh`**: Build process and artifact generation
- **`version.json`**: Single source of truth for versioning
- **`BVM-README.md`**: BVM-specific documentation
- **`alpine.sh`** / **`ubuntu.sh`**: Docker convenience scripts for Linux testing

## Common Tasks

- **Adding new functionality**: Extend helpers.sh or create new utility scripts
- **Cross-platform features**: Test on macOS, Linux, and Windows PowerShell
- **Version management**: Update version.json, test with both installer approaches
- **Testing new features**: Add tests to `tests/specs/` following naming convention
- **URL changes**: Update base URL constants in relevant scripts
