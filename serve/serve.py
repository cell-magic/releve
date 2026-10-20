#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""serve — relevé as a page anyone can use: an address in, a report out.

    serve --contact URL [--port 8000] [--shell en=FILE --shell fr=FILE] [--static DIR] [--counts FILE]
          [--authority URL] [--sky FILE] [--local]

A form asks for the address of a page. The page is observed once, judged, and
the report is the answer. What holds, here and nowhere else:

  - Nothing is kept. No account, no cookie, no script, no log of who asked or
    of what was asked. The observation lives in memory for the time of the
    answer. A reader who wants to follow a page keeps its record themselves:
    the report offers it as a file, and takes it back with the next request.
  - What is counted is counted by week, and stays on the server: how many
    reports were given, in which language, how many followed a record handed
    back, and the broad region a browser's language setting points to.
    Nothing in a count belongs to one request; no time finer than the week.
    No page shows them; serve/counts.py reads them where they are kept.
  - A record handed back is believed only if its seals hold.
  - What the rules leave to a person is put to them as questions, in the report.
    Their answers come back with the record, in the same form, and are written
    into it as a person's readings, beside what the rule said; no page is
    visited for that. A failure a rule can show is not put as a question.
  - The observer's conduct is the observer's own (robots.txt, one page at a
    time, nothing submitted). Here it is narrowed further: only public
    addresses on the web's own ports are requested, by the page or by anything
    the page loads, and one site is visited at most once every PAUSE seconds.
  - One page is observed at a time. Requests wait their turn; past WAITING of
    them, the answer is to come back later.

`--authority` names a time-stamping authority (RFC 3161): each record is dated
by it when it is made or answered, and only the record's latest hash is sent
to it, which says nothing of what it was made from. `--sky` names a JSON file:
an illustration, and the rule by which a dated record moves its cloud dots
(sky.py), set above the report's date.

