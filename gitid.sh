#!/usr/bin/env bash

# gitid - switch git auth & user details
# https://github.com/RXNova/homebrew-gitid
#
# Source this file in your .zshrc or .bashrc:
#   source /path/to/gitid.sh

GITID_VERSION="0.1.0"

export GITID_DIR="${GITID_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/gitid}"
GITID_PROFILES_DIR="$GITID_DIR/profiles"
GITID_CONFIG_FILE="$GITID_DIR/config"

# ── helpers ──────────────────────────────────────────────

_gitid_ensure_dir() {
  [ -d "$GITID_PROFILES_DIR" ] || mkdir -p "$GITID_PROFILES_DIR"
  [ -f "$GITID_CONFIG_FILE" ] || cat > "$GITID_CONFIG_FILE" <<'EOF'
# gitid configuration
# default_profile: profile to use when no directory rule matches
default_profile=
# default_scope: global or local (default: global)
default_scope=global
# auto_switch: true/false — auto-switch profile on cd (default: true)
auto_switch=true
EOF
}

_gitid_profile_path() {
  echo "$GITID_PROFILES_DIR/$1"
}

_gitid_profile_exists() {
  [ -f "$(_gitid_profile_path "$1")" ]
}

_gitid_read_profile() {
  local file="$(_gitid_profile_path "$1")"
  unset _P_NAME _P_EMAIL _P_SSHKEY _P_SIGNINGKEY _P_GPGFORMAT
  while IFS='=' read -r key value; do
    case "$key" in
      name) _P_NAME="$value" ;;
      email) _P_EMAIL="$value" ;;
      sshkey) _P_SSHKEY="$value" ;;
      signingkey) _P_SIGNINGKEY="$value" ;;
      gpgformat) _P_GPGFORMAT="$value" ;;
    esac
  done < "$file"
}

_gitid_write_profile() {
  local file="$(_gitid_profile_path "$1")"
  cat > "$file" <<EOF
name=${_P_NAME}
email=${_P_EMAIL}
sshkey=${_P_SSHKEY}
signingkey=${_P_SIGNINGKEY}
gpgformat=${_P_GPGFORMAT}
EOF
}

