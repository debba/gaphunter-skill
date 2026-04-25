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

ln -s "$REPO_DIR/SKILL.md" "$SKILL_DIR/SKILL.md"

echo "Installed: $SKILL_DIR/SKILL.md -> $REPO_DIR/SKILL.md"
echo "Restart Claude Code to pick up the new skill."
echo "Usage: /gaphunter <ProductName>"
