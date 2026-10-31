#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The notice the compiled BLS check carries wherever it goes: each Rust crate compiled into
it, its version, its licence as it states it, its authors, and its licence text, as the MIT
and BSD licences ask. Of a crate under MIT or Apache-2.0, MIT is taken. Identical texts are
given once. Read from `cargo metadata` and the crates' own files, so the lockfile decides.

    python3 record/bls/notice.py > record/bls/NOTICE
"""
import json, subprocess, sys
from pathlib import Path

here = Path(__file__).resolve().parent
meta = json.loads(subprocess.run(["cargo", "metadata", "--format-version", "1", "--locked",
                                  "--filter-platform", "wasm32-unknown-unknown"], cwd=here, capture_output=True, check=True).stdout)
ids = {p["id"]: p for p in meta["packages"]}
nodes = {n["id"]: n for n in meta["resolve"]["nodes"]}
seen, stack = set(), [meta["resolve"]["root"]]
while stack:  # what the library links, not what builds it
    i = stack.pop()
    if i not in seen:
        seen.add(i)
        stack += [d["pkg"] for d in nodes[i]["deps"] if any(k["kind"] is None for k in d["dep_kinds"])]
crates = sorted((ids[i] for i in seen if ids[i]["name"] != "releve-bls"), key=lambda p: p["name"])


def text_of(p):
    root = Path(p["manifest_path"]).parent
    for name in ("LICENSE-MIT", "LICENSE-MIT.md", "LICENSE", "LICENSE.txt", "COPYING"):
        f = root / name
        if f.is_file():
            return f.read_text(encoding="utf-8").strip()
    sys.exit(f"notice: no licence text in {p['name']} {p['version']}")


out = ["Rust crates compiled into the BLS check (record/bls), as releve-bls and as WebAssembly in record/verifier.html.",
       "Of each crate offered under MIT or Apache-2.0, MIT is taken.", ""]
texts = {}
for p in crates:
    authors = ", ".join(a.split(" <")[0] for a in p.get("authors") or []) or "its authors"
    out.append(f"- {p['name']} {p['version']}: {p['license']}; {authors}")
    texts.setdefault(text_of(p), []).append(f"{p['name']} {p['version']}")
for text, names in texts.items():
    out += ["", "---", "For " + ", ".join(names) + ":", "", text]
print("\n".join(out))
