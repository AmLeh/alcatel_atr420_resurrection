import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIRMWARE_DIR = Path(__file__).resolve().parent
BUILD_DIR = FIRMWARE_DIR / "build" / "panel_code_scan"

SDCC = ROOT / "compilers" / "sdcc" / "bin" / "sdcc.exe"
PACKIHX = ROOT / "compilers" / "sdcc" / "bin" / "packihx.exe"
SOURCE_C = FIRMWARE_DIR / "tests" / "panel_code_scan.c"
BASE = BUILD_DIR / "panel_code_scan"
IHX = BASE.with_suffix(".ihx")
OUT_HEX = FIRMWARE_DIR / "build" / "PANEL_CODE_SCAN_00_7F.HEX"


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
    print("Behavior: interactive panel raw-code scanner, keys 1/2 step, */# show/auto")


if __name__ == "__main__":
    main()
