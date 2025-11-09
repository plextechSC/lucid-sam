# PowerShell script to download SAM 2.1 checkpoints
# This is a Windows version of download_ckpts.sh

# Define the URLs for SAM 2.1 checkpoints
$SAM2p1_BASE_URL = "https://dl.fbaipublicfiles.com/segment_anything_2/092824"
$sam2p1_hiera_t_url = "$SAM2p1_BASE_URL/sam2.1_hiera_tiny.pt"
$sam2p1_hiera_s_url = "$SAM2p1_BASE_URL/sam2.1_hiera_small.pt"
$sam2p1_hiera_b_plus_url = "$SAM2p1_BASE_URL/sam2.1_hiera_base_plus.pt"
$sam2p1_hiera_l_url = "$SAM2p1_BASE_URL/sam2.1_hiera_large.pt"

# Function to download a file
function Download-File {
    param(
        [string]$Url,
        [string]$OutputPath
    )
    
    try {
        Write-Host "Downloading $OutputPath..."
        $ProgressPreference = 'SilentlyContinue'  # Suppress progress bar for cleaner output
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
        if (Test-Path $OutputPath) {
            Write-Host "Successfully downloaded $OutputPath"
            return $true
        } else {
            Write-Error "Download failed: $OutputPath"
            return $false
        }
    } catch {
        Write-Error "Failed to download from $Url : $($_.Exception.Message)"
        return $false
    }
}

# Get the script directory (checkpoints directory)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Download each checkpoint
$Success = $true

Write-Host "Downloading sam2.1_hiera_tiny.pt checkpoint..."
if (-not (Download-File -Url $sam2p1_hiera_t_url -OutputPath (Join-Path $ScriptDir "sam2.1_hiera_tiny.pt"))) {
    $Success = $false
}

Write-Host "Downloading sam2.1_hiera_small.pt checkpoint..."
if (-not (Download-File -Url $sam2p1_hiera_s_url -OutputPath (Join-Path $ScriptDir "sam2.1_hiera_small.pt"))) {
    $Success = $false
}

Write-Host "Downloading sam2.1_hiera_base_plus.pt checkpoint..."
if (-not (Download-File -Url $sam2p1_hiera_b_plus_url -OutputPath (Join-Path $ScriptDir "sam2.1_hiera_base_plus.pt"))) {
    $Success = $false
}

Write-Host "Downloading sam2.1_hiera_large.pt checkpoint..."
if (-not (Download-File -Url $sam2p1_hiera_l_url -OutputPath (Join-Path $ScriptDir "sam2.1_hiera_large.pt"))) {
    $Success = $false
}

if ($Success) {
    Write-Host "All checkpoints downloaded successfully."
    exit 0
} else {
    Write-Error "Some checkpoints failed to download."
    exit 1
}

