typedef unsigned char u8;
typedef unsigned int u16;

#define PANEL_KEY_ON_OFF 0x60
#define PANEL_KEY_PTT_PRESSED 0x2E
#define PANEL_KEY_PTT_RELEASED 0x2D
#define PANEL_KEY_APPEL 0x04

#define PANEL_KEY_0 0x00
#define PANEL_KEY_1 0x06
#define PANEL_KEY_2 0x05
#define PANEL_KEY_3 0x03
#define PANEL_KEY_4 0x0F
#define PANEL_KEY_5 0x11
#define PANEL_KEY_6 0x12
#define PANEL_KEY_7 0x14
#define PANEL_KEY_8 0x18
#define PANEL_KEY_9 0x16

#define PANEL_IO_ANT_OFF 0x60
#define PANEL_IO_ANT_ORANGE_ON_A 0x61
#define PANEL_IO_SPEAKER_OFF 0x62
#define PANEL_IO_SPEAKER_ON 0x63
#define PANEL_IO_KEY_OFF 0x64
#define PANEL_IO_KEY_ON 0x65
#define PANEL_IO_BELL_OFF 0x66
#define PANEL_IO_BELL_ON 0x67
#define PANEL_IO_ANT_ORANGE_ON_B 0x68
#define PANEL_IO_ANT_GREEN_ON 0x69

__sfr __at(0x80) P0;
__sfr __at(0x87) PCON;
__sfr __at(0x88) TCON;
__sfr __at(0x89) TMOD;
__sfr __at(0x8A) TL0;
__sfr __at(0x8B) TL1;
__sfr __at(0x8C) TH0;
__sfr __at(0x8D) TH1;
__sfr __at(0x90) P1;
__sfr __at(0x98) SCON;
__sfr __at(0x99) SBUF;
__sfr __at(0xA0) P2;
__sfr __at(0xA8) IE;
__sfr __at(0xB0) P3;
__sfr __at(0xB8) IP;

__sbit __at(0x8D) TF0;
__sbit __at(0x90) P1_0;
__sbit __at(0x91) P1_1;
__sbit __at(0x98) RI;
__sbit __at(0x99) TI;
__sbit __at(0xA9) ET0;
__sbit __at(0xAF) EA;
__sbit __at(0xB0) P3_0;
__sbit __at(0xB2) P3_2;
__sbit __at(0xB3) P3_3;
__sbit __at(0xB5) P3_5;

#define XBYTE(addr) (*(volatile __xdata u8 *)(addr))

static volatile u8 hardware_watchdog_divider;
static volatile u8 hardware_p32_divider;
static volatile u8 io8243_busy;

static void tiny_delay(void)
{
    __asm
        nop
        nop
        nop
        nop
    __endasm;
}

static void short_delay(void)
{
    volatile u16 i;

    for (i = 0; i < 800; i++) {
    }
}

static void hardware_watchdog_service(void)
{
    if (io8243_busy) {
        return;
    }

    P1_0 = !P1_0;
    P3_0 = 1;
    SCON |= 0x10;
    P1_0 = !P1_0;
}

void timer0_isr(void) __interrupt(1) __using(1)
{
    if (hardware_p32_divider == 0) {
        hardware_p32_divider = 6;
    }

    hardware_p32_divider--;
    if (hardware_p32_divider == 0) {
        hardware_p32_divider = 6;
        P3_2 = !P3_2;
    }

    if (hardware_watchdog_divider == 0) {
        hardware_watchdog_divider = 50;
    }

    hardware_watchdog_divider--;
    if (hardware_watchdog_divider == 0) {
        hardware_watchdog_divider = 50;
        hardware_watchdog_service();
    }
}

static void hardware_watchdog_start(void)
{
    hardware_p32_divider = 6;
    hardware_watchdog_divider = 50;
    TF0 = 0;
    ET0 = 1;
    EA = 1;
}

static void latch_write(u8 select, u8 value)
{
    u8 old_ea = EA;

    EA = 0;
    io8243_busy = 1;
    P1 = select;
    tiny_delay();
    P3_5 = 0;
    tiny_delay();
    P1 = value;
    tiny_delay();
    P3_5 = 1;
    tiny_delay();
    io8243_busy = 0;
    EA = old_ea;
}

