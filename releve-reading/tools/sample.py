#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""Print the dominant colours of an image, sampled in 3-bit buckets.

    python tools/sample.py shots/reading-light.png [more.png ...]

Chrome is the only image decoder guaranteed on this host, so the image is loaded
over CDP and read back through a canvas. Buckets are coarse (8 levels per channel)
because the question is "is that cream or white", not "which exact pixel".
"""
import asyncio, json, subprocess, sys, tempfile, time, urllib.request
from pathlib import Path

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
PORT = 9338
JS = r"""(() => {
  const img = document.querySelector('img');
  const c = document.createElement('canvas');
  c.width = img.naturalWidth; c.height = img.naturalHeight;
  const x = c.getContext('2d'); x.drawImage(img, 0, 0);
  const d = x.getImageData(0, 0, c.width, c.height).data;
  const counts = new Map();
  for (let i = 0; i < d.length; i += 4) {
    const k = ((d[i] >> 3) << 10) | ((d[i+1] >> 3) << 5) | (d[i+2] >> 3);
    counts.set(k, (counts.get(k) || 0) + 1);
  }
  const hex = k => '#' + [((k>>10)&31)<<3, ((k>>5)&31)<<3, (k&31)<<3].map(v => v.toString(16).padStart(2,'0')).join('');
  return [...counts.entries()].sort((a,b) => b[1]-a[1]).slice(0, 4)
    .map(([k,n]) => ({hex: hex(k), pct: +(100*n/(d.length/4)).toFixed(1)}));
})()"""


async def main(paths):
    profile = tempfile.mkdtemp(prefix="sample-")
    proc = subprocess.Popen([CHROME, "--headless=new", "--disable-gpu", "--allow-file-access-from-files",
                             f"--remote-debugging-port={PORT}", f"--user-data-dir={profile}", "about:blank"],
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
        import websockets
        async with websockets.connect(page["webSocketDebuggerUrl"], max_size=None) as ws:
            counter = 0

            async def send(method, **params):
                nonlocal counter
                counter += 1
                await ws.send(json.dumps({"id": counter, "method": method, "params": params}))
                while True:
                    msg = json.loads(await ws.recv())
                    if msg.get("id") == counter:
                        return msg.get("result", {})

            await send("Page.enable")
            for p in paths:
                await send("Page.navigate", url=Path(p).resolve().as_uri())
                await asyncio.sleep(1.2)
                res = await send("Runtime.evaluate", expression=JS, returnByValue=True)
                print(f"{p}: {json.dumps(res['result']['value'])}")
    finally:
        proc.terminate()


if __name__ == "__main__":
    asyncio.run(main(sys.argv[1:] or ["shots/reading-light.png"]))