_gitid_get_config() {
  local key="$1"
  [ -f "$GITID_CONFIG_FILE" ] || return
  while IFS='=' read -r k v; do
    [[ "$k" =~ ^#.*$ ]] && continue
    [ -z "$k" ] && continue
    if [ "$k" = "$key" ]; then
      echo "$v"
      return
    fi
  done < "$GITID_CONFIG_FILE"
}

_gitid_set_config() {
  local key="$1" value="$2"
  if grep -q "^${key}=" "$GITID_CONFIG_FILE" 2>/dev/null; then
    sed -i '' "s|^${key}=.*|${key}=${value}|" "$GITID_CONFIG_FILE"
  else
    echo "${key}=${value}" >> "$GITID_CONFIG_FILE"
  fi
}

_gitid_is_git_repo() {
  git rev-parse --is-inside-work-tree &>/dev/null
}

_gitid_get_scope() {
  local scope="$(_gitid_get_config default_scope)"
  echo "--${scope:-global}"
}

_gitid_apply() {
  local profile="$1"
  local scope="${2:-$(_gitid_get_scope)}"

  _gitid_read_profile "$profile"

  git config $scope user.name "$_P_NAME"
  git config $scope user.email "$_P_EMAIL"

  if [ -n "$_P_SSHKEY" ]; then
    git config $scope core.sshCommand "ssh -i $_P_SSHKEY"
  else
    git config $scope --unset core.sshCommand 2>/dev/null
  fi

  if [ -n "$_P_SIGNINGKEY" ]; then
    git config $scope user.signingkey "$_P_SIGNINGKEY"
    git config $scope commit.gpgsign true
    [ -n "$_P_GPGFORMAT" ] && git config $scope gpg.format "$_P_GPGFORMAT"
  else
    git config $scope --unset user.signingkey 2>/dev/null
    git config $scope --unset commit.gpgsign 2>/dev/null
    git config $scope --unset gpg.format 2>/dev/null
  fi
}

# ── directory rules ──────────────────────────────────────

GITID_RULES_FILE="$GITID_DIR/rules"

_gitid_ensure_rules() {
  [ -f "$GITID_RULES_FILE" ] || touch "$GITID_RULES_FILE"
}

# Find the best matching rule for a directory (longest prefix match)
_gitid_match_rule() {
  local target_dir="$1"
  local best_match="" best_profile="" best_len=0

  _gitid_ensure_rules
  while IFS='=' read -r dir profile; do
    [[ "$dir" =~ ^#.*$ ]] && continue
    [ -z "$dir" ] && continue
    # Expand ~ to home
    dir="${dir/#\~/$HOME}"
    # Check if target starts with this dir
    if [[ "$target_dir" == "$dir" || "$target_dir" == "$dir"/* ]]; then
      local len=${#dir}
      if [ "$len" -gt "$best_len" ]; then
        best_len=$len
        best_match="$dir"
        best_profile="$profile"
      fi
    fi
  done < "$GITID_RULES_FILE"

  [ -n "$best_profile" ] && echo "$best_profile"
}

# ── auto-switch on cd ───────────────────────────────────

_GITID_LAST_PROFILE=""

_gitid_auto_switch() {
  local auto="$(_gitid_get_config auto_switch)"
  [ "$auto" = "false" ] && return

  local profile="$(_gitid_match_rule "$PWD")"

  # Fallback to default profile
  if [ -z "$profile" ]; then
    profile="$(_gitid_get_config default_profile)"
  fi

  [ -z "$profile" ] && return
  [ "$profile" = "$_GITID_LAST_PROFILE" ] && return

  if _gitid_profile_exists "$profile"; then
    _gitid_apply "$profile" "--global"
    _gitid_read_profile "$profile"
    _GITID_LAST_PROFILE="$profile"
    echo "gitid: switched to \"$profile\" ($_P_NAME <$_P_EMAIL>)"
  fi
}

# Hook into cd
if [ -n "$ZSH_VERSION" ]; then
  autoload -U add-zsh-hook
  add-zsh-hook chpwd _gitid_auto_switch
else
  _gitid_original_cd="$(type -t cd)"
  cd() {
    builtin cd "$@" && _gitid_auto_switch
  }
fi

# ── main command ─────────────────────────────────────────

gitid() {
  _gitid_ensure_dir

  local cmd="$1"
  shift

  case "$cmd" in

    # ── add ──────────────────────────────────────────
    add)
      local profile_name="$1"
      if [ -z "$profile_name" ]; then
        printf "Profile name: " && read -r profile_name
      fi
      [ -z "$profile_name" ] && echo "Profile name is required." && return 1

      if _gitid_profile_exists "$profile_name"; then
        printf "Profile \"%s\" exists. Overwrite? (y/N): " "$profile_name" && read -r yn
        [ "$yn" != "y" ] && [ "$yn" != "Y" ] && echo "Aborted." && return 0
      fi

      printf "Name (user.name): " && read -r _P_NAME
      [ -z "$_P_NAME" ] && echo "Name is required." && return 1
      printf "Email (user.email): " && read -r _P_EMAIL
      [ -z "$_P_EMAIL" ] && echo "Email is required." && return 1
      printf "SSH key path (leave empty to skip): " && read -r _P_SSHKEY
      printf "Signing key (leave empty to skip): " && read -r _P_SIGNINGKEY
      _P_GPGFORMAT=""
      if [ -n "$_P_SIGNINGKEY" ]; then
        printf "GPG format (openpgp/ssh, default openpgp): " && read -r _P_GPGFORMAT
        _P_GPGFORMAT="${_P_GPGFORMAT:-openpgp}"
      fi

      _gitid_write_profile "$profile_name"
      echo "✓ Profile \"$profile_name\" saved."
      ;;

    # ── remove ───────────────────────────────────────
    remove|rm)
      local profile_name="$1"
      [ -z "$profile_name" ] && echo "Usage: gitid remove <name>" && return 1
      if _gitid_profile_exists "$profile_name"; then
        rm "$(_gitid_profile_path "$profile_name")"
        # Also remove any rules pointing to this profile
        if [ -f "$GITID_RULES_FILE" ]; then
          sed -i '' "/=$profile_name$/d" "$GITID_RULES_FILE"
        fi
        echo "✓ Profile \"$profile_name\" removed."
      else
        echo "✗ Profile \"$profile_name\" not found." && return 1
      fi
      ;;

    # ── list ─────────────────────────────────────────
    list|ls)
      local profiles=("$GITID_PROFILES_DIR"/*(N))
      if [ ${#profiles[@]} -eq 0 ]; then
        echo "No profiles saved. Use \"gitid add\" to create one."
        return 0
      fi

      local current_name current_email
      if _gitid_is_git_repo; then
        current_name="$(git config --local user.name 2>/dev/null)"
        current_email="$(git config --local user.email 2>/dev/null)"
      fi
      if [ -z "$current_name" ]; then
        current_name="$(git config --global user.name 2>/dev/null)"
        current_email="$(git config --global user.email 2>/dev/null)"
      fi

      local default_profile="$(_gitid_get_config default_profile)"

      echo ""
      echo "Saved profiles:"
      echo ""
      for file in "${profiles[@]}"; do
        local pname="$(basename "$file")"
        _gitid_read_profile "$pname"
        local marker="  "
        if [ "$_P_NAME" = "$current_name" ] && [ "$_P_EMAIL" = "$current_email" ]; then
          marker="● "
        fi
        local default_tag=""
        [ "$pname" = "$default_profile" ] && default_tag=" (default)"
        echo "  ${marker}${pname}${default_tag}"
        echo "      name:  $_P_NAME"
        echo "      email: $_P_EMAIL"
        [ -n "$_P_SSHKEY" ] && echo "      ssh:   $_P_SSHKEY"
        [ -n "$_P_SIGNINGKEY" ] && echo "      sign:  $_P_SIGNINGKEY ($_P_GPGFORMAT)"

        # Show linked directories
        _gitid_ensure_rules
        local has_dirs=0
        while IFS='=' read -r dir profile; do
          [[ "$dir" =~ ^#.*$ ]] && continue
          [ -z "$dir" ] && continue
          if [ "$profile" = "$pname" ]; then
            [ $has_dirs -eq 0 ] && echo "      dirs:"
            echo "        - $dir"
            has_dirs=1
          fi
        done < "$GITID_RULES_FILE"
        echo ""
      done
      ;;

    # ── use ──────────────────────────────────────────
    use)
      local profile_name="$1"
      local scope="$(_gitid_get_scope)"
      [[ " $* " == *" --local "* ]] && scope="--local"
      [[ " $* " == *" --global "* ]] && scope="--global"

      if [ -z "$profile_name" ]; then
        # Interactive selection
        local profiles=("$GITID_PROFILES_DIR"/*(N))
        if [ ${#profiles[@]} -eq 0 ]; then
          echo "No profiles saved. Use \"gitid add\" to create one."
          return 0
        fi
        echo ""
        echo "Select a profile:"
        echo ""
        local i=1
        for file in "${profiles[@]}"; do
          local pname="$(basename "$file")"
          _gitid_read_profile "$pname"
          echo "  $i) $pname ($_P_NAME <$_P_EMAIL>)"
          i=$((i + 1))
        done
        echo ""
        printf "Enter number: " && read -r choice
        local idx=$((choice))
        if [ "$idx" -lt 1 ] || [ "$idx" -ge "$i" ]; then
          echo "Invalid selection." && return 1
        fi
        profile_name="$(basename "${profiles[$idx]}")"
      fi

      if ! _gitid_profile_exists "$profile_name"; then
        echo "✗ Profile \"$profile_name\" not found."
        echo "  Run \"gitid list\" to see available profiles."
        return 1
      fi

      if [ "$scope" = "--local" ] && ! _gitid_is_git_repo; then
        echo "✗ Not inside a git repo. Use --global or cd into a repo."
        return 1
      fi

      _gitid_apply "$profile_name" "$scope"
      _gitid_read_profile "$profile_name"
      _GITID_LAST_PROFILE="$profile_name"
      local scope_label="globally"
      [ "$scope" = "--local" ] && scope_label="locally"
      echo "✓ Switched $scope_label to \"$profile_name\" ($_P_NAME <$_P_EMAIL>)"
      ;;

    # ── import ───────────────────────────────────────
    import)
      local profile_name="$1"
      if [ -z "$profile_name" ]; then
        printf "Profile name to save as: " && read -r profile_name
      fi
      [ -z "$profile_name" ] && echo "Profile name is required." && return 1

      local source_scope="--global"
      [[ " $* " == *" --local "* ]] && source_scope="--local"

      _P_NAME="$(git config $source_scope user.name 2>/dev/null)"
      _P_EMAIL="$(git config $source_scope user.email 2>/dev/null)"

      if [ -z "$_P_NAME" ] || [ -z "$_P_EMAIL" ]; then
        echo "✗ No user.name/user.email in ${source_scope#--} git config." && return 1
      fi

      if _gitid_profile_exists "$profile_name"; then
        printf "Profile \"%s\" exists. Overwrite? (y/N): " "$profile_name" && read -r yn
        [ "$yn" != "y" ] && [ "$yn" != "Y" ] && echo "Aborted." && return 0
      fi

      local ssh_cmd="$(git config $source_scope core.sshCommand 2>/dev/null)"
      _P_SSHKEY=""
      if [ -n "$ssh_cmd" ]; then
        _P_SSHKEY="$(echo "$ssh_cmd" | sed -n 's/.*-i \([^ ]*\).*/\1/p')"
      fi

      _P_SIGNINGKEY="$(git config $source_scope user.signingkey 2>/dev/null)"
      _P_GPGFORMAT="$(git config $source_scope gpg.format 2>/dev/null)"
      [ -n "$_P_SIGNINGKEY" ] && [ -z "$_P_GPGFORMAT" ] && _P_GPGFORMAT="openpgp"

      _gitid_write_profile "$profile_name"
      local scope_label="${source_scope#--}"
      echo "✓ Imported $scope_label git config as \"$profile_name\""
      echo "    name:  $_P_NAME"
      echo "    email: $_P_EMAIL"
      [ -n "$_P_SSHKEY" ] && echo "    ssh:   $_P_SSHKEY"
      [ -n "$_P_SIGNINGKEY" ] && echo "    sign:  $_P_SIGNINGKEY ($_P_GPGFORMAT)"
      ;;

    # ── rule ─────────────────────────────────────────
    rule)
      local subcmd="$1"
      shift
      case "$subcmd" in
        add|set)
          local dir="$1" profile="$2"
          if [ -z "$dir" ] || [ -z "$profile" ]; then
            echo "Usage: gitid rule add <directory> <profile>"
            echo "  e.g. gitid rule add ~/work/acme work"
            return 1
          fi
          # Resolve to absolute path but keep ~ for display
          local abs_dir
          abs_dir="$(cd "$dir" 2>/dev/null && pwd)" || abs_dir="$dir"

          if ! _gitid_profile_exists "$profile"; then
            echo "✗ Profile \"$profile\" not found." && return 1
          fi

          _gitid_ensure_rules

          # Remove existing rule for this dir
          if grep -q "^${abs_dir}=" "$GITID_RULES_FILE" 2>/dev/null; then
            sed -i '' "s|^${abs_dir}=.*|${abs_dir}=${profile}|" "$GITID_RULES_FILE"
          else
            echo "${abs_dir}=${profile}" >> "$GITID_RULES_FILE"
          fi
          echo "✓ Rule: $abs_dir → $profile"
          ;;

        remove|rm)
          local dir="$1"
          [ -z "$dir" ] && echo "Usage: gitid rule remove <directory>" && return 1
          local abs_dir
          abs_dir="$(cd "$dir" 2>/dev/null && pwd)" || abs_dir="$dir"
          _gitid_ensure_rules
          if grep -q "^${abs_dir}=" "$GITID_RULES_FILE" 2>/dev/null; then
            sed -i '' "\|^${abs_dir}=|d" "$GITID_RULES_FILE"
            echo "✓ Rule removed for $abs_dir"
          else
            echo "✗ No rule found for $abs_dir" && return 1
          fi
          ;;

        list|ls|"")
          _gitid_ensure_rules
          local count=0
          echo ""
          echo "Directory rules:"
          echo ""
          while IFS='=' read -r dir profile; do
            [[ "$dir" =~ ^#.*$ ]] && continue
            [ -z "$dir" ] && continue
            echo "  $dir → $profile"
            count=$((count + 1))
          done < "$GITID_RULES_FILE"
          [ "$count" -eq 0 ] && echo "  No rules configured. Use \"gitid rule add <dir> <profile>\"."
          echo ""
          ;;

        *)
          echo "Usage: gitid rule <add|remove|list>"
          return 1
          ;;
      esac
      ;;

    # ── config ───────────────────────────────────────
    config)
      local subcmd="$1"
      shift
      case "$subcmd" in
        set)
          local key="$1" value="$2"
          if [ -z "$key" ] || [ -z "$value" ]; then
            echo "Usage: gitid config set <key> <value>"
            echo ""
            echo "Keys:"
            echo "  default_profile    Fallback profile when no rule matches"
            echo "  default_scope      global or local (default: global)"
            echo "  auto_switch        true or false (default: true)"
            return 1
          fi
          case "$key" in
            default_profile)
              if [ -n "$value" ] && [ "$value" != "none" ] && ! _gitid_profile_exists "$value"; then
                echo "✗ Profile \"$value\" not found." && return 1
              fi
              [ "$value" = "none" ] && value=""
              _gitid_set_config "$key" "$value"
              echo "✓ $key = ${value:-<unset>}"
              ;;
            default_scope)
              if [ "$value" != "global" ] && [ "$value" != "local" ]; then
                echo "✗ Scope must be \"global\" or \"local\"." && return 1
              fi
              _gitid_set_config "$key" "$value"
              echo "✓ $key = $value"
              ;;
            auto_switch)
              if [ "$value" != "true" ] && [ "$value" != "false" ]; then
                echo "✗ Must be \"true\" or \"false\"." && return 1
              fi
              _gitid_set_config "$key" "$value"
              echo "✓ $key = $value"
              if [ "$value" = "true" ]; then
                echo "  Profile will auto-switch when you cd into a mapped directory."
              else
                echo "  Auto-switch disabled."
              fi
              ;;
            *)
              echo "✗ Unknown config key: $key"
              echo "  Valid keys: default_profile, default_scope, auto_switch"
              return 1
              ;;
          esac
          ;;

        get)
          local key="$1"
          if [ -z "$key" ]; then
            echo "Usage: gitid config get <key>"
            return 1
          fi
          local val="$(_gitid_get_config "$key")"
          echo "${key} = ${val:-<unset>}"
          ;;

        list|ls|"")
          echo ""
          echo "Configuration ($GITID_CONFIG_FILE):"
          echo ""
          echo "  default_profile = $(_gitid_get_config default_profile || echo '<unset>')"
          echo "  default_scope   = $(_gitid_get_config default_scope || echo 'global')"
          echo "  auto_switch     = $(_gitid_get_config auto_switch || echo 'true')"
          echo ""
          ;;

        *)
          echo "Usage: gitid config <set|get|list>"
          return 1
          ;;
      esac
      ;;

    # ── status ───────────────────────────────────────
    status)
      local scope="$(_gitid_get_scope)"
      local scope_label="${scope#--}"
      if _gitid_is_git_repo && [[ " $* " != *" --global "* ]]; then
        scope="--local"
        scope_label="local"
      fi
      [[ " $* " == *" --global "* ]] && scope="--global" && scope_label="global"

      if ! _gitid_is_git_repo && [[ " $* " != *" --global "* ]]; then
        scope="--global"
        scope_label="global"
        echo "Not inside a git repo — showing global config."
      fi

      echo ""
      echo "Current git config ($scope_label):"
      echo ""
      echo "  user.name:       $(git config $scope user.name 2>/dev/null || echo 'not set')"
      echo "  user.email:      $(git config $scope user.email 2>/dev/null || echo 'not set')"
      echo "  core.sshCommand: $(git config $scope core.sshCommand 2>/dev/null || echo 'default')"
      echo "  user.signingkey: $(git config $scope user.signingkey 2>/dev/null || echo 'none')"
      echo "  commit.gpgsign:  $(git config $scope commit.gpgsign 2>/dev/null || echo 'false')"
      echo "  gpg.format:      $(git config $scope gpg.format 2>/dev/null || echo 'default')"

      local current_name="$(git config $scope user.name 2>/dev/null)"
      local current_email="$(git config $scope user.email 2>/dev/null)"
      local matched=0
      for file in "$GITID_PROFILES_DIR"/*(N); do
        local pname="$(basename "$file")"
        _gitid_read_profile "$pname"
        if [ "$_P_NAME" = "$current_name" ] && [ "$_P_EMAIL" = "$current_email" ]; then
          echo ""
          echo "  ● Matches profile: $pname"
          matched=1
          break
        fi
      done
      [ "$matched" -eq 0 ] && [ -n "$current_name" ] && echo "" && echo "  ○ No matching saved profile."

      # Show active rule for current directory
      local rule_profile="$(_gitid_match_rule "$PWD")"
      if [ -n "$rule_profile" ]; then
        echo "  ↳ Directory rule: $PWD → $rule_profile"
      fi
      echo ""
      ;;

    # ── setup ─────────────────────────────────────────
    setup)
      local shell_name source_path source_line
      # Determine the source path (brew or direct)
      if [ -f "/opt/homebrew/opt/gitid/gitid.sh" ]; then
        source_path="/opt/homebrew/opt/gitid/gitid.sh"
      elif [ -f "/usr/local/opt/gitid/gitid.sh" ]; then
        source_path="/usr/local/opt/gitid/gitid.sh"
      else
        source_path="${BASH_SOURCE[0]:-$0}"
        # Resolve to absolute path
        source_path="$(cd "$(dirname "$source_path")" && pwd)/$(basename "$source_path")"
      fi

      source_line="[ -s \"$source_path\" ] && \\. \"$source_path\"  # gitid"

      local configs=()
      [ -f "$HOME/.zshrc" ] && configs+=("$HOME/.zshrc")
      [ -f "$HOME/.bashrc" ] && configs+=("$HOME/.bashrc")
      # If neither exists, default to .zshrc on macOS, .bashrc otherwise
      if [ ${#configs[@]} -eq 0 ]; then
        if [[ "$OSTYPE" == darwin* ]]; then
          configs+=("$HOME/.zshrc")
        else
          configs+=("$HOME/.bashrc")
        fi
      fi

      local added=0
      for config in "${configs[@]}"; do
        if grep -q "gitid.sh" "$config" 2>/dev/null; then
          echo "✓ Already configured in $config"
          continue
        fi
        echo "" >> "$config"
        echo "# gitid: switch git identities" >> "$config"
        echo "$source_line" >> "$config"
        echo "✓ Added gitid to $config"
        added=1
      done

      if [ "$added" -eq 1 ]; then
        echo ""
        echo "Restart your terminal or run:"
        echo "  source $source_path"
      fi
      ;;

    # ── version ──────────────────────────────────────
    version|-v|--version)
      echo "gitid $GITID_VERSION"
      ;;

    # ── help ─────────────────────────────────────────
    help|"")
      echo ""
      echo "gitid — switch git auth & user details"
      echo ""
      echo "Usage:"
      echo "  gitid <command> [options]"
      echo ""
      echo "Commands:"
      echo "  add [name]                    Add or update a profile"
      echo "  remove <name>                 Remove a profile"
      echo "  list                          List all saved profiles"
      echo "  use [name]                    Switch to a profile (interactive if no name)"
      echo "  import [name]                 Import current git config as a profile"
      echo "  status                        Show current git config & active profile"
      echo "  setup                         Add gitid to your shell config"
      echo "  version                       Show version"
      echo "  help                          Show this help"
      echo ""
      echo "  config list                   Show all settings"
      echo "  config set <key> <value>      Set a config value"
      echo "  config get <key>              Get a config value"
      echo ""
      echo "  rule list                     List directory → profile rules"
      echo "  rule add <dir> <profile>      Auto-switch profile for a directory"
      echo "  rule remove <dir>             Remove a directory rule"
      echo ""
      echo "Config keys:"
      echo "  default_profile    Fallback profile when no directory rule matches"
      echo "  default_scope      global or local (default: global)"
      echo "  auto_switch        true or false — auto-switch on cd (default: true)"
      echo ""
      echo "Examples:"
      echo "  gitid add work"
      echo "  gitid import default"
      echo "  gitid use work"
      echo "  gitid rule add ~/work/acme work"
      echo "  gitid rule add ~/personal personal"
      echo "  gitid config set default_profile personal"
      echo "  gitid config set auto_switch true"
      echo ""
      ;;

    *)
      echo "Unknown command: $cmd"
      echo "Run \"gitid help\" for usage."
      return 1
      ;;
  esac
}

# Run auto-switch on initial load
_gitid_auto_switch
