#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""plié, held to its word: the same program, folded into Haskell and into JavaScript, gives
the same bytes on the same input; the compiled files kept in the repository are the ones
their sources give; and the compiler refuses what it must. Needs GHC (with aeson and
cryptohash-sha256) and Node. The Lean fold is written and kept, not checked here: no Lean was
installed where this was made (HANDOVER.md)."""
import json, os, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLIE = ROOT / "plie" / "plie.py"
sys.path.insert(0, str(ROOT / "plie"))
import plie  # noqa: E402

checks = []


def check(name, ok, detail=""):
    checks.append(ok)
    print(("ok    " if ok else "FAIL  ") + name + ("" if ok or not detail else f"\n      {detail}"))


def compiled(tmp, sources):
    """The Haskell fold built into a program, and the JavaScript fold written beside it."""
    hs = tmp / "hs" / "Plie"
    hs.mkdir(parents=True)
    subprocess.run([sys.executable, PLIE, "hs", hs, *sources], check=True)
    main = tmp / "hs" / "Main.hs"
    main.write_text("import qualified Data.ByteString as B\nimport qualified Data.Text as T\nimport qualified Data.Text.IO as TIO\n"
                    "import System.Environment (getArgs)\nimport Plie.Bridge (call)\nimport Plie.Entries (entries)\n"
                    "main :: IO ()\nmain = do { [f] <- getArgs; i <- B.getContents; either error TIO.putStrLn (call entries (T.pack f) i) }\n")
    exe = tmp / "fold"
    r = subprocess.run(["ghc", "-O0", "-v0", f"-i{ROOT / 'plie' / 'prelude'}", f"-i{tmp / 'hs'}", "-outputdir", tmp / "o",
                        main, "-o", exe], capture_output=True, text=True)
    if r.returncode:
        print(r.stdout + r.stderr)
        sys.exit("plie: the Haskell fold does not build")
    js = tmp / "fold.mjs"
    subprocess.run([sys.executable, PLIE, "js", js, (ROOT / "plie" / "prelude" / "plie.js").as_uri(), *sources], check=True)
    return exe, js


def both(exe, js, fn, value):
    text = json.dumps(value, ensure_ascii=False).encode("utf-8")
    h = subprocess.run([exe, fn], input=text, capture_output=True)
    j = subprocess.run(["node", ROOT / "plie" / "run.mjs", js, fn], input=text, capture_output=True)
    return h.stdout, j.stdout, (h.stderr + j.stderr).decode("utf-8", "replace")


def main():
    with tempfile.TemporaryDirectory() as d:
        tmp = Path(d)
        exe, js = compiled(tmp, [ROOT / "record" / "Json.plie", ROOT / "tests" / "plie" / "Conformance.plie"])
        inputs = [
            {"ints": [-15, -7, -1, 0, 1, 6, 7, 300, 9007199254740991], "texts": ["", "abc", "ABé", "a😀b", "Zz\u0001\t\"\\", "aaxa"],
             "hexes": ["", "00ff", "C3a9", "abc", "zz", "c3"]},
            {"ints": [], "texts": [], "hexes": []},
            {"ints": [5, 3, 5, 1], "texts": ["", "😀", "z", "é"], "hexes": ["7f"], "€": {"b": [1, None, True], "a": "x"}},
        ]
        for k, value in enumerate(inputs, 1):
            h, j, err = both(exe, js, "conformance", value)
            check(f"Haskell and JavaScript give the same bytes ({k})", h == j and h.strip() != b"", err or f"hs {h[:200]!r}\n      js {j[:200]!r}")
        out = json.loads(both(exe, js, "conformance", inputs[0])[0])
        check("division and remainder round toward minus infinity", out["div"][:2] == [-3, -1] and out["mod"][:2] == [6, 0])
        check("text is counted by code point", out["textLength"][3] == 3)
        check("an emoji sorts by code point, keys by UTF-16 unit", both(exe, js, "conformance", inputs[2])[0].count(b'"sortUtf16":["z","\xc3\xa9","\xf0\x9f\x98\x80","\xee\x80\x80"]') == 1)
        check("SHA-256 of the empty text is the known one", out["sha256"][0] == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        check("a canonical object orders its keys and escapes as RFC 8785 says",
              json.loads(both(exe, js, "conformance", {"b": 1, "a": "\u0001\u001f\"é"})[0])["canonical"] == '{"a":"\\u0001\\u001f\\"é","b":1}')
        check("unhex refuses an odd length and a stray digit", out["unhex"][3:5] == [None, None] and out["unhex"][2] == "c3a9")
        check("a float is refused at the door", both(exe, js, "conformance", {"ints": [1.5]})[0] == b"")
    # what the compiler must refuse
    with tempfile.TemporaryDirectory() as d:
        bad = Path(d) / "Bad.plie"
        for name, src in [("a definition without a signature", "module Bad where\nf x = x\n"),
                          ("a prelude name redefined", "module Bad where\nmap : Int -> Int\nmap x = x\n"),
                          ("a name reserved by Lean", "module Bad where\ntheorem : Int\ntheorem = 1\n"),
                          ("a comparison chained", "module Bad where\nf : Int -> Bool\nf x = 1 < x < 3\n")]:
            bad.write_text(name and src, encoding="utf-8")
            r = subprocess.run([sys.executable, PLIE, "hs", d, bad], capture_output=True, text=True)
            check(f"refuses {name}", r.returncode == 1 and "plié:" in r.stderr, r.stderr)
    # the folds kept in the repository are those their sources give
    for target, out in [("hs", ROOT / "record" / "gen" / "hs" / "Plie"), ("lean", ROOT / "record" / "gen" / "lean" / "Plie"),
                        ("js", ROOT / "record" / "gen" / "record.js")]:
        sources = sorted((ROOT / "record").glob("*.plie"))
        if not out.exists():
            check(f"the {target} fold of record/ is kept", False, f"{out} missing")
            continue
        with tempfile.TemporaryDirectory() as d:
            fresh = Path(d) / ("record.js" if target == "js" else "")
            args = [sys.executable, PLIE, target, fresh if target == "js" else d]
            if target == "js":
                args.append("../../plie/prelude/plie.js")
            subprocess.run(args + sources, check=True)
            kept = {p.name: p.read_bytes() for p in (out.iterdir() if out.is_dir() else [out]) if p.suffix in (".hs", ".lean", ".js")}
            made = {p.name: p.read_bytes() for p in (Path(d).iterdir()) if p.suffix in (".hs", ".lean", ".js")}
            check(f"the {target} fold of record/ is the one its sources give", kept == made,
                  f"differs: {sorted(set(kept) ^ set(made)) or [k for k in kept if kept[k] != made.get(k)]}")
    print(f"{sum(checks)} of {len(checks)} hold")
    return 0 if all(checks) else 1


if __name__ == "__main__":
    sys.exit(main())
