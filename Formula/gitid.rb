class Gitid < Formula
  desc "Switch git auth & user details between profiles"
  homepage "https://github.com/RXNova/homebrew-gitid"
  url "https://github.com/RXNova/homebrew-gitid/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "69ba669294c396fbd9c8979369d13e562e67e918c4d717a85cee14f04ec8f227"
  license "MIT"

  def install
    libexec.install "gitid.sh"

    # Wrapper sourced by shell config (enables cd auto-switch)
    (prefix/"gitid.sh").write <<~BASH
      #!/usr/bin/env bash
      [ -z "$GITID_DIR" ] && export GITID_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/gitid"
      \\. "#{libexec}/gitid.sh"
    BASH

    # Standalone bin script — auto-runs setup on first use
    (bin/"gitid").write <<~BASH
      #!/usr/bin/env bash
      export _GITID_NO_AUTO_SWITCH=1
      source "#{opt_prefix}/gitid.sh"

      # Auto-setup on first run
      if ! grep -q "gitid.sh" "$HOME/.zshrc" 2>/dev/null && \
         ! grep -q "gitid.sh" "$HOME/.bashrc" 2>/dev/null; then
        gitid setup
        echo ""
        echo "Restart your terminal to enable auto-switch on cd."
        echo ""
      fi

      gitid "$@"
    BASH
  end

  def caveats
    <<~EOS
      gitid will auto-configure your shell on first run.
      Just run any gitid command to get started:

        gitid help
    EOS
  end

  test do
    assert_match "gitid", shell_output("#{bin}/gitid version")
  end
end
