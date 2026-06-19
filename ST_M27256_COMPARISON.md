# ST_M27256 vs ST_M27256_2 comparison

Purpose: compare the newly added original firmware dump `ST_M27256.HEX` with the
previous dump `ST_M27256_2.HEX`.

## Result

The two 32 KiB images differ by exactly one byte.

| Address | `ST_M27256.HEX` | `ST_M27256_2.HEX` | Meaning |
| ---: | ---: | ---: | --- |
| `0002h` | `26h` | `00h` | Reset vector target low byte |

Therefore:

- `ST_M27256.HEX` has a valid reset vector: `0000h: LJMP 0026h`.
- `ST_M27256_2.HEX` has a broken reset vector: `0000h: LJMP 0000h`.
- All other bytes are identical.

## First bytes

Known-good `ST_M27256.HEX`:

```text
0000: 02 00 26 00 00 00 0D 0C 10 03 06 02 59 EF 00 00
```

Previous `ST_M27256_2.HEX`:

```text
0000: 02 00 00 00 00 00 0D 0C 10 03 06 02 59 EF 00 00
```

## Correct vector table

```asm
0000:  02 00 26  LJMP L0026
000B:  02 59 EF  LJMP L59EF
0023:  02 59 B8  LJMP L59B8
0026:  90 04 64  MOV DPTR,#0464h
```

## Consequences for the project

The earlier conclusion that the board might not execute external code from
`0000h` was based on the damaged `ST_M27256_2.HEX` reset vector. With the
known-good dump, normal 8051 reset execution is expected:

```text
reset -> 0000h -> LJMP 0026h -> startup code
```

For future reverse engineering, use `ST_M27256.HEX`, `ST_M27256.bin`, and
`ST_M27256.asm` as the reference firmware.

`ST_M27256_2.HEX` is still useful because it is otherwise byte-identical, but it
should not be used as the boot reference unless byte `0002h` is corrected to
`26h`.

## Generated files

- `ST_M27256.bin` - binary image generated from `ST_M27256.HEX`.
- `ST_M27256.asm` - 8051 disassembly generated from `ST_M27256.HEX`.
