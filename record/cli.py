# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The record's command line, from the repository's root.

    python -m record verify BUNDLE --roots ROOTS [--previous BUNDLE]   every check, named
    python -m record recompute BUNDLE | RECORD                          the readings again, compared by byte
    python -m record recompute --v1 CORPUS                              readings of a relevé 0.10 corpus
    python -m record changes BEFORE AFTER                               what changed on a page between two of its records

`releve` must be on the path, or named in RELEVE; it holds the core (record/*.plie)."""
import json, sys
from record import core, observation, psl, verify
from record.run import ENERGY


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def recompute(record):
    """The readings rebuilt from the record's observation and rule results, and whether they are its own, byte for byte."""
    lists = psl.load()
    named = {r["name"]: r for r in record["readings"]}
    psl_named = named.get("dependencies", {}).get("value", {}).get("psl")
    again = core.call("readingsOf", {"observation": record["observation"], "rules": record["rules"], "site": record["site"],
                                     "psl": lists, "energy": named.get("energy", {}).get("value", {}).get("coefficient", ENERGY)})
    kept, made = core.run("canonicalOf", record["readings"]), core.run("canonicalOf", again)
    return kept == made, len(json.loads(made)["canonical"].encode("utf-8")), psl_named, lists["version"]


def main(a):
    if not a or a[0] not in ("verify", "recompute", "changes"):
        print(__doc__)
        return 2
    if a[0] == "verify":
        bundle = load(a[1])
        roots = load(a[a.index("--roots") + 1])
        previous = load(a[a.index("--previous") + 1])["record"] if "--previous" in a else None
        checks, ok = verify.verify(bundle, roots, previous)
        verify.show(checks)
        print("verified: every check holds" if ok else "NOT VERIFIED")
        return 0 if ok else 1
    if a[0] == "changes":
        before, after = (load(p).get("record", load(p)) for p in a[1:3])
        out = core.call("changesOf", {"before": before, "after": after})
        if not out["compared"]:
            print("these are records of two different pages; a page is compared only with itself")
            return 1
        print(f"{out['page']}: from {out['from']} to {out['to']}, {len(out['changes'])} change(s)")
        for c in out["changes"]:
            print(f"  {c['delta']:+d}  {c['kind']:<18} {c['key']}")
        return 0
    if a[1] == "--v1":
        lists = psl.load()
        with open(a[2], encoding="utf-8") as f:
            for line in f:
                v = observation.from_v1(line) if line.strip() else None
                if not v:
                    continue
                site = observation.origin(v["url"])
                got = core.call("readingsOf", {"observation": v["observation"], "rules": [], "site": site, "psl": lists, "energy": ENERGY})
                keep = [r for r in got if r["name"] in ("dependencies", "energy")]
                print(json.dumps({"url": v["url"], "at": v["at"], "readings": keep, "not_recorded": v["not_recorded"]}, ensure_ascii=False))
        return 0
    doc = load(a[1])
    record = doc.get("record", doc)
    same, size, named, pinned = recompute(record)
    if named != pinned:
        print(f"the record's dependency reading names list {named}; this relevé holds {pinned}")
    print(f"readings recomputed: {'byte-equal' if same else 'DIFFERENT'} ({size} bytes, canonical)")
    return 0 if same else 1
