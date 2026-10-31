#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""survive, against five local sites that are the whole truth table (tests/survive/):

  clean              every marker delivered                   PRESENT
  stripped           delivered bare, the origin has C2PA      STRIPPED_AT_DELIVERY
  absent             neither has any                          ABSENT_AT_ORIGIN
  blocked            the origin answers 403                   ORIGIN_UNOBSERVABLE
  still-transformed  probe 2 still carries an edge header     ORIGIN_UNOBSERVABLE

Each is run twice: the two bodies must be the same bytes and give the same root, and that
root the one stored (tests/survive/expected/). Then the contract's absolutes, each shown
to fail when broken; the markers, probe 2's guard and the settle rule on their own; and
the record path read for randomness, clocks and locales. No network: 127.0.0.1 only.

    python tests/survive.py [--accept]   # --accept stores the bodies as they now are"""
import copy, json, re, sys, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from playwright.sync_api import sync_playwright  # noqa: E402

from survive import markers, probe, record, settle  # noqa: E402
from survive.__main__ import Refused, run, second  # noqa: E402

HERE = ROOT / "tests" / "survive"
EXPECTED = HERE / "expected"
PORT = 8790
SITE = f"http://127.0.0.1:{PORT}"
CONTACT = "https://example.org/robot"
CASES = ("clean", "stripped", "absent", "blocked", "still-transformed")
TYPES = {".html": "text/html; charset=utf-8", ".jpg": "image/jpeg", ".css": "text/css"}
checks = []


def check(name, ok, detail=""):
    checks.append(bool(ok))
    print(("ok    " if ok else "FAIL  ") + name + ("" if ok or not detail else f"\n      {detail}"))


def routes():
    out = {"/style.css": (HERE / "style.css", 200, {})}
    for case in CASES:
        for path, r in json.loads((HERE / case / "fixture.json").read_text())["routes"].items():
            out[path] = (HERE / case / r["file"] if "file" in r else None, r.get("status", 200), r.get("headers", {}))
    return out


EXTRA = {  # pages for the settle rule alone, not part of the truth table
    "/settle/events/": "<!doctype html><title>Events</title><script>new EventSource('/events')</script><p>An open stream",
    "/settle/poller/": "<!doctype html><title>Poller</title><script>setInterval(() => fetch('/tick?' + performance.now()), 200)</script><p>A poller",
}


