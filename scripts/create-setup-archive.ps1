<#
.SYNOPSIS
    Creates a setup archive containing all files needed for CTT tests on CI.

.DESCRIPTION
    This script packages the following into setup.zip:
    - zwave_stack/storage/ -> storage/
    - .zwave-js-cache/ -> zwave-js-cache/
    - CTT AppData folder -> appdata/
    - CTT Keys folder -> keys/

.EXAMPLE
    .\create-setup-archive.ps1
#>

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$tempDir = Join-Path $env:TEMP "ctt-setup-staging"
$outputFile = Join-Path $repoRoot "setup.zip"

# Source paths
$zwaveStorage = Join-Path $repoRoot "zwave_stack\storage"
$zwaveJsCache = Join-Path $repoRoot ".zwave-js-cache"
$cttAppData = "C:\Users\$env:USERNAME\AppData\Roaming\Z-Wave Alliance\Z-Wave CTT 3"
$cttKeys = "C:\Users\$env:USERNAME\Documents\Z-Wave Alliance\Z-Wave CTT 3\Keys"

Write-Host "Creating CTT setup archive..." -ForegroundColor Cyan
Write-Host ""

# Clean up any existing temp directory
if (Test-Path $tempDir) {
    Remove-Item -Recurse -Force $tempDir
}

# Create staging directory
New-Item -ItemType Directory -Path $tempDir | Out-Null

# Copy zwave_stack/storage
if (Test-Path $zwaveStorage) {
    Write-Host "Copying zwave_stack/storage -> storage/" -ForegroundColor Green
    Copy-Item -Recurse $zwaveStorage (Join-Path $tempDir "storage")
} else {
    Write-Host "WARNING: $zwaveStorage not found, skipping" -ForegroundColor Yellow
}

# Copy .zwave-js-cache
if (Test-Path $zwaveJsCache) {
    Write-Host "Copying .zwave-js-cache -> zwave-js-cache/" -ForegroundColor Green
    Copy-Item -Recurse $zwaveJsCache (Join-Path $tempDir "zwave-js-cache")
} else {
    Write-Host "WARNING: $zwaveJsCache not found, skipping" -ForegroundColor Yellow
}

# Copy CTT AppData
if (Test-Path $cttAppData) {
    Write-Host "Copying CTT AppData -> appdata/" -ForegroundColor Green
    Copy-Item -Recurse $cttAppData (Join-Path $tempDir "appdata")
} else {
    Write-Host "WARNING: $cttAppData not found, skipping" -ForegroundColor Yellow
}

# Copy CTT Keys
if (Test-Path $cttKeys) {
    Write-Host "Copying CTT Keys -> keys/" -ForegroundColor Green
    Copy-Item -Recurse $cttKeys (Join-Path $tempDir "keys")
} else {
    Write-Host "WARNING: $cttKeys not found, skipping" -ForegroundColor Yellow
}

# Remove old archive if it exists
if (Test-Path $outputFile) {
    Remove-Item $outputFile
}

# Create the zip archive
Write-Host ""
Write-Host "Creating $outputFile..." -ForegroundColor Cyan
Compress-Archive -Path "$tempDir\*" -DestinationPath $outputFile -CompressionLevel Optimal

# Clean up temp directory
Remove-Item -Recurse -Force $tempDir

Write-Host ""
Write-Host "Archive created successfully: $outputFile" -ForegroundColor Green

# Show archive contents
Write-Host ""
Write-Host "Archive contents:" -ForegroundColor Cyan
$shell = New-Object -ComObject Shell.Application
$zip = $shell.NameSpace($outputFile)
foreach ($item in $zip.Items()) {
    Write-Host "  - $($item.Name)/" -ForegroundColor White
}
