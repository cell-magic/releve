#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The service, checked against local sites: an address in, a report out, and
nothing left behind. Needs Python, Playwright, Chromium and `releve`; no network."""
import base64, gzip, os, re, subprocess, sys, tempfile, threading, uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.request import Request, urlopen

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "serve"))
import serve  # noqa: E402

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


def ask(door, url=None, lang="en", record=None, path="/"):
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
                            headers={"Content-Type": "multipart/form-data; boundary=" + mark}))
    return r.status, {k.lower(): v for k, v in r.headers.items()}, r.read().decode("utf-8")


def asked(*urls):
    """What the rules ask of these pages: how many were read, and every line that is not a pass."""
    seen = subprocess.run([sys.executable, str(Path(serve.__file__).parent.parent / "observe" / "observe.py"), *urls,
                           "--contact", "https://example.org/robot"], capture_output=True).stdout
    corpus = Path(tempfile.mkdtemp()) / "c"
    subprocess.run([serve.RELEVE, "ingest", str(corpus)], input=seen, capture_output=True)
    facts = subprocess.run([serve.RELEVE, "facts", str(corpus), "--all"], capture_output=True).stdout.decode("utf-8")
    return len(seen.splitlines()), re.findall(r"^- \*\*(?:FAIL|REVIEW|HINT)\*\*.*$", facts, re.M)


def kept(text):
    return base64.b64decode(re.search(r'href="data:application/gzip;base64,([^"]+)"', text).group(1))


open_, closed = site("User-agent: *\nDisallow: /private/\n"), site("User-agent: *\nDisallow: /\n")
serve.PAUSE = 1
here = sorted(os.listdir("."))
serve.setup("https://example.org/robot", local=True)
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
code, heads, text = ask(door, f"http://localhost:{open_}/one", "en", record)
check("reads a record handed back, and says what stands", "Since the observation of" in text and "1 standing" in text)
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
check("takes web addresses only", "Ce n'est pas une adresse web" in text)

for address, verdict in [("http://127.0.0.1/", "not public"), ("http://10.1.2.3/x", "not public"), ("http://169.254.169.254/latest/", "not public"),
                         ("http://[::1]/", "not public"), ("https://93.184.216.34:8443/", "not public"), ("https://93.184.216.34/", None),
                         ("http://no-such-host.invalid/", "not public"), ("data:text/html,x", None)]:
    check(f"in the open, {address} is {'requested' if verdict is None else 'never requested'}", serve.shut(address, False) == verdict)

# The service is held to what it asks of others: its own pages, read by its own rules, are asked for nothing.
shelf["/answer"] = first
read, lines = asked(f"http://127.0.0.1:{door}/", f"http://127.0.0.1:{door}/fr/", f"http://localhost:{open_}/answer")
check("its own pages, read by its own rules, are asked for nothing" + "".join("\n      " + l for l in lines), read == 3 and not lines)

# Installed by its own recipe, it keeps none of its output and stands behind a proxy that logs no request.
recipe = (Path(serve.__file__).parent / "install.sh").read_text(encoding="utf-8")
check("its recipe keeps no output and no log of requests", all(x in recipe for x in ("StandardOutput=null", "StandardError=null", "exclude http.log.error"))
      and "output file" not in recipe)

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
