#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="gaphunter"
SKILL_DIR="$HOME/.claude/skills/$SKILL_NAME"

if [ -d "$SKILL_DIR" ]; then
  rm -rf "$SKILL_DIR"
  echo "Uninstalled: $SKILL_DIR"
else
  echo "Not installed (directory not found: $SKILL_DIR)"
fi
