$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Sdcc = Join-Path $Root "compilers\sdcc\bin\sdcc.exe"
$PackIhx = Join-Path $Root "compilers\sdcc\bin\packihx.exe"
$Build = Join-Path $PSScriptRoot "build"
$Source = Join-Path $PSScriptRoot "panel_demo.c"
$Base = Join-Path $Build "panel_demo"

New-Item -ItemType Directory -Force -Path $Build | Out-Null

& $Sdcc `
    -mmcs51 `
    --model-small `
    --out-fmt-ihx `
    --code-loc 0x0000 `
    --code-size 0x8000 `
    --iram-size 0x80 `
    --stack-size 0x20 `
    --std-sdcc11 `
    --opt-code-size `
    -o "$Base.ihx" `
    $Source

$Hex = Join-Path $Build "PANEL_DEMO.HEX"
& $PackIhx "$Base.ihx" | Set-Content -Encoding ascii -Path $Hex
$StandaloneHex = Join-Path $Build "STANDALONE_KEYCODE_DISPLAY.HEX"

function ConvertFrom-IHex {
    param([string[]]$Lines)

    $mem = @{}
    foreach ($line in $Lines) {
        if (-not $line.StartsWith(":")) { continue }
        $count = [Convert]::ToInt32($line.Substring(1, 2), 16)
        $addr = [Convert]::ToInt32($line.Substring(3, 4), 16)
        $type = [Convert]::ToInt32($line.Substring(7, 2), 16)
        if ($type -ne 0) { continue }
        for ($i = 0; $i -lt $count; $i++) {
            $b = [Convert]::ToInt32($line.Substring(9 + $i * 2, 2), 16)
            $mem[$addr + $i] = $b
        }
    }
    return $mem
}

function New-IHexRecord {
    param([int]$Address, [int[]]$Data)

    $sum = $Data.Count + (($Address -shr 8) -band 0xff) + ($Address -band 0xff)
    $body = ":{0:X2}{1:X4}00" -f $Data.Count, $Address
    foreach ($b in $Data) {
        $sum += $b
        $body += "{0:X2}" -f ($b -band 0xff)
    }
    $checksum = ((-$sum) -band 0xff)
    return $body + ("{0:X2}" -f $checksum)
}

function ConvertTo-IHex {
    param($Mem)

    $records = New-Object System.Collections.Generic.List[string]
    $addresses = @($Mem.Keys | Sort-Object)
    $i = 0
    while ($i -lt $addresses.Count) {
        $addr = [int]$addresses[$i]
        $data = New-Object System.Collections.Generic.List[int]
        while (
            $i -lt $addresses.Count -and
            [int]$addresses[$i] -eq ($addr + $data.Count) -and
            $data.Count -lt 16
        ) {
            $data.Add([int]$Mem[[int]$addresses[$i]])
            $i++
        }
        $records.Add((New-IHexRecord -Address $addr -Data $data.ToArray()))
    }
    $records.Add(":00000001FF")
    return $records
}

$mem = ConvertFrom-IHex -Lines (Get-Content $Hex)

# The original EPROM has a self-loop at 0000h, while useful startup code begins
# at 0026h. Some board/internal-ROM boot path may jump into external memory at
# 0026h, so mirror our reset jump there as a diagnostic entry.
$mem[0x0026] = 0x02
$mem[0x0027] = 0x00
$mem[0x0028] = 0x4C

ConvertTo-IHex -Mem $mem | Set-Content -Encoding ascii -Path $Hex
Copy-Item $Hex $StandaloneHex -Force

Write-Host "Built: demo_panel\build\PANEL_DEMO.HEX"
Write-Host "Built: demo_panel\build\STANDALONE_KEYCODE_DISPLAY.HEX"
