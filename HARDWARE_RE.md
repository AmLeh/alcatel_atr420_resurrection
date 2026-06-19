# Reverse engineering notes for ST_M27256

Goal: identify hardware-control code paths and use them as a base for a clean replacement firmware.

Source files:

- `ST_M27256.HEX` - known-good original Intel HEX image from an unopened working station.
- `ST_M27256.bin` - 32 KiB binary image generated from the known-good HEX.
- `ST_M27256.asm` - first-pass 8051 disassembly of the known-good image.
- `ST_M27256_2.HEX` - older dump. It differs only at byte `0002h`: `00h` instead of `26h`, which breaks the reset vector.
- `disasm_8051.py` - local disassembler used for this pass.
- `ST_M2732A.HEX` - 4 KiB EPROM image, likely external data/config ROM.
- `ST_M2732A_ANALYSIS.md` - analysis notes for the 4 KiB EPROM.
- `ST_M27256_COMPARISON.md` - byte-level comparison of the two 32 KiB dumps.
- `RF_RX_TX_PATHS.md` - RX/TX state paths found from confirmed `ANT` LED panel commands.
- `RF_PROBING_PLAN.md` - oscilloscope/logic-analyzer plan for frequency, RX, and TX capture.
- `SCHEMA_ANALYSIS.md` - notes extracted from the full ATR421 schematic PNG.
- `schema/SchemaATR421_HD.png` - full electrical schematic image.

## Current map

## Known hardware notes

- Main CPU side: Intel MCS-51 / 8051-family code in external program memory.
- Board photos:
  - `1.jpg` - component side of the logic/RF boards.
  - `2.jpg` - solder side of the logic/RF boards.
  - `3.jpg` - close-up of the RF/PLL area; confirms the PLL marking.
  - `4.jpg` - close-up of the solder side under the RF/PLL area.
- Full schematic: `schema/SchemaATR421_HD.png`, labeled ATR421 family. The
  actual front-panel marking found on this station is ATR420, so treat the
  schematic as same-family until differences are proven.
- Main CPU visible on `1.jpg`: Philips/Intel `MAF 8031AH-2 12P`.
- Front-panel/product marking found later: `ALCATEL RADIOTELEPHONE`, `Made in France`, `ATR 420`, date `03/94`.
- External program/data memory is visible near the CPU: 32 KiB program EPROM plus a smaller EPROM/config ROM.
- A Philips `PC74HC373P` latch is visible near the EPROM/CPU area. This supports the hypothesis that the firmware writes decoded control states through an external latch/register network.
- `OKI M82C43` chips are visible near the CPU/crystal area. Treat these as likely external I/O expansion/peripheral devices until the board netlist is traced.
- Panel MCU: `IP-80C51643`.
- Panel MCU owns the keyboard, signal LEDs, and display subsystem.
- Display driver: National Semiconductor `COP370` VFD/LED display driver.
- Therefore the main CPU most likely does not drive the display driver directly. It exchanges commands/status/key events with the panel MCU, and the panel MCU drives the `COP370`.
- Confirmed CPU-to-panel LED/control commands:
  - `60h` - `ANT` off.
  - `61h` or `68h` - `ANT` orange on.
  - `69h` - `ANT` green on.
  - `67h` - `BELL` on.
  - `66h` - `BELL` off.
  - `65h` - `KEY` on.
  - `64h` - `KEY` off.
  - `63h` - `SPEAKER` on.
  - `62h` - `SPEAKER` off.
- Important direction note: incoming key code `60h` is the physical `ON/OFF` key, while outgoing panel command `60h` turns `ANT` off.
- Public documentation for the exact `IP-80C51643` marking is not readily identifiable; treat it as an 8051-family/custom-mask part until the panel firmware dump proves the instruction set.
- Additional EPROM: `ST_M2732A.HEX`, 4 KiB. This image appears to be an external data/config ROM read by the main firmware through `MOVX`, not executable panel firmware.
- PLL: confirmed by `3.jpg` visual inspection as Motorola `MC145156P2`. This changes the model from the earlier `MC145152` assumption: `MC145156` is a clocked serial-input PLL, so the firmware can program frequency by shifting a serial control word rather than driving parallel divider pins directly.

