#!/usr/bin/env python3
import argparse
from pathlib import Path


SFR = {
    0x80: "P0", 0x81: "SP", 0x82: "DPL", 0x83: "DPH", 0x87: "PCON",
    0x88: "TCON", 0x89: "TMOD", 0x8A: "TL0", 0x8B: "TL1", 0x8C: "TH0",
    0x8D: "TH1", 0x90: "P1", 0x98: "SCON", 0x99: "SBUF", 0xA0: "P2",
    0xA8: "IE", 0xB0: "P3", 0xB8: "IP", 0xD0: "PSW", 0xE0: "ACC",
    0xF0: "B",
}

BIT_SFR = {
    0x80: "P0", 0x88: "TCON", 0x90: "P1", 0x98: "SCON", 0xA0: "P2",
    0xA8: "IE", 0xB0: "P3", 0xB8: "IP", 0xD0: "PSW", 0xE0: "ACC",
    0xF0: "B",
}


def read_ihex(path):
    mem = {}
    upper = 0
    for lineno, raw in enumerate(Path(path).read_text().splitlines(), 1):
        line = raw.strip()
        if not line:
            continue
        if not line.startswith(":"):
            raise ValueError(f"Line {lineno}: not an Intel HEX record")
        data = bytes.fromhex(line[1:])
        count, addr, rectype = data[0], (data[1] << 8) | data[2], data[3]
        payload, checksum = data[4:4 + count], data[4 + count]
        if ((sum(data[:4 + count]) + checksum) & 0xFF) != 0:
            raise ValueError(f"Line {lineno}: bad checksum")
        if rectype == 0x00:
            base = upper + addr
            for i, b in enumerate(payload):
                mem[base + i] = b
        elif rectype == 0x01:
            break
        elif rectype == 0x02:
            upper = int.from_bytes(payload, "big") << 4
        elif rectype == 0x04:
            upper = int.from_bytes(payload, "big") << 16
    return mem


def hx(v, width=2):
    return f"0{v:0{width}X}h" if v >= 0xA0 and width == 2 else f"{v:0{width}X}h"


def direct(v):
    return SFR.get(v, hx(v))


def bit_addr(v):
    if v < 0x80:
        byte = 0x20 + (v >> 3)
        bit = v & 7
        return f"{hx(byte)}.{bit}"
    base = v & 0xF8
    bit = v & 7
    return f"{BIT_SFR.get(base, hx(base))}.{bit}"


def rel_target(pc, rel):
    signed = rel - 0x100 if rel & 0x80 else rel
    return (pc + 2 + signed) & 0xFFFF


def rel3_target(pc, rel):
    signed = rel - 0x100 if rel & 0x80 else rel
    return (pc + 3 + signed) & 0xFFFF


def ajmp_target(pc, op, low):
    return ((pc + 2) & 0xF800) | ((op & 0xE0) << 3) | low


