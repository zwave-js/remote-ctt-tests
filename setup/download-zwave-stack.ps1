<#
.SYNOPSIS
    Downloads the latest Z-Wave stack binaries from GitHub.

.DESCRIPTION
    This script downloads the latest Z-Wave stack release from the
    Z-Wave-Alliance/z-wave-stack-binaries repository and extracts
    the required ELF binaries to zwave_stack/bin/.

.EXAMPLE
    .\download-zwave-stack.ps1
#>

$ErrorActionPreference = "Stop"

$REPO = "Z-Wave-Alliance/z-wave-stack-binaries"
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$OUTPUT_DIR = Join-Path $repoRoot "zwave_stack\bin"

$BINARIES = @(
    @{
        Pattern = "^ZW_zwave_ncp_serial_api_controller_.*_REALTIME_DEBUG\.elf$"
        Output  = "ZW_zwave_ncp_serial_api_controller.elf"
    },
    @{
        Pattern = "^ZW_zwave_ncp_serial_api_end_device_.*_REALTIME_DEBUG\.elf$"
        Output  = "ZW_zwave_ncp_serial_api_end_device.elf"
    }
)

$tempDir = Join-Path $env:TEMP "zwave-stack-$(Get-Random)"

try {
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    Write-Host "Downloading latest Z-Wave stack binaries..." -ForegroundColor Cyan
    & gh release download --repo $REPO --pattern "*Linux.tar.gz" -D $tempDir
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to download release"
    }

    $tarball = Get-ChildItem -Path $tempDir -Filter "*.tar.gz" | Select-Object -First 1
    if (-not $tarball) {
        throw "No tarball found in downloaded files"
    }

    Write-Host "Extracting $($tarball.Name)..." -ForegroundColor Cyan
    Push-Location $tempDir
    try {
        & "$env:SystemRoot\System32\tar.exe" -xzf $tarball.Name
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to extract tarball"
        }
    }
    finally {
        Pop-Location
    }

    $binDir = Join-Path $tempDir "bin"
    $files = Get-ChildItem -Path $binDir -File

    foreach ($binary in $BINARIES) {
        $match = $files | Where-Object { $_.Name -match $binary.Pattern } | Select-Object -First 1
        if (-not $match) {
            throw "No file matching $($binary.Pattern) found"
        }

        $dest = Join-Path $OUTPUT_DIR $binary.Output
        Write-Host "Copying $($match.Name) -> $($binary.Output)" -ForegroundColor Cyan
        Copy-Item $match.FullName $dest
    }

    Write-Host "Done!" -ForegroundColor Green
}
finally {
    if (Test-Path $tempDir) {
        Remove-Item -Recurse -Force $tempDir
    }
}
