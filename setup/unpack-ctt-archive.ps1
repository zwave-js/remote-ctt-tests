<#
.SYNOPSIS
    Extracts the CTT setup archive on CI before running tests.

.DESCRIPTION
    This script extracts setup/ctt-setup.zip and places files in the correct locations:
    - appdata/ -> %APPDATA%/Z-Wave Alliance/Z-Wave CTT 3/
    - ctt-bin/ -> C:\Program Files (x86)\Z-Wave Alliance\Z-Wave CTT 3/

    Keys are copied from ctt/keys/ (stored in repository, not in archive).

    It also updates ctt/project/Config/ZatsSettings.json to point to the correct keys directory.

.EXAMPLE
    .\unpack-ctt-archive.ps1
#>

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$archiveFile = Join-Path $repoRoot "setup\ctt-setup.zip"
$tempDir = Join-Path $env:TEMP "ctt-archive-extract"

# Destination paths
$cttAppData = "$env:APPDATA\Z-Wave Alliance\Z-Wave CTT 3"
$cttKeys = "$env:USERPROFILE\Documents\Z-Wave Alliance\Z-Wave CTT 3\Keys"
$cttPath = "C:\Program Files (x86)\Z-Wave Alliance\Z-Wave CTT 3"

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

# Copy keys from ctt/keys/ in repository (not from archive)
$sourceKeys = Join-Path $repoRoot "ctt\keys"
if (Test-Path $sourceKeys) {
    Write-Host "Copying keys from ctt/keys/ -> $cttKeys" -ForegroundColor Green
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
    Write-Host "WARNING: ctt/keys/ not found in repository" -ForegroundColor Yellow
}

# Copy ctt-bin -> CTT installation location
$sourceCttBin = Join-Path $tempDir "ctt-bin"
if (Test-Path $sourceCttBin) {
    Write-Host "Copying ctt-bin -> $cttPath" -ForegroundColor Green
    # Create parent directories if needed
    $parentDir = Split-Path -Parent $cttPath
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    if (Test-Path $cttPath) {
        Remove-Item -Recurse -Force $cttPath
    }
    Copy-Item -Recurse $sourceCttBin $cttPath
} else {
    Write-Host "WARNING: ctt-bin/ not found in archive" -ForegroundColor Yellow
}

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

# Update ZatsSettings.json with correct KeysStoragePath
if (Test-Path $zatsSettingsPath) {
    Write-Host "Updating ZatsSettings.json with KeysStoragePath..." -ForegroundColor Green
    $zatsSettings = Get-Content $zatsSettingsPath -Raw | ConvertFrom-Json5
    $zatsSettings.KeysStoragePath = $cttKeys
    $zatsSettings | ConvertTo-Json -Depth 10 | Set-Content $zatsSettingsPath -Encoding UTF8
    Write-Host "  KeysStoragePath set to: $cttKeys" -ForegroundColor Green
} else {
    Write-Host "WARNING: ZatsSettings.json not found at $zatsSettingsPath" -ForegroundColor Yellow
}

# Clean up temp directory
Remove-Item -Recurse -Force $tempDir

Write-Host ""
Write-Host "CTT setup files extracted successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Extracted to:" -ForegroundColor Cyan
Write-Host "  - $cttAppData" -ForegroundColor White
Write-Host "  - $cttKeys" -ForegroundColor White
Write-Host "  - $cttPath" -ForegroundColor White
