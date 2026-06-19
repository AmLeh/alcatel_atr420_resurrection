# Demo panel firmware

This directory contains a first experimental 8051 firmware for the main MCU
EPROM socket.

Built HEX:

```text
demo_panel/build/PANEL_DEMO.HEX
demo_panel/build/STANDALONE_KEYCODE_DISPLAY.HEX
```

Diagnostic HEX:

```text
demo_panel/build/DIAG_ENTRY_SCAN.HEX
```

`DIAG_ENTRY_SCAN.HEX` is not a normal demo. It is a startup diagnostic image:
many possible entry addresses jump to one minimal hand-written 8051 routine at
`0200h`. The routine runs the early latch sequence, initializes UART, toggles
`P3.2`/`P1.0`, and repeatedly sends a short display frame. Use it when
`PANEL_DEMO.HEX` gives no visible reaction at all.

Current standalone build:

- code bytes: 1894;
- address range: `0000h..076Ah`;
- reset vector: `0000h: LJMP 004Ch`;
- diagnostic mirrored entry: `0026h: LJMP 004Ch`;
- output format: ASCII Intel HEX.

What it tries to do:

- initialize ports to inactive/high state;
- run the original early latch enable sequence from `0037h..0069h`;
- send candidate synchronous panel wakeup packets from the original
  `2E1Eh..2FF1h` family;
- send candidate UART panel wakeup bytes from the original `4Bxx` family;
- initialize Timer1/UART using the same values as the original firmware near
  `026Fh`;
- send demo text to the panel display through UART/SBUF, using the original
  7-bit data plus parity-bit convention;
- poll UART receive and show received byte as `KEY xx`;
- poll the synchronous panel/status nibble line and show received nibble as
  `SYN 0x`.

Display output hypothesis:

- original display-code table: `498Ch/49B9h`;
- original full text sender candidate: `L4B07`;
- original UART transmit queue: RAM queue `36h`, sent by `L4CFD`;
- frame used by this demo: `78h` followed by 8 encoded display characters in
  the same scrambled order as `L4B07`.

Startup latch sequence now included:

```text
P1=4E -> latch 1E
P1=6E -> latch 4E
P1=5E -> latch 0E
P1=4F -> latch DF
P1=6F -> latch AF
P1=7F -> latch 0F
```

Synchronous wakeup packet candidates now included:

```text
00 01 0D 0E 16 18 24 2F
00 02 0B 2F
00 02 0B 0C 2F
00 02 0D 0E 2F
00 03 2F
00 05 2F
00 06 0D 0E 16 18 24 2F
1F 00 00 00 00 2F
```

These are sent using the original `L598E` bit protocol shape on
`P1.1/P1.2/P1.3/P3.4`, but with timeouts so the demo can continue to UART tests
if the panel does not handshake.

Keyboard/input hypothesis:

- UART input is received by the original serial ISR at `L59B8` and queued at
  RAM `33h`; `L568F` consumes this queue and treats values as command/key-like
  codes.
- The synchronous receive routine `L58DC/L58E1` also receives a 4-bit value and
  stores it into the low nibble of RAM `68h`.
- The demo shows both sources because the exact keyboard path is not proven yet.

Build:

```powershell
powershell -ExecutionPolicy Bypass -File .\demo_panel\build.ps1
copy .\demo_panel\build\PANEL_DEMO.HEX .\demo_panel\build\STANDALONE_KEYCODE_DISPLAY.HEX
python .\demo_panel\make_entry_scan_hex.py
```

`STANDALONE_KEYCODE_DISPLAY.HEX` does not run the original radio firmware main
loop. It is a small demo program for the panel path: display output and raw
key-code display only.

Reset-vector note:

The known-good original dump `ST_M27256.HEX` has a normal reset vector:
`0000h: LJMP 0026h`. The older `ST_M27256_2.HEX` had one damaged byte at
`0002h`, producing `0000h: LJMP 0000h`. Earlier no-reaction tests based on the
old dump should be reinterpreted with this correction in mind.

The demo still has a diagnostic mirrored entry at `0026h`, but this is no longer
evidence for non-standard booting; it is only a harmless fallback jump.
