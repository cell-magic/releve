#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""Prove that "Export all" writes a real file, and say what is in it.

    python tools/export-proof.py [url]

A screenshot cannot show a download. This launches Chrome with a download
directory, clicks the colophon's export, and prints the file's name, size and
first lines.
"""
import asyncio, json, os, subprocess, sys, tempfile, time, urllib.request

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
PORT = 9341


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
    profile = tempfile.mkdtemp(prefix="export-")
    downloads = tempfile.mkdtemp(prefix="export-out-")
    proc = subprocess.Popen([CHROME, "--headless=new", "--disable-gpu", "--no-first-run",
                             f"--remote-debugging-port={PORT}", f"--user-data-dir={profile}",
                             "about:blank"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
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
            await c.send("Browser.setDownloadBehavior", behavior="allow", downloadPath=downloads,
                         eventsEnabled=True)
            await c.send("Page.navigate", url=url)
            await asyncio.sleep(2.0)

            async def ev(expr):
                res = await c.send("Runtime.evaluate", expression=expr, returnByValue=True)
                if "exceptionDetails" in res:
                    raise RuntimeError(json.dumps(res["exceptionDetails"])[:400])
                return res["result"].get("value")

            clicked = await ev(
                "[...document.querySelectorAll('button')].find(b => b.textContent.trim().toLowerCase() === 'export all').click(), true")
            print("clicked:", clicked)

            found = []
            for _ in range(40):
                found = [f for f in os.listdir(downloads) if not f.endswith(".crdownload")]
                if found:
                    break
                await asyncio.sleep(0.25)

            if not found:
                print("FAIL  no file landed in the download directory")
                return 1

            path = os.path.join(downloads, found[0])
            body = open(path, "rb").read().decode("utf-8")
            lines = [ln for ln in body.split("\r\n") if ln]
            print("PASS  file:", found[0])
            print("PASS  bytes:", len(body.encode("utf-8")), " lines:", len(lines))
            print("PASS  crlf rows:", body.count("\r\n"), " trailing crlf:", body.endswith("\r\n"))
            print("---- first 3 rows ----")
            for ln in lines[:3]:
                print(ln)
            print("---- last row ----")
            print(lines[-1])
            ok = (len(lines) == 10 and lines[0].split(",")[0] == '"number"'
                  and '"locator"' in lines[0] and '"blocking"' in body)
            print(("PASS" if ok else "FAIL") + "  nine findings under one header")

            await ev("[...document.querySelectorAll('.dev-ticket')][0].click(), true")
            ticket = []
            for _ in range(40):
                ticket = [f for f in os.listdir(downloads) if f.endswith('.md')]
                if ticket:
                    break
                await asyncio.sleep(0.25)
            if not ticket:
                print("FAIL  no ticket landed")
                return 1
            md = open(os.path.join(downloads, ticket[0]), encoding="utf-8").read()
            print("PASS  ticket:", ticket[0], "|", len(md), "bytes")
            print(md)
            t_ok = (md.count('## ') == 3 and '## Evidence' in md and '## Remedy' in md
                    and 'where:' in md and ticket[0].endswith('.md'))
            print(("PASS" if t_ok else "FAIL") + "  one defect, with evidence and remedy")
            return 0 if (ok and t_ok) else 1
    finally:
        proc.terminate()


if __name__ == "__main__":
    sys.exit(asyncio.run(main(sys.argv[1] if len(sys.argv) > 1 else "http://localhost:4173/reading/")))
