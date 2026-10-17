#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The service, checked against local sites: an address in, a report out, and
nothing left behind. Needs Python, Playwright, Chromium and `releve`; no network."""
import base64, gzip, hashlib, json, os, re, subprocess, sys, tempfile, threading, uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.request import Request, urlopen

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "serve"))
import serve  # noqa: E402
from authority import authority  # noqa: E402

PAGE = "<!doctype html><html lang=en><title>{0}</title><main><h1>{0}</h1><p>Words of the page.</p><img src=/x.png></main></html>"
hits, checks, shelf = [], [], {}  # requests seen; results; pages put up to be read


def site(robots):
    class Site(BaseHTTPRequestHandler):
        def do_GET(self):
            hits.append((self.server.server_port, self.path))
            body = robots if self.path == "/robots.txt" else shelf.get(self.path) or PAGE.format(self.path.strip("/") or "Home")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain" if self.path == "/robots.txt" else "text/html")
            self.end_headers()
            self.wfile.write(body.encode())

        def log_message(self, *_):
            pass

    s = ThreadingHTTPServer(("127.0.0.1", 0), Site)
    threading.Thread(target=s.serve_forever, daemon=True).start()
    return s.server_port


def check(name, ok):
    checks.append(ok)
    print(("ok    " if ok else "FAIL  ") + name)


def ask(door, url=None, lang="en", record=None, path="/", accept=None):
    """The door's answer: status, headers, text."""
    if url is None:
        r = urlopen(f"http://127.0.0.1:{door}{path}")
    else:
        mark, parts = uuid.uuid4().hex, [("url", None, url.encode()), ("lang", None, lang.encode())]
        if record is not None:
            parts.append(("record", "record.jsonl.gz", record))
        body = b"".join(b"--" + mark.encode() + b'\r\nContent-Disposition: form-data; name="' + n.encode() + b'"'
                        + (b'; filename="' + f.encode() + b'"' if f else b"") + b"\r\n\r\n" + v + b"\r\n" for n, f, v in parts)
        r = urlopen(Request(f"http://127.0.0.1:{door}/", data=body + b"--" + mark.encode() + b"--\r\n",
                            headers={"Content-Type": "multipart/form-data; boundary=" + mark, **({"Accept-Language": accept} if accept else {})}))
    return r.status, {k.lower(): v for k, v in r.headers.items()}, r.read().decode("utf-8")


def asked(*urls):
    """What the rules ask of these pages: how many were read, and every line that is not a pass."""
    seen = subprocess.run([sys.executable, str(Path(serve.__file__).parent.parent / "observe" / "observe.py"), *urls,
                           "--contact", "https://example.org/robot"], capture_output=True).stdout
    corpus = Path(tempfile.mkdtemp()) / "c"
    subprocess.run([serve.RELEVE, "ingest", str(corpus)], input=seen, capture_output=True)
    facts = subprocess.run([serve.RELEVE, "facts", str(corpus), "--all"], capture_output=True).stdout.decode("utf-8")
    # What only a person can answer is put to the page's owner on every page: the reviewer's questions, and
    # the language each page and passage is in. Everything else a rule finds is a finding.
    return len(seen.splitlines()), [l for l in re.findall(r"^- \*\*(?:FAIL|REVIEW|HINT)\*\*.*$", facts, re.M)
                                    if not re.match(r"- \*\*REVIEW\*\* (review-[\w-]+|lang-code) · (page|\d+ pages( \([^)]*\))?) · ", l)]


def kept(text):
    return base64.b64decode(re.search(r'href="data:application/gzip;base64,([^"]+)"', text).group(1))


open_, closed = site("User-agent: *\nDisallow: /private/\n"), site("User-agent: *\nDisallow: /\n")
serve.PAUSE = 1
here = sorted(os.listdir("."))
counts = Path(tempfile.mkdtemp()) / "counts.json"
counts.write_text(json.dumps({"2026-W01": {"reports": 12, "following": 3, "languages": {"en": 7, "fr": 5}, "regions": {"Europe": 9, "Asia": 2, "unknown": 1}}}))
serve.setup("https://example.org/robot", local=True, counts=counts)
door = ThreadingHTTPServer(("127.0.0.1", 0), serve.Door)
threading.Thread(target=door.serve_forever, daemon=True).start()
door = door.server_port

for path, lang in (("/", "en"), ("/fr/", "fr")):
    code, heads, text = ask(door, path=path)
    check(f"asks for an address, in {lang}", code == 200 and f'<html lang="{lang}">' in text and 'name="url"' in text)
    check(f"sets no cookie, runs no script, and asks not to be stored ({lang})",
          "set-cookie" not in heads and "<script" not in text and heads["cache-control"] == "no-store"
          and "default-src 'none'" in heads["content-security-policy"])

