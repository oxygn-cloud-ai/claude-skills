#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${REPO_DIR}/skills"
TARGET_BASE="${HOME}/.claude/skills"

usage() {
  echo "Usage: ./install.sh [skill-name | --list | --help]"
  echo ""
  echo "  ./install.sh           Install all skills"
  echo "  ./install.sh chk1      Install a specific skill"
  echo "  ./install.sh --list    List available skills"
  echo "  ./install.sh --help    Show this help"
}

list_skills() {
  echo "Available skills:"
  echo ""
  for dir in "${SKILLS_DIR}"/*/; do
    [ -d "$dir" ] || continue
    name="$(basename "$dir")"
    [[ "$name" == _* ]] && continue
    desc=""
    if [ -f "${dir}/SKILL.md" ]; then
      desc=$(grep -m1 '^description:' "${dir}/SKILL.md" | sed 's/^description: *//' | cut -c1-80)
    fi
    printf "  %-16s %s\n" "$name" "$desc"
  done
}

install_skill() {
  local name="$1"
  local source="${SKILLS_DIR}/${name}"
  local target="${TARGET_BASE}/${name}"

  if [ ! -d "$source" ]; then
    echo "ERROR: Skill '${name}' not found in ${SKILLS_DIR}"
    exit 1
  fi

  if [ ! -f "${source}/SKILL.md" ]; then
    echo "ERROR: ${source}/SKILL.md not found"
    exit 1
  fi

  if [ -d "$target" ]; then
    echo "Skill '${name}' already exists at ${target}"
    read -rp "Overwrite? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "Skipped '${name}'."
      return
    fi
  fi

  mkdir -p "$target"
  cp "${source}/SKILL.md" "${target}/SKILL.md"
  echo "Installed '${name}' → ${target}"
}

# Parse arguments
case "${1:-}" in
  --help|-h)
    usage
    exit 0
    ;;
  --list|-l)
    list_skills
    exit 0
    ;;
  "")
    # Install all skills
    count=0
    for dir in "${SKILLS_DIR}"/*/; do
      [ -d "$dir" ] || continue
      name="$(basename "$dir")"
      [[ "$name" == _* ]] && continue
      [ -f "${dir}/SKILL.md" ] || continue
      install_skill "$name"
      count=$((count + 1))
    done
    echo ""
    echo "Done. ${count} skill(s) installed."
    ;;
  *)
    install_skill "$1"
    ;;
esac