### Photo-derived hardware hypotheses

Visible devices and first-pass roles:

| Device/area | Photo observation | Current hypothesis |
| --- | --- | --- |
| `MAF 8031AH-2` | Main 40-pin CPU near program EPROM | External-code 8051 core running `ST_M27256.HEX`. |
| `PC74HC373P` | Latch near CPU/EPROM and address/data routing | Address/data latch and/or external control latch. Must distinguish from normal 8031 ALE address latch. |
| `OKI M82C43` | Two large OKI chips near CPU/crystals | Likely external I/O/peripheral expansion or custom support logic. Need datasheet/pin tracing. |
| `MC145156P2` / schematic `MC145156P` | PLL chip on RF board, confirmed marking and schematic | Serial-input PLL. The schematic confirms dedicated control lines `CLK`, `DS`, and `E` through `MN03 54LS09`; this supersedes the earlier P1-sync-only hypothesis for the main PLL programming path. |
| `MC14013BCP`, `MC14051BCP`, `MC14066BCP`, `MC14069UB` | CMOS logic around RF/control area | Analog switching, flip-flops, gating for TX/RX/audio/PLL control. |
| `LM2904N` | Op-amps around power/RF control area | Analog control loops: PLL filter, squelch/RSSI/audio/power control candidates. |
| RF close-up support parts | `3.jpg` shows `M74HC00M`, `SNS4LS09A`, `MC14013`, `LF13331R`, trimmers/coils around the PLL | Glue logic and analog switches likely route PLL programming/control, VCO/audio/RF paths, and TX/RX mode lines. |
| RF solder-side close-up | `4.jpg` shows dense traces and vias under the PLL/support-logic area | Good candidate probing area. Exact data/clock/load pins still need pinout overlay or continuity checks against `MC145156P2`. |

Confirmed continuity checks:

| MC145156-2 pin | Signal candidate | Connected to | Note |
| ---: | --- | --- | --- |
| `11` | `CLK` | `SN54LS09J` pin `3`; source 8031 pin `16` / `P3.6` / `/WR` | PLL clock is generated by firmware `MOVX @R0,A` writes, not by direct `SETB/CLR P3.6`. |
| `12` | `DATA` | `SN54LS09J` pin `6`; source 8031 pin `13` / `P3.3` | PLL serial data; original routine `L50B3` toggles `P3.3`. |
| `13` | `ENB` / load | `SN54LS09J` pin `11`; source `MN13` 8243 pin `5` / `P43` | PLL enable/latch line through LS09 open-collector AND gate; firmware candidate writes are around `L4FD9`/`L5184`. |
| `9` | `LD` | coupled by capacitor to MC145156-2 pin `20` | This is not a direct DC continuity control line; treat as an analog/coupled network until measured. |
| Relay/power area | Red relay and power conditioning on logic board | Candidate for power hold, TX/RX switching, or supply rail control. |

Immediate measurement targets suggested by the photos:

1. Put logic analyzer on the schematic-confirmed PLL programming lines: W1 `CLK` pin `8`, W1 `DS` pin `2`, and W1 `E` pin `7`; alternatively use `MN03` outputs `3/6/11`, MC145156 pins `11/12/13`, or CPU-side 8031 `P3.6`/`P3.3` plus `MN13` 8243 `P43`.
2. Also record 8243 writes on `P1.0`, `P1.4..P1.7`, and `P3.5`; these include the candidate 8243 writes for PLL enable/load and may also control TX/RX switching, band filters, or support logic around the PLL.
3. During channel changes, check whether the `CLK/DS/E` bit stream changes. If yes, decode it as the MC145156 programming word.
4. During `APPEL`/PTT, record the same lines plus latch writes; this separates frequency programming from TX enable.
5. Probe PLL `LD` if accessible; it should change/settle after programming and can validate decoded PLL words.
6. From `4.jpg`, prefer probing either directly on the `MC145156P2` pins or on the nearest vias that can be continuity-matched to those pins; the solder-side traces are dense enough that visual-only tracing is not yet reliable.
7. With the new continuity data, also probe `SN54LS09J` inputs that drive pins `3`, `6`, and `11`; those inputs are likely closer to the CPU/latch-side control signals than the PLL pins themselves.

