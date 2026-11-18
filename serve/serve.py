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
  - A record handed back is believed only if its chain holds.
  - The page observed goes back to whoever asked, whole, in a signed bundle with
    the receipt that replays it, and the verifier that checks both offline. The
    record keeps the receipt's head, dated with the rest; the page itself is
    kept nowhere.
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

ROOT = Path(__file__).resolve().parent.parent
sys.path[:0] = [str(ROOT / "observe"), str(ROOT)]
import observe as observer  # noqa: E402  (the observer, beside this file)
from receipt import bundle, sampler  # noqa: E402  (the page as served, and its receipt)
import sky  # noqa: E402  (the sky of a record, beside this file)

AUTHORITY = SKY = FROM = None   # set by setup()
GUIDE = {}                       # the criteria guide, per language, rendered once at setup
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
        "claims": [
            "Not AI — deterministic: the same page gives the same report.",
            "Evidence, not opinion — every finding names the element, the value and the rule.",
            "Dated and sealed — an outside authority time-stamps it (RFC 3161).",
            "Nothing kept — no account, no cookie, no record of the address.",
        ],
        "copy": "Copy the receipt", "print": "Print / save as PDF",
        "run": "Instrument execution: 0 cookies · 0 byte of the page kept · 0 trace of the address.",
        "sky": "The sky of this record", "skyis": "Each dot of these clouds is placed by the authority’s signed reply: sky {code}. A record changed, or dated otherwise, has another sky.",
        "verify": "How to verify a record",
        "keep": "Following this page or adding pages of the site", "keepit": "This service keeps nothing. Keep this record (.gz) and hand it back with the next request: "
        "on the same address, it records what was mended, what is new and what stands; on another page of the same site (up to 25 pages), it pools the questions shared by a template and completes the statement templates.",
        "download": "Download the record", "file": ".gz file", "again": "Report on another page",
        "drafts": "Draft statements", "draftsare": "An accessibility statement and an eco-design declaration, drafted from this record, for the owner to review, complete and publish.",
        "getdrafts": "Download the drafts",
        "updated": "the record and the statement templates below are updated.",
        "guide": "Read the criteria, and what each is for",
        "html": ".html file",
        "served": "The page as it was served", "servedis": "The page the robot was served, held whole in a signed bundle, with the receipt that "
        "replays it. The verifier checks both in a browser, offline. The record carries the receipt’s head, dated with the rest.",
        "getreceipt": "Download the receipt", "json": ".json file", "getbundle": "Download the bundle", "wacz": ".wacz file",
        "getverifier": "Download the verifier",
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
            "record": "This record cannot be read, or its chain does not hold. Send the file as it was downloaded.",
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
        "claims": [
            "Sans IA — déterministe : la même page donne le même rapport.",
            "Des preuves, pas un avis — chaque constat nomme l’élément, la valeur et la règle.",
            "Daté et scellé — une autorité extérieure l’horodate (RFC 3161).",
            "Rien de conservé — ni compte, ni cookie, ni trace de l’adresse.",
        ],
        "copy": "Copier le cartouche", "print": "Imprimer / enregistrer en PDF",
        "run": "Exécution de l'instrument : 0 cookie · 0 octet de la page conservé · 0 trace de l'adresse.",
        "sky": "Le ciel de ce relevé", "skyis": "Chaque point de ces nuages est placé par la réponse signée de l’autorité : ciel {code}. Un relevé modifié, ou daté autrement, a un autre ciel.",
        "verify": "Vérifier un relevé",
        "keep": "Suivre cette page ou compléter le site", "keepit": "Ce service ne conserve rien. Gardez ce relevé (.gz) et joignez-le à votre prochaine demande : "
        "sur la même adresse, il consigne ce qui a été corrigé, ce qui est nouveau et ce qui persiste ; sur une autre page du même site (jusqu'à 25 pages), il mutualise les questions de gabarit et complète les trames de déclaration.",
        "download": "Télécharger le relevé", "file": "fichier .gz", "again": "Un autre état des lieux",
        "drafts": "Trames de déclaration pré-remplies", "draftsare": "Une déclaration d'accessibilité et une déclaration d'écoconception, pré-remplies à partir de ce relevé, que le responsable vérifie, complète et publie.",
        "getdrafts": "Télécharger les trames",
        "updated": "le relevé et les trames de déclaration ci-dessous sont à jour.",
        "guide": "Les critères, et à quoi chacun sert",
        "html": "fichier .html",
        "served": "La page telle qu’elle a été servie", "servedis": "La page servie au robot, gardée entière dans un paquet signé, avec le reçu "
        "qui la rejoue. Le vérificateur contrôle l’un et l’autre dans un navigateur, hors ligne. Le relevé porte l’empreinte du reçu, datée avec le reste.",
        "getreceipt": "Télécharger le reçu", "json": "fichier .json", "getbundle": "Télécharger le paquet", "wacz": "fichier .wacz",
        "getverifier": "Télécharger le vérificateur",
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
            "record": "Ce relevé ne peut pas être lu, ou sa chaîne ne tient pas. Envoyez le fichier tel qu’il a été téléchargé.",
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