head = urlopen(Request(f"http://127.0.0.1:{door}/", method="HEAD"))
check("answers a request for the headers alone with the headers alone", head.status == 200 and int(head.headers["Content-Length"]) > 0 and head.read() == b"")

code, heads, first = ask(door, f"http://localhost:{open_}/one", "fr")
check("answers an address with its report, in the language asked for",
      code == 200 and '<html lang="fr">' in first and "Méthode" in first and "pas d'attribut alt" in first and "set-cookie" not in heads)
record = kept(first)
check("offers the record, sealed, to be kept by whoever asked", gzip.decompress(record).startswith(b'{"hash"'))

code, heads, text = ask(door, f"http://localhost:{open_}/one", "en")
check("leaves a site alone that it has just visited", "observed a moment ago" in text)

threading.Event().wait(serve.PAUSE + 0.2)
code, heads, text = ask(door, f"http://localhost:{open_}/one", "en", record, accept="en-GB,en;q=0.9")
check("reads a record handed back, and says what stands", "Since " in text and re.search(r"\b\d+ unchanged\.", text) is not None)
check("hands the record back longer by one observation", len(gzip.decompress(kept(text)).splitlines()) == 2)

forged = gzip.compress(gzip.decompress(record).replace(b"Words of the page", b"Words of another"))
for name, bad in (("forged", forged), ("damaged", b"not a record")):
    code, heads, text = ask(door, f"http://127.0.0.1:{open_}/two", "en", bad)
    check(f"believes no {name} record", "its seals do not hold" in text and "Method" not in text)
    threading.Event().wait(serve.PAUSE + 0.2)

code, heads, text = ask(door, f"http://127.0.0.1:{closed}/page", "en")
check("obeys robots.txt, and says how to be let in", "asks robots to stay out" in text and "User-agent: releve-observe" in text
      and not [h for h in hits if h == (closed, "/page")])

code, heads, text = ask(door, "localhost/one", "fr")
check("takes web addresses only", "Ce n’est pas une adresse web" in text)

for address, verdict in [("http://127.0.0.1/", "not public"), ("http://10.1.2.3/x", "not public"), ("http://169.254.169.254/latest/", "not public"),
                         ("http://[::1]/", "not public"), ("https://93.184.216.34:8443/", "not public"), ("https://93.184.216.34/", None),
                         ("http://no-such-host.invalid/", "not public"), ("data:text/html,x", None)]:
    check(f"in the open, {address} is {'requested' if verdict is None else 'never requested'}", serve.shut(address, False) == verdict)

# What is counted: each report given, by week, language, whether it followed a record, and the broad region a
# browser's language setting names. Nothing of the request itself; a week is shown once it has ended.
now = json.loads(counts.read_text())[serve.Tally.week()]
stored = counts.read_text()
check("counts each report given by week, language, record and region, and nothing else",
      now == {"reports": 2, "following": 1, "languages": {"fr": 1, "en": 1}, "regions": {"unknown": 1, "Europe": 1}}
      and not any(x in stored for x in ("127.0.0.1", "localhost", "/one", "example", "http")))
check("reads a region from the language setting alone",
      [serve.region(a) for a in ("fr-FR,fr;q=0.9", "fr,fr-CA;q=0.8", "en", "zh-Hant-TW", "es-419", None)]
      == ["Europe", "North America", "unknown", "Asia", "unknown", "unknown"])
printed = subprocess.run([sys.executable, str(Path(serve.__file__).parent / "counts.py"), str(counts)], capture_output=True, text=True).stdout
check("reads its counts where they are kept: the weeks that have ended, a small region as fewer than 5",
      "| 2026-W01 | 12 | 3 | 7 | 5 | 9 | fewer than 5 | fewer than 5 |" in printed and serve.Tally.week() not in printed)
try:
    urlopen(f"http://127.0.0.1:{door}/counts")
    hidden = False
except Exception as e:
    hidden = getattr(e, "code", None) == 404
check("shows its counts on no page", hidden)

# What only a person can decide is put to them, and their answers come back with the record they belong to.
shelf["/pictured"] = ("<!doctype html><html lang=en><title>Pictured</title><main><h1>Pictured</h1><p>Before the picture.</p>"
                      "<img src=/x.png alt='A harbour at dawn' width=40 height=40><p>After it.</p></main></html>")
threading.Event().wait(serve.PAUSE + 0.2)
code, heads, questions = ask(door, f"http://localhost:{open_}/pictured", "en")
asking = sorted(set(re.findall(r'<fieldset><legend>Does the alternative describe the image\?</legend><input type="radio" id="a-[\w-]+-pass" name="(a-[\w-]+)"', questions)))
held = re.search(r'<form method="post" action="/answer" enctype="multipart/form-data">\s*<input type="hidden" name="lang" value="en">\s*'
                 r'<input type="hidden" name="kept" value="([^"]+)">', questions)