static u8 latch_read_nibble(u8 select)
{
    u8 value;
    u8 old_ea = EA;

    EA = 0;
    io8243_busy = 1;
    P1 = select;
    tiny_delay();
    P3_5 = 0;
    P1 |= 0xF0;
    value = (P1 >> 4) & 0x0F;
    P3_5 = 1;
    io8243_busy = 0;
    EA = old_ea;
    return value;
}

static void pll_clock_pulse_movx(void)
{
    __asm
        mov r0,#0x00
        mov a,#0x00
        movx @r0,a
    __endasm;
}

static void pll_send_bit(u8 bit_value)
{
    P3_3 = bit_value ? 1 : 0;
    tiny_delay();
    pll_clock_pulse_movx();
    tiny_delay();
}

static void pll_original_preload_candidate(void)
{
    latch_write(0xCE, 0x7E);
    latch_write(0x8E, 0x1E);
}

static void pll_original_postload_candidate(void)
{
    latch_write(0x8E, 0x8E);
    latch_write(0xCE, 0x7E);
}

static void pll_shift_candidate_word(u8 r4, u8 r3, u8 r2, u8 mode_bit)
{
    u8 i;

    P2 = 0x00;

    if (mode_bit) {
        pll_send_bit(1);
        pll_send_bit(0);
    } else {
        pll_send_bit(0);
        pll_send_bit(0);
    }

    pll_send_bit((r4 >> 1) & 1);
    pll_send_bit(r4 & 1);

    for (i = 0; i < 8; i++) {
        pll_send_bit((r3 & 0x80) != 0);
        r3 <<= 1;
    }

    for (i = 0; i < 8; i++) {
        pll_send_bit((r2 & 0x40) != 0);
        r2 <<= 1;
    }

    P3_3 = 0;
}

static void pll_program_candidate_digit(u8 digit)
{
    u8 r4;
    u8 r3;
    u8 r2;
    u16 candidate;

    candidate = (u16)(0x0100 + ((u16)digit * 0x25));
    r4 = (u8)((candidate >> 10) & 0x03);
    r3 = (u8)((candidate >> 2) & 0xFF);
    r2 = (u8)((candidate & 0x03) << 5);

    pll_original_preload_candidate();
    pll_shift_candidate_word(r4, r3, r2, 0);
    pll_original_postload_candidate();
}

static u8 panel_key_to_digit(u8 key)
{
    switch (key) {
    case PANEL_KEY_0: return 0;
    case PANEL_KEY_1: return 1;
    case PANEL_KEY_2: return 2;
    case PANEL_KEY_3: return 3;
    case PANEL_KEY_4: return 4;
    case PANEL_KEY_5: return 5;
    case PANEL_KEY_6: return 6;
    case PANEL_KEY_7: return 7;
    case PANEL_KEY_8: return 8;
    case PANEL_KEY_9: return 9;
    default: return 0xFF;
    }
}

static void xmem_copy(u16 dst, u16 src, u8 len)
{
    while (len--) {
        XBYTE(dst++) = XBYTE(src++);
    }
}

static void xmem_fill(u16 start, u16 end_exclusive, u8 value)
{
    while (start != end_exclusive) {
        XBYTE(start++) = value;
    }
}