`--shell` sets the report in a page of your own: the file's `<!-- relevé -->`
is replaced by the report's content, `{title}` by its title; `--static` serves
the files that page needs, under /static/. `--counts` keeps the weekly counts
in a file, across restarts. `--local` admits private addresses, for trying it
on your own machine; never use it in the open.
"""
import argparse, base64, gzip, ipaddress, json, os, queue, re, shutil, socket, subprocess, sys, tempfile, threading, time, urllib.parse, zlib
from datetime import date
from concurrent.futures import Future
from email.parser import BytesParser
from email.policy import HTTP
from html import escape, unescape
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "observe"))
import observe as observer  # noqa: E402  (the observer, beside this file)
import sky  # noqa: E402  (the sky of a record, beside this file)

AUTHORITY = SKY = FROM = None   # set by setup()
PAUSE = 10        # seconds between two visits to one site, at least
WAITING = 4       # requests that may wait their turn
PATIENCE = 90     # seconds a request waits for its answer
LARGEST = 3_000_000  # bytes of a request: a record handed back, compressed
PAGES = 25        # pages a record may hold
RECORDS = 500     # records a record may hold: observations, readings and declarations
RENEW = 40        # observations after which the browser is started afresh

WORDS = {
    "en": {
        "title": "Free page report", "lead": "Give the address of a page. It is opened once, in a browser, by the robot releve-observe; "
        "what it shows is read by rule, and the report is the answer. Nothing is kept: no account, no cookie, no record of the address.",
        "address": "URL", "required": "Required · full address, with https://", "record": "Previous record, to compare", "optional": "Optional",
        "go": "Run report", "language": "Report language",
        "sky": "The sky of this record", "skyis": "Each dot of these clouds is placed by the authority’s signed reply: sky {code}. A record changed, or dated otherwise, has another sky.",
        "verify": "How to verify a record",
        "keep": "Following this page over time", "keepit": "This service keeps nothing. To follow this page over time, keep its record: "
        "hand it back with the next request, and the report will say what was mended, what is new and what stands.",
        "download": "Download the record", "file": ".gz file", "again": "Report on another page",
        "drafts": "Draft statements", "draftsare": "An accessibility statement and an eco-design declaration, drafted from this record, for the owner to complete and publish.",
        "getdrafts": "Download the drafts",
        "html": ".html file",
        "recorded": "{} recorded.",
        "answers": ("1 answer", "{} answers"), "unanswered": "No answers submitted.",
        "no": "The page was not observed", "busy": "Others are waiting. Ask again in a minute.",
        "why": {
            "not a web address": "This is not a web address. It begins with https:// or http://.",
            "not public": "Only public addresses of the web are observed.",
            "robots.txt refuses": "This site’s robots.txt asks robots to stay out, and the robot obeys. To let it in, add to robots.txt: "
                                  "User-agent: releve-observe, then Allow: /",
            "robots.txt unreachable": "This site did not answer for its robots.txt, so the robot stayed out.",
            "recently": "This site was observed a moment ago. Ask again in a few seconds.",
            "record": "This record cannot be read, or its seals do not hold. Send the file as it was downloaded.",
            "full": "This record holds as much as it may.",
            "slow": "The page took too long to answer.",
        },
        "left": [(r".*", r"The robot left the page alone: \g<0>.")],
        "counts": "What the service counts", "countsit": "By week: how many reports were given, in which language, how many followed a record "
        "handed back, and the broad region a browser’s language setting points to. No address, no time finer than the week, nothing about any one "
        "request. A week is shown once it has ended; a region counted fewer than five times in it is shown as “fewer than 5”.",
        "columns": ["Week", "Reports", "Following a record", "In English", "In French"], "few": "fewer than 5", "none": "Nothing counted yet.",
        "regions": {"Europe": "Europe", "North America": "North America", "South America": "South America", "Asia": "Asia", "Africa": "Africa",
                    "Oceania": "Oceania", "unknown": "Region not stated"},
    },
    "fr": {
        "title": "État des lieux gratuit", "lead": "Indiquez l’adresse d’une page. Elle est ouverte une fois, dans un navigateur, par le robot releve-observe ; "
        "ce qu’elle montre est lu par des règles, et le rapport est la réponse. Rien n’est conservé : ni compte, ni cookie, ni trace de l’adresse.",
        "address": "URL", "required": "Requis · adresse complète, avec https://", "record": "Relevé précédent, pour comparer", "optional": "Facultatif",
        "go": "Obtenir l’état des lieux", "language": "Langue du rapport",
        "sky": "Le ciel de ce relevé", "skyis": "Chaque point de ces nuages est placé par la réponse signée de l’autorité : ciel {code}. Un relevé modifié, ou daté autrement, a un autre ciel.",
        "verify": "Vérifier un relevé",
        "keep": "Suivre cette page dans le temps", "keepit": "Ce service ne conserve rien. Pour suivre cette page dans le temps, gardez son relevé : "
        "joignez-le à votre prochaine demande, et le rapport dira ce qui a été corrigé, ce qui est nouveau et ce qui persiste.",
        "download": "Télécharger le relevé", "file": "fichier .gz", "again": "Un autre état des lieux",
        "drafts": "Projets de déclarations", "draftsare": "Une déclaration d’accessibilité et une déclaration d’écoconception, rédigées à partir de ce relevé, que le responsable complète et publie.",
        "getdrafts": "Télécharger les projets",
        "html": "fichier .html",
        "recorded": "{}.",
        "answers": ("1 réponse consignée", "{} réponses consignées"), "unanswered": "Aucune réponse envoyée.",
        "no": "La page n’a pas été observée", "busy": "D’autres demandes attendent. Réessayez dans une minute.",
        "why": {
            "not a web address": "Ce n’est pas une adresse web. Elle commence par https:// ou http://.",
            "not public": "Seules les adresses publiques du web sont observées.",
            "robots.txt refuses": "Le fichier robots.txt de ce site demande aux robots de rester dehors, et le robot obéit. Pour le laisser entrer, "
                                  "ajouter à robots.txt : User-agent: releve-observe, puis Allow: /",
            "robots.txt unreachable": "Ce site n’a pas répondu pour son robots.txt ; le robot est resté dehors.",
            "recently": "Ce site vient d’être observé. Réessayez dans quelques secondes.",
            "record": "Ce relevé ne peut pas être lu, ou ses scellés ne tiennent pas. Envoyez le fichier tel qu’il a été téléchargé.",
            "full": "Ce relevé contient déjà tout ce qu’il peut contenir.",
            "slow": "La page a mis trop de temps à répondre.",
        },
        "left": [(r"answered (\d+)", r"La page a répondu \1 ; le robot l’a laissée."),
                 (r"a challenge stands before the content", "Une vérification anti-robot précède le contenu ; le robot n’insiste pas."),
                 (r"leads to .*", "La page mène à une adresse fermée au robot ; il ne l’a pas suivie."),
                 (r".*", "La page n’a pas pu être chargée.")],
        "counts": "Ce que le service compte", "countsit": "Par semaine : combien de rapports ont été remis, en quelle langue, combien faisaient suite "
        "à un relevé rendu, et la grande région que désigne le réglage de langue du navigateur. Ni adresse, ni heure plus fine que la semaine, rien "
        "qui concerne une demande en particulier. Une semaine paraît une fois achevée ; une région comptée moins de cinq fois y est indiquée « moins de 5 ».",
        "columns": ["Semaine", "Rapports", "Après un relevé", "En anglais", "En français"], "few": "moins de 5", "none": "Rien n’est encore compté.",
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
         "a{color:#1f3a8a}:focus-visible{outline:2px solid #1f3a8a;outline-offset:2px}"
         "fieldset{min-width:0;margin:.5rem 0 0;padding:.5rem .75rem;border:1px solid #c8cacd}legend{padding:0 .25rem;font-weight:600}"
         "fieldset input[type=radio],fieldset label{display:inline;margin:.5rem .25rem 0 0}fieldset label{margin-right:1rem}"
         "fieldset label[for^=n-],fieldset label[for^=dn-]{display:block}fieldset input[type=text]{width:100%;padding:.3rem;color:inherit;background:#fff;border:1px solid #5c6066}")


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


def unpacked(record):
    """A record handed back, opened no further than 20 times the largest request: a small file that would
    open into a huge one is refused before it can fill the memory it passes through."""
    unzip = zlib.decompressobj(16 + zlib.MAX_WBITS)
    try:
        whole = unzip.decompress(record, 20 * LARGEST)
    except zlib.error:
        raise Refused("record") from None
    if unzip.unconsumed_tail or not unzip.eof:
        raise Refused("record")
    return whole


def opened(record, d):
    """A record handed back, written where it passes through memory, believed only if its seals hold."""
    corpus = Path(d, "c")
    if record:
        corpus.write_bytes(unpacked(record))
        code, said, _ = releve("verify", corpus)
        if code != 0 or not said.startswith(b"sealed"):
            raise Refused("record")
        if int(said.split()[2]) >= RECORDS:
            raise Refused("full")
    return corpus


def read(observation, record, lang):
    """The report on a record with this observation added, and the record as it now stands.
    The record is a sealed corpus, compressed; it exists here in memory only."""
    with tempfile.TemporaryDirectory(dir=MEMORY, prefix="releve-") as d:
        corpus = opened(record, d)
        if releve("ingest", corpus, feed=json.dumps(observation, ensure_ascii=False).encode("utf-8"))[0] != 0:
            raise Refused("record")
        stamp(corpus)
        code, report, _ = releve("report", lang, corpus, "--ask")
        if code != 0:
            raise Refused("record")
        return report.decode("utf-8"), gzip.compress(corpus.read_bytes(), mtime=0)


def stamp(corpus):
    """The record dated by the authority named, if one is: only its latest hash leaves. An authority that
    does not answer leaves the record undated, and the report says nothing of a date."""
    if AUTHORITY:
        releve("stamp", corpus, AUTHORITY)


def skyline(record, lang):
    """The record's sky, drawn from its latest time stamp, with what it means; nothing for a record not dated."""
    reply = None
    for line in unpacked(record).decode("utf-8").splitlines():
        if '"stamped":' in line:
            reply = json.loads(line)["event"].get("stamped", {}).get("reply") or reply
    if not SKY or not reply:
        return ""
    w = WORDS[lang]
    drawing, code = sky.draw(SKY["drawing"], base64.b64decode(reply), SKY)
    link = SKY.get("verify", {}).get(lang)
    return (f'<figure>{sky.inline(drawing, w["sky"])}\n<figcaption class="meta">{w["skyis"].format(code=code)}'
            + (f' <a href="{escape(link)}">{w["verify"]}</a>' if link else "") + "</figcaption></figure>")