# Accessibility-overlay vendors: a third-party script that claims to fix accessibility without changing
# the page. The RGAA doctrine asks for native accessibility, not such a layer. Detecting one is a fact
# about what the page loads, not a verdict on it.
OVERLAYS = [("accessibe.com", "AccessiBe"), ("userway.org", "UserWay"), ("audioeye.com", "AudioEye"),
            ("facil-iti.com", "Facil'iti"), ("equalweb.com", "EqualWeb")]


def overlays(resources):
    """The accessibility-overlay vendors a page loads, by name. A host matches its own domain or a
    subdomain of it."""
    found = set()
    for r in resources:
        host = urllib.parse.urlsplit(r.get("url", "")).hostname or ""
        for base, name in OVERLAYS:
            if host == base or host.endswith("." + base):
                found.add(name)
    return sorted(found)


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
         "fieldset label[for^=n-],fieldset label[for^=dn-]{display:block}fieldset input[type=text]{width:100%;padding:.3rem;color:inherit;background:#fff;border:1px solid #5c6066}"
         "details.pli{margin:.75rem 0;border-top:1px solid #c8cacd;padding-top:.5rem}details.pli>summary{cursor:pointer;padding:.25rem 0}")


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


def receipted(url, html, conditions):
    """The page as the robot was served it, held whole in a signed bundle, and the receipt that replays it.
    Made in memory for whoever asked; kept nowhere."""
    pages = [(url, html)]
    _, receipt, _ = sampler.run(pages, len(pages))
    return receipt, bundle.build(pages, receipt, conditions)


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
    """A record handed back, written where it passes through memory, believed only if its chain holds."""
    corpus = Path(d, "c")
    if record:
        corpus.write_bytes(unpacked(record))
        code, said, _ = releve("verify", corpus)
        if code != 0 or not said.startswith(b"chained"):
            raise Refused("record")
        if int(said.split()[2]) >= RECORDS:
            raise Refused("full")
    return corpus


def read(observation, record, lang):
    """The report on a record with this observation added, and the record as it now stands.
    The record is a chained corpus, compressed; it exists here in memory only."""
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


def claims(lang):
    """The four things that set the service apart, on the landing form before any report."""
    return '<ul class="claims">' + "".join("<li>" + c + "</li>" for c in WORDS[lang]["claims"]) + "</ul>"


