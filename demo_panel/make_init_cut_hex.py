from pathlib import Path

from make_original_init_custom_keycode_hex import (
    SOURCE_HEX,
    build_custom_app,
    put,
    read_ihex,
    write_ihex,
)


OUT_DIR = Path(__file__).resolve().parent / "build"
HOOK = 0x6C00

# Natural instruction-boundary checkpoints in the known-good startup path.
# Some branches depend on the external config EPROM/RAM state; building a few
# adjacent cuts makes the hardware test much more informative.
CUTS = [
    (0x0075, "after early latch init and P1.1 pulse"),
    (0x0098, "after internal RAM clear and 0000-0FFF checksum"),
    (0x00A1, "after 0469h option read"),
    (0x00D1, "after first 223B/223E state touch"),
    (0x0108, "after 2000-23FF fill/checksum mirror path"),
    (0x0179, "alternate 047Eh=0 startup branch"),
    (0x01B3, "after channel/config table copy branch"),
    (0x025A, "after initial channel/state calculation"),
    (0x026F, "before original timer/UART init"),
    (0x028D, "after original timer/UART init"),
    (0x02B4, "after initial flags and 2191h mirror"),
    (0x0318, "before final 2248/224A/224C/224F state writes"),
    (0x033C, "before final 224C/224F state writes"),
    (0x034C, "full confirmed original startup"),
]


def build_one(cut_addr, suffix):
    mem = read_ihex(SOURCE_HEX)

    put(mem, cut_addr, [0x02, (HOOK >> 8) & 0xFF, HOOK & 0xFF])
    for addr, data in build_custom_app().items():
        put(mem, addr, data)

    out = OUT_DIR / f"INITCUT_{suffix:04X}.HEX"
    write_ihex(out, mem)
    return out


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    for cut, note in CUTS:
        out = build_one(cut, cut)
        print(f"Built: {out.name}  cut={cut:04X}  {note}")


if __name__ == "__main__":
    main()
