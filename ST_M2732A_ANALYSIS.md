# Analysis of ST_M2732A.HEX

## Summary

`ST_M2732A.HEX` is very likely not executable firmware. It looks like a 4 KiB external data EPROM used by the main 8051 firmware through `MOVX`.

Why:

- The image range is `0000h..0FFFh`, matching a 2732 EPROM size.
- Most bytes are erased (`FFh`).
- Only 171 bytes are non-`FFh`.
- The non-`FFh` bytes are concentrated around addresses that the main firmware reads heavily through `MOVX`, especially `0464h..0489h`.
- First-pass 8051 disassembly is not meaningful as code; it mostly decodes erased `FFh` bytes as `MOV R7,A`.

Generated files:

- `ST_M2732A.bin` - 4096-byte binary image.
- `ST_M2732A.asm` - linear 8051 disassembly, mostly useful only to prove this is not normal code.
- `ST_M2732A_USED_BY_MAIN.csv` - non-`FFh` bytes cross-referenced with main firmware `MOVX` accesses.
- `analyze_m2732a.py` - analysis script.

## Statistics

| Property | Value |
| --- | ---: |
| Size | 4096 bytes |
| Address range | `0000h..0FFFh` |
| Non-`FFh` bytes | 171 |
| Main firmware `MOVX` references into this range | 241 instructions |
| Unique main firmware addresses in this range | 43 |
| Non-`FFh` bytes directly referenced by main firmware | 30 |

The main firmware startup checksum-like algorithm over `0000h..0FFFh` gives:

```text
R7:R6 = 87:E2
```

## Important directly referenced bytes

These bytes are both non-`FFh` in `ST_M2732A` and directly read by the main firmware:

| Address | Value | Main read count | Current meaning |
| --- | --- | ---: | --- |
| `0464h` | `42h` | 18 | Startup/status/config byte. Bit 4 is tested early. |
| `0465h` | `6Bh` | 13 | Hot config/status byte. |
| `0466h` | `B7h` | 8 | Config/status byte; bit 5 tested near timer/UART init. |
| `0467h` | `81h` | 9 | Config/status byte. |
| `0468h` | `DEh` | 17 | Config/status byte; bit 6 used by event/state logic. |
| `0469h` | `F0h` | 10 | Startup/status byte; bits 4 and 5 are used. |
| `046Ah` | `00h` | 24 | Very hot status/config byte; bits 1, 2, 6 tested. |
| `046Bh` | `00h` | 8 | Config/status byte. |
| `046Ch` | `FBh` | 31 | Hottest byte in this EPROM; likely important option/status mask. |
| `046Dh` | `FEh` | 10 | Config/status byte. |
| `0474h` | `3Bh` | 8 | Used by state logic. |
| `0475h` | `55h` | 4 | Used during startup/table selection. |
| `047Dh` | `0Ah` | 4 | Used by state logic. |
| `047Eh` | `00h` | 11 | Startup gate/status; bit 6 controls early branch. |
| `0483h` | `0Fh` | 6 | Config/status byte. |
| `08AAh` | `01h` | 4 | Referenced from main firmware; likely table/config byte. |

## Why this is useful

This EPROM explains many values that the main firmware reads from addresses previously classified as external status/config registers.

Before this file, addresses like `0464h`, `046Ah`, and `046Ch` looked like unknown external hardware registers. Now they appear to be backed by a small external data EPROM, at least in this dump.

This helps in three ways:

1. It makes the original main firmware easier to emulate or reason about, because many branch conditions now have known constant values.
2. It may contain radio variant/options/channel tables used by the main firmware.
3. A replacement test firmware can either ignore this EPROM or deliberately read it as a board configuration ROM.

## What it does not solve

This file is probably not the panel MCU firmware.

It does not directly give:

- LCD 1602 command protocol.
- Keyboard scan matrix.
- LED control protocol.
- Panel MCU code.

For the keyboard/LCD demo, the still-most-important missing file is the firmware dump from the panel MCU `IP-80C51643`.

## Practical conclusion

`ST_M2732A.HEX` is useful for the full project, especially for understanding original board options and main firmware decisions.

For the first demo firmware focused on LCD/keyboard:

- Keep this EPROM present if the board expects it.
- The demo firmware can ignore it at first.
- Later, read `0464h..0489h` as board configuration if needed.
- It does not replace the need to dump and analyze the panel MCU firmware.
