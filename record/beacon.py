# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The public beacon a selection is drawn from: drand's quicknet (League of Entropy), a
round every 3 seconds, each a BLS signature on BLS12-381 (bls-unchained-g1-rfc9380) whose
SHA-256 is the round's randomness. The round taken is the first one published after the
candidates were dated, so no one could know it when they were chosen.

The beacon is asked within a bounded window, over several of drand's relays. If no round
comes, the record says "selection not beacon-seeded" (run.py), and nothing stands in for
it. The BLS check needs py_ecc (record/requirements.txt); without it the round is said not
checked, never taken as checked."""
import hashlib, json, time, urllib.request

CHAIN = "52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971"
PUBLIC_KEY = ("83cf0f2896adee7eb8b5f01fcad3912212c437e0073e911fb90022d3e760183c8c4b450b6a0a6c3ac6a5776a2d1064510d1fec758c921cc22b0e"
              "17e63aaf4bcb5ed66304de9cf809bd274ca73bab4af5a6e9c76a4bc09e76eae8991ef5ece45a")
GENESIS, PERIOD = 1692803367, 3
DST = b"BLS_SIG_BLS12381G1_XMD:SHA-256_SSWU_RO_NUL_"
RELAYS = ["https://api.drand.sh", "https://api2.drand.sh", "https://api3.drand.sh", "https://drand.cloudflare.com"]
WINDOW = 60  # seconds within which a round must come


def round_time(r):
    return GENESIS + (r - 1) * PERIOD


def first_after(t):
    """The first round published strictly after time t (seconds since 1970)."""
    return (t - GENESIS) // PERIOD + 2


def fetch(r, relays=RELAYS, window=WINDOW):
    """Round r from the first relay that gives it, within the window: {round, signature, randomness}, or None."""
    deadline = time.monotonic() + window
    while time.monotonic() < deadline:
        wait = round_time(r) - time.time()
        if wait > 0:
            time.sleep(min(wait + 0.5, max(0, deadline - time.monotonic())))
        for base in relays:
            try:
                with urllib.request.urlopen(f"{base}/{CHAIN}/public/{r}", timeout=5) as answer:
                    got = json.loads(answer.read())
                if int(got["round"]) == r:
                    return {"round": r, "signature": got["signature"], "randomness": got["randomness"]}
            except (OSError, ValueError, KeyError):
                continue
        time.sleep(1)
    return None


def bls(r, signature_hex, public_key_hex=PUBLIC_KEY):
    """Whether the signature is quicknet's over round r: True, False, or None when it cannot be checked here."""
    try:
        from py_ecc.bls.hash_to_curve import hash_to_G1
        from py_ecc.bls.point_compression import decompress_G1, decompress_G2
        from py_ecc.optimized_bls12_381 import FQ12, G2, final_exponentiate, neg
        from py_ecc.optimized_bls12_381.optimized_pairing import miller_loop
    except ImportError:
        return None
    try:
        sig, pk = bytes.fromhex(signature_hex), bytes.fromhex(public_key_hex)
        s = decompress_G1(int.from_bytes(sig, "big"))
        p = decompress_G2((int.from_bytes(pk[:48], "big"), int.from_bytes(pk[48:], "big")))
        h = hash_to_G1(hashlib.sha256(r.to_bytes(8, "big")).digest(), DST, hashlib.sha256)
        return final_exponentiate(miller_loop(G2, s) * miller_loop(neg(p), h)) == FQ12.one()
    except (ValueError, AssertionError, TypeError):
        return False
