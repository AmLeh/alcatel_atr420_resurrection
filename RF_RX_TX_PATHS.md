# RX/TX paths found from panel ANT LED commands

This note tracks original-firmware paths found by using confirmed panel LED
commands as markers.

Source: `ST_M27256_annotated.asm`.

## Confirmed panel LED command markers

CPU-to-panel UART commands:

| Command | Meaning |
| ---: | --- |
| `60h` | `ANT` off |
| `61h` / `68h` | `ANT` orange on |
| `69h` | `ANT` green on |

Important direction note: incoming key code `60h` is the panel `ON/OFF` key.
Outgoing command `60h` is `ANT` off.

## Panel command queue

The panel-display command queue starts at internal RAM `2Fh`.

```asm
L034F:
034F: 78 2F     MOV R0,#2Fh
0351: B6 03 03  CJNE @R0,#03h,L0357
0354: 22        RET
L0355:
0355: 78 2F     MOV R0,#2Fh
L0357:
0357: D2 1E     SETB 23h.6
...
0372: E9        MOV A,R1
0373: F6        MOV @R0,A
```

`L034F` queues a panel operation code if the queue is not full.
`L0355` queues more aggressively. `SETB 23h.6` wakes the dispatcher.

The dispatcher consumes this queue here:

```asm
L58B2:
58B2: 20 5A 03  JB 2Bh.2,L58B8
58B5: 02 4A 16  LJMP L4A16

L4A16:
4A16: 78 2F     MOV R0,#2Fh
4A18: 12 03 79  LCALL L0379
4A1B: B4 FF 03  CJNE A,#0FFh,L4A21
```

`L4A21` is a jump table. Relevant operation-code entries:

| Queue op | Jump table entry | Panel command behavior |
| ---: | --- | --- |
| `0Fh` | `4A57 -> L4BA4` | send `68h`, `ANT` orange on |
| `11h` | `4A5D -> L4BC7` | send `6Ch`, then `69h`, `ANT` green on |
| `12h` | `4A60 -> L4BD4` | send `6Dh`, then `60h`, `ANT` off |
| `15h` | `4A69 -> L4BF2` | status refresh, then `60h`, optionally `69h` |
| `16h` | `4A6C -> L4BAB` | send `60h`, optionally `69h` |

## TX / ANT orange path

The cleanest TX marker is operation `0Fh`.

```asm
L468A:
468A: 30 47 0E  JNB 28h.7,L469B
L468D:
468D: 75 4A 10  MOV 4Ah,#10h
4690: D2 1F     SETB 23h.7
4692: 20 50 05  JB 2Ah.0,L469A
4695: 79 0F     MOV R1,#0Fh
4697: 12 03 4F  LCALL L034F
```

That queued `0Fh` reaches:

```asm
L4BA4:
4BA4: 79 68     MOV R1,#68h
4BA6: 12 03 65  LCALL L0365
4BA9: 80 89     SJMP L4B34
```

Hardware interpretation:

- `L468A/L468D` is the high-level TX/display-state marker.
- `L4BA4` sends outgoing panel command `68h`, confirmed as `ANT orange on`.
- `L468D` also sets `23h.7`, which wakes another state-machine branch through
  the main dispatcher. That branch often leads into RF latch setup.

Related RF/TX setup routines:

```asm
L45B3:
45B3: 20 50 FC  JB 2Ah.0,L45B2
45B6: C2 33     CLR 26h.3
45B8: C2 4B     CLR 29h.3
45BA: D2 2E     SETB 25h.6
45BC: 75 60 05  MOV 60h,#05h
45BF: 75 61 05  MOV 61h,#05h
45C2: 85 60 4E  MOV 4Eh,60h
45C5: 12 59 64  LCALL L5964
45C8: 90 22 4C  MOV DPTR,#224Ch
45CB: 74 01     MOV A,#01h
45CD: F0        MOVX @DPTR,A
```

