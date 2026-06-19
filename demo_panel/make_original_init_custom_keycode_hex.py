from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_HEX = ROOT / "ST_M27256.HEX"
OUT_HEX = Path(__file__).resolve().parent / "build" / "ORIGINAL_INIT_CUSTOM_KEYCODE.HEX"


def read_ihex(path):
    mem = {}
    for line in path.read_text(encoding="ascii").splitlines():
        if not line.startswith(":"):
            continue
        count = int(line[1:3], 16)
        addr = int(line[3:7], 16)
        rectype = int(line[7:9], 16)
        if rectype != 0:
            continue
        for i in range(count):
            mem[addr + i] = int(line[9 + i * 2:11 + i * 2], 16)
    return mem


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
    for i, b in enumerate(data):
        mem[addr + i] = b & 0xFF


class Code:
    def __init__(self, base):
        self.base = base
        self.data = []
        self.labels = {}
        self.fixups = []

    @property
    def pc(self):
        return self.base + len(self.data)

    def label(self, name):
        self.labels[name] = self.pc

    def emit(self, *values):
        self.data.extend(v & 0xFF for v in values)

    def mov_direct_imm(self, direct, imm):
        self.emit(0x75, direct, imm)

    def mov_a_imm(self, imm):
        self.emit(0x74, imm)

    def mov_a_direct(self, direct):
        self.emit(0xE5, direct)

    def mov_direct_a(self, direct):
        self.emit(0xF5, direct)

    def lcall(self, target):
        self.emit(0x12)
        self.fixups.append((len(self.data), target, "abs16"))
        self.emit(0x00, 0x00)

    def ljmp(self, target):
        self.emit(0x02)
        self.fixups.append((len(self.data), target, "abs16"))
        self.emit(0x00, 0x00)

    def sjmp(self, target):
        self.emit(0x80)
        self.fixups.append((len(self.data), target, "rel8"))
        self.emit(0x00)

    def cjne_a_imm(self, imm, target):
        self.emit(0xB4, imm)
        self.fixups.append((len(self.data), target, "rel8"))
        self.emit(0x00)

    def jnb(self, bit_addr, target):
        self.emit(0x30, bit_addr)
        self.fixups.append((len(self.data), target, "rel8"))
        self.emit(0x00)

    def resolve(self):
        out = self.data[:]
        for pos, target, kind in self.fixups:
            addr = self.labels[target] if isinstance(target, str) else target
            if kind == "abs16":
                out[pos] = (addr >> 8) & 0xFF
                out[pos + 1] = addr & 0xFF
            elif kind == "rel8":
                next_pc = self.base + pos + 1
                rel = addr - next_pc
                if not -128 <= rel <= 127:
                    raise ValueError(f"relative jump out of range: {target} rel={rel}")
                out[pos] = rel & 0xFF
            else:
                raise ValueError(kind)
        return out


