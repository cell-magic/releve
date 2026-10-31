# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The verifier, from the command line. What only the world can check is checked here:
the record against its schema, each time-stamp token under OpenSSL, the beacon round's BLS
signature. Then all of it goes to the core (record/Verify.plie, `releve core verifyBundle`),
which makes every other check, the same ones verifier.html makes in a browser."""
import json
from record import beacon, core, schema, tsa


def edge(bundle):
    """What the core is handed: each check only the world can make, its verdict and what it checked."""
    r = bundle["record"]
    out = {}
    token = bytes.fromhex(bundle.get("token", ""))
    ok, why = tsa.check(token, bundle["root"]) if token else (False, "the bundle holds no token")
    out["tsa"] = {"ok": ok, "imprint": bundle["root"] if ok else None, "detail": why}
    c = r.get("selection", {}).get("commitment", {})
    if c.get("token"):
        t = bytes.fromhex(c["token"])
        ok, why = tsa.check(t, c["hash"])
        out["commitment_tsa"] = {"ok": ok, "imprint": c["hash"] if ok else None, "time": tsa.time_of(t) if ok else None, "detail": why}
    b = r.get("beacon", {})
    if "round" in b:
        v = beacon.bls(b["round"], b["signature"])
        out["bls"] = {"ok": v, "detail": "releve-bls is not built (record/bls): the BLS signature is not checked" if v is None
                      else "the round's signature does not hold under quicknet's key"}
    return out


def verify(bundle, roots, previous=None):
    """Every check, named, in order: [(name, True | False | None, detail)], and whether all hold."""
    wrong = schema.problems(bundle.get("record"))
    checks = [("schema", not wrong, "the record holds to releve-record/2" if not wrong else "; ".join(wrong[:3]))]
    out = core.call("verifyBundle", {"bundle": bundle, "previous": previous, "roots": roots, "edge": edge(bundle)})
    checks += [(c["check"], c["ok"], c["detail"]) for c in out["checks"]]
    return checks, out["ok"] and not wrong


def show(checks):
    for name, ok, detail in checks:
        print(f"{'ok  ' if ok is True else 'FAIL' if ok is False else '--  '}  {name:<16} {detail}")
