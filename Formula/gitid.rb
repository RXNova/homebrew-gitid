class Gitid < Formula
  desc "Switch git auth & user details between profiles"
  homepage "https://github.com/RXNova/homebrew-gitid"
  url "https://github.com/RXNova/homebrew-gitid/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "2044d266c865066e036b183369cfd444febfb6bcb026dd3bac99a9fad72b7fd7"
  license "MIT"

  def install
    libexec.install "gitid.sh"

    (prefix/"gitid.sh").write <<~BASH
      #!/usr/bin/env bash
      [ -z "$GITID_DIR" ] && export GITID_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/gitid"
      \\. "#{libexec}/gitid.sh"
    BASH
  end

  def caveats
    <<~EOS
      Run the setup command to add gitid to your shell automatically:

        source #{opt_prefix}/gitid.sh && gitid setup

      Or manually add to ~/.zshrc or ~/.bashrc:

        [ -s "#{opt_prefix}/gitid.sh" ] && \\. "#{opt_prefix}/gitid.sh"

      Then restart your terminal.
    EOS
  end

  test do
    assert_match "gitid", shell_output("bash -c 'source #{opt_prefix}/gitid.sh && gitid version'")
  end
end
