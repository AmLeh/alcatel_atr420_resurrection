# ATRV5E frequency-core fork

Experimental fork of `firmware/current` that ports only the parts of
`ATRV5E.A51` which match the unmodified station hardware:

- 19-bit MC145156 word: `SW1 SW2 N9..N0 A6..A0`;
- 12.5 kHz reference/step;
- RX synthesizer frequency with a 21.4 MHz IF;
- TX synthesizer frequency;
- optional -600 kHz repeater shift;
- direct seven-digit frequency entry.

The fork deliberately keeps the PLL enable/load transaction recovered from
the station's original ROM. It does not copy ATRV5E's direct LCD, keyboard,
audio, squelch, or P43 wiring, because those belong to the modified radio.
It also does not enable the transmitter power path: PTT/APPEL currently changes
the PLL word and panel indication only.

## Controls

- `*`: frequency -12.5 kHz;
- `#`: frequency +12.5 kHz;
- `DIVA`: toggle simplex / -600 kHz repeater mode;
- digits: enter seven frequency digits, for example `1455750`;
- PTT or `APPEL`: program the same TX PLL word;
- PTT/APPEL release: restore the RX PLL word;
- `ON/OFF`: use the existing shutdown path.

The panel character map has no confirmed decimal-point code, so `145.5750`
is displayed as `145 5750`.

## Build

```powershell
python .\firmware\build_atrv5e_frequency_core.py
```

Output:

```text
firmware/build/ALCATEL3558_ATRV5E_FREQUENCY_CORE.HEX
```
