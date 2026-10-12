#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""serve — relevé as a page anyone can use: an address in, a report out.

    serve --contact URL [--port 8000] [--shell en=FILE --shell fr=FILE] [--static DIR] [--counts FILE] [--local]

A form asks for the address of a page. The page is observed once, judged, and
the report is the answer. What holds, here and nowhere else:

  - Nothing is kept. No account, no cookie, no script, no log of who asked or
    of what was asked. The observation lives in memory for the time of the
    answer. A reader who wants to follow a page keeps its record themselves:
    the report offers it as a file, and takes it back with the next request.
  - What is counted is counted by week, and shown to anyone at /counts once
    the week has ended: how many reports were given, in which language, how
    many followed a record handed back, and the broad region a browser's
    language setting points to. Nothing in a count belongs to one request; no
    time finer than the week.
  - A record handed back is believed only if its seals hold.
  - The observer's conduct is the observer's own (robots.txt, one page at a
    time, nothing submitted). Here it is narrowed further: only public
    addresses on the web's own ports are requested, by the page or by anything
    the page loads, and one site is visited at most once every PAUSE seconds.
  - One page is observed at a time. Requests wait their turn; past WAITING of
    them, the answer is to come back later.

`--shell` sets the report in a page of your own: the file's `<!-- relevé -->`
is replaced by the report's content, `{title}` by its title; `--static` serves
the files that page needs, under /static/. `--counts` keeps the weekly counts
in a file, across restarts. `--local` admits private addresses, for trying it
on your own machine; never use it in the open.
"""
import argparse, base64, gzip, ipaddress, json, os, queue, re, shutil, socket, subprocess, sys, tempfile, threading, time, urllib.parse
from datetime import date
from concurrent.futures import Future
from email.parser import BytesParser
from email.policy import HTTP
from html import escape, unescape
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "observe"))
import observe as observer  # noqa: E402  (the observer, beside this file)

PAUSE = 10        # seconds between two visits to one site, at least
WAITING = 4       # requests that may wait their turn
PATIENCE = 90     # seconds a request waits for its answer
LARGEST = 3_000_000  # bytes of a request: a record handed back, compressed
PAGES = 25        # pages a record may hold
RENEW = 40        # observations after which the browser is started afresh

WORDS = {
    "en": {
        "title": "relevé", "lead": "Give the address of a page. It is opened once, in a browser, by the robot releve-observe; "
        "what it shows is read by rule, and the report is the answer. Nothing is kept: no account, no cookie, no record of the address.",
        "address": "Address of the page", "record": "Record of earlier observations, if one was kept (optional)",
        "go": "Observe the page", "language": "Language of the report",
        "keep": "Keeping the record", "keepit": "This service keeps nothing. To follow this page over time, keep its record: "
        "hand it back with the next request, and the report will say what was mended, what is new and what stands.",
        "download": "Download the record", "again": "Observe another page",
        "no": "The page was not observed", "busy": "Others are waiting. Ask again in a minute.",
        "why": {
            "not a web address": "This is not a web address. It begins with https:// or http://.",
            "not public": "Only public addresses of the web are observed.",
            "robots.txt refuses": "This site's robots.txt asks robots to stay out, and the robot obeys. To let it in, add to robots.txt: "
                                  "User-agent: releve-observe, then Allow: /",
            "robots.txt unreachable": "This site did not answer for its robots.txt, so the robot stayed out.",
            "recently": "This site was observed a moment ago. Ask again in a few seconds.",
            "record": "This record cannot be read, or its seals do not hold. Send the file as it was downloaded.",
            "full": "This record already holds as many pages as it may.",
            "slow": "The page took too long to answer.",
        },
        "left": [(r".*", r"The robot left the page alone: \g<0>.")],
        "counts": "What the service counts", "countsit": "By week: how many reports were given, in which language, how many followed a record "
        "handed back, and the broad region a browser's language setting points to. No address, no time finer than the week, nothing about any one "
        "request. A week is shown once it has ended; a region counted fewer than five times in it is shown as “fewer than 5”.",
        "columns": ["Week", "Reports", "Following a record", "In English", "In French"], "few": "fewer than 5", "none": "Nothing counted yet.",
        "regions": {"Europe": "Europe", "North America": "North America", "South America": "South America", "Asia": "Asia", "Africa": "Africa",
                    "Oceania": "Oceania", "unknown": "Region not stated"},
    },
    "fr": {
        "title": "relevé", "lead": "Indiquez l'adresse d'une page. Elle est ouverte une fois, dans un navigateur, par le robot releve-observe ; "
        "ce qu'elle montre est lu par des règles, et le rapport est la réponse. Rien n'est conservé : ni compte, ni cookie, ni trace de l'adresse.",
        "address": "Adresse de la page", "record": "Relevé des observations précédentes, si vous l'avez gardé (facultatif)",
        "go": "Observer la page", "language": "Langue du rapport",
        "keep": "Garder le relevé", "keepit": "Ce service ne conserve rien. Pour suivre cette page dans le temps, gardez son relevé : "
        "joignez-le à votre prochaine demande, et le rapport dira ce qui a été corrigé, ce qui est nouveau et ce qui persiste.",
        "download": "Télécharger le relevé", "again": "Observer une autre page",
        "no": "La page n'a pas été observée", "busy": "D'autres demandes attendent. Réessayez dans une minute.",
        "why": {
            "not a web address": "Ce n'est pas une adresse web. Elle commence par https:// ou http://.",
            "not public": "Seules les adresses publiques du web sont observées.",
            "robots.txt refuses": "Le fichier robots.txt de ce site demande aux robots de rester dehors, et le robot obéit. Pour le laisser entrer, "
                                  "ajouter à robots.txt : User-agent: releve-observe, puis Allow: /",
            "robots.txt unreachable": "Ce site n'a pas répondu pour son robots.txt ; le robot est resté dehors.",
            "recently": "Ce site vient d'être observé. Réessayez dans quelques secondes.",
            "record": "Ce relevé ne peut pas être lu, ou ses scellés ne tiennent pas. Envoyez le fichier tel qu'il a été téléchargé.",
            "full": "Ce relevé contient déjà autant de pages qu'il peut en contenir.",
            "slow": "La page a mis trop de temps à répondre.",
        },
        "left": [(r"answered (\d+)", r"La page a répondu \1 ; le robot l'a laissée."),
                 (r"a challenge stands before the content", "Une vérification anti-robot précède le contenu ; le robot n'insiste pas."),
                 (r"leads to .*", "La page mène à une adresse fermée au robot ; il ne l'a pas suivie."),
                 (r".*", "La page n'a pas pu être chargée.")],
        "counts": "Ce que le service compte", "countsit": "Par semaine : combien de rapports ont été remis, en quelle langue, combien faisaient suite "
        "à un relevé rendu, et la grande région que désigne le réglage de langue du navigateur. Ni adresse, ni heure plus fine que la semaine, rien "
        "qui concerne une demande en particulier. Une semaine paraît une fois achevée ; une région comptée moins de cinq fois y est indiquée « moins de 5 ».",
        "columns": ["Semaine", "Rapports", "Après un relevé", "En anglais", "En français"], "few": "moins de 5", "none": "Rien n'est encore compté.",
        "regions": {"Europe": "Europe", "North America": "Amérique du Nord", "South America": "Amérique du Sud", "Asia": "Asie", "Africa": "Afrique",
                    "Oceania": "Océanie", "unknown": "Région non indiquée"},
    },
}
# The broad region of a country, by its two-letter code, as a browser's language setting names it (fr-FR, en-GB).
REGIONS = {code: region for region, codes in [
    ("Europe", "AD AL AT AX BA BE BG BY CH CY CZ DE DK EE ES FI FO FR GB GG GI GR HR HU IE IM IS IT JE LI LT LU LV MC MD ME MK MT NL NO PL PT "
               "RO RS RU SE SI SJ SK SM UA VA XK"),
    ("North America", "AG AI AW BB BL BM BQ BS BZ CA CR CU CW DM DO GD GL GP GT HN HT JM KN KY LC MF MQ MS MX NI PA PM PR SV SX TC TT US VC VG VI"),
    ("South America", "AR BO BR CL CO EC FK GF GY PE PY SR UY VE"),
    ("Asia", "AE AF AM AZ BD BH BN BT CN GE HK ID IL IN IQ IR JO JP KG KH KP KR KW KZ LA LB LK MM MN MO MV MY NP OM PH PK PS QA SA SG SY TH TJ "
             "TL TM TR TW UZ VN YE"),
    ("Africa", "AO BF BI BJ BW CD CF CG CI CM CV DJ DZ EG EH ER ET GA GH GM GN GQ GW KE KM LR LS LY MA MG ML MR MU MW MZ NA NE NG RE RW SC SD "
               "SH SL SN SO SS ST SZ TD TG TN TZ UG YT ZA ZM ZW"),
    ("Oceania", "AS AU CK FJ FM GU KI MH MP NC NF NR NU NZ PF PG PN PW SB TK TO TV VU WF WS"),
] for code in codes.split()}
FEW = 5           # a region counted fewer times than this in a week is not shown by its number


def region(accept):
    """The broad region the first language tag with a country names (fr-FR, en-GB), or "unknown". Nothing else is read."""
    for tag in (accept or "").split(",")[:8]:
        for sub in tag.split(";")[0].strip().split("-")[1:]:
            if len(sub) == 2 and sub.isalpha():
                return REGIONS.get(sub.upper(), "unknown")
    return "unknown"


class Tally:
    """The weekly counts, and nothing else: no address, no time finer than the week, nothing that ties a number to one request."""
    def __init__(self, path=None):
        self.path, self.lock = Path(path) if path else None, threading.Lock()
        self.weeks = json.loads(self.path.read_text(encoding="utf-8")) if self.path and self.path.exists() else {}

    @staticmethod
    def week():
        year, week, _ = date.today().isocalendar()
        return f"{year}-W{week:02d}"

    def count(self, lang, following, where):
        with self.lock:
            w = self.weeks.setdefault(self.week(), {"reports": 0, "following": 0, "languages": {}, "regions": {}})
            w["reports"] += 1
            w["following"] += bool(following)
            w["languages"][lang] = w["languages"].get(lang, 0) + 1
            w["regions"][where] = w["regions"].get(where, 0) + 1
            if self.path:
                spare = self.path.with_suffix(".new")
                spare.write_text(json.dumps(self.weeks, sort_keys=True), encoding="utf-8")
                spare.replace(self.path)

    def shown(self):
        """The counts as anyone may read them: weeks that have ended only, so that no count moves while it is watched,
        and a region under FEW in a week shown as such, not by its number."""
        with self.lock:
            return {k: dict(v, regions={r: (n if n >= FEW else f"<{FEW}") for r, n in v["regions"].items()})
                    for k, v in sorted(self.weeks.items()) if k < self.week()}


TYPES = {".css": "text/css; charset=utf-8", ".svg": "image/svg+xml", ".woff2": "font/woff2", ".png": "image/png", ".ico": "image/x-icon"}
STYLE = ("*{box-sizing:border-box}html{color:#1a1a1a;background:#fff}body{margin:0;font:1rem/1.6 system-ui,sans-serif}"
         "main{max-width:42rem;margin:0 auto;padding:1rem 1rem 4rem;overflow-wrap:anywhere}h1,h2,h3{line-height:1.25}"
         "label{display:block;margin-top:1rem}input,select{display:block;max-width:100%;font:inherit}"
         "input[type=url],select{width:32rem;padding:.4rem;color:inherit;background:#fff;border:1px solid #1a1a1a}input[type=file]{margin-top:.25rem}"
         "button{font:inherit;margin-top:1.25rem;padding:.5rem 1rem;color:#fff;background:#1a1a1a;border:1px solid #1a1a1a}"
         "code{font:.875rem/1.4 ui-monospace,monospace;color:#5c6066}.meta{color:#5c6066;font-size:.9375rem}dt{font-weight:600}dd{margin:0 0 .5rem}"
         "a{color:#1f3a8a}:focus-visible{outline:2px solid #1f3a8a;outline-offset:2px}")


def shut(url, local, known={}):
    """Why nothing may be requested from this address, or None: only public addresses, on the web's own ports."""
    try:
        p = urllib.parse.urlsplit(url)
        port = p.port
    except ValueError:
        return "not public"
    if p.scheme not in ("http", "https", "ws", "wss") or local:
        return None
    if port not in (None, 80, 443) or not p.hostname:
        return "not public"
    if p.hostname not in known or time.monotonic() - known[p.hostname][1] > 60:
        try:
            public = all(ipaddress.ip_address(a[4][0]).is_global for a in socket.getaddrinfo(p.hostname, None))
        except (OSError, ValueError):
            public = False
        known[p.hostname] = (public, time.monotonic())
    return None if known[p.hostname][0] else "not public"


