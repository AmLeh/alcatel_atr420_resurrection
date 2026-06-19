# Replacement firmware HAL draft

This is a first draft of the low-level API for a clean firmware. Names are provisional until the board signals are confirmed with schematic or probing.

## Pin map, current hypothesis

| Signal | 8051 pin/SFR bit | Direction | Current role |
| --- | --- | --- | --- |
| `LATCH_BUS` | `P1` | out/in | Shared external control bus. |
| `LATCH_STB` | `P3.5` | out | Active-low strobe/select for latch/bus transfers. |
| `SYNC_FRAME` | `P1.1` | out | Framing/select for synchronous peripheral. |
| `SYNC_CLK` | `P1.2` | out | Clock/ack line for synchronous peripheral. |
| `SYNC_DATA` | `P1.3` | out/in | Data line for synchronous peripheral. |
| `SYNC_READY` | `P3.4` | in | Ready/ack line from synchronous peripheral. |
| `TICK_OUT` | `P3.2` | out | Toggled by Timer0 ISR when enabled. |
| `UART_RXTX` | `SBUF/SCON` | in/out | Serial interface, role still unknown. |

Panel hardware note:

- Panel MCU is marked `IP-80C51643`.
- Keyboard, indicator LEDs, and the display subsystem are connected to this panel MCU, not directly to the main CPU.
- Display driver is National Semiconductor `COP370` for VFD/LED display.
- Demo firmware should therefore talk to the panel MCU protocol first. Direct `COP370` control is a separate fallback path only if the panel MCU is bypassed.

## Minimal primitives to reproduce first

### Latch write

Original routine: `L03CC`.

```c
void latch_write(uint8_t value)
{
    P3_5 = 0;
    P1 = value;
    P3_5 = 1;
}
```

Most original call sites prepare `P1` and `A` separately, then call `L03CC`; because `L03CC` only writes `A` into `P1`, the previous `MOV P1,#xx` is probably part of the external bus select phase. A safer replacement primitive may need to preserve that two-phase behavior:

```c
void latch_command(uint8_t select, uint8_t value)
{
    P1 = select;
    latch_write(value);
}
```

### Latch read nibble

Original routine: `L03BF`.

```c
uint8_t latch_read_nibble(uint8_t select)
{
    P1 = select;
    P3_5 = 0;
    P1 |= 0xF0;
    uint8_t value = (P1 >> 4) & 0x0F;
    P3_5 = 1;
    return value;
}
```

### Synchronous byte send

Original routine: `L598E`.

```c
void sync_send_byte(uint8_t value)
{
    P1_1 = 0;
    nop(); nop(); nop(); nop();
    P1_1 = 1;

    for (uint8_t i = 0; i < 8; i++) {
        P1_3 = value & 1;
        P1_2 = 0;
        value = rotate_right(value);
        while (P3_4) {}
        P1_2 = 1;
        while (!P3_4) {}
    }

    P1_3 = 1;
    delay_short();
}
```

### Synchronous nibble receive

Original setup starts at `L58DC`; bit loop starts at `L58E1`.

```c
bool sync_recv_nibble(uint8_t *out)
{
    for (uint8_t retry = 0; retry < 5; retry++) {
        uint8_t value = 0;
        for (uint8_t i = 0; i < 4; i++) {
            if (P3_4) {
                break;
            }
            value = rrc_with_bit(value, P1_3);
            P1_2 = 0;
            while (!P3_4) {}
            P1_2 = 1;
        }
        *out = value & 0x0F;
        return true;
    }
    return false;
}
```

This pseudocode preserves protocol shape, not exact compiler output. Timing may matter and should be validated on real hardware.

### Display character encoding

Original routine: `L49E6`. Tables: `498Ch` and `49B9h`.

The original firmware converts ASCII-like characters into panel/display codes before
building command bytes. The confirmed input alphabet is:

```text
 ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789r*=<>/+-
```

The first demo should reuse this mapping instead of sending raw ASCII to the
panel MCU.

```c
uint8_t display_encode_char(char ch)
{
    static const char in[] = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789r*=<>/+-";
    static const uint8_t out[] = {
        0x24, 0x0A, 0x25, 0x10, 0x0D, 0x0E, 0x27, 0x0C,
        0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
        0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20,
        0x21, 0x22, 0x23, 0x00, 0x01, 0x02, 0x03, 0x04,
        0x05, 0x06, 0x07, 0x08, 0x09, 0x0F, 0x28, 0x29,
        0x2A, 0x2B, 0x2C, 0x2D, 0x0B
    };

    for (uint8_t i = 0; i < sizeof(in) - 1; i++) {
        if (in[i] == ch) {
            return out[i];
        }
    }
    return 0x24;
}
```