def markdown(text):
    """A person's note made safe for one line of the record's working document, as `releve facts` writes it."""
    text = " ".join(text.split())[:200]
    return "".join("\\" + c if c in "\\`*_[]</" else c for c in text)


def answer(record, given, lang, declared=None):
    """A person's answers to the points to decide, recorded in the record they hold. Only a point the rule
    itself left to a person is answered; a failure the rule can show is not argued away. The answers go
    through the one door a reading has, `releve correct`, and the report is given again, as it now stands."""
    if not record:
        raise Refused("record")
    with tempfile.TemporaryDirectory(dir=MEMORY, prefix="releve-") as d:
        corpus = opened(record, d)
        code, doc, _ = releve("facts", corpus, "--all")
        if code != 0:
            raise Refused("record")
        lines, observation, count = [], None, 0
        for line in doc.decode("utf-8").split("\n"):
            # A page's report names its observation; questions asked once for pages that share a template name it.
            head = re.match(r"Observation `(\w+)`", line)
            shared = re.match(r"Template `(\w+)`", line)
            observation = head.group(1) if head else "site-" + shared.group(1) if shared else observation
            point = re.match(r"- \*\*REVIEW\*\* (.*) \{(\w+)\}$", line)
            if point and observation and " · machine said " not in line and f"{observation}-{point.group(2)}" in given:
                verdict, note = given[f"{observation}-{point.group(2)}"]
                line = f"- **{verdict}** {point.group(1)}{' // ' + markdown(note) if note.strip() else ''} {{{point.group(2)}}}"
                count += 1
            lines.append(line)
        if count and releve("correct", corpus, feed="\n".join(lines).encode("utf-8"))[0] != 0:
            raise Refused("record")
        # The owner's declarations, through the one door they have, `releve declare`: only what changed is recorded.
        if declared:
            code, doc, _ = releve("declarations", corpus)
            lines = []
            for line in doc.decode("utf-8").split("\n"):
                item = re.match(r"- (.+?) · (?:yes|no|n/a|open) · (.*?)(?: // .*)?$", line)
                name = item and re.sub(r"[^a-z0-9]+", "-", item.group(1).lower()).strip("-")
                if item and name in declared:
                    said, note = declared[name]
                    line = f"- {item.group(1)} · {said} · {item.group(2)}{' // ' + markdown(note) if note.strip() else ''}"
                lines.append(line)
            code, _, said = releve("declare", corpus, feed="\n".join(lines).encode("utf-8"))
            if code != 0:
                raise Refused("record")
            count += int(said.split()[0])
        if count:
            stamp(corpus)
        code, report, _ = releve("report", lang, corpus, "--ask")
        if code != 0:
            raise Refused("record")
        first = re.search(r"^# Relevé · (.*)$", doc.decode("utf-8"), re.M)
        return report.decode("utf-8"), gzip.compress(corpus.read_bytes(), mtime=0), count, first.group(1) if first else ""


