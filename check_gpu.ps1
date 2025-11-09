# PowerShell script to check GPU and CUDA availability
# This script helps diagnose why CUDA might not be working

Write-Host "=== GPU and CUDA Diagnostic ===" -ForegroundColor Cyan
Write-Host ""

# Check for nvidia-smi
Write-Host "1. Checking for NVIDIA GPU drivers..." -ForegroundColor Yellow
$NvidiaSmiPath = $null
if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    $NvidiaSmiPath = "nvidia-smi"
} elseif (Test-Path "C:\Windows\System32\nvidia-smi.exe") {
    $NvidiaSmiPath = "C:\Windows\System32\nvidia-smi.exe"
}

if ($NvidiaSmiPath) {
    Write-Host "   ✓ nvidia-smi found" -ForegroundColor Green
    Write-Host "   Running nvidia-smi..." -ForegroundColor Yellow
    & $NvidiaSmiPath
    Write-Host ""
} else {
    Write-Host "   ✗ nvidia-smi not found. NVIDIA drivers may not be installed." -ForegroundColor Red
    Write-Host "   Please install NVIDIA drivers from: https://www.nvidia.com/drivers" -ForegroundColor Yellow
    Write-Host ""
}

# Check Python environment
Write-Host "2. Checking Python environment..." -ForegroundColor Yellow
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VenvDir = Join-Path $ScriptDir ".venv"
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"

if (Test-Path $VenvPython) {
    Write-Host "   ✓ Virtual environment found at $VenvDir" -ForegroundColor Green
    
    # Check PyTorch installation
    Write-Host "3. Checking PyTorch installation..." -ForegroundColor Yellow
    $PyTorchCheck = @"
import sys
try:
    import torch
    print(f"   ✓ PyTorch version: {torch.__version__}")
    print(f"   ✓ CUDA available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"   ✓ CUDA version: {torch.version.cuda}")
        print(f"   ✓ cuDNN version: {torch.backends.cudnn.version()}")
        print(f"   ✓ Number of GPUs: {torch.cuda.device_count()}")
        for i in range(torch.cuda.device_count()):
            print(f"   ✓ GPU {i}: {torch.cuda.get_device_name(i)}")
            print(f"     Memory: {torch.cuda.get_device_properties(i).total_memory / 1024**3:.2f} GB")
    else:
        print("   ✗ CUDA is not available in PyTorch")
        print("   This means PyTorch was installed without CUDA support (CPU-only version)")
        print("")
        print("   To fix this, you need to:")
        print("   1. Uninstall current PyTorch: pip uninstall torch torchvision")
        print("   2. Install PyTorch with CUDA 12.1: pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121")
        print("   3. Or install PyTorch with CUDA 11.8: pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118")
        print("")
        print("   Alternatively, delete the .venv folder and rerun setup.ps1")
except ImportError:
    print("   ✗ PyTorch is not installed")
    sys.exit(1)
"@
    
    $PyTorchCheck | & $VenvPython
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   ✗ Error checking PyTorch" -ForegroundColor Red
    }
} else {
    Write-Host "   ✗ Virtual environment not found at $VenvDir" -ForegroundColor Red
    Write-Host "   Please run setup.ps1 first" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Diagnostic Complete ===" -ForegroundColor Cyan

