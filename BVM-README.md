# BVM - BoxLang Version Manager

BVM is a simple version manager for BoxLang, similar to jenv or nvm. It allows you to easily install, manage, and switch between different versions of BoxLang.

## 🆚 BVM vs Single-Version Installer

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

## 🍬 Features

- 📦 **Install complete BoxLang environment** - runtime, MiniServer, and helper scripts
- 🔄 **Switch between versions easily** - change your active BoxLang version with one command
- 📋 **List installed versions** - see what's installed locally with `bvm list` or `bvm ls`
- 🌐 **List remote versions** - see what's available for download with `bvm list-remote` or `bvm ls-remote`
- 🗑️ **Clean uninstall** - remove versions you no longer need with `bvm uninstall`, `bvm remove`, or `bvm rm`
- 🔍 **Health check** - verify your BVM installation with `bvm doctor` or `bvm health`
- 🧹 **Cache management** - clean up downloaded files with `bvm clean`
- 🚀 **Execute BoxLang components** - run BoxLang, MiniServer through BVM with version management
- 🔗 **Seamless integration** - wrapper scripts make all tools available in PATH
- ⚡ **Command aliases** - convenient short aliases for all major commands
- 🛠️ **Helper script integration** - all BoxLang helper scripts work with active version
- 🎯 **Smart version detection** - automatically detects actual version numbers from installations

## 🔎 Version Detection & Management

BVM intelligently detects actual version numbers when installing "**latest**" or "**snapshot**" versions, providing clear and accurate version tracking.  A symbolic link named `latest` points to the most recent stable version, while snapshot versions are installed with their full version names (e.g., `1.3.0-snapshot`).

### How Version Detection Works

When you install using aliases like "latest" or "snapshot", BVM:

1. **Downloads the requested version** (latest stable or development snapshot)
2. **Inspects the BoxLang JAR file** to extract the actual version number
3. **Installs under the detected version** (e.g., `1.2.0` or `1.3.0-snapshot`)
4. **Creates appropriate symlinks** (only for "latest" - points to the actual version)

### Benefits

- 🎯 **Clear version tracking** - `bvm list` shows actual version numbers, not generic aliases
- 📋 **Accurate history** - see exactly which versions you have installed
- 🔍 **No confusion** - distinguish between different snapshot builds
- 🔗 **Smart symlinks** - "latest" symlink for convenience, actual versions for clarity

### Example

**Before** (old behavior):

```bash
$ bvm list
Installed BoxLang versions:
  * latest (current)
    snapshot
    1.1.0
```

**After** (new behavior):

```bash
$ bvm list
Installed BoxLang versions:
  * 1.2.0 (current)
    latest → 1.2.0
    1.3.0-snapshot
    1.1.0
```

## 🚀 Quick Start

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