class Refused(Exception):
    """The request ends here, and says why."""


class Bench(threading.Thread):
    """The one place where pages are observed, one at a time. A browser is not shared between threads."""
    def __init__(self, contact, local):
        super().__init__(daemon=True)
        self.agent, self.local = f"{observer.AGENT}; +{contact}", local
        self.turns, self.rules, self.last = queue.Queue(), {}, {}
        self.guard = lambda to: shut(to, local)

    def ask(self, url):
        if self.turns.qsize() >= WAITING:
            raise Refused("busy")
        turn = Future()
        self.turns.put((url, turn))
        return turn.result(timeout=PATIENCE)

    def closed(self, url):
        """Why the robot may not go to this address, or None."""
        where = observer.place(url)
        if where is None:
            return "not a web address"
        if self.guard(url):
            return "not public"
        origin = where[0]
        if origin not in self.rules or time.monotonic() - self.rules[origin][1] > (300 if self.rules[origin][0] else 30):
            self.rules[origin] = (observer.robots(origin, self.agent, self.guard), time.monotonic())
        rules = self.rules[origin][0]
        return "robots.txt unreachable" if rules is None else None if rules.can_fetch(observer.AGENT, url) else "robots.txt refuses"

    def run(self):
        try:
            self.observing()
        finally:  # without its bench the service answers nothing: it ends, and whatever keeps it starts it again
            os._exit(1)

    def observing(self):
        from playwright.sync_api import Error as BrowserError, sync_playwright
        with sync_playwright() as pw:
            browser, seen = pw.chromium.launch(), 0
            while True:
                url, turn = self.turns.get()
                try:
                    why = self.closed(url)
                    site = (observer.place(url) or (None, None))[1]
                    if not why and time.monotonic() - self.last.get(site, -1e9) < PAUSE:
                        why = "recently"
                    if why:
                        raise Refused(why)
                    try:
                        turn.set_result(observer.observe(browser, url, self.agent, None, self.closed, self.guard))
                    finally:
                        self.last[site] = time.monotonic()
                except (Refused, observer.Refused) as r:
                    turn.set_exception(Refused(str(r)))
                except BrowserError as e:
                    turn.set_exception(Refused("could not load: " + str(e).splitlines()[0]))
                    seen = RENEW
                except Exception as e:  # the bench outlives any one page
                    turn.set_exception(Refused(type(e).__name__))
                    seen = RENEW
                seen += 1
                for memory in (self.last, self.rules):  # what is remembered of a site is forgotten within minutes
                    for k in [k for k, v in memory.items() if time.monotonic() - (v[1] if isinstance(v, tuple) else v) > 300]:
                        del memory[k]
                if seen >= RENEW:
                    try:
                        browser.close()
                    except BrowserError:
                        pass
                    browser, seen = pw.chromium.launch(), 0


