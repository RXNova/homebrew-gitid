# gitid

Switch git auth and user details between profiles. Like nvm, but for git identities.

Auto-switches your git identity when you `cd` into a project directory.

## Install

### Homebrew (recommended)

<img src="https://brew.sh/assets/img/homebrew.svg" alt="Homebrew" width="120">

```sh
brew tap RXNova/gitid
brew install gitid
```

Shell config is automatically set up on first run.

### Manual

```sh
git clone https://github.com/RXNova/homebrew-gitid.git ~/.gitid-src
echo 'source ~/.gitid-src/gitid.sh' >> ~/.zshrc
source ~/.zshrc
```

## Quick Start

```sh
# Import your current git config as a profile
gitid import work

# Add a new profile interactively
gitid add personal

# Switch to a profile
gitid use personal

# Auto-switch when entering a directory
gitid rule add ~/work work
gitid rule add ~/personal personal

# Now just cd into a directory and gitid switches automatically
cd ~/work/my-project
# gitid: switched to "work" (John <john@work.com>)
```

## Commands

### Profiles

| Command | Description |
|---------|-------------|
| `gitid add [name]` | Add or update a profile interactively |
| `gitid remove <name>` | Remove a profile |
| `gitid list` | List all saved profiles (highlights active) |
| `gitid use [name]` | Switch to a profile (interactive picker if no name) |
| `gitid import [name]` | Import current git config as a profile |
| `gitid status` | Show current git config and matched profile |

### Directory Rules

Automatically switch profiles when you `cd` into a directory. Rules match on longest prefix, so `~/work/acme` takes priority over `~/work`.

| Command | Description |
|---------|-------------|
| `gitid rule add <dir> <profile>` | Auto-switch profile for a directory tree |
| `gitid rule remove <dir>` | Remove a directory rule |
| `gitid rule list` | List all directory rules |

### Configuration

| Command | Description |
|---------|-------------|
| `gitid config list` | Show all settings |
| `gitid config set <key> <value>` | Set a config value |
| `gitid config get <key>` | Get a config value |

### Other

| Command | Description |
|---------|-------------|
| `gitid setup` | Add gitid to your shell config (`~/.zshrc` / `~/.bashrc`) |
| `gitid version` | Show version |
| `gitid help` | Show help |

## Options

| Flag | Description |
|------|-------------|
| `--global` | Apply to global git config (default) |
| `--local` | Apply to local repo git config |

## Config Keys

Stored at `~/.config/gitid/` (XDG compliant).

| Key | Default | Description |
|-----|---------|-------------|
| `default_profile` | *(unset)* | Fallback profile when no directory rule matches |
| `default_scope` | `global` | `global` or `local` |
| `auto_switch` | `true` | Auto-switch profile on `cd` |

## What Gets Switched

Each profile stores and switches the following git config values:

- `user.name`
- `user.email`
- `core.sshCommand` (SSH key for auth)
- `user.signingkey` (GPG/SSH commit signing)
- `commit.gpgsign`
- `gpg.format`

## Storage

```
~/.config/gitid/
  config          # settings (default_profile, default_scope, auto_switch)
  profiles/       # one file per profile (plain key=value)
    work
    personal
  rules           # directory-to-profile mappings (path=profile)
```

## Examples

```sh
# Add a work profile with SSH key and signing
gitid add work
# Name (user.name): John Doe
# Email (user.email): john@work.com
# SSH key path: ~/.ssh/id_work
# Signing key: ABC123
# GPG format: openpgp

# Import current global git config
gitid import current --global

# Import current local repo config
gitid import project --local

# Switch globally
gitid use work

# Switch only for current repo
gitid use personal --local

# Interactive profile picker
gitid use

# Map directories to profiles
gitid rule add ~/work work
gitid rule add ~/work/freelance freelance
gitid rule add ~/oss personal

# Set a default fallback
gitid config set default_profile personal

# Check what's active
gitid status
```

## Uninstall

```sh
brew uninstall gitid
brew untap rxnova/gitid
```

Then remove the gitid line from your `~/.zshrc` or `~/.bashrc`.

## License

MIT
