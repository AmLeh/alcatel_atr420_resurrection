from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_HEX = ROOT / "ST_M27256.HEX"
OUT_HEX = Path(__file__).resolve().parent / "build" / "HYBRID_KEYCODE_DISPLAY.HEX"


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


def main():
    mem = read_ihex(SOURCE_HEX)

    hook = 0x6B80
    hex_table = 0x6BC0

    # Accepted-key endpoint:
    # 5724: MOV 7Bh,R3
    # 5726: SETB 24h.4
    # 5728: LJMP L5745
    #
    # R3 contains the decoded byte from the panel/keyboard stream. Jump to a
    # hook that keeps the original state update and then displays the code.
    put(mem, 0x5724, [0x02, (hook >> 8) & 0xFF, hook & 0xFF])

    code = [
        0x8B, 0x7B,              # MOV 7Bh,R3
        0xD2, 0x24,              # SETB 24h.4

        # Display buffer 72h..79h = "KEY xx  ".
        # Codes are from the original table at 498C/49B9.
        0x75, 0x72, 0x14,        # K
        0x75, 0x73, 0x0E,        # E
        0x75, 0x74, 0x22,        # Y
        0x75, 0x75, 0x24,        # space

        0xEB,                    # MOV A,R3
        0xC4,                    # SWAP A
        0x54, 0x0F,              # ANL A,#0Fh
        0x90, (hex_table >> 8) & 0xFF, hex_table & 0xFF,
        0x93,                    # MOVC A,@A+DPTR
        0xF5, 0x76,              # MOV 76h,A

        0xEB,                    # MOV A,R3
        0x54, 0x0F,              # ANL A,#0Fh
        0x90, (hex_table >> 8) & 0xFF, hex_table & 0xFF,
        0x93,                    # MOVC A,@A+DPTR
        0xF5, 0x77,              # MOV 77h,A

        0x75, 0x78, 0x24,        # space
        0x75, 0x79, 0x24,        # space
        0x78, 0x36,              # MOV R0,#36h ; UART/display queue
        0x76, 0x00,              # MOV @R0,#00h ; clear queue length
        0x02, 0x4B, 0x07,        # LJMP L4B07
    ]

    table = [
        0x00, 0x01, 0x02, 0x03,
        0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x0A, 0x25,
        0x10, 0x0D, 0x0E, 0x27,
    ]

    put(mem, hook, code)
    put(mem, hex_table, table)

    OUT_HEX.parent.mkdir(parents=True, exist_ok=True)
    write_ihex(OUT_HEX, mem)

    print(f"Built: {OUT_HEX}")
    print("Patch: 5724 -> LJMP 6B80")
    print("Hook:  keep key state, display 'KEY xx', then LJMP L4B07")


if __name__ == "__main__":
    main()
