#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DEST="$HOME/.claude/skills"

mkdir -p "$SKILLS_DEST"

# Collect code and vault workflow names (space-padded for whole-word matching)
code_names=""
for src in "$REPO_ROOT/code/workflows"/*.md; do
  [[ -e "$src" ]] || continue
  code_names="$code_names $(basename "$src" .md) "
done

vault_names=""
for src in "$REPO_ROOT/vault/workflows"/*.md; do
  [[ -e "$src" ]] || continue
  vault_names="$vault_names $(basename "$src" .md) "
done

# Error on any name that appears in both code and vault
for src in "$REPO_ROOT/vault/workflows"/*.md; do
  [[ -e "$src" ]] || continue
  name=$(basename "$src" .md)
  if [[ "$code_names" == *" $name "* ]]; then
    echo "ERROR: workflow name collision — '$name' exists in both code/workflows/ and vault/workflows/"
    echo "Move it to shared/workflows/ if it's context-independent, or rename one copy."
    exit 1
  fi
done

# Write a skill stub file
write_skill() {
  local name="$1"
  local stub="$2"
  mkdir -p "$SKILLS_DEST/$name"
  rm -f "$SKILLS_DEST/$name/SKILL.md"
  printf '%s\n' "$stub" > "$SKILLS_DEST/$name/SKILL.md"
  installed_names="$installed_names $name "
  echo "Synced: $name"
}

installed_names=""

for src in "$REPO_ROOT/code/workflows"/*.md; do
  [[ -e "$src" ]] || continue
  name=$(basename "$src" .md)
  write_skill "$name" "Read and follow \`_AI/local/workflows/$name.md\`."
done

for src in "$REPO_ROOT/vault/workflows"/*.md; do
  [[ -e "$src" ]] || continue
  name=$(basename "$src" .md)
  write_skill "$name" "Read and follow \`_AI/local/workflows/$name.md\`."
done

for src in "$REPO_ROOT/shared/workflows"/*.md; do
  [[ -e "$src" ]] || continue
  name=$(basename "$src" .md)
  write_skill "$name" "Read and follow \`_AI/shared/workflows/$name.md\`."
done

# Remove stale skills: SKILL.md references our paths but name not in current install set
for dir in "$SKILLS_DEST"/*/; do
  name=$(basename "$dir")
  skill_file="$dir/SKILL.md"
  [[ -f "$skill_file" ]] || continue
  if grep -q '_AI/local/workflows/\|_AI/shared/workflows/' "$skill_file" 2>/dev/null; then
    if [[ "$installed_names" != *" $name "* ]]; then
      rm -rf "$dir"
      echo "Removed: $name"
    fi
  fi
done
