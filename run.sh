#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

if [ ! -d "$VENV_DIR" ]; then
  echo ".venv not found. Initializing environment via setup.sh..."
  # Source to create and activate if possible
  if [ -f "$SCRIPT_DIR/setup.sh" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/setup.sh"
  else
    echo "setup.sh not found. Please run 'python3 -m venv .venv' manually." >&2
    exit 1
  fi
else
  # shellcheck source=/dev/null
  source "$VENV_DIR/bin/activate"
fi

exec python3 "$SCRIPT_DIR/sam.py"