### Interrupt/vector area

8051 vectors are visible in the first bytes:

| Vector | Address | Code | Current interpretation |
| --- | ---: | --- | --- |
| Reset | `0000h` | `LJMP L0026` | Normal reset entry in the known-good `ST_M27256.HEX`. The older `ST_M27256_2.HEX` had one damaged byte here and jumped to `0000h`. |
| Timer 0 | `000Bh` | `LJMP L59EF` | Periodic timer ISR. Toggles `P3.2` under a software flag. |
| Serial | `0023h` | `LJMP L59B8` | UART ISR. Reads `SBUF` on receive, handles transmit/serial flags. |

The code after `0026h` is the real initialization/mainline code reached directly from the reset vector.

### Timer/UART setup

At `026Fh`:

```asm
026F: MOV TMOD,#22h
0272: MOV TCON,#50h
0275: MOV SCON,#70h
0278: MOV TH1,#0E7h
027B: MOV TL1,#0E7h
027E: MOV TH0,#9Ch
0281: MOV TL0,#9Ch
0284: MOV IE,#92h
0287: MOV IP,#10h
```

Interpretation:

- Timer 0 and Timer 1 are both mode 2 auto-reload timers.
- `TCON=50h` starts both timers (`TR1=1`, `TR0=1`).
- `SCON=70h` configures UART mode 1-ish operation with receive enabled; `SM2` is also set.
- `IE=92h` enables global interrupts, Timer 0 interrupt, and serial interrupt.
- `IP=10h` gives serial interrupt high priority.

This block is the current best place to start when recreating clock/timer/UART behavior.

### Parallel latch/bus on P1 with strobe P3.5

Two very important routines:

```asm
L03BF:
03BF: CLR P3.5
03C1: ORL P1,#0F0h
03C4: MOV A,P1
03C6: SWAP A
03C7: ANL A,#0Fh
03C9: SETB P3.5
03CB: RET

L03CC:
03CC: CLR P3.5
03CE: MOV P1,A
03D0: SETB P3.5
03D2: RET
```

Working hypothesis:

- `L03CC` writes one byte/nibble-coded control value to an external latch or decoder through `P1`.
- `P3.5` is the latch enable/strobe. Active low during transfer, released high after.
- `L03BF` reads a 4-bit value. It releases the high nibble of `P1`, samples `P1`, swaps nibbles, and returns the sampled high nibble in `A & 0Fh`.

Schematic/continuity update:

- 8031 pins `5..8` (`P1.4..P1.7`) are the shared 8243 command/data nibble bus.
- 8031 pin `1` (`P1.0`) selects the active 8243.
- `MN13` receives `P1.0` directly and drives the PLL enable candidate on
  `P43` / pin `5`.
- `MN13` pin `4` controls microphone enable. Because `MN13` pin `5` is already
  identified as `P43`, this is probably the adjacent `P42` output, but keep the
  physical pin number as the confirmed fact until the 8243 pinout is fully
  overlaid.
- `MN14` receives the same `P1.0` through an inverter.
- Therefore the low bit of the `P1` values used before `L03CC` is important:
  it selects which 8243 sees the transaction.

Frequent immediate values written through this path include:

`AF EF 8F 8E CE 5E BF FF CF 2E EE AE 3E 4E 6E 4F 6F 7F 1F`

These values are probably board control states: band/filter/PTT/audio/display/PLL selects. They should be correlated with schematic or live pin probing.

High-value call sites:

- `002Fh`, `003Ch`..`0069h` - early setup sequence.
- `0610h`..`068Ch` - compact control routines with fixed values.
- `4700h`..`4775h` - more fixed hardware state setters.
- `5937h`..`5971h` - state changes near bit-protocol code.

Extracted table:

- `LATCH_COMMANDS.csv` contains 51 calls/jumps to `L03CC`.
- Columns: call address, caller label, P1 immediate value if known, A immediate value if known.
- Two calls at `0639h` and `064Ah` are conditional; values depend on carry from bits read at `2253h`.
- Call at `472Fh` sets `A=#BEh` but does not set `P1` immediately before `L03CC`; that means it intentionally reuses the current `P1` selection, or nearby disassembly crosses a data/code boundary.

