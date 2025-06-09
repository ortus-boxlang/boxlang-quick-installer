# ⚡︎ Project Jericho - BoxLang Quick Installer

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

This is the BoxLang quick installer for Mac, *NIX, and Windows systems. It allows you to quickly install the BoxLang runtime and its modules, as well as the BoxLang MiniServer.
It also comes with several command scripts to help you manage your BoxLang installation and modules.

## Command Scripts

The following commands are available for both Windows and Mac/*NIX systems. Please note that all commands have a `--help` option to get more information on how to use them:

- `install-boxlang`: Installs the latest, snapshot or any version of BoxLang.
- `install-bx-module`: Installs modules from ForgeBox to your system or local project.
- `install-jre.ps1`: Installs the Java Runtime Environment (JRE) 21 for BoxLang on Windows systems.

## Binaries

The following binaries are installed to your system or local project:

- `boxlang` or `bx`: Runs the BoxLang Runtime.  Please see the [BoxLang documentation](https://boxlang.ortusbooks.com/getting-started/running-boxlang) for more information on how to use it.
- `boxlang-miniserver` or `bx-miniserver`: Runs the BoxLang MiniServer.  Please see the [BoxLang documentation](https://boxlang.ortusbooks.com/getting-started/running-boxlang-miniserver) for more information on how to use it.

## Requirements

- Java 21 or higher
- A supported operating system (Mac, *NIX, or Windows)
- Following Packages for Mac/Unix systems:
  - `curl`
  - `unzip`
  - `jq`

## Usage

### Mac and *NIX

You can use the following command to install BoxLang on Mac and *NIX systems:

```bash
# User installation
/bin/bash -c "$(curl -fsSL https://install.boxlang.io)"

# System-wide installation
sudo /bin/bash -c "$(curl -fsSL https://install.boxlang.io)"

# Get Help
install-boxlang --help
```

### Windows

You can use the following command to install BoxLang on Windows:

```PowerShell
Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString(''https://install-windows.boxlang.io''))"'
```

## Contributing

Here is the [contribution guide](CONTRIBUTING.md) for this project.

## License

This project is licensed under the [Apache License, Version 2.0](LICENSE).

----

Made with ♥️ in USA 🇺🇸, El Salvador 🇸🇻 and Spain 🇪🇸
