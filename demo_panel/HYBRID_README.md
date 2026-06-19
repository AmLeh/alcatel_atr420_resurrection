# Hybrid firmware images

These images are based on the known-good original firmware `ST_M27256.HEX`.

## HYBRID_ORIGINAL_STARTUP_123.HEX

Path:

```text
demo_panel/build/HYBRID_ORIGINAL_STARTUP_123.HEX
```

Purpose:

- keep the original reset vector and startup code;
- run the original initialization from `0026h`;
- at the original transition point `034Ch`, jump to a small hook at `6B00h`;
- force the original display buffer `72h..79h` to contain `123     `;
- jump into the original `L4B07` routine, which queues a display frame and
  returns into the original dispatcher.

Patch summary:

```text
034C: 02 6B 00    ; LJMP 6B00h

6B00:
  75 72 01        ; char0 = '1'
  75 73 02        ; char1 = '2'
  75 74 03        ; char2 = '3'
  75 75 24        ; spaces
  75 76 24
  75 77 24
  75 78 24
  75 79 24
  78 36           ; R0 = UART/display queue
  76 00           ; clear queue length
  02 4B 07        ; LJMP original display-frame builder
```

Expected behavior:

- If the original startup and original display path are enough, the station
  should behave close to the stock firmware at boot and show `123`.
- If this image works but the clean demo does not, the missing piece is in the
  original initialization/state setup before `034Ch` or in the original event
  dispatcher.

Build:

```powershell
python .\demo_panel\make_hybrid_200_hex.py
```

## HYBRID_FORCE_123_EVERY_DISPLAY.HEX

Path:

```text
demo_panel/build/HYBRID_FORCE_123_EVERY_DISPLAY.HEX
```

Purpose:

- keep the original firmware behavior;
- patch the original full display-frame builder `L4B07`;
- force the display buffer to `123     ` every time the original firmware tries
  to send a full display update.

Patch summary:

```text
4B07: 02 6B 40    ; LJMP 6B40h

6B40:
  75 72 01        ; char0 = '1'
  75 73 02        ; char1 = '2'
  75 74 03        ; char2 = '3'
  75 75 24        ; spaces
  75 76 24
  75 77 24
  75 78 24
  75 79 24
  79 78           ; original replaced MOV R1,#78h
  12 03 65        ; original replaced LCALL L0365
  02 4B 0C        ; continue original L4B07
```

Expected behavior:

- If `L4B07` is the normal full-screen update path, the display should keep
  returning to `123` instead of being overwritten by the original startup `200`
  or channel display.

Build:

```powershell
python .\demo_panel\make_hybrid_force_123_hex.py
```

## HYBRID_KEYCODE_DISPLAY.HEX

Path:

```text
demo_panel/build/HYBRID_KEYCODE_DISPLAY.HEX
```

Purpose:

- keep the original firmware startup, panel initialization, timers, UART and
  display sender;
- hook the accepted-key endpoint at `5724h`;
- show the accepted key byte from `R3` as `KEY xx`, where `xx` is hexadecimal.

Patch summary:

```text
5724: 02 6B 80    ; LJMP 6B80h

6B80:
  8B 7B           ; original MOV 7Bh,R3
  D2 24           ; original SETB 24h.4
  ...             ; write "KEY xx  " to display buffer 72h..79h
  78 36           ; R0 = UART/display queue
  76 00           ; clear queue length
  02 4B 07        ; LJMP original display-frame builder
```

Expected behavior:

- boot should remain close to original;
- when a key accepted by the original firmware is pressed, display should change
  to `KEY xx`;
- `xx` is the internal byte code after the panel/keyboard receive parser.

Build:

```powershell
python .\demo_panel\make_hybrid_keycode_hex.py
```

## ORIGINAL_INIT_CUSTOM_KEYCODE.HEX

Path:

```text
demo_panel/build/ORIGINAL_INIT_CUSTOM_KEYCODE.HEX
```

Purpose:

- run the known-good original reset/startup code from `0026h` through `034Ch`;
- stop before the original event dispatcher `L585F`;
- disable interrupts and run a custom direct UART panel demo;
- show `DEMO 02` at boot and then show received panel bytes as `KEY xx`;
- avoid the original key state-machine, so functional keys such as APPEL should
  not run original radio actions;
- handle `ON/OFF` key code `60h` by re-entering the original shutdown handler.

Patch summary:

```text
034C: 02 6C 00    ; LJMP custom app

6C00:
  IE = 00h
  show "DEMO 02"
  poll RI/SBUF directly
  if key == 60h: IE = 92h; LJMP 56D8h
  show "KEY xx"
```

Expected behavior:

- If this image works while `STANDALONE_KEYCODE_DISPLAY.HEX` does not, the
  missing panel initialization is somewhere in original startup before `034Ch`.
- If this image still shows a blank display, then the original dispatcher path
  after `034Ch` is also doing a required panel wakeup/update step.

Hardware result:

- Confirmed working on the station.
- The display shows the custom screen/key codes after original startup.
- This proves the original startup through `034Ch` is sufficient for panel
  initialization, and the original dispatcher is not required for the
  keyboard/display demo loop.
- `ON/OFF=60h` is a special original RX-parser case at `56D8h`: it writes
  `2257h=0Bh`, queues display/panel event `02h` twice, then returns to the
  original dispatcher. The demo now jumps to this path to let the station
  perform the native shutdown sequence.

Build:

```powershell
python .\demo_panel\make_original_init_custom_keycode_hex.py
```

## INITCUT_xxxx.HEX

Path pattern:

```text
demo_panel/build/INITCUT_0075.HEX
demo_panel/build/INITCUT_0098.HEX
...
demo_panel/build/INITCUT_034C.HEX
```

Purpose:

- find the smallest part of original startup required to wake the panel;
- each image runs original code from reset until address `xxxx`;
- at `xxxx`, the image jumps to the same custom `DEMO 02` / `KEY xx` loop;
- the custom loop initializes UART/timers itself, so early cuts before `026Fh`
  are valid tests.

Generated cuts:

| Image | Original startup runs until | What it tests |
| --- | ---: | --- |
| `INITCUT_0075.HEX` | `0075h` | early latch init and `P1.1` pulse only |
| `INITCUT_0098.HEX` | `0098h` | plus internal RAM clear/checksum pass |
| `INITCUT_00A1.HEX` | `00A1h` | plus `0469h` option read |
| `INITCUT_00D1.HEX` | `00D1h` | plus first `223B..223E` state touches |
| `INITCUT_0108.HEX` | `0108h` | plus `2000..23FF` fill/checksum mirror path |
| `INITCUT_0179.HEX` | `0179h` | alternate `047Eh=0` startup branch |
| `INITCUT_01B3.HEX` | `01B3h` | plus channel/config table branch |
| `INITCUT_025A.HEX` | `025Ah` | plus initial channel/state calculation |
| `INITCUT_026F.HEX` | `026Fh` | before original timer/UART init |
| `INITCUT_028D.HEX` | `028Dh` | after original timer/UART init |
| `INITCUT_02B4.HEX` | `02B4h` | plus initial flags and `2191h` mirror |
| `INITCUT_0318.HEX` | `0318h` | before final `2248/224A/224C/224F` writes |
| `INITCUT_033C.HEX` | `033Ch` | before final `224C/224F` writes |
| `INITCUT_034C.HEX` | `034Ch` | full confirmed startup baseline |

Suggested test order:

```text
0075 -> 01B3 -> 026F -> 0318 -> 034C
```

Then narrow the boundary with the adjacent images around the first working cut.

Build:

```powershell
python .\demo_panel\make_init_cut_hex.py
```
