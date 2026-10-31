# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""survive — whether the provenance markers of a page's images survive its delivery.

    python -m survive URL --contact URL  >  record.json

One record (CONTRACT.md), its keys sorted, on one line. The observer's conduct holds: robots.txt
is read first and obeyed, wherever the page or a probe leads; the robot names itself and its
operator; nothing is submitted, no window opened, no service worker run. No model, no
randomness, no clock in the body: two runs of one unchanged surface give the same bytes but
for `observed_at`."""
import argparse, sys, time
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "observe"))
from observe import AGENT, DESKTOP, PAUSE, place, robots  # noqa: E402
from playwright.sync_api import Error as BrowserError, sync_playwright  # noqa: E402

from survive import markers, probe, record, settle  # noqa: E402

SCOPE = {"viewport": DESKTOP, "dpr": 1, "reduced_motion": "reduce", "locale": "en-US", "tz": "UTC", "pages": 1}
ASSETS = """() => { const out = [];
  for (const i of document.images) { const u = i.currentSrc || i.src; if (u) out.push(["img", u]); }
  for (const m of document.querySelectorAll('meta[property="og:image"]')) {
    const c = m.getAttribute("content"); if (c) try { out.push(["og:image", new URL(c, document.baseURI).href]); } catch (e) {} }
  return out; }"""


class Refused(Exception):
    pass


def run(browser, url, contact):
    """The record of one page."""
    agent = f"{AGENT}; +{contact}"
    ua = f"Mozilla/5.0 (compatible; {agent})"
    rules = {}

    def closed(to):
        where = place(to)
        if where is None:
            return "not a web address"
        if where[0] not in rules:
            rules[where[0]] = robots(where[0], agent)
        if rules[where[0]] is None:
            return "robots.txt unreachable"
        return None if rules[where[0]].can_fetch(AGENT, to) else "robots.txt refuses"

    why = closed(url)
    if why:
        raise Refused(why)
    ctx = browser.new_context(viewport=SCOPE["viewport"], device_scale_factor=SCOPE["dpr"], reduced_motion=SCOPE["reduced_motion"],
                              locale=SCOPE["locale"], timezone_id=SCOPE["tz"], user_agent=ua, accept_downloads=False,
                              service_workers="block")
    try:
        settle.watch(ctx)
        ctx.route("**/*", lambda r: r.abort() if r.request.is_navigation_request() and closed(r.request.url) else r.continue_())
        page = ctx.new_page()
        page.on("popup", lambda p: p.close())
        seen = {}
        page.on("response", lambda r: seen.__setitem__(r.url, r))
        flight = settle.Flight(page)
        started = time.monotonic()
        answer = page.goto(url, wait_until="commit", timeout=settle.CAP)
        if answer is None or answer.status >= 400:
            raise Refused(f"answered {answer.status if answer else 'nothing'}")
        settled = settle.settle(page, flight, started)
        found = sorted({(role, u) for role, u in page.evaluate(ASSETS) if u.startswith(("http://", "https://"))})
        assets, probes, targets, warnings, asked = [], [], [], [], {}
        for role, u in found:
            try:
                if role == "img" and u in seen:
                    r = seen[u]
                    status, headers, data = r.status, r.headers, r.body()
                elif closed(u):
                    warnings.append(f"{u}: not fetched: {closed(u)}")
                    continue
                else:  # an image the page names but did not load, as a reader's share card or crawler would ask for it
                    r = ctx.request.get(u, max_redirects=0, timeout=probe.TIMEOUT * 1000)
                    status, headers, data = r.status, r.headers, r.body()
            except BrowserError:
                status, data = None, None
            if status != 200 or data is None:
                warnings.append(f"{u}: its delivered bytes could not be read; it is not recorded")
                continue
            delivered = markers.inspect(data)
            transformer, vector, target, absolute = probe.edge(headers), "header", u, False
            if transformer is None:
                wrapped = probe.wrapper(u)
                transformer, vector = (wrapped[0], "wrapper") if wrapped else (None, "origin")
                if wrapped:
                    target, absolute = wrapped[1], wrapped[2]
            origin = None
            if transformer and any(not delivered[c] for c in markers.CLASSES):
                if target not in asked:
                    asked[target] = second(target, absolute, agent, closed, warnings)
                    targets.append(target)
                    probes.append(asked[target])
                origin = asked[target]["sizes"]
            assets.append(record.asset(u, role, delivered, origin, transformer, vector))
        scope = dict(SCOPE, url=url, probes=targets, ua=ua, settle=settled)
        if settled["capped"]:
            warnings.append(f"the surface did not settle within {settle.CAP} ms; taken with {settled['active_pollers']} requests in flight")
        return record.document(scope, assets, probes, warnings, datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
    finally:
        ctx.close()


def second(target, absolute, agent, closed, warnings):
    """Probe 2 to one target: {status, still_transformed, sizes}; sizes None unless the origin was seen."""
    connect_to = None
    if absolute:
        why, connect_to = probe.refused(target)
        if why:
            warnings.append(f"probe 2 to {target} not sent: {why}")
            return {"status": "refused", "still_transformed": False, "sizes": None}
    why = closed(target)
    if why:
        warnings.append(f"probe 2 to {target} not sent: {why}")
        return {"status": "robots", "still_transformed": False, "sizes": None}
    time.sleep(PAUSE)
    status, headers, data = probe.fetch(target, f"Mozilla/5.0 (compatible; {agent})", connect_to)
    still = probe.edge(headers) is not None
    if still:
        warnings.append(f"probe 2 to {target} came back still transformed ({probe.edge(headers)})")
    return {"status": status, "still_transformed": still,
            "sizes": markers.inspect(data) if status == "200" and not still and data is not None else None}


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("url")
    ap.add_argument("--contact", required=True, metavar="URL", help="where site owners can read what this robot does and reach its operator")
    args = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", newline="\n")
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        try:
            doc = run(browser, args.url, args.contact)
        except (Refused, BrowserError) as e:
            print(f"survive: {args.url}: {str(e).splitlines()[0]}; left alone", file=sys.stderr)
            return 3
        finally:
            browser.close()
    print(record.canonical(doc))
    return 0


if __name__ == "__main__":
    sys.exit(main())
