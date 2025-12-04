<#
.SYNOPSIS
    Extracts the network state archive on CI before running tests.

.DESCRIPTION
    This script extracts setup/network-state.zip and places files in the correct locations:
    - storage/ -> zwave_stack/storage/
    - dut-storage/ -> DUT storage directory (from config.json)

.EXAMPLE
    .\unpack-network-state-archive.ps1
#>

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$archiveFile = Join-Path $repoRoot "setup\network-state.zip"
$tempDir = Join-Path $env:TEMP "network-state-extract"

# Helper function to parse JSON with comments (JSON5-style)
function ConvertFrom-Json5 {
    param(
        [Parameter(ValueFromPipeline=$true)]
        [string]$Content
    )
    # Remove single-line comments (// ...)
    $Content = $Content -replace '(?m)^\s*//.*$', ''
    $Content = $Content -replace '//[^"]*$', ''
    # Remove multi-line comments (/* ... */)
    $Content = $Content -replace '/\*[\s\S]*?\*/', ''
    # Remove trailing commas before } or ]
    $Content = $Content -replace ',(\s*[}\]])', '$1'
    return $Content | ConvertFrom-Json
}

# Load config.json for DUT paths (supports comments)
$configPath = Join-Path $repoRoot "config.json"
$config = Get-Content $configPath -Raw | ConvertFrom-Json5

# Destination paths
$zwaveStorage = Join-Path $repoRoot "zwave_stack\storage"
$dutStorageDir = Join-Path $repoRoot $config.dut.storageDir
$dutStorageArchiveName = "dut-storage"

Write-Host "Extracting network state archive..." -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $archiveFile)) {
    Write-Host "ERROR: Archive not found: $archiveFile" -ForegroundColor Red
    exit 1
}

# Clean up any existing temp directory
if (Test-Path $tempDir) {
    Remove-Item -Recurse -Force $tempDir
}

# Extract archive
Write-Host "Extracting $archiveFile..." -ForegroundColor Green
Expand-Archive -Path $archiveFile -DestinationPath $tempDir -Force

# Copy storage -> zwave_stack/storage
$sourceStorage = Join-Path $tempDir "storage"
if (Test-Path $sourceStorage) {
    Write-Host "Copying storage -> zwave_stack/storage/" -ForegroundColor Green
    if (Test-Path $zwaveStorage) {
        Remove-Item -Recurse -Force $zwaveStorage
    }
    Copy-Item -Recurse $sourceStorage $zwaveStorage
} else {
    Write-Host "WARNING: storage/ not found in archive" -ForegroundColor Yellow
}

# Copy DUT storage files to storageDir
$sourceDutStorage = Join-Path $tempDir $dutStorageArchiveName
if (Test-Path $sourceDutStorage) {
    Write-Host "Copying $dutStorageArchiveName -> $($config.dut.storageDir)" -ForegroundColor Green
    # Create destination directory if it doesn't exist
    if (-not (Test-Path $dutStorageDir)) {
        New-Item -ItemType Directory -Path $dutStorageDir -Force | Out-Null
    }
    # Copy individual files (not the folder itself)
    Get-ChildItem $sourceDutStorage | ForEach-Object {
        Write-Host "  Copying $($_.Name)" -ForegroundColor Gray
        Copy-Item $_.FullName $dutStorageDir -Force
    }
} else {
    Write-Host "WARNING: $dutStorageArchiveName/ not found in archive" -ForegroundColor Yellow
}

# Clean up temp directory
Remove-Item -Recurse -Force $tempDir

Write-Host ""
Write-Host "Network state files extracted successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Extracted to:" -ForegroundColor Cyan
Write-Host "  - $zwaveStorage" -ForegroundColor White
Write-Host "  - $dutStorageDir" -ForegroundColor White

# Debug: Print directory structures
Write-Host ""
Write-Host "=== Debug: Directory Structures ===" -ForegroundColor Magenta
Write-Host ""
Write-Host "zwave_stack/storage:" -ForegroundColor Yellow
if (Test-Path $zwaveStorage) {
    Get-ChildItem $zwaveStorage -Recurse | ForEach-Object {
        Write-Host "  $($_.FullName.Replace($repoRoot, '.'))" -ForegroundColor Gray
    }
} else {
    Write-Host "  (directory not found)" -ForegroundColor Red
}
Write-Host ""
Write-Host "DUT storage ($($config.dut.storageDir)):" -ForegroundColor Yellow
if (Test-Path $dutStorageDir) {
    Get-ChildItem $dutStorageDir -Recurse | ForEach-Object {
        Write-Host "  $($_.FullName.Replace($repoRoot, '.'))" -ForegroundColor Gray
    }
} else {
    Write-Host "  (directory not found)" -ForegroundColor Red
}
