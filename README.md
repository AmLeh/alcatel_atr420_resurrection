![illustration](https://github.com/AmLeh/alcatel_atr420_resurrection/blob/main/photo1.jpg)

# Alcatel ATR420 Resurrection

Reverse engineering notes, tooling, and replacement firmware experiments for
an Alcatel ATR420 radiotelephone.

External ATR42x reverse-engineering reference:
<https://blog.shibby.fr/2017/10/alcatel-atr42x-la-resurrection/>.

The project goal is to understand how the original 8031/MCS-51 firmware
controls the front panel, PLL synthesizer, RF path, and power/control logic, and
to gradually build a clean replacement firmware.

## Current Status

Working standalone C firmware has been built and tested on real hardware:

- boots from the external 27256 program memory;
- initializes the front-panel controller;
- writes text to the VFD/LED display;
- receives keyboard codes from the panel;
- controls known panel LEDs;
- services the external reset/watchdog circuit;
- handles the physical `ON/OFF` key;
- has experimental PLL/RF probing firmware.

This is still a reverse-engineering and bring-up project. It is not yet a
complete replacement radio firmware.

## Target Hardware

Observed front-panel marking:

```text
ALCATEL RADIOTELEPHONE
Made in France
ATR 420
03/94
```

Main logic:

- main CPU: Intel/MCS-51 family `8031`;
- external program EPROM: `27256`;
- personalization/config EPROM: `2732`;
- I/O expanders: two `8243`;
- front-panel MCU: `IP-80C51643`;
- display/LED driver on the panel: National Semiconductor `COP370`;
- PLL synthesizer: Motorola `MC145156P2`.

## Major Findings

### Front Panel

The display, keyboard, and status LEDs are handled by a separate front-panel
MCU. The main 8031 talks to that panel controller rather than driving the
display directly.

Confirmed outgoing panel LED/control bytes:

| Code | Action |
| ---: | --- |
| `69h` | ANT green on |
| `61h`, `68h` | ANT orange on |
| `60h` | ANT off |
| `67h` | BELL on |
| `66h` | BELL off |
| `65h` | KEY on |
| `64h` | KEY off |
| `63h` | SPEAKER on |
| `62h` | SPEAKER off |

Confirmed keyboard codes are tracked in [`key_codes.txt`](key_codes.txt).

### Watchdog / 8243 Selection

8031 pin 1 (`P1.0`) has two roles:

- it selects one of two `8243` I/O expanders;
- it resets/services the external reset timer/watchdog circuit.

`MN13` receives `P1.0` directly. `MN14` receives the same signal through an
inverter. Firmware that writes to the `8243` expanders must therefore treat
`P1.0` as a shared bank-select/watchdog line, not as a disposable GPIO.

### PLL Programming

The PLL is a Motorola `MC145156P2`. Its programming lines are now mapped:

| MC145156P2 pin | Signal | Source |
| ---: | --- | --- |
| `11` | clock | 8031 pin `16`, `P3.6` / `/WR` |
| `12` | data | 8031 pin `13`, `P3.3` |
| `13` | enable/load | `MN13` 8243 pin `5`, `P43` |

The original firmware routine at `L50B3` sets or clears `P3.3` for data and
then uses `MOVX @R0,A` to generate a `/WR` pulse on `P3.6`, which clocks the
PLL.

See [`PLL_PROGRAMMING_PATH.md`](PLL_PROGRAMMING_PATH.md) for the detailed
call path and candidate C implementation strategy.

### RF / TX Control

Known `MN13` outputs:

- `MN13` pin `5` / `P43`: PLL enable/load;
- `MN13` Port4.0: `OPE`, RF power/amplifier enable;
- `MN13` Port4.2: `BLM`, microphone/audio-to-VCO gate;
- `MN13` Port4.3: `ENR`, PLL enable/load;
- `MN13` Port5.1..3: `BF1..BF3`, speaker-volume mux;
- `MN13` Port6.1..3: `BBF3/BBF2/BBF1`, audio routing gates;
- `MN13` Port7.0: `STN_V`, PLL lock status;
- `MN13` Port7.1: `ALT_T`, active-low PTT/accessory TX request;
- `MN13` Port7.3: `DP`, carrier detect.

RX/TX state candidates are tracked in
[`RF_RX_TX_PATHS.md`](RF_RX_TX_PATHS.md).

## Repository Layout

```text
firmware/
  current/                 Current standalone C firmware base
  tests/                   Hardware test firmwares
  versions/                Known working snapshots
  build_*.py               SDCC build wrappers

demo_panel/                Earlier panel bring-up experiments
schema/                    Local schematic workspace and crops, if available

*.py                       Firmware-analysis helper scripts
*.md                       Reverse-engineering notes
*.csv                      Extracted call graphs, event tables, latch tables
```

Important documents:

- [`HARDWARE_RE.md`](HARDWARE_RE.md) - hardware reverse-engineering notes;
- [`SCHEMA_ANALYSIS.md`](SCHEMA_ANALYSIS.md) - schematic-derived findings;
- [`LOGIC_BOARD_FINDINGS.md`](LOGIC_BOARD_FINDINGS.md) - distilled findings
  from Shibby's public ATR42x logic-board notes;
- [`PLL_PROGRAMMING_PATH.md`](PLL_PROGRAMMING_PATH.md) - PLL programming path;
- [`RF_PROBING_PLAN.md`](RF_PROBING_PLAN.md) - scope/logic-analyzer plan;
- [`RF_RX_TX_PATHS.md`](RF_RX_TX_PATHS.md) - RX/TX firmware paths;
- [`firmware/README.md`](firmware/README.md) - replacement firmware notes.

## Building Firmware

The build scripts expect SDCC for MCS-51. A local SDCC installation can be
placed under:

```text
compilers/sdcc/bin/sdcc.exe
compilers/sdcc/bin/packihx.exe
```

Build the current firmware:

```powershell
python .\firmware\build_current.py
```

Build the PLL digit probe:

```powershell
python .\firmware\build_pll_digit_probe.py
```

Build the panel LED/code scanner:

```powershell
python .\firmware\build_panel_code_scan.py
```

## Test Firmwares

| Firmware | Purpose |
| --- | --- |
| `firmware/current/alcatel3558_firmware.c` | Current replacement firmware base |
| `firmware/tests/panel_keys2.c` | Display persistent key codes |
| `firmware/tests/panel_code_scan.c` | Send panel command bytes and identify LEDs |
| `firmware/tests/rf_latch_probe.c` | Probe RF/RX/TX latch candidates |
| `firmware/tests/pll_digit_probe.c` | Send PLL candidate sequences from digit keys |

## Legal / Safety Notes

This repository is intended for research, restoration, repair, and
interoperability work on owned hardware.

Radio transmit experiments can be unsafe or illegal if performed on the air.
Use a dummy load, avoid transmitting on unauthorized frequencies, and observe
local radio regulations.

Original firmware dumps, vendor schematics, and compiler binaries may be
copyrighted or redistributable only under their own terms. The public
repository is structured to keep generated build outputs and local binary dumps
out of version control by default.

## How To Contribute

Useful contributions:

- confirm or correct pin mappings;
- add oscilloscope/logic-analyzer captures;
- decode MC145156 programming words;
- improve the 8243 driver abstraction;
- document panel protocol bytes;
- test replacement firmware builds on real hardware.

Please keep safety notes with any RF/TX experiments.