def decode(mem, pc, labels=None):
    b = lambda off: mem.get(pc + off, 0)
    op = b(0)
    label = lambda a: labels.get(a, f"L{a:04X}") if labels else f"L{a:04X}"

    if op == 0x00:
        return 1, "NOP", []
    if op in (0x01, 0x21, 0x41, 0x61, 0x81, 0xA1, 0xC1, 0xE1):
        t = ajmp_target(pc, op, b(1))
        return 2, f"AJMP {label(t)}", [t]
    if op == 0x02:
        t = (b(1) << 8) | b(2)
        return 3, f"LJMP {label(t)}", [t]
    if op == 0x03:
        return 1, "RR A", []
    if op == 0x04:
        return 1, "INC A", []
    if op == 0x05:
        return 2, f"INC {direct(b(1))}", []
    if op in (0x06, 0x07):
        return 1, f"INC @R{op & 1}", []
    if 0x08 <= op <= 0x0F:
        return 1, f"INC R{op & 7}", []
    if op == 0x10:
        t = rel3_target(pc, b(2))
        return 3, f"JBC {bit_addr(b(1))},{label(t)}", [t]
    if op in (0x11, 0x31, 0x51, 0x71, 0x91, 0xB1, 0xD1, 0xF1):
        t = ajmp_target(pc, op, b(1))
        return 2, f"ACALL {label(t)}", [t]
    if op == 0x12:
        t = (b(1) << 8) | b(2)
        return 3, f"LCALL {label(t)}", [t]
    if op == 0x13:
        return 1, "RRC A", []
    if op == 0x14:
        return 1, "DEC A", []
    if op == 0x15:
        return 2, f"DEC {direct(b(1))}", []
    if op in (0x16, 0x17):
        return 1, f"DEC @R{op & 1}", []
    if 0x18 <= op <= 0x1F:
        return 1, f"DEC R{op & 7}", []
    if op == 0x20:
        t = rel3_target(pc, b(2))
        return 3, f"JB {bit_addr(b(1))},{label(t)}", [t]
    if op == 0x22:
        return 1, "RET", []
    if op == 0x23:
        return 1, "RL A", []
    if 0x24 <= op <= 0x2F:
        return alu_decode("ADD", op, b(1))
    if op == 0x30:
        t = rel3_target(pc, b(2))
        return 3, f"JNB {bit_addr(b(1))},{label(t)}", [t]
    if op == 0x32:
        return 1, "RETI", []
    if op == 0x33:
        return 1, "RLC A", []
    if 0x34 <= op <= 0x3F:
        return alu_decode("ADDC", op - 0x10, b(1))
    if op in (0x40, 0x50, 0x60, 0x70, 0x80):
        names = {0x40: "JC", 0x50: "JNC", 0x60: "JZ", 0x70: "JNZ", 0x80: "SJMP"}
        t = rel_target(pc, b(1))
        return 2, f"{names[op]} {label(t)}", [t]
    if 0x42 <= op <= 0x4F:
        return logic_decode("ORL", op, b(1), b(2))
    if 0x52 <= op <= 0x5F:
        return logic_decode("ANL", op - 0x10, b(1), b(2))
    if 0x62 <= op <= 0x6F:
        return logic_decode("XRL", op - 0x20, b(1), b(2))
    if op == 0x72:
        return 2, f"ORL C,{bit_addr(b(1))}", []
    if op == 0x73:
        return 1, "JMP @A+DPTR", []
    if op == 0x74:
        return 2, f"MOV A,#{hx(b(1))}", []
    if op == 0x75:
        return 3, f"MOV {direct(b(1))},#{hx(b(2))}", []
    if op in (0x76, 0x77):
        return 2, f"MOV @R{op & 1},#{hx(b(1))}", []
    if 0x78 <= op <= 0x7F:
        return 2, f"MOV R{op & 7},#{hx(b(1))}", []
    if op == 0x82:
        return 2, f"ANL C,{bit_addr(b(1))}", []
    if op == 0x83:
        return 1, "MOVC A,@A+PC", []
    if op == 0x84:
        return 1, "DIV AB", []
    if op == 0x85:
        return 3, f"MOV {direct(b(2))},{direct(b(1))}", []
    if op in (0x86, 0x87):
        return 2, f"MOV {direct(b(1))},@R{op & 1}", []
    if 0x88 <= op <= 0x8F:
        return 2, f"MOV {direct(b(1))},R{op & 7}", []
    if op == 0x90:
        return 3, f"MOV DPTR,#{hx((b(1) << 8) | b(2), 4)}", []
    if op == 0x92:
        return 2, f"MOV {bit_addr(b(1))},C", []
    if op == 0x93:
        return 1, "MOVC A,@A+DPTR", []
    if 0x94 <= op <= 0x9F:
        return alu_decode("SUBB", op - 0x70, b(1))
    if op == 0xA0:
        return 2, f"ORL C,/{bit_addr(b(1))}", []
    if op == 0xA2:
        return 2, f"MOV C,{bit_addr(b(1))}", []
    if op == 0xA3:
        return 1, "INC DPTR", []
    if op == 0xA4:
        return 1, "MUL AB", []
    if op == 0xA5:
        return 1, "DB 0A5h ; reserved opcode", []
    if op in (0xA6, 0xA7):
        return 2, f"MOV @R{op & 1},{direct(b(1))}", []
    if 0xA8 <= op <= 0xAF:
        return 2, f"MOV R{op & 7},{direct(b(1))}", []
    if op == 0xB0:
        return 2, f"ANL C,/{bit_addr(b(1))}", []
    if op == 0xB2:
        return 2, f"CPL {bit_addr(b(1))}", []
    if op == 0xB3:
        return 1, "CPL C", []
    if op in (0xB4, 0xB5):
        t = rel3_target(pc, b(2))
        lhs = "A" if op == 0xB4 else f"A,{direct(b(1))}"
        rhs = f"#{hx(b(1))}" if op == 0xB4 else None
        text = f"CJNE {lhs},{rhs},{label(t)}" if rhs else f"CJNE {lhs},{label(t)}"
        return 3, text, [t]
    if op in (0xB6, 0xB7):
        t = rel3_target(pc, b(2))
        return 3, f"CJNE @R{op & 1},#{hx(b(1))},{label(t)}", [t]
    if 0xB8 <= op <= 0xBF:
        t = rel3_target(pc, b(2))
        return 3, f"CJNE R{op & 7},#{hx(b(1))},{label(t)}", [t]
    if op == 0xC0:
        return 2, f"PUSH {direct(b(1))}", []
    if op == 0xC2:
        return 2, f"CLR {bit_addr(b(1))}", []
    if op == 0xC3:
        return 1, "CLR C", []
    if op == 0xC4:
        return 1, "SWAP A", []
    if op == 0xC5:
        return 2, f"XCH A,{direct(b(1))}", []
    if op in (0xC6, 0xC7):
        return 1, f"XCH A,@R{op & 1}", []
    if 0xC8 <= op <= 0xCF:
        return 1, f"XCH A,R{op & 7}", []
    if op == 0xD0:
        return 2, f"POP {direct(b(1))}", []
    if op == 0xD2:
        return 2, f"SETB {bit_addr(b(1))}", []
    if op == 0xD3:
        return 1, "SETB C", []
    if op == 0xD4:
        return 1, "DA A", []
    if op == 0xD5:
        t = rel3_target(pc, b(2))
        return 3, f"DJNZ {direct(b(1))},{label(t)}", [t]
    if op in (0xD6, 0xD7):
        return 1, f"XCHD A,@R{op & 1}", []
    if 0xD8 <= op <= 0xDF:
        t = rel_target(pc, b(1))
        return 2, f"DJNZ R{op & 7},{label(t)}", [t]
    if op == 0xE0:
        return 1, "MOVX A,@DPTR", []
    if op in (0xE2, 0xE3):
        return 1, f"MOVX A,@R{op & 1}", []
    if op == 0xE4:
        return 1, "CLR A", []
    if op == 0xE5:
        return 2, f"MOV A,{direct(b(1))}", []
    if op in (0xE6, 0xE7):
        return 1, f"MOV A,@R{op & 1}", []
    if 0xE8 <= op <= 0xEF:
        return 1, f"MOV A,R{op & 7}", []
    if op == 0xF0:
        return 1, "MOVX @DPTR,A", []
    if op in (0xF2, 0xF3):
        return 1, f"MOVX @R{op & 1},A", []
    if op == 0xF4:
        return 1, "CPL A", []
    if op == 0xF5:
        return 2, f"MOV {direct(b(1))},A", []
    if op in (0xF6, 0xF7):
        return 1, f"MOV @R{op & 1},A", []
    if 0xF8 <= op <= 0xFF:
        return 1, f"MOV R{op & 7},A", []
    raise AssertionError(f"Unhandled opcode {op:02X}")


