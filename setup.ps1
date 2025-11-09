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

# Install Python dependencies if requirements.txt exists
$ReqFile = Join-Path $ScriptDir "requirements.txt"
if (Test-Path $ReqFile) {
    Write-Host "Installing dependencies from requirements.txt..."
    & $VenvPip install -r $ReqFile
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install dependencies"
        exit 1
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

