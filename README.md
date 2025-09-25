# ⚡︎ BoxLang Quick Installer

> A next generation multi-runtime dynamic programming language for the JVM. InvokeDynamic is our first name!

```
██████   ██████  ██   ██ ██       █████  ███    ██  ██████
██   ██ ██    ██  ██ ██  ██      ██   ██ ████   ██ ██
██████  ██    ██   ███   ██      ███████ ██ ██  ██ ██   ███
██   ██ ██    ██  ██ ██  ██      ██   ██ ██  ██ ██ ██    ██
██████   ██████  ██   ██ ███████ ██   ██ ██   ████  ██████
```

----

Because of God's grace, this project exists. If you don't like this, then don't read it, it's not for you.

>"Therefore being justified by faith, we have peace with God through our Lord Jesus Christ:
By whom also we have access by faith into this grace wherein we stand, and rejoice in hope of the glory of God.
And not only so, but we glory in tribulations also: knowing that tribulation worketh patience;
And patience, experience; and experience, hope:
And hope maketh not ashamed; because the love of God is shed abroad in our hearts by the
Holy Ghost which is given unto us. ." Romans 5:5

----

The BoxLang Quick Installer provides convenient installation scripts for Mac, Linux (including Alpine Linux containers), and Windows systems to get BoxLang up and running in minutes. Choose between a single-version installer for simplicity or BVM (BoxLang Version Manager) for advanced version management.

## 🚀 Quick Start

**Mac and Linux:**

```bash
# Single version (simple)
/bin/bash -c "$(curl -fsSL https://install.boxlang.io)"

# With automatic Java installation
curl -fsSL https://install.boxlang.io | bash -s -- --with-jre
```

**Windows:**

```powershell
# Single version (simple)
powershell -NoExit -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://install-windows.boxlang.io'))"
```

### Verify Installation

```bash
# Check BoxLang version
boxlang --version

# Start BoxLang REPL
boxlang

# Start MiniServer
boxlang-miniserver --port 8080
```

## 📋 Prerequisites

### All Platforms

- **Java 21+** - Required to run BoxLang
  - ✨ Can be automatically installed with `--with-jre` option (supports musl libc on Alpine Linux)
  - Or install manually (see instructions below)
- **bash** - Required shell (automatically installed on Alpine Linux)

### Mac/Linux Additional Requirements

- **curl** - For downloading releases
- **unzip** - For extracting archives
- **jq** - For JSON parsing (optional, fallback available)

### Installing Prerequisites

**macOS (with Homebrew):**

```bash
brew install curl unzip jq
```

**Ubuntu/Debian:**

```bash
sudo apt update && sudo apt install curl unzip jq default-jdk
```

**RHEL/CentOS/Fedora:**

```bash
sudo dnf install curl unzip jq java-21-openjdk
```

**Alpine Linux:**

```bash
# Prerequisites automatically installed by installer
apk add --no-cache bash curl unzip
# Java 21 automatically installed with --with-jre option
```

**Windows:**