`L5964` drives RF/control latch state and sets `20h.0`:

```asm
L5964:
5964: 74 7E     MOV A,#7Eh
5966: 75 90 EE  MOV P1,#0EEh
5969: 12 03 CC  LCALL L03CC
596C: 74 FE     MOV A,#0FEh
596E: 75 90 5E  MOV P1,#5Eh
5971: 12 03 CC  LCALL L03CC
5974: D2 00     SETB 20h.0
```

Timer/service code then uses `25h.6`, `60h`, `61h`, `4Eh`, and `20h.0`:

```asm
L4DE5:
4DE5: 30 2E 29  JNB 25h.6,L4E11
4DE8: D5 4E 26  DJNZ 4Eh,L4E11
4DEB: 20 00 13  JB 20h.0,L4E01
4DEE: 85 60 4E  MOV 4Eh,60h
4DF1: D2 00     SETB 20h.0
4DF3: 30 57 1B  JNB 2Ah.7,L4E11
4DF6: 75 90 8E  MOV P1,#8Eh
4DF9: 74 1E     MOV A,#1Eh
4DFB: 12 03 CC  LCALL L03CC
...
4E01: 85 61 4E  MOV 4Eh,61h
4E04: C2 00     CLR 20h.0
4E06: 30 57 08  JNB 2Ah.7,L4E11
4E09: 75 90 CE  MOV P1,#0CEh
4E0C: 74 EE     MOV A,#0EEh
4E0E: 12 03 CC  LCALL L03CC
```

This is a strong RF/TX timing candidate. It toggles latch writes after the TX
setup routine has enabled `25h.6`.

## Tangenta/PTT panel codes

Newly observed incoming panel-key codes:

| Key event | Incoming code |
| --- | ---: |
| Tangenta/PTT pressed | `2Eh` |
| Tangenta/PTT released | `2Dh` |

These values are not handled by a direct `CJNE ...,#2Eh` / `CJNE ...,#2Dh`
branch in the main key handler. Instead, the received panel byte is stored as a
generic key/event code.

The first important path is the panel receive/key normalization routine:

```asm
L56D8:
56D8: EB        MOV A,R3
56D9: B4 60 13  CJNE A,#60h,L56EF
...
L56EF:
56EF: B4 2F 03  CJNE A,#2Fh,L56F5
56F2: 02 57 24  LJMP L5724
...
L5717:
5717: 20 2E 0A  JB 25h.6,L5724
571A: 75 54 02  MOV 54h,#02h
571D: D2 33     SETB 26h.3
571F: 12 59 64  LCALL L5964
5722: D2 4B     SETB 29h.3
L5724:
5724: 8B 7B     MOV 7Bh,R3
5726: D2 24     SETB 24h.4
```

For both `2Eh` and `2Dh`, the code reaches `L5717` unless TX/RF flag
`25h.6` is already set. The routine then:

- arms timer/counter `54h = 02h`;
- sets delayed flag `26h.3`;
- calls `L5964`, the RF/microphone/latch candidate;
- sets `29h.3`;
- stores the raw key code in `7Bh`;
- raises key-event flag `24h.4`.

The dispatcher consumes `24h.4` here:

```asm
L58C4:
58C4: 20 5B 03  JB 2Bh.3,L58CA
58C7: 02 3C 5E  LJMP L3C5E
```

`L3C5E` is a state-dependent key dispatcher. In the states checked so far,
`2Eh` and `2Dh` are not special-cased; they fall through the generic path while
the RF preparation from `L5717/L5964` has already happened.

The delayed service path later cancels the RF prep unless another state keeps it
alive:

