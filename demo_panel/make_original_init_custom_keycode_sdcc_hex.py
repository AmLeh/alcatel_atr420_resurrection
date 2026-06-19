import subprocess
from pathlib import Path

from make_original_init_custom_keycode_hex import read_ihex, write_ihex, put


ROOT = Path(__file__).resolve().parents[1]
DEMO_DIR = Path(__file__).resolve().parent
BUILD_DIR = DEMO_DIR / "build"
SDCC_BUILD_DIR = BUILD_DIR / "sdcc"

SOURCE_HEX = ROOT / "ST_M27256.HEX"
SOURCE_C = DEMO_DIR / "original_init_custom_keycode_sdcc.c"
SDCC = ROOT / "compilers" / "sdcc" / "bin" / "sdcc.exe"
SDCC_IHX = SDCC_BUILD_DIR / "original_init_custom_keycode_sdcc.ihx"
OUT_HEX = BUILD_DIR / "ORIGINAL_INIT_CUSTOM_KEYCODE_SDCC.HEX"

HOOK_ADDR = 0x6C00


def compile_sdcc():
    SDCC_BUILD_DIR.mkdir(parents=True, exist_ok=True)
    cmd = [
        str(SDCC),
        "-mmcs51",
        "--model-small",
        "--code-loc",
        f"0x{HOOK_ADDR:04X}",
        "--xram-loc",
        "0x0000",
        "--iram-size",
        "128",
        "--out-fmt-ihx",
        "-I.",
        "-o",
        str(SDCC_IHX),
        str(SOURCE_C),
    ]
    subprocess.run(cmd, cwd=ROOT, check=True)


def main():
    compile_sdcc()

    mem = read_ihex(SOURCE_HEX)
    app = read_ihex(SDCC_IHX)

    lowest = min(app)
    if lowest != HOOK_ADDR:
        raise RuntimeError(f"SDCC app starts at 0x{lowest:04X}, expected 0x{HOOK_ADDR:04X}")

    for addr, value in app.items():
        if addr < HOOK_ADDR:
            raise RuntimeError(f"unexpected compiled byte below hook: 0x{addr:04X}")
        if addr in mem and mem[addr] not in (0x00, 0xFF):
            # The selected high ROM area is NOP-filled in the known-good image.
            # Stop if a future dump uses it for real code/data.
            raise RuntimeError(f"compiled app overlaps non-empty original byte at 0x{addr:04X}")
        mem[addr] = value

    put(mem, 0x034C, [0x02, (HOOK_ADDR >> 8) & 0xFF, HOOK_ADDR & 0xFF])

    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    write_ihex(OUT_HEX, mem)

    print(f"Built: {OUT_HEX}")
    print(f"Compiled C app: {SDCC_IHX}")
    print("Patch: 034C -> LJMP 6C00")
    print("Behavior: original startup/init, SDCC C display/key loop, ON/OFF jumps to original shutdown handler")


if __name__ == "__main__":
    main()
