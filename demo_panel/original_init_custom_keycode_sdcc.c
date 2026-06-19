typedef unsigned char u8;

__sfr __at(0x87) PCON;
__sfr __at(0x88) TCON;
__sfr __at(0x89) TMOD;
__sfr __at(0x8A) TL0;
__sfr __at(0x8B) TL1;
__sfr __at(0x8C) TH0;
__sfr __at(0x8D) TH1;
__sfr __at(0x98) SCON;
__sfr __at(0x99) SBUF;
__sfr __at(0xA8) IE;
__sfr __at(0xB8) IP;

__sbit __at(0x98) RI;
__sbit __at(0x99) TI;

#define ORIGINAL_POWER_HANDLER 0x56D8

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
        display_code(text[0]),
        display_code(text[1]),
        display_code(text[2]),
        display_code(text[3]),
        display_code(text[4]),
        display_code(text[5]),
        display_code(text[6]),
        display_code(text[7]));
}

static void panel_show_key(u8 key)
{
    panel_send_codes(
        display_code('K'),
        display_code('E'),
        display_code('Y'),
        display_code(' '),
        display_code(hex_digit(key >> 4)),
        display_code(hex_digit(key)),
        display_code(' '),
        display_code(' '));
}

static void init_uart_like_original(void)
{
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

static void jump_original_power_handler(void) __naked
{
    __asm
        mov _IE,#0x92
        mov r3,#0x60
        ljmp #0x56D8
    __endasm;
}

void custom_app(void)
{
    u8 key;

    init_uart_like_original();
    panel_show_text8("DEMO 02 ");

    for (;;) {
        while (!RI) {
        }

        RI = 0;
        key = SBUF & 0x7F;

        if (key == 0x60) {
            jump_original_power_handler();
        }

        panel_show_key(key);
    }
}

void main(void)
{
    custom_app();
}
