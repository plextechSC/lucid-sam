# Run Segment Anything Model

## Linux/macOS
 - Clone this repo
 - Make sure you're in the `/lucid-sam` folder
 - Run this command: `sh run.sh`
 - To change the images you process, put your images in `/input_images/[scenario name]`.
 - Example scenario name: "highway sunset"

## Windows
 - Clone this repo
 - Make sure you're in the `/lucid-sam` folder
 - Open PowerShell
 - If you encounter execution policy errors, run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
 - Run this command: `.\run.ps1`
 - To change the image you process, replace `input.png`. You can also manually point the script to use any image by changing `image_path` in `sam.py`.

### Manual Setup (Windows)
If you prefer to set up manually:
 - Run `.\setup.ps1` to create the virtual environment and install dependencies
 - The script will automatically detect NVIDIA GPUs and install PyTorch with CUDA support
 - The script will automatically download SAM2 checkpoints if they're missing
 - Then run `.\run.ps1` to execute the main script

### GPU Support (Windows)
The setup script automatically detects NVIDIA GPUs (like RTX 3060 Ti) and installs PyTorch with CUDA support.

**If your GPU is not being used:**
1. Make sure you have NVIDIA drivers installed (check with `nvidia-smi`)
2. Run `.\check_gpu.ps1` to diagnose GPU and CUDA availability
3. If PyTorch was installed without CUDA, run `.\fix_cuda.ps1` to automatically reinstall PyTorch with CUDA support
   - Alternatively, you can delete the `.venv` folder and rerun `.\setup.ps1` (recommended for fresh installs)
   - Or manually reinstall PyTorch with CUDA:
     ```powershell
     .\.venv\Scripts\pip.exe uninstall -y torch torchvision
     .\.venv\Scripts\pip.exe install torch torchvision --index-url https://download.pytorch.org/whl/cu121
     ```

**Requirements for NVIDIA GPU:**
- NVIDIA GPU with CUDA support (RTX 3060 Ti and newer are supported)
- NVIDIA drivers installed
- PyTorch with CUDA support (automatically installed by setup.ps1)
