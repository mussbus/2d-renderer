"""Losslessly encode the four E1 GPU PPM readbacks as review PNGs.

Default output stays in the local cache. --compare checks the recorded review
images on the current reference machine; driver-independent pixels are not claimed.
"""
import argparse
import hashlib
from pathlib import Path
import struct
import zlib


def chunk(kind, payload):
    return (struct.pack(">I", len(payload)) + kind + payload
            + struct.pack(">I", zlib.crc32(kind + payload) & 0xffffffff))


def encode(raw):
    magic, dimensions, maximum, rgb = raw.split(b"\n", 3)
    width, height = map(int, dimensions.split())
    if magic != b"P6" or maximum != b"255" or width <= 0 or height <= 0 or len(rgb) != width * height * 3:
        raise ValueError("Invalid E1 RGB readback")
    rows = b"".join(b"\0" + rgb[y * width * 3:(y + 1) * width * 3] for y in range(height))
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))
    return png


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=Path(".zig-cache/e1-captures"))
    parser.add_argument("--output", type=Path, default=Path(".zig-cache/e1-review"))
    parser.add_argument("--compare", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    for tick in (120, 176, 212, 256):
        name = f"tick_{tick}.png"
        png = encode((args.input / f"tick_{tick}.ppm").read_bytes())
        if args.compare is not None and png != (args.compare / name).read_bytes():
            raise ValueError(f"E1 repeat readback differs at tick {tick}")
        (args.output / name).write_bytes(png)
        print(f"{name} sha256={hashlib.sha256(png).hexdigest()}")
    print("E1_REVIEW_OK frames=4 lossless_rgb=true")


if __name__ == "__main__":
    main()
