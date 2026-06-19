#!/usr/bin/env python3
import csv
from collections import defaultdict
from pathlib import Path

from disasm_8051 import read_ihex


def load_movx_access():
    rows = []
    with Path("MOVX_ACCESS.csv").open(newline="") as f:
        for row in csv.DictReader(f):
            if not row["dptr"]:
                continue
            addr = int(row["dptr"], 16)
            if 0 <= addr <= 0x0FFF:
                rows.append(row)
    return rows


def checksum_like_main_cpu(mem):
    r6 = 0
    r7 = 0
    carry = 0
    dptr = 0
    while dptr < 0x1000:
        a = mem.get(dptr, 0xFF) ^ (dptr & 0xFF)
        total = a + r6
        r6 = total & 0xFF
        carry = 1 if total > 0xFF else 0
        dptr += 1

        a = mem.get(dptr, 0xFF) ^ (dptr & 0xFF)
        total = a + r7 + carry
        r7 = total & 0xFF
        dptr += 1
    return r7, r6


def main():
    mem = read_ihex("ST_M2732A.HEX")
    non_ff = {addr: value for addr, value in sorted(mem.items()) if value != 0xFF}
    movx_rows = load_movx_access()
    by_addr = defaultdict(list)
    for row in movx_rows:
        by_addr[int(row["dptr"], 16)].append(row)

    out = Path("ST_M2732A_USED_BY_MAIN.csv")
    with out.open("w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["addr", "value", "main_access_count", "main_accesses"],
        )
        writer.writeheader()
        for addr, value in non_ff.items():
            refs = by_addr.get(addr, [])
            writer.writerow({
                "addr": f"{addr:04X}",
                "value": f"{value:02X}",
                "main_access_count": len(refs),
                "main_accesses": " ".join(f"{r['pc']}:{r['kind']}:{r['label']}" for r in refs[:12]),
            })

    ref_addrs = sorted(by_addr)
    used_non_ff = [addr for addr in non_ff if addr in by_addr]
    checksum_hi, checksum_lo = checksum_like_main_cpu(mem)

    print(f"ST_M2732A size: {len(mem)} bytes")
    print(f"Non-FF bytes: {len(non_ff)}")
    print(f"MOVX references in main firmware to 0000h..0FFFh: {len(movx_rows)} instructions, {len(ref_addrs)} unique addresses")
    print(f"Non-FF bytes directly referenced by main firmware: {len(used_non_ff)}")
    print(f"Main checksum algorithm result R7:R6 = {checksum_hi:02X}:{checksum_lo:02X}")
    print(f"Wrote {out}")
    print("Directly referenced non-FF bytes:")
    for addr in used_non_ff:
        refs = by_addr[addr]
        print(f"  {addr:04X}={non_ff[addr]:02X} refs={len(refs)}")


if __name__ == "__main__":
    main()
