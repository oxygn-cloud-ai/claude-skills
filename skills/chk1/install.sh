#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="chk1"
TARGET_DIR="${HOME}/.claude/skills/${SKILL_NAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="${SCRIPT_DIR}/SKILL.md"

if [ ! -f "$SOURCE_FILE" ]; then
  echo "ERROR: SKILL.md not found in ${SCRIPT_DIR}"
  exit 1
fi

if [ -d "$TARGET_DIR" ]; then
  echo "Skill '${SKILL_NAME}' already exists at ${TARGET_DIR}"
  read -rp "Overwrite? [y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

mkdir -p "$TARGET_DIR"
cp "$SOURCE_FILE" "$TARGET_DIR/SKILL.md"

echo "Installed '${SKILL_NAME}' skill to ${TARGET_DIR}"
echo ""
echo "Usage in Claude Code:"
echo "  /chk1                     Audit most recent implementation"
echo "  /chk1 <commit>..<commit>  Audit a specific commit range"
echo "  /chk1 help                Display usage guide"
