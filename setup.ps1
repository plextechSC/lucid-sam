# PowerShell setup script for Windows
# This script creates a virtual environment, installs dependencies, and sets up SAM2
#
# Note: If you encounter execution policy errors, run:
#   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Get the script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VenvDir = Join-Path $ScriptDir ".venv"

# Error handling
$ErrorActionPreference = "Stop"

# Check if Python is available
$Python = $null
if (Get-Command python3 -ErrorAction SilentlyContinue) {
    $Python = "python3"
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $Python = "python"
} else {
    Write-Error "Python is not installed. Please install Python 3."
    exit 1
}

# Create venv if it doesn't exist
if (-not (Test-Path $VenvDir)) {
    Write-Host "Creating virtual environment at $VenvDir"
    & $Python -m venv $VenvDir
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create virtual environment"
        exit 1
    }
}

# Get paths to venv executables
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
$VenvPip = Join-Path $VenvDir "Scripts\pip.exe"

if (-not (Test-Path $VenvPython)) {
    Write-Error "Virtual environment Python not found at $VenvPython"
    exit 1
}

Write-Host "Using virtual environment: $VenvDir"

# Upgrade pip
Write-Host "Upgrading pip..."
& $VenvPython -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to upgrade pip"
    exit 1
}

# Check for NVIDIA GPU and install appropriate PyTorch version
Write-Host "Checking for NVIDIA GPU and CUDA support..."
$HasCuda = $false
$CudaVersion = $null

# Check if nvidia-smi is available (indicates NVIDIA drivers)
# On Windows, nvidia-smi is usually in C:\Windows\System32 or in the PATH
$NvidiaSmiPath = $null
if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    $NvidiaSmiPath = "nvidia-smi"
} elseif (Test-Path "C:\Windows\System32\nvidia-smi.exe") {
    $NvidiaSmiPath = "C:\Windows\System32\nvidia-smi.exe"
}

if ($NvidiaSmiPath) {
    Write-Host "NVIDIA GPU detected. Checking CUDA version..."
    try {
        $NvidiaSmiOutput = & $NvidiaSmiPath --query-gpu=driver_version,cuda_version --format=csv,noheader,nounits 2>&1
        if ($LASTEXITCODE -eq 0 -and $NvidiaSmiOutput) {
            $HasCuda = $true
            Write-Host "NVIDIA GPU driver detected. CUDA should be available."
            # Try to extract CUDA version if available
            if ($NvidiaSmiOutput -match "(\d+\.\d+)") {
                $CudaVersion = $Matches[1]
                Write-Host "Driver reports CUDA version: $CudaVersion"
            }
        }
    } catch {
        Write-Warning "Could not query NVIDIA GPU: $($_.Exception.Message)"
    }
}

# Uninstall existing torch/torchvision if present (to avoid conflicts)
Write-Host "Checking for existing PyTorch installation..."
& $VenvPip uninstall -y torch torchvision 2>&1 | Out-Null

# Install PyTorch with appropriate CUDA support
if ($HasCuda) {
    Write-Host "Installing PyTorch with CUDA support for NVIDIA GPU..."
    # Try CUDA 12.1 first (most recent, works with RTX 30xx series including RTX 3060 Ti)
    Write-Host "Attempting to install PyTorch with CUDA 12.1..."
    & $VenvPip install torch torchvision --index-url https://download.pytorch.org/whl/cu121
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to install PyTorch with CUDA 12.1, trying CUDA 11.8..."
        & $VenvPip install torch torchvision --index-url https://download.pytorch.org/whl/cu118
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to install PyTorch with CUDA 11.8, installing CPU version instead..."
            & $VenvPip install torch torchvision
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to install PyTorch"
                exit 1
            }
        } else {
            Write-Host "PyTorch with CUDA 11.8 installed successfully"
        }
    } else {
        Write-Host "PyTorch with CUDA 12.1 installed successfully"
    }
    
    # Verify CUDA is available in PyTorch
    Write-Host "Verifying CUDA availability in PyTorch..."
    $VerifyScript = @"
