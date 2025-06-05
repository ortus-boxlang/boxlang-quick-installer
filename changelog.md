# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

* * *

## [Unreleased]

## [1.5.0] - 2025-05-21

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

## [1.5.0] - 2025-05-21

### Added

- Permissions for JRE installer
- Added `install-jre.ps1` to install the Java Runtime Environment (JRE) for BoxLang in Windows.
- Version cleanup

### Fixed

- JRE installation directory
- Permissions for JRE Paths

## [1.4.0] - 2025-03-03

### Changed

- Consolidated the `install-bx-module` and the `install-bx-modules` into one single command `install-boxlang`
- Make `install-bx-module` use the notation `moduleName@version` for specific versions of modules

## [1.3.0] - 2025-01-13

### Added

- Moved all downloads of the BoxLang modules to come from FORGEBOX since now this is the official distribution point.

## [1.2.0] - 2024-09-28

## [1.1.0] - 2024-07-08

### Added

- Added `install-bx-modules` so you can do multi-list installations
- Adding a line to remove existing boxlang jars when installing.

## [1.0.2] - 2024-06-21

- Use the `latest` as the default now
- Remove old zips upon first install
- Updated release build
- Java 21 as the new standard

## [1.0.1] - 2024-May-28

### Added

The installer scripts are now installed to: `/usr/local/bin`. So you can reuse them.

- `install-boxlang`
- `install-bx-module`

## [1.0.0] - 2024-May-27

### Added

- Initial release

[Unreleased]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.5.0...HEAD

[1.5.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.4.0...v1.5.0

[1.4.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.4.0...v1.4.0

[1.3.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.3.0...v1.3.0

[1.2.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.2.0...v1.2.0

[1.1.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.0.2...v1.1.0

[1.0.2]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.0.2...v1.0.2

[1.0.1]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/v1.0.0...v1.0.1

[1.0.0]: https://github.com/ortus-boxlang/boxlang-quick-installer/compare/eca6d7845aca8001a5a58d405135f7267887ede3...v1.0.0
