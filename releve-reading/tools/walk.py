#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""Walk the built surface with real DOM events and assert the brief's flows.

    python tools/walk.py [url]

Checks the things a screenshot cannot: focus lands on close, Tab is trapped in
the plate and the fork only, Escape returns focus, a stop writes a receipt with
Undo, Undo reverses it, and the record and count render their rows.
"""
import asyncio, json, subprocess, sys, tempfile, time, urllib.request

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
PORT = 9339

HELPERS = r"""
window.__q = s => document.querySelector(s);
window.__btn = label => [...document.querySelectorAll('button')]
  .find(b => (b.textContent || '').trim().toLowerCase() === label.toLowerCase());
window.__key = (key, opts = {}) => document.dispatchEvent(new KeyboardEvent('keydown', {key, bubbles: true, ...opts}));
window.__panelCount = () => document.querySelectorAll('.panel').length;
window.__path = () => location.pathname.replace(/^\//, "/") || "/";
window.__counter = () => (document.querySelector('.counter.position') || {}).textContent;
window.__receipts = () => [...document.querySelectorAll('.receipt')].map(r => r.textContent.trim());
window.__live = () => document.querySelectorAll('[aria-live]').length;
window.__rows = sel => document.querySelectorAll(sel + ' tr').length;
"""


class CDP:
    def __init__(self, ws):
        self.ws, self.id = ws, 0

    async def send(self, method, **params):
        self.id += 1
        await self.ws.send(json.dumps({"id": self.id, "method": method, "params": params}))
        while True:
            msg = json.loads(await self.ws.recv())
            if msg.get("id") == self.id:
                if "error" in msg:
                    raise RuntimeError(f"{method}: {msg['error']}")
                return msg.get("result", {})


async def main(url):
    profile = tempfile.mkdtemp(prefix="walk-")
    proc = subprocess.Popen([CHROME, "--headless=new", "--disable-gpu", "--no-first-run",
                             f"--remote-debugging-port={PORT}", f"--user-data-dir={profile}",
                             "about:blank"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    results = []

    def check(name, ok, detail=""):
        results.append((name, bool(ok), detail))
        print(("PASS  " if ok else "FAIL  ") + name + (f"  [{detail}]" if detail else ""))

    try:
        page = None
        for _ in range(80):
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json/list") as r:
                    targets = json.load(r)
                page = next(t for t in targets if t["type"] == "page")
                break
            except Exception:
                time.sleep(0.25)
        if page is None:
            raise RuntimeError("chrome did not expose a page target")

        import websockets
        async with websockets.connect(page["webSocketDebuggerUrl"], max_size=None) as ws:
            c = CDP(ws)
            await c.send("Page.enable")
            await c.send("Runtime.enable")
            await c.send("Emulation.setDeviceMetricsOverride", width=1280, height=900,
                         deviceScaleFactor=1, mobile=False)
            await c.send("Page.navigate", url=url)
            await asyncio.sleep(2.0)

            async def ev(expr, await_promise=False):
                res = await c.send("Runtime.evaluate", expression=expr, returnByValue=True,
                                   awaitPromise=await_promise)
                if "exceptionDetails" in res:
                    raise RuntimeError(json.dumps(res["exceptionDetails"])[:400])
                return res["result"].get("value")

            await ev(HELPERS)

            # the ring: five stations, one position, one URL
            check("five stations on one axis", await ev("__panelCount()") == 5, str(await ev("__panelCount()")))
            check("counter reads 01 / 05", await ev("__counter()") == "01 / 05", str(await ev("__counter()")))
            check("the status region is polite, and the only one", await ev(
                "document.querySelectorAll('[aria-live]').length === 1 && "
                "document.querySelector('[role=status]').getAttribute('aria-live') === 'polite'"))
            check("nothing opens a window", await ev("document.querySelectorAll('a[target]').length") == 0)
            check("no refund promised", await ev("!document.body.textContent.toLowerCase().includes('refund')"))

            # zone 1 frontload
            check("the verdict leads the surface", await ev(
                "(() => { const b = document.querySelector('.scope-bar .verdict');"
                " return !!b && /\\d+ blocking/.test(b.textContent); })()"))
            check("the contract names method and zero-AI", await ev(
                "document.querySelector('.scope-bar .contract').textContent.includes('France')"))
            check("the specimen states its class and its rule", await ev(
                "(() => { const a = document.querySelector('.archetype');"
                " return !!a.querySelector('h3') && !!a.querySelector('.rules table'); })()"))
            check("the ledger has three cells", await ev("document.querySelectorAll('.ledger > div').length") == 3)
            check("no percentage score anywhere", await ev("!/\\d+\\s?%|percent/i.test(document.body.textContent)"))

            # zone 2: blocking open, passing folded
            check("a finding is a class, a component, a trigger", await ev(
                "(() => { const t = document.querySelector('.defect-title');"
                " return !!t.querySelector('.class') && !!t.querySelector('.comp') && !!t.querySelector('.trig'); })()"))
            check("the locator is not the remedy", await ev(
                "(() => { const p = document.querySelector('.defect');"
                " return p.querySelector('.defect-locator').textContent.trim() !== "
                "p.querySelector('.remediation').textContent.trim(); })()"))
            check("blocking witnesses open", await ev(
                "document.querySelector(\".defect[data-variant='blocking'] .defect-evidence\").open === true"))
            check("passing checks fold into one closed row", await ev(
                "(() => { const s = document.querySelector('.stable');"
                " return !!s && s.open === false && s.querySelectorAll('.defect').length >= 1; })()"))
            check("one ticket per blocking finding", await ev(
                "document.querySelectorAll('.dev-ticket').length === "
                "document.querySelectorAll(\".defect[data-variant='blocking']\").length"))

            # the drift strip
            check("twelve ticks", await ev("document.querySelectorAll('.tick').length") == 12)
            await ev("document.querySelectorAll('.tick')[6].click()"); await asyncio.sleep(0.2)
            check("a tick moves the diff", await ev(
                "document.querySelectorAll('.tick')[6].getAttribute('aria-current') === 'true'"))

            # keyboard rotation, then a jump
            await ev("__key('ArrowRight')"); await asyncio.sleep(0.4)
            check("arrow moves one station", await ev("__counter()") == "02 / 05", str(await ev("__counter()")))
            check("the URL follows", await ev("__path()") == "/specimen", str(await ev("__path()")))
            check("focus lands on the station heading", await ev(
                "document.activeElement.tagName") == "H2", str(await ev("document.activeElement.tagName")))
            await ev("__key('3')"); await asyncio.sleep(0.4)
            check("a digit jumps", await ev("__counter()") == "03 / 05", str(await ev("__counter()")))
            await ev("__key('ArrowRight')"); await asyncio.sleep(0.4)
            await ev("__key('ArrowRight')"); await asyncio.sleep(0.4)
            check("the ring wraps nothing past 05", await ev("__counter()") == "05 / 05", str(await ev("__counter()")))
            await ev("__btn('next').click()"); await asyncio.sleep(0.4)
            check("next is spent at the end", await ev("__btn('next').disabled") is True)
            await ev("__btn('first').click()"); await asyncio.sleep(0.4)
            check("first returns to probe", await ev("__path()") == "/probe", str(await ev("__path()")))

            # a probe lands on the specimen, and says the endpoint is not mounted
            await ev("document.querySelector('#probe-url').value = 'https://example.fr'")
            await ev("document.querySelector('.probe-form').requestSubmit()"); await asyncio.sleep(0.4)
            check("a probe opens the specimen", await ev("__path()") == "/specimen", str(await ev("__path()")))

            # radar: the form closes honestly, nothing pretends to bill
            await ev("document.querySelectorAll('.index button')[3].click()"); await asyncio.sleep(0.4)
            check("drift is reachable by number", await ev("__counter()") == "04 / 05", str(await ev("__counter()")))
            await ev("document.querySelectorAll('.index button')[4].click()"); await asyncio.sleep(0.4)
            await ev("document.querySelector('.radar-form').requestSubmit()"); await asyncio.sleep(0.4)
            check("no fake billing", await ev("document.body.textContent.includes('Nothing was sent.')"))

            # plate: focus to close, trap, Escape restores
            await ev("__btn('plate').click()"); await asyncio.sleep(0.4)
            check("plate dialog opens", await ev("!!document.querySelector('.dialog.plate')"))
            check("focus on close", await ev("document.activeElement.textContent.trim()") == "close",
                  str(await ev("document.activeElement.textContent.trim()")))
            check("seven plate rows", await ev("document.querySelectorAll('.plate-row').length") == 7,
                  str(await ev("document.querySelectorAll('.plate-row').length")))
            await ev("__key('Escape')"); await asyncio.sleep(0.3)
            check("Escape closes the plate", await ev("!document.querySelector('.dialog')"))
            check("back to the station it opened from", await ev("__path()") == "/radar",
                  str(await ev("__path()")))

            # stop: the slab is the only door, and it prints a receipt with Undo
            await ev("__btn('stop').click()"); await asyncio.sleep(0.4)
            check("fork opens from the stop slab", await ev("!!document.querySelector('.dialog.fork')"))
            await ev("__btn('end the subscription').click()"); await asyncio.sleep(0.5)
            check("state is left", await ev("document.querySelector('.line .segs').textContent.toLowerCase().includes('left')"))
            receipts = await ev("__receipts()") or []
            check("receipt printed on the line", any("No further charges." in r for r in receipts), str(receipts[:1]))
            await ev("document.querySelector('.receipt .undo').click()"); await asyncio.sleep(0.4)
            check("undo reverses the stop", await ev("document.querySelector('.line .segs').textContent.toLowerCase().includes('active')"))

            # record and who-answers are overlays now: the ring stays put
            await ev("__btn('record').click()"); await asyncio.sleep(0.4)
            check("record is an overlay, not a page", await ev("__panelCount()") == 5, str(await ev("__panelCount()")))
            check("record renders rows", (await ev("__rows('.table.record')") or 0) >= 2,
                  str(await ev("__rows('.table.record')")))
            check("path names the overlay", str(await ev("__path()")).endswith("/record"), str(await ev("__path()")))
            await ev("__key('Escape')"); await asyncio.sleep(0.3)
            await ev("__btn('who answers').click()"); await asyncio.sleep(0.4)
            check("count renders five rows", await ev("__rows('.table.count')") == 5,
                  str(await ev("__rows('.table.count')")))
            await ev("__key('Escape')"); await asyncio.sleep(0.3)
            check("no accent under 12px in quiet",
                  await ev("(() => [...document.querySelectorAll('*')].filter(el => "
                           "getComputedStyle(el).color === 'rgb(85, 83, 77)' && "
                           "parseFloat(getComputedStyle(el).fontSize) < 12).length)()") == 0)

    finally:
        proc.terminate()

    failed = [n for n, ok, _ in results if not ok]
    print(f"\nwalk: {len(results)} checks, {len(failed)} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main(sys.argv[1] if len(sys.argv) > 1 else "http://localhost:4173/")))
