# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""Which provenance markers an image file carries, read from its bytes: presence and size
alone. No manifest is parsed and no signature checked; a marker present says only that the
bytes of its kind are there.

    c2pa   JPEG APP11 JUMBF; PNG caBX; ISO-BMFF uuid box d8fec3d6-1b0e-483c-9297-5828877ec481
    exif   JPEG APP1 "Exif"; PNG eXIf
    iptc   JPEG APP13 "Photoshop 3.0" 8BIM; XMP in JPEG APP1

The size of a class is the sum of the bytes of its segments, chunks or boxes, headers
included; 0 when none is there. A file that is none of the three formats, or that breaks
off, is read as far as it holds."""
import struct

CLASSES = ("c2pa", "exif", "iptc")
C2PA_UUID = bytes.fromhex("d8fec3d61b0e483c92975828877ec481")
XMP = b"http://ns.adobe.com/xap/1.0/\0"


def inspect(data):
    """{class: bytes} for the three classes, from a file's bytes."""
    sizes = dict.fromkeys(CLASSES, 0)
    if data[:2] == b"\xff\xd8":
        jpeg(data, sizes)
    elif data[:8] == b"\x89PNG\r\n\x1a\n":
        png(data, sizes)
    elif data[4:8] == b"ftyp":
        bmff(data, sizes)
    return sizes


def jpeg(data, sizes):
    i = 2
    while i + 4 <= len(data) and data[i] == 0xFF:
        marker = data[i + 1]
        if marker in (0xD9, 0xDA):  # end of image, start of scan: no marker segment follows
            return
        if marker == 0x01 or 0xD0 <= marker <= 0xD7:  # standalone markers have no length
            i += 2
            continue
        length = struct.unpack(">H", data[i + 2:i + 4])[0]
        if length < 2 or i + 2 + length > len(data):
            return
        body = data[i + 4:i + 2 + length]
        whole = 2 + length
        if marker == 0xEB and body[:2] == b"JP" and body[12:16] == b"jumb":  # APP11: "JP", instance, sequence, LBox, TBox
            sizes["c2pa"] += whole
        elif marker == 0xE1 and body.startswith(b"Exif\0\0"):
            sizes["exif"] += whole
        elif marker == 0xE1 and body.startswith(XMP):
            sizes["iptc"] += whole
        elif marker == 0xED and body.startswith(b"Photoshop 3.0\0") and body[14:18] == b"8BIM":
            sizes["iptc"] += whole
        i += whole


def png(data, sizes):
    i = 8
    while i + 12 <= len(data):
        length, kind = struct.unpack(">I4s", data[i:i + 8])
        whole = 12 + length
        if i + whole > len(data):
            return
        if kind == b"caBX":
            sizes["c2pa"] += whole
        elif kind == b"eXIf":
            sizes["exif"] += whole
        elif kind == b"IEND":
            return
        i += whole


def bmff(data, sizes):
    i = 0
    while i + 8 <= len(data):
        size, kind = struct.unpack(">I4s", data[i:i + 8])
        head = 8
        if size == 1:
            if i + 16 > len(data):
                return
            size, head = struct.unpack(">Q", data[i + 8:i + 16])[0], 16
        elif size == 0:
            size = len(data) - i
        if size < head or i + size > len(data):
            return
        if kind == b"uuid" and data[i + head:i + head + 16] == C2PA_UUID:
            sizes["c2pa"] += size
        i += size
