# Documentation Index

This project is still evolving, so most reverse-engineering notes currently
live in the repository root. This index groups the most useful files by topic.

## Hardware

- [`../HARDWARE_RE.md`](../HARDWARE_RE.md) - main hardware notes.
- [`../SCHEMA_ANALYSIS.md`](../SCHEMA_ANALYSIS.md) - schematic-derived notes.
- [`../RF_PROBING_PLAN.md`](../RF_PROBING_PLAN.md) - oscilloscope and logic
  analyzer capture plan.

## Firmware Reverse Engineering

- [`../PLL_PROGRAMMING_PATH.md`](../PLL_PROGRAMMING_PATH.md) - MC145156 PLL
  programming routine and signal mapping.
- [`../RF_RX_TX_PATHS.md`](../RF_RX_TX_PATHS.md) - receive/transmit control
  path candidates.
- [`../DISPLAY_PROTOCOL_CANDIDATES.md`](../DISPLAY_PROTOCOL_CANDIDATES.md) -
  display/front-panel protocol notes.
- [`../FIRMWARE_HAL_DRAFT.md`](../FIRMWARE_HAL_DRAFT.md) - draft abstraction
  layer for replacement firmware.

## Generated Analysis Tables

- [`../CALL_GRAPH.csv`](../CALL_GRAPH.csv)
- [`../EVENT_DISPATCH.csv`](../EVENT_DISPATCH.csv)
- [`../EVENT_FLAG_XREF.csv`](../EVENT_FLAG_XREF.csv)
- [`../LATCH_COMMANDS.csv`](../LATCH_COMMANDS.csv)
- [`../MOVX_ACCESS.csv`](../MOVX_ACCESS.csv)
- [`../ST_M2732A_USED_BY_MAIN.csv`](../ST_M2732A_USED_BY_MAIN.csv)

## Replacement Firmware

- [`../firmware/README.md`](../firmware/README.md)
- [`../firmware/current/alcatel3558_firmware.c`](../firmware/current/alcatel3558_firmware.c)
- [`../firmware/tests/`](../firmware/tests)
