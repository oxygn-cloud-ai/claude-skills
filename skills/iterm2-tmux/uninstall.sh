#!/usr/bin/env bash
set -euo pipefail

# iterm2-tmux uninstaller
# Removes installed scripts and config. Does NOT touch ~/.tmux.conf or iTerm2 preferences.

CONFIG_FILE="${HOME}/.config/iterm2-tmux/config"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/.local/bin}"

# Read saved install dir from config if available
if [ -f "$CONFIG_FILE" ]; then
  cfg_dir=$(grep '^INSTALL_DIR=' "$CONFIG_FILE" 2>/dev/null | cut -d= -f2- | tr -d '"' || true)
  [ -n "$cfg_dir" ] && INSTALL_DIR="$cfg_dir"
fi

# --- Colors ---
if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; CYAN=''; BOLD=''; RESET=''
fi

ok()   { printf "${GREEN}  ok${RESET}  %s\n" "$*"; }
warn() { printf "${YELLOW}warn${RESET}  %s\n" "$*" >&2; }
info() { printf "${CYAN}info${RESET}  %s\n" "$*"; }

SCRIPTS=(tmux-iterm-tabs.sh tmux-attach-session.sh tmux-sessions.sh tmux-picker.sh gen-session-bg.py)

printf "\n${BOLD}iterm2-tmux uninstall${RESET}\n\n"

# Remove scripts
for script in "${SCRIPTS[@]}"; do
  target="${INSTALL_DIR}/${script}"
  if [ -f "$target" ] || [ -L "$target" ]; then
    rm "$target"
    ok "Removed ${target}"
  else
    warn "${script} not found at ${target}"
  fi
done

# Remove session backgrounds
bg_dir="${INSTALL_DIR}/.session-backgrounds"
if [ -d "$bg_dir" ]; then
  rm -rf "$bg_dir"
  ok "Removed ${bg_dir}"
fi

# Remove config
if [ -d "${HOME}/.config/iterm2-tmux" ]; then
  rm -rf "${HOME}/.config/iterm2-tmux"
  ok "Removed config directory"
fi

echo ""
info "~/.tmux.conf and iTerm2 preferences were NOT modified."
info "Remove the iterm2-tmux settings from ~/.tmux.conf manually if desired."
echo ""
