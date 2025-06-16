# BVM - BoxLang Version Manager

BVM is a simple version manager for BoxLang, similar to jenv or nvm. It allows you to easily install, manage, and switch between different versions of BoxLang.

## BVM vs Single-Version Installer

**Choose BVM if you:**
- 🔄 Work on multiple projects that might need different BoxLang versions
- 🧪 Want to test your code against different BoxLang releases
- 🚀 Need to switch between stable and snapshot versions
- 📦 Want centralized management of BoxLang installations
- 🛠️ Are a BoxLang developer or advanced user

**Choose the single-version installer (`install-boxlang.sh`) if you:**
- 📌 Only need one BoxLang version system-wide
- 🎯 Want the simplest possible installation
- 🏢 Are setting up production servers with a specific BoxLang version
- ⚡ Want the fastest installation with minimal overhead

**Both installers provide identical functionality:**
- ✅ Same BoxLang runtime and MiniServer
- ✅ Same helper scripts (`install-bx-module`, `install-bx-site`, etc.)
- ✅ Same command-line tools (`boxlang`, `bx`, `boxlang-miniserver`, etc.)
- ✅ Same installation quality and reliability

The only difference is that BVM adds version management capabilities on top.

## Features

- 📦 **Install complete BoxLang environment** - runtime, MiniServer, and helper scripts
- 🔄 **Switch between versions easily** - change your active BoxLang version with one command
- 📋 **List installed versions** - see what's installed locally
- 🌐 **List remote versions** - see what's available for download
- 🗑️ **Clean uninstall** - remove versions you no longer need
- 🔍 **Health check** - verify your BVM installation
- 🧹 **Cache management** - clean up downloaded files
- 🚀 **Execute BoxLang components** - run BoxLang, MiniServer, and helper scripts through BVM
- 🔗 **Seamless integration** - wrapper scripts make all tools available in PATH

## Quick Start

### Installation

```bash
# Install BVM
curl -fsSL https://boxlang.io/install-bvm.sh | bash

# Or download and run locally
wget https://raw.githubusercontent.com/ortus-boxlang/boxlang-quick-installer/main/src/install-bvm.sh
chmod +x install-bvm.sh
./install-bvm.sh
```

### Basic Usage

```bash
# Install the latest stable BoxLang version
bvm install latest

# Switch to the latest version
bvm use latest

# Check current version
bvm current

# List installed versions
bvm list

# Run BoxLang
bvm exec --version
```

## Commands

### Version Management

- `bvm install <version>` - Install a specific BoxLang version
  - `bvm install latest` - Install latest stable release
  - `bvm install snapshot` - Install latest development snapshot
  - `bvm install 1.2.0` - Install specific version

- `bvm use <version>` - Switch to a specific BoxLang version
- `bvm current` - Show currently active BoxLang version
- `bvm uninstall <version>` - Uninstall a specific BoxLang version

### Information

- `bvm list` - List all installed BoxLang versions
- `bvm list-remote` - List available BoxLang versions for download
- `bvm which` - Show path to current BoxLang installation
- `bvm version` - Show BVM version

### Execution

- `bvm exec <args>` - Execute BoxLang with current version
- `bvm run <args>` - Alias for exec
- `bvm miniserver <args>` - Start BoxLang MiniServer with current version
- `bvm module <args>` - Run install-bx-module script with current version
- `bvm site <args>` - Run install-bx-site script with current version

### Maintenance

- `bvm clean` - Clean cache and temporary files
- `bvm doctor` - Check BVM installation health
- `bvm help` - Show help message

## What BVM Installs

When you install a BoxLang version with BVM, it downloads and sets up:

### Core Components
- **BoxLang Runtime** (`boxlang`, `bx`) - The main BoxLang interpreter
- **BoxLang MiniServer** (`boxlang-miniserver`, `bx-miniserver`) - Web application server

### Helper Scripts
- **install-bx-module** - BoxLang module installer
- **install-bx-site** - BoxLang site installer
- **Other utility scripts** - Various helper tools

### Integration
- **Wrapper scripts** - BVM creates wrapper scripts so you can use `boxlang`, `bx`, `boxlang-miniserver`, etc. directly
- **Version management** - All tools automatically use the currently active BoxLang version

## Examples

```bash
# Install and use the latest BoxLang
bvm install latest
bvm use latest

# Install a specific version
bvm install 1.2.0
bvm use 1.2.0

# See what's installed
bvm list

# Check what versions are available
bvm list-remote

# Run BoxLang REPL
bvm exec
# or use the direct command (after installation)
boxlang

# Run BoxLang MiniServer
bvm miniserver
# or use the direct command
boxlang-miniserver --port 8080

# Install a BoxLang module
bvm module bx-orm
# or use the direct command
install-bx-module bx-orm

# Install a BoxLang site template
bvm site mysite
# or use the direct command
install-bx-site mysite

# Run a BoxLang script
bvm exec myscript.bx

# Get BoxLang version
bvm exec --version

# Check BVM health
bvm doctor

# Clean up cache
bvm clean
```

## Migrating from Single-Version Installer to BVM

If you currently have BoxLang installed via `install-boxlang.sh` and want to switch to BVM for version management:

### 1. Uninstall Current BoxLang (Recommended)
```bash
# Remove system-wide installation
sudo install-boxlang.sh --uninstall

# Or remove user installation
install-boxlang.sh --uninstall
```

### 2. Install BVM
```bash
curl -fsSL https://boxlang.io/install-bvm.sh | bash
```

### 3. Install Your Preferred BoxLang Version
```bash
# Install the same version you had before
bvm install latest  # or specific version like 1.2.0
bvm use latest
```

### 4. Verify Everything Works
```bash
bvm doctor
boxlang --version
```

**Note:** Your BoxLang home directory (`~/.boxlang`) with modules, settings, and data will be preserved during migration.

## Prerequisites

- **curl** - For downloading BoxLang releases
- **unzip** - For extracting archives
- **jq** - For parsing JSON (optional, fallback available)
- **Java 21+** - Required to run BoxLang

### Installing Prerequisites

**macOS (with Homebrew):**
```bash
brew install curl unzip jq
```

**Ubuntu/Debian:**
```bash
sudo apt update && sudo apt install curl unzip jq
```

**RHEL/CentOS/Fedora:**
```bash
sudo dnf install curl unzip jq
```

## Integration with Shell

BVM automatically adds itself and the current BoxLang version to your PATH. After installation, restart your terminal or run:

```bash
source ~/.bashrc  # or ~/.zshrc, ~/.profile, etc.
```

## Troubleshooting

### BVM not found after installation
- Restart your terminal
- Check that `~/.bvm/bin` is in your PATH
- Run `source ~/.bashrc` (or your shell's profile file)

### BoxLang not found after switching versions
- Run `bvm doctor` to check installation health
- Verify the version exists with `bvm list`
- Try `bvm use <version>` again

### Download failures
- Check your internet connection
- Verify the version exists with `bvm list-remote`
- Try clearing cache with `bvm clean`

### Health check
```bash
bvm doctor
```

This will check your BVM installation and identify any issues.

## Contributing

BVM is part of the BoxLang Quick Installer project. To contribute:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

Licensed under the Apache License, Version 2.0. See the LICENSE file for details.

## Support

- 🌐 Website: https://boxlang.io
- 📖 Documentation: https://boxlang.io/docs
- 💾 GitHub: https://github.com/ortus-boxlang/boxlang
- 💬 Community: https://boxlang.io/community
