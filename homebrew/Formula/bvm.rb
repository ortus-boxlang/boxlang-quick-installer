# Formula for BVM (BoxLang Version Manager)
# This file is maintained automatically — sha256 and version are updated on each release.
# See: https://github.com/ortus-boxlang/boxlang-quick-installer

class Bvm < Formula
  desc "BoxLang Version Manager - install and switch between BoxLang versions"
  homepage "https://boxlang.io"
  url "https://github.com/ortus-boxlang/boxlang-quick-installer/releases/download/v1.27.0/boxlang-installer.zip"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  version "1.27.0"
  license "Apache-2.0"

  # BVM is a shell script — no binary dependencies beyond bash and curl
  depends_on :macos => :ventura if OS.mac?

  def install
    # Install bvm.sh and its helper scripts to libexec so that the relative
    # path lookup inside bvm.sh ($(dirname "$0")/helpers/helpers.sh) works.
    libexec.install "bvm.sh"
    libexec.install "helpers"

    # Create a thin wrapper in bin/ that execs the real script from libexec.
    # Using exec preserves $0 as the libexec path, which is what bvm.sh
    # relies on when locating helpers/helpers.sh at runtime.
    (bin/"bvm").write <<~EOS
      #!/bin/bash
      exec "#{libexec}/bvm.sh" "$@"
    EOS
  end

  def caveats
    <<~EOS
      BVM manages BoxLang installations in ~/.bvm

      Get started:
        bvm install latest     # Install the latest stable BoxLang
        bvm use latest         # Make it the active version
        bvm list               # List installed versions
        bvm help               # Full command reference

      After installing a version, BoxLang binaries are available at:
        ~/.bvm/current/bin/boxlang
        ~/.bvm/current/bin/boxlang-miniserver

      BVM will configure your shell PATH automatically on first use.
    EOS
  end

  test do
    # bvm help prints "BoxLang Version Manager (BVM)" to stdout
    assert_match "BoxLang Version Manager", shell_output("#{bin}/bvm help 2>&1")
  end
end
