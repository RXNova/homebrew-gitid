class Gitid < Formula
  desc "Switch git auth & user details between profiles"
  homepage "https://github.com/RXNova/homebrew-gitid"
  url "https://github.com/RXNova/homebrew-gitid/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "69ba669294c396fbd9c8979369d13e562e67e918c4d717a85cee14f04ec8f227"
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
      export _GITID_NO_AUTO_SWITCH=1
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
