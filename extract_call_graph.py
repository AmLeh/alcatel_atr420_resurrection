#!/usr/bin/env python3
import csv
import re
from pathlib import Path


CALL_RE = re.compile(r"\b(?:LCALL|ACALL|LJMP|AJMP|SJMP|JC|JNC|JZ|JNZ|JB|JNB|JBC|CJNE|DJNZ)\b.*\b(L[0-9A-F]{4})\b")


def main():
    rows = []
    current_label = ""

    for line in Path("ST_M27256_2.asm").read_text().splitlines():
        label = re.match(r"^(L[0-9A-F]{4}):$", line)
        if label:
            current_label = label.group(1)
            continue

        m = re.match(r"^([0-9A-F]{4}):\s+[0-9A-F ]+\s+(.*)$", line)
        if not m:
            continue

        pc, text = m.group(1), m.group(2).strip()
        target = CALL_RE.search(text)
        if not target:
            continue

        mnemonic = text.split()[0]
        rows.append({
            "pc": pc,
            "caller_label": current_label,
            "mnemonic": mnemonic,
            "target": target.group(1),
            "instruction": text,
        })

    out = Path("CALL_GRAPH.csv")
    with out.open("w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["pc", "caller_label", "mnemonic", "target", "instruction"],
        )
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {out} ({len(rows)} control-flow edges)")
    for target in ("L03CC", "L03BF", "L598E", "L58E1", "L59B8", "L59EF"):
        callers = [r for r in rows if r["target"] == target]
        print(f"{target}: {len(callers)} incoming edges")


if __name__ == "__main__":
    main()
