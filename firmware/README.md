# Alcatel 3558 replacement firmware

This directory is the new home for the standalone C firmware.

## Layout

```text
firmware/
  current/
    alcatel3558_firmware.c
  versions/
    v0_c_demo3_panel_keycode/
      alcatel3558_firmware.c
      ALCATEL3558_C_DEMO3_WORKING.HEX
  build/
    ALCATEL3558_CURRENT.HEX
  build_current.py
```

## Current baseline

`current/alcatel3558_firmware.c` is now the main working firmware base. It is
based on the confirmed standalone C bring-up code, but adds direct frequency
entry and MC145156 PLL programming for the inspected radio.

Current controls:

- startup banner: `ATR421`;
- default frequency: `144.0000 MHz`;
- digit keys: enter seven frequency digits, for example `1455750`;
- `*` / `#`: step down/up by 12.5 kHz;
- RX audio is enabled on the selected frequency;
- `BELL` follows carrier detect (`DP`);
- `APPEL` / PTT: switch to TX state on the current frequency;
- PTT/APPEL release: return to RX state;
- `ON/OFF`: use the existing shutdown path.

The matching build output is:

```text
firmware/build/ALCATEL3558_CURRENT.HEX
```

`versions/v0_c_demo3_panel_keycode` is the first confirmed standalone C
baseline and is kept for reference:

- boots without merging or patching the original firmware;
- shows `C DEMO3`;
- initializes the panel/display/key path from C;
- receives key codes from the panel UART;
- shows `KEY xx`.

Keep this version unchanged. New work should happen in:

```text
firmware/current/alcatel3558_firmware.c
```

`versions/atrv5e_frequency_core` is not the current base. That branch was an
experimental ATRV5E-derived port; on the tested station its HEX builds did not
boot reliably. Keep it only as historical reference unless the hardware reason
is found and fixed.

## Hardware scope / do not generalize blindly

The RF/PLL constants below are confirmed on the inspected board only. Before
reusing this firmware on another ATR42x/Alcatel 3558 unit, check the actual PLL
and prescaler chips on the RF board.

Confirmed inspected-board parts:

- PLL synthesizer: Motorola `MC145156P2`;
- prescaler: Motorola `MC12016`;
- dual-modulus ratio: `40/41`;
- PLL reference/channel step: 12.5 kHz.

Several early test firmwares assumed a `64/65` prescaler. That assumption is
wrong for this station and gives wrong frequencies.

## Hardware Watchdog

The external reset watchdog is confirmed on hardware. If firmware does not
service it, 8031 `RESET` pin 9 receives a high pulse about every 1.7 seconds.

The reset-prevention behavior was first observed as a required periodic change
on:

```text
8031 pin 1 = P1.0
```

Schematic tracing later clarified that `P1.0` is also the chip-select selector
for two 8243 I/O expanders:

- `MN13` 8243 has CS driven directly from `P1.0`.
- `MN14` 8243 has CS driven from `P1.0` through an inverter.

So `P1.0` should be treated as an 8243 bank-select line. Periodically touching
it prevents reset in the current standalone firmware, but future RF/PLL code
must avoid random toggles during 8243 transactions.

The current firmware base implements this as `hardware_watchdog_service()` and
calls it periodically from `timer0_isr()`. The Timer0 watchdog support is
started after `original_startup_init_clone()` by `hardware_watchdog_start()`.

The original firmware also toggles `P3.2` from Timer0; this is preserved as a
secondary periodic signal, but `P1.0` is the reset-prevention signal confirmed
by scope and hardware test.

## Power Off

Panel key code `60h` is the `ON/OFF` key. The current firmware base handles it
through `radio_power_off()`.

The handler follows the original `L56D8` path by writing:

```text
XDATA 2257h = 0Bh
```

and then sends the currently known panel shutdown/control byte sequence before
waiting for power-off.

## Build

From the project root:

```powershell
python .\firmware\build_current.py
```

Output:

```text
firmware/build/ALCATEL3558_CURRENT.HEX
```

## Confirmed PLL facts

The inspected RF board uses:

- `MC145156P2` PLL synthesizer;
- `MC12016` dual-modulus prescaler, so `P/P+1 = 40/41`;
- 12.5 kHz PLL reference/step.

Manual PLL calculation:

```text
Ntotal = N * 40 + A
PLL frequency = Ntotal * 12.5 kHz
```

Example:

```text
144.000 MHz -> Ntotal 11520 -> N=288, A=0
```

The MC145156 word order is:

```text
SW1, SW2, N9..N0, A6..A0
```

