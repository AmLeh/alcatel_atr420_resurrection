typedef unsigned char u8;
typedef unsigned int u16;

__sfr __at (0x80) P0;
__sfr __at (0x87) PCON;
__sfr __at (0x88) TCON;
__sfr __at (0x89) TMOD;
__sfr __at (0x8A) TL0;
__sfr __at (0x8B) TL1;
__sfr __at (0x8C) TH0;
__sfr __at (0x8D) TH1;
__sfr __at (0x90) P1;
__sfr __at (0x98) SCON;
__sfr __at (0x99) SBUF;
__sfr __at (0xA0) P2;
__sfr __at (0xA8) IE;
__sfr __at (0xB0) P3;
__sfr __at (0xB8) IP;

__sbit __at (0x91) P1_1;
__sbit __at (0x92) P1_2;
__sbit __at (0x93) P1_3;
__sbit __at (0x98) RI;
__sbit __at (0x99) TI;
__sbit __at (0xB4) P3_4;
__sbit __at (0xB5) P3_5;

static const char alphabet[] = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789r*=<>/+-";
static const u8 display_codes[] = {
    0x24, 0x0A, 0x25, 0x10, 0x0D, 0x0E, 0x27, 0x0C,
    0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
    0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20,
    0x21, 0x22, 0x23, 0x00, 0x01, 0x02, 0x03, 0x04,
    0x05, 0x06, 0x07, 0x08, 0x09, 0x0F, 0x28, 0x29,
    0x2A, 0x2B, 0x2C, 0x2D, 0x0B
};

static u8 display_encode_char(char ch)
{
    u8 i;

    for (i = 0; i < sizeof(alphabet) - 1; i++) {
        if (alphabet[i] == ch) {
            return display_codes[i];
        }
    }

    return 0x24;
}

static char hex_digit(u8 v)
{
    v &= 0x0F;
    if (v < 10) {
        return (char)('0' + v);
    }
    return (char)('A' + v - 10);
}

static void delay_short(void)
{
    volatile u16 i;

    for (i = 0; i < 800; i++) {
    }
}

static void delay_long(void)
{
    u8 i;

    for (i = 0; i < 80; i++) {
        delay_short();
    }
}

static void delay_tiny(void)
{
    volatile u8 i;

    for (i = 0; i < 40; i++) {
    }
}

static void latch_command(u8 select, u8 value)
{
    P3_5 = 1;
    P1 = select;
    delay_tiny();
    P3_5 = 0;
    delay_tiny();
    P1 = value;
    delay_tiny();
    P3_5 = 1;
    delay_tiny();
}

static void board_init_like_original_startup(void)
{
    __asm
        mov _P1,#0x4e
        mov a,#0x1e
        clr _P3_5
        mov _P1,a
        setb _P3_5

        mov _P1,#0x6e
        mov a,#0x4e
        clr _P3_5
        mov _P1,a
        setb _P3_5

        mov _P1,#0x5e
        mov a,#0x0e
        clr _P3_5
        mov _P1,a
        setb _P3_5

        mov _P1,#0x4f
        mov a,#0xdf
        clr _P3_5
        mov _P1,a
        setb _P3_5

        mov _P1,#0x6f
        mov a,#0xaf
        clr _P3_5
        mov _P1,a
        setb _P3_5

        mov _P1,#0x7f
        mov a,#0x0f
        clr _P3_5
        mov _P1,a
        setb _P3_5
    __endasm;

    delay_long();

    P1_1 = 0;
    delay_tiny();
    delay_tiny();
    P1_1 = 1;
    delay_short();
}

static void uart_init_like_original(void)
{
    IE = 0x00;
    IP = 0x00;

    TMOD = 0x22;
    TCON = 0x50;
    SCON = 0x70;
    TH1 = 0xE7;
    TL1 = 0xE7;
    TH0 = 0x9C;
    TL0 = 0x9C;
    PCON = 0x80;

    TI = 0;
    RI = 0;
}

static void uart_put(u8 value)
{
    u8 data = value & 0x7F;
    u8 p = data;

    p ^= p >> 4;
    p ^= p >> 2;
    p ^= p >> 1;

    TI = 0;
    SBUF = data | ((p & 1) << 7);
    while (!TI) {
    }
    TI = 0;
}

static u8 wait_p3_4_is(u8 state)
{
    u16 timeout = 60000;

    if (state) {
        while (!P3_4 && --timeout) {
        }
    } else {
        while (P3_4 && --timeout) {
        }
    }

    return timeout != 0;
}

static u8 sync_send_byte_timeout(u8 value)
{
    u8 i;

    P1_1 = 0;
    delay_tiny();
    P1_1 = 1;

    for (i = 0; i < 8; i++) {
        P1_3 = value & 1;
        P1_2 = 0;
        value = (value >> 1) | (value << 7);

        if (!wait_p3_4_is(0)) {
            P1_2 = 1;
            P1_3 = 1;
            return 0;
        }

        P1_2 = 1;

        if (!wait_p3_4_is(1)) {
            P1_3 = 1;
            return 0;
        }
    }

    P1_3 = 1;
    delay_tiny();
    return 1;
}

static void panel_send_sync_packet(const u8 *packet, u8 len)
{
    u8 i;

    for (i = 0; i < len; i++) {
        if (!sync_send_byte_timeout(packet[i])) {
            return;
        }
        delay_tiny();
    }
    delay_short();
}

