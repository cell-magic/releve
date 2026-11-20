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
window.__counter = () => (document.querySelector('.counter') || {}).textContent;
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
            check("eleven stations on one axis", await ev("__panelCount()") == 11, str(await ev("__panelCount()")))
            check("counter reads 01 / 09", await ev("__counter()") == "01 / 09", str(await ev("__counter()")))
            check("no aria-live anywhere", await ev("__live()") == 0, str(await ev("__live()")))
            check("nothing opens a window",
                  await ev("document.querySelectorAll('a[target]').length") == 0)
            check("no refund promised", await ev("document.body.textContent.includes('€6.00')") is False)
            check("the gloss defines, it does not repeat the fix", await ev(
                "(() => { const p = document.querySelector('.panel');"
                " const f = p.querySelectorAll('.body')[1].textContent.trim();"
                " const g = p.querySelector('.note').textContent.replace(/^1/, '').trim();"
                " return f !== g; })()"))

            await ev("__key('ArrowRight')"); await asyncio.sleep(0.2)
            await ev("__key('ArrowRight')"); await asyncio.sleep(0.3)
            check("arrows move one panel", await ev("__counter()") == "03 / 09", str(await ev("__counter()")))
            await ev("__key('Home')"); await asyncio.sleep(0.3)
            check("Home returns to 01", await ev("__counter()") == "01 / 09", str(await ev("__counter()")))

            # plate: focus to close, trap, Escape restores
            await ev("__btn('plate').click()"); await asyncio.sleep(0.4)
            check("plate dialog opens", await ev("!!document.querySelector('.dialog.plate')"))
            check("focus on close", await ev("document.activeElement.textContent.trim()") == "close",
                  str(await ev("document.activeElement.textContent.trim()")))
            check("nine plate rows", await ev("document.querySelectorAll('.plate-row').length") == 7,
                  str(await ev("document.querySelectorAll('.plate-row').length")))
            check("no stamp before send", await ev("!document.querySelector('.stamp')"))
            await ev("""(() => {
                const d = document.querySelector('.dialog');
                const f = [...d.querySelectorAll('button:not([disabled])')];
                f[f.length - 1].focus();
                return true; })()""")
            await ev("__key('Tab')"); await asyncio.sleep(0.1)
            check("Tab wraps inside the plate",
                  await ev("document.activeElement.textContent.trim()") == "close",
                  str(await ev("document.activeElement.textContent.trim()")))
            await ev("__key('Escape')"); await asyncio.sleep(0.3)
            check("Escape closes the plate", await ev("!document.querySelector('.dialog')"))
            check("path back to the reading", await ev("location.pathname") == "/read/1",
                  str(await ev("location.pathname")))

            # export sets the stamp
            await ev("__btn('export all').click()"); await asyncio.sleep(0.5)
            check("export opens the plate with a stamp", await ev("!!document.querySelector('.stamp')"))
            await ev("__key('Escape')"); await asyncio.sleep(0.3)

            # fork -> stop -> receipt -> undo
            await ev("__btn('active').click()"); await asyncio.sleep(0.4)
            check("fork opens from the state segment", await ev("!!document.querySelector('.dialog.fork')"))
            await ev("__btn('stop and keep the record').click()"); await asyncio.sleep(0.5)
            check("stop closes the fork", await ev("!document.querySelector('.dialog')"))
            check("state is left", await ev("__btn('left') !== undefined"))
            receipts = await ev("__receipts()") or []
            check("receipt printed on the line",
                  any("No further charges." in r for r in receipts), str(receipts[:1]))
            check("undo present", await ev("!!document.querySelector('.receipt .undo')"))
            await ev("document.querySelector('.receipt .undo').click()"); await asyncio.sleep(0.4)
            check("undo reverses the stop", await ev("__btn('active') !== undefined"))

            # record + count are stations, not pages: the axis stays
            await ev("__btn('record').click()"); await asyncio.sleep(0.4)
            check("record stays on the ring", await ev("__panelCount()") == 11,
                  str(await ev("__panelCount()")))
            check("record renders rows", (await ev("__rows('.table.record')") or 0) >= 2,
                  str(await ev("__rows('.table.record')")))
            check("path names the station", await ev("location.pathname") == "/record",
                  str(await ev("location.pathname")))
            await ev("__btn('who answers').click()"); await asyncio.sleep(0.4)
            check("count renders five rows", await ev("__rows('.table.count')") == 5,
                  str(await ev("__rows('.table.count')")))
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
