# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

* * *

## [Unreleased]


### Added

- You can now use `bvm install snapshot` and `bvm use snapshot` to install and use the latest snapshot version of BoxLang.
- The `bvm list` command now shows both the symlinked version and the actual version of BoxLang installed.

### Fixed

- Fixed progress bars for downloads in the `bvm` command to use the correct `curl` flags.
- `snapshot` and `latest` version detection now uses the `version-latest.properties` and `version-snapshot.properties` files to determine the latest version.  This also fixes the issue where the miniserver text appeared in the version number.

## [1.15.0] - 2025-07-02

### Added

- SHA-256 checksum verification for downloads to ensure integrity.
- New `bvm stats` command to show statistics about the BoxLang installation, including the number of installed modules, their versions, and the total size of the installation.
- More internal docs
- install-bx-module helper tests
- Network connection checker for bvm to assist on disconnected systems
- Global cleanup helper in case something goes wrong during version installations

### Changed

- Updated the helpers to be installed from the CDN

### Fixed

- Invalid usage of `mktemp` by not using `xxx` placeholders, which caused issues on some systems.
- Fixed the `install-bx-module` script to use the right helpers path.
- Build script was not updating the rigth `@build.version` so it was never updated in the bvm and installer.'

* * *

## [1.14.0] - 2025-06-24

### Added

- If doing `bvm install snapshot`, it will now always force install the latest snapshot version of BoxLang.
- New convention for BVM: `.bvmrc` file in the root of the project to specify the BoxLang version to use.
- New `bvm use` command to switch between BoxLang versions according to the `.bvmrc` file
- New `bvm local` to show the current BoxLang version in use for the current project.
- New `bvm local {version}` command to set the BoxLang version for the current project.
- Consistency on help commands and colors.
- Added the `bvm uninstall` command to uninstall BVM itself.
- Added the `bvm check-update` command to check for updates to BVM and if one is found, it will prompt to install it.

### Changed

- In `bvm` removed the `uninstall` alias to `remove|rm` to avoid confusion with the `bvm uninstall` command, which is used to uninstall BVM itself.

* * *

## [1.13.1] - 2025-06-23

### Fixed

- Syntax error in the `install-boxlang` script that caused it to fail on some systems.

* * *

## [1.13.0] - 2025-06-19

### Added

- The `install-bvm` script is now also installed, so you can upgrade your BVM installation easily.
- BVM now stores the `latest` or `snapshot` versions with the actual version number and keep symlinks to them.

### Fixed

- Do not remove optional symlinks in the `install-boxlang` command.
- Added `$TERM` check in case of headless systems to avoid errors in the installer scripts.
- Fixed the `install-bx-module` to include the right helpers.

* * *

## [1.12.1] - 2025-06-17

### Fixed

- `bvm` can't find source helpers in the `helpers` directory, you need the full path to the helper functions.

* * *

## [1.12.0] - 2025-06-17

### Added

- `--version/-v` flag to all commands to show the version of the command.
- Encapsulation with helper functions in `helpers/helpers.sh` for better code organization.
- Experimental BoxLang Version Manager (`bvm`) to manage multiple BoxLang versions.
- Updated `preflight_check` to beginning to make sure we don't leave folders behind.
- Added non interactive mode to the `install-boxlang` command by using the `--yes, -y` flag for all prompts.
- Added `--with-commandbox` flag to the `install-boxlang` command to install CommandBox automatically.
- Added `--without-commandbox` flag to the `install-boxlang` command to skip CommandBox installation.
- Do not ask the user for the path portions, just add it, if not it doesn't work anyways
- Snapshot builds now detect it and update the url accordingly for the quick installer
- `install-boxlang` refactoring to be similar to all scripts.

* * *

## [1.11.0] - 2025-06-11

### Added

- Improved the `install-bx-module` so when no module is defined, show the help message.
- Add support for `be` or `snapshot` versions of modules.

* * *

## [1.10.0] - 2025-06-11

