# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The public beacon a selection is drawn from: drand's quicknet (League of Entropy), a
round every 3 seconds, each a BLS signature on BLS12-381 (bls-unchained-g1-rfc9380) whose
SHA-256 is the round's randomness. The round taken is the first one published after the
candidates were dated, so no one could know it when they were chosen.

The beacon is asked within a bounded window, over several of drand's relays. If no round
comes, the record says "selection not beacon-seeded" (run.py), and nothing stands in for
it. The BLS check is record/bls, one Rust source run here as releve-bls and in the browser
as WebAssembly; where releve-bls is not built, the round is said not checked, never taken
as checked."""
import json, os, shutil, subprocess, time, urllib.request
from pathlib import Path

CHAIN = "52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971"
GENESIS, PERIOD = 1692803367, 3
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


def checker():
    """releve-bls: named in RELEVE_BLS, on the path, or built beside this file (cargo build --release in record/bls)."""
    built = Path(__file__).resolve().parent / "bls" / "target" / "release" / "releve-bls"
    found = os.environ.get("RELEVE_BLS") or shutil.which("releve-bls") or (str(built) if built.is_file() else None)
    return found


def bls(r, signature_hex):
    """Whether the signature is quicknet's over round r: True, False, or None when it cannot be checked here."""
    exe = checker()
    if exe is None:
        return None
    out = subprocess.run([exe, str(int(r)), signature_hex], capture_output=True, text=True, timeout=60)
    return out.returncode == 0 and out.stdout.strip() == "valid"
