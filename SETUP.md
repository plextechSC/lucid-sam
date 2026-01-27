# Lucid-SAM Setup Guide (Lambda AI)

This guide is for setting up the environment on Lambda AI cloud instances, which reset to default Ubuntu installation each session.

## Quick Start (Single Command)

```bash
# Run from the lucid-sam directory
cd /lambda/nfs/lucid-sam/lucid-sam && ./setup_env.sh
```

## Environment Details

- **Platform:** Lambda AI Cloud
- **GPU:** NVIDIA GH200 480GB
- **CUDA:** 12.8
- **Python:** 3.12
- **PyTorch:** 2.7.0 (system-installed with CUDA support)

## Important: PyTorch CUDA Support

Lambda AI comes with a **system-wide PyTorch installation** at `/usr/lib/python3/dist-packages/` that has CUDA support enabled. 

**DO NOT** run `pip install torch --upgrade` or `pip install -r requirements.txt` with torch included - this will replace the CUDA-enabled PyTorch with a CPU-only version from PyPI.

### If you accidentally break CUDA support:

```bash
# Remove the user-installed CPU-only torch
pip uninstall torch torchvision -y

# The system CUDA-enabled torch will now be used
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
```

## Manual Setup Steps

### 1. Install Python dependencies (excluding torch)

```bash
# Install only non-torch dependencies
pip install segment-anything opencv-python pillow

# If you need numpy < 2 for compatibility:
pip install "numpy<2"
```

### 2. Verify CUDA is working

```bash
python -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA: {torch.cuda.is_available()}'); print(f'GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\"}')"
```

Expected output:
```
PyTorch: 2.7.0
CUDA: True
GPU: NVIDIA GH200 480GB
```

### 3. Download SAM checkpoints (if not already on NFS)

The checkpoints should persist on the NFS storage at `/lambda/nfs/lucid-sam/lucid-sam/checkpoints/`.

If missing, download:
```bash
mkdir -p checkpoints
cd checkpoints
wget https://dl.fbaipublicfiles.com/segment_anything/sam_vit_h_4b8939.pth
```

## Running the Scripts

### 1. Crop Images (removes lens distortion)

```bash
# Process all scenarios in data/ folder
python crop_images.py --data-dir data --output-dir cropped

# Dry run to see what would be processed
python crop_images.py --data-dir data --dry-run
```

This script:
- **Crops** cam02, cam05, cam07 (removes distortion borders)
- **Copies** all other cameras directly

### 2. Run SAM Segmentation

```bash
# Run in foreground
python main.py

# Run in tmux (recommended for long jobs)
tmux new -s sam -c /lambda/nfs/lucid-sam/lucid-sam 'python main.py'

# Detach from tmux: Ctrl+b, then d
# Reattach: tmux attach -t sam
```

Configure input/output in `main.py`:
```python
INPUT_DIR = "cropped"  # or "data" for uncropped
OUTPUT_DIR = "output"
```

## Directory Structure

```
lucid-sam/
├── data/                    # Raw input images
│   ├── 7PpL05/
│   │   ├── cam02/
│   │   ├── cam03/
│   │   └── ...
│   └── ffea0d/
│       └── ...
├── cropped/                 # Cropped images (after crop_images.py)
│   └── (same structure)
├── output/                  # SAM masks output
│   ├── 7PpL05/
│   │   ├── cam02/
│   │   │   ├── {frame_name}/
│   │   │   │   ├── 000.png  # mask 0
│   │   │   │   ├── 001.png  # mask 1
│   │   │   │   └── ...
│   │   │   └── ...
│   │   └── ...
│   └── ...
├── checkpoints/             # SAM model weights
├── main.py                  # Main SAM processing script
├── crop_images.py           # Image cropping script
├── sam.py                   # SAM wrapper functions
└── models.py                # Model definitions
```

## Troubleshooting

### "Numpy is not available" error
```bash
pip install "numpy<2"
```

### "Using device: cpu" (no CUDA)
```bash
# Check if user-installed torch is overriding system torch
pip list | grep torch

# If torch shows in user packages, remove it
pip uninstall torch torchvision -y
```

### tmux commands
```bash
tmux ls                  # List sessions
tmux attach -t sam       # Attach to session
tmux kill-session -t sam # Kill session
```

## NFS Storage

Lambda AI provides persistent NFS storage at `/lambda/nfs/`. Store your:
- Code repository
- Model checkpoints  
- Input/output data

These persist across sessions.