- Java 21+ from [Oracle](https://www.oracle.com/java/technologies/downloads/) or [OpenJDK](https://openjdk.org/)
- PowerShell 5.1+ (included with Windows 10+)

## 📦 Installation Options

### Option 1: Single-Version Installer (Recommended for Most Users)

**Choose this if you:**

- 📌 Need one BoxLang version system-wide
- 🎯 Want the simplest possible installation
- 🏢 Are setting up production servers
- ⚡ Want the fastest installation with minimal overhead

**Features:**

- ✅ Installs latest stable BoxLang version
- ✅ Sets up BoxLang runtime and MiniServer
- ✅ Includes all helper scripts
- ✅ Automatic PATH configuration
- ✅ User or system-wide installation options

### Option 2: BVM (BoxLang Version Manager)

**Choose this if you:**

- 🔄 Work on multiple projects needing different BoxLang versions
- 🧪 Want to test code against different BoxLang releases
- 🚀 Need to switch between stable and snapshot versions
- 📦 Want centralized management of BoxLang installations
- 🛠️ Are a BoxLang developer or advanced user

**Features:**

- ✅ Install and manage multiple BoxLang versions
- ✅ Switch between versions with one command
- ✅ List local and remote versions
- ✅ Clean uninstall capabilities
- ✅ Health check and diagnostics

## ⚙️ Command Options

Here are the available options for the install command.

| Option | Short | Description |
|--------|-------|-------------|
| `--help` | `-h` | Show this help message |
| `--uninstall` | | Remove BoxLang from the system |
| `--check-update` | | Check if a newer version is available |
| `--system` | | Force system-wide installation (requires sudo) |
| `--force` | | Force reinstallation even if already installed |
| `--with-commandbox` | | Install CommandBox without prompting |
| `--without-commandbox` | | Skip CommandBox installation |
| `--with-jre` | | ✨ Automatically install Java 21 JRE if not found |
| `--without-jre` | | ✨ Skip Java installation (manual installation required) |
| `--yes` | `-y` | Use defaults for all prompts (installs CommandBox and Java) |

### Notes

- Use `--system` when you want to install BoxLang for all users on the system
- The `--force` option is useful when you need to reinstall or update an existing installation
- `--yes` automatically accepts all defaults, including installing CommandBox and Java
- `--with-commandbox` and `--without-commandbox` give you explicit control over CommandBox installation
- ✨ `--with-jre` automatically installs OpenJDK 21 JRE if Java 21+ is not found
- ✨ `--without-jre` skips Java installation entirely (you must install Java manually)
- ✨ The installer can detect your OS (macOS/Linux/Alpine) and architecture (x64/ARM64) for Java installation
- 🐋 **Container-friendly** - Works in Docker containers with minimal base images

## 🛠️ What Gets Installed

### Core Components

- **BoxLang Runtime** (`boxlang`, `bx`) - The main BoxLang Runtime Engine
- **BoxLang MiniServer** (`boxlang-miniserver`, `bx-miniserver`) - Lightweight web application server

### Helper Scripts

- **install-bx-module** - Install modules from ForgeBox
- **install-jre** (Windows) - Install Java Runtime Environment

### Directory Structure

```
~/.boxlang/           # BoxLang home directory
├── bin/              # Executable binaries
├── lib/              # Core libraries
├── scripts/          # Installed scripts

# System installation locations:
System Wide: /usr/local/bin/       # Binaries (Linux/Mac)
Local User: ~/.local/bin/          # Binaries (Linux/Mac)

C:\BoxLang\  # Installation directory (Windows)
```

## 📖 Help Command

Always make sure to run the `--help` command to get the latest and greatest command usage.

```bash
📦 BoxLang® Quick Installer v@build.version@

This script installs the BoxLang® runtime, MiniServer and tools on your system.

Usage:
  install-boxlang [version] [options]
  install-boxlang --help

Arguments:
  [version]         (Optional) Specify which version to install
                    - 'latest' (default): Install the latest stable release
                    - 'snapshot': Install the latest development snapshot
                    - '1.2.0': Install a specific version number

Options:
  --help, -h            Show this help message
  --uninstall           Remove BoxLang from the system
  --check-update        Check if a newer version is available
  --system              Force system-wide installation (requires sudo)
  --force               Force reinstallation even if already installed
  --with-commandbox     Install CommandBox without prompting
  --without-commandbox  Skip CommandBox installation
  --with-jre            ✨ Automatically install Java 21 JRE if not found
  --without-jre         ✨ Skip Java installation (manual installation required)
  --yes, -y             Use defaults for all prompts (installs CommandBox and Java)

Examples:
  install-boxlang
  install-boxlang latest
  install-boxlang snapshot
  install-boxlang 1.2.0
  install-boxlang --force
  install-boxlang --with-commandbox
  install-boxlang --without-commandbox
  install-boxlang --with-jre
  install-boxlang --without-jre
  install-boxlang --with-commandbox --with-jre
  install-boxlang --yes
  install-boxlang --uninstall
  install-boxlang --check-update
  sudo install-boxlang --system

Non-Interactive Usage:
  🌐 Install with CommandBox: curl -fsSL https://boxlang.io/install.sh | bash -s -- --with-commandbox
  🌐 Install without CommandBox: curl -fsSL https://boxlang.io/install.sh | bash -s -- --without-commandbox
  🌐 Install with Java auto-install: curl -fsSL https://boxlang.io/install.sh | bash -s -- --with-jre
  🌐 Full auto-install (Java + CommandBox): curl -fsSL https://boxlang.io/install.sh | bash -s -- --yes
  🌐 Install with defaults: curl -fsSL https://boxlang.io/install.sh | bash -s -- --yes
```

## 🎯 Detailed Usage

### Single-Version Installer Commands

```bash
# Install latest stable version
install-boxlang

# Install specific version
install-boxlang --version 1.2.0

# Install snapshot version
install-boxlang --snapshot

# ✨ NEW: Auto-install with Java (if not found)
install-boxlang --with-jre

# ✨ NEW: Skip Java installation entirely
install-boxlang --without-jre

# ✨ NEW: Full automation (Java + CommandBox)
install-boxlang --yes

# ✨ NEW: Combine options for specific setup
install-boxlang --with-commandbox --with-jre

# System-wide installation (requires sudo)
sudo install-boxlang --system

# Uninstall BoxLang
install-boxlang --uninstall

# Get help
install-boxlang --help
```

### Module Management

```bash
# Install a module globally
install-bx-module bx-orm

# Install multiple modules
install-bx-module bx-orm,bx-mail,bx-db

# Install to specific directory
install-bx-module bx-orm --directory ./modules

# Install specific version
install-bx-module bx-orm@1.0.0

# Get help
install-bx-module --help
```

## 🌐 Running Applications

### BoxLang Runtime

```bash
# Start REPL
boxlang

# Run a class
boxlang Task.bx

# Run a script
boxlang myscript.bxs

# Execute inline code
boxlang -c "println('Hello BoxLang!')"

# Compile to bytecode
boxlang compile myscript.bx

# Show version
boxlang --version
```

### BoxLang MiniServer

```bash
# Start with default settings
boxlang-miniserver

# Specify port
boxlang-miniserver --port 8080

# Set web root
boxlang-miniserver --webroot ./public

# Enable development mode
boxlang-miniserver --dev

# Show all options
boxlang-miniserver --help
```

## 🔧 Configuration

### Environment Variables

```bash
# BoxLang home directory
export BOXLANG_HOME=~/.boxlang

# Java options for BoxLang
export BOXLANG_OPTS="-Xmx2g -Xms512m"

# Module search paths
export BOXLANG_MODULES_PATH="./modules:~/.boxlang/modules"
```

## 🐛 Troubleshooting

### Common Issues

**BoxLang not found after installation:**

```bash
# Restart terminal or reload profile
source ~/.bashrc  # or ~/.zshrc

# Check PATH
echo $PATH | grep boxlang
```

**Java not found:**

```bash
# ✨ NEW: Let BoxLang installer handle Java automatically
install-boxlang --with-jre

# Or check Java installation manually
java -version

# Manual Java installation options:
# Install Java 21 (Ubuntu/Debian)
sudo apt install default-jdk

# Install Java 21 (macOS)
brew install openjdk@21

# Download from Adoptium (cross-platform)
# https://adoptium.net/temurin/releases/
```

**Permission denied errors:**

```bash
# Fix permissions for user installation
chmod +x ~/.boxlang/bin/*

# Or use system installation
sudo install-boxlang --system
```

**Module installation fails:**

```bash
# Check network connectivity
curl -I https://forgebox.io

# Clear module cache
rm -rf ~/.boxlang/modules/.cache

# Install with verbose output
install-bx-module bx-orm --verbose
```

### Getting Help

```bash
# Command-specific help
install-boxlang --help
install-bx-module --help
bvm help

# Health check (BVM only)
bvm doctor

# Verbose output for debugging
install-boxlang --verbose
install-bx-module --verbose
```

## 📚 Resources

### Documentation

- 📖 [Official Documentation](https://boxlang.io/docs)
- 🚀 [Getting Started Guide](https://boxlang.io/docs/getting-started)
- 📋 [Language Reference](https://boxlang.io/docs/reference)
- 🔧 [Module Development](https://boxlang.io/docs/modules)

### Community

- 💬 [Discord Community](https://boxlang.io/discord)
- 📧 [Mailing List](https://boxlang.io/mailing-list)
- 🐛 [Issue Tracker](https://github.com/ortus-boxlang/boxlang/issues)
- 💡 [Feature Requests](https://github.com/ortus-boxlang/boxlang/discussions)

### Examples

- 🧑‍💻 [Interactive Playground](https://try.boxlang.io)
- 📁 [Sample Applications](https://github.com/ortus-boxlang/bx-demos)
- 🎓 [Tutorials](https://learn.boxlang.io)

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### Reporting Issues

1. Check existing [issues](https://ortussolutions.atlassian.net/browse/BLINSTALL)
2. Create a detailed bug report with:
   - Operating system and version
   - BoxLang version
   - Steps to reproduce
   - Expected vs actual behavior

### Contributing Code

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes
4. Add tests if applicable
5. Update documentation
6. Submit a pull request

### Testing

Help test new features and releases:

```bash
# Install snapshot for testing
bvm install snapshot
bvm use snapshot

# Report any issues found
```

## 📄 License

This project is licensed under the [Apache License, Version 2.0](license.txt).

## 🆘 Support

### Community Support (Free)

- 🌐 Website: https://boxlang.io
- 📖 Documentation: https://boxlang.ortusbooks.com
- 💾 GitHub: https://github.com/ortus-boxlang/boxlang
- 💬 Community: https://community.ortussolutions.com/
- 🧑‍💻 Try: https://try.boxlang.io
- 📧 Mailing List: https://newsletter.boxlang.io

### Professional Support

- 🫶 Enterprise Support: https://boxlang.io/plans
- 🎓 Training: https://learn.boxlang.io
- 🔧 Consulting: https://www.ortussolutions.com/services/development
- 📞 Priority Support: [Available with enterprise plans](https://boxlang.io/plans)


----

Made with ♥️ in USA 🇺🇸, El Salvador 🇸🇻 and Spain 🇪🇸
