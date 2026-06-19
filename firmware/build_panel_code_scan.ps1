$ErrorActionPreference = "Stop"

if ($PSScriptRoot) {
    $Firmware = $PSScriptRoot
}
elseif ($MyInvocation.MyCommand.Path) {
    $Firmware = Split-Path -Parent $MyInvocation.MyCommand.Path
}
elseif (Test-Path ".\tests\panel_code_scan.c") {
    $Firmware = (Get-Location).Path
}
elseif (Test-Path ".\firmware\tests\panel_code_scan.c") {
    $Firmware = Join-Path (Get-Location).Path "firmware"
}
else {
    throw "Run this script from the project root or firmware directory."
}
$Root = Split-Path -Parent $Firmware
$Build = Join-Path $Firmware "build\panel_code_scan"
$Sdcc = Join-Path $Root "compilers\sdcc\bin\sdcc.exe"
$PackIhx = Join-Path $Root "compilers\sdcc\bin\packihx.exe"
$Source = Join-Path $Firmware "tests\panel_code_scan.c"
$Ihx = Join-Path $Build "panel_code_scan.ihx"
$OutHex = Join-Path $Firmware "build\PANEL_CODE_SCAN_00_7F.HEX"

if (!(Test-Path $Sdcc)) {
    throw "SDCC not found: $Sdcc"
}
if (!(Test-Path $PackIhx)) {
    throw "packihx not found: $PackIhx"
}
if (!(Test-Path $Source)) {
    throw "Source not found: $Source"
}

New-Item -ItemType Directory -Force -Path $Build | Out-Null
Remove-Item -Force -ErrorAction SilentlyContinue -Path $Ihx

Push-Location $Root
try {
    & $Sdcc `
        -mmcs51 `
        --model-small `
        --code-loc 0x0000 `
        --xram-loc 0x0000 `
        --iram-size 128 `
        --out-fmt-ihx `
        --std-sdcc11 `
        --opt-code-size `
        -I. `
        -o $Ihx `
        $Source
    if ($LASTEXITCODE -ne 0) {
        throw "SDCC failed with exit code $LASTEXITCODE"
    }
    if (!(Test-Path $Ihx)) {
        throw "SDCC did not create: $Ihx"
    }

    & $PackIhx $Ihx | Set-Content -Encoding ascii -Path $OutHex
    if ($LASTEXITCODE -ne 0) {
        throw "packihx failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

Write-Host "Built: $OutHex"
