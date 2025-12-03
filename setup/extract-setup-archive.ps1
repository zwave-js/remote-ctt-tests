<#
.SYNOPSIS
    Extracts the CTT setup archive on CI before running tests.

.DESCRIPTION
    This script extracts setup/setup.zip and places files in the correct locations:
    - storage/ -> zwave_stack/storage/
    - zwave-js-storage/ -> zwave-js/storage/
    - appdata/ -> %APPDATA%/Z-Wave Alliance/Z-Wave CTT 3/
    - keys/ -> %USERPROFILE%/Documents/Z-Wave Alliance/Z-Wave CTT 3/Keys/

.EXAMPLE
    .\extract-setup-archive.ps1
#>

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$archiveFile = Join-Path $repoRoot "setup\setup.zip"
$tempDir = Join-Path $env:TEMP "ctt-setup-extract"

# Destination paths
$zwaveStorage = Join-Path $repoRoot "zwave_stack\storage"
$zwaveJsStorage = Join-Path $repoRoot "zwave-js\storage"
$cttAppData = "$env:APPDATA\Z-Wave Alliance\Z-Wave CTT 3"
$cttKeys = "$env:USERPROFILE\Documents\Z-Wave Alliance\Z-Wave CTT 3\Keys"

Write-Host "Extracting CTT setup archive..." -ForegroundColor Cyan
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

# Copy zwave-js-storage -> zwave-js/storage
$sourceJsStorage = Join-Path $tempDir "zwave-js-storage"
if (Test-Path $sourceJsStorage) {
    Write-Host "Copying zwave-js-storage -> zwave-js/storage/" -ForegroundColor Green
    if (Test-Path $zwaveJsStorage) {
        Remove-Item -Recurse -Force $zwaveJsStorage
    }
    Copy-Item -Recurse $sourceJsStorage $zwaveJsStorage
} else {
    Write-Host "WARNING: zwave-js-storage/ not found in archive" -ForegroundColor Yellow
}

# Copy appdata -> CTT AppData location
$sourceAppData = Join-Path $tempDir "appdata"
if (Test-Path $sourceAppData) {
    Write-Host "Copying appdata -> $cttAppData" -ForegroundColor Green
    # Create parent directories if needed
    $parentDir = Split-Path -Parent $cttAppData
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    if (Test-Path $cttAppData) {
        Remove-Item -Recurse -Force $cttAppData
    }
    Copy-Item -Recurse $sourceAppData $cttAppData
} else {
    Write-Host "WARNING: appdata/ not found in archive" -ForegroundColor Yellow
}

# Copy keys -> CTT Keys location
$sourceKeys = Join-Path $tempDir "keys"
if (Test-Path $sourceKeys) {
    Write-Host "Copying keys -> $cttKeys" -ForegroundColor Green
    # Create parent directories if needed
    $parentDir = Split-Path -Parent $cttKeys
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    if (Test-Path $cttKeys) {
        Remove-Item -Recurse -Force $cttKeys
    }
    Copy-Item -Recurse $sourceKeys $cttKeys
} else {
    Write-Host "WARNING: keys/ not found in archive" -ForegroundColor Yellow
}

# Clean up temp directory
Remove-Item -Recurse -Force $tempDir

Write-Host ""
Write-Host "Setup files extracted successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Extracted to:" -ForegroundColor Cyan
Write-Host "  - $zwaveStorage" -ForegroundColor White
Write-Host "  - $zwaveJsStorage" -ForegroundColor White
Write-Host "  - $cttAppData" -ForegroundColor White
Write-Host "  - $cttKeys" -ForegroundColor White