import torch
print(f"PyTorch version: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"CUDA version: {torch.version.cuda}")
    print(f"GPU device: {torch.cuda.get_device_name(0)}")
else:
    print("WARNING: CUDA is not available in PyTorch despite NVIDIA GPU being detected.")
    print("This may indicate that CUDA drivers or toolkit need to be installed.")
"@
    $VerifyScript | & $VenvPython
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Could not verify CUDA availability"
    }
} else {
    Write-Host "No NVIDIA GPU detected or nvidia-smi not available. Installing CPU-only PyTorch..."
    & $VenvPip install torch torchvision
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install PyTorch"
        exit 1
    }
}

# Install other Python dependencies from requirements.txt (excluding torch)
$ReqFile = Join-Path $ScriptDir "requirements.txt"
if (Test-Path $ReqFile) {
    Write-Host "Installing other dependencies from requirements.txt..."
    # Read requirements.txt and filter out torch/torchvision
    $Requirements = Get-Content $ReqFile | Where-Object { 
        $_ -notmatch '^\s*torch\s*$' -and 
        $_ -notmatch '^\s*torchvision\s*$' -and 
        $_ -notmatch '^\s*$' 
    }
    
    if ($Requirements.Count -gt 0) {
        # Create a temporary requirements file without torch
        $TempReqFile = Join-Path $ScriptDir "requirements_temp.txt"
        $Requirements | Out-File -FilePath $TempReqFile -Encoding utf8
        & $VenvPip install -r $TempReqFile
        $InstallExitCode = $LASTEXITCODE
        Remove-Item $TempReqFile -ErrorAction SilentlyContinue
        
        if ($InstallExitCode -ne 0) {
            Write-Error "Failed to install dependencies"
            exit 1
        }
    } else {
        Write-Host "No additional dependencies to install (torch already installed)"
    }
} else {
    Write-Warning "requirements.txt not found, skipping dependency installation"
}

# Install facebookresearch/sam2 as editable in external/sam2
$Sam2Dir = Join-Path $ScriptDir "external\sam2"
if (-not (Test-Path $Sam2Dir)) {
    Write-Host "Installing sam2 (facebookresearch/sam2) into $Sam2Dir"
    $ExternalDir = Split-Path -Parent $Sam2Dir
    if (-not (Test-Path $ExternalDir)) {
        New-Item -ItemType Directory -Path $ExternalDir -Force | Out-Null
    }
    
    if (Get-Command git -ErrorAction SilentlyContinue) {
        git clone https://github.com/facebookresearch/sam2.git $Sam2Dir
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to clone sam2 repository"
            exit 1
        }
    } else {
        Write-Error "git is required to install sam2. Please install git and re-run."
        exit 1
    }
}

Write-Host "Installing sam2 as editable package..."
& $VenvPip install -e $Sam2Dir
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to install sam2"
    exit 1
}

# Ensure model checkpoints are present; download if missing
$CkptDir = Join-Path $ScriptDir "checkpoints"
if (Test-Path $CkptDir) {
    $CkptFiles = Get-ChildItem -Path $CkptDir -Filter "*.pt" -ErrorAction SilentlyContinue
    if ($CkptFiles.Count -eq 0) {
        Write-Host "No .pt checkpoints found in $CkptDir. Downloading..."
        $DownloadScript = Join-Path $CkptDir "download_ckpts.ps1"
        if (Test-Path $DownloadScript) {
            Push-Location $CkptDir
            & powershell -ExecutionPolicy Bypass -File $DownloadScript
            Pop-Location
        } else {
            Write-Warning "download_ckpts.ps1 not found. Please download checkpoints manually."
        }
    } else {
        Write-Host "Checkpoints already present in $CkptDir"
    }
} else {
    Write-Host "Creating checkpoints directory and downloading checkpoints..."
    New-Item -ItemType Directory -Path $CkptDir -Force | Out-Null
    $DownloadScript = Join-Path $CkptDir "download_ckpts.ps1"
    if (Test-Path $DownloadScript) {
        Push-Location $CkptDir
        & powershell -ExecutionPolicy Bypass -File $DownloadScript
        Pop-Location
    } else {
        Write-Warning "download_ckpts.ps1 not found. Please download checkpoints manually."
    }
}

Write-Host "Setup complete!"