```asm
L4EE1:
4EE1: 30 33 1C  JNB 26h.3,L4F00
4EE4: D5 54 19  DJNZ 54h,L4F00
4EE7: 20 4B 02  JB 29h.3,L4EEC
4EEA: C2 2E     CLR 25h.6
L4EEC:
4EEC: C2 4B     CLR 29h.3
4EEE: C2 00     CLR 20h.0
4EF0: C2 33     CLR 26h.3
4EF2: E5 64     MOV A,64h
4EF4: B4 03 03  CJNE A,#03h,L4EFA
4EFD: 12 59 31  LCALL L5931
```

Working interpretation:

- `2Eh`/`2Dh` are panel-side PTT events, but the original firmware does not seem
  to branch on those literal values at the first key-handler level.
- The common non-idle key path wakes RF latch logic through `L5964`.
- Actual transition to stable TX is probably caused by the later state machine
  setting flags such as `20h.7`, which reaches `L468A` and `L459D/L45B3`.
- Release/return-to-RX is probably represented by the RX event flags that reach
  `L4648`, `L4600`, `L477E`, `L5977`, and ANT-off/ANT-green panel commands.

## Deeper PTT/RF state trace

The next layer down shows that PTT handling is split into three independent
mechanisms:

1. A front-end panel/key event stores the raw code in `7Bh`.
2. RX/TX state-machine flags choose TX indication, RX indication, or return to
   idle.
3. A separate `25h.2` hardware event applies the current RF/PLL state through
   `L4FD9`.

### TX request path

Many state-machine states handle a one-shot flag `20h.7` as "request TX":

```asm
L18D2:
18D2: 10 07 19  JBC 20h.7,L18EE
...
L18EE:
18EE: 12 46 8A  LCALL L468A
18F1: 12 45 9D  LCALL L459D
```

`L468A` is the high-level TX marker. If `28h.7` is set, it queues panel op
`0Fh`, which later sends `68h` (`ANT orange on`). If `28h.7` is not set, it
does not show orange yet and instead schedules a hardware apply:

```asm
L468A:
468A: 30 47 0E  JNB 28h.7,L469B
L468D:
468D: 75 4A 10  MOV 4Ah,#10h
4690: D2 1F     SETB 23h.7
4695: 79 0F     MOV R1,#0Fh
4697: 12 03 4F  LCALL L034F
...
L469B:
469B: D2 2A     SETB 25h.2
469D: D2 67     SETB 2Ch.7
```

`L459D` is a short TX/RF enable candidate:

```asm
L459D:
459D: 20 50 12  JB 2Ah.0,L45B2
45A0: C2 33     CLR 26h.3
45A2: C2 4B     CLR 29h.3
45A4: D2 2E     SETB 25h.6
45A6: 75 60 05  MOV 60h,#05h
45A9: 75 61 05  MOV 61h,#05h
45AC: 85 60 4E  MOV 4Eh,60h
45AF: 12 59 64  LCALL L5964
```

So a stable TX request appears to be:

```text
20h.7 event
  -> L468A/L468D: show or schedule TX, panel ANT orange path
  -> L459D/L5964: enable RF/mic latch state and start 25h.6 timing
  -> often 25h.2: apply PLL/RF state through L4FD9
```

### RX / return path

The common return-to-RX indicator is one-shot flag `21h.1`:

```asm
L18D2:
18D8: 10 09 24  JBC 21h.1,L18FF
...
L18FF:
18FF: 12 46 48  LCALL L4648
1902: 75 64 02  MOV 64h,#02h
```

`L4648` queues panel op `16h`, which sends `60h` (`ANT off`) and may then send
`69h` (`ANT green on`) if RX is allowed:

```asm
L4648:
4648: C2 67     CLR 2Ch.7
464A: D2 2A     SETB 25h.2
464C: 79 16     MOV R1,#16h
464E: 12 03 4F  LCALL L034F
```

The return-to-RX path usually pairs this with `L5977` or `L477E`:

```asm
L477E:
477E: 12 59 77  LCALL L5977
4781: C2 38     CLR 27h.0
4783: C2 31     CLR 26h.1
...
L5977:
5977: C2 00     CLR 20h.0
5979: C2 2E     CLR 25h.6
```

