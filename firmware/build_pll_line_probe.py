import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIRMWARE_DIR = Path(__file__).resolve().parent
BUILD_DIR = FIRMWARE_DIR / "build" / "pll_line_probe"

SDCC = ROOT / "compilers" / "sdcc" / "bin" / "sdcc.exe"
PACKIHX = ROOT / "compilers" / "sdcc" / "bin" / "packihx.exe"
SOURCE_C = FIRMWARE_DIR / "tests" / "pll_line_probe.c"
BASE = BUILD_DIR / "pll_line_probe"
IHX = BASE.with_suffix(".ihx")
OUT_HEX = FIRMWARE_DIR / "build" / "PLL_LINE_PROBE.HEX"


def main():
    BUILD_DIR.mkdir(parents=True, exist_ok=True)

    cmd = [
        str(SDCC),
        "-mmcs51",
        "--model-small",
        "--code-loc",
        "0x0000",
        "--xram-loc",
        "0x0000",
        "--iram-size",
        "128",
        "--out-fmt-ihx",
        "--std-sdcc11",
        "--opt-code-size",
        "-I.",
        "-o",
        str(IHX),
        str(SOURCE_C),
    ]
    subprocess.run(cmd, cwd=ROOT, check=True)

    packed = subprocess.check_output([str(PACKIHX), str(IHX)], cwd=ROOT)
    OUT_HEX.write_bytes(packed)

    print(f"Built: {OUT_HEX}")
    print(f"Source: {SOURCE_C}")
    print("Behavior: repeated slow PLL line probe: P3.3, MOVX /WR, CE/8E/5E latch bursts")


if __name__ == "__main__":
    main()