def page(lang, title, body, shell=None):
    if shell:
        return shell.replace("{title}", escape(title)).replace("<!-- relevé -->", body)
    return (f'<!doctype html>\n<html lang="{lang}">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n'
            f"<title>{escape(title)}</title>\n<style>{STYLE}</style>\n</head>\n<body>\n<main>\n{body}\n</main>\n</body>\n</html>\n")


def form(lang, heading=2):
    w, other = WORDS[lang], "fr" if lang == "en" else "en"
    return (f'<form method="post" action="{PREFIX}/" enctype="multipart/form-data">\n'
            f'<p><label for="url">{w["address"]}</label>\n<span class="meta" id="url-note">{w["required"]}</span>\n'
            f'<input id="url" name="url" type="url" required autocomplete="url" placeholder="https://" aria-describedby="url-note"></p>\n'
            f'<p><label for="lang">{w["language"]}</label>\n<select id="lang" name="lang"><option value="{lang}" selected>{"English" if lang == "en" else "Français"}</option>'
            f'<option value="{other}">{"English" if other == "en" else "Français"}</option></select></p>\n'
            f'<p><label for="record">{w["record"]}</label>\n<span class="meta" id="record-note">{w["optional"]}</span>\n'
            f'<input id="record" name="record" type="file" aria-describedby="record-note"></p>\n'
            f'<p><button type="submit">{w["go"]}</button></p>\n</form>')


