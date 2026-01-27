#!/bin/bash
# Quick environment setup for Lambda AI sessions
# Usage: ./setup_env.sh

set -e

echo "=========================================="
echo "Lucid-SAM Environment Setup (Lambda AI)"
echo "=========================================="

# Ensure we're in the right directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo "[1/4] Removing any user-installed torch (to preserve system CUDA torch)..."
pip uninstall torch torchvision -y 2>/dev/null || true

echo ""
echo "[2/4] Installing Python dependencies..."
pip install --quiet segment-anything opencv-python pillow "numpy<2"

echo ""
echo "[3/4] Verifying CUDA support..."
python -c "
import torch
print(f'  PyTorch version: {torch.__version__}')
print(f'  CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'  GPU: {torch.cuda.get_device_name(0)}')
else:
    print('  WARNING: CUDA not available!')
    exit(1)
"

echo ""
echo "[4/4] Checking SAM checkpoint..."
if [ -f "checkpoints/sam_vit_h_4b8939.pth" ]; then
    echo "  SAM checkpoint found: checkpoints/sam_vit_h_4b8939.pth"
else
    echo "  WARNING: SAM checkpoint not found!"
    echo "  Download with:"
    echo "    mkdir -p checkpoints && cd checkpoints"
    echo "    wget https://dl.fbaipublicfiles.com/segment_anything/sam_vit_h_4b8939.pth"
fi

echo ""
echo "=========================================="
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Crop images:  python crop_images.py --data-dir data --output-dir cropped"
echo "  2. Run SAM:      python main.py"
echo "  3. Or in tmux:   tmux new -s sam 'python main.py'"
echo "=========================================="
