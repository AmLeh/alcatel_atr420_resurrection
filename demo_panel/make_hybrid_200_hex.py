from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_HEX = ROOT / "ST_M27256.HEX"
OUT_HEX = Path(__file__).resolve().parent / "build" / "HYBRID_ORIGINAL_STARTUP_123.HEX"


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

    hook = 0x6B00

    # Patch original startup tail:
    # 034C originally: LJMP L585F
    # New path: original startup -> hook -> original L4B07 -> original dispatcher.
    put(mem, 0x034C, [0x02, (hook >> 8) & 0xFF, hook & 0xFF])

    # Internal display codes from table 498C/49B9:
    # '1' = 01h, '2' = 02h, '3' = 03h, space = 24h.
    #
    # L4B07 sends:
    # 78, 79h, 75h, 78h, 74h, 77h, 73h, 76h, 72h
    # so RAM 72..79 are the original display buffer.
    code = [
        0x75, 0x72, 0x01,  # MOV 72h,#01h ; '1'
        0x75, 0x73, 0x02,  # MOV 73h,#02h ; '2'
        0x75, 0x74, 0x03,  # MOV 74h,#03h ; '3'
        0x75, 0x75, 0x24,  # spaces
        0x75, 0x76, 0x24,
        0x75, 0x77, 0x24,
        0x75, 0x78, 0x24,
        0x75, 0x79, 0x24,
        0x78, 0x36,        # MOV R0,#36h ; UART/display queue
        0x76, 0x00,        # MOV @R0,#00h ; clear queue length
        0x02, 0x4B, 0x07,  # LJMP L4B07 ; queue full display frame and enter dispatcher
    ]
    put(mem, hook, code)

    OUT_HEX.parent.mkdir(parents=True, exist_ok=True)
    write_ihex(OUT_HEX, mem)

    print(f"Built: {OUT_HEX}")
    print("Patch: 034C -> LJMP 6B00")
    print("Hook:  6B00 -> force display buffer '123     ' -> LJMP L4B07")


if __name__ == "__main__":
    main()
