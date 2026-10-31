#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The fixtures' images, from base.jpg (16 by 16 pixels, drawn once by Chromium's canvas):
each the base with the marker segments its case needs, inserted after the start of image.
The markers are well formed in their framing and say nothing true: no manifest in them is
a real one, and none is meant to verify. Run it again and the same bytes come out."""
import struct
from pathlib import Path

HERE = Path(__file__).resolve().parent
BASE = (HERE / "base.jpg").read_bytes()


def segment(marker, body):
    return bytes([0xFF, marker]) + struct.pack(">H", len(body) + 2) + body


def box(kind, body):
    return struct.pack(">I", len(body) + 8) + kind + body


C2PA = segment(0xEB, b"JP" + struct.pack(">HI", 1, 1) + box(b"jumb", box(
    b"jumd", bytes.fromhex("6332706100110010800000aa00389b71") + b"\x03" + b"c2pa\0")))
EXIF = segment(0xE1, b"Exif\0\0" + b"MM\0*" + struct.pack(">I", 8) + struct.pack(">H", 0) + struct.pack(">I", 0))
IPTC = segment(0xED, b"Photoshop 3.0\0" + b"8BIM" + struct.pack(">H", 0x0404) + b"\0\0"
               + struct.pack(">I", 8) + b"\x1c\x02\x00\x00\x02\x00\x04\x00")


def image(*segments):
    return BASE[:2] + b"".join(segments) + BASE[2:]


FILES = {"clean/photo.jpg": image(C2PA, EXIF, IPTC),
         "stripped/delivered.jpg": image(), "stripped/origin.jpg": image(C2PA),
         "absent/delivered.jpg": image(), "absent/origin.jpg": image(),
         "blocked/delivered.jpg": image(),
         "still-transformed/photo.jpg": image()}

if __name__ == "__main__":
    for name, data in FILES.items():
        (HERE / name).parent.mkdir(exist_ok=True)
        (HERE / name).write_bytes(data)