def serve():
    table = routes()

    class Site(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_GET(self):
            if self.path == "/events":
                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream")
                self.end_headers()
                try:
                    for _ in range(40):
                        self.wfile.write(b"data: x\n\n")
                        self.wfile.flush()
                        time.sleep(0.5)
                except (BrokenPipeError, ConnectionResetError):  # the page is closed, and the stream with it
                    pass
                return
            if self.path == "/robots.txt":
                body, status, headers, kind = b"User-agent: *\nDisallow: /closed/\n", 200, {}, "text/plain"
            elif self.path in EXTRA or self.path.startswith("/tick"):
                body, status, headers, kind = (EXTRA.get(self.path, "").encode(), 200, {}, "text/html; charset=utf-8")
            elif self.path in table:
                file, status, headers = table[self.path]
                body, kind = (file.read_bytes(), TYPES[file.suffix]) if file else (b"forbidden", "text/plain")
            else:
                body, status, headers, kind = b"not here", 404, {}, "text/plain"
            self.send_response(status)
            self.send_header("Content-Type", kind)
            self.send_header("Content-Length", str(len(body)))
            for k, v in headers.items():
                self.send_header(k, v)
            self.end_headers()
            self.wfile.write(body)

    server = ThreadingHTTPServer(("127.0.0.1", PORT), Site)
    server.daemon_threads = True
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def states(doc):
    return {(a["role"], c): v["state"] for a in doc["assets"] for c, v in a["classes"].items()}


def main():
    accept = "--accept" in sys.argv
    serve()
    EXPECTED.mkdir(exist_ok=True)
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        docs = {}
        for case in CASES:
            first, again = (run(browser, f"{SITE}/{case}/", CONTACT) for _ in range(2))
            docs[case] = first
            body = record.canonical(record.body(first))
            check(f"{case}: two runs give the same body, byte for byte, and the same root",
                  body == record.canonical(record.body(again)) and first["root"] == again["root"])
            kept = EXPECTED / f"{case}.json"
            if accept:
                kept.write_text(record.canonical(dict(record.body(first), root=first["root"])) + "\n", encoding="utf-8", newline="\n")
            stored = json.loads(kept.read_text(encoding="utf-8")) if kept.exists() else {}
            check(f"{case}: the root is the one stored ({first['root'][:16]}…)",
                  stored.get("root") == first["root"] and record.canonical(record.body(stored)) == body,
                  f"stored {stored.get('root')}")
            check(f"{case}: the record keeps to its contract", not record.problems(first), record.problems(first))
            check(f"{case}: unsigned, it says so, and the root is still given", first["signed"] is False and len(first["root"]) == 64)
        # ---- the truth table, read from the records themselves
        s = {case: states(docs[case]) for case in CASES}
        check("clean: every class of every asset is present, and no probe was sent",
              set(s["clean"].values()) == {"PRESENT"} and len(s["clean"]) == 6 and docs["clean"]["probe2"]["attempted"] == 0)
        check("stripped: C2PA stripped at delivery; EXIF and IPTC absent at the origin; the transformer is the surface's",
              s["stripped"] == {("img", "c2pa"): "STRIPPED_AT_DELIVERY", ("img", "exif"): "ABSENT_AT_ORIGIN", ("img", "iptc"): "ABSENT_AT_ORIGIN"}
              and docs["stripped"]["assets"][0]["transformer"] == "next-image" and docs["stripped"]["assets"][0]["vector"] == "wrapper"
              and docs["stripped"]["scope"]["probes"] == [f"{SITE}/stripped/origin.jpg"])
        check("absent: every class absent at the origin, after a probe that succeeded untransformed",
              set(s["absent"].values()) == {"ABSENT_AT_ORIGIN"} and docs["absent"]["probe2"] == {"attempted": 1, "status": ["200"], "still_transformed": 0})
        check("blocked: the origin answers 403, so it is unobservable, never absent",
              set(s["blocked"].values()) == {"ORIGIN_UNOBSERVABLE"} and docs["blocked"]["probe2"]["status"] == ["403"])
        check("still-transformed: probe 2 comes back with the edge header, so the origin is unobservable",
              set(s["still-transformed"].values()) == {"ORIGIN_UNOBSERVABLE"} and docs["still-transformed"]["probe2"]["still_transformed"] == 1
              and docs["still-transformed"]["assets"][0]["transformer"] == "cloudflare-polish"
              and docs["still-transformed"]["assets"][0]["vector"] == "header")
        check("assets of one address are kept apart by role, in order", [a["role"] for a in docs["clean"]["assets"]] == ["img", "og:image"])
        # ---- the settle rule
        ev = run(browser, f"{SITE}/settle/events/", CONTACT)["scope"]["settle"]
        check("an open EventSource does not hold the surface from settling", ev["capped"] is False and ev["active_pollers"] == 0, ev)
        t0 = time.monotonic()
        poll = run(browser, f"{SITE}/settle/poller/", CONTACT)
        took = time.monotonic() - t0
        check("a page that polls is taken at the cap, and says so", poll["scope"]["settle"]["capped"] is True and 15 <= took < 30
              and any("did not settle" in w for w in poll["warnings"]) and not record.problems(poll), poll["scope"]["settle"])
        try:
            run(browser, f"{SITE}/closed/", CONTACT)
            left = False
        except Refused:
            left = True
        check("a page robots.txt closes is left alone, and nothing is recorded", left)
        browser.close()
    # ---- the absolutes, each broken once
    doc = docs["stripped"]
    broken = copy.deepcopy(docs["clean"])
    broken["assets"].reverse()
    check("an asset list out of the frozen order is caught", any("order" in p for p in record.problems(broken)))
    broken = copy.deepcopy(doc)
    del broken["scope"]["settle"]["cap"]
    check("a scope without the settle triple is caught", any("settle" in p for p in record.problems(broken)))
    broken = copy.deepcopy(docs["blocked"])
    broken["assets"][0]["classes"]["c2pa"]["state"] = "ABSENT_AT_ORIGIN"
    check("ABSENT_AT_ORIGIN without a successful untransformed probe 2 is caught",
          any("without a successful" in p for p in record.problems(broken)))
    broken = copy.deepcopy(doc)
    broken["root"] = "0" * 64
    check("a root that is not the body's is caught", any("root" in p for p in record.problems(broken)))
    # ---- the fix list
    fixes = record.fixlist(doc, markup=["image-alt"])
    check("the fix list ranks stripped, then absent, then markup; unobservable is unmeasured, apart",
          [r.get("state", "markup") for r in fixes["ranked"]] == ["STRIPPED_AT_DELIVERY", "ABSENT_AT_ORIGIN", "ABSENT_AT_ORIGIN", "markup"]
          and record.fixlist(docs["blocked"])["ranked"] == [] and len(record.fixlist(docs["blocked"])["unmeasured"]) == 3)
    # ---- the markers on their own
    png = b"\x89PNG\r\n\x1a\n" + b"".join(len(d).to_bytes(4, "big") + k + d + b"\0" * 4 for k, d in
                                          ((b"IHDR", b"\0" * 13), (b"caBX", b"x" * 10), (b"eXIf", b"MM\0*"), (b"IEND", b"")))
    bmff = (16).to_bytes(4, "big") + b"ftypheic" + b"\0" * 4 + (40).to_bytes(4, "big") + b"uuid" + markers.C2PA_UUID + b"\0" * 16
    xmp = b"\xff\xd8" + b"\xff\xe1" + (2 + len(markers.XMP) + 4).to_bytes(2, "big") + markers.XMP + b"<x/>" + b"\xff\xda"
    check("PNG caBX and eXIf, ISO-BMFF's C2PA uuid box, and XMP in JPEG APP1 are each read, by size",
          markers.inspect(png) == {"c2pa": 22, "exif": 16, "iptc": 0} and markers.inspect(bmff) == {"c2pa": 40, "exif": 0, "iptc": 0}
          and markers.inspect(xmp)["iptc"] == 2 + 2 + len(markers.XMP) + 4)
    check("a file that breaks off, or is no image, is read as far as it holds",
          markers.inspect((HERE / "clean" / "photo.jpg").read_bytes()[:30]) == {"c2pa": 0, "exif": 0, "iptc": 0}
          and markers.inspect(b"GIF89a") == {"c2pa": 0, "exif": 0, "iptc": 0})
    # ---- probe 2's guard
    check("wrappers are stripped: a relative url=, an absolute one decoded, Cloudflare's path, imgix's parameters",
          probe.wrapper(f"{SITE}/_next/image?url=%2Fa.jpg&w=64") == ("next-image", f"{SITE}/a.jpg", False)
          and probe.wrapper(f"{SITE}/_next/image?url=https%3A%2F%2Fcdn.example%2Fa.jpg&w=64") == ("next-image", "https://cdn.example/a.jpg", True)
          and probe.wrapper("https://x.example/cdn-cgi/image/width=80,format=auto/img/a.jpg") == ("cloudflare-images", "https://x.example/img/a.jpg", False)
          and probe.wrapper("https://x.imgix.net/a.jpg?w=80&auto=format&v=2") == ("imgix", "https://x.imgix.net/a.jpg?v=2", False)
          and probe.wrapper("https://x.example/a.jpg?w=80") is None)
    shut = [probe.refused(u)[0] for u in ("http://127.0.0.1/a", "http://10.1.2.3/a", "http://172.20.0.1/a", "http://192.168.1.1/a",
                                          "http://169.254.169.254/latest", "http://[::1]/a", "http://[fd00::1]/a", "http://[::ffff:127.0.0.1]/a",
                                          "http://localhost/a", "ftp://example.org/a", "file:///etc/passwd")]
    check("an absolute target is refused at a loopback, private, link-local or unique-local address, or off http(s)", all(shut), shut)
    warnings = []
    out = second(f"http://127.0.0.1:{PORT}/stripped/origin.jpg", True, "tests", lambda u: None, warnings)
    check("a wrapper whose url= names a private address sends nothing, and the origin stays unobserved",
          out == {"status": "refused", "still_transformed": False, "sizes": None} and warnings)
    # ---- the record path, read
    source = "\n".join(p.read_text(encoding="utf-8") for p in sorted((ROOT / "survive").glob("*.py")))
    banned = [w for w in ("Math.random", "Date.now(", "toLocale", "Intl.", "import locale", "random.", "uuid.", "%c", "%x", "%X",
                          "%a", "%A", "%b", "%B", "%p", ":n}") if w in source]
    check("the record path has no randomness, no wall clock in the body, and no locale-dependent formatting", not banned, banned)
    check("the one clock read in the record path is observed_at's", len(re.findall(r"datetime\.now|time\.time\(", source)) == 1)
    print(f"{sum(checks)} of {len(checks)} hold")
    return 0 if all(checks) else 1


if __name__ == "__main__":
    sys.exit(main())
