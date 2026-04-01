#!/usr/bin/env bash
set -euo pipefail

# Generates SHA256 checksums for all SKILL.md files.
# Output: CHECKSUMS.sha256 at repo root.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="${REPO_DIR}/skills"
OUTPUT="${REPO_DIR}/CHECKSUMS.sha256"

cd "$REPO_DIR"

# Find all SKILL.md files (exclude template)
files=()
for dir in "${SKILLS_DIR}"/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  [[ "$name" == _* ]] && continue
  [ -f "${dir}/SKILL.md" ] || continue
  files+=("skills/${name}/SKILL.md")
done

if [ ${#files[@]} -eq 0 ]; then
  echo "No SKILL.md files found" >&2
  exit 1
fi

# Generate checksums
shasum -a 256 "${files[@]}" > "$OUTPUT"

echo "Generated ${OUTPUT}:"
cat "$OUTPUT"