def cartouche(lang, url, body):
    """The receipt as three lines to paste into a PR, a ticket or a handover: the address, the verdict,
    and the record's head to verify offline. Nothing is fetched; it is the report already in hand."""
    verdict = re.search(r"<strong>(?:Sur cette page|On this page)[^<]*</strong>", body)
    head = re.search(r"<code>([0-9a-f]{8})</code>", body)
    v = re.sub(r"<[^>]+>", "", verdict.group(0)) if verdict else ""
    h = head.group(1) if head else ""
    if lang == "fr":
        return f"Relevé · Bureau des Surfaces\n{url}\n{v}\nEmpreinte : {h} · vérifiable hors ligne : https://releve.bureaudessurfaces.fr/"
    return f"Record · Bureau des Surfaces\n{url}\n{v}\nFingerprint: {h} · verifiable offline: https://releve.bureaudessurfaces.fr/"


def drafted(record, lang):
    """The draft statements of a record, as a file to keep: drawn from the record alone, in memory."""
    with tempfile.TemporaryDirectory(dir=MEMORY, prefix="releve-") as d:
        corpus = Path(d, "c")
        corpus.write_bytes(unpacked(record))
        code, out, _ = releve("statement", lang, corpus)
        if code != 0:
            return b""
        return (out.replace(b"Draft statements \xc2\xb7 ", b"Pre-filled statement templates \xc2\xb7 ")
                   .replace(b"Projets de d\xc3\xa9clarations \xc2\xb7 ", b"Trames de d\xc3\xa9claration pr\xc3\xa9-remplies \xc2\xb7 "))


def offered(lang, name, kind, data, words):
    """A file to keep, as a link that holds it."""
    w = WORDS[lang]
    return (f'<a download="{name}" href="data:{kind};base64,{base64.b64encode(data).decode("ascii")}">{w[words[0]]}</a>'
            f' · {w[words[1]]}, {len(data) // 1024 + 1}&nbsp;k{"B" if lang == "en" else "o"}')


def promote(body):
    """The one-line verdict — how many checks pass, how many fixes and open questions — moved out of
    the method drawer to the top of the report, where it answers the one question a reader asks."""
    m = re.search(r"<p><strong>(?:Sur cette page|On this page)[^<]*</strong>.*?</p>", body, re.S)
    if not m:
        return body
    verdict = m.group(0).replace("<p>", '<p class="verdict">', 1)
    body = body[: m.start()] + body[m.end():]
    at = body.find("</h1>")
    if at < 0:
        return verdict + "\n" + body
    return body[: at + len("</h1>")] + "\n" + verdict + body[at + len("</h1>"):]


def drop(body, heading):
    """Cut a whole section, heading and all: the engine's own reading model, not a rule's words."""
    return re.sub(r"<h2>" + re.escape(heading) + r"</h2>.*?(?=<h2>|\Z)", "", body, flags=re.S, count=1)


def zones(body, fr):
    """Two labels over the report's two halves: what the rules decided, and what they could not."""
    if fr:
        body = re.sub(r"(<h2>Empreinte</h2>\n)", r'\1<p class="zone">Ce que les règles ont tranché — daté par une autorité extérieure.</p>\n', body, count=1)
        body = re.sub(r"(<h2>Questions ouvertes \(\d+\)</h2>\n)", r'\1<p class="zone">Ce qu’aucune règle ne peut trancher — à confirmer par un humain.</p>\n', body, count=1)
    else:
        body = re.sub(r"(<h2>Footprint</h2>\n)", r'\1<p class="zone">What the rules decided — dated by an outside authority.</p>\n', body, count=1)
        body = re.sub(r"(<h2>Open questions \(\d+\)</h2>\n)", r'\1<p class="zone">What no rule can decide — to confirm by a person.</p>\n', body, count=1)
    return body