Most common P1 select values before latch write:

| P1 value | Count | Current guess |
| --- | ---: | --- |
| `EFh` | 5 | Repeated fixed command group, paired with `7Fh/BFh/DFh`. |
| `AFh` | 5 | Repeated fixed command group, paired with `4Fh/8Fh/2Fh`. |
| `8Fh` | 5 | Mode/state command group near `47xx`, `57D5h`. |
| `8Eh` | 5 | Often paired with `1Eh`, likely paired with `CEh` group. |
| `CEh` | 5 | Often paired with `7Eh/EEh/BEh`. |
| `CFh` | 4 | Often paired with `DFh/7Fh/9Fh`. |
| `5Eh` | 4 | Paired with `0Eh`, `FEh`, or computed value from `218Ch`. |
| `EEh` | 3 | Paired with `7Eh/DEh`. |
| `AEh` | 3 | Paired with `2Eh/4Eh/8Eh`. |

Useful repeated command pairs:

| P1 | A | Count | Seen near |
| --- | --- | ---: | --- |
| `8Eh` | `1Eh` | 3 | init and `4DFBh/547Dh`; likely a default state. |
| `0EFh` | `7Fh` | 2 | `065Ah`, `55D0h`. |
| `0CEh` | `0EEh` | 2 | `4E0Eh`, `544Eh`. |
| `0CEh` | `7Eh` | 2 | `4FE0h`, `5192h`. |
| `0AFh` | `8Fh` | 2 | `067Ah`, `55EDh`. |
| `0CFh` | `0DFh` | 2 | `3BA9h`, `4727h`. |
| `0EFh` | `0BFh` | 2 | `061Ch`, `55E4h`. |
| `5Eh` | `0Eh` | 2 | init and `5944h`. |
| `8Fh` | `2Fh` | 2 | `471Ah`, `57DAh`. |
| `0AFh` | `4Fh` | 2 | `0615h`, `55DBh`. |
| `8Fh` | `4Fh` | 2 | `475Dh`, `4770h`. |
| `0EEh` | `7Eh` | 2 | `593Ch`, `5969h`. |

These are now the first candidates for named hardware states in the new firmware.

### Bit protocol on P1.1/P1.2/P1.3 with input P3.4

Transmit-like routine starts at `598Eh`:

```asm
598E: CLR P1.1
5994: SETB P1.1
5996: MOV R2,#08h
5998: JB ACC.0,L59A0
599B: CLR P1.3
59A0: SETB P1.3
59A2: CLR P1.2
59A4: RR A
59A5: JB P3.4,L59A5
59A8: SETB P1.2
59AA: JNB P3.4,L59AA
59AD: DJNZ R2,L5998
59AF: SETB P1.3
```

Receive-like routine starts at `58E1h`:

```asm
58E1: JB P3.4,L592C
58E4: MOV C,P1.3
58E6: RRC A
58E7: CLR P1.2
58E9: JNB P3.4,L58E9
58EC: SETB P1.2
58EE: DJNZ R2,L58E1
```

Working hypothesis:

- `P1.1` is a select/reset/framing signal.
- `P1.2` is a clock/ack line driven by MCU.
- `P1.3` is bidirectional or data-related: driven during transmit, sampled during receive.
- `P3.4` is a ready/clock/ack input from the external device.
- Transmit sends 8 bits LSB-first from `A`.
- Receive samples 4 bits into a nibble, then stores it into low nibble of RAM byte `68h`.

This looks like a custom synchronous peripheral link, possibly front-panel keyboard/display, synthesizer, or an auxiliary controller.

Direct incoming edges:

| Target | Incoming edge | Meaning |
| --- | --- | --- |
| `L598E` | `597C: CJNE A,#0FFh,L598E` | Sends a byte read from internal/external state unless it is `FFh`. |
| `L58E1` | loop edges from `58EEh` and `592Ch` | Internal receive loop only; entry setup starts at `58DCh`. |

The setup before `L58E1`:

