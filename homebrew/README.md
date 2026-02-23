# BoxLang Homebrew Tap

This directory contains the [Homebrew](https://brew.sh) formula files for BoxLang tooling.

## Setting Up the Tap

The formulas in this directory belong in a dedicated Homebrew tap repository named **`homebrew-boxlang`** under the `ortus-boxlang` GitHub organization.

### One-Time Setup — Create the Tap Repository

1. Create a new **public** GitHub repository at `ortus-boxlang/homebrew-boxlang`.
2. Copy the `Formula/` directory from this folder into the root of that new repository.
3. Commit and push.

```
homebrew-boxlang/
└── Formula/
    ├── bvm.rb
    └── boxlang.rb
```

Users can then install with:

```bash
brew tap ortus-boxlang/boxlang
brew install bvm            # BoxLang Version Manager
brew install boxlang        # BoxLang quick installer tools
```

---

## What Each Formula Installs

### `bvm` — BoxLang Version Manager

Installs the `bvm` command, which lets you install, switch, and manage multiple
BoxLang runtime versions — similar to `nvm` for Node.js or `rbenv` for Ruby.

```bash
brew install bvm

bvm install latest     # install the latest stable BoxLang
bvm use latest         # activate it
bvm list               # see installed versions
bvm help               # full command reference
```

### `boxlang` — Quick Installer Tools

Installs the one-shot installer scripts for BoxLang and its ecosystem:

| Command              | Purpose                                      |
|----------------------|----------------------------------------------|
| `install-boxlang`    | Install the BoxLang runtime to your system   |
| `install-bx-module`  | Install a BoxLang module                     |
| `install-bx-site`    | Install a BoxLang site template              |

```bash
brew install boxlang

install-boxlang              # install latest stable BoxLang
install-boxlang --with-jre   # also install Java 21 automatically
install-boxlang --help       # see all options
```

> **Tip:** For development workflows where you need multiple BoxLang versions,
> `brew install bvm` is the recommended choice.

---

## Keeping Formulas Up to Date

The release workflow in `.github/workflows/release.yml` automatically:

1. Uploads `boxlang-installer.zip` to every stable GitHub Release.
2. Computes the SHA-256 of the zip and updates both formula files.
3. Commits the updated formulas back to the `main` branch of this repository.
4. If the `HOMEBREW_TAP_TOKEN` secret is configured, pushes the updated formulas
   to the `ortus-boxlang/homebrew-boxlang` tap repository automatically.

### First-Time Tap Configuration

To enable automatic tap updates, create a [fine-grained personal access token](https://github.com/settings/tokens)
with **Contents: read & write** access scoped to `ortus-boxlang/homebrew-boxlang`, then add it as a
repository secret named `HOMEBREW_TAP_TOKEN` in `ortus-boxlang/boxlang-quick-installer`.

---

## Manual Formula Update

If you need to update the formulas by hand (e.g. after the initial tap setup):

```bash
# 1. Build the release zip and capture its sha256
./build.sh
SHA256=$(sha256sum build/boxlang-installer.zip | awk '{print $1}')
VERSION=$(jq -r '.INSTALLER_VERSION' version.json)

# 2. Update both formula files
sed -i "s/sha256 \"[a-f0-9]\{64\}\"/sha256 \"${SHA256}\"/" homebrew/Formula/bvm.rb
sed -i "s/  version \"[0-9.]*\"/  version \"${VERSION}\"/" homebrew/Formula/bvm.rb
sed -i "s|/download/v[0-9.]*/boxlang-installer.zip|/download/v${VERSION}/boxlang-installer.zip|" homebrew/Formula/bvm.rb

sed -i "s/sha256 \"[a-f0-9]\{64\}\"/sha256 \"${SHA256}\"/" homebrew/Formula/boxlang.rb
sed -i "s/  version \"[0-9.]*\"/  version \"${VERSION}\"/" homebrew/Formula/boxlang.rb
sed -i "s|/download/v[0-9.]*/boxlang-installer.zip|/download/v${VERSION}/boxlang-installer.zip|" homebrew/Formula/boxlang.rb

# 3. Copy to the tap repo and push
cp homebrew/Formula/*.rb /path/to/homebrew-boxlang/Formula/
```

---

## Local Development / Testing

```bash
# Audit the formula for common issues
brew audit --new homebrew/Formula/bvm.rb

# Install directly from a local formula file (useful before the tap exists)
brew install --formula homebrew/Formula/bvm.rb

# Run formula tests
brew test homebrew/Formula/bvm.rb
```
