<#
.SYNOPSIS
    Creates an archive containing CTT installation files for CI.

.DESCRIPTION
    This script packages the following into setup/ctt-setup.zip:
    - CTT AppData folder -> appdata/
    - CTT Keys file (homeId-specific) -> keys/
    - CTT binaries (from CTT_PATH or default location) -> ctt-bin/

.EXAMPLE
    .\pack-ctt-archive.ps1

.NOTES
    Set CTT_PATH environment variable to override the default CTT installation path.
    Default: C:\Program Files (x86)\Z-Wave Alliance\Z-Wave CTT 3
#>

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$tempDir = Join-Path $env:TEMP "ctt-archive-staging"
$outputFile = Join-Path $repoRoot "setup\ctt-setup.zip"

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

# Load config.json for homeId (supports comments)
$configPath = Join-Path $repoRoot "config.json"
$config = Get-Content $configPath -Raw | ConvertFrom-Json5

# DUT configuration (for homeId-specific keys)
$homeId = $config.dut.homeId
$homeIdUpper = $homeId.ToUpper()

# Source paths
$cttAppData = "C:\Users\$env:USERNAME\AppData\Roaming\Z-Wave Alliance\Z-Wave CTT 3"
$cttKeys = "C:\Users\$env:USERNAME\Documents\Z-Wave Alliance\Z-Wave CTT 3\Keys"
$cttPath = if ($env:CTT_PATH) { $env:CTT_PATH } else { "C:\Program Files (x86)\Z-Wave Alliance\Z-Wave CTT 3" }

Write-Host "Creating CTT setup archive..." -ForegroundColor Cyan

# Clean up any existing temp directory
if (Test-Path $tempDir) {
    Remove-Item -Recurse -Force $tempDir
}

# Create staging directory
New-Item -ItemType Directory -Path $tempDir | Out-Null

# Copy CTT AppData
if (Test-Path $cttAppData) {
    Write-Host "  Copying CTT AppData..." -ForegroundColor Green
    Copy-Item -Recurse $cttAppData (Join-Path $tempDir "appdata")
} else {
    Write-Host "  WARNING: CTT AppData not found at $cttAppData" -ForegroundColor Yellow
}

# Copy CTT Keys - only the homeId-specific key file
$keysStagingDir = Join-Path $tempDir "keys"
New-Item -ItemType Directory -Path $keysStagingDir | Out-Null

if (Test-Path $cttKeys) {
    $keyFile = Join-Path $cttKeys "$homeIdUpper.txt"
    if (Test-Path $keyFile) {
        Write-Host "  Copying CTT Keys ($homeIdUpper.txt)..." -ForegroundColor Green
        Copy-Item $keyFile $keysStagingDir
    } else {
        Write-Host "  WARNING: Key file not found at $keyFile" -ForegroundColor Yellow
    }
} else {
    Write-Host "  WARNING: CTT Keys directory not found at $cttKeys" -ForegroundColor Yellow
}

# Copy CTT binaries
if (Test-Path $cttPath) {
    Write-Host "  Copying CTT binaries from $cttPath..." -ForegroundColor Green
    Copy-Item -Recurse $cttPath (Join-Path $tempDir "ctt-bin")
} else {
    Write-Host "  WARNING: CTT installation not found at $cttPath" -ForegroundColor Yellow
}

# Remove old archive if it exists
if (Test-Path $outputFile) {
    Remove-Item $outputFile
}

# Create the zip archive using tar.exe (much faster than Compress-Archive)
Write-Host "  Compressing archive..." -ForegroundColor Green
& "$env:SystemRoot\System32\tar.exe" -a -cf $outputFile -C $tempDir *

# Clean up temp directory
Remove-Item -Recurse -Force $tempDir

Write-Host ""
Write-Host "Created $outputFile" -ForegroundColor Green