def effort_summary(body, fr):
    """The open questions counted by the effort each asks, so a reader sees the shape of the work
    before the list: how many are light, moderate, heavy. Reads only what the report already states."""
    sec = re.search(r"(<h2>(?:Questions ouvertes|Open questions) \(\d+\)</h2>)(.*?)(?=<h2>|\Z)", body, re.S)
    if not sec:
        return body
    keys = ([("correction légère", "légère", "légères"), ("correction moyenne", "moyenne", "moyennes"),
             ("correction lourde", "lourde", "lourdes")] if fr
            else [("light fix", "light", "light"), ("moderate fix", "moderate", "moderate"), ("heavy fix", "heavy", "heavy")])
    counts = [0, 0, 0]
    for m in re.finditer(r"<h3>.*?</h3>\n<p class=\"meta\">([^<]*)</p>\n<ul>\n(.*?)\n</ul>", sec.group(2), re.S):
        for i, (key, _, _) in enumerate(keys):
            if key in m.group(1):
                counts[i] += m.group(2).count("<li>")
                break
    if not any(counts):
        return body
    parts = [f"{n} {many if n != 1 else one}" for n, (_, one, many) in zip(counts, keys) if n]
    summary = ("Par effort : " if fr else "By effort: ") + " · ".join(parts) + "."
    return body[:sec.start()] + sec.group(1) + f'<p class="meta">{summary}</p>\n' + sec.group(2) + body[sec.end():]


def trim(body, fr):
    """Cut the invented prose from the report a person reads: the per-criterion blurbs (the rule's
    references stay), the 'Holds here' wrappers (the statement itself becomes the question), and the
    observer's own hesitation ('may be mid-animation'). The verdict is promoted to the top, the engine's
    reading model is cut whole, and the method, the criteria list and the not-looked-at note fold into
    closed drawers. Wording is borrowed from the rules, not written."""
    body = re.sub(r"</h3>\n<p>(.*?) <span class=\"meta\">(.*?)</span></p>",
                  lambda m: "</h3>\n<p class=\"meta\">" + m.group(2) + "</p>", body)
    body = re.sub(r"<legend>Holds here: “(.*?)”?</legend>", r"<legend>\1</legend>", body)
    body = re.sub(r"<legend>Tenu ici : «\s*(.*?)\s*»\s*?</legend>", r"<legend>\1</legend>", body)
    body = re.sub(r" · partly transparent \(opacity [\d.]+\), may be mid-animation", "", body)
    body = re.sub(r" · en partie transparent \(opacité [\d,]+\)[^<]*", "", body)
    body = promote(body)
    body = drop(body, "La lecture" if fr else "The reading")
    body = effort_summary(body, fr)
    body = zones(body, fr)
    for t in (["Méthode", "Critère par critère", "Ce qui n'a pas été regardé"] if fr
              else ["Method", "Criterion by criterion", "What was not looked at"]):
        pat = re.compile(r"<h2>" + re.escape(t) + r"</h2>(.*?)(?=<h2>|\Z)", re.S)
        body = pat.sub(lambda m, tt=t: '<details class="pli"><summary>' + tt + "</summary>\n" + m.group(1) + "</details>\n", body, count=1)
    return body


def panels(body):
    """A report laid out horizontally: one panel per heading, the opening panel carrying the title and
    the verdict. Each panel is a station of the ring, read down its own column, the ring read across."""
    return "".join(f'<section class="station">{p}</section>\n' for p in re.split(r"(?=<h2[ >])", body) if p.strip())