def build_custom_app():
    hook = 0x6C00
    send_byte = 0x6D00
    send_frame = 0x6D20
    hex_table = 0x6D80

    c = Code(hook)

    # Configure UART/timers here too. This keeps checkpoint-cut test images fair:
    # cuts before 026F have not executed the original UART setup yet.
    c.mov_direct_imm(0x89, 0x22)   # TMOD
    c.mov_direct_imm(0x88, 0x50)   # TCON
    c.mov_direct_imm(0x98, 0x70)   # SCON
    c.mov_direct_imm(0x8D, 0xE7)   # TH1
    c.mov_direct_imm(0x8B, 0xE7)   # TL1
    c.mov_direct_imm(0x8C, 0x9C)   # TH0
    c.mov_direct_imm(0x8A, 0x9C)   # TL0
    c.mov_direct_imm(0xB8, 0x10)   # IP
    c.mov_direct_imm(0x87, 0x80)   # PCON

    # Disable interrupts so the original dispatcher/ISR logic cannot consume
    # panel bytes or run radio functions; use direct polling instead.
    c.mov_direct_imm(0xA8, 0x00)   # IE = 0
    c.emit(0xC2, 0x98)             # CLR RI
    c.emit(0xC2, 0x99)             # CLR TI
    c.lcall("show_demo")

    c.label("loop")
    c.jnb(0x98, "loop")            # wait RI
    c.emit(0xC2, 0x98)             # CLR RI
    c.mov_a_direct(0x99)           # A = SBUF
    c.emit(0x54, 0x7F)             # ANL A,#7Fh
    c.emit(0xFB)                   # MOV R3,A
    c.cjne_a_imm(0x60, "not_power")

    # ON/OFF is special in the original firmware. It does not become a normal
    # accepted key event; the RX parser jumps through L56D8, writes XDATA 2257h
    # with 0Bh, queues two display/panel events, then returns to L585F. Re-enter
    # that path so the station can perform its native shutdown sequence.
    c.mov_direct_imm(0xA8, 0x92)   # IE = original value
    c.ljmp(0x56D8)

    c.label("not_power")
    c.lcall("show_key")
    c.sjmp("loop")

    c.label("show_demo")
    for direct, value in [
        (0x72, 0x0D),  # D
        (0x73, 0x0E),  # E
        (0x74, 0x16),  # M
        (0x75, 0x18),  # O
        (0x76, 0x24),  # space
        (0x77, 0x00),  # 0
        (0x78, 0x02),  # 2
        (0x79, 0x24),  # space
    ]:
        c.mov_direct_imm(direct, value)
    c.lcall(send_frame)
    c.emit(0x22)                   # RET

    c.label("show_key")
    for direct, value in [
        (0x72, 0x14),  # K
        (0x73, 0x0E),  # E
        (0x74, 0x22),  # Y
        (0x75, 0x24),  # space
    ]:
        c.mov_direct_imm(direct, value)

    c.emit(0xEB)                   # MOV A,R3
    c.emit(0xC4)                   # SWAP A
    c.emit(0x54, 0x0F)             # ANL A,#0Fh
    c.emit(0x90, (hex_table >> 8) & 0xFF, hex_table & 0xFF)
    c.emit(0x93)                   # MOVC A,@A+DPTR
    c.mov_direct_a(0x76)

    c.emit(0xEB)                   # MOV A,R3
    c.emit(0x54, 0x0F)             # ANL A,#0Fh
    c.emit(0x90, (hex_table >> 8) & 0xFF, hex_table & 0xFF)
    c.emit(0x93)                   # MOVC A,@A+DPTR
    c.mov_direct_a(0x77)

    c.mov_direct_imm(0x78, 0x24)
    c.mov_direct_imm(0x79, 0x24)
    c.lcall(send_frame)
    c.emit(0x22)                   # RET

    main_code = c.resolve()

    s = Code(send_byte)
    s.emit(0x54, 0x7F)             # ANL A,#7Fh
    s.emit(0xA2, 0xD0)             # MOV C,PSW.0
    s.emit(0x92, 0xE7)             # MOV ACC.7,C
    s.emit(0xC2, 0x99)             # CLR TI
    s.emit(0xF5, 0x99)             # MOV SBUF,A
    s.label("wait_ti")
    s.jnb(0x99, "wait_ti")         # wait TI
    s.emit(0xC2, 0x99)             # CLR TI
    s.emit(0x22)                   # RET
    send_byte_code = s.resolve()

    f = Code(send_frame)
    for op, value in [
        ("imm", 0x78),
        ("direct", 0x79),
        ("direct", 0x75),
        ("direct", 0x78),
        ("direct", 0x74),
        ("direct", 0x77),
        ("direct", 0x73),
        ("direct", 0x76),
        ("direct", 0x72),
    ]:
        if op == "imm":
            f.mov_a_imm(value)
        else:
            f.mov_a_direct(value)
        f.lcall(send_byte)
    f.emit(0x22)                   # RET
    send_frame_code = f.resolve()

    table = [
        0x00, 0x01, 0x02, 0x03,
        0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x0A, 0x25,
        0x10, 0x0D, 0x0E, 0x27,
    ]

    return {
        hook: main_code,
        send_byte: send_byte_code,
        send_frame: send_frame_code,
        hex_table: table,
    }


def main():
    mem = read_ihex(SOURCE_HEX)
    hook = 0x6C00

    # End of known-good original startup:
    # 034C: LJMP L585F
    # Replace it with our custom panel/key demo app.
    put(mem, 0x034C, [0x02, (hook >> 8) & 0xFF, hook & 0xFF])

    for addr, data in build_custom_app().items():
        put(mem, addr, data)

    OUT_HEX.parent.mkdir(parents=True, exist_ok=True)
    write_ihex(OUT_HEX, mem)

    print(f"Built: {OUT_HEX}")
    print("Patch: 034C -> LJMP 6C00")
    print("Behavior: original startup/init, custom display/key loop, ON/OFF jumps to original shutdown handler")


if __name__ == "__main__":
    main()