def releve(*args, feed=None):
    r = subprocess.run([RELEVE, *map(str, args)], input=feed, capture_output=True, timeout=60)
    return r.returncode, r.stdout, r.stderr.decode("utf-8", "replace").strip()


def read(observation, record, lang):
    """The report on a record with this observation added, and the record as it now stands.
    The record is a sealed corpus, compressed; it exists here in memory only."""
    with tempfile.TemporaryDirectory(dir=MEMORY, prefix="releve-") as d:
        corpus = Path(d, "c")
        if record:
            try:
                corpus.write_bytes(gzip.decompress(record)[:20 * LARGEST])
            except (OSError, EOFError):
                raise Refused("record") from None
            code, said, _ = releve("verify", corpus)
            if code != 0 or not said.startswith(b"sealed"):
                raise Refused("record")
            if int(said.split()[2]) >= 4 * PAGES:
                raise Refused("full")
        if releve("ingest", corpus, feed=json.dumps(observation, ensure_ascii=False).encode("utf-8"))[0] != 0:
            raise Refused("record")
        code, report, _ = releve("report", lang, corpus)
        if code != 0:
            raise Refused("record")
        return report.decode("utf-8"), gzip.compress(corpus.read_bytes(), mtime=0)


def page(lang, title, body, shell=None):
    if shell:
        return shell.replace("{title}", escape(title)).replace("<!-- relevé -->", body)
    return (f'<!doctype html>\n<html lang="{lang}">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n'
            f"<title>{escape(title)}</title>\n<style>{STYLE}</style>\n</head>\n<body>\n<main>\n{body}\n</main>\n</body>\n</html>\n")


