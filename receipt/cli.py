# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The receipt's command line, from the repository's root.

    python -m receipt sample  <manifest.txt> <receipt.json> [--budget N]
    python -m receipt bundle  <manifest.txt> <receipt.json> <bundle.wacz> [--conditions c.json]
    python -m receipt verify  <receipt.json> <bundle.wacz | manifest.txt>

manifest.txt: one line per page in crawl order, "<url>\\t<path to saved html>".
"""
import sys, json
from . import sampler, bundle


def _pages(manifest):
    out = []
    with open(manifest, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if line:
                url, path = line.split("\t")
                with open(path, encoding="utf-8", errors="replace") as h:
                    out.append((url, h.read()))
    return out


def main(a):
    if not a or a[0] not in ("sample", "bundle", "verify"):
        print(__doc__); return 2
    if a[0] == "sample":
        budget = int(a[a.index("--budget") + 1]) if "--budget" in a else 40
        pages = _pages(a[1])
        picked, rec, _ = sampler.run(pages, budget)
        json.dump(rec, open(a[2], "w"), indent=1)
        c = rec["coverage"]
        print(f"{len(pages)} pages, {len(picked)} picked, head {rec['head'][:16]}")
        print(f"coverage radius {c['radius']} ({c['stop']}); best possible radius in [{c['optimal_radius_interval'][0]}, {c['radius']}]")
        return 0
    if a[0] == "bundle":
        cond = json.load(open(a[a.index("--conditions") + 1])) if "--conditions" in a else {}
        data = bundle.build(_pages(a[1]), json.load(open(a[2])), cond)
        open(a[3], "wb").write(data)
        print(f"bundle written: {len(data)} bytes")
        return 0
    rec = json.load(open(a[1]))
    if a[2].endswith(".wacz"):
        r = bundle.verify(open(a[2], "rb").read(), rec)
        print("valid" if r["ok"] else "INVALID", "|", ", ".join(f"{k}={r[k]}" for k in ("integrity", "signature", "replay", "evidence", "pages")))
        for p in r["problems"]:
            print("  -", p)
        return 0 if r["ok"] else 1
    ok = sampler.verify(_pages(a[2]), rec)
    print("valid" if ok else "INVALID")
    return 0 if ok else 1