def smart_adjust(body, lang, record=None):
    """Ensure the interactive report presents its footprint and reading measures above the manual questionnaires,
    and folds whole-page review checklists, non-applicable criteria, and unanswered declaration families into
    native <details class="pli"> disclosures. Idempotent if the kernel has already emitted <details class="pli">."""
    fr = lang == "fr"
    if fr:
        body = body.replace("<h1>État des lieux · ", "<h1>Relevé · ", 1)
        body = re.sub(
            r"<p><strong>(\d+) contrôle(s?) passe(?:nt)? · ",
            lambda m: f"<p><strong>Sur cette page\xa0: {m.group(1)} point{m.group(2)} sans écart · ",
            body,
            count=1,
        )
        body = body.replace(
            "Déclarés une fois par le responsable pour tout le relevé. Les textes officiels prévalent.",
            "Les réponses saisies pré-remplissent la trame déclarative de l'éditeur. Les textes officiels prévalent.",
            1,
        )
    else:
        body = body.replace("<h1>Report · ", "<h1>Record · ", 1)
        body = re.sub(
            r"<p><strong>(\d+) check(s?) pass(?:es)? · ",
            lambda m: f"<p><strong>On this page: {m.group(1)} point{m.group(2)} without discrepancy · ",
            body,
            count=1,
        )
        body = body.replace(
            "Declared once by the owner for the whole record. The official texts prevail.",
            "Recorded answers pre-fill the publisher's statement template. The official texts prevail.",
            1,
        )
    obs = None
    if record:
        for line in unpacked(record).decode("utf-8", "replace").splitlines():
            if '"observed":' in line:
                obs = json.loads(line).get("event", {}).get("observed") or obs
    if obs:
        res = (obs.get("network") or {}).get("resources") or []
        pre_hosts = {urllib.parse.urlsplit(r.get("url", "")).hostname for r in res if r.get("third") and r.get("pre")} - {None, ""}
        if pre_hosts:
            if fr:
                body = re.sub(r"(· \d+ hôtes tiers)", rf"\1 ({len(pre_hosts)} sollicités avant toute interaction)", body, count=1)
            else:
                body = re.sub(r"(· \d+ third-party hosts)", rf"\1 ({len(pre_hosts)} contacted before any interaction)", body, count=1)
        ov = overlays(res)
        if ov:
            over = (f'<p class="meta">Surcouche d’accessibilité tierce : {", ".join(ov)} — la doctrine RGAA demande une accessibilité native, non une surcouche.</p>\n'
                    if fr else f'<p class="meta">Third-party accessibility overlay: {", ".join(ov)} — the RGAA doctrine asks for native accessibility, not an overlay.</p>\n')
            body = re.sub(r"(<h2>(?:Empreinte|Footprint)</h2>\n)", rf"\1{over}", body, count=1)
        imgs = [s for s in (obs.get("surfaces") or []) if s.get("kind") == "img"]
        if imgs:
            m_cnt = sum(1 for s in imgs if s.get("manifest") is True)
            o_cnt = sum(1 for s in imgs if s.get("origin"))
            prov = (f"<p>{m_cnt} sur {len(imgs)} images portent un manifeste de provenance (C2PA)\xa0; {o_cnt} déclarent une origine synthétique.</p>\n"
                    if fr else f"<p>{m_cnt} of {len(imgs)} images carry a provenance manifest (C2PA); {o_cnt} state a synthetic origin.</p>\n")
            body = re.sub(r"(<h2>(?:Empreinte|Footprint)</h2>\n<p>.*?</p>\n)", rf"\1{prov}", body, count=1)
            stripped = [s for s in imgs if s.get("origin") and not s.get("manifest")]
            if stripped:
                n = len(stripped)
                if fr:
                    strip = f'<p class="meta">{n} image{"s" if n != 1 else ""} déclare{"nt" if n != 1 else ""} une origine synthétique sans manifeste C2PA lisible — article 50(2) du règlement sur l’IA.</p>\n'
                else:
                    strip = f'<p class="meta">{n} image{"s" if n != 1 else ""} declare{"s" if n == 1 else ""} a synthetic origin with no readable C2PA manifest — AI Act Art. 50(2).</p>\n'
                body = re.sub(r"(<h2>(?:Empreinte|Footprint)</h2>\n)", rf"\1{strip}", body, count=1)
    if '<details class="pli"' in body:
        return trim(body, fr)
    # 1. Promote Empreinte / Footprint and La lecture / The reading above Questions ouvertes / Open questions
    fp_re = re.compile(r"(<h2>(?:Empreinte|Footprint)</h2>\n.*?)(?=<h2 id=\"declarations\">|<h2>(?:Ce qui n'a pas été regardé|What was not looked at)</h2>|\Z)", re.S)
    q_re = re.compile(r"<h2>(?:Questions ouvertes|Open questions|Allègements|Lighter options) \(\d+\)</h2>")
    m_fp, m_q = fp_re.search(body), q_re.search(body)
    if m_fp and m_q and m_fp.start() > m_q.start():
        vitals = m_fp.group(1)
        body = body[:m_fp.start()] + body[m_fp.end():]
        m_q = q_re.search(body)
        if m_q:
            body = body[:m_q.start()] + vitals + body[m_q.start():]
    # 2. Fold whole-page review checklists (", à relire" / ", for review") inside Questions ouvertes
    rev_re = re.compile(r"(<h3>[^<]*(?:, à relire|, for review)</h3>\n.*?)(?=<p><button type=\"submit\">|<h2>)", re.S)
    m_rev = rev_re.search(body)
    if m_rev:
        chunk = m_rev.group(1)
        n_q = chunk.count("<fieldset>")
        if n_q:
            lbl = f"À relire sur la page entière ({n_q})" if fr else f"Page-wide questions ({n_q})"
            body = body[:m_rev.start()] + f'<details class="pli"><summary>{lbl}</summary>\n{chunk}</details>\n' + body[m_rev.end():]
    # 3. Fold non-applicable ("sans objet :" / "not applicable:") items in Critère par critère
    crit_re = re.compile(r"(<h2>(?:Critère par critère|Criterion by criterion)</h2>\n)<ul>\n(.*?)\n</ul>", re.S)
    m_crit = crit_re.search(body)
    if m_crit:
        items = m_crit.group(2).splitlines()
        active = [x for x in items if " · sans objet\xa0:" not in x and " · sans objet :" not in x and " · not applicable: " not in x]
        na = [x for x in items if x not in active]
        if na:
            lbl = f"Sans objet sur cette page ({len(na)})" if fr else f"Not applicable on this page ({len(na)})"
            rep = (m_crit.group(1) + "<ul>\n" + "\n".join(active) + "\n</ul>\n"
                   + f'<details class="pli"><summary>{lbl}</summary>\n<ul>\n' + "\n".join(na) + "\n</ul></details>")
            body = body[:m_crit.start()] + rep + body[m_crit.end():]
    # 4. Fold unanswered declaration families inside Déclarations
    decl_re = re.compile(r'(<h2 id="declarations">.*?<p><strong>.*?</strong></p>\n)(.*?)(<p><button type="submit">(?:Envoyer les déclarations|Submit declarations)</button></p>)', re.S)
    m_decl = decl_re.search(body)
    if m_decl:
        def fold_fam(m):
            title, ul = m.group(1), m.group(2)
            total = ul.count("<li>")
            done = ul.count(" checked>")
            open_n = total - done
            if fr:
                stat = f"{open_n} ouverte{'s' if open_n > 1 else ''}" + (f", {done} déclarée{'s' if done > 1 else ''}" if done else "")
            else:
                stat = f"{open_n} open" + (f", {done} answered" if done else "")
            attr = " open" if done else ""
            return f'<details class="pli"{attr}><summary>{title} · {stat}.</summary>\n<h3>{title}</h3>\n<ul>\n{ul}\n</ul></details>'
        folded = re.sub(r"<h3>([^<]+)</h3>\n<ul>\n(.*?)\n</ul>", fold_fam, m_decl.group(2), flags=re.S)
        body = body[:m_decl.start()] + m_decl.group(1) + folded + m_decl.group(3) + body[m_decl.end():]
    if fr:
        body = body.replace(">Envoyer les réponses</button>", ">Consigner les réponses</button>")
        body = body.replace(">Envoyer les déclarations</button>", ">Consigner les déclarations</button>")
    else:
        body = body.replace(">Submit answers</button>", ">Record the answers</button>")
        body = body.replace(">Submit declarations</button>", ">Record the declarations</button>")
    return trim(body, fr)