check("puts what only a person can decide as a question, in a form that carries the record back",
      len(asking) == 1 and held is not None and base64.b64decode(held.group(1)) == kept(questions)
      and "Does the alternative describe the image?" in questions and '<button type="submit">' in questions)


def send(fields):
    mark = uuid.uuid4().hex
    body = b"".join(b"--" + mark.encode() + b'\r\nContent-Disposition: form-data; name="' + n.encode() + b'"\r\n\r\n' + v.encode() + b"\r\n"
                    for n, v in fields.items())
    r = urlopen(Request(f"http://127.0.0.1:{door}/answer", data=body + b"--" + mark.encode() + b"--\r\n",
                        headers={"Content-Type": "multipart/form-data; boundary=" + mark}))
    return r.read().decode("utf-8")


before, tallied = len(hits), counts.read_text()
answered = send({"lang": "en", "kept": held.group(1), asking[0]: "pass", "n-" + asking[0][2:]: "the harbour, as the caption says\nsecond line {x}"})
check("records a person's answer in the record, beside the rule's, and visits no page for it",
      "1 answer recorded." in answered and "Confirmed by the reviewer (1)" in answered and "the harbour, as the caption says second line {x}" in answered
      and f'name="{asking[0]}"' not in answered and len(hits) == before and counts.read_text() == tallied)
grown = gzip.decompress(kept(answered))
check("hands back the record longer by the answer, sealed as before", len(grown.splitlines()) == 2 and b'"corrected"' in grown
      and grown.startswith(gzip.decompress(kept(questions))))
corpus = Path(tempfile.mkdtemp()) / "c"
corpus.write_bytes(gzip.decompress(record))
said = subprocess.run([serve.RELEVE, "facts", str(corpus)], capture_output=True).stdout.decode("utf-8")
shown = re.search(r"^- \*\*FAIL\*\* image-alt .* \{(\w+)\}$", said, re.M).group(1)
first_oid = re.search(r"^Observation `(\w+)`", said, re.M).group(1)
refused = send({"lang": "en", "kept": base64.b64encode(record).decode(), f"a-{first_oid}-{shown}": "pass"})
check("does not let an answer argue away a failure the rule can show", "No answers submitted." in refused
      and len(gzip.decompress(kept(refused)).splitlines()) == len(gzip.decompress(record).splitlines()))
forgery = send({"lang": "en", "kept": base64.b64encode(forged).decode(), asking[0]: "pass"})
check("takes answers only with a record whose seals hold", "its seals do not hold" in forgery)

declared = send({"lang": "en", "kept": base64.b64encode(kept(answered)).decode(), "d-rgesn-1-3": "yes", "dn-rgesn-1-3": "Anna", "d-rgesn-9-1": "n/a", "dn-rgesn-9-1": "",
                 "d-bitv-2-0-4": "n/a", "dn-bitv-2-0-4": "not a German public body"})
check("records the owner's declarations with the record, and only what changed",
      "3 answers recorded." in declared and "1 yes · 0 no · 2 not applicable · 78 open" in declared and "not a German public body" in declared
      and 'id="d-rgesn-1-3-yes" name="d-rgesn-1-3" value="yes" checked' in declared and len(hits) == before
      and "0 answers" not in send({"lang": "en", "kept": base64.b64encode(kept(declared)).decode(), "d-rgesn-1-3": "yes", "dn-rgesn-1-3": "Anna"})
      and "No answers submitted." in send({"lang": "en", "kept": base64.b64encode(kept(declared)).decode(), "d-rgesn-1-3": "yes", "dn-rgesn-1-3": "Anna"}))

# A question asked of the page as a whole comes once for the pages built on the same template; one answer covers them.
shelf["/pictured-too"] = shelf["/pictured"].replace("Pictured", "Pictured too")
threading.Event().wait(serve.PAUSE + 0.2)
code, heads, two = ask(door, f"http://localhost:{open_}/pictured-too", "en", record=kept(questions))
pooled = sorted(set(re.findall(r'name="(a-site-\w+-\w+)" value="pass"', two)))
check("asks what the pages' template decides once for the pages that share it, not on each page",
      code == 200 and "The whole site" in two and len(pooled) > 3 and "On each of these pages: Is no information given by color alone?" in two
      and two.count("Is no information given by color alone?") == 1)
held_two = re.search(r'<input type="hidden" name="kept" value="([^"]+)">', two).group(1)
covered = send({"lang": "en", "kept": held_two, pooled[0]: "pass", "n-" + pooled[0][2:]: "checked on both"})
grown = gzip.decompress(kept(covered)).splitlines()
check("records one answer for every page that shares the template, and asks it no more",
      "1 answer recorded." in covered and "Answered for these pages (1)" in covered and "checked on both" in covered
      and f'name="{pooled[0]}"' not in covered and b'"covers":[' in grown[-1] and grown[-1].count(b'","') >= 1)

