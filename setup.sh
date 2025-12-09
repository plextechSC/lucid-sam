#!/usr/bin/env bash

# Resolve script path for bash and zsh (and fall back to $0)
if [ -n "${ZSH_VERSION:-}" ]; then
  SCRIPT_PATH="${(%):-%N}"
elif [ -n "${BASH_VERSION:-}" ]; then
  SCRIPT_PATH="${BASH_SOURCE[0]}"
else
  SCRIPT_PATH="$0"
fi

# Determine project root (directory of this script)
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

# Detect if this script is being sourced (bash/zsh)
is_sourced=0
if [ -n "${ZSH_EVAL_CONTEXT:-}" ]; then
  case $ZSH_EVAL_CONTEXT in *:file) is_sourced=1;; esac
elif [ -n "${BASH_VERSION:-}" ]; then
  if [ "${BASH_SOURCE[0]}" != "$0" ]; then is_sourced=1; fi
fi

# Safety options: only enable strict mode when executed directly
if [ "$is_sourced" -eq 0 ]; then
  set -euo pipefail
else
  # When sourced, avoid altering shell options (prevents leaking -u into zsh)
  :
fi

# Choose python executable
if command -v python3 >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
else
  echo "Python is not installed. Please install Python 3." >&2
  # If sourced, avoid exiting the caller shell
  if [ -n "${ZSH_EVAL_CONTEXT:-}" ] || [ -n "${BASH_VERSION:-}" ]; then return 1 2>/dev/null; fi
  exit 1
fi

# Create venv if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
  echo "Creating virtual environment at $VENV_DIR"
  "$PY" -m venv "$VENV_DIR"
fi

# Activate the venv. This only persists if this script is sourced.
if [ -f "$VENV_DIR/bin/activate" ]; then
  if [ "$is_sourced" -eq 1 ]; then
    # shellcheck source=/dev/null
    . "$VENV_DIR/bin/activate"
    echo "Activated virtual environment: $VENV_DIR"
    # Install Python dependencies if requirements.txt exists
    REQ_FILE="$SCRIPT_DIR/requirements.txt"
    if [ -f "$REQ_FILE" ]; then
      python -m pip install --upgrade pip
      pip install -r "$REQ_FILE"
    fi

    # Ensure SAM 1 model checkpoints are present; download if missing
    CKPT_DIR="$SCRIPT_DIR/checkpoints"
    mkdir -p "$CKPT_DIR"

    # SAM 1 checkpoint URLs
    SAM_VIT_H_URL="https://dl.fbaipublicfiles.com/segment_anything/sam_vit_h_4b8939.pth"
    SAM_VIT_L_URL="https://dl.fbaipublicfiles.com/segment_anything/sam_vit_l_0b3195.pth"
    SAM_VIT_B_URL="https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth"

    download_if_missing() {
      local url="$1"
      local filename="$(basename "$url")"
      local filepath="$CKPT_DIR/$filename"
      if [ ! -f "$filepath" ]; then
        echo "Downloading $filename..."
        curl -L -o "$filepath" "$url"
      else
        echo "Checkpoint $filename already exists."
      fi
    }

    # Download all SAM 1 checkpoints
    download_if_missing "$SAM_VIT_H_URL"
    download_if_missing "$SAM_VIT_L_URL"
    download_if_missing "$SAM_VIT_B_URL"

    echo "SAM 1 checkpoints ready in $CKPT_DIR"
  else
    echo "Virtual environment is ready at $VENV_DIR"
    echo "To activate it in your current shell, run:"
    echo "  source ./setup.sh"
  fi
else
  echo "Failed to locate activation script at $VENV_DIR/bin/activate" >&2
  if [ "$is_sourced" -eq 1 ]; then return 1 2>/dev/null; else exit 1; fi
fi


