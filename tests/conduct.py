#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The observer's conduct, checked against local sites that say no in every
way a robot must hear; and its measure, against a page whose weight is known.
Needs Python, Playwright and Chromium; no network."""
import base64, json, subprocess, sys, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from time import monotonic, sleep

OBSERVE = Path(__file__).resolve().parent.parent / "observe" / "observe.py"
CONTACT = "https://example.org/robot"
PAGE = "<!doctype html><html lang=en><title>{}</title><main><h1>{}</h1></main></html>"
ANSWERS = {"/locked": 401, "/busy": 429, "/gone": 404}
REDIRECTS = {}  # path -> address, filled once the sites are up
PIXEL = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")
# Five requests for a reader at 1280 px who scrolls to the end: the page, the wide image, the
# redirect and where it lands, the lazy image. The inline image is no request; the narrow image
# is fetched only by the observer's own 320 px pass.
WEIGHED = """<!doctype html><html lang=en><title>Weighed</title><meta name=viewport content="width=device-width">
<main><h1>Weighed</h1><picture><source media="(max-width: 400px)" srcset="/img/narrow.png"><img src="/img/wide.png" alt=""></picture>
<img alt="" src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7">
<div style="height:6000px"></div><img loading=lazy src="/img/lazy.png" alt="" width=40 height=40><img src="/hop.png" alt=""></main></html>"""
# A page that says a great deal: every text the observer keeps of it is an extract.
LONG = "word " * 120
WORDY = f"""<!doctype html><html lang=en><title>{LONG}</title><main><h1>{LONG}</h1><p>{LONG}</p>
<a href="/one" aria-label="{LONG}">{LONG}</a><img src="/img/wide.png" alt="{LONG}"><button>{LONG}</button>
<label>{LONG}<input placeholder="{LONG}" name="{LONG}"></label><fieldset><legend>{LONG}</legend></fieldset>
<table><caption>{LONG}</caption><tr><th>{LONG}</th></tr></table></main></html>"""
# A page that never settles: once loaded, it asks for a font that never arrives.
UNSETTLED = """<!doctype html><html lang=en><title>Unsettled</title><style>@font-face{font-family:Late;src:url(/font.woff2)}</style>
<main><h1>Unsettled</h1><p><a href="/one">One</a> <a href="/two">Two</a></p></main>
<script>addEventListener("load", () => setTimeout(() => { const s = document.createElement("span"); s.style.fontFamily = "Late"; s.textContent = "late"; document.body.append(s) }, 50))</script>"""
log, posts = [], []  # requests as (port, method, path, user agent, time); anything submitted


def site(robots):
    class Site(BaseHTTPRequestHandler):
        def do_GET(self):
            log.append((self.server.server_port, "GET", self.path, self.headers.get("User-Agent", ""), monotonic()))
            if self.path in REDIRECTS:
                self.send_response(302)
                self.send_header("Location", REDIRECTS[self.path])
                self.end_headers()
                return
            if self.path == "/font.woff2":  # a font that never arrives
                self.send_response(200)
                self.send_header("Content-Type", "font/woff2")
                self.send_header("Content-Length", "100000")
                self.end_headers()
                self.wfile.write(b"wOF2")
                self.wfile.flush()
                sleep(120)
                return
            if self.path.startswith("/img/"):
                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.end_headers()
                self.wfile.write(PIXEL)
                return
            if self.path == "/robots.txt":
                body, code = robots, 200
            elif self.path == "/weighed":
                body, code = WEIGHED, 200
            elif self.path == "/wordy":
                body, code = WORDY, 200
            elif self.path == "/unsettled":
                body, code = UNSETTLED, 200
            elif self.path in ANSWERS:
                body, code = "no", ANSWERS[self.path]
            elif self.path == "/gate":
                body, code = PAGE.format("Just a moment...", "Checking"), 200
            elif self.path == "/script":
                body, code = f"<script>location = '{REDIRECTS['/away']}'</script>", 200
            elif self.path == "/refresh":
                body, code = f"<meta http-equiv=refresh content='0;url={REDIRECTS['/away']}'>", 200
            elif self.path == "/calm":
                body, code = PAGE.format("Un instant de calme", "Calme"), 200
            elif self.path == "/late":
                body, code = f"<title>Late</title><script>setTimeout(() => location = '{REDIRECTS['/away']}', 1200)</script>", 200
            elif self.path == "/renamed":
                body, code = "<title>Renamed</title><script>history.pushState({}, '', '/private/renamed')</script>", 200
            elif self.path == "/popup":
                body, code = "<title>Popup</title><script>window.open('/private/popup')</script>", 200
            elif self.path == "/autopost":
                body, code = "<title>Post</title><form method=post action=/posted></form><script>document.forms[0].submit()</script>", 200
            elif self.path == "/form":
                body, code = PAGE.format("Contact", "<iframe title=check src='/cdn-cgi/challenge-platform/widget'></iframe>"), 200
            else:
                body, code = PAGE.format("Page", self.path), 200
            self.send_response(code)
            self.send_header("Content-Type", "text/plain" if self.path == "/robots.txt" else "text/html")
            self.end_headers()
            self.wfile.write(body.encode())

        def do_POST(self):
            posts.append(self.path)
            self.send_response(405)
            self.end_headers()

        def log_message(self, *_):
            pass

    s = ThreadingHTTPServer(("127.0.0.1", 0), Site)
    threading.Thread(target=s.serve_forever, daemon=True).start()
    return f"http://127.0.0.1:{s.server_port}", s.server_port


def observe(*urls, mandate=None):
    cmd = [sys.executable, str(OBSERVE), *urls, "--contact", CONTACT] + (["--mandate", mandate] if mandate else [])
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", timeout=300)
    return [json.loads(l) for l in r.stdout.splitlines() if l.strip()], r.stderr, r.returncode


def hits(port, path):
    return [e for e in log if e[0] == port and e[2] == path]


open_, a = site("User-agent: *\nDisallow: /private/\n")
closed, b = site("User-agent: *\nDisallow: /\n")
REDIRECTS.update({"/hop.png": f"{open_}/img/hopped.png", "/near": f"{open_}/landed", "/away": f"{closed}/elsewhere".replace("127.0.0.1", "localhost")})  # another host
checks = []


def check(name, ok):
    checks.append(ok)
    print(("ok    " if ok else "FAIL  ") + name)


out, err, code = observe(f"{open_}/one", f"{open_}/two")
check("observes what it may", [o["url"] for o in out] == [f"{open_}/one", f"{open_}/two"] and code == 0)
check("pauses at least 1 s between pages", hits(a, "/two")[0][4] - hits(a, "/one")[-1][4] >= 1.0)
check("names itself and its operator", all("releve-observe/0.5" in e[3] and CONTACT in e[3] for e in log if e[0] == a))

for path, why in [("/locked", "answered 401"), ("/busy", "answered 429"), ("/gone", "answered 404"),
                  ("/gate", "a challenge stands before the content")]:
    out, err, code = observe(open_ + path)
    check(f"leaves {path} alone, once", not out and why in err and code == 3 and len(hits(a, path)) == 1)

out, err, code = observe(f"{closed}/page")
check("obeys robots.txt", not out and "robots.txt refuses" in err and not hits(b, "/page"))

out, err, code = observe("http://127.0.0.1:9/page")
check("stays out when robots.txt is unreachable", not out and "robots.txt unreachable" in err)

out, err, code = observe(f"{closed}/page", mandate="LETTRE-2026-10-01")
check("a written mandate overrides robots.txt, on the record", out and out[0].get("mandate") == "LETTRE-2026-10-01")

out, err, code = observe(f"{open_}/near")
check("follows a redirect within the site, and keeps the address asked for",
      [(o["url"], o["requested"]) for o in out] == [(f"{open_}/landed", f"{open_}/near")])

out, err, code = observe(f"{open_}/away")
check("never requests a closed address a redirect leads to", not out and "robots.txt refuses" in err and not hits(b, "/elsewhere"))

out, err, code = observe(f"{open_}/away", mandate="LETTRE-2026-10-01")
check("a mandate for one site does not open another", not out and not hits(b, "/elsewhere"))

for path in ("/script", "/refresh"):
    out, err, code = observe(open_ + path)
    check(f"never requests a closed address {path} leads to", not out and "robots.txt refuses" in err and not hits(b, "/elsewhere"))

log.clear()
out, err, code = observe(f"{open_}/busy", f"{open_}/after")
check("leaves the whole site alone once it pushes back", not out and "said no earlier" in err and not hits(a, "/after"))

out, err, code = observe(open_.removeprefix("http://") + "/bare")
check("observes web addresses only", not out and "not a web address" in err and not hits(a, "/bare"))

out, err, code = observe(f"{open_}/calm", f"{open_}/form")
check("takes neither an ordinary title nor a widget in a form for a challenge", len(out) == 2)

out, err, code = observe(f"{open_}/late", f"{open_}/renamed")
check("records no page that leaves for, or renames itself to, a closed address", not out and not hits(b, "/elsewhere"))

out, err, code = observe(f"{open_}/popup")
check("opens no other window", len(out) == 1 and not hits(a, "/private/popup"))

out, err, code = observe(f"{open_}/autopost")
check("lets no script submit a form", not out and "submits a form" in err)


out, err, code = observe(f"{open_}/weighed")
check("weighs the page as a reader's browser loads it, not what its own measuring adds",
      len(out) == 1 and out[0]["network"]["requests"] == 5 and out[0]["network"]["transfer"] > 5 * len(PIXEL))

out, err, code = observe(f"{open_}/wordy")
kept = [v for o in out for part in [o["page"]] + o["surfaces"] + o["events"] for k, v in part.items()
        if k in ("title", "text", "name", "label", "alt", "placeholder", "hint", "said", "skip") and isinstance(v, str)]
check("keeps extracts of 80 characters at most of what a page says", len(out) == 1 and len(kept) > 12 and max(map(len, kept)) <= 80)

out, err, code = observe(f"{open_}/unsettled")
check("observes a page that cannot be pictured in time, without its picture, and walks it by keyboard",
      len(out) == 1 and out[0]["shot"] is None and out[0]["page"]["keys"]["stops"] == 2 and out[0]["page"]["keys"]["checked"] == 0)

check("submits nothing", not posts)
sys.exit(0 if all(checks) else 1)
