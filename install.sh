#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="gaphunter"
SKILL_DIR="$HOME/.claude/skills/$SKILL_NAME"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing $SKILL_NAME skill..."

mkdir -p "$SKILL_DIR"

if [ -L "$SKILL_DIR/SKILL.md" ]; then
  rm "$SKILL_DIR/SKILL.md"
fi

if [ -e "$SKILL_DIR/templates" ] || [ -L "$SKILL_DIR/templates" ]; then
  rm -rf "$SKILL_DIR/templates"
fi

ln -s "$REPO_DIR/SKILL.md" "$SKILL_DIR/SKILL.md"
ln -s "$REPO_DIR/templates" "$SKILL_DIR/templates"

echo "Installed: $SKILL_DIR/SKILL.md -> $REPO_DIR/SKILL.md"
echo "Installed: $SKILL_DIR/templates -> $REPO_DIR/templates"
echo "Restart Claude Code to pick up the new skill."
echo "Usage: /gaphunter <ProductName>"