def given_back(lang, report, record, url, said="", served=None):
    """The report as a page of the service: its title, and its body with the record to keep. Where the report
    puts points to a person, it stands inside a form that sends the answers back with the record, and only then;
    the record goes to the service when the person sends it, as when they hand back the file."""
    w = WORDS[lang]
    title = re.search(r"<title>(.*?)</title>", report, re.S).group(1)
    body = report[report.index("<main>") + 6:report.index("</main>")]
    kept = base64.b64encode(record).decode("ascii")
    body = body.replace("</h1>", "</h1>\n" + said, 1).replace("<!-- sky -->", skyline(record, lang), 1)
    if SHELLS:
        body = smart_adjust(body, lang, record)
    name = "releve-" + re.sub(r"[^a-z0-9.-]+", "-", (observer.place(url) or ("", "page"))[1].lower()) + ".jsonl.gz"
    keep = f'<h2>{w["keep"]}</h2>\n<p>{w["keepit"]}</p>\n<p>{offered(lang, name, "application/gzip", record, ("download", "file"))}</p>\n'
    keep += (f'<p class="meta">{w["run"]}</p>\n'
             f'<div class="cartouche"><button type="button" class="copier" data-cartouche>{w["copy"]}</button>'
             f'<button type="button" class="print" data-print>{w["print"]}</button>'
             f'<template id="cartouche">{escape(cartouche(lang, url, body))}</template></div>\n')
    if served:
        receipt, wacz = served
        stem = name.replace(".jsonl.gz", "")
        keep += (f'<h2>{w["served"]}</h2>\n<p>{w["servedis"]}</p>\n<ul>\n'
                 f'<li>{offered(lang, stem + ".receipt.json", "application/json", json.dumps(receipt, indent=1).encode("utf-8"), ("getreceipt", "json"))}</li>\n'
                 f'<li>{offered(lang, stem + ".wacz", "application/wacz", wacz, ("getbundle", "wacz"))}</li>\n'
                 f'<li>{offered(lang, "verifier.html", "text/html", VERIFIER, ("getverifier", "html"))}</li>\n</ul>\n')
    drafts = drafted(record, lang)
    if drafts:
        keep += (f'<h2>{w["drafts"]}</h2>\n<p>{w["draftsare"]}</p>\n'
                 f'<p>{offered(lang, name.replace("releve-", "statements-").replace(".jsonl.gz", ".html"), "text/html", drafts, ("getdrafts", "html"))}</p>\n')
    keep += f'<h2>{w["again"]}</h2>\n{form(lang)}'
    content = panels(body) + panels(keep)
    if 'type="radio"' in content:
        content = (f'<form method="post" action="{PREFIX}/answer" enctype="multipart/form-data">\n<input type="hidden" name="lang" value="{lang}">\n'
                   f'<input type="hidden" name="kept" value="{kept}">\n{content}</form>\n')
    return unescape(title), content