def alu_decode(mnemonic, normalized_op, imm):
    mode = normalized_op & 0x0F
    if mode == 0x04:
        return 2, f"{mnemonic} A,#{hx(imm)}", []
    if mode == 0x05:
        return 2, f"{mnemonic} A,{direct(imm)}", []
    if mode in (0x06, 0x07):
        return 1, f"{mnemonic} A,@R{mode & 1}", []
    return 1, f"{mnemonic} A,R{mode & 7}", []


def logic_decode(mnemonic, normalized_op, a, b):
    mode = normalized_op & 0x0F
    if mode == 0x02:
        return 2, f"{mnemonic} {direct(a)},A", []
    if mode == 0x03:
        return 3, f"{mnemonic} {direct(a)},#{hx(b)}", []
    if mode == 0x04:
        return 2, f"{mnemonic} A,#{hx(a)}", []
    if mode == 0x05:
        return 2, f"{mnemonic} A,{direct(a)}", []
    if mode in (0x06, 0x07):
        return 1, f"{mnemonic} A,@R{mode & 1}", []
    return 1, f"{mnemonic} A,R{mode & 7}", []


def contiguous_ranges(mem):
    keys = sorted(mem)
    if not keys:
        return []
    ranges = []
    start = prev = keys[0]
    for k in keys[1:]:
        if k == prev + 1:
            prev = k
        else:
            ranges.append((start, prev))
            start = prev = k
    ranges.append((start, prev))
    return ranges


def build_labels(mem):
    labels = {}
    for start, end in contiguous_ranges(mem):
        pc = start
        while pc <= end:
            size, _text, targets = decode(mem, pc, labels={})
            for t in targets:
                if t in mem:
                    labels.setdefault(t, f"L{t:04X}")
            pc += size
    return labels


def disassemble(mem, source):
    labels = build_labels(mem)
    out = [
        f"; Disassembly of {source}",
        "; CPU: Intel MCS-51 / 8051",
        "; Generated by disasm_8051.py",
        "",
    ]
    for start, end in contiguous_ranges(mem):
        out.append(f"; Range {start:04X}h..{end:04X}h")
        pc = start
        while pc <= end:
            if pc in labels:
                out.append(f"{labels[pc]}:")
            size, text, _targets = decode(mem, pc, labels)
            raw = " ".join(f"{mem.get(pc + i, 0):02X}" for i in range(size))
            out.append(f"{pc:04X}:  {raw:<8}  {text}")
            pc += size
        out.append("")
    return "\n".join(out)


def main():
    parser = argparse.ArgumentParser(description="Simple Intel HEX to 8051 ASM disassembler")
    parser.add_argument("hexfile")
    parser.add_argument("-o", "--output")
    parser.add_argument("--bin")
    args = parser.parse_args()

    mem = read_ihex(args.hexfile)
    asm = disassemble(mem, Path(args.hexfile).name)
    output = Path(args.output) if args.output else Path(args.hexfile).with_suffix(".asm")
    output.write_text(asm + "\n")

    if args.bin:
        ranges = contiguous_ranges(mem)
        lo, hi = ranges[0][0], ranges[-1][1]
        image = bytes(mem.get(a, 0xFF) for a in range(lo, hi + 1))
        Path(args.bin).write_bytes(image)

    print(f"Wrote {output} ({len(asm.splitlines())} lines)")


if __name__ == "__main__":
    main()