# Get help
bvm help
# or use aliases
bvm --help
bvm -h
```

## 📋 Prerequisites

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

## 🤖 Integration with the System Shell

BVM automatically adds itself and the current BoxLang version to your `PATH`. After installation, restart your terminal or run:

```bash
source ~/.bashrc  # or ~/.zshrc, ~/.profile, etc.
```

## ⚡Commands

### Version Management

- `bvm install <version>` - Install a specific BoxLang version
  - `bvm install latest` - Install latest stable release (detects and installs actual version, e.g., `1.2.0`)
  - `bvm install snapshot` - Install latest development snapshot (detects and installs actual version, e.g., `1.3.0-snapshot`)
  - `bvm install 1.2.0` - Install specific version

- `bvm use <version>` - Switch to a specific BoxLang version
  - Can use actual version numbers (e.g., `1.2.0`, `1.3.0-snapshot`) or `latest` symlink
- `bvm current` - Show currently active BoxLang version
- `bvm uninstall <version>` - Uninstall a specific BoxLang version (use actual version number)
  - Aliases: `bvm remove <version>`, `bvm rm <version>`

### Information

- `bvm list` - List all installed BoxLang versions (shows actual version numbers and symlinks)
  - Alias: `bvm ls`
  - Example output: `1.2.0`, `latest → 1.2.0`, `1.3.0-snapshot`
- `bvm list-remote` - List available BoxLang versions for download
  - Alias: `bvm ls-remote`
- `bvm which` - Show path to current BoxLang installation
- `bvm version` - Show BVM version
  - Aliases: `bvm --version`, `bvm -v`

### Execution

- `bvm exec <args>` - Execute BoxLang with current version
  - Alias: `bvm run <args>`
- `bvm miniserver <args>` - Start BoxLang MiniServer with current version
  - Aliases: `bvm mini-server <args>`, `bvm ms <args>`

### Maintenance

- `bvm clean` - Clean cache and temporary files
- `bvm doctor` - Check BVM installation health
  - Alias: `bvm health`
- `bvm help` - Show help message
  - Aliases: `bvm --help`, `bvm -h`

## 🖥️ What BVM Installs

When you install a BoxLang version with BVM, it downloads and sets up:

### Core Components

- **BoxLang Runtime** (`boxlang`, `bx`) - The main BoxLang interpreter
- **BoxLang MiniServer** (`boxlang-miniserver`, `bx-miniserver`) - Web application server

### Helper Scripts

- **install-bx-module** - BoxLang module installer (available in PATH after installation)
- **install-bx-site** - BoxLang site installer (available in PATH after installation)
- **Other utility scripts** - Various helper tools

### Integration

- **Wrapper scripts** - BVM creates wrapper scripts so you can use `boxlang`, `bx`, `boxlang-miniserver`, etc. directly
- **Version management** - All tools automatically use the currently active BoxLang version
- **Helper script integration** - All helper scripts work with the currently active BoxLang version
- **Smart version detection** - Automatically detects actual version numbers from downloaded installations

## 🧑‍💻 Examples

```bash
# Install and use the latest BoxLang (detects actual version)
bvm install latest    # Downloads latest, detects version (e.g., 1.2.0), installs as 1.2.0
bvm use latest        # Uses the latest symlink

# Install a development snapshot (detects actual version)
bvm install snapshot  # Downloads snapshot, detects version (e.g., 1.3.0-snapshot), installs as 1.3.0-snapshot
bvm use 1.3.0-snapshot

# Install a specific version
bvm install 1.2.0
bvm use 1.2.0

# See what's installed (shows actual version numbers)
bvm list
# Example output:
#   * 1.2.0 (current)
#     latest → 1.2.0
#     1.3.0-snapshot
#     1.1.0

# or use the short alias
bvm ls

# Check what versions are available
bvm list-remote
# or use the short alias
bvm ls-remote

# Run BoxLang REPL
bvm exec
# or use the direct command (after installation)
boxlang

# Run BoxLang MiniServer
bvm miniserver
# or use the direct command
boxlang-miniserver --port 8080

# Install a BoxLang module (using helper script)
install-bx-module bx-orm

# Install a BoxLang site template (using helper script)
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

## 🦾 Migrating from Single-Version Installer to BVM

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

## 🐛 Troubleshooting

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

## 🤝 Contributing

BVM is part of the BoxLang Quick Installer project. To contribute:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

Licensed under the Apache License, Version 2.0. See the LICENSE file for details.

## 🆘Support

### Community Support (Free)

🌐 Website: https://boxlang.io
📖 Documentation: https://boxlang.ortusbooks.com
💾 GitHub: https://github.com/ortus-boxlang/boxlang
💬 Community: https://community.ortussolutions.com/
🧑‍💻 Try: https://try.boxlang.io
📧 Mailing List: https://newsletter.boxlang.io

### Professional Support

🫶 Enterprise Support: https://boxlang.io/plans
🎓 Training: https://learn.boxlang.io
🔧 Consulting: https://www.ortussolutions.com/services/development
📞 Priority Support: Available with enterprise plans
