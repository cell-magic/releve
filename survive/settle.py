# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""When the surface counts as settled: Settle(idle=500, quiet=1000, cap=15000), in ms.

  idle   no request of the counted kinds in flight for that long. Counted: Document,
         Stylesheet, Script, Font, Fetch, XHR. Not counted: WebSocket, EventSource, Ping,
         nor images and media, whose bytes are what is measured, not what is waited on.
  quiet  no change to the document's tree (childList, attributes) for that long, seen by a
         MutationObserver that marks the time at most once every THROTTLE ms.
  cap    from the navigation, whatever else: then the surface is taken as it is, and the
         scope says so (capped: true) with the counted requests still in flight
         (active_pollers).

The triple and its outcome go into the scope of every run. This rule governs the surface
alone: probe 2 is a plain fetch with its own timeout (probe.py)."""
import time

IDLE, QUIET, CAP = 500, 1000, 15000
THROTTLE = 100
COUNTED = {"document", "stylesheet", "script", "font", "fetch", "xhr"}
WATCH = """(() => { window.__marked = performance.now(); const t = %d;
  new MutationObserver(() => { const now = performance.now(); if (now - window.__marked >= t) window.__marked = now; })
    .observe(document, { childList: true, attributes: true, subtree: true }); })();""" % THROTTLE


def watch(context):
    """Before any page of the context: the MutationObserver quiet is read from."""
    context.add_init_script(WATCH)


class Flight:
    """The counted requests in flight on a page, and since when none has been."""
    def __init__(self, page):
        self.open, self.since = set(), time.monotonic()
        page.on("request", self.sent)
        page.on("requestfinished", self.done)
        page.on("requestfailed", self.done)

    def sent(self, request):
        if request.resource_type in COUNTED:
            self.open.add(id(request))

    def done(self, request):
        if id(request) in self.open:
            self.open.discard(id(request))
            if not self.open:
                self.since = time.monotonic()


def settle(page, flight, started):
    """Wait for the surface to settle, from `started` (time.monotonic at navigation): the scope's settle block."""
    while True:
        now = time.monotonic()
        if (now - started) * 1000 >= CAP:
            return {"idle": IDLE, "quiet": QUIET, "cap": CAP, "capped": True, "active_pollers": len(flight.open)}
        idle = not flight.open and (now - flight.since) * 1000 >= IDLE
        quiet = idle and page.evaluate("performance.now() - (window.__marked || 0)") >= QUIET
        if idle and quiet:
            return {"idle": IDLE, "quiet": QUIET, "cap": CAP, "capped": False, "active_pollers": 0}
        page.wait_for_timeout(50)
