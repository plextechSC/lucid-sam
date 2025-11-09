# PowerShell script to fix CUDA installation for PyTorch
# This script reinstalls PyTorch with CUDA support if it was previously installed without CUDA

Write-Host "=== PyTorch CUDA Fix Script ===" -ForegroundColor Cyan
Write-Host ""

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VenvDir = Join-Path $ScriptDir ".venv"
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
$VenvPip = Join-Path $VenvDir "Scripts\pip.exe"

# Check if virtual environment exists
if (-not (Test-Path $VenvPython)) {
    Write-Error "Virtual environment not found at $VenvDir"
    Write-Host "Please run setup.ps1 first to create the virtual environment."
    exit 1
}

Write-Host "Virtual environment found: $VenvDir" -ForegroundColor Green
Write-Host ""

# Check for NVIDIA GPU
Write-Host "Checking for NVIDIA GPU..." -ForegroundColor Yellow
$NvidiaSmiPath = $null
if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    $NvidiaSmiPath = "nvidia-smi"
} elseif (Test-Path "C:\Windows\System32\nvidia-smi.exe") {
    $NvidiaSmiPath = "C:\Windows\System32\nvidia-smi.exe"
}

if (-not $NvidiaSmiPath) {
    Write-Warning "nvidia-smi not found. NVIDIA drivers may not be installed."
    Write-Host "Please install NVIDIA drivers from: https://www.nvidia.com/drivers" -ForegroundColor Yellow
    Write-Host ""
    $Continue = Read-Host "Continue anyway? (y/n)"
    if ($Continue -ne "y" -and $Continue -ne "Y") {
        exit 1
    }
} else {
    Write-Host "NVIDIA GPU detected" -ForegroundColor Green
    & $NvidiaSmiPath --query-gpu=name --format=csv,noheader | ForEach-Object {
        Write-Host "  GPU: $_" -ForegroundColor Green
    }
    Write-Host ""
}

# Check current PyTorch installation
Write-Host "Checking current PyTorch installation..." -ForegroundColor Yellow
$CheckScript = @"
import torch
print(f"PyTorch version: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"CUDA version: {torch.version.cuda}")
    print(f"GPU: {torch.cuda.get_device_name(0)}")
"@

$CheckOutput = $CheckScript | & $VenvPython 2>&1
Write-Host $CheckOutput

$HasCuda = $CheckOutput -match "CUDA available: True"

if ($HasCuda) {
    Write-Host ""
    Write-Host "CUDA is already available in PyTorch!" -ForegroundColor Green
    Write-Host "No action needed."
    exit 0
}

Write-Host ""
Write-Host "CUDA is not available. Reinstalling PyTorch with CUDA support..." -ForegroundColor Yellow
Write-Host ""

# Uninstall current PyTorch
Write-Host "1. Uninstalling current PyTorch..." -ForegroundColor Yellow
& $VenvPip uninstall -y torch torchvision torchaudio 2>&1 | Out-Null
Write-Host "   ✓ Uninstalled" -ForegroundColor Green

# Install PyTorch with CUDA 12.1
Write-Host "2. Installing PyTorch with CUDA 12.1..." -ForegroundColor Yellow
& $VenvPip install torch torchvision --index-url https://download.pytorch.org/whl/cu121
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to install PyTorch with CUDA 12.1, trying CUDA 11.8..."
    & $VenvPip install torch torchvision --index-url https://download.pytorch.org/whl/cu118
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install PyTorch with CUDA support"
        Write-Host "Falling back to CPU-only version..." -ForegroundColor Yellow
        & $VenvPip install torch torchvision
        exit 1
    } else {
        Write-Host "   ✓ PyTorch with CUDA 11.8 installed" -ForegroundColor Green
    }
} else {
    Write-Host "   ✓ PyTorch with CUDA 12.1 installed" -ForegroundColor Green
}

# Verify installation
Write-Host ""
Write-Host "3. Verifying CUDA installation..." -ForegroundColor Yellow
$VerifyScript = @"
import torch
print(f"PyTorch version: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"CUDA version: {torch.version.cuda}")
    print(f"GPU: {torch.cuda.get_device_name(0)}")
    print("")
    print("✓ SUCCESS: CUDA is now available!")
else:
    print("")
    print("✗ WARNING: CUDA is still not available.")
    print("This may indicate that:")
    print("  1. CUDA drivers are not properly installed")
    print("  2. The CUDA version in PyTorch doesn't match your drivers")
    print("  3. Your GPU is not CUDA-compatible")
"@

$VerifyOutput = $VerifyScript | & $VenvPython 2>&1
Write-Host $VerifyOutput

if ($VerifyOutput -match "CUDA available: True") {
    Write-Host ""
    Write-Host "=== Fix Complete ===" -ForegroundColor Green
    Write-Host "PyTorch with CUDA support is now installed and ready to use."
} else {
    Write-Host ""
    Write-Host "=== Fix Incomplete ===" -ForegroundColor Yellow
    Write-Host "CUDA is still not available. Please check:"
    Write-Host "  1. NVIDIA drivers are installed (run nvidia-smi)"
    Write-Host "  2. Your GPU supports CUDA"
    Write-Host "  3. Try running check_gpu.ps1 for more diagnostics"
}