static void panel_sync_wakeup_sequence(void)
{
    static const u8 pkt_00_01[] = {0x00, 0x01, 0x0D, 0x0E, 0x16, 0x18, 0x24, 0x2F};
    static const u8 pkt_00_02_a[] = {0x00, 0x02, 0x0B, 0x2F};
    static const u8 pkt_00_02_b[] = {0x00, 0x02, 0x0B, 0x0C, 0x2F};
    static const u8 pkt_00_02_c[] = {0x00, 0x02, 0x0D, 0x0E, 0x2F};
    static const u8 pkt_00_03[] = {0x00, 0x03, 0x2F};
    static const u8 pkt_00_05[] = {0x00, 0x05, 0x2F};
    static const u8 pkt_00_06[] = {0x00, 0x06, 0x0D, 0x0E, 0x16, 0x18, 0x24, 0x2F};
    static const u8 pkt_1f[] = {0x1F, 0x00, 0x00, 0x00, 0x00, 0x2F};

    panel_send_sync_packet(pkt_00_01, sizeof(pkt_00_01));
    panel_send_sync_packet(pkt_00_02_a, sizeof(pkt_00_02_a));
    panel_send_sync_packet(pkt_00_02_b, sizeof(pkt_00_02_b));
    panel_send_sync_packet(pkt_00_02_c, sizeof(pkt_00_02_c));
    panel_send_sync_packet(pkt_00_03, sizeof(pkt_00_03));
    panel_send_sync_packet(pkt_00_05, sizeof(pkt_00_05));
    panel_send_sync_packet(pkt_00_06, sizeof(pkt_00_06));
    panel_send_sync_packet(pkt_1f, sizeof(pkt_1f));
}

static void panel_uart_wakeup_sequence(void)
{
    uart_put(0x60);
    uart_put(0x6A);
    uart_put(0x6A);
    uart_put(0x6A);
    uart_put(0x6A);
    uart_put(0x6A);
    uart_put(0x68);
    uart_put(0x6D);
    uart_put(0x60);
}

static void panel_send_display_codes(const u8 c[8])
{
    uart_put(0x78);
    uart_put(c[7]);
    uart_put(c[3]);
    uart_put(c[6]);
    uart_put(c[2]);
    uart_put(c[5]);
    uart_put(c[1]);
    uart_put(c[4]);
    uart_put(c[0]);
}

static void panel_show_text(const char text[8])
{
    u8 c[8];
    u8 i;

    for (i = 0; i < 8; i++) {
        c[i] = display_encode_char(text[i]);
    }

    panel_send_display_codes(c);
}

static void panel_show_key_uart(u8 key)
{
    char text[8];

    text[0] = 'K';
    text[1] = 'E';
    text[2] = 'Y';
    text[3] = ' ';
    text[4] = hex_digit(key >> 4);
    text[5] = hex_digit(key);
    text[6] = ' ';
    text[7] = ' ';
    panel_show_text(text);
}

static void panel_show_key_sync(u8 key)
{
    char text[8];

    text[0] = 'S';
    text[1] = 'Y';
    text[2] = 'N';
    text[3] = ' ';
    text[4] = '0';
    text[5] = hex_digit(key);
    text[6] = ' ';
    text[7] = ' ';
    panel_show_text(text);
}

static u8 uart_try_get(u8 *out)
{
    if (RI) {
        RI = 0;
        *out = SBUF;
        return 1;
    }

    return 0;
}

static u8 sync_try_recv_nibble(u8 *out)
{
    u8 i;
    u8 value = 0;
    u16 timeout;

    if (P3_4) {
        return 0;
    }

    for (i = 0; i < 4; i++) {
        if (P3_4) {
            return 0;
        }

        value >>= 1;
        if (P1_3) {
            value |= 0x08;
        }

        P1_2 = 0;
        timeout = 40000;
        while (!P3_4 && --timeout) {
        }
        P1_2 = 1;

        if (!timeout) {
            return 0;
        }

        timeout = 40000;
        while (P3_4 && --timeout) {
        }
        if (!timeout && i != 3) {
            return 0;
        }
    }

    *out = value & 0x0F;
    return 1;
}

static void ports_init_safe(void)
{
    P0 = 0xFF;
    P1 = 0xFF;
    P2 = 0xFF;
    P3 = 0xFF;

    P1_1 = 1;
    P1_2 = 1;
    P1_3 = 1;
    P3_5 = 1;
}

void main(void)
{
    u8 b;
    u8 phase = 0;
    u8 quiet_loops = 0;

    ports_init_safe();
    board_init_like_original_startup();
    uart_init_like_original();
    panel_sync_wakeup_sequence();
    panel_uart_wakeup_sequence();

    panel_show_text("DEMO 01 ");
    delay_long();

    for (;;) {
        if (uart_try_get(&b)) {
            b &= 0x7F;
            panel_show_key_uart(b);
            delay_long();
            quiet_loops = 0;
            continue;
        }

        if (sync_try_recv_nibble(&b)) {
            panel_show_key_sync(b);
            delay_long();
            quiet_loops = 0;
            continue;
        }

        delay_short();
        quiet_loops++;

        if (quiet_loops == 0) {
            if (phase == 0) {
                panel_show_text("PANEL   ");
            } else if (phase == 1) {
                panel_show_text("ALCATEL ");
            } else {
                panel_show_text("PRESS   ");
            }

            phase++;
            if (phase >= 3) {
                phase = 0;
            }
        }
    }
}
