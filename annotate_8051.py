#!/usr/bin/env python3
from pathlib import Path
import sys


LABEL_NAMES = {
    "L03BF": "hw_latch_read_nibble",
    "L03CC": "hw_latch_write_p1",
    "L58E1": "sync_recv_nibble",
    "L598E": "sync_send_byte",
    "L59B8": "serial_isr",
    "L59EF": "timer0_isr",
}

ADDRESS_COMMENTS = {
    "0000": "reset vector",
    "000B": "timer0 vector -> timer0_isr",
    "0023": "serial vector -> serial_isr",
    "026F": "timer/UART init: TMOD=22h, both timers mode 2",
    "0272": "start T0/T1",
    "0275": "UART setup",
    "0284": "enable EA, ET0, ES",
    "0287": "serial interrupt high priority",
    "03BF": "P3.5 low, release P1 high nibble, read nibble",
    "03CC": "P3.5 low, write A to P1, P3.5 high",
    "58E1": "begin 4-bit synchronous receive, paced by P3.4",
    "598E": "begin 8-bit synchronous transmit, LSB first",
    "59B8": "UART ISR entry",
    "59EF": "timer0 ISR entry",
}

INSTRUCTION_COMMENTS = {
    "CLR P3.5": "latch/select strobe active",
    "SETB P3.5": "latch/select strobe inactive",
    "CLR P1.1": "sync framing/select low",
    "SETB P1.1": "sync framing/select high",
    "CLR P1.2": "sync clock/ack low",
    "SETB P1.2": "sync clock/ack high",
    "CLR P1.3": "sync data low",
    "SETB P1.3": "sync data high",
    "JB P3.4": "wait/test external ready line",
    "JNB P3.4": "wait/test external ready line",
    "MOV A,P1": "sample port 1",
    "MOV SBUF": "UART transmit",
    "MOV R1,SBUF": "UART receive byte",
}


def annotate_line(line):
    stripped = line.strip()
    if stripped in (f"{label}:" for label in LABEL_NAMES):
        label = stripped[:-1]
        return [f"; --- {LABEL_NAMES[label]} ({label}) ---", line]

    if len(line) >= 5 and line[:4] in ADDRESS_COMMENTS and line[4] == ":":
        return [f"; NOTE {line[:4]}h: {ADDRESS_COMMENTS[line[:4]]}", line]

    for needle, comment in INSTRUCTION_COMMENTS.items():
        if needle in line and " ; " not in line:
            return [f"{line} ; {comment}"]

    return [line]


def main():
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("ST_M27256.asm")
    output = Path(sys.argv[2]) if len(sys.argv) > 2 else source.with_name(source.stem + "_annotated.asm")
    lines = []
    for line in source.read_text().splitlines():
        lines.extend(annotate_line(line))
    output.write_text("\n".join(lines) + "\n")
    print(f"Wrote {output} ({len(lines)} lines)")


if __name__ == "__main__":
    main()