Panel packet candidates are documented in `DISPLAY_PROTOCOL_CANDIDATES.md`. The
first practical test should try known command-shaped byte sequences from
`2E1Eh..2EA7h`, then variants where encoded characters are sent as
`0x30 | code`, `0x40 | code`, and `0x50 | code`.

Update after display-path pass:

- The strongest full-string display candidate is now `L4B07 -> queue 36h -> L4CFD -> SBUF`.
- The demo firmware sends `78h` plus 8 encoded characters in the same order as
  `L4B07`: `char7, char3, char6, char2, char5, char1, char4, char0`.
- UART RX is also a keyboard/input candidate: original ISR `L59B8` queues
  received `SBUF` bytes at RAM `33h`, and `L568F` consumes them as command/key-like codes.
- The synchronous `L58DC/L58E1` path remains a second input candidate and returns
  a 4-bit value.

## Startup sequence candidate

The apparent startup sequence begins at `0026h`, but reset vector `0000h` is a self-loop in this dump. Before producing a bootable replacement image, confirm one of these:

- EPROM is banked/remapped and `0000h` in this HEX is not the CPU reset window.
- Original MCU starts from a different external address because of board glue logic.
- The dump is patched/corrupted at reset vector.
- The intended entry is manually jumped to by another controller.

Until this is known, a custom firmware image should not assume that copying the old vector table is enough.

## First bring-up firmware idea

1. Set all ports to inactive states:
   - `P1 = FFh`
   - `P3.5 = 1`
   - `P1.1 = 1`
   - `P1.2 = 1`
   - `P1.3 = 1`
2. Configure Timer0/Timer1/UART like the original `026Fh` block.
3. Run the original early latch command sequence from `0037h..0069h`, but with delays between commands for probing.
4. Toggle `P3.2` at a visible/testable rate.
5. Implement `sync_send_byte`/`sync_recv_nibble` and test whether external hardware responds on `P3.4`.
6. Only after pin behavior is confirmed, replace magic latch pairs with named operations.

## Minimal event model

The original firmware uses bit-addressable internal RAM as an event bus. A clean firmware can represent the first useful subset as named flags:

```c
enum event_flag {
    EV_SYNC_RX_READY,       // original 20h.3
    EV_TICK_5,              // original 20h.1
    EV_SYNC_TX_PENDING,     // original 20h.2
    EV_UART_SERVICE,        // original 24h.0
    EV_LATCH_STATUS_READ,   // original 25h.1
    EV_APPLY_HW_STATE,      // original 25h.2
    EV_MODE_UPDATE,         // original 24h.3
};
```

Initial replacement event loop:

```c
for (;;) {
    if (events & EV_SYNC_RX_READY) {
        events &= ~EV_SYNC_RX_READY;
        sync_recv_nibble(&last_sync_nibble);
    }

    if (events & EV_TICK_5) {
        events &= ~EV_TICK_5;
        service_periodic_timers();
    }

    if (events & EV_SYNC_TX_PENDING) {
        uint8_t b = sync_next_tx_byte();
        if (b != 0xFF) {
            sync_send_byte(b);
        } else {
            events &= ~EV_SYNC_TX_PENDING;
        }
    }

    if (events & EV_UART_SERVICE) {
        events &= ~EV_UART_SERVICE;
        service_uart();
    }

    if (events & EV_LATCH_STATUS_READ) {
        events &= ~EV_LATCH_STATUS_READ;
        uint8_t status = latch_read_nibble(0x3E);
        update_status_from_latch(status);
    }

    if (events & EV_APPLY_HW_STATE) {
        events &= ~EV_APPLY_HW_STATE;
        apply_radio_outputs();
    }

    if (events & EV_MODE_UPDATE) {
        events &= ~EV_MODE_UPDATE;
        update_mode_state();
    }
}
```

Timer0 should set `EV_TICK_5` every 5 ticks, matching original byte `19h`, and set `EV_SYNC_RX_READY` only when the sync bus is idle and `P3.4` is in the expected state.
