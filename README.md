# gitid

Switch git auth and user details between profiles. Like nvm, but for git identities.

## Install

### Homebrew (recommended)

```sh
brew tap RXNova/gitid
brew install gitid
```

### Manual

```sh
git clone https://github.com/RXNova/gitid.git ~/.gitid-src
echo 'source ~/.gitid-src/gitid.sh' >> ~/.zshrc
```

## Usage

```sh
# Add a profile
gitid add work

# Import current git config as a profile
gitid import personal

# Switch profile
gitid use work
gitid use              # interactive selection

# Show current status
gitid status

# List profiles
gitid list

# Auto-switch by directory
gitid rule add ~/work/acme work
gitid rule add ~/personal personal

# Set default fallback profile
gitid config set default_profile personal

# Disable auto-switch
gitid config set auto_switch false
```

## Config

Stored at `~/.config/gitid/` (XDG compliant).

| Key | Default | Description |
|-----|---------|-------------|
| `default_profile` | *(unset)* | Fallback profile when no directory rule matches |
| `default_scope` | `global` | `global` or `local` |
| `auto_switch` | `true` | Auto-switch profile on `cd` |

## License

MIT