```asm
58DC: MOV R2,#04h
58DE: MOV R1,#05h
58E0: CLR A
```

So receive attempts up to 5 times and samples 4 bits per attempt.

### Event dispatcher / main loop

`L585F` is an important architecture node. It behaves like a cooperative event dispatcher:

```asm
585F: JB 20h.3,L589A
5862: JBC 24h.1,L589D
5865: JBC 24h.2,L58A0
5868: JBC 20h.1,L58A3
586B: JB 20h.2,L58A6
586E: JBC 25h.1,L58A9
5871: JBC 25h.0,L58AC
...
5898: SJMP L585F
```

Interpretation:

- Internal bit-addressable RAM (`20h..2Eh`) is used as event flags.
- `JBC` means "test and clear flag", so most events are one-shot.
- `JB` means level-style event, so `20h.3` and `20h.2` stay set until handler clears them.
- `L589A -> L58DC` starts the 4-bit receive path when Timer0 ISR sets `20h.3`.
- `L58A6 -> L597C` starts the byte transmit path when `20h.2` is set.
- Several hardware state handlers reached from this dispatcher eventually call `L03CC`.

For a new firmware this suggests a clean structure:

```c
while (1) {
    poll_or_wait_events();
    if (sync_rx_pending) sync_recv_nibble();
    if (sync_tx_pending) sync_send_byte(next_byte);
    if (latch_state_dirty) apply_latch_state();
    service_uart();
}
```

The exact original state machine does not need to be cloned, but this identifies how hardware work is scheduled.

Generated files:

- `EVENT_DISPATCH.csv` - 18 top-level events handled by `L585F`.
- `EVENT_FLAG_XREF.csv` - references to those 18 event flags: producers, consumers, and clears.

Top-level dispatcher map:

| Flag | Kind | Handler | Current interpretation |
| --- | --- | --- | --- |
| `20h.3` | level | `L58DC` | Synchronous receive start. Set only by Timer0 ISR when `P3.4` qualifies; cleared after receive. |
| `24h.1` | one-shot | `L541E` | Delayed/probed state update; sets timer flag `27h.5`. |
| `24h.2` | one-shot | `L542D` | Hardware state update; may write latch pairs `CE/EE` or `8E/1E`. |
| `20h.1` | one-shot | `L4D2A` | Periodic timer service. Maintains counters, UART/service flags, latch timeout actions. |
| `20h.2` | level | `L597C` | Synchronous transmit event. Set at `2CC9h`, cleared at `5984h`. |
| `25h.1` | one-shot | `L534F` | Latch read/status handler using `L03BF`. |
| `25h.0` | one-shot | `L568F` | Serial/sync related handler. |
| `24h.0` | one-shot | `L4CFD` | UART transmit/service handler. Also set by serial ISR on transmit-complete path. |
| `23h.6` | one-shot | `L4A16`/`L51AB` | Branch depends on board/status flag `2Bh.2`. |
| `23h.7` | one-shot | `L2BE3` | Event handler with `MOVX` activity. |
| `2Eh.0` | one-shot | `L5609` | Sub-dispatcher for `2Eh` flags; related to UART/sync command flow. |
| `24h.6` | one-shot | `L3271` | Event handler. |
| `25h.2` | one-shot | `L4FD9` | Hardware latch/state handler. |
| `24h.4` | one-shot | `L3C5E`/`L06A6` | Branch depends on `2Bh.3`; one path enters a jump table. |
| `24h.7` | one-shot | `L346C` | Event handler. |
| `24h.3` | one-shot | `L57E0` | Large mode/state dispatcher via jump table. This flag is set in 58 places. |
| `23h.5` | one-shot | `L5748` | Event handler with jump table. |
| `24h.5` | one-shot | `L54B9` | External state handler with heavy `MOVX` activity. |

Important event-flag observations:

