# PowerShell setup script for Windows
# This script creates a virtual environment, installs dependencies, and sets up SAM2
#
# Note: If you encounter execution policy errors, run:
#   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Force output buffering to be disabled for real-time progress
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size(120, 9999)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SAM2 Setup Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get the script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VenvDir = Join-Path $ScriptDir ".venv"

# Error handling - use Continue for pip operations to handle warnings gracefully
$ErrorActionPreference = "Continue"

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
    Write-Host "Step 1: Creating virtual environment..." -ForegroundColor Yellow
    Write-Host "   Location: $VenvDir" -ForegroundColor Gray
    & $Python -m venv $VenvDir
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create virtual environment"
        exit 1
    }
    Write-Host "   ✓ Virtual environment created" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "Step 1: Virtual environment already exists" -ForegroundColor Green
    Write-Host "   Location: $VenvDir" -ForegroundColor Gray
    Write-Host ""
}

# Get paths to venv executables
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
$VenvPip = Join-Path $VenvDir "Scripts\pip.exe"

if (-not (Test-Path $VenvPython)) {
    Write-Error "Virtual environment Python not found at $VenvPython"
    exit 1
}

# Upgrade pip
Write-Host "Step 2: Upgrading pip..." -ForegroundColor Yellow
try {
    & $VenvPython -m pip install --upgrade pip --quiet
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        Write-Error "Failed to upgrade pip"
        exit 1
    }
    Write-Host "   ✓ pip upgraded" -ForegroundColor Green
} catch {
    Write-Error "Failed to upgrade pip: $($_.Exception.Message)"
    exit 1
}

# Check for NVIDIA GPU and install appropriate PyTorch version
Write-Host ""
Write-Host "Step 3: Checking for NVIDIA GPU and CUDA support..." -ForegroundColor Yellow
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

# Check if torch is already installed and uninstall if present (to avoid conflicts)
Write-Host ""
Write-Host "Step 4: Checking for existing PyTorch installation..." -ForegroundColor Yellow
$OriginalErrorAction = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"

# Check if torch is installed by trying to import it
$CheckTorchScript = @"
try:
    import torch
    print("INSTALLED")
except ImportError:
    print("NOT_INSTALLED")
"@

# Suppress stderr and capture only stdout
$ErrorActionPreference = "SilentlyContinue"
try {
    $TorchCheckOutput = $CheckTorchScript | & $VenvPython 2>&1 | Where-Object { $_ -is [string] -and $_ -notmatch "Error|Traceback|Warning" }
    $TorchStatus = ($TorchCheckOutput -join "").Trim()
} catch {
    $TorchStatus = "NOT_INSTALLED"
}
if (-not $TorchStatus -or $TorchStatus -eq "") {
    $TorchStatus = "NOT_INSTALLED"
}
$ErrorActionPreference = $OriginalErrorAction

if ($TorchStatus -eq "INSTALLED") {
    Write-Host "   Removing existing PyTorch installation..." -ForegroundColor Yellow
    $ErrorActionPreference = "SilentlyContinue"
    $null = & $VenvPip uninstall -y torch torchvision 2>&1 | Out-Null
    $ErrorActionPreference = $OriginalErrorAction
    Write-Host "   Removed existing PyTorch" -ForegroundColor Green
} else {
    Write-Host "   No existing PyTorch installation found" -ForegroundColor Gray
}

