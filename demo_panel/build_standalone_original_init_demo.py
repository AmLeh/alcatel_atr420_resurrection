import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEMO_DIR = Path(__file__).resolve().parent
BUILD_DIR = DEMO_DIR / "build" / "standalone_c"

SDCC = ROOT / "compilers" / "sdcc" / "bin" / "sdcc.exe"
PACKIHX = ROOT / "compilers" / "sdcc" / "bin" / "packihx.exe"
SOURCE_C = DEMO_DIR / "standalone_original_init_demo.c"
BASE = BUILD_DIR / "standalone_original_init_demo"
IHX = BASE.with_suffix(".ihx")
OUT_HEX = DEMO_DIR / "build" / "STANDALONE_ORIGINAL_INIT_DEMO_C.HEX"


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
    print(f"Compiled C app: {IHX}")
    print("Behavior: standalone SDCC firmware, C clone of original startup init, display/key demo")


if __name__ == "__main__":
    main()
