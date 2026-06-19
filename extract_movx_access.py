#!/usr/bin/env python3
import csv
import re
from pathlib import Path


def main():
    rows = []
    last_dptr = ""
    current_label = ""

    for line in Path("ST_M27256_2.asm").read_text().splitlines():
        label = re.match(r"^(L[0-9A-F]{4}):$", line)
        if label:
            current_label = label.group(1)
            continue

        ins = re.match(r"^([0-9A-F]{4}):\s+([0-9A-F ]+)\s+(.*)$", line)
        if not ins:
            continue

        pc, _raw, text = ins.groups()
        dptr = re.match(r"MOV DPTR,#([0-9A-F]{4})h", text)
        if dptr:
            last_dptr = dptr.group(1)

        if "MOVX" not in text:
            continue

        if text == "MOVX A,@DPTR":
            kind = "read"
            target = last_dptr
        elif text == "MOVX @DPTR,A":
            kind = "write"
            target = last_dptr
        elif text == "MOVX A,@R0":
            kind = "read_indirect_r0"
            target = ""
        elif text == "MOVX A,@R1":
            kind = "read_indirect_r1"
            target = ""
        elif text == "MOVX @R0,A":
            kind = "write_indirect_r0"
            target = ""
        elif text == "MOVX @R1,A":
            kind = "write_indirect_r1"
            target = ""
        else:
            kind = "unknown"
            target = last_dptr

        rows.append({
            "pc": pc,
            "label": current_label,
            "kind": kind,
            "dptr": target,
            "instruction": text,
        })

    out = Path("MOVX_ACCESS.csv")
    with out.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["pc", "label", "kind", "dptr", "instruction"])
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {out} ({len(rows)} MOVX instructions)")


if __name__ == "__main__":
    main()
