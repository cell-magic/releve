# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""Nouns: the single state tree.

A noun is an atom (non-negative int) or a cell (head, tail). Addressing and
editing follow Nock opcodes 0 and 10: axis 1 is the whole noun, 2a is the head
of axis a, 2a+1 its tail. Edits return a new noun that shares every untouched
subtree. Serialisation is canonical, so equal nouns hash equally.
"""
from hashlib import sha256

Noun = object  # int | tuple[Noun, Noun]


def is_cell(n):
    return isinstance(n, tuple)


def slot(axis, n):
    """Nock 0: the subtree of n at axis."""
    if axis < 1:
        raise ValueError("axis must be >= 1")
    for bit in bin(axis)[3:]:
        if not is_cell(n):
            raise ValueError("slot into atom")
        n = n[1] if bit == "1" else n[0]
    return n


def edit(axis, value, n):
    """Nock 10: n with the subtree at axis replaced by value (structural sharing)."""
    if axis == 1:
        return value
    if not is_cell(n):
        raise ValueError("edit into atom")
    parent, last = divmod(axis, 2)
    sub = slot(parent, n)
    sub = (sub[0], value) if last else (value, sub[1])
    return edit(parent, sub, n)


def peg(a, b):
    """Axis of b inside the subtree at a."""
    if b == 1:
        return a
    return peg(a, b // 2) * 2 + (b % 2)


def list_axis(i):
    """Axis of element i in a null-terminated list [x0 [x1 [... 0]]]."""
    return (1 << (i + 2)) - 2


# ---- conversion -------------------------------------------------------------

def cord(s: str) -> int:
    """Text as an atom (little-endian UTF-8), as Hoon cords."""
    return int.from_bytes(s.encode(), "little")


def uncord(a: int) -> str:
    return a.to_bytes((a.bit_length() + 7) // 8, "little").decode()


def from_list(xs):
    out = 0
    for x in reversed(xs):
        out = (x, out)
    return out


def to_list(n):
    out = []
    while is_cell(n):
        out.append(n[0])
        n = n[1]
    return out


def tag(name: str, *fields):
    """A tagged record [%name f1 f2 ...] as a right-nested cell."""
    n = fields[-1] if fields else 0
    for f in reversed(fields[:-1]):
        n = (f, n)
    return (cord(name), n) if fields else cord(name)


# ---- canonical bytes and hash ------------------------------------------------

def _varint(k):
    out = bytearray()
    while True:
        b, k = k & 0x7F, k >> 7
        out.append(b | (0x80 if k else 0))
        if not k:
            return bytes(out)


def jam(n) -> bytes:
    """Canonical serialisation (not Urbit's bit-level jam; same role)."""
    out = bytearray()
    stack = [n]
    while stack:
        x = stack.pop()
        if is_cell(x):
            out.append(1)
            stack.append(x[1])
            stack.append(x[0])
        else:
            if x < 0:
                raise ValueError("atoms are non-negative")
            body = x.to_bytes((x.bit_length() + 7) // 8, "little")
            out.append(0)
            out += _varint(len(body))
            out += body
    return bytes(out)


def _atom_bytes(x: int) -> bytes:
    if x < 0:
        raise ValueError("atoms are non-negative")
    return x.to_bytes((x.bit_length() + 7) // 8, "little")


def merkle(n) -> bytes:
    """Merkle hash of a noun (a content-addressed DAG, as git stores trees):
        atom:  SHA-256(0x00 | varint(len) | little-endian bytes)
        cell:  SHA-256(0x01 | merkle(head) | merkle(tail))
    Equal subtrees have equal hashes wherever they occur."""
    out = {}
    stack = [(n, False)]
    while stack:
        x, ready = stack.pop()
        if not is_cell(x):
            b = _atom_bytes(x)
            out[id(x), "a", x] = sha256(b"\x00" + _varint(len(b)) + b).digest()
            continue
        if ready:
            h, t = x
            out[id(x)] = sha256(b"\x01" + _get(out, h) + _get(out, t)).digest()
        else:
            stack.append((x, True))
            stack.append((x[1], False))
            stack.append((x[0], False))
    return _get(out, n)


def _get(out, x):
    return out[id(x), "a", x] if not is_cell(x) else out[id(x)]


def mug(n) -> str:
    """Hex Merkle root of a noun."""
    return merkle(n).hex()


# ---- signed integers inside atoms --------------------------------------------

def s2a(x: int) -> int:
    """Signed int to atom (zigzag)."""
    return (x << 1) if x >= 0 else ((-x << 1) - 1)


def a2s(a: int) -> int:
    return (a >> 1) if not (a & 1) else -((a + 1) >> 1)
