# ATR42x logic-board findings from Shibby's notes

Source: Shibby's ATR42x reverse-engineering article and linked logic-board
analysis:
<https://blog.shibby.fr/2017/10/alcatel-atr42x-la-resurrection/>

This file records the project-specific conclusions we use in the replacement
firmware. It deliberately does not copy the third-party document text.

## 8243 expanders

The logic board uses two Intel 8243-compatible 4-bit I/O expanders:

- `MN13`: RF, PLL, audio routing, and internal status signals.
- `MN14`: accessory/option-card signals.

Both are driven through the 8031 `P1.4..P1.7` nibble bus and `P3.5` strobe.
`P1.0` selects which expander is active: `MN13` directly, `MN14` through an
inverter.

The useful command nibbles seen in the original source and notes are:

| Command byte | Meaning |
| ---: | --- |
| `0x3E` | read `MN13` Port 7 |
| `0x4E` | write `MN13` Port 4 |
| `0x5E` | write `MN13` Port 5 |
| `0x6E` | write `MN13` Port 6 |
| `0x7E` | write `MN13` Port 7 |
| `0x8E` | OR `MN13` Port 4 |
| `0xCE` | AND `MN13` Port 4 |

The value nibble is carried in the high half of the following `P1` write; the
low half remains the expander-select suffix.

## `MN13` signal map

| Port bit | Signal | Direction | Firmware use |
| ---: | --- | --- | --- |
| P4.0 | `OPE` | output | RF power/amplifier enable |
| P4.2 | `BLM` | output | microphone/audio-to-VCO gate |
| P4.3 | `ENR` | output | PLL enable/load pulse |
| P5.1 | `BF1` | output | speaker-volume mux bit |
| P5.2 | `BF2` | output | speaker-volume mux bit |
| P5.3 | `BF3` | output | speaker-volume mux bit |
| P6.1 | `BBF3` | output | telephone-line TX audio gate |
| P6.2 | `BBF2` | output | RX audio to telephone line |
| P6.3 | `BBF1` | output | RX audio to speaker/front panel |
| P7.0 | `STN_V` | input | PLL lock status |
| P7.1 | `ALT_T` | input | PTT/accessory TX request, active low |
| P7.3 | `DP` | input | carrier detect, high when carrier is present |

`INFO EM` is also present on P7.2 on some variants, but we do not currently use
it in the base firmware.

## TX audio/modulation path

Schematic tracing separates RF power control from modulation audio:

- `BFEM` comes from the microphone amplifier;
- `BFETCS` comes from the external/accessory audio source;
- the two paths are mixed before the modulation path.

Therefore `BFEM`/`BFETCS` and `BLM` should be treated as audio/modulation
controls. They are needed for modulated TX audio, but they should not be used as
the primary explanation for a missing or weak unmodulated RF carrier.

## PLL behavior

The `MC145156P` path is:

- data: 8031 `P3.3`;
- clock: external-memory `/WR` pulse on 8031 `P3.6`, generated with `MOVX`;
- load/enable: `MN13` Port4 bit 3 (`ENR`).

The observed programming burst is 19 bits, followed by an `ENR` pulse.

Important hardware-variant warning: some radio cards use an `MC145158-2`
daughter implementation instead of the `MC145156P`. The two PLLs do not use the
same programming dialogue, so replacement firmware must eventually make PLL
type an explicit hardware profile.

## Safe RX/TX ordering

For TX:

1. react to active-low `ALT_T`;
2. program/apply the TX PLL word and wait for `STN_V`;
3. enable RF with `OPE`;
4. only then enable microphone/external TX audio with `BLM`.

For RX:

1. disable microphone audio with `BLM`;
2. disable RF power/amplifier drive with `OPE`;
3. program/apply the RX PLL word and wait for `STN_V`;
4. open RX audio only when `DP` indicates carrier.

This avoids feeding audio or RF power while the synthesizer is being retuned.

## Carrier detect and squelch

`DP` is read through `MN13` Port7 bit 3. The original logic performs repeated
Port7 reads; the replacement firmware should use at least three reads before
treating `DP`/`ALT_T`/`STN_V` as stable.

When `DP` becomes active, RX audio can be opened by setting `BBF1` and/or
`BBF2`, then restoring the selected speaker volume on `BF1..BF3`. When carrier
disappears, close `BBF1/BBF2` and set volume to zero/mute.

The squelch threshold itself is analog on the RF board; firmware only reacts to
the resulting carrier-detect signal.

## Front panel confirmation

The logic-board notes match our panel implementation:

- command `0x78` writes a full 8-character SC20 display line;
- after `0x78`, the panel consumes characters in physical order
  `7, 3, 6, 2, 5, 1, 4, 0`;
- the panel reports unknown commands with an error byte such as `0x41`.