- `20h.3`: Timer0 ISR sets it at `59F8h` if `P3.4` is low and sync transmit is not active; receive path clears it at `58F0h`.
- `20h.2`: set at `2CC9h`, consumed by `L597C`, cleared at `5984h`. Timer0 refuses to start receive while this is set.
- `20h.1`: set by Timer0 every 5 ISR ticks via byte counter `19h`; consumed by `L4D2A`.
- `24h.0`: set by serial ISR at `59BFh` on non-RI serial interrupt path; consumed by `L4CFD`.
- `24h.3`: high-level mode/state update event. It fans into `L57E0`, which selects a large jump table using internal byte `64h`.
- `25h.2`: common "apply hardware/state" event; set in 35 places and handled by `L4FD9`.

This suggests the original firmware has three layers:

1. ISR layer: Timer0 and UART set compact event bits.
2. Event layer: `L585F` consumes event bits and calls focused handlers.
3. Mode layer: `L57E0` and other jump tables implement radio/UI state machines.

### Serial ISR

At `59B8h`:

```asm
59B8: JBC SCON.0,L59C4
59BB: CLR SCON.1
59BD: CLR 2Ch.6
59BF: SETB 24h.0
59C1: LJMP L59EE
59C4: PUSH 01h
...
59CE: MOV R1,SBUF
...
59DC: MOV @R0,A
59EE: RETI
```

Interpretation:

- If `RI` is set, received byte from `SBUF` is pushed into an internal RAM buffer.
- If not receive, it treats the interrupt as transmit-complete-ish: clears `TI`, updates software flags.
- Other code writes `SBUF` at `4D0Dh`, `4D19h`, `56A6h`, and `573Ch`.

UART is likely a service/programming/control interface or inter-board serial link.

### Timer 0 ISR

At `59EFh`:

```asm
59EF: JB 20h.3,L59FA
59F2: JB P3.4,L59FA
59F5: JB 20h.2,L59FA
59F8: SETB 20h.3
...
5A0B: CPL P3.2
5A0D: RETI
```

Interpretation:

- Polls/qualifies `P3.4`.
- Maintains small software timers/counters in internal RAM bytes `18h` and `19h`.
- Conditionally toggles `P3.2`; likely a square wave, beep, scan clock, or watchdog-style service output.

### External MOVX address regions

Static pass found 106 unique DPTR addresses used with `MOVX`. The hottest regions:

| Region | Examples | Notes |
| --- | --- | --- |
| `0464h`..`0488h` | `0465`, `046C`, `046A`, `0464`, `0468`, `0469` | Frequently read. Likely external status/config/register mirror. |
| `218Ch`..`21FFh` | `2199`, `21CA`, `21FD`, `21FA`, `21FB` | Persistent/config/state tables. |
| `223Bh`..`2258h` | `224C`, `224F`, `2248`, `2258`, `2251` | Heavily used external RAM/register page. |
| `2000h`.. | `2000`, `2001`, `201C` | Used during initialization and table operations. |

Next pass should classify each `MOVX` access as read/write and attach the surrounding routine.

`MOVX_ACCESS.csv` now contains 605 `MOVX` instructions. Top resolved accesses:

| Address | Direction | Count | Current guess |
| --- | --- | ---: | --- |
| `046Ch` | read | 31 | Hot external status/config byte. |
| `046Ah` | read | 24 | Hot external status/config byte. Bits 1,2,6 are tested in early code. |
| `0464h` | read | 18 | Startup status byte; saved in `B/R3`; bit 4 affects internal flags. |
| `0468h` | read | 16 | External status byte; bit 6 affects state at `477Eh`. |
| `224Ch` | write | 16 | External RAM/state page. |
| `2248h` | write | 12 | External RAM/state page. |
| `224Fh` | write | 12 | External RAM/state page. |
| `047Eh` | read | 11 | Startup gate/status; bit 6 controls branch at `010Ch`. |
| `046Dh` | read | 10 | Hot external status/config byte. |
| `0469h` | read | 10 | Startup/status byte; bits 4/5 used. |
| `21FAh` | read/write | 19 total | State mirror/current value around routines near `05EFh`. |

Working split:

- `0464h..0488h`: now confirmed to overlap non-`FFh` data in `ST_M2732A.HEX`; likely external config/option/status bytes from the 4 KiB EPROM.
- `21xx`: state tables and mirrors used by firmware logic.
- `223Bh..2258h`: external RAM/state page used during initialization, counters, or encoded BCD/nibble values.

