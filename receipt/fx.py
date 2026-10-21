# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""Bit-exact fixed-point arithmetic (Q32.32 on Python integers).

No hardware floats anywhere in the kernel: every result is a function of
integers only, so two runtimes that follow this file produce identical bits.
These are the jets of the specification, written as plain integer code.
"""
from fractions import Fraction

F = 32
ONE = 1 << F
HALF = ONE >> 1


def q(x) -> int:
    """Constant to fixed point. Accepts int, str ('0.05', '1/500') or Fraction."""
    fr = Fraction(x)
    num = fr.numerator << F
    return (num + fr.denominator // 2) // fr.denominator if num >= 0 else -((-num + fr.denominator // 2) // fr.denominator)


def to_float(a: int) -> float:  # for reports only, never inside the kernel
    return a / ONE


def mul(a, b):
    return (a * b) >> F


def div(a, b):
    if b == 0:
        raise ZeroDivisionError
    return (a << F) // b


def _ln2():
    # ln 2 = sum_{k>=1} 1/(k 2^k), computed at 2F bits then rounded
    P = 2 * F + 8
    acc, k, term = 0, 1, (1 << P) // 2
    while term:
        acc += term // k
        k += 1
        term >>= 1
    return acc >> (P - F)


LN2 = _ln2()


def exp(x: int) -> int:
    """e^x for fixed-point x. Underflows to 0 below about -22."""
    if x < -q(22):
        return 0
    k = x // LN2
    r = x - k * LN2                     # 0 <= r < ln2
    P = 2 * F                           # extra guard bits
    R = r << (P - F)
    one = 1 << P
    term, acc, n = one, one, 1
    while term:
        term = (term * R >> P) // n
        acc += term
        n += 1
    out = acc >> (P - F)
    return out << k if k >= 0 else out >> (-k)


def ln(x: int) -> int:
    """Natural log of fixed-point x > 0."""
    if x <= 0:
        raise ValueError("ln of non-positive")
    k = x.bit_length() - 1 - F          # x = m * 2^k with m in [1, 2)
    m = x >> k if k >= 0 else x << (-k)
    P = 2 * F
    M = m << (P - F)
    one = 1 << P
    t = ((M - one) << P) // (M + one)   # atanh argument, |t| < 1/3
    t2 = t * t >> P
    acc, term, n = 0, t, 1
    while term:
        acc += term // n
        term = term * t2 >> P
        n += 2
    return (2 * acc >> (P - F)) + k * LN2


def sigmoid(x: int) -> int:
    if x >= 0:
        return div(ONE, ONE + exp(-x))
    ex = exp(x)
    return div(ex, ONE + ex)


def sqrt(x: int) -> int:
    from math import isqrt
    return isqrt(x << F)
