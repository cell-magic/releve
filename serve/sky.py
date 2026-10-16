# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The sky of a record: an illustration whose cloud dots are moved by the
time stamp that dates the record. Nothing else in the picture moves.

Anyone can draw it again from the record alone, by these steps:

1. The seed is the first four bytes, read big-endian, of the SHA-256 of the
   authority's signed reply (the `reply` of the latest `stamped` record,
   decoded from base64): `openssl dgst -sha256 stamp.tsr`.
2. Two generators, mulberry32 (as below), start from the seed and from the
   seed xor 0x9E3779B9.
3. From the first, a smooth field: for each axis, three waves, each with an
   amplitude, a frequency along x and along y, and a phase.
4. Each dot of the clouds, a sub-path no larger than `dot` in either
   direction, to the right of the `frontier` and outside every box `kept`,
   moves whole by the field at its first point, plus a jitter from the
   second generator, in path order.

The rule (`dot`, `frontier`, `kept`, `amp`, `jitter`) belongs to the illustration and
comes with it. A record changed, or dated otherwise, has another reply, and
so another sky."""
import hashlib, math, re

TOKEN = re.compile(r"[MmLlHhVvZz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?")


def mulberry32(a):
    a &= 0xFFFFFFFF

    def step():
        nonlocal a
        a = (a + 0x6D2B79F5) & 0xFFFFFFFF
        t = a
        t = ((t ^ (t >> 15)) * (1 | t)) & 0xFFFFFFFF
        t = (t + (((t ^ (t >> 7)) * (61 | t)) & 0xFFFFFFFF) ^ t) & 0xFFFFFFFF
        return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296
    return step


def seed(reply):
    """The seed, and the short code a person can read, from the signed reply's bytes."""
    digest = hashlib.sha256(reply).digest()
    return int.from_bytes(digest[:4], "big"), digest[:4].hex()


def subpaths(d):
    """Each sub-path: the tokens of its moveto, whether it is relative, its first point, its box, and the
    tokens of the absolute coordinates within it, each with its axis."""
    tokens = [(m.group(0), m.span()) for m in TOKEN.finditer(d)]
    out, i, cmd, x, y, sx, sy = [], 0, None, 0.0, 0.0, 0.0, 0.0
    while i < len(tokens):
        t = tokens[i][0]
        if t.isalpha():
            cmd = t
            i += 1
            if cmd in "Zz":
                x, y = sx, sy
                continue
        if cmd in "Mm":
            a, b = float(tokens[i][0]), float(tokens[i + 1][0])
            x, y = (x + a, y + b) if cmd == "m" else (a, b)
            sx, sy = x, y
            out.append({"at": (i, i + 1), "rel": cmd == "m", "x": x, "y": y, "box": [x, y, x, y], "abs": []})
            i += 2
            cmd = "l" if cmd == "m" else "L"
            continue
        if cmd in "Ll":
            a, b = float(tokens[i][0]), float(tokens[i + 1][0])
            x, y = (x + a, y + b) if cmd == "l" else (a, b)
            out[-1]["abs"] += [(i, 0), (i + 1, 1)] if cmd == "L" else []
            i += 2
        elif cmd in "Hh":
            a = float(tokens[i][0])
            x = x + a if cmd == "h" else a
            out[-1]["abs"] += [(i, 0)] if cmd == "H" else []
            i += 1
        elif cmd in "Vv":
            a = float(tokens[i][0])
            y = y + a if cmd == "v" else a
            out[-1]["abs"] += [(i, 1)] if cmd == "V" else []
            i += 1
        else:
            raise ValueError(f"sky: the path uses {cmd}, which this drawing does not read")
        box = out[-1]["box"]
        box[:] = [min(box[0], x), min(box[1], y), max(box[2], x), max(box[3], y)]
    return tokens, out


def field(rng, amp):
    waves = [[(amp * (0.5 + rng()), 0.5 + 3 * rng(), 0.5 + 3 * rng(), 2 * math.pi * rng()) for _ in range(3)] for _ in range(2)]
    return lambda x, y: tuple(sum(a * math.sin(2 * math.pi * (fx * x + fy * y) / 2500 + p) for a, fx, fy, p in axis) / 2 for axis in waves)


def number(v, like):
    """A coordinate written with as many decimals as the one it replaces, and at least one."""
    places = max(1, len(like.split(".")[1]) if "." in like else 0)
    s = f"{v:.{places}f}"
    return s[1:] if s.startswith("-") and float(s) == 0 else s


def draw(svg, reply, rule):
    """The illustration with its cloud dots moved by the reply; the short code of its sky."""
    d = re.search(r' d="([^"]+)"', svg).group(1)
    tokens, subs = subpaths(d)
    s, code = seed(reply)
    move = field(mulberry32(s), rule["amp"])
    jitter = mulberry32(s ^ 0x9E3779B9)
    frontier = sorted(rule["frontier"])

    def cloud(p):
        x0, y0, x1, y1 = p["box"]
        edge = next((x for ymax, x in frontier if p["y"] < ymax), frontier[-1][1])
        kept = any(a <= p["x"] <= c and b <= p["y"] <= e for a, b, c, e in rule.get("kept", []))
        return x1 - x0 <= rule["dot"] and y1 - y0 <= rule["dot"] and p["x"] > edge and not kept

    edits, last = {}, (0.0, 0.0)
    for p in subs:
        t = (0.0, 0.0)
        if cloud(p):
            fx, fy = move(p["x"], p["y"])
            # Moves are whole tenths, so that every point of a dot moves alike and its shape is kept exactly.
            t = (round(fx + (jitter() - 0.5) * 2 * rule["jitter"], 1), round(fy + (jitter() - 0.5) * 2 * rule["jitter"], 1))
        shift = (t[0] - last[0], t[1] - last[1]) if p["rel"] else t
        for k, delta in zip(p["at"], shift):
            if delta:
                edits[k] = float(tokens[k][0]) + delta
        for k, axis in p["abs"] if t != (0.0, 0.0) else []:
            edits[k] = float(tokens[k][0]) + t[axis]
        last = t
    out, pos = [], 0
    for k, v in sorted(edits.items()):
        a, b = tokens[k][1]
        text = number(v, tokens[k][0])
        if not text.startswith("-") and a > 0 and (d[a - 1].isdigit() or d[a - 1] == "."):
            text = " " + text
        out += [d[pos:a], text]
        pos = b
    out.append(d[pos:])
    return svg.replace(d, "".join(out), 1), code


def inline(svg, label):
    """The drawing as it stands in a page: no metadata, as wide as its column, named."""
    svg = re.sub(r"<metadata>.*?</metadata>", "", svg, flags=re.S)
    w, h = (re.search(rf'{k}="([\d.]+)"', svg).group(1) for k in ("width", "height"))
    return re.sub(r"<svg[^>]*>", f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="100%" role="img" aria-label="{label}">', svg, count=1)
