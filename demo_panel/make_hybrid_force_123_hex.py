from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_HEX = ROOT / "ST_M27256.HEX"
OUT_HEX = Path(__file__).resolve().parent / "build" / "HYBRID_FORCE_123_EVERY_DISPLAY.HEX"


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
    hook = 0x6B40

    # Patch original L4B07 entry:
    # 4B07 originally starts with:
    #   MOV R1,#78h
    #   LCALL L0365
    # We replace the first 3 bytes with LJMP hook. The hook sets display buffer
    # and then executes the replaced instructions before jumping back to 4B0C.
    put(mem, 0x4B07, [0x02, (hook >> 8) & 0xFF, hook & 0xFF])

    code = [
        0x75, 0x72, 0x01,  # char0 = '1'
        0x75, 0x73, 0x02,  # char1 = '2'
        0x75, 0x74, 0x03,  # char2 = '3'
        0x75, 0x75, 0x24,
        0x75, 0x76, 0x24,
        0x75, 0x77, 0x24,
        0x75, 0x78, 0x24,
        0x75, 0x79, 0x24,
        0x79, 0x78,        # original replaced MOV R1,#78h
        0x12, 0x03, 0x65,  # original replaced LCALL L0365
        0x02, 0x4B, 0x0C,  # continue original L4B07 after replaced bytes
    ]
    put(mem, hook, code)

    OUT_HEX.parent.mkdir(parents=True, exist_ok=True)
    write_ihex(OUT_HEX, mem)

    print(f"Built: {OUT_HEX}")
    print("Patch: 4B07 -> LJMP 6B40")
    print("Hook:  force display buffer '123     ' on every L4B07 display update")


if __name__ == "__main__":
    main()