def drafted(record, lang):
    """The draft statements of a record, as a file to keep: drawn from the record alone, in memory."""
    with tempfile.TemporaryDirectory(dir=MEMORY, prefix="releve-") as d:
        corpus = Path(d, "c")
        corpus.write_bytes(unpacked(record))
        code, out, _ = releve("statement", lang, corpus)
        return out if code == 0 else b""


def given_back(lang, report, record, url, said=""):
    """The report as a page of the service: its title, and its body with the record to keep. Where the report
    puts points to a person, it stands inside a form that sends the answers back with the record, and only then;
    the record goes to the service when the person sends it, as when they hand back the file."""
    w = WORDS[lang]
    title = re.search(r"<title>(.*?)</title>", report, re.S).group(1)
    body = report[report.index("<main>") + 6:report.index("</main>")]
    kept = base64.b64encode(record).decode("ascii")
    body = body.replace("</h1>", "</h1>\n" + said, 1).replace("<!-- sky -->", skyline(record, lang), 1)
    if 'type="radio"' in body:
        body = (f'<form method="post" action="{PREFIX}/answer" enctype="multipart/form-data">\n<input type="hidden" name="lang" value="{lang}">\n'
                f'<input type="hidden" name="kept" value="{kept}">\n{body}</form>\n')
    name = "releve-" + re.sub(r"[^a-z0-9.-]+", "-", (observer.place(url) or ("", "page"))[1].lower()) + ".jsonl.gz"
    keep = (f'<h2>{w["keep"]}</h2>\n<p>{w["keepit"]}</p>\n'
            f'<p><a download="{name}" href="data:application/gzip;base64,{kept}">{w["download"]}</a>'
            f' · {w["file"]}, {len(record) // 1024 + 1}&nbsp;k{"B" if lang == "en" else "o"}</p>\n')
    drafts = drafted(record, lang)
    if drafts:
        keep += (f'<h2>{w["drafts"]}</h2>\n<p>{w["draftsare"]}</p>\n<p><a download="{name.replace("releve-", "statements-").replace(".jsonl.gz", ".html")}" '
                 f'href="data:text/html;base64,{base64.b64encode(drafts).decode("ascii")}">{w["getdrafts"]}</a>'
                 f' · {w["html"]}, {len(drafts) // 1024 + 1}&nbsp;k{"B" if lang == "en" else "o"}</p>\n')
    keep += f'<h2>{w["again"]}</h2>\n{form(lang)}'
    return unescape(title), body + keep


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
        if path not in ("/", "/fr/"):
            return self.answer(404, "en", "relevé", '<h1>relevé</h1>\n<p><a href="' + PREFIX + '/">relevé</a></p>')
        lang = "fr" if path == "/fr/" else "en"
        w = WORDS[lang]
        self.answer(200, lang, w["title"], f'<h1>{w["title"]}</h1>\n<p>{w["lead"]}</p>\n{form(lang)}')

    do_HEAD = do_GET  # the same answer, without its body

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
            said = ""
            if urllib.parse.urlsplit(self.path).path.removeprefix(PREFIX) == "/answer":
                # Answers to the points to decide, with the record they belong to. No page is visited.
                given = {k[2:]: ("PASS" if v == b"pass" else "FAIL", (fields.get("n-" + k[2:]) or b"").decode("utf-8", "replace"))
                         for k, v in fields.items() if k and k.startswith("a-") and v in (b"pass", b"fail")}
                try:
                    held = base64.b64decode(fields.get("kept") or b"", validate=True)
                except ValueError:
                    raise Refused("record") from None
                declared = {k[2:]: (v.decode("ascii"), (fields.get("dn-" + k[2:]) or b"").decode("utf-8", "replace"))
                            for k, v in fields.items() if k and k.startswith("d-") and v in (b"yes", b"no", b"n/a")}
                report, record, count, url = answer(held, given, lang, declared)
                w = WORDS[lang]
                said = f'<p><strong>{escape(w["recorded"].format(w["answers"][0] if count == 1 else w["answers"][1].format(count)) if count else w["unanswered"])}</strong></p>\n'
            else:
                url = (fields.get("url") or b"").decode("utf-8", "replace").strip()
                if len(url) > 2000 or observer.place(url) is None:
                    raise Refused("not a web address")
                observation = BENCH.ask(url)
                if FROM:  # where the page was seen from: a site may answer, and ask consent, by country
                    observation = {**observation, "from": FROM}
                report, record = read(observation, fields.get("record") or None, lang)
                url = observation["url"]
                TALLY.count(lang, fields.get("record"), region(self.headers.get("Accept-Language")))
        except TimeoutError:
            return self.refuse(lang, "slow")
        except Refused as r:
            return self.refuse(lang, str(r))
        except Exception as e:  # whatever went wrong, the answer says so and nothing is written
            return self.refuse(lang, type(e).__name__)
        self.answer(200, lang, *given_back(lang, report, record, url, said))

    def refuse(self, lang, why):
        w = WORDS[lang]
        if why == "busy":
            return self.answer(503, lang, w["title"], f'<h1>{w["title"]}</h1>\n<p>{w["busy"]}</p>\n{form(lang)}', [("Retry-After", "60")])
        said = w["why"].get(why) or next(re.sub(a, b, escape(why), count=1) for a, b in w["left"] if re.match(a, why))
        self.answer(200, lang, w["no"], f'<h1>{w["no"]}</h1>\n<p>{said}</p>\n{form(lang)}')


