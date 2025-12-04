<#
.SYNOPSIS
    Creates an archive containing Z-Wave network state for CI.

.DESCRIPTION
    This script packages the following into setup/network-state.zip:
    - zwave_stack/storage/ -> storage/
    - DUT storage files (from config.json glob patterns) -> dut-storage/

.EXAMPLE
    .\pack-network-state-archive.ps1
#>

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$tempDir = Join-Path $env:TEMP "network-state-staging"
$outputFile = Join-Path $repoRoot "setup\network-state.zip"

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

# DUT configuration
$homeId = $config.dut.homeId
$homeIdLower = $homeId.ToLower()
$homeIdUpper = $homeId.ToUpper()
$dutStorageDir = Join-Path $repoRoot $config.dut.storageDir
$dutStorageArchiveName = "dut-storage"

# Source paths
$zwaveStorage = Join-Path $repoRoot "zwave_stack\storage"

Write-Host "Creating network state archive..." -ForegroundColor Cyan

# Clean up any existing temp directory
if (Test-Path $tempDir) {
    Remove-Item -Recurse -Force $tempDir
}

# Create staging directory
New-Item -ItemType Directory -Path $tempDir | Out-Null

# Copy zwave_stack/storage
if (Test-Path $zwaveStorage) {
    Write-Host "  Copying zwave_stack/storage..." -ForegroundColor Green
    Copy-Item -Recurse $zwaveStorage (Join-Path $tempDir "storage")
} else {
    Write-Host "  WARNING: zwave_stack/storage not found at $zwaveStorage" -ForegroundColor Yellow
}

# Copy DUT storage files using glob patterns from config
$dutStagingDir = Join-Path $tempDir $dutStorageArchiveName
New-Item -ItemType Directory -Path $dutStagingDir | Out-Null

if (Test-Path $dutStorageDir) {
    Write-Host "  Copying DUT storage files..." -ForegroundColor Green
    foreach ($pattern in $config.dut.storageFileFilter) {
        # Replace placeholders
        $resolvedPattern = $pattern -replace '%HOME_ID_LOWER%', $homeIdLower
        $resolvedPattern = $resolvedPattern -replace '%HOME_ID_UPPER%', $homeIdUpper

        $fullPattern = Join-Path $dutStorageDir $resolvedPattern
        $matchedFiles = Get-Item -Path $fullPattern -ErrorAction SilentlyContinue

        foreach ($file in $matchedFiles) {
            Write-Host "    $($file.Name)" -ForegroundColor Gray
            Copy-Item $file.FullName $dutStagingDir
        }
    }
} else {
    Write-Host "  WARNING: DUT storage directory not found at $dutStorageDir" -ForegroundColor Yellow
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