def form(lang, heading=2):
    w, other = WORDS[lang], "fr" if lang == "en" else "en"
    return (f'<form method="post" action="{PREFIX}/" enctype="multipart/form-data">\n'
            f'<label for="url">{w["address"]}</label>\n<input id="url" name="url" type="url" required autocomplete="url" placeholder="https://">\n'
            f'<label for="lang">{w["language"]}</label>\n<select id="lang" name="lang"><option value="{lang}" selected>{"English" if lang == "en" else "Français"}</option>'
            f'<option value="{other}">{"English" if other == "en" else "Français"}</option></select>\n'
            f'<label for="record">{w["record"]}</label>\n<input id="record" name="record" type="file">\n'
            f'<button type="submit">{w["go"]}</button>\n</form>')


class Door(BaseHTTPRequestHandler):
    server_version, sys_version, protocol_version = "releve", "", "HTTP/1.1"

    def log_message(self, *_):  # no log of who asked, or of what
        pass

    def answer(self, code, lang, title, body, extra=()):
        out = page(lang, title, body, SHELLS.get(lang)).encode("utf-8")
        self.send_response(code)
        for k, v in [("Content-Type", "text/html; charset=utf-8"), ("Content-Length", str(len(out))), ("Cache-Control", "no-store"),
                     ("Referrer-Policy", "no-referrer"), ("X-Content-Type-Options", "nosniff"), ("X-Robots-Tag", "noindex"),
                     ("Content-Security-Policy", "default-src 'none'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; "
                                                 "form-action 'self'; base-uri 'none'; frame-ancestors 'none'"), *extra]:
            self.send_header(k, v)
        self.end_headers()
        self.command == "HEAD" or self.wfile.write(out)

    def do_GET(self):
        path = urllib.parse.urlsplit(self.path).path.removeprefix(PREFIX)
        if STATIC and path.startswith("/static/"):
            file = (STATIC / path[8:]).resolve()
            if STATIC in file.parents and file.is_file():
                out = file.read_bytes()
                self.send_response(200)
                for k, v in [("Content-Type", TYPES.get(file.suffix, "application/octet-stream")), ("Content-Length", str(len(out))),
                             ("Cache-Control", "public, max-age=86400"), ("X-Content-Type-Options", "nosniff")]:
                    self.send_header(k, v)
                self.end_headers()
                return self.command == "HEAD" or self.wfile.write(out)
        if path == "/counts.json":
            out = json.dumps(TALLY.shown(), ensure_ascii=False, indent=1).encode("utf-8")
            self.send_response(200)
            for k, v in [("Content-Type", "application/json"), ("Content-Length", str(len(out))), ("Cache-Control", "no-store"),
                         ("X-Content-Type-Options", "nosniff")]:
                self.send_header(k, v)
            self.end_headers()
            return self.command == "HEAD" or self.wfile.write(out)
        if path in ("/counts", "/fr/counts"):
            return self.counts("fr" if path.startswith("/fr/") else "en")
        if path not in ("/", "/fr/"):
            return self.answer(404, "en", "relevé", '<h1>relevé</h1>\n<p><a href="' + PREFIX + '/">relevé</a></p>')
        lang = "fr" if path == "/fr/" else "en"
        w = WORDS[lang]
        self.answer(200, lang, w["title"], f'<h1>{w["title"]}</h1>\n<p>{w["lead"]}</p>\n{form(lang)}')

    do_HEAD = do_GET  # the same answer, without its body

    def counts(self, lang):
        w, weeks = WORDS[lang], TALLY.shown()
        regions = [r for r in w["regions"] if any(r in v["regions"] for v in weeks.values())]
        head = "".join(f'<th scope="col">{c}</th>' for c in w["columns"] + [w["regions"][r] for r in regions])
        cell = lambda n: w["few"] if isinstance(n, str) else str(n)
        rows = "".join(f'<tr><th scope="row">{k}</th><td>{v["reports"]}</td><td>{v["following"]}</td><td>{v["languages"].get("en", 0)}</td>'
                       f'<td>{v["languages"].get("fr", 0)}</td>' + "".join(f'<td>{cell(v["regions"].get(r, 0))}</td>' for r in regions) + "</tr>"
                       for k, v in reversed(list(weeks.items())))
        table = f'<table>\n<thead><tr>{head}</tr></thead>\n<tbody>{rows}</tbody>\n</table>' if weeks else f'<p>{w["none"]}</p>'
        self.answer(200, lang, w["counts"], f'<h1>{w["counts"]}</h1>\n<p>{w["countsit"]}</p>\n{table}')

    def do_POST(self):
        lang = "en"
        try:
            size = int(self.headers.get("Content-Length") or 0)
            if not 0 < size <= LARGEST:
                raise Refused("record")
            raw = self.rfile.read(size)
            kind = self.headers.get("Content-Type", "")
            if kind.startswith("multipart/form-data"):
                parts = BytesParser(policy=HTTP).parsebytes(b"Content-Type: " + kind.encode("latin-1") + b"\r\n\r\n" + raw)
                fields = {p.get_param("name", header="content-disposition"): p.get_payload(decode=True) for p in parts.iter_parts()}
            else:
                fields = {k: v[0].encode("utf-8") for k, v in urllib.parse.parse_qs(raw.decode("utf-8", "replace")).items()}
            lang = "fr" if fields.get("lang") == b"fr" else "en"
            url = (fields.get("url") or b"").decode("utf-8", "replace").strip()
            if len(url) > 2000 or observer.place(url) is None:
                raise Refused("not a web address")
            observation = BENCH.ask(url)
            report, record = read(observation, fields.get("record") or None, lang)
            TALLY.count(lang, fields.get("record"), region(self.headers.get("Accept-Language")))
        except TimeoutError:
            return self.refuse(lang, "slow")
        except Refused as r:
            return self.refuse(lang, str(r))
        except Exception as e:  # whatever went wrong, the answer says so and nothing is written
            return self.refuse(lang, type(e).__name__)
        w = WORDS[lang]
        title = re.search(r"<title>(.*?)</title>", report, re.S).group(1)
        body = report[report.index("<main>") + 6:report.index("</main>")]
        name = "releve-" + re.sub(r"[^a-z0-9.-]+", "-", (observer.place(observation["url"]) or ("", "page"))[1].lower()) + ".jsonl.gz"
        keep = (f'<h2>{w["keep"]}</h2>\n<p>{w["keepit"]}</p>\n'
                f'<p><a download="{name}" href="data:application/gzip;base64,{base64.b64encode(record).decode("ascii")}">{w["download"]}</a>'
                f' ({len(record) // 1024 + 1} k{"B" if lang == "en" else "o"})</p>\n<h2>{w["again"]}</h2>\n{form(lang)}')
        self.answer(200, lang, unescape(title), body + keep)

    def refuse(self, lang, why):
        w = WORDS[lang]
        if why == "busy":
            return self.answer(503, lang, w["title"], f'<h1>{w["title"]}</h1>\n<p>{w["busy"]}</p>\n{form(lang)}', [("Retry-After", "60")])
        said = w["why"].get(why) or next(re.sub(a, b, escape(why), count=1) for a, b in w["left"] if re.match(a, why))
        self.answer(200, lang, w["no"], f'<h1>{w["no"]}</h1>\n<p>{said}</p>\n{form(lang)}')