def setup(contact, local=False, shells=(), static=None, prefix="", counts=None, authority=None, skyfile=None, seen_from=None):
    """Everything the door needs, set once before it opens."""
    global AUTHORITY, BENCH, FROM, MEMORY, PREFIX, RELEVE, SHELLS, SKY, STATIC, TALLY
    AUTHORITY, FROM = authority, seen_from
    SKY = None
    if skyfile:
        SKY = json.loads(Path(skyfile).read_text(encoding="utf-8"))
        SKY["drawing"] = (Path(skyfile).parent / SKY["svg"]).read_text(encoding="utf-8")
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
    ap.add_argument("--authority", metavar="URL", help="a time-stamping authority (RFC 3161) to date each record by; without it, none")
    ap.add_argument("--from", dest="seen_from", metavar="CC", help="the country this machine reaches the web from, as two letters; each record says it")
    ap.add_argument("--sky", metavar="FILE", help="the illustration whose cloud dots each dated record moves, and its rule (sky.py)")
    args = ap.parse_args()
    if args.seen_from and not re.fullmatch(r"[A-Z]{2}", args.seen_from):
        ap.error("--from takes a country as two capital letters, as CH or FR")
    setup(args.contact, args.local, args.shell, args.static, args.prefix, args.counts, args.authority, args.sky, args.seen_from)
    ThreadingHTTPServer((args.host, args.port), Door).serve_forever()


if __name__ == "__main__":
    main()
