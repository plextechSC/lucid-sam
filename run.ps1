# PowerShell run script for Windows
# This script activates the virtual environment and runs main.py
#
# Note: If you encounter execution policy errors, run:
#   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Get the script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VenvDir = Join-Path $ScriptDir ".venv"

# Check if venv exists, if not run setup
if (-not (Test-Path $VenvDir)) {
    Write-Host ".venv not found. Initializing environment via setup.ps1..."
    $SetupScript = Join-Path $ScriptDir "setup.ps1"
    if (Test-Path $SetupScript) {
        # Run setup script and capture output
        # Use Continue error action to handle warnings gracefully
        $OriginalErrorAction = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $SetupOutput = & powershell -ExecutionPolicy Bypass -File $SetupScript 2>&1
            $SetupOutput | Write-Host
            $SetupExitCode = $LASTEXITCODE
        } catch {
            Write-Error "Setup script failed: $($_.Exception.Message)"
            $ErrorActionPreference = $OriginalErrorAction
            exit 1
        }
        $ErrorActionPreference = $OriginalErrorAction
        
        # Check if setup actually failed (non-zero exit code)
        if ($SetupExitCode -ne 0 -and $SetupExitCode -ne $null) {
            Write-Error "Setup failed with exit code $SetupExitCode"
            exit 1
        }
        
        # Verify venv was created successfully
        if (-not (Test-Path $VenvDir)) {
            Write-Error "Setup completed but virtual environment was not created at $VenvDir"
            exit 1
        }
    } else {
        Write-Error "setup.ps1 not found. Please run setup.ps1 manually."
        exit 1
    }
}

# Use Python from the virtual environment directly
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
if (-not (Test-Path $VenvPython)) {
    Write-Error "Python executable not found in virtual environment at $VenvPython"
    exit 1
}

# Run main.py using the venv Python
$MainScript = Join-Path $ScriptDir "main.py"
if (Test-Path $MainScript) {
    & $VenvPython $MainScript
    exit $LASTEXITCODE
} else {
    Write-Error "main.py not found at $MainScript"
    exit 1
}