### Fixed

- Windows Updates

* * *

## [1.9.0] - 2025-06-10

### Fixed

- Windows Updates

* * *

## [1.8.0] - 2025-06-09

### Added

- Added a new `--force` flag to the `install-boxlang` command to force the installation of BoxLang even if it is already installed.
- Updated readme
- New `${TEMP_DIR}` variable to the installer scripts, which points to the system's temporary directory.
- Creation of new boxlang installation home according to the OS and the user.
  - User: `~/.local/boxlang`
  - System Wide: `/usr/local/boxlang`
- Download installer scripts from the repo instead of one by one
- Add a new flag to check if there is a new version of BoxLang available: `--check-update`

* * *

## [1.7.1] - 2025-06-07

### Fixed

- Updated the right permissions for the `install-boxlang`

* * *

## [1.7.0] - 2025-06-05

### Added

- Checks if CommandBox is installed, if not, it asks to install it for you.
- `jq` dependency check
- sudo support for Linux and macOS

### Fixed

- Boxlang Home fixed for windows
- Console reading via &lt; /dev/tty

* * *

## [1.6.0] - 2025-06-05

### Added

- Added comma-separated list support for module installations
- Added remove modules via `--remove`
- Show version of installed modules
- Added record installation back to ForgeBox
- Added `--help` to all commands
- Uploads to new destination on s3: `boxlang-quick-installer`
- md5 and sha256 checksums for the installer
- zip files for the installer
- `version.json` file to track the installer
- Update the `install-boxlang.bat` for Windows to make sure you can run it from anywhere.
- If you are in Powershell 5 or lower, it will now use no progress bar.
- Updated the `install-boxlang.ps1` to add a BOXLANG_HOME env variable to the system and install the boxlang scripts.

* * *

## [1.5.0] - 2025-05-21

### Added

- Permissions for JRE installer
- Added `install-jre.ps1` to install the Java Runtime Environment (JRE) for BoxLang in Windows.
- Version cleanup

### Fixed

- JRE installation directory
- Permissions for JRE Paths

* * *

## [1.4.0] - 2025-03-03

### Changed

- Consolidated the `install-bx-module` and the `install-bx-modules` into one single command `install-boxlang`
- Make `install-bx-module` use the notation `moduleName@version` for specific versions of modules

* * *

## [1.3.0] - 2025-01-13

### Added

- Moved all downloads of the BoxLang modules to come from FORGEBOX since now this is the official distribution point.

* * *

## [1.2.0] - 2024-09-28

* * *

## [1.1.0] - 2024-07-08

### Added

- Added `install-bx-modules` so you can do multi-list installations
- Adding a line to remove existing boxlang jars when installing.

* * *

## [1.0.2] - 2024-06-21

- Use the `latest` as the default now
- Remove old zips upon first install
- Updated release build
- Java 21 as the new standard

* * *

## [1.0.1] - 2024-May-28

### Added

The installer scripts are now installed to: `/usr/local/bin`. So you can reuse them.

- `install-boxlang`
- `install-bx-module`

* * *

## [1.0.0] - 2024-May-27

### Added

- Initial release

[unreleased]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.15.0...HEAD
[1.15.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.14.0...v1.15.0
[1.14.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.13.1...v1.14.0
[1.13.1]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.13.0...v1.13.1
[1.13.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.13.0...v1.13.0
[1.12.1]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.12.0...v1.12.1
[1.12.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.11.0...v1.12.0
[1.11.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.10.0...v1.11.0
[1.10.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.9.0...v1.10.0
[1.9.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.7.1...v1.8.0
[1.7.1]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.7.0...v1.7.1
[1.7.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.4.0...v1.4.0
[1.3.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.3.0...v1.3.0
[1.2.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.2.0...v1.2.0
[1.1.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.0.2...v1.1.0
[1.0.2]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.0.2...v1.0.2
[1.0.1]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/eca6d7845aca8001a5a58d405135f7267887ede3...v1.0.0
