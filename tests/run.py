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
import hashlib, json, os, random, re, shutil, subprocess, sys, tempfile, threading
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

    # A person passes what the machine failed; then what is seen changes. Their reading no longer
    # applies, and the machine's does not quietly take its place: the finding comes back for review.
    v = tmp / "value"
    first = json.loads((HERE / "observations" / "fixture.jsonl").read_text(encoding="utf-8"))
    releve("ingest", v, feed=json.dumps(first).encode("utf-8"))
    weak = next(f for f in json.loads(releve("atlas", v)[1])["findings"] if f["criterion"] == "text-contrast" and f["verdict"] == "fail")
    passed = edited(releve("facts", v)[1].decode("utf-8"), (rf"^- \*\*FAIL\*\*(.*) \{{{weak['id']}\}}$", rf"- **PASS**\1 // brand colour, accepted {{{weak['id']}}}"))
    releve("correct", v, feed=passed)

    def later(colour):
        o = json.loads(json.dumps(first))
        next(s for s in o["surfaces"] if s["key"] == weak["surface"]["key"])["fg"] = colour
        releve("ingest", v, feed=json.dumps(o).encode("utf-8"))
        return next(l for l in releve("facts", v)[1].decode("utf-8").splitlines() if l.endswith(f"{{{weak['id']}}}"))

    check("a person's reading carries while what is seen is unchanged", later(weak["surface"]["fg"]).startswith("- **PASS**"))
    line = later([150, 150, 150, 1])
    check("when it changes, the finding returns to review, not to the machine's verdict",
          line.startswith("- **REVIEW**") and "read otherwise before this changed · machine said FAIL" in line)
    check("an untouched report of it records nothing", releve("correct", v, feed=releve("facts", v)[1])[2] == "0 corrections recorded")
    releve("correct", v, feed=edited(releve("facts", v)[1].decode("utf-8"), (rf"^- \*\*REVIEW\*\*(.*\{{{weak['id']}\}})$", r"- **FAIL**\1")))
    line = later([150, 150, 150, 1])
    check("the new reading then stands, and carries in its turn", line.startswith("- **FAIL**") and "read otherwise" not in line)

    # The reading. A series takes a step for each event, whatever the reader holds; independent
    # events take a quarter of that; a series beside them costs nothing until it is the longer.
    blank = json.loads((HERE / "observations" / "edge.jsonl").read_text(encoding="utf-8"))
    blank["page"].update(lang="en", viewport=None, reflow=320, dupIds=[])

    def event(n, *path):
        return {"n": n, "sel": f"e{n}", "kind": "text", "shown": True, "said": f"word{n}", "path": [list(p) for p in path],
                "box": [0, 0, 9, 9], "size": 16, "weight": 400}

    def readings(pages):
        corpus, lines = Path(tempfile.mkdtemp()) / "c", []
        for i, (events, failing) in enumerate(pages):
            surfaces = [{"kind": "button", "key": f"k{n}", "sel": f"e{n}", "order": n, "ev": n, "name": ""} for n in failing]
            lines.append(json.dumps(dict(blank, url=f"http://localhost/{i}", events=events, surfaces=surfaces)))
        releve("ingest", corpus, feed="\n".join(lines).encode("utf-8"))
        return [json.loads(l)["reading"] for l in releve("atlas", corpus)[1].splitlines()]

    series = [event(n, ("olist", 0), ("item", n + 1)) for n in range(12)]
    apart = [event(n, ("list", 0), ("item", n + 1)) for n in range(12)]
    beside = [[event(n, ("main", 0), ("olist", 1), ("item", 9 + n)) for n in range(d)]
              + [event(n, ("navigation", 2), ("list", 3), ("item", 99 + n)) for n in range(d, 12)] for d in range(1, 7)]
    r = readings([(es, []) for es in [series, apart] + beside])
    check("twelve events in series take twelve steps", (r[0]["depth"], r[0]["steps"], r[0]["lower"], r[0]["upper"]) == (12, 12, 12, 12))
    check("twelve independent events take three", (r[1]["depth"], r[1]["steps"]) == (1, 3))
    check("a series beside the rest costs nothing until it is the longer", [x["steps"] for x in r[2:]] == [3, 3, 3, 4, 5, 6])

    rng, pages = random.Random(20261011), []

    def nested(deep, count, path, out):
        kind, me = rng.choice(["list", "olist"]), count[1]
        count[1] += 1
        for _ in range(rng.randint(1, 5)):
            count[1] += 1
            inner = path + [(kind, me), ("item", count[1])]
            if deep and rng.random() < 0.45:
                nested(deep - 1, count, inner, out)
            else:
                for _ in range(rng.randint(1, 3)):
                    out.append(event(count[0], *inner))
                    count[0] += 1

    for _ in range(200):
        out, share = [], rng.choice([0, 0.1, 0.5, 1])
        nested(rng.randint(0, 4), [0, 0], [], out)
        pages.append((out, [e["n"] for e in out if rng.random() < share]))
    r = readings(pages)
    check("on two hundred nestings, the steps stay between the bounds the depth and the size set",
          all(x["events"] == len(es) and max(x["depth"], -(-len(es) // 4)) == x["lower"] <= x["clear"] <= x["upper"] <= len(es)
              for (es, _), x in zip(pages, r)))
    check("failures never shorten a reading, and failing everywhere makes it serial",
          all(x["clear"] <= x["steps"] <= len(es) and (bad or x["steps"] == x["clear"]) and (len(bad) < len(es) or x["steps"] == len(es))
              for (es, bad), x in zip(pages, r)))

    (tmp / "damaged").write_bytes(b"\n\nnot a record\n")
    code, _, said = releve("facts", tmp / "damaged")
    check("a damaged corpus is refused, with its line", code == 1 and "line 3" in said)

    # Reports name the criteria version that judged them, so the criteria cannot change under an
    # unchanged version: raise `version` in Criteria.hs, then --accept records the new digest.
    said = releve("--version")[1].decode("utf-8")
    source = b"".join((HERE.parent / "kernel" / "src" / "Releve" / f).read_bytes().replace(b"\r\n", b"\n") for f in ("Criteria.hs", "Colour.hs"))
    now = said.split("criteria v")[1].strip() + " " + hashlib.sha256(source).hexdigest()
    record = HERE / "expected" / "criteria.txt"
    if accept and (not record.exists() or record.read_text(encoding="utf-8").split()[0] != now.split()[0]):
        record.write_text(now + "\n", encoding="utf-8")
    check("the criteria are those of their version", record.exists() and record.read_text(encoding="utf-8").strip() == now)

    cabal = re.search(r"^version:\s*(\S+)", (HERE.parent / "releve.cabal").read_text(encoding="utf-8"), re.M).group(1)
    check("the program and the package state the same release", said.startswith(f"releve {cabal} "))

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
