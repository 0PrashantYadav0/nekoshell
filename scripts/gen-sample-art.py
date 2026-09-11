#!/usr/bin/env python3
"""Generate the sample pixel-art PNGs in art/. Original artwork, MIT."""
import struct
import zlib
from pathlib import Path

SCALE = 12
PALETTE = {"P": (203, 166, 247), "W": (205, 214, 244), "K": (30, 30, 46), "R": (245, 194, 231),
           "N": (250, 179, 135), "G": (166, 227, 161), "B": (137, 180, 250), "Y": (249, 226, 175)}

SPRITES = {
    "neko": [
        "....P......P....", "...PP......PP...", "...PPP....PPP...", "..PPPPPPPPPPPP..",
        "..PPPPPPPPPPPP..", ".PPPPPPPPPPPPPP.", ".PPWWPPPPPPWWPP.", ".PPWKPPPPPPWKPP.",
        ".PPPPPPPPPPPPPP.", ".PRRPPPPNPPPPRR.", ".PRRPPPNNNPPPRR.", "..PPPPPPPPPPPP..",
        "..PPPPPPPPPPPP..", "...PPPPPPPPPP...", "....PP....PP....", "................"],
    "ghost": [
        "................", ".....BBBBBB.....", "....BBBBBBBB....", "...BBBBBBBBBB...",
        "...BBWWBBBBWWB..", "...BBWKBBBBWKB..", "...BBBBBBBBBBB..", "...BBBBBBBBBBB..",
        "...BBBBBBBBBBB..", "...BBBBBBBBBBB..", "...BBBBBBBBBBB..", "...BBBBBBBBBBB..",
        "...BB.BBBB.BBB..", "...B...BB...B...", "................", "................"],
    "slime": [
        "................", "................", "......GGGG......", "....GGGGGGGG....",
        "...GGGGGGGGGG...", "..GGGGGGGGGGGG..", "..GGWWGGGGWWGG..", "..GGWKGGGGWKGG..",
        ".GGGGGGGGGGGGGG.", ".GGGGGGGGGGGGGG.", ".GGGGGYYYYGGGGG.", ".GGGGGGGGGGGGGG.",
        "..GGGGGGGGGGGG..", "...GGGGGGGGGG...", "................", "................"],
}


def png_bytes(rows):
    h = len(rows) * SCALE
    w = len(rows[0]) * SCALE
    raw = bytearray()
    for row in rows:
        line = bytearray()
        for ch in row:
            rgba = PALETTE[ch] + (255,) if ch in PALETTE else (0, 0, 0, 0)
            line += bytes(rgba) * SCALE
        for _ in range(SCALE):
            raw += b"\x00" + line

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")


def main():
    out = Path(__file__).resolve().parent.parent / "art"
    out.mkdir(exist_ok=True)
    for name, rows in SPRITES.items():
        (out / f"{name}.png").write_bytes(png_bytes(rows))
        print(f"wrote art/{name}.png")


if __name__ == "__main__":
    main()
