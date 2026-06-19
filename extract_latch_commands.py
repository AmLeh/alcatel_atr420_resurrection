#!/usr/bin/env python3
import csv
import re
from pathlib import Path


CALLS = ("LCALL L03CC", "ACALL L03CC", "AJMP L03CC", "LJMP L03CC")


def parse_instruction(line):
    m = re.match(r"^([0-9A-F]{4}):\s+([0-9A-F ]+)\s+(.*)$", line)
    if not m:
        return None
    return {"pc": m.group(1), "raw": m.group(2).strip(), "text": m.group(3).strip()}


def immediate_move(text, register):
    m = re.match(rf"MOV {register},#([0-9A-F]+)h$", text)
    return m.group(1).upper() if m else ""


def main():
    lines = Path("ST_M27256_2.asm").read_text().splitlines()
    rows = []
    current_label = ""
    recent = []

    for line in lines:
        label = re.match(r"^(L[0-9A-F]{4}):$", line)
        if label:
            current_label = label.group(1)
            recent.clear()
            continue

        ins = parse_instruction(line)
        if not ins:
            continue

        text = ins["text"]
        if any(call in text for call in CALLS):
            p1_value = ""
            a_value = ""
            p1_pc = ""
            a_pc = ""
            for prev in reversed(recent[-8:]):
                if not p1_value:
                    value = immediate_move(prev["text"], "P1")
                    if value:
                        p1_value = value
                        p1_pc = prev["pc"]
                if not a_value:
                    value = immediate_move(prev["text"], "A")
                    if value:
                        a_value = value
                        a_pc = prev["pc"]
                if p1_value and a_value:
                    break

            rows.append({
                "call_pc": ins["pc"],
                "caller_label": current_label,
                "call": text,
                "p1_pc": p1_pc,
                "p1_value": p1_value,
                "a_pc": a_pc,
                "a_value": a_value,
            })

        recent.append(ins)
        if len(recent) > 16:
            recent.pop(0)

    out = Path("LATCH_COMMANDS.csv")
    with out.open("w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["call_pc", "caller_label", "call", "p1_pc", "p1_value", "a_pc", "a_value"],
        )
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {out} ({len(rows)} latch calls)")
    for row in rows[:20]:
        print(
            f"{row['call_pc']} {row['caller_label']:>6} "
            f"P1={row['p1_value'] or '??'} A={row['a_value'] or '??'}"
        )


if __name__ == "__main__":
    main()
