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

    # Install facebookresearch/sam2 as editable in external/sam2
    SAM2_DIR="$SCRIPT_DIR/external/sam2"
    if [ ! -d "$SAM2_DIR" ]; then
      echo "Installing sam2 (facebookresearch/sam2) into $SAM2_DIR"
      mkdir -p "$(dirname "$SAM2_DIR")"
      if command -v git >/dev/null 2>&1; then
        git clone https://github.com/facebookresearch/sam2.git "$SAM2_DIR"
      else
        echo "git is required to install sam2. Please install git and re-run." >&2
        return 1 2>/dev/null
      fi
    fi
    pip install -e "$SAM2_DIR"

    # Ensure model checkpoints are present; download if missing
    CKPT_DIR="$SCRIPT_DIR/checkpoints"
    if [ -d "$CKPT_DIR" ]; then
      if ! ls "$CKPT_DIR"/*.pt >/dev/null 2>&1; then
        echo "No .pt checkpoints found in $CKPT_DIR. Downloading..."
        pushd "$CKPT_DIR" >/dev/null
        if [ -x "download_ckpts.sh" ]; then
          ./download_ckpts.sh
        else
          bash ./download_ckpts.sh
        fi
        popd >/dev/null
      else
        echo "Checkpoints already present in $CKPT_DIR"
      fi
    else
      echo "Creating checkpoints directory and downloading checkpoints..."
      mkdir -p "$CKPT_DIR"
      pushd "$CKPT_DIR" >/dev/null
      bash ./download_ckpts.sh
      popd >/dev/null
    fi
  else
    echo "Virtual environment is ready at $VENV_DIR"
    echo "To activate it in your current shell, run:"
    echo "  source ./setup.sh"
  fi
else
  echo "Failed to locate activation script at $VENV_DIR/bin/activate" >&2
  if [ "$is_sourced" -eq 1 ]; then return 1 2>/dev/null; else exit 1; fi
fi