static void original_startup_init_clone(void)
{
    u8 cfg0464;
    u8 cfg0469;
    u8 cfg046a;
    u8 cfg046b;
    u8 cfg046c;
    u8 cfg046d;
    u8 cfg046e;
    u8 cfg0473;
    u8 cfg0475;
    u8 cfg047e;
    u8 i;

    P0 = 0xFF;
    P1 = 0xFF;
    P2 = 0xFF;
    P3 = 0xFF;
    P3_5 = 1;

    cfg0464 = XBYTE(0x0464);
    (void)latch_read_nibble(0x2E);

    latch_write(0x4E, 0x1E);
    latch_write(0x6E, 0x4E);
    latch_write(0x5E, 0x0E);
    latch_write(0x4F, 0xDF);

    cfg046b = XBYTE(0x046B);
    if (cfg046b & 0x20) {
        latch_write(0x6F, 0xAF);
        latch_write(0x7F, 0x0F);
    }

    P1_1 = 0;
    tiny_delay();
    P1_1 = 1;

    cfg0469 = XBYTE(0x0469);
    if (cfg0469 & 0x10) {
        XBYTE(0x215D) = 0x78;
        XBYTE(0x215E) = 0x08;
    }

    cfg046a = XBYTE(0x046A);
    if (!(cfg046a & 0x40)) {
        xmem_fill(0x2000, 0x2400, 0x0B);
        XBYTE(0x2242) = 0x87;
        XBYTE(0x2243) = 0xE2;
        XBYTE(0x2258) = 0x00;
    }

    cfg046c = XBYTE(0x046C);
    cfg047e = XBYTE(0x047E);
    cfg0475 = XBYTE(0x0475);

    if (!(cfg047e & 0x40)) {
        if (!((cfg046b & 0x80) && XBYTE(0x201C) != 0x0B)) {
            XBYTE(0x2000) = cfg0475 & 0x03;
            if (cfg046c & 0x10) {
                xmem_copy(0x2001, 0x0550, 0x14);
                xmem_copy(0x2018, 0x0564, 0x05);
            } else {
                xmem_copy(0x2001, 0x0550, 0x1C);
            }
        }
    }

    xmem_copy(0x2161, 0x047E, 0x05);

    if ((XBYTE(0x2100) & 0x0F) == 0x0B) {
        XBYTE(0x21B9) = 0x00;
        for (i = 0; i < 9; i++) {
            XBYTE((u16)(0x2020 + ((u16)i * 0x20))) = 0x00;
        }
    }

    if ((cfg0469 & 0x80) == 0) {
        XBYTE(0x216B) = XBYTE(0x0470) & 0x0F;
        XBYTE(0x216C) = (XBYTE(0x0470) >> 4) & 0x0F;
        XBYTE(0x216D) = XBYTE(0x0471) & 0x0F;
        XBYTE(0x216E) = (XBYTE(0x0471) >> 4) & 0x0F;
        XBYTE(0x216F) = XBYTE(0x0472) & 0x0F;
        xmem_copy(0x21F3, 0x216B, 0x05);
    } else if ((XBYTE(0x21F3) & 0x0F) >= 0x0A) {
        XBYTE(0x216B) = XBYTE(0x0470) & 0x0F;
        XBYTE(0x216C) = (XBYTE(0x0470) >> 4) & 0x0F;
        XBYTE(0x216D) = XBYTE(0x0471) & 0x0F;
        XBYTE(0x216E) = (XBYTE(0x0471) >> 4) & 0x0F;
        XBYTE(0x216F) = XBYTE(0x0472) & 0x0F;
        xmem_copy(0x21F3, 0x216B, 0x05);
    }

    if ((XBYTE(0x218C) & 0x0F) >= 0x07) {
        XBYTE(0x218C) = 0x04;
    }

    if (cfg0464 & 0x10) {
        XBYTE(0x218D) = 0x00;
        XBYTE(0x21DA) = 0x00;
    }

    XBYTE(0x21E1) = 0x00;
    XBYTE(0x21CA) = 0x00;
    XBYTE(0x2197) = 0x00;
    XBYTE(0x2191) = XBYTE(0x0483);

    cfg046e = XBYTE(0x046E);
    cfg0473 = XBYTE(0x0473);
    (void)cfg046e;
    (void)cfg0473;

    XBYTE(0x2248) = 0x0B;
    XBYTE(0x2249) = 0x0B;

    cfg046d = XBYTE(0x046D);
    if (cfg046d & 0x80) {
        XBYTE(0x224A) = 0x00;
        XBYTE(0x224B) = 0x00;
    } else {
        XBYTE(0x224A) = 0x01;
        XBYTE(0x224B) = 0x05;
    }

    XBYTE(0x224C) = 0xFF;
    XBYTE(0x224D) = 0xFF;
    XBYTE(0x224F) = 0xFF;
    XBYTE(0x2250) = 0xFF;

    TMOD = 0x22;
    TCON = 0x50;
    SCON = 0x70;
    TH1 = 0xE7;
    TL1 = 0xE7;
    TH0 = 0x9C;
    TL0 = 0x9C;
    IP = 0x10;
    PCON = 0x80;
    IE = 0x00;
    RI = 0;
    TI = 0;
}