# Install PyTorch with appropriate CUDA support
Write-Host ""
Write-Host "Step 5: Installing PyTorch..." -ForegroundColor Yellow
$ErrorActionPreference = "Continue"  # Allow warnings during PyTorch installation
if ($HasCuda) {
    Write-Host "   GPU detected! Installing PyTorch with CUDA support" -ForegroundColor Green
    Write-Host "   This will download ~2-3 GB and may take 5-15 minutes..." -ForegroundColor Cyan
    Write-Host "   Please be patient, download progress will be shown below..." -ForegroundColor Gray
    Write-Host ""
    # Try CUDA 12.1 first (most recent, works with RTX 30xx series including RTX 3060 Ti)
    # Run pip directly without capturing to allow real-time output
    & $VenvPip install torch torchvision --index-url https://download.pytorch.org/whl/cu121 --progress-bar pretty
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        Write-Warning "Failed to install PyTorch with CUDA 12.1, trying CUDA 11.8..."
        Write-Host "Downloading and installing PyTorch with CUDA 11.8..." -ForegroundColor Gray
        Write-Host ""
        & $VenvPip install torch torchvision --index-url https://download.pytorch.org/whl/cu118 --progress-bar pretty
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            Write-Warning "Failed to install PyTorch with CUDA 11.8, installing CPU version instead..."
            Write-Host "Installing CPU-only PyTorch..." -ForegroundColor Gray
            Write-Host ""
            & $VenvPip install torch torchvision --progress-bar pretty
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
                Write-Error "Failed to install PyTorch"
                exit 1
            } else {
                Write-Host "PyTorch (CPU) installed successfully" -ForegroundColor Yellow
            }
        } else {
            Write-Host "PyTorch with CUDA 11.8 installed successfully" -ForegroundColor Green
        }
    } else {
        Write-Host "PyTorch with CUDA 12.1 installed successfully" -ForegroundColor Green
    }
    
    # Verify CUDA is available in PyTorch
    Write-Host ""
    Write-Host "Verifying CUDA availability in PyTorch..." -ForegroundColor Yellow
    $TempVerifyScript = Join-Path $ScriptDir "verify_cuda_temp.py"
    $VerifyScriptContent = "import torch`n"
    $VerifyScriptContent += "print(f'PyTorch version: {torch.__version__}')`n"
    $VerifyScriptContent += "print(f'CUDA available: {torch.cuda.is_available()}')`n"
    $VerifyScriptContent += "if torch.cuda.is_available():`n"
    $VerifyScriptContent += "    print(f'CUDA version: {torch.version.cuda}')`n"
    $VerifyScriptContent += "    print(f'GPU device: {torch.cuda.get_device_name(0)}')`n"
    $VerifyScriptContent += "else:`n"
    $VerifyScriptContent += "    print('WARNING: CUDA is not available in PyTorch despite NVIDIA GPU being detected.')`n"
    $VerifyScriptContent += "    print('This may indicate that CUDA drivers or toolkit need to be installed.')`n"
    $VerifyScriptContent | Out-File -FilePath $TempVerifyScript -Encoding utf8
    
    try {
        $VerifyOutput = & $VenvPython $TempVerifyScript 2>&1
        $VerifyOutput | Write-Host
        Remove-Item $TempVerifyScript -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Could not verify CUDA availability: $($_.Exception.Message)"
        Remove-Item $TempVerifyScript -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "   No NVIDIA GPU detected. Installing CPU-only PyTorch..." -ForegroundColor Yellow
    Write-Host "   This will download ~200 MB..." -ForegroundColor Gray
    Write-Host ""
    & $VenvPip install torch torchvision --progress-bar pretty
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        Write-Error "Failed to install PyTorch"
        exit 1
    } else {
        Write-Host "PyTorch (CPU) installed successfully" -ForegroundColor Green
    }
}
$ErrorActionPreference = "Stop"  # Restore strict error handling

# Install other Python dependencies from requirements.txt (excluding torch)
Write-Host ""
Write-Host "Step 6: Installing other dependencies..." -ForegroundColor Yellow
$ReqFile = Join-Path $ScriptDir "requirements.txt"
if (Test-Path $ReqFile) {
    # Read requirements.txt and filter out torch/torchvision
    $AllRequirements = Get-Content $ReqFile
    $Requirements = @()
    foreach ($line in $AllRequirements) {
        if ($line -notmatch '^\s*torch\s*$' -and $line -notmatch '^\s*torchvision\s*$' -and $line -notmatch '^\s*$') {
            $Requirements += $line
        }
    }
    
    if ($Requirements.Count -gt 0) {
        # Create a temporary requirements file without torch
        $TempReqFile = Join-Path $ScriptDir "requirements_temp.txt"
        $Requirements | Out-File -FilePath $TempReqFile -Encoding utf8
        $ErrorActionPreference = "Continue"
        & $VenvPip install -r $TempReqFile --progress-bar pretty
        $InstallExitCode = $LASTEXITCODE
        Remove-Item $TempReqFile -ErrorAction SilentlyContinue
        $ErrorActionPreference = "Stop"
        
        if ($InstallExitCode -ne 0 -and $InstallExitCode -ne $null) {
            Write-Error "Failed to install dependencies"
            exit 1
        }
        Write-Host "   ✓ Dependencies installed" -ForegroundColor Green
    } else {
        Write-Host "   No additional dependencies to install" -ForegroundColor Gray
    }
} else {
    Write-Warning "requirements.txt not found, skipping dependency installation"
}

# Install facebookresearch/sam2 as editable in external/sam2
Write-Host ""
Write-Host "Step 7: Setting up SAM2..." -ForegroundColor Yellow
$Sam2Dir = Join-Path $ScriptDir "external\sam2"
if (-not (Test-Path $Sam2Dir)) {
    Write-Host "   Cloning sam2 repository..." -ForegroundColor Gray
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

Write-Host "   Installing sam2 as editable package..." -ForegroundColor Gray
Write-Host "   This may take a few minutes..." -ForegroundColor Gray
Write-Host ""
$ErrorActionPreference = "Continue"
& $VenvPip install -e $Sam2Dir --progress-bar pretty
$ErrorActionPreference = "Stop"
if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
    Write-Error "Failed to install sam2"
    exit 1
}
Write-Host "   ✓ sam2 installed" -ForegroundColor Green

# Ensure model checkpoints are present; download if missing
Write-Host ""
Write-Host "Step 8: Checking for model checkpoints..." -ForegroundColor Yellow
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

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "You can now run the script with: .\run.ps1" -ForegroundColor Cyan
Write-Host ""

