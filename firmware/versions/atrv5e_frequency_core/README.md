# ATRV5E frequency-core fork

Status: deprecated / not the current base.

This branch is kept as a historical experiment only. On the tested station its
HEX builds did not boot reliably, including builds published as
`ALCATEL3558_ATRV5E_FREQUENCY_CORE.HEX` and
`ALCATEL3558_FREE_FREQ_STARTUP_FIX.HEX`. Use
`firmware/current/alcatel3558_firmware.c` instead.

Experimental fork of `firmware/current` that ports only the parts of
`ATRV5E.A51` which match the unmodified station hardware:

- 19-bit MC145156 word: `SW1 SW2 N9..N0 A6..A0`;
- 12.5 kHz reference/step;
- MC12016 prescaler, so the PLL dual-modulus ratio is `40/41`;
- RX synthesizer frequency with a 21.4 MHz IF;
- TX synthesizer frequency;
- optional -600 kHz repeater shift;
- direct seven-digit frequency entry;
- fast UART-keyboard polling without the old per-loop delay;
- BELL LED indication from the PLL `LOCK/STN_V` status bit.

The fork deliberately keeps the PLL enable/load transaction recovered from
the station's original ROM. It does not copy ATRV5E's direct LCD, keyboard,
audio, squelch, or P43 wiring, because those belong to the modified radio.
It also does not yet enable the full transmitter power path: PTT/APPEL changes
the PLL word, asserts PLL `SW1`, and changes the panel indication. This is
enough to reproduce the confirmed 144.000 MHz low-level carrier, but the
missing PA-enable/audio/modulation path is still under investigation.

## Controls

- `*`: frequency -12.5 kHz;
- `#`: frequency +12.5 kHz;
- `DIVA`: toggle simplex / -600 kHz repeater mode;
- digits: enter seven frequency digits, for example `1455750`;
- PTT or `APPEL`: program the same TX PLL word;
- PTT/APPEL release: restore the RX PLL word;
- `BELL` LED: follows PLL lock (`LOCK/STN_V`) when RX/TX words are programmed;
- `ON/OFF`: use the existing shutdown path.

The panel character map has no confirmed decimal-point code, so `145.5750`
is displayed as `145 5750`.

## PLL calculation

The station hardware has an `MC12016` prescaler. Therefore:

```text
Ntotal = N * 40 + A
0 <= A < 40
PLL frequency = Ntotal * 12.5 kHz
```

For example, `144.000 MHz` gives:

```text
Ntotal = 144000 / 12.5 = 11520
N = 11520 / 40 = 288
A = 11520 % 40 = 0
```

`SW1` is MC145156 pin 14 and has been traced to the station's `CER` line
(`Commande Emission/Reception`). CER feeds the antenna/RF switching chain and
also drives several transistor stages in the TX module. `SW2` is MC145156 pin
15 and is still not used by the inspected board.

The MC145156 switch outputs are open-drain: a programmed `1` releases the line
to its external pull-up, while a programmed `0` pulls it low. Use
`SW1=0, SW2=0` for RX and `SW1=1, SW2=0` for TX.

## Build

```powershell
python .\firmware\build_atrv5e_frequency_core.py
```

Output:

```text
firmware/build/ALCATEL3558_ATRV5E_FREQUENCY_CORE.HEX
```

The old builds of this branch that held 8031 `P1.0` high are known not to boot
on the station. Later builds used the same short low-high P1.0 service pulse
as the working recovery/probe firmware, but this branch still remains
non-current and was not promoted after hardware testing. For bench testing,
the build is also copied as:

```text
firmware/build/ALCATEL3558_FREE_FREQ_STARTUP_FIX.HEX
```