### PLL application is separate from PTT

`25h.2` is the hardware/PLL apply event. It is set by both TX and RX paths:

- `L469B` after TX request when `28h.7` is not already active.
- `L464A` on RX/return-to-RX.
- `L4982` after channel/current `7Ch` is updated.
- many mode/state transitions around `L16xx..L2Bxx`.

The dispatcher sends `25h.2` here:

```asm
L58BE:
58BE: 02 32 71  LJMP L3271
L58C1:
58C1: 02 4F D9  LJMP L4FD9
```

The useful target for a C rewrite is therefore:

```c
ptt_pressed:
    tx_indicator_or_state_request();   /* L468A/L468D */
    tx_rf_enable_candidate();          /* L459D/L5964 */
    pll_apply_current_channel();       /* L4FD9/L50B3 if needed */

ptt_released:
    tx_rf_disable_candidate();         /* L5977/L477E */
    rx_indicator_or_state_request();   /* L4648/L4600 */
    pll_apply_current_channel();       /* L4FD9/L50B3 if needed */
```

This split explains why `2Eh`/`2Dh` are hard to follow by literal key-code
search: they enter the common event system, while RF effects are controlled by
flags (`20h.7`, `21h.1`, `25h.2`, `25h.6`, `2Ch.7`) and not by repeated raw
comparisons against `2Eh` or `2Dh`.

## RX / ANT green path

The cleanest RX/status marker is operation `16h`.

```asm
L4648:
4648: C2 67     CLR 2Ch.7
464A: D2 2A     SETB 25h.2
464C: 79 16     MOV R1,#16h
464E: 12 03 4F  LCALL L034F
4651: 22        RET
```

Operation `16h` reaches:

```asm
L4BAB:
4BAB: 79 60     MOV R1,#60h
4BAD: 12 03 65  LCALL L0365
4BB0: 30 46 08  JNB 28h.6,L4BBB
4BB3: 20 4F 05  JB 29h.7,L4BBB
4BB6: 79 69     MOV R1,#69h
4BB8: 12 03 65  LCALL L0365
```

Hardware interpretation:

- `L4648` requests a return/update to RX-capable state.
- `L4BAB` first sends `60h` (`ANT off`), then sends `69h` (`ANT green on`) only
  if `28h.6 == 1` and `29h.7 == 0`.
- `28h.6` is therefore a strong "receiver active/green allowed" state flag.
- `29h.7` suppresses green in some special/transient states.

Another direct green path is operation `11h`, normally queued by `L4600` when
`28h.6` is set:

```asm
L4600:
4600: 30 46 0C  JNB 28h.6,L460F
4603: 12 05 77  LCALL L0577
4606: 20 50 0E  JB 2Ah.0,L4617
4609: 79 11     MOV R1,#11h
460B: 12 03 4F  LCALL L034F
...
L460F:
460F: 20 50 05  JB 2Ah.0,L4617
4612: 79 12     MOV R1,#12h
4614: 12 03 4F  LCALL L034F
```

`11h` reaches:

```asm
L4BC7:
4BC7: 79 6C     MOV R1,#6Ch
4BC9: 12 03 65  LCALL L0365
4BCC: 79 69     MOV R1,#69h
4BCE: 12 03 65  LCALL L0365
```

If `28h.6` is clear, `L4600` queues `12h`, which reaches `L4BD4` and sends
`6Dh` then `60h` (`ANT off`).

## RF/PLL latch routines near RX/TX transitions

These are the most relevant low-level hardware-control candidates adjacent to
the RX/TX LED paths:

