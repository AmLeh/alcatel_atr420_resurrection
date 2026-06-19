#!/usr/bin/env python3
import csv
import re
from pathlib import Path


FLAGS = {
    "20h.3", "24h.1", "24h.2", "20h.1", "20h.2", "25h.1",
    "25h.0", "24h.0", "23h.6", "23h.7", "2Eh.0", "24h.6",
    "25h.2", "24h.4", "24h.7", "24h.3", "23h.5", "24h.5",
}

OP_RE = re.compile(r"^([0-9A-F]{4}):\s+[0-9A-F ]+\s+(SETB|CLR|JBC|JB|JNB)\s+([0-9A-F]{2}h\.[0-7])(?:,(L[0-9A-F]{4}))?")


def main():
    rows = []
    current_label = ""
    for line in Path("ST_M27256_2.asm").read_text().splitlines():
        label = re.match(r"^(L[0-9A-F]{4}):$", line)
        if label:
            current_label = label.group(1)
            continue
        m = OP_RE.match(line)
        if not m:
            continue
        pc, op, flag, target = m.groups()
        if flag not in FLAGS:
            continue
        rows.append({
            "flag": flag,
            "pc": pc,
            "label": current_label,
            "op": op,
            "target": target or "",
            "line": line.strip(),
        })

    out = Path("EVENT_FLAG_XREF.csv")
    with out.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["flag", "pc", "label", "op", "target", "line"])
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {out} ({len(rows)} flag references)")
    for flag in sorted(FLAGS):
        refs = [r for r in rows if r["flag"] == flag]
        sets = sum(1 for r in refs if r["op"] == "SETB")
        clrs = sum(1 for r in refs if r["op"] == "CLR")
        tests = len(refs) - sets - clrs
        print(f"{flag:5} set={sets:2} clr={clrs:2} test={tests:2}")


if __name__ == "__main__":
    main()