# The service is held to what it asks of others: its own pages, read by its own rules, are asked for nothing.
shelf["/answer"] = first
shelf["/questions"] = questions
read, lines = asked(f"http://127.0.0.1:{door}/", f"http://127.0.0.1:{door}/fr/", f"http://localhost:{open_}/answer", f"http://localhost:{open_}/questions")
check("its own pages, read by its own rules, are found wanting in nothing a rule decides" + "".join("\n      " + l for l in lines), read == 4 and not lines)

# Installed by its own recipe, it keeps none of its output and stands behind a proxy that logs no request.
recipe = (Path(serve.__file__).parent / "install.sh").read_text(encoding="utf-8")
check("its recipe keeps no output and no log of requests, and tells the service nothing of who asked",
      all(x in recipe for x in ("StandardOutput=null", "StandardError=null", "exclude http.log.error", "header_up -X-Forwarded-For"))
      and "output file" not in recipe)

# Dated by an outside authority: the report gives the time, the authority and the sky its reply draws; the
# record holds the reply, its seals and the stamp check, and the sky's code is the reply's own digest. Only
# the cloud dots move: the building stays to the point.
work = Path(tempfile.mkdtemp())
os.environ["RELEVE_CA"] = str(authority(work / "tsa", 8767))
dots = "".join(f"m{3 if k else 200}.0 {k % 3}.0h1v1h-1z" for k in range(30))
(work / "sky.svg").write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="400" height="100"><path d="M10 10h80v80h-80z{dots}"/></svg>')
(work / "sky.json").write_text(json.dumps({"svg": "sky.svg", "dot": 2, "frontier": [[1000, 150]], "kept": [], "amp": 6, "jitter": 1,
                                           "verify": {"en": "https://example.org/verify/", "fr": "https://example.org/fr/verifier/"}}))
serve.AUTHORITY, serve.SKY = "http://127.0.0.1:8767/", {**json.loads((work / "sky.json").read_text()), "drawing": (work / "sky.svg").read_text()}
status, headers, text = ask(door, f"http://127.0.0.1:{open_}/dated")
record = kept(text) if status == 200 else b""
last = [json.loads(l) for l in gzip.decompress(record).decode("utf-8").splitlines() if '"stamped"' in l] if record else []
code = hashlib.sha256(base64.b64decode(last[-1]["event"]["stamped"]["reply"])).hexdigest()[:8] if last else None
(work / "c").write_bytes(gzip.decompress(record) if record else b"")
drawn = re.search(r'<figure><svg[^>]*><path d="([^"]+)"', text)
check("dates the record by the authority named, and sets its sky above the date",
      bool(last) and "an outside time-stamping authority (RFC 3161)" in text and f"sky {code}." in text and drawn is not None
      and drawn.group(1).startswith("M10 10h80v80h-80z") and drawn.group(1) != (work / "sky.svg").read_text().split('d="')[1].split('"')[0]
      and 'href="https://example.org/verify/"' in text and "signature verified" in subprocess.run([serve.RELEVE, "verify", work / "c"], capture_output=True, text=True).stdout)
serve.AUTHORITY = serve.SKY = None

# With the report, the drafts drawn from the same record: a file to keep, the record dated within it.
draft = re.search(r'<a download="statements-[^"]+\.html" href="data:text/html;base64,([^"]+)">Download the drafts</a>', text)
drafts = base64.b64decode(draft.group(1)).decode("utf-8") if draft else ""
check("hands over the draft statements of the record, dated as the record is",
      "<h2>Accessibility statement</h2>" in drafts and "<h2>Eco-design declaration</h2>" in drafts and "The record is dated " in drafts)

# A service whose browser cannot start is of no use, and does not pretend: it ends, to be started again.
try:
    ended = subprocess.run([sys.executable, serve.__file__, "--contact", "https://example.org/robot", "--port", "0"], timeout=60, capture_output=True,
                           env={**os.environ, "PLAYWRIGHT_BROWSERS_PATH": tempfile.mkdtemp(), "PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD": "1"}).returncode
except subprocess.TimeoutExpired:
    ended = None
check("ends when its browser cannot start", ended == 1)

# A record passes through a directory in memory that is gone with the answer; nothing is written beside the service.
passing = [n for d in {serve.MEMORY or serve.tempfile.gettempdir(), serve.tempfile.gettempdir()} for n in os.listdir(d) if n.startswith("releve-")]
check("leaves nothing behind", not passing and sorted(os.listdir(".")) == here)
sys.exit(0 if all(checks) else 1)