class Door(BaseHTTPRequestHandler):
    server_version, sys_version, protocol_version = "releve", "", "HTTP/1.1"

    def log_message(self, *_):  # no log of who asked, or of what
        pass

    def answer(self, code, lang, title, body, extra=()):
        out = page(lang, title, body, SHELLS.get(lang)).encode("utf-8")
        self.send_response(code)
        for k, v in [("Content-Type", "text/html; charset=utf-8"), ("Content-Length", str(len(out))), ("Cache-Control", "no-store"),
                     ("Referrer-Policy", "no-referrer"), ("X-Content-Type-Options", "nosniff"), ("X-Robots-Tag", "noindex"),
                     ("Content-Security-Policy", "default-src 'none'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; "
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
        if path in ("/guide", "/fr/guide"):
            lang = "fr" if path == "/fr/guide" else "en"
            out = GUIDE.get(lang, b"")
            if not out:
                return self.answer(404, lang, "relevé", '<h1>relevé</h1>\n<p><a href="' + PREFIX + '/">relevé</a></p>')
            self.send_response(200)
            for k, v in [("Content-Type", "text/html; charset=utf-8"), ("Content-Length", str(len(out))), ("Cache-Control", "no-store"),
                         ("Referrer-Policy", "no-referrer"), ("X-Content-Type-Options", "nosniff"), ("X-Robots-Tag", "noindex"),
                         ("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'")]:
                self.send_header(k, v)
            self.end_headers()
            return self.command == "HEAD" or self.wfile.write(out)
        if path not in ("/", "/fr/"):
            return self.answer(404, "en", "relevé", '<h1>relevé</h1>\n<p><a href="' + PREFIX + '/">relevé</a></p>')
        lang = "fr" if path == "/fr/" else "en"
        w = WORDS[lang]
        self.answer(200, lang, w["title"], panels(f'<h1>{w["title"]}</h1>\n<p>{w["lead"]}</p>\n{claims(lang)}\n{form(lang)}'))

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
            said, served = "", None
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
                said = (f'<p><strong>{escape(w["recorded"].format(w["answers"][0] if count == 1 else w["answers"][1].format(count)) if count else w["unanswered"])}'
                        + (f' — {w["updated"]}' if count and SHELLS else '') + '</strong></p>\n')
            else:
                url = (fields.get("url") or b"").decode("utf-8", "replace").strip()
                if len(url) > 2000 or observer.place(url) is None:
                    raise Refused("not a web address")
                observation, html = BENCH.ask(url)
                if FROM:  # where the page was seen from: a site may answer, and ask consent, by country
                    observation = {**observation, "from": FROM}
                served = receipted(observation["url"], html, {"from": FROM} if FROM else {})
                observation = {**observation, "receipt": served[0]["head"]}
                report, record = read(observation, fields.get("record") or None, lang)
                url = observation["url"]
                TALLY.count(lang, fields.get("record"), region(self.headers.get("Accept-Language")))
        except TimeoutError:
            return self.refuse(lang, "slow")
        except Refused as r:
            return self.refuse(lang, str(r))
        except Exception as e:  # whatever went wrong, the answer says so and nothing is written
            return self.refuse(lang, type(e).__name__)
        self.answer(200, lang, *given_back(lang, report, record, url, said, served))

    def refuse(self, lang, why):
        w = WORDS[lang]
        if why == "busy":
            return self.answer(503, lang, w["title"], panels(f'<h1>{w["title"]}</h1>\n<p>{w["busy"]}</p>\n{form(lang)}'), [("Retry-After", "60")])
        said = w["why"].get(why) or next(re.sub(a, b, escape(why), count=1) for a, b in w["left"] if re.match(a, why))
        self.answer(200, lang, w["no"], panels(f'<h1>{w["no"]}</h1>\n<p>{said}</p>\n{form(lang)}'))


def setup(contact, local=False, shells=(), static=None, prefix="", counts=None, authority=None, skyfile=None, seen_from=None):
    """Everything the door needs, set once before it opens."""
    global AUTHORITY, BENCH, FROM, GUIDE, MEMORY, PREFIX, RELEVE, SHELLS, SKY, STATIC, TALLY, VERIFIER
    AUTHORITY, FROM = authority, seen_from
    SKY = None
    if skyfile:
        SKY = json.loads(Path(skyfile).read_text(encoding="utf-8"))
        SKY["drawing"] = (Path(skyfile).parent / SKY["svg"]).read_text(encoding="utf-8")
    VERIFIER = (ROOT / "receipt" / "verifier.html").read_bytes()
    RELEVE = shutil.which(os.environ.get("RELEVE", "releve")) or sys.exit("serve: releve not found; build it, or name it in RELEVE")
    GUIDE.clear()
    for glang in ("en", "fr"):
        code, out, _ = releve("guide", glang)
        if code == 0:
            GUIDE[glang] = out
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
