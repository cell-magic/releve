#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""Drive headless Chrome over CDP for the reading surface: measure, shoot, print.

  python tools/shoot.py <url> <outdir> [label]

Writes <label>-{wide,narrow,zoom200,dark,light,short}.png and <label>-metrics.json.
Metrics are the acceptance checks from the brief, not decoration: peek clipping,
horizontal overflow, truncated money/date lines, rail heights, band direction.
"""
import asyncio, base64, json, os, subprocess, sys, tempfile, time, urllib.request
from pathlib import Path

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
PORT = 9334

MEASURE = r"""
(() => {
  const q = s => document.querySelector(s);
  const band = q('.band');
  const p0 = band.children[0], p1 = band.children[1];
  const rect = el => { if (!el) return null; const b = el.getBoundingClientRect();
    return {x: Math.round(b.x), y: Math.round(b.y), w: Math.round(b.width), h: Math.round(b.height)}; };
  const numW = el => { const r = document.createRange(); r.selectNodeContents(el);
    return Math.round(r.getBoundingClientRect().width); };
  const o1 = p1.querySelector('.ordinal');
  const bb = band.getBoundingClientRect(), o1r = o1.getBoundingClientRect();
  const clipped = [...document.querySelectorAll('.statement, .body, .line .seg, .line .acts button, .gloss')]
    .filter(e => e.scrollWidth > e.clientWidth + 1)
    .map(e => (e.textContent || '').trim().slice(0, 48));
  return {
    vp: [innerWidth, innerHeight],
    docScrollW: document.documentElement.scrollWidth,
    overflowX: document.documentElement.scrollWidth > innerWidth + 1,
    band: rect(band), bandDir: getComputedStyle(band).flexDirection,
    panel0: rect(p0), panelBasis: getComputedStyle(p0).flexBasis,
    peek: Math.round(bb.width - p0.getBoundingClientRect().width),
    ordinal: rect(p0.querySelector('.ordinal')),
    ordinalNumeralW: numW(p0.querySelector('.ordinal')),
    ordinalFont: getComputedStyle(p0.querySelector('.ordinal')).fontSize,
    peekOrdinalVisible: Math.round(Math.max(0, Math.min(o1r.right, bb.right) - Math.max(o1r.left, bb.left))),
    peekOrdinalClippedPx: Math.round(Math.max(0, o1r.right - bb.right)),
    panels: band.children.length,
    panelScrollOverflow: [...band.children].map(p => Math.round(p.scrollHeight - p.clientHeight)),
    gloss: {h: rect(q('.gloss')).h, text: q('.gloss').textContent.trim(),
            clipped: q('.gloss').scrollWidth > q('.gloss').clientWidth + 1},
    line: {h: rect(q('.line')).h, scrollW: q('.line').scrollWidth, clientW: q('.line').clientWidth},
    rail: {h: rect(q('.rail')).h, scrollW: q('.rail').scrollWidth, clientW: q('.rail').clientWidth},
    truncated: clipped,
    bodyFont: getComputedStyle(document.body).fontFamily.slice(0, 32),
    bodySize: getComputedStyle(document.body).fontSize,
    stop: (() => {
      const s = document.querySelector('.stop');
      if (!s) return 'missing';
      const c = getComputedStyle(s);
      const r = s.getBoundingClientRect();
      return {bg: c.backgroundColor, fg: c.color, w: Math.round(r.width), h: Math.round(r.height),
              cls: s.className};
    })(),
    cost: (() => {
      const s = document.querySelector('.tone-cost');
      return s ? getComputedStyle(s).color : 'missing';
    })(),
    twoPx: [...document.querySelectorAll('*')]
      .filter(el => ['Top', 'Right', 'Bottom', 'Left']
        .some(k => parseFloat(getComputedStyle(el)['border' + k + 'Width']) === 2))
      .map(el => el.className || el.tagName),
    marginCol: (() => {
      const m = document.querySelector('.margin-col');
      if (!m) return 'missing';
      const c = getComputedStyle(m);
      const r = m.getBoundingClientRect();
      return {display: c.display, w: Math.round(r.width), left: Math.round(r.left)};
    })(),
    inlineGloss: (() => {
      const g = document.querySelector('.gloss-src');
      if (!g) return 'missing';
      const c = getComputedStyle(g);
      return {position: c.position, fontSize: c.fontSize, color: c.color};
    })(),
    railDisplay: getComputedStyle(q('.rail')).display,
    dirDisplay: getComputedStyle(q('.rail .dir')).display
  };
})()
"""


class CDP:
    def __init__(self, ws):
        self.ws = ws
        self.id = 0

    async def send(self, method, **params):
        self.id += 1
        await self.ws.send(json.dumps({"id": self.id, "method": method, "params": params}))
        while True:
            msg = json.loads(await self.ws.recv())
            if msg.get("id") == self.id:
                if "error" in msg:
                    raise RuntimeError(f"{method}: {msg['error']}")
                return msg.get("result", {})


async def main(url, outdir, label):
    out = Path(outdir)
    out.mkdir(parents=True, exist_ok=True)
    profile = tempfile.mkdtemp(prefix="cdp-reading-")
    proc = subprocess.Popen(
        [CHROME, "--headless=new", "--disable-gpu", "--no-first-run",
         f"--remote-debugging-port={PORT}", f"--user-data-dir={profile}",
         "--hide-scrollbars", "about:blank"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for _ in range(80):
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json/list") as r:
                    targets = json.load(r)
                page = next(t for t in targets if t["type"] == "page")
                break
            except Exception:
                time.sleep(0.25)
        else:
            raise RuntimeError("chrome did not expose a page target")

        import websockets
        async with websockets.connect(page["webSocketDebuggerUrl"], max_size=None) as ws:
            c = CDP(ws)
            await c.send("Page.enable")
            await c.send("Runtime.enable")
            await c.send("Emulation.setDeviceMetricsOverride", width=1440, height=900,
                         deviceScaleFactor=1, mobile=False)
            await c.send("Page.navigate", url=url)
            await asyncio.sleep(2.0)

            async def measure(tag, w, h, mobile=False, scale=1):
                await c.send("Emulation.setDeviceMetricsOverride", width=w, height=h,
                             deviceScaleFactor=scale, mobile=mobile)
                await asyncio.sleep(0.6)
                res = await c.send("Runtime.evaluate", expression=MEASURE, returnByValue=True)
                m = res["result"]["value"]
                print(f"--- {tag} {w}x{h}", json.dumps(m))
                return m

            async def shot(name):
                r = await c.send("Page.captureScreenshot", format="png", captureBeyondViewport=False)
                path = out / f"{label}-{name}.png"
                path.write_bytes(base64.b64decode(r["data"]))
                print("wrote", path)

            results = {}
            await c.send("Emulation.setEmulatedMedia",
                         features=[{"name": "prefers-color-scheme", "value": "light"}])
            results["wide"] = await measure("wide", 1440, 900)
            await shot("wide")
            results["narrow"] = await measure("narrow", 390, 844, mobile=True)
            await shot("narrow")
            results["tight"] = await measure("tight", 401, 844, mobile=True)
            results["w1100"] = await measure("w1100", 1100, 900)
            await shot("w1100")
            results["w1200"] = await measure("w1200", 1200, 900)
            results["zoom200"] = await measure("zoom200", 720, 900, mobile=False, scale=2)
            await shot("zoom200")
            results["short"] = await measure("short", 320, 256, mobile=True)
            await shot("short")
            await c.send("Runtime.evaluate", expression=(
                "(() => { const g = document.querySelector('.gloss-src');"
                " g.scrollIntoView({block: 'center'}); return g.getBoundingClientRect().top; })()"))
            await asyncio.sleep(0.5)
            await shot("short-gloss")

            await c.send("Emulation.setEmulatedMedia",
                         features=[{"name": "prefers-color-scheme", "value": "dark"}])
            results["dark"] = await measure("dark", 1440, 900)
            await shot("dark")
            await c.send("Emulation.setEmulatedMedia",
                         features=[{"name": "prefers-color-scheme", "value": "light"}])
            results["light"] = results["wide"]

            # panel 03 snapped: does the peek still read?
            await c.send("Emulation.setDeviceMetricsOverride", width=390, height=844,
                         deviceScaleFactor=1, mobile=True)
            await c.send("Runtime.evaluate", expression=(
                "(() => { const b = document.querySelector('.band');"
                " b.scrollLeft = b.children[2].offsetLeft; return b.scrollLeft; })()"))
            await asyncio.sleep(0.8)
            res = await c.send("Runtime.evaluate", expression=MEASURE, returnByValue=True)
            results["panel3"] = res["result"]["value"]
            print("--- panel3", json.dumps(results["panel3"]))
            await shot("panel3")

            # the four surfaces that are not the strip: plate, fork, record, count
            await c.send("Emulation.setDeviceMetricsOverride", width=1440, height=900,
                         deviceScaleFactor=1, mobile=False)
            base = url.rstrip("/")
            for route, name in (("/plate/1", "plate"), ("/stop/1", "fork"),
                                ("/record", "record"), ("/help", "help")):
                await c.send("Page.navigate", url=base + route)
                await asyncio.sleep(1.4)
                await shot(name)

            await c.send("Page.navigate", url=base + "/plate/1")
            await asyncio.sleep(1.2)
            await c.send("Emulation.setEmulatedMedia",
                         features=[{"name": "prefers-color-scheme", "value": "dark"}])
            await asyncio.sleep(0.4)
            await shot("plate-dark")
            await c.send("Emulation.setEmulatedMedia",
                         features=[{"name": "prefers-color-scheme", "value": "light"}])
            await c.send("Page.navigate", url=base + "/read/1")
            await asyncio.sleep(0.8)

            (out / f"{label}-metrics.json").write_text(
                json.dumps(results, indent=2), encoding="utf-8")
            print("wrote", out / f"{label}-metrics.json")
    finally:
        proc.terminate()


if __name__ == "__main__":
    url = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:4173/"
    outdir = sys.argv[2] if len(sys.argv) > 2 else "shots"
    label = sys.argv[3] if len(sys.argv) > 3 else "reading"
    asyncio.run(main(url, outdir, label))
