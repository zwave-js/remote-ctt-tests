<#
.SYNOPSIS
    Creates a setup archive containing all files needed for CTT tests on CI.

.DESCRIPTION
    This script packages the following into setup/setup.zip:
    - zwave_stack/storage/ -> storage/
    - DUT storage files (from config.json glob patterns) -> dut-storage/
    - CTT AppData folder -> appdata/
    - CTT Keys file (homeId-specific) -> keys/

.EXAMPLE
    .\create-setup-archive.ps1
#>

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$tempDir = Join-Path $env:TEMP "ctt-setup-staging"
$outputFile = Join-Path $repoRoot "setup\setup.zip"

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
$cttAppData = "C:\Users\$env:USERNAME\AppData\Roaming\Z-Wave Alliance\Z-Wave CTT 3"
$cttKeys = "C:\Users\$env:USERNAME\Documents\Z-Wave Alliance\Z-Wave CTT 3\Keys"

Write-Host "Creating setup archive..." -ForegroundColor Cyan

# Clean up any existing temp directory
if (Test-Path $tempDir) {
    Remove-Item -Recurse -Force $tempDir
}

# Create staging directory
New-Item -ItemType Directory -Path $tempDir | Out-Null

# Copy zwave_stack/storage
if (Test-Path $zwaveStorage) {
    Copy-Item -Recurse $zwaveStorage (Join-Path $tempDir "storage")
}

# Copy DUT storage files using glob patterns from config
$dutStagingDir = Join-Path $tempDir $dutStorageArchiveName
New-Item -ItemType Directory -Path $dutStagingDir | Out-Null

if (Test-Path $dutStorageDir) {
    foreach ($pattern in $config.dut.storageFileFilter) {
        # Replace placeholders
        $resolvedPattern = $pattern -replace '%HOME_ID_LOWER%', $homeIdLower
        $resolvedPattern = $resolvedPattern -replace '%HOME_ID_UPPER%', $homeIdUpper

        $fullPattern = Join-Path $dutStorageDir $resolvedPattern
        $matchedFiles = Get-Item -Path $fullPattern -ErrorAction SilentlyContinue

        foreach ($file in $matchedFiles) {
            Copy-Item $file.FullName $dutStagingDir
        }
    }
}

# Copy CTT AppData
if (Test-Path $cttAppData) {
    Copy-Item -Recurse $cttAppData (Join-Path $tempDir "appdata")
}

# Copy CTT Keys - only the homeId-specific key file
$keysStagingDir = Join-Path $tempDir "keys"
New-Item -ItemType Directory -Path $keysStagingDir | Out-Null

if (Test-Path $cttKeys) {
    $keyFile = Join-Path $cttKeys "$homeIdUpper.txt"
    if (Test-Path $keyFile) {
        Copy-Item $keyFile $keysStagingDir
    }
}

# Remove old archive if it exists
if (Test-Path $outputFile) {
    Remove-Item $outputFile
}

# Create the zip archive using tar.exe (much faster than Compress-Archive)
& "$env:SystemRoot\System32\tar.exe" -a -cf $outputFile -C $tempDir *

# Clean up temp directory
Remove-Item -Recurse -Force $tempDir

Write-Host "Created $outputFile" -ForegroundColor Green