Important `ST_M2732A` values read by the main firmware:

| Address | Value | Note |
| --- | --- | --- |
| `0464h` | `42h` | Startup/status/config byte. |
| `0468h` | `DEh` | Bit 6 affects state/event logic. |
| `0469h` | `F0h` | Bits 4 and 5 are tested. |
| `046Ah` | `00h` | Very frequently read; bits 1, 2, 6 tested. |
| `046Ch` | `FBh` | Most frequently read byte in this ROM. |
| `047Eh` | `00h` | Startup gate/status byte. |

See `ST_M2732A_USED_BY_MAIN.csv` for the full cross-reference.

## Naming candidates

Suggested labels for a commented ASM pass:

| Current label | Suggested name | Reason |
| --- | --- | --- |
| `L03BF` | `hw_latch_read_nibble` | Samples high nibble of `P1` with `P3.5` strobe. |
| `L03CC` | `hw_latch_write_p1` | Writes `A` to `P1` with `P3.5` strobe. |
| `L026F` block | `init_timers_uart` | Sets timers, serial port, interrupt enables. |
| `L598E` | `sync_send_byte` | Sends 8 bits using `P1.2/P1.3` and waits on `P3.4`. |
| `L58E1` | `sync_recv_nibble` | Samples 4 bits via `P1.3` paced by `P3.4`. |
| `L59B8` | `serial_isr` | UART interrupt. |
| `L59EF` | `timer0_isr` | Timer interrupt. |
| `L585F` | `event_dispatcher` | Cooperative flag dispatcher/main loop. |
| `L58DC` | `sync_recv_start` | Sets retry count/bit count before `sync_recv_nibble`. |
| `L597C` | `sync_tx_event` | Reads byte and branches into `sync_send_byte`. |

## Generated analysis files

| File | Purpose |
| --- | --- |
| `ST_M27256.asm` | Known-good ASM disassembly. |
| `ST_M27256_2_annotated.asm` | Older annotated ASM; regenerate annotations against `ST_M27256.asm` before relying on reset-vector comments. |
| `MOVX_ACCESS.csv` | All `MOVX` accesses with PC, current label, direction, and DPTR if known. |
| `LATCH_COMMANDS.csv` | All calls/jumps to `L03CC` with nearby immediate `P1` and `A` values. |
| `CALL_GRAPH.csv` | Control-flow edges from calls, jumps, and conditional branches. |
| `EVENT_DISPATCH.csv` | Top-level event table from `L585F`. |
| `EVENT_FLAG_XREF.csv` | Cross-references for the 18 top-level event flags. |
| `ST_M2732A_USED_BY_MAIN.csv` | Non-`FFh` bytes in `ST_M2732A` with main firmware references. |
| `DISPLAY_PROTOCOL_CANDIDATES.md` | Display/panel protocol candidates: ASCII-to-display-code table, queue `40h`, and packet builders near `2E1Eh`/`52E2h`. |

## Next concrete steps

1. Build the first display demo around `DISPLAY_PROTOCOL_CANDIDATES.md`: reproduce `L598E`, use the `498Ch/49B9h` character table, then test known packet candidates from `2E1Eh..2EA7h`.
2. Start a clean firmware HAL with these primitives:
   - `latch_write(uint8_t select, uint8_t value)` -> drives `P1`/`P3.5` like `L03CC`.
   - `latch_read_nibble(uint8_t select)` -> drives `P1`/`P3.5` like `L03BF`.
   - `sync_send_byte(uint8_t value)` -> reproduces `L598E`.
   - `sync_recv_nibble()` -> reproduces `L58E1`.
   - `timer0_tick_isr()` -> reproduces the minimal timer service/toggle behavior.
   - `serial_isr()` -> optional until UART role is known.
3. Create named constants for the repeated latch pairs above, but keep names provisional until matched to hardware.
4. If hardware is available, probe `P1.0..P1.3`, `P3.2`, `P3.4`, `P3.5` during startup and during button/channel/PTT actions.
5. Rework the demo firmware using the known-good startup path and remove assumptions based on the damaged `ST_M27256_2.HEX` reset vector.