def setup(contact, local=False, shells=(), static=None, prefix="", counts=None):
    """Everything the door needs, set once before it opens."""
    global BENCH, MEMORY, PREFIX, RELEVE, SHELLS, STATIC, TALLY
    RELEVE = shutil.which(os.environ.get("RELEVE", "releve")) or sys.exit("serve: releve not found; build it, or name it in RELEVE")
    MEMORY = "/dev/shm" if os.access("/dev/shm", os.W_OK) else None  # records pass through memory, not through a disk
    PREFIX = prefix.rstrip("/")
    SHELLS = {k: Path(v).read_text(encoding="utf-8") for k, v in (x.split("=", 1) for x in shells)}
    STATIC = Path(static).resolve() if static else None
    TALLY = Tally(counts)
    BENCH = Bench(contact, local)
    BENCH.start()


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--port", type=int, default=8000)
    ap.add_argument("--host", default="127.0.0.1", help="the address to listen on; a proxy that keeps no log stands in front")
    ap.add_argument("--contact", metavar="URL", required=True,
                    help="where site owners can read what the robot does and reach whoever runs this service")
    ap.add_argument("--prefix", default="", help="the path this service is reached under, if not the root")
    ap.add_argument("--shell", action="append", default=[], metavar="LANG=FILE", help="a page of your own to set the report in")
    ap.add_argument("--static", metavar="DIR", help="files the shell needs, served under /static/")
    ap.add_argument("--counts", metavar="FILE", help="where the weekly counts are kept across restarts; without it, in memory only")
    ap.add_argument("--local", action="store_true", help="admit private addresses: for trying it on your own machine only")
    args = ap.parse_args()
    setup(args.contact, args.local, args.shell, args.static, args.prefix, args.counts)
    ThreadingHTTPServer((args.host, args.port), Door).serve_forever()


if __name__ == "__main__":
    main()
