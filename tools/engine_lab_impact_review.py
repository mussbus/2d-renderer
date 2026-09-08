"""Losslessly encode the seven native Engine Lab PPM readbacks for owner review.

This only encodes captured RGB bytes; it never renders or synthesizes pixels.
Outputs stay beside this task's captures. No accepted evidence is overwritten.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zlib

CAPTURE_DIR = Path(__file__).resolve().parents[1] / ".tmp/projectile-impact/captures"
NAMES = ("ready", "launch", "flight", "contact", "fade", "drain", "reset")


def chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture-dir", type=Path, default=CAPTURE_DIR)
    parser.add_argument("--names", nargs="+", default=NAMES)
    args = parser.parse_args()
    records = []
    for name in args.names:
        if Path(name).name != name or not name:
            raise ValueError("Capture names must be simple file stems")
        source = args.capture_dir / f"{name}.ppm"
        magic, dimensions, maximum, rgb = source.read_bytes().split(b"\n", 3)
        width, height = map(int, dimensions.split())
        if magic != b"P6" or maximum != b"255" or (width, height) != (640, 480) or len(rgb) != width * height * 3:
            raise ValueError(f"Unexpected bounded native readback: {source}")
        rows = b"".join(b"\0" + rgb[start:start + width * 3] for start in range(0, len(rgb), width * 3))
        encoded = zlib.compress(rows, 9)
        if zlib.decompress(encoded) != rows:
            raise ValueError("Lossless round-trip mismatch")
        png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) + chunk(b"IDAT", encoded) + chunk(b"IEND", b"")
        output = source.with_suffix(".png")
        output.write_bytes(png)
        records.append({"name": name, "width": width, "height": height, "rgb_sha256": hashlib.sha256(rgb).hexdigest(), "png_sha256": hashlib.sha256(png).hexdigest()})
    (args.capture_dir / "manifest.json").write_text(json.dumps({"schema": 1, "source": "SDL3 direct3d12 captureUnified", "lossless_rgb": True, "captures": records}, indent=2) + "\n", encoding="utf-8")
    print(f"ENGINE_LAB_IMPACT_REVIEW_OK captures={len(records)} lossless_rgb=true")


if __name__ == "__main__":
    main()
