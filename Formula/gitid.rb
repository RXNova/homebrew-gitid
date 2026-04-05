class Gitid < Formula
  desc "Switch git auth & user details between profiles"
  homepage "https://github.com/RXNova/homebrew-gitid"
  url "https://github.com/RXNova/homebrew-gitid/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "3d0f946eaf221a4e0144d078396be85756a0cf10541e6bb9a26f733824f826dd"
  license "MIT"

  def install
    libexec.install "gitid.sh"

    # Wrapper sourced by shell config
    (prefix/"gitid.sh").write <<~BASH
      #!/usr/bin/env bash
      [ -z "$GITID_DIR" ] && export GITID_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/gitid"
      \\. "#{libexec}/gitid.sh"
    BASH

    # Standalone bin script for setup and basic commands before shell is configured
    (bin/"gitid").write <<~BASH
      #!/usr/bin/env bash
      source "#{opt_prefix}/gitid.sh"
      gitid "$@"
    BASH
  end

  def caveats
    <<~EOS
      Run this to add gitid to your shell:

        gitid setup

      Then restart your terminal.
    EOS
  end

  test do
    assert_match "gitid", shell_output("#{bin}/gitid version")
  end
end
