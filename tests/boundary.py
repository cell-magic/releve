#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The boundary (BOUNDARY.md), checked: open code imports nothing closed, no closed
directory or closed-licensed file stands in this repository, every open source file
names EUPL-1.2 in its SPDX header.

    python tests/boundary.py [ROOT]

ROOT defaults to this repository. The files read are those git tracks and those it
would track (untracked, not ignored), so a violation shows before it is committed.
"""
import ast, re, subprocess, sys, tomllib
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent).resolve()
SOURCE = {".py", ".hs", ".js", ".mjs", ".sh", ".html", ".css", ".yml", ".yaml", ".json", ".plie", ".lean"}
MARK = "LicenseRef-Bureau-Closed"
CLOSED = re.compile(r"SPDX-" r"License-Identifier:\s*" + MARK)  # a file under the closed licence, not one that names it
TAG = "SPDX-" "License-Identifier: EUPL-1.2"  # split, so that REUSE does not read it as this file's own


def closed_names():
    text = (ROOT / "BOUNDARY.md").read_text(encoding="utf-8")
    block = re.search(r"```boundary\n(.*?)```", text, re.S)
    if not block:
        sys.exit("boundary: BOUNDARY.md names no closed paths (a ```boundary block)")
    return set(block.group(1).split())


def annotated():
    """The paths REUSE.toml licenses for files that cannot carry a comment, as patterns."""
    toml = tomllib.loads((ROOT / "REUSE.toml").read_text(encoding="utf-8"))
    pats = [p for a in toml.get("annotations", []) if a.get("SPDX-License-Identifier") == "EUPL-1.2"
            for p in ([a["path"]] if isinstance(a["path"], str) else a["path"])]
    glob = lambda p: re.compile("^" + re.escape(p).replace(r"\*\*", ".*").replace(r"\*", "[^/]*") + "$")
    return [glob(p) for p in pats]


def files():
    out = subprocess.run(["git", "-C", str(ROOT), "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                         capture_output=True, check=True).stdout
    return sorted({ROOT / p for p in out.decode("utf-8").split("\0") if p and (ROOT / p).is_file()})


def imported(path, text):
    """The modules or paths a source file reaches for, as written."""
    if path.suffix == ".py":
        try:
            tree = ast.parse(text)
        except SyntaxError:
            return []
        out = []
        for n in ast.walk(tree):
            if isinstance(n, ast.Import):
                out += [a.name for a in n.names]
            elif isinstance(n, ast.ImportFrom) and n.module and not n.level:
                out.append(n.module)
            elif isinstance(n, ast.Call) and getattr(n.func, "attr", "") in ("insert", "append") \
                    and "path" in ast.unparse(n.func.value):  # sys.path.insert(0, ...)
                out += [c.value for c in ast.walk(n) if isinstance(c, ast.Constant) and isinstance(c.value, str)]
        return out
    if path.suffix in (".hs", ".plie", ".lean"):
        return re.findall(r"^import\s+(?:qualified\s+)?([\w.]+)", text, re.M)
    if path.suffix in (".js", ".mjs", ".html"):
        return re.findall(r"""(?:\bimport\b[^'"\n]*?|\brequire\s*\(\s*|\bimport\s*\(\s*)['"]([^'"]+)['"]""", text)
    if path.suffix == ".sh":
        return re.findall(r"^\s*(?:source|\.)\s+(\S+)", text, re.M)
    return []


def segments(ref):
    return {s.lower() for s in re.split(r"[/\\.]", ref) if s}


def main():
    names, licensed = closed_names(), annotated()
    problems = []
    for f in files():
        rel = f.relative_to(ROOT)
        for part in rel.parts[:-1]:
            if part.lower() in names:
                problems.append(f"{rel}: in a closed directory ({part}/)")
                break
        try:
            text = f.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue  # images and other binary files are named in REUSE.toml
        if CLOSED.search(text):
            problems.append(f"{rel}: carries the closed licence ({MARK})")
        if f.suffix in SOURCE:
            head = "\n".join(text.splitlines()[:12])
            if TAG not in head and not any(g.match(rel.as_posix()) for g in licensed):
                problems.append(f"{rel}: no SPDX header naming EUPL-1.2")
            for ref in imported(f, text):
                hit = segments(ref) & {n.replace("-", "_") for n in names} | segments(ref) & names
                if hit:
                    problems.append(f"{rel}: reaches for closed code ({ref})")
    for p in problems:
        print("FAIL  " + p)
    print(f"boundary: {len(files())} files, {len(problems)} problem{'s' if len(problems) != 1 else ''}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
