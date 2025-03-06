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

This is the BoxLang quick installer for Mac and *NIX systems. It will download and install the latest version of BoxLang and the
BoxLang MiniServer for you.

You can also install any version of BoxLang by passing the version number as an argument to the script.

## Usage

```bash
/bin/bash -c "$(curl -fsSL https://downloads.ortussolutions.com/ortussolutions/boxlang/install-boxlang.sh)"
```

```PowerShell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/ortus-boxlang/boxlang-quick-installer/development/src/Run-InstallBoxLang.ps1'))
```

## Module Installation

You can use the following command for module installation to the installed BoxLang Home:

```bash
install-bx-module <module-name>
```

If you want to install it to a local boxlang_modules folder you can use the following command:

```bash
install-bx-module <module-name> --local
```

## Contributing

- All code should be formatted using either our Java Formatter or the CFFormatter.
- All code should have a license/copyright header based on [CodeHeader.txt](workbench/CodeHeader.txt)

Made with ♥️ in USA 🇺🇸, El Salvador 🇸🇻 and Spain 🇪🇸
