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

- `MN13` 8243 pin `5` / `P43` drives MC145156 PLL `EN`.
- `MN13` 8243 pin `4` controls microphone enable, likely `P42` if the adjacent
  8243 port pin mapping is confirmed.
- Therefore TX enable is probably split across the same `MN13` writes: one bit
  for PLL load/control and one bit for microphone/audio path enable.
- When comparing RX and TX latch sequences, watch the values sent to `MN13`
  around `L5937`, `L5948`, `L5964`, and the TX path around `L4DE5..L4E0E`.

## Working hypotheses

- `L468A/L468D` = request TX/active transmit indication; queues panel op `0Fh`
  and leads to `ANT orange`.
- `L45B3` / `L5964` / `L4DE5` = TX/RF/microphone enable or TX timing support.
- `L4648` = request RX/return-to-receive indication; queues panel op `16h`.
- `L4600` = choose RX-green vs ANT-off state based on `28h.6`.
- `28h.6` = RX-active/green-allowed flag candidate.
- `29h.7` = special/transient state that suppresses `ANT green`.
- `L5931/L5937/L5948/L5964/L5977` = RF/PLL latch-control cluster.
