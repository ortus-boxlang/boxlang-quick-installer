# Formula for the BoxLang Quick Installer toolset
# This file is maintained automatically — sha256 and version are updated on each release.
# See: https://github.com/ortus-boxlang/boxlang-quick-installer

class Boxlang < Formula
  desc "BoxLang quick installer - install the BoxLang runtime and related tools"
  homepage "https://boxlang.io"
  url "https://github.com/ortus-boxlang/boxlang-quick-installer/releases/download/v1.27.0/boxlang-installer.zip"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  version "1.27.0"
  license "Apache-2.0"

  depends_on :macos => :ventura if OS.mac?

  def install
    # Install the installer scripts and shared helpers to libexec.
    # Each bin wrapper below execs the script from libexec so that the
    # relative $(dirname "$0")/helpers/helpers.sh path resolves correctly.
    libexec.install "install-boxlang.sh"
    libexec.install "install-bx-module.sh"
    libexec.install "install-bx-site.sh"
    libexec.install "helpers"

    (bin/"install-boxlang").write <<~EOS
      #!/bin/bash
      exec "#{libexec}/install-boxlang.sh" "$@"
    EOS

    (bin/"install-bx-module").write <<~EOS
      #!/bin/bash
      exec "#{libexec}/install-bx-module.sh" "$@"
    EOS

    (bin/"install-bx-site").write <<~EOS
      #!/bin/bash
      exec "#{libexec}/install-bx-site.sh" "$@"
    EOS
  end

  def caveats
    <<~EOS
      The BoxLang installer commands are now available:

        install-boxlang              # Install the latest stable BoxLang runtime
        install-boxlang --with-jre   # Also install Java 21 JRE automatically
        install-boxlang --help       # Full option reference

        install-bx-module            # Install a BoxLang module
        install-bx-site              # Install a BoxLang site template

      To manage multiple BoxLang versions, consider using BVM instead:
        brew install bvm
        bvm install latest && bvm use latest
    EOS
  end

  test do
    # install-boxlang --help prints "BoxLang® Quick Installer" to stdout
    assert_match "BoxLang", shell_output("#{bin}/install-boxlang --help 2>&1")
  end
end