`SW1` is MC145156 pin 14 and has been traced to `CER`
(`Commande Emission/Reception`), the RF/antenna switching command into the TX
module. The MC145156 switch outputs are open-drain, so `SW1=1` releases CER to
its external pull-up and `SW1=0` pulls it low. `SW2` is not connected on the
inspected board. Use `SW1=0, SW2=0` for RX and `SW1=1, SW2=0` for TX.

`CER` alone is not proven to enable full transmitter output power. It opens
the antenna/RF switching chain and several transistor stages, but high-power TX
and modulation still appear to need additional original-firmware conditions or
analog path setup.

## Confirmed RX path

RX is confirmed working on the inspected station with the current firmware.
The relevant hardware controls are:

```text
PLL RX word: SW1=0, SW2=0
MN13 Port6: 0xC  ; BBF1 + BBF2, open RX audio gates
MN13 Port5: 0x8  ; working speaker-volume setting
```

The firmware reads carrier detect from `MN13` Port7 bit 3 (`DP`) three times
and uses a majority vote before updating the front panel. In the current base:

```text
BELL on  = DP/carrier present
BELL off = no carrier detected
```

When entering TX the firmware closes the RX audio gates and sends panel
`SPEAKER off`; when returning to RX it reprograms the RX PLL word, opens
`BBF1/BBF2`, restores the speaker-volume setting, sends `SPEAKER on`, and
marks `ANT green`.

## Test Builds

Panel control-code scanner:

```powershell
python .\firmware\build_panel_code_scan.py
```

PLL digit probe:

```powershell
python .\firmware\build_pll_digit_probe.py
```

Output:

```text
firmware/build/PLL_DIGIT_PROBE.HEX
```

Behavior:

- boots with the normal standalone C initialization;
- shows `PLL DIG`;
- keys `0..9` show `PLL n`;
- every new digit key sends the current PLL candidate sequence: original
  `L4FD9`-style 8243 pre-load writes, serial data on `P3.3`, clock pulses by
  `MOVX @R0,A` on `P3.6`/`/WR`, then original post-load candidate writes.

Output:

```text
firmware/build/PANEL_CODE_SCAN_00_7F.HEX
```

Behavior:

- runs the same standalone C initialization as the confirmed `C DEMO3` build;
- shows `CTRL5E` at boot;
- scans only panel control-code candidates seen in the original firmware:
  `5E, 60..6A, 6C..70`;
- key `1` sends the current raw panel code, then moves to the previous
  candidate;
- key `2` sends the current raw panel code, then moves to the next candidate;
- key `*` shows the current code as `CODExx`;
- key `#` starts automatic scan through the candidate list at about one code
  per second;
- any other non-idle key stops automatic scan.

Use this to find panel LED/control codes. In manual mode the display is only
redrawn by `*`, so LED changes should mostly correlate with the byte sent by
`1` or `2`.

Confirmed panel LED/control codes:

| Code | Action |
| ---: | --- |
| `60h` | `ANT` off |
| `61h` | `ANT` orange on |
| `62h` | `SPEAKER` off |
| `63h` | `SPEAKER` on |
| `64h` | `KEY` off |
| `65h` | `KEY` on |
| `66h` | `BELL` off |
| `67h` | `BELL` on |
| `68h` | `ANT` orange on, alternate code |
| `69h` | `ANT` green on |

Note: `60h` is also the incoming panel key code for the physical `ON/OFF` key.
In the CPU-to-panel direction, `60h` is the confirmed `ANT` off command.

The earlier full `00h..7Fh` scan was too broad: codes such as `00h` can be
interpreted by the panel as display/state commands and may restore or blink the
last full-screen frame.

RF latch probe:

```powershell
python .\firmware\build_rf_latch_probe.py
```

Output:

```text
firmware/build/RF_LATCH_PROBE.HEX
```

Behavior:

- runs the same standalone C initialization as the confirmed `C DEMO3` build;
- shows `RFPROBE`, then `1RX 2TX`;
- key `1` sends RX/receive latch candidates from `L5937/L5948` and marks
  `ANT green`;
- key `2` sends TX/transmit latch candidates from `L5964` and `L4DE5..L4E0E`,
  then marks `ANT orange`;
- key `*` sends the current RF-off/stop candidate and marks `ANT off`;
- key `#` shows the help text again.

Use the TX candidate only with appropriate RF safety precautions; it is meant
for probing and may affect the real transmit path.

## Version rule

When a HEX is confirmed on hardware, copy the current source and HEX into a new
directory under `firmware/versions/`, for example:

```text
firmware/versions/v1_pll_capture_probe/
```

Use short names that describe the first confirmed capability.
