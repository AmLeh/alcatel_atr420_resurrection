#!/usr/bin/env python3
import csv
import re
from collections import defaultdict
from pathlib import Path


DISPATCH = [
    ("20h.3", "level", "L58DC", "sync receive start"),
    ("24h.1", "one-shot", "L541E", "event handler"),
    ("24h.2", "one-shot", "L542D", "event handler"),
    ("20h.1", "one-shot", "L4D2A", "timer tick event"),
    ("20h.2", "level", "L597C", "sync transmit event"),
    ("25h.1", "one-shot", "L534F", "latch read/status handler"),
    ("25h.0", "one-shot", "L568F", "serial/sync related handler"),
    ("24h.0", "one-shot", "L4CFD", "UART transmit/service handler"),
    ("23h.6", "one-shot", "L4A16/L51AB", "branch depends on 2Bh.2"),
    ("23h.7", "one-shot", "L2BE3", "event handler"),
    ("2Eh.0", "one-shot", "L5609", "2Eh sub-dispatcher"),
    ("24h.6", "one-shot", "L3271", "event handler"),
    ("25h.2", "one-shot", "L4FD9", "latch/state handler"),
    ("24h.4", "one-shot", "L3C5E/L06A6", "branch depends on 2Bh.3"),
    ("24h.7", "one-shot", "L346C", "event handler"),
    ("24h.3", "one-shot", "L57E0", "large mode/state dispatcher"),
    ("23h.5", "one-shot", "L5748", "event handler"),
    ("24h.5", "one-shot", "L54B9", "event handler"),
]


def read_asm():
    lines = Path("ST_M27256_2.asm").read_text().splitlines()
    by_label = defaultdict(list)
    current = ""
    pending_address_labels = {f"L{addr:04X}" for addr in (0x58DC,)}
    for line in lines:
        m = re.match(r"^(L[0-9A-F]{4}):$", line)
        if m:
            current = m.group(1)
            continue
        addr = re.match(r"^([0-9A-F]{4}):", line)
        if addr and f"L{addr.group(1)}" in pending_address_labels:
            current = f"L{addr.group(1)}"
        if current:
            by_label[current].append(line)
    return by_label


def summarize_handler(lines):
    text = "\n".join(lines[:220])
    tags = []
    if "L03CC" in text or "MOV P1,#" in text or "CLR P3.5" in text:
        tags.append("latch")
    if "L03BF" in text or "MOV A,P1" in text:
        tags.append("latch_read")
    if "MOVX" in text:
        tags.append("movx")
    if "SBUF" in text or "SCON" in text:
        tags.append("uart")
    if "P1.1" in text or "P1.2" in text or "P1.3" in text or "P3.4" in text:
        tags.append("sync")
    if "JMP @A+DPTR" in text:
        tags.append("jump_table")
    return ",".join(tags)


def main():
    by_label = read_asm()
    rows = []
    for flag, kind, handler_expr, note in DISPATCH:
        handlers = handler_expr.split("/")
        tags = sorted({tag for h in handlers for tag in summarize_handler(by_label[h]).split(",") if tag})
        first_pcs = []
        for h in handlers:
            for line in by_label[h][:12]:
                m = re.match(r"^([0-9A-F]{4}):", line)
                if m:
                    first_pcs.append(m.group(1))
                    break
        rows.append({
            "flag": flag,
            "kind": kind,
            "handler": handler_expr,
            "first_pc": "/".join(first_pcs),
            "tags": ",".join(tags),
            "note": note,
        })

    out = Path("EVENT_DISPATCH.csv")
    with out.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["flag", "kind", "handler", "first_pc", "tags", "note"])
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {out} ({len(rows)} dispatch events)")
    for row in rows:
        print(f"{row['flag']:5} {row['kind']:8} -> {row['handler']:11} {row['tags']}")


if __name__ == "__main__":
    main()
