#!/bin/bash
# Interactive tmux session picker for remote connections (Blink, SSH).
# Lists all tmux sessions and lets you pick one to attach.
# Usage: Add to ~/.ssh/rc or set as forced command, or call from shell profile.
set -euo pipefail

export PATH="/opt/homebrew/bin:$PATH"

# Ensure tmux sessions exist
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SESSIONS_SCRIPT="$SCRIPT_DIR/tmux-sessions.sh"
if [[ -x "$SESSIONS_SCRIPT" ]]; then
  "$SESSIONS_SCRIPT" 2>/dev/null || true
fi

if ! command -v tmux &>/dev/null; then
  echo "tmux not found." >&2
  exit 1
fi

# Get sessions
sessions=$(tmux ls -F '#{session_name} (#{session_windows} windows#{?session_attached, - attached,})' 2>/dev/null) || {
  echo "No tmux sessions running." >&2
  exit 1
}

count=$(echo "$sessions" | wc -l | tr -d ' ')

if [[ "$count" -eq 0 ]]; then
  echo "No tmux sessions found."
  exit 1
fi

# If only one session, attach directly
if [[ "$count" -eq 1 ]]; then
  session_name=$(echo "$sessions" | awk '{print $1}')
  echo "Only one session: $session_name — attaching..."
  exec tmux attach -t "$session_name"
fi

# Interactive picker
echo ""
echo "  tmux sessions"
echo "  ─────────────"
echo ""

i=1
names=()
while IFS= read -r line; do
  name=$(echo "$line" | awk '{print $1}')
  names+=("$name")
  # Highlight attached sessions
  if echo "$line" | grep -q "attached"; then
    printf "  \033[2m%2d) %s\033[0m\n" "$i" "$line"
  else
    printf "  %2d) %s\n" "$i" "$line"
  fi
  i=$((i + 1))
done <<< "$sessions"

echo ""
printf "  Select [1-%d]: " "$count"
read -r choice

# Validate
if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "$count" ]]; then
  echo "Invalid selection." >&2
  exit 1
fi

selected="${names[$((choice - 1))]}"
echo "  Attaching to $selected..."
exec tmux attach -t "$selected"
