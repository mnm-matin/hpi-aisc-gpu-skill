#!/usr/bin/env bash
# Install or update the hpi-aisc-gpu agent skill.
#
# Usage:
#   ./install.sh           # symlink this checkout into ~/.agents/skills/hpi-aisc-gpu
#   ./install.sh --update  # git pull, then ensure the symlink exists
#
# Idempotent. Safe to re-run.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="hpi-aisc-gpu"
SKILLS_DIR="${AGENT_SKILLS_DIR:-$HOME/.agents/skills}"
LINK_PATH="$SKILLS_DIR/$SKILL_NAME"

if [[ "${1:-}" == "--update" ]]; then
  echo "[hpi-aisc-gpu] updating $REPO_DIR"
  git -C "$REPO_DIR" pull --ff-only
fi

mkdir -p "$SKILLS_DIR"

if [[ -L "$LINK_PATH" ]]; then
  current_target="$(readlink "$LINK_PATH")"
  if [[ "$current_target" == "$REPO_DIR" ]]; then
    echo "[hpi-aisc-gpu] symlink already points at $REPO_DIR"
    exit 0
  fi
  echo "[hpi-aisc-gpu] replacing existing symlink ($current_target -> $REPO_DIR)"
  rm "$LINK_PATH"
elif [[ -e "$LINK_PATH" ]]; then
  echo "[hpi-aisc-gpu] ERROR: $LINK_PATH exists and is not a symlink." >&2
  echo "Move or remove it manually, then re-run." >&2
  exit 1
fi

ln -s "$REPO_DIR" "$LINK_PATH"
echo "[hpi-aisc-gpu] installed: $LINK_PATH -> $REPO_DIR"
