# Run Segment Anything Model

## Linux/macOS
 - Clone this repo
 - Make sure you're in the `/lucid-sam` folder
 - Run this command: `sh run.sh`
 - To change the image you process, replace `input.png`. You can also manually point the script to use any image by changing `image_path` in `sam.py`.

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
 - The script will automatically download SAM2 checkpoints if they're missing
 - Then run `.\run.ps1` to execute the main script