```asm
L5931:
5931: 20 D1 14  JB PSW.1,L5948
5934: 20 46 11  JB 28h.6,L5948
L5937:
5937: 74 7E     MOV A,#7Eh
5939: 75 90 EE  MOV P1,#0EEh
593C: 12 03 CC  LCALL L03CC
593F: 74 0E     MOV A,#0Eh
5941: 75 90 5E  MOV P1,#5Eh
5944: 12 03 CC  LCALL L03CC
```

```asm
L5948:
5948: 74 8E     MOV A,#8Eh
594A: 75 90 AE  MOV P1,#0AEh
594D: 12 03 CC  LCALL L03CC
5950: 30 55 10  JNB 2Ah.5,L5963
5953: 90 21 8C  MOV DPTR,#218Ch
5956: E0        MOVX A,@DPTR
5957: 54 77     ANL A,#77h
5959: 44 70     ORL A,#70h
595B: C4        SWAP A
595C: 23        RL A
595D: 75 90 5E  MOV P1,#5Eh
5960: 12 03 CC  LCALL L03CC
```

```asm
L5964:
5964: 74 7E     MOV A,#7Eh
5966: 75 90 EE  MOV P1,#0EEh
5969: 12 03 CC  LCALL L03CC
596C: 74 FE     MOV A,#0FEh
596E: 75 90 5E  MOV P1,#5Eh
5971: 12 03 CC  LCALL L03CC
5974: D2 00     SETB 20h.0
```

```asm
L5977:
5977: C2 00     CLR 20h.0
5979: C2 2E     CLR 25h.6
597B: 22        RET
```

`L5931/L5937/L5948/L5964/L5977` are high-priority RF/PLL-control candidates
because they are repeatedly called immediately before or after RX/TX state
changes, and they write external latch states through `P1` + `P3.5` (`L03CC`).

New schematic/continuity clue:

- `MN13` Port4.0 drives `OPE`, the RF power/amplifier enable.
- `MN13` Port4.2 drives `BLM`, the microphone/audio-to-VCO gate.
- `MN13` Port4.3 drives MC145156 PLL `ENR`.
- `MN13` Port7.0 is `STN_V`, PLL lock status.
- `MN13` Port7.1 is `ALT_T`, the active-low PTT/accessory TX request.
- `MN13` Port7.3 is `DP`, carrier detect.
- Therefore TX enable is split across the same `MN13` writes: PLL load/control,
  RF enable, and microphone/audio gate are distinct bits and should be sequenced
  deliberately.
- `BFEM` is the microphone-amplifier audio path and `BFETCS` is the
  external/accessory audio path; these are mixed before modulation. They are
  modulation/audio clues, not primary PA-power clues.
- When comparing RX and TX latch sequences, watch the values sent to `MN13`
  around `L5937`, `L5948`, `L5964`, and the TX path around `L4DE5..L4E0E`.

Safe replacement-firmware sequence from the logic-board notes:

1. TX: handle active-low `ALT_T`, program/apply the TX PLL word, wait for
   `STN_V`, then enable `OPE`, then enable `BLM` for the BFEM/BFETCS
   modulation-audio path.
2. RX: disable `BLM`, disable `OPE`, program/apply the RX PLL word, wait for
   `STN_V`, then open RX audio only when `DP` indicates carrier.
3. Carrier/squelch: read `MN13` Port7 repeatedly. The base C firmware now uses
   three reads and a majority vote before reacting to `DP`.

## Working hypotheses

- `L468A/L468D` = request TX/active transmit indication; queues panel op `0Fh`
  and leads to `ANT orange`.
- `L45B3` / `L5964` / `L4DE5` = TX/RF/microphone enable or TX timing support.
- `L4648` = request RX/return-to-receive indication; queues panel op `16h`.
- `L4600` = choose RX-green vs ANT-off state based on `28h.6`.
- `28h.6` = RX-active/green-allowed flag candidate.
- `29h.7` = special/transient state that suppresses `ANT green`.
- `L5931/L5937/L5948/L5964/L5977` = RF/PLL latch-control cluster.