static u8 display_code(char ch)
{
    switch (ch) {
    case '0': return 0x00;
    case '1': return 0x01;
    case '2': return 0x02;
    case '3': return 0x03;
    case '4': return 0x04;
    case '5': return 0x05;
    case '6': return 0x06;
    case '7': return 0x07;
    case '8': return 0x08;
    case '9': return 0x09;
    case 'A': return 0x0A;
    case 'B': return 0x25;
    case 'C': return 0x10;
    case 'D': return 0x0D;
    case 'E': return 0x0E;
    case 'F': return 0x27;
    case 'G': return 0x0C;
    case 'H': return 0x11;
    case 'I': return 0x12;
    case 'J': return 0x13;
    case 'K': return 0x14;
    case 'L': return 0x15;
    case 'M': return 0x16;
    case 'N': return 0x17;
    case 'O': return 0x18;
    case 'P': return 0x19;
    case 'Q': return 0x1A;
    case 'R': return 0x1B;
    case 'S': return 0x1C;
    case 'T': return 0x1D;
    case 'U': return 0x1E;
    case 'V': return 0x1F;
    case 'W': return 0x20;
    case 'X': return 0x21;
    case 'Y': return 0x22;
    case 'Z': return 0x23;
    case 'r': return 0x0F;
    case '*': return 0x28;
    case '=': return 0x29;
    case '<': return 0x2A;
    case '>': return 0x2B;
    case '/': return 0x2C;
    case '+': return 0x2D;
    case '-': return 0x0B;
    default: return 0x24;
    }
}

static char hex_digit(u8 v)
{
    v &= 0x0F;
    return (v < 10) ? (char)('0' + v) : (char)('A' + v - 10);
}

static void uart_send_panel(u8 value)
{
    u8 data = value & 0x7F;
    u8 parity = data;

    parity ^= parity >> 4;
    parity ^= parity >> 2;
    parity ^= parity >> 1;

    TI = 0;
    SBUF = data | ((parity & 1) ? 0x80 : 0x00);
    while (!TI) {
    }
    TI = 0;
}

static void panel_send_codes(u8 c0, u8 c1, u8 c2, u8 c3,
                             u8 c4, u8 c5, u8 c6, u8 c7)
{
    uart_send_panel(0x78);
    uart_send_panel(c7);
    uart_send_panel(c3);
    uart_send_panel(c6);
    uart_send_panel(c2);
    uart_send_panel(c5);
    uart_send_panel(c1);
    uart_send_panel(c4);
    uart_send_panel(c0);
}

static void panel_show_text8(const char *text)
{
    panel_send_codes(
        display_code(text[0]), display_code(text[1]),
        display_code(text[2]), display_code(text[3]),
        display_code(text[4]), display_code(text[5]),
        display_code(text[6]), display_code(text[7]));
}

static void panel_show_key(u8 key)
{
    panel_send_codes(
        display_code('K'), display_code('E'), display_code('Y'), display_code(' '),
        display_code(hex_digit(key >> 4)), display_code(hex_digit(key)),
        display_code(' '), display_code(' '));
}

static void radio_power_off(void)
{
    u8 i;

    /* Original key-60 path at L56D8 writes 2257h=0Bh before shutdown events. */
    XBYTE(0x2257) = 0x0B;

    for (i = 0; i < 10; i++) {
        uart_send_panel(0x6A);
    }

    panel_show_text8("BYE BYE ");

    for (;;) {
        short_delay();
    }
}

void main(void)
{
    u8 key;

    original_startup_init_clone();
    hardware_watchdog_start();
    panel_show_text8("C DEMO3 ");

    for (;;) {
        while (!RI) {
        }

        RI = 0;
        key = SBUF & 0x7F;

        /* APPEL is a second physical PTT control in every firmware variant. */
        if (key == PANEL_KEY_APPEL) {
            key = PANEL_KEY_PTT_PRESSED;
        }

        if (key == PANEL_KEY_ON_OFF) {
            radio_power_off();
        } else {
            panel_show_key(key);
        }

        short_delay();
    }
}
