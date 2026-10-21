# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""Page selection with a receipt.

Pass 1 commits every page's structural signature, in crawl order; pass 2 picks pages by
farthest-first traversal until the budget is spent or every page is within the stop
radius of a pick. The receipt names the configuration, the chain head, the final state,
every pick and the coverage bound. Anyone holding the same pages in the same order can
replay the run and must obtain the same head; the selector keeps no page.
"""
from . import kcenter as KC
from . import runtime as R
from . import signature as S


def events(pages, url_of=None):
    """Pass-1 events in crawl order, then the pass-2 select event. A page is (url, html) or
    (url, html, content digest as hex) when html is a skeleton of the page."""
    evs = []
    for page in pages:
        url, html = page[0], page[1]
        d = int(page[2], 16) if len(page) > 2 and page[2] else None
        if url_of is not None:
            url_of[S.ref(url)] = url
        evs.append(S.event(url, html, d))
    evs.append(KC.select_event(evs))
    return evs


def run(pages, budget=40, stop_r2=None, every=64):
    """pages: (url, html) in crawl order (see events). Returns (picked urls, receipt, runtime)."""
    cfg = KC.config(budget, stop_r2)
    rt = R.Runtime(cfg, every=every)
    url_of = {}
    for ev in events(pages, url_of):
        rt.poke(ev)
    rec = rt.receipt()
    picked = [url_of[d["ref"]] for d in rec["decisions"]]
    for d in rec["decisions"]:
        d["ref"] = format(d["ref"], "032x")
    rec["sample"] = picked
    return picked, rec, rt


def verify(pages, receipt):
    """Replay pages against a receipt; the budget is read from the receipt."""
    cfg = KC.config(receipt.get("budget", 40))
    return R.verify(receipt, cfg, KC.genesis(), events(pages))
