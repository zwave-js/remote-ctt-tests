<#
.SYNOPSIS
    Extracts the CTT setup archive on CI before running tests.

.DESCRIPTION
    This script extracts setup/setup.zip and places files in the correct locations:
    - storage/ -> zwave_stack/storage/
    - dut-storage/ -> DUT storage directory (from config.json)
    - appdata/ -> %APPDATA%/Z-Wave Alliance/Z-Wave CTT 3/
    - keys/ -> %USERPROFILE%/Documents/Z-Wave Alliance/Z-Wave CTT 3/Keys/

    It also updates ctt/project/Config/ZatsSettings.json to point to the correct keys directory.

.EXAMPLE
    .\extract-setup-archive.ps1
#>

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$archiveFile = Join-Path $repoRoot "setup\setup.zip"
$tempDir = Join-Path $env:TEMP "ctt-setup-extract"

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
$cttAppData = "$env:APPDATA\Z-Wave Alliance\Z-Wave CTT 3"
$cttKeys = "$env:USERPROFILE\Documents\Z-Wave Alliance\Z-Wave CTT 3\Keys"

# CTT settings file
$zatsSettingsPath = Join-Path $repoRoot "ctt\project\Config\ZatsSettings.json"

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
        Write-Host "  Copying $($_.Name)" -ForegroundColor Green
        Copy-Item $_.FullName $dutStorageDir -Force
    }
} else {
    Write-Host "WARNING: $dutStorageArchiveName/ not found in archive" -ForegroundColor Yellow
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

# Update ZatsSettings.json with correct KeysStoragePath
if (Test-Path $zatsSettingsPath) {
    Write-Host "Updating ZatsSettings.json with KeysStoragePath..." -ForegroundColor Green
    $zatsSettings = Get-Content $zatsSettingsPath -Raw | ConvertFrom-Json
    $zatsSettings.KeysStoragePath = $cttKeys
    $zatsSettings | ConvertTo-Json -Depth 10 | Set-Content $zatsSettingsPath -Encoding UTF8
    Write-Host "  KeysStoragePath set to: $cttKeys" -ForegroundColor Green
} else {
    Write-Host "WARNING: ZatsSettings.json not found at $zatsSettingsPath" -ForegroundColor Yellow
}

# Clean up temp directory
Remove-Item -Recurse -Force $tempDir

Write-Host ""
Write-Host "Setup files extracted successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Extracted to:" -ForegroundColor Cyan
Write-Host "  - $zwaveStorage" -ForegroundColor White
Write-Host "  - $dutStorageDir" -ForegroundColor White
Write-Host "  - $cttAppData" -ForegroundColor White
Write-Host "  - $cttKeys" -ForegroundColor White

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
