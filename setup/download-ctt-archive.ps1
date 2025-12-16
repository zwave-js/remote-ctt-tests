<#
.SYNOPSIS
    Downloads the CTT setup archive from GitHub.

.DESCRIPTION
    This script downloads the latest CTT setup archive from the
    byoctt private repository.

.EXAMPLE
    .\download-ctt-archive.ps1

.NOTES
    Requires GH_TOKEN environment variable with access to the byoctt repository.
#>

$ErrorActionPreference = "Stop"

$REPO = "zwave-js/byoctt"
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$OUTPUT_FILE = Join-Path $repoRoot "setup\ctt-setup.zip"

Write-Host "Downloading CTT setup archive..." -ForegroundColor Cyan

# Remove existing file if present
if (Test-Path $OUTPUT_FILE) {
    Remove-Item $OUTPUT_FILE
}

# Download from latest release
Write-Host "  Downloading from $REPO..." -ForegroundColor Green
& gh release download latest --repo $REPO --pattern "ctt-setup.zip" -D (Split-Path $OUTPUT_FILE)

if ($LASTEXITCODE -ne 0) {
    throw "Failed to download CTT archive from $REPO"
}

if (-not (Test-Path $OUTPUT_FILE)) {
    throw "Downloaded file not found at $OUTPUT_FILE"
}

$fileSize = (Get-Item $OUTPUT_FILE).Length / 1MB
Write-Host "  Downloaded: ctt-setup.zip ($([math]::Round($fileSize, 1)) MB)" -ForegroundColor Green
Write-Host "Done!" -ForegroundColor Green
