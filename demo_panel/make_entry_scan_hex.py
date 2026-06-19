from pathlib import Path


def ljmp(addr):
    return [0x02, (addr >> 8) & 0xFF, addr & 0xFF]


def mov_direct_imm(direct, value):
    return [0x75, direct & 0xFF, value & 0xFF]


def latch(select, value):
    return [
        0x75, 0x90, select,  # MOV P1,#select
        0x74, value,         # MOV A,#value
        0xC2, 0xB5,          # CLR P3.5
        0xF5, 0x90,          # MOV P1,A
        0xD2, 0xB5,          # SETB P3.5
    ]


def delay(r6=0x40, r7=0xFF):
    return [
        0x7E, r6,      # MOV R6,#r6
        0x7F, r7,      # MOV R7,#r7
        0xDF, 0xFE,    # DJNZ R7,$
        0xDE, 0xFA,    # DJNZ R6,inner
    ]


def uart_put(value):
    return [
        0xC2, 0x99,          # CLR TI
        0x75, 0x99, value,   # MOV SBUF,#value
        0x30, 0x99, 0xFD,    # JNB TI,$
        0xC2, 0x99,          # CLR TI
    ]


def ihex_record(addr, data):
    total = len(data) + ((addr >> 8) & 0xFF) + (addr & 0xFF)
    body = f":{len(data):02X}{addr:04X}00" + "".join(f"{b:02X}" for b in data)
    total += sum(data)
    return body + f"{(-total) & 0xFF:02X}"


def write_ihex(path, mem):
    records = []
    addresses = sorted(mem)
    i = 0
    while i < len(addresses):
        addr = addresses[i]
        data = []
        while i < len(addresses) and addresses[i] == addr + len(data) and len(data) < 16:
            data.append(mem[addresses[i]])
            i += 1
        records.append(ihex_record(addr, data))
    records.append(":00000001FF")
    path.write_text("\n".join(records) + "\n", encoding="ascii")


def put(mem, addr, data):
    for offset, byte in enumerate(data):
        mem[addr + offset] = byte & 0xFF


def main():
    out = Path(__file__).resolve().parent / "build" / "DIAG_ENTRY_SCAN.HEX"
    out.parent.mkdir(parents=True, exist_ok=True)

    mem = {}
    beacon = 0x0200

    entries = [
        0x0000, 0x0003, 0x0008, 0x000B, 0x0010, 0x0013, 0x0018, 0x001B,
        0x0020, 0x0023, 0x0026, 0x002B, 0x0030, 0x0037, 0x0040, 0x004C,
        0x0050, 0x006C, 0x0080, 0x0100,
    ]
    for entry in entries:
        put(mem, entry, ljmp(beacon))

    code = []
    code += mov_direct_imm(0x81, 0x2F)  # SP
    code += [0xC2, 0xAF]                # CLR EA
    code += mov_direct_imm(0x80, 0xFF)  # P0
    code += mov_direct_imm(0x90, 0xFF)  # P1
    code += mov_direct_imm(0xA0, 0xFF)  # P2
    code += mov_direct_imm(0xB0, 0xFF)  # P3
    code += delay(0x20, 0xFF)

    for select, value in [
        (0x4E, 0x1E),
        (0x6E, 0x4E),
        (0x5E, 0x0E),
        (0x4F, 0xDF),
        (0x6F, 0xAF),
        (0x7F, 0x0F),
        (0xEE, 0x7E),
        (0x5E, 0x0E),
    ]:
        code += latch(select, value)
        code += delay(0x08, 0xFF)

    code += [
        0xC2, 0x91,                    # CLR P1.1
        0x00, 0x00, 0x00, 0x00,
        0xD2, 0x91,                    # SETB P1.1
    ]

    code += mov_direct_imm(0x89, 0x22)  # TMOD
    code += mov_direct_imm(0x88, 0x50)  # TCON
    code += mov_direct_imm(0x98, 0x70)  # SCON
    code += mov_direct_imm(0x8D, 0xE7)  # TH1
    code += mov_direct_imm(0x8B, 0xE7)  # TL1
    code += mov_direct_imm(0x87, 0x80)  # PCON

    loop = beacon + len(code)
    code += [
        0xB2, 0xB2,                    # CPL P3.2
        0xB2, 0x90,                    # CPL P1.0
    ]
    for b in [0x78, 0x24, 0x16, 0x24, 0x18, 0x17, 0x0A, 0x21, 0x0D]:
        code += uart_put(b)
    code += delay(0x80, 0xFF)
    code += ljmp(loop)

    put(mem, beacon, code)
    write_ihex(out, mem)
    print(f"Built: {out}")
    print(f"bytes={len(mem)} range=0x{min(mem):04X}..0x{max(mem):04X}")
    print("entry points:", ", ".join(f"0x{x:04X}" for x in entries))


if __name__ == "__main__":
    main()
