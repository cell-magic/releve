# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The core, called: `releve core FUNCTION`, JSON in, canonical JSON out (RFC 8785)."""
import json, os, shutil, subprocess


def releve():
    found = shutil.which(os.environ.get("RELEVE", "releve"))
    if not found:
        raise SystemExit("record: releve not found; build it, or name it in RELEVE")
    return found


def call(function, value):
    """The core's answer, parsed; and its canonical text, as the core wrote it."""
    text = run(function, value)
    return json.loads(text)


def run(function, value):
    r = subprocess.run([releve(), "core", function], input=json.dumps(value, ensure_ascii=False).encode("utf-8"),
                       capture_output=True, timeout=600)
    if r.returncode:
        raise RuntimeError(f"releve core {function}: {r.stderr.decode('utf-8', 'replace').strip()}")
    return r.stdout.decode("utf-8").rstrip("\n")


def canonical(value):
    """The RFC 8785 text of a value, and its SHA-256 in hex, as the core gives them."""
    out = call("canonicalOf", value)
    return out["canonical"], out["hash"]
