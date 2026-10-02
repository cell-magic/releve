#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The kernel's checks. No browser, no network: recorded observations in,
reports compared byte for byte with the expected ones.

    python tests/run.py            check
    python tests/run.py --accept   rewrite the expected reports after a deliberate change
    python tests/run.py --record   re-record the test pages after changing the observer
                                   (needs Playwright and Chromium), then review the diff

The kernel is `releve` on the PATH, or the program named by RELEVE.
"""
import json, os, re, shutil, subprocess, sys, tempfile, threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
NAMED = os.environ.get("RELEVE", "releve")   # Windows: the name may come without its .exe
RELEVE = shutil.which(NAMED) or shutil.which(NAMED + ".exe") or sys.exit("run: releve not found; build it, or name it in RELEVE")
checks = []


def releve(*args, feed=None):
    r = subprocess.run([RELEVE, *map(str, args)], input=feed, capture_output=True)
    return r.returncode, r.stdout, r.stderr.decode("utf-8").strip()


def check(name, ok):
    checks.append(ok)
    print(("ok    " if ok else "FAIL  ") + name)


def edited(doc, *changes):
    for pattern, by in changes:
        doc = re.sub(pattern, by, doc, flags=re.M)
    return doc.encode("utf-8")


def record():
    class Quiet(SimpleHTTPRequestHandler):
        def log_message(self, *_):
            pass
    server = ThreadingHTTPServer(("127.0.0.1", 8765), partial(Quiet, directory=HERE / "pages"))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    for page in sorted((HERE / "pages").glob("*.html")):
        r = subprocess.run([sys.executable, HERE.parent / "observe" / "observe.py", f"http://localhost:8765/{page.name}",
                            "--contact", "https://example.org/robot"], capture_output=True, check=True)
        (HERE / "observations" / f"{page.stem}.jsonl").write_bytes(r.stdout)
        print(f"recorded {page.stem}")


def main():
    accept = "--accept" in sys.argv
    tmp = Path(tempfile.mkdtemp())
    for obs in sorted((HERE / "observations").glob("*.jsonl")):
        name, corpus, expected = obs.stem, tmp / obs.stem, HERE / "expected" / f"{obs.stem}.md"
        releve("ingest", corpus, feed=obs.read_bytes())
        report = releve("facts", corpus)[1]
        if accept:
            expected.write_bytes(report)
        check(f"report {name}", report == expected.read_bytes())
        # An untouched report records nothing, however often it is fed back.
        check(f"untouched {name}", releve("correct", corpus, feed=report)[2] == "0 corrections recorded")

    # A correction is recorded once, shown with the machine's verdict, and survives replay.
    c = tmp / "fixture"
    edit = edited(releve("facts", c)[1].decode("utf-8"),
                  (r"^- \*\*REVIEW\*\* main-region(.*) \{(.*)\}$", r"- **PASS** main-region\1 // layout uses a single article {\2}"))
    check("correction recorded", releve("correct", c, feed=edit)[2] == "1 correction recorded")
    check("correction idempotent", releve("correct", c, feed=edit)[2] == "0 corrections recorded")
    check("correction shown", re.search(rb"^- \*\*PASS\*\* main-region.*machine said REVIEW // layout uses a single article",
                                        releve("facts", c)[1], re.M) is not None)

    # One combined document for several pages: each section corrects its own page.
    m = tmp / "multi"
    both = b"".join((HERE / "observations" / f"{n}.jsonl").read_bytes() for n in ("fixture", "edge"))
    releve("ingest", m, feed=both)
    combined = releve("facts", m, "--all")[1].decode("utf-8")
    check("combined report", len(re.findall(r"^Observation `", combined, re.M)) == 2)
    edit = edited(combined, (r"^- \*\*REVIEW\*\* main-region", "- **FAIL** main-region"),
                  (r"^- \*\*REVIEW\*\* text-contrast(.*Half faded.*)$", r"- **PASS** text-contrast\1"))
    check("combined corrections", releve("correct", m, feed=edit)[2] == "2 corrections recorded")

    # Seals: intact, tampered, and with Windows line endings.
    check("seal intact", releve("verify", c)[0] == 0)
    (tmp / "tampered").write_bytes(c.read_bytes().replace(b"Relev", b"Relev_", 1))
    check("seal tamper detected", releve("verify", tmp / "tampered")[0] != 0)
    (tmp / "crlf").write_bytes(c.read_bytes().replace(b"\n", b"\r\n"))
    check("seal CRLF", releve("verify", tmp / "crlf")[0] == 0)
    report = releve("facts", c)[1].replace(b"\n", b"\r\n")
    check("report read back with Windows line endings", releve("correct", c, feed=report)[2] == "0 corrections recorded")

    # An edit that cannot be read is refused whole: a reviewer's decision is never dropped in silence.
    c2 = tmp / "edge"
    report = releve("facts", c2)[1].decode("utf-8")
    for name, change in [("a note typed after the id", (r"^(- \*\*REVIEW\*\* .*\})$", r"\1 my note")),
                         ("an unknown verdict word", (r"^- \*\*REVIEW\*\*", "- **OK**"))]:
        code, _, said = releve("correct", c2, feed=edited(report, change))
        check(f"{name} is refused, and nothing is recorded", code == 1 and "cannot be read" in said
              and releve("correct", c2, feed=report.encode("utf-8"))[2] == "0 corrections recorded")
    note = edited(report, (r"^- \*\*REVIEW\*\*(.*) \{(.*)\}$", r"- **PASS**\1 // seen // and checked {\2}"))
    releve("correct", c2, feed=note)
    check("a note keeps all of its text", b"// seen \\/\\/ and checked" in releve("facts", c2)[1]
          and releve("correct", c2, feed=releve("facts", c2)[1])[2] == "0 corrections recorded")

    (tmp / "damaged").write_bytes(b"\n\nnot a record\n")
    code, _, said = releve("facts", tmp / "damaged")
    check("a damaged corpus is refused, with its line", code == 1 and "line 3" in said)

    cabal = re.search(r"^version:\s*(\S+)", (HERE.parent / "releve.cabal").read_text(encoding="utf-8"), re.M).group(1)
    check("the program and the package state the same release", releve("--version")[1].decode().startswith(f"releve {cabal} "))

    # The address asked for and the browser that rendered are kept and shown.
    o = json.loads((HERE / "observations" / "fixture.jsonl").read_text(encoding="utf-8"))
    o.update(requested="http://localhost:8765/old", browser="Chromium 141.0")
    releve("ingest", tmp / "asked", feed=json.dumps(o, ensure_ascii=False).encode("utf-8"))
    a = json.loads(releve("atlas", tmp / "asked")[1])
    check("requested address and browser kept", a["requested"] == "http://localhost:8765/old" and a["browser"] == "Chromium 141.0"
          and b" \xc2\xb7 Chromium 141.0" in releve("facts", tmp / "asked")[1])
    sys.exit(0 if all(checks) else 1)


if __name__ == "__main__":
    record() if "--record" in sys.argv else main()
