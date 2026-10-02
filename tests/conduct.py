#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The observer's conduct, checked against local sites that say no in every
way a robot must hear. Needs Python, Playwright and Chromium; no network."""
import json, subprocess, sys, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from time import monotonic

OBSERVE = Path(__file__).resolve().parent.parent / "observe" / "observe.py"
CONTACT = "https://example.org/robot"
PAGE = "<!doctype html><html lang=en><title>{}</title><main><h1>{}</h1></main></html>"
ANSWERS = {"/locked": 401, "/busy": 429, "/gone": 404}
REDIRECTS = {}  # path -> address, filled once the sites are up
log = []  # (port, method, path, user agent, time)


def site(robots):
    class Site(BaseHTTPRequestHandler):
        def do_GET(self):
            log.append((self.server.server_port, "GET", self.path, self.headers.get("User-Agent", ""), monotonic()))
            if self.path in REDIRECTS:
                self.send_response(302)
                self.send_header("Location", REDIRECTS[self.path])
                self.end_headers()
                return
            if self.path == "/robots.txt":
                body, code = robots, 200
            elif self.path in ANSWERS:
                body, code = "no", ANSWERS[self.path]
            elif self.path == "/gate":
                body, code = PAGE.format("Just a moment...", "Checking"), 200
            elif self.path == "/script":
                body, code = f"<script>location = '{REDIRECTS['/away']}'</script>", 200
            else:
                body, code = PAGE.format("Page", self.path), 200
            self.send_response(code)
            self.send_header("Content-Type", "text/plain" if self.path == "/robots.txt" else "text/html")
            self.end_headers()
            self.wfile.write(body.encode())

        def do_POST(self):
            log.append((self.server.server_port, "POST", self.path, "", monotonic()))
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


open_, a = site("User-agent: *\nAllow: /\n")
closed, b = site("User-agent: *\nDisallow: /\n")
REDIRECTS.update({"/near": f"{open_}/landed", "/away": f"{closed}/elsewhere"})
checks = []


def check(name, ok):
    checks.append(ok)
    print(("ok    " if ok else "FAIL  ") + name)


out, err, code = observe(f"{open_}/one", f"{open_}/two")
check("observes what it may", [o["url"] for o in out] == [f"{open_}/one", f"{open_}/two"] and code == 0)
check("pauses at least 1 s between pages", hits(a, "/two")[0][4] - hits(a, "/one")[-1][4] >= 1.0)
check("names itself and its operator", all("releve-observe/0.3" in e[3] and CONTACT in e[3] for e in log if e[0] == a))

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

out, err, code = observe(f"{open_}/script")
check("records nothing when a script moves the page to a closed address", not out and "robots.txt refuses" in err)

check("submits nothing", not [e for e in log if e[1] != "GET"])
sys.exit(0 if all(checks) else 1)
