#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The kernel's checks. No browser, no network: recorded observations in,
reports compared byte for byte with the expected ones.

    python tests/run.py            check
    python tests/run.py --accept   rewrite the expected reports after a deliberate change
    python tests/run.py --record [PAGE ...]
                                   re-record the test pages, or the ones named, after changing
                                   the observer (needs Playwright and Chromium), then review the diff

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


def record(names=()):
    class Quiet(SimpleHTTPRequestHandler):
        def log_message(self, *_):
            pass
    server = ThreadingHTTPServer(("127.0.0.1", 8765), partial(Quiet, directory=HERE / "pages"))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    for page in sorted(p for p in (HERE / "pages").glob("*.html") if not names or p.stem in names):
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

    # The report: the same document from a corpus and from observations passed through, in each
    # language; and nothing in the French one left in English but what the page itself said.
    structure = (HERE / "observations" / "structure.jsonl").read_bytes()
    for lang in ("en", "fr"):
        doc, expected = releve("report", lang, tmp / "structure")[1], HERE / "expected" / f"structure.{lang}.html"
        if accept:
            expected.write_bytes(doc)
        check(f"report in {lang}", doc == expected.read_bytes() and f'<html lang="{lang}">'.encode() in doc)
        check(f"the same report in {lang} with nothing kept", releve("report", lang, "-", feed=structure)[1] == doc)
    check("the guide names every criterion, in each language",
          all(all(f'<h2 id="{l.split()[0]}">'.encode() in releve("guide", lang)[1] for l in releve("criteria")[1].decode("utf-8").splitlines()[1:])
              for lang in ("en", "fr")))
    everything = b"".join(o.read_bytes() for o in sorted((HERE / "observations").glob("*.jsonl")))
    french = releve("report", "fr", "-", feed=everything)[1].decode("utf-8") + releve("guide", "fr")[1].decode("utf-8")
    ours = re.sub(r"«.*?»|<code>.*?</code>|<a .*?</a>|<title>.*?</title>|<h[12][^>]*>.*?</h[12]>|<style>.*?</style>", "", french, flags=re.S)
    left = sorted(set(re.findall(r"\b(?:the|with|without|and|is|are|of|not|no|by|has)\b", re.sub(r"<[^>]+>", " ", ours))))
    check("the French report is in French" + (": " + ", ".join(left) if left else ""), not left)

    # What a report says, it says of the page, and it claims nothing for it: no audit, no conformity, no
    # certificate, no quality mark, no guarantee. The one thing it says of audits is that it is not one. Words
    # quoted from the page are the page's; what HTML itself writes (<label>, aria-label) is set as code.
    english = releve("report", "en", "-", feed=everything)[1].decode("utf-8") + releve("guide", "en")[1].decode("utf-8")
    claims = []
    for text in (english, french):
        said = re.sub(r"«.*?»|“.*?”|<code>.*?</code>|<a .*?</a>|<title>.*?</title>|<h[12][^>]*>.*?</h[12]>|<style>.*?</style>", " ", text, flags=re.S)
        said = re.sub(r"<[^>]+>", " ", said).replace("\u202f", " ").replace("\xa0", " ").lower()
        said = re.sub(r"is not a conformity audit|n'est pas un audit de conformité", " ", said)
        claims += re.findall(r"\baudit\w*|\bconformes?\b|\bcompliant\b|\w*certif\w*|\blabel\w*|\bgaranti\w*|\bguarant\w*|100\s*%|\bobligatoire\w*|\bmandatory\b", said)
    check("a report claims nothing for the page" + (": " + ", ".join(sorted(set(claims))) if claims else ""), not claims)

    # The reading. A series takes a step for each event, whatever the reader holds; independent
    # events take a quarter of that; a series beside them costs nothing until it is the longer.
    blank = json.loads((HERE / "observations" / "edge.jsonl").read_text(encoding="utf-8"))
    blank["page"].update(lang="en", viewport=None, reflow=320, dupIds=[])

    def event(n, *path):
        return {"n": n, "sel": f"e{n}", "kind": "text", "shown": True, "said": f"word{n}", "words": 1, "bits": 30, "path": [list(p) for p in path],
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

    # How a page travels, judged from the responses that brought it. The test pages are read from
    # this machine and are not judged on it; these two records stand for a page served in the open.
    def carried(**r):
        return dict({"kind": "Image", "mime": "image/avif", "bytes": 9000, "proto": "h2", "encoded": "", "cached": True, "third": False}, **r)

    heavy = [carried(url="https://example.org/", kind="Document", mime="text/html", bytes=30000),
             carried(url="https://example.org/site.css", kind="Stylesheet", mime="text/css", bytes=12000, proto="http/1.1", encoded="br", cached=False),
             carried(url="https://static.example.org/logo.avif"),
             carried(url="https://cdn.other.net/lib.js", kind="Script", mime="text/javascript", bytes=90000, third=True)] \
        + [carried(url=f"https://example.org/f{i}.woff2", kind="Font", mime="font/woff2", bytes=100000) for i in range(5)]
    light = [carried(url="https://example.org/", kind="Document", mime="text/html", bytes=30000, encoded="br"),
             carried(url="https://example.org/site.css", kind="Stylesheet", mime="text/css", bytes=12000, encoded="gzip"),
             carried(url="https://example.org/f.woff2", kind="Font", mime="font/woff2", bytes=100000)]
    corpus = tmp / "carried"
    for name, rs, more in (("heavy", heavy, {"tls": "TLS 1.2", "ipv6": False}), ("light", light, {"tls": "TLS 1.3", "ipv6": True})):
        o = json.loads(json.dumps(blank))
        o.update(url=f"https://example.org/{name}", events=[], surfaces=[])
        o["page"].update(more)
        o["network"].update(resources=rs, thirdParties=sorted({r["url"].split("/")[2] for r in rs if r["third"]}))
        releve("ingest", corpus, feed=json.dumps(o).encode("utf-8"))
    said = releve("facts", corpus, "https://example.org/heavy")[1].decode("utf-8").replace("\\/", "/")
    check("a page that travels heavily is told how, line by line", all(line in said for line in (
        "**HINT** fonts · page · 5 font files, 488 kB", "**HINT** compression · page · example.org/ · 29 kB, not compressed",
        "**HINT** caching · page · example.org/site.css may not be kept by the browser", "**HINT** protocol · page · negotiated TLS 1.2",
        "1 of its 8 own responses came over HTTP/1", "its name has no IPv6 address", "its own static files come from 2 domains: example.org, static.example.org",
        "**REVIEW** third-parties · page · 1 third-party host answered before any consent was given: cdn.other.net")))
    said = releve("facts", corpus, "https://example.org/light")[1].decode("utf-8")
    check("a page that travels lightly passes each of them", all(f"- {c}: 1 of 1 pass" in said for c in ("fonts", "compression", "caching", "protocol", "third-parties"))
          and "**HINT**" not in said)

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
    check("the order of mending ends at the page with nothing failing, each line leaving no more steps than the one before",
          all((x["mending"] == []) == (x["steps"] == x["clear"])
              and all(a["steps"] >= b["steps"] for a, b in zip(x["mending"], x["mending"][1:]))
              and (not x["mending"] or (x["mending"][0]["steps"] <= x["steps"] and x["mending"][-1]["steps"] == x["clear"]))
              for x in r))
    check("failures never shorten a reading, and failing everywhere makes it serial",
          all(x["clear"] <= x["steps"] <= len(es) and (bad or x["steps"] == x["clear"]) and (len(bad) < len(es) or x["steps"] == len(es))
              for (es, bad), x in zip(pages, r)))

    # The points to decide, put to a person. Asking, each point the rule left to a person comes with
    # yes, no and a note; a failure the rule can show is not put as a question.
    k = tmp / "keyboard"
    said = releve("facts", k)[1].decode("utf-8")
    oid = re.search(r"^Observation `(\w+)`", said, re.M).group(1)
    left, shown = re.findall(r"^- \*\*REVIEW\*\* .* \{(\w+)\}$", said, re.M), re.findall(r"^- \*\*FAIL\*\* .* \{(\w+)\}$", said, re.M)
    asked = releve("report", "en", k, "--ask")[1].decode("utf-8")
    plain = releve("report", "en", k)[1].decode("utf-8")
    check("asking, each point to decide comes with yes, no and a note, and no failure does",
          left and shown and all(f'name="a-{oid}-{i}"' in asked and f'id="n-{oid}-{i}"' in asked for i in left)
          and not any(f"-{i}" in asked for i in shown) and asked.count('type="radio" id="a-') == 2 * len(left)
          and asked.count("Submit answers") == 1)
    check("not asking, the report puts the same questions in words, with nothing to fill in",
          "<input" not in plain and "<button" not in plain and plain.count("Question:") == len(left)
          and "Is the image decorative?" in plain and "Does the alternative describe the image?" in plain)
    check("an image put to a person is shown with its file and the words around it",
          '<a href="http://localhost:8765/plain.png">plain.png</a>' in plain and "Text before: “The words before the picture of the harbour.”" in plain
          and "Text after: “The words after it, about the boats.”" in plain)
    answered = edited(said, (rf"^- \*\*REVIEW\*\*(.*) \{{{left[0]}\}}$", rf"- **PASS**\1 // the harbour, as the caption says {{{left[0]}}}"))
    releve("correct", k, feed=answered)
    after = releve("report", "en", k, "--ask")[1].decode("utf-8")
    check("an answer stands as a person's, beside what the rule said, and is no longer asked",
          "Confirmed by the reviewer (1)" in after and "reviewer's answer; rule: open" in after
          and "1 answer by the reviewer" in after and f'name="a-{oid}-{left[0]}"' not in after and "the harbour, as the caption says" in after)

    # The longest chain of requests, each asked for by the one before, read from the links the browser reports.
    said = releve("facts", tmp / "chain")[1].decode("utf-8")
    check("the longest chain of requests is named, first request first",
          "- longest chain: 4 requests, each asked for by the one before · chain.html → chain-1.js → chain-2.js → generator.png" in said
          and json.loads(releve("atlas", tmp / "chain")[1])["footprint"]["chain"][-1].endswith("/generator.png"))

    # Every RGESN criterion is covered once: by a rule that touches it, or by the owner's declaration.
    rgesn = {f"{f}.{n}" for f, k in enumerate([10, 10, 7, 15, 8, 7, 4, 10, 7], 1) for n in range(1, k + 1)}
    ruled = set(re.findall(r"\b\d+\.\d+\b", " ".join(l.split("RGESN", 1)[1].split("AI Act")[0] for l in releve("criteria")[1].decode("utf-8").splitlines() if "RGESN" in l)))
    d = tmp / "declared"
    releve("ingest", d, feed=(HERE / "observations" / "forms.jsonl").read_bytes())
    doc = releve("declarations", d)[1].decode("utf-8")
    listed = re.findall(r"^- RGESN (\S+) · open · ", doc, re.M)
    check("every RGESN criterion is covered once, by a rule or by a declaration",
          len(rgesn) == 78 and ruled | set(listed) == rgesn and not ruled & set(listed) and len(listed) == len(set(listed)))
    # Every RGAA criterion is covered once: by a rule, by a question to the reviewer, or by the owner's declaration.
    rgaa = {f"{t}.{n}" for t, k in enumerate([9, 2, 3, 13, 8, 2, 5, 10, 4, 14, 13, 11, 12], 1) for n in range(1, k + 1)}

    def numbers(seg):
        out = set()
        for tok in re.findall(r"\d+\.\d+(?:–\d+\.\d+)?", seg):
            if "–" in tok:
                a, b = tok.split("–")
                out |= {f"{a.split('.')[0]}.{k}" for k in range(int(a.split(".")[1]), int(b.split(".")[1]) + 1)}
            else:
                out.add(tok)
        return out
    lines = [l for l in releve("criteria")[1].decode("utf-8").splitlines() if "RGAA" in l]
    asked_of = [numbers(l.split("RGAA", 1)[1]) for l in lines if l.startswith("review-")]
    ruled_by = [numbers(l.split("RGAA", 1)[1].split("WCAG")[0]) for l in lines if not l.startswith("review-")]
    declared_rgaa = set(re.findall(r"^- RGAA (\S+) · open · ", doc, re.M))
    every = [x for group in asked_of + ruled_by for x in group] + sorted(declared_rgaa)
    check("every RGAA criterion is covered once, by a rule, by a question or by a declaration",
          len(rgaa) == 106 and set(every) == rgaa and len(set(x for g in asked_of for x in g) | declared_rgaa) == sum(map(len, asked_of)) + len(declared_rgaa)
          and not (set(x for g in ruled_by for x in g) & (set(x for g in asked_of for x in g) | declared_rgaa)))
    check("a declaration shows what the observation saw", "- RGESN 1.6 · open · Is data collected only as needed? · seen: " in doc)
    answered = edited(doc, (r"^- RGESN 1\.3 · open · (.*)$", r"- RGESN 1.3 · yes · \1 // Anna Teterkina"),
                      (r"^- RGESN 9\.1 · open · (.*)$", r"- RGESN 9.1 · n/a · \1"))
    check("an owner's declarations are recorded, and an untouched document records nothing",
          releve("declare", d, feed=answered)[2] == "2 declarations recorded"
          and releve("declare", d, feed=releve("declarations", d)[1])[2] == "0 declarations recorded")
    before = d.read_bytes()
    code, _, said = releve("declare", d, feed=edited(answered.decode("utf-8"), (r"^- RGESN 1\.4 · open", "- RGESN 1.4 · maybe")))
    check("an answer that cannot be read is refused, with everything else", code == 1 and "yes, no, n/a or open" in said and d.read_bytes() == before)
    plain, asked = releve("report", "en", d)[1].decode("utf-8"), releve("report", "en", d, "--ask")[1].decode("utf-8")
    check("the report says what is declared, and asking, the answer in force is already chosen",
          "1 yes · 0 no · 1 not applicable · 78 open" in plain and "Anna Teterkina" in plain and "2 are declared so far" in plain
          and 'id="d-rgesn-1-3-yes" name="d-rgesn-1-3" value="yes" checked' in asked and asked.count("<fieldset>") >= 80)
    releve("declare", d, feed=edited(releve("declarations", d)[1].decode("utf-8"), (r"^- RGESN 1\.3 · yes", "- RGESN 1.3 · open")))
    check("a declaration withdrawn is open again", "0 yes · 0 no · 1 not applicable · 79 open" in releve("report", "en", d)[1].decode("utf-8")
          and releve("verify", d)[0] == 0)

    # Article 50 of the AI Act: each of its 7 paragraphs read by a rule, declared by the owner for what no page
    # shows, or said to bind no site; and the guide says so in the numbers it gives.
    art = {f"50({k})" for k in range(1, 8)}
    by_rule = set(re.findall(r"50\(\d\)", " ".join(l.split("art.", 1)[1] for l in releve("criteria")[1].decode("utf-8").splitlines() if "art." in l)))
    by_owner = set(re.findall(r"^- AI Act (50\(\d\)) · open · ", doc, re.M))
    guide = releve("guide", "en")[1].decode("utf-8")
    check("every paragraph of article 50 is read by a rule, declared, or said to bind no site",
          (by_rule | by_owner | {"50(6)", "50(7)"}) == art and "Paragraph 50(6)" in guide and "Paragraph 50(7)" in guide
          and "address 106 of the 106 criteria of the RGAA 4.1.2, 78 of the 78 of the RGESN 2024, and 7 of the 7 paragraphs of article 50" in guide)

    # The frameworks: each as its provisions. A WCAG-based text is the success criteria it names,
    # and what it asks beyond them; the RGAA reaches WCAG by its own correspondence.
    fw = {f["framework"]: f for f in map(json.loads, releve("frameworks")[1].decode("utf-8").splitlines())}
    sizes = {"WCAG 2.1 AA": 50, "EN 301 549 · EAA": 51, "BITV 2.0": 51, "Section 508": 38, "ADA Title II": 50, "AODA": 37,
             "JIS X 8341-3:2016": 38, "DDA 1992": 38, "RGAA 4.1.2": 106, "RGESN 2024": 78, "AI Act article 50": 7, "CCPA · CPRA": 3}
    check("each framework counts its provisions, and every one is addressed",
          all(fw[n]["of"] == k for n, k in sizes.items()) and all(f["addressed"] == f["of"] and not f["open"] and f["source"].startswith("https://") for f in fw.values())
          and "through the RGAA's own correspondence, 50 of the 50 success criteria of WCAG 2.1" in guide and guide.count('<th scope="row">') == len(fw))
    bitv = edited(releve("declarations", d)[1].decode("utf-8"), (r"^- BITV 2\.0 §4 · open · (.*)$", r"- BITV 2.0 §4 · n/a · \1 // not a German public body"))
    check("a provision of another law is declared like any other",
          releve("declare", d, feed=bitv)[2] == "1 declaration recorded"
          and 'id="d-bitv-2-0-4-na" name="d-bitv-2-0-4" value="n/a" checked' in releve("report", "en", d, "--ask")[1].decode("utf-8"))

    # Refusing cookies as easily as accepting them: a filled button against a plain link is put to a person;
    # accepting alone breaks the rule; alike, it holds; no prompt, nothing to judge.
    prompt = json.loads((HERE / "observations" / "consent.jsonl").read_text(encoding="utf-8"))

    def consent(c):
        o, k = json.loads(json.dumps(prompt)), tmp / f"consent-{random.random()}"
        if c is not None:
            o["page"]["consent"] = c
        releve("ingest", k, feed=json.dumps(o).encode("utf-8"))
        return next(l for l in releve("facts", k)[1].decode("utf-8").splitlines() if "consent-choice" in l)
    alone = consent({"prompt": True, "choices": [["accept", "button", "OK", 4000, "filled"], ["settings", "link", "Learn more", 900, "plain"]]})
    alike = consent({"prompt": True, "cmp": "didomi", "choices": [["accept", "button", "Accept", 4000, "filled"], ["reject", "button", "Refuse", 3900, "filled"]]})
    none = consent({"prompt": False})
    c = tmp / "consent"
    cp = releve("declarations", c)[1].decode("utf-8")
    check("a prompt for consent: refusing smaller than accepting is asked, accepting alone fails, alike holds",
          "Is refusing as easy and as visible as accepting" in releve("report", "en", c, "--ask")[1].decode("utf-8")
          and "Continue without accepting" in consent(None)
          and "no way to refuse beside it" in alone and alike == "- consent-choice: 1 of 1 pass" and "no prompt for consent on arrival" in none
          and "seen: links: Do Not Sell or Share My Personal Information" in cp and "seen: links: Leichte Sprache" in cp)

    # A question is put only where what it asks about can exist: shortcuts, gestures and motion
    # need a script; a legend needs a group; option groups need a list.
    plain_page, scripted_page, forms_page = ((HERE / "expected" / f"{n}.md").read_text(encoding="utf-8") for n in ("tables", "page", "forms"))
    check("a page without script is not asked about scripts, shortcuts, gestures or motion",
          "review-scripts: n/a · no script on the page" in plain_page
          and not re.search(r"RGAA (7\.\d|12\.10|13\.1[0-2]) ·", plain_page)
          and all(f"RGAA {i} · this page" in scripted_page for i in ("7.1", "12.10", "13.10", "13.12")))
    check("a form is asked about legends and option groups only when it has them",
          "RGAA 11.7 ·" in forms_page and "RGAA 11.8 ·" not in forms_page)
    check("a link that names its language in that language needs no question",
          "lang-code: 1 of 5 pass" in scripted_page)

    # Pages built on the same template are asked what it decides once, and one answer covers them all,
    # while each keeps that template; a page that changes it, or a page first seen later, is asked again.
    base = json.loads((HERE / "observations" / "chain.jsonl").read_text(encoding="utf-8"))

    def clone(path, bump=0):
        o = json.loads(json.dumps(base))
        o["url"] = "http://localhost:8765/" + path
        for r in o["network"]["resources"]:
            r["bytes"] += bump if r["kind"] == "Script" else 0
        return json.dumps(o, ensure_ascii=False).encode("utf-8")
    t = tmp / "template"
    for name in ("one", "two", "three"):
        releve("ingest", t, feed=clone(name))
    whole = releve("facts", t, "--all")[1].decode("utf-8")
    shared = re.findall(r"^- \*\*REVIEW\*\* review-[\w-]+ · 3 pages · RGAA [\d.]+ → .* \{\w+\}$", whole, re.M)
    check("a question about the page as a whole is asked once for the pages that share a template",
          "Template `" in whole and len(shared) >= 8 and whole.count("## Shared (") == 4
          and len(re.findall(r"RGAA 3\.1\b", whole)) == 1)
    code, _, said = releve("correct", t, feed=edited(whole, (r"^- \*\*REVIEW\*\* (review-colours · 3 pages · RGAA 3\.1 → .*?) \{", r"- **PASS** \1 // the template, read once {")))
    of = lambda page: releve("facts", t, "http://localhost:8765/" + page)[1].decode("utf-8")
    passed = r"^- \*\*PASS\*\* review-colours · page · RGAA 3\.1 · this page .* machine said REVIEW // the template, read once \{"
    check("one answer stands for every page counted with it",
          code == 0 and said == "1 correction recorded" and all(re.search(passed, of(p), re.M) for p in ("one", "two", "three")))
    releve("ingest", t, feed=clone("two", bump=1))
    releve("ingest", t, feed=clone("four"))
    whole = releve("facts", t, "--all")[1].decode("utf-8")
    check("a page that changes its template is asked again, and so is a page first seen later; the others keep the answer",
          re.search(r"^- \*\*REVIEW\*\* review-colours · page · RGAA 3\.1 · .* read otherwise before this changed", of("two"), re.M) is not None
          and re.search(passed, of("one"), re.M) is not None and re.search(passed, of("four"), re.M) is None
          and re.search(r"^- \*\*REVIEW\*\* review-colours · 3 pages · RGAA 3\.1 → .* answered otherwise on some pages \{", whole, re.M) is not None)

    # The keyboard walk names an element as the record does: the same lines, in both files.
    def naming(f):
        return re.search(r"  const ids = new Map\(\);.*?\n  }\n", (HERE.parent / "observe" / f).read_text(encoding="utf-8"), re.S).group(0)
    check("the keyboard walk and the spacing pass name an element as the record does",
          naming("keys.js") == naming("extract.js") == naming("spacing.js"))

    (tmp / "damaged").write_bytes(b"\n\nnot a record\n")
    code, _, said = releve("facts", tmp / "damaged")
    check("a damaged corpus is refused, with its line", code == 1 and "line 3" in said)

    # Reports name the criteria version that judged them, so the criteria cannot change under an
    # unchanged version: raise `version` in Criteria.hs, then --accept records the new digest.
    said = releve("--version")[1].decode("utf-8")
    source = b"".join((HERE.parent / "kernel" / "src" / "Releve" / f).read_bytes().replace(b"\r\n", b"\n") for f in ("Criteria.hs", "Checklist.hs", "Colour.hs"))
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
    record(sys.argv[sys.argv.index("--record") + 1:]) if "--record" in sys.argv else main()
