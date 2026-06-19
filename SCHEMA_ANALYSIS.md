# ATR420/ATR421 schematic notes

Source schematic:

```text
schema/SchemaATR421_HD.png
```

Image size: `10413 x 6818`.

The front panel on the station is marked:

```text
ALCATEL RADIOTELEPHONE
Made in France
ATR 420
03/94
```

The schematic file name says `ATR421`; treat it as the same family until any
hardware differences are found.

Generated working crops:

| Crop | Content |
| --- | --- |
| `schema/crops/top_rf_radio_module.png` | RF/radio module overview |
| `schema/crops/right_tx_module.png` | transmit module overview |
| `schema/crops/bottom_logic_module.png` | logic module overview |
| `schema/crops/logic_cpu_memory.png` | CPU, EPROM, personalization ROM, RAM |
| `schema/crops/rf_pll_control_inputs.png` | PLL control inputs and 54LS09 gates |
| `schema/crops/rf_pll_mc145156_wide.png` | PLL, prescaler, VCO/control area |
| `schema/crops/rf_pll_w1_connector_pins.png` | W1 flexible cable pins for PLL control |

## Logic module

Confirmed devices on the logic schematic:

| Designator | Part | Role |
| --- | --- | --- |
| `MN1` | `uP 8031AH` | main CPU |
| `MN2` | `74HC373` | address/data latch |
| `MN3` | `27256` | program EPROM, marked `EPROM GESTION` |
| `MN4` | `2732` | personalization/config EPROM, marked `EPROM PERSONALISATION` |
| `MN5` | `HM3 6544` | RAM |
| `MN3/MN4` on left side | `8243` | I/O expanders |

The schematic confirms the project interpretation that `ST_M27256.HEX` is the
main program EPROM and `ST_M2732A.HEX` is personalization/config data.

## PLL/RF module

Confirmed PLL-related devices:

| Designator | Part | Role |
| --- | --- | --- |
| `MN01` | `MC145156P` | PLL synthesizer |
| `MN02` | `MC12016-P` | prescaler |
| `MN03` | `54LS09` | open-collector AND gates driving PLL control inputs |
| `YO2` | crystal/reference oscillator network | PLL reference |

The schematic labels the MC145156P control pins directly:

| MC145156P signal | Pin | Driven through |
| --- | ---: | --- |
| `clock` | `11` | `MN03` 54LS09 output pin `3` |
| `data` | `12` | `MN03` 54LS09 output pin `6` |
| `EN` | `13` | `MN03` 54LS09 output pin `11` |
| `Ref` | `17` | `YO2` reference network |
| `E/R` | `14` | loop/filter/control network |

The CPU-side/flexible-cable input names before `MN03` are:

| Signal | W1 pin | MN03 pins | MC145156P destination |
| --- | ---: | --- | --- |
| `CLK` | `8` | input pin `2`, output pin `3` | `clock`, pin `11` |
| `DS` | `2` | inputs pins `4/5`, output pin `6` | `data`, pin `12` |
| `E` | `7` | inputs pins `12/13`, output pin `11` | `EN`, pin `13` |

Continuity tracing to the logic board gives the CPU/expander side of those
signals:

| MC145156P signal | Source pin | Firmware-visible mechanism |
| --- | --- | --- |
| `clock`, pin `11` | 8031 pin `16`, `P3.6` / `/WR` | `MOVX @R0,A` write strobe |
| `data`, pin `12` | 8031 pin `13`, `P3.3` | direct `SETB/CLR P3.3` |
| `EN`, pin `13` | 8243 pin `5`, `P43` | external-port/latch write through `L03CC` |

The enable-side 8243 is schematic `MN13`. It is controlled by 8031 pins
`5..8` (`P1.4..P1.7`) plus the 8243 strobe line. Its chip select is 8031 pin
`1` (`P1.0`). The second 8243, `MN14`, uses the same `P1.0` through an inverter,
so `P1.0` selects which expander is addressed.

The matching original firmware routine is documented in
`PLL_PROGRAMMING_PATH.md`. The key routine is `L50B3`: it sets/clears `P3.3`
for the data bit, then uses `MOVX @R0,A` to pulse `/WR` on `P3.6` as the PLL
clock.

This supersedes the earlier "P1.1/P1.2/P1.3/P3.4 as PLL" hypothesis for the
main MC145156 programming path. Those CPU pins may still be used for another
sync interface, but PLL programming should first be captured on `CLK`, `DS`,
and `E`.

## Practical probing update

Best points for frequency-programming capture:

1. `W1 pin 8` / `CLK`, or 8031 pin `16` / `P3.6` / `/WR`.
2. `W1 pin 2` / `DS`, or 8031 pin `13` / `P3.3`.
3. `W1 pin 7` / `E`, or 8243 pin `5` / `P43`.
4. Ground.

Alternative points:

1. `MN03` output pin `3` -> MC145156P pin `11 clock`.
2. `MN03` output pin `6` -> MC145156P pin `12 data`.
3. `MN03` output pin `11` -> MC145156P pin `13 EN`.

The `MN03` outputs are open-collector style through `54LS09`; if the waveform
looks inverted or pull-up-limited, compare both the W1 input side and the
MC145156P side.

## Immediate code correlation

The earlier continuity checks match the schematic:

| Previous continuity result | Schematic confirmation |
| --- | --- |
| MC145156 pin `11` to SN54LS09 pin `3` | `clock` via `MN03` output `3` |
| MC145156 pin `12` to SN54LS09 pin `6` | `data` via `MN03` output `6` |
| MC145156 pin `13` to SN54LS09 pin `11` | `EN` via `MN03` output `11` |

Next reverse-engineering target:

- trace W1 `CLK/DS/E` back through the logic/interconnection sheet to the CPU
  or I/O expander pins;
- then match those lines to the original firmware latch writes around
  `L5931/L5937/L5964/L5977` and the RX/TX paths in `RF_RX_TX_PATHS.md`.
