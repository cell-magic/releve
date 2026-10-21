# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The page selector: a two-pass k-center kernel, a pure transition over one state noun.

Pass 1 (collect):  [%page [ref [digest sig]]]   state [n 0]: counts pages, keeps nothing
Pass 2 (select):   [%select pages]                 pages = the same cells, in crawl order
                   farthest-first traversal (Gonzalez 1985) from the first page:
                   repeatedly pick the page farthest from the current picks, until
                   the budget is spent or every page lies within the stop radius.
                   state [n [k [r2 picks]]]

The chain commits every page twice: once per collect event, once inside the select
event. Each page enters with its URL reference, a digest of its full content and its
structural signature, so the head also binds what the picked pages said. A verifier rebuilds both from the pages, so any edit, swap or omission changes
the head. Nothing about the pages survives selection except the picks and r2.

Coverage bound (named on the receipt). Let r be the covering radius of the k picks
(distance from the farthest page to its nearest pick). The k picks plus that farthest
page are k+1 pages pairwise at least r apart, so any k centres leave some pair in one
cluster: the optimal covering radius r* for k centres satisfies r/2 <= r* <= r.
Equivalently r <= 2 r* (Gonzalez's 2-approximation), certified by this run itself.
When the stop radius ends the run, every page is within it of a pick.

Config:  [budget [stop-r2 0]]  (stop-r2 in Q32.32; default 1/4, a stop radius of 0.5 in
         signature units: pages that close count as the same structure).
Effects: [%pick k ref] per pick, then [%coverage r2 stop]  stop: 0 radius, 1 budget, 2 all pages picked
"""
from . import fx
from . import noun as N

PROTOCOL = "surface-core/select-1"
STOP_RADIUS, STOP_BUDGET, STOP_ALL = 0, 1, 2
STOP_NAMES = {0: "stop radius reached", 1: "budget spent", 2: "every page picked"}
DEFAULT_STOP = fx.q("1/4")


def config(budget=40, stop_r2=None):
    stop = DEFAULT_STOP if stop_r2 is None else stop_r2
    return N.from_list([N.s2a(int(budget)), N.s2a(stop)])


def params(cfg):
    budget, stop = N.to_list(cfg)
    return dict(budget=N.a2s(budget), stop_r2=N.a2s(stop))


def genesis():
    return (0, 0)


def _d2(a, b):
    s = 0
    for x, y in zip(a, b):
        d = x - y
        s += fx.mul(d, d)
    return s


def select(sigs, budget, stop_r2):
    """Farthest-first traversal. Returns (picks, r2, stop). Ties go to the lowest index."""
    n = len(sigs)
    if n == 0 or budget <= 0:
        return [], 0, STOP_BUDGET
    picks = [0]
    d = [_d2(s, sigs[0]) for s in sigs]
    while True:
        i = 0
        for j in range(1, n):
            if d[j] > d[i]:
                i = j
        r2 = d[i]
        if r2 <= stop_r2:
            return picks, r2, STOP_RADIUS
        if len(picks) >= budget:
            return picks, r2, STOP_BUDGET
        if r2 == 0:
            return picks, 0, STOP_ALL
        picks.append(i)
        for j in range(n):
            dj = _d2(sigs[j], sigs[i])
            if dj < d[j]:
                d[j] = dj


def poke(cfg, state, event):
    prm = params(cfg)
    kind, body = event
    k = N.uncord(kind)
    n = N.slot(2, state)
    if k == "page":
        if N.is_cell(N.slot(3, state)):
            raise ValueError("selection already made")
        return [], (n + 1, 0)
    if k == "select":
        pages = N.to_list(body)
        if len(pages) != n or N.is_cell(N.slot(3, state)):
            raise ValueError("select must follow exactly the collected pages")
        refs = [p[0] for p in pages]
        sigs = [[N.a2s(a) for a in N.to_list(p[1][1])] for p in pages]
        picks, r2, stop = select(sigs, prm["budget"], prm["stop_r2"])
        effects = [N.tag("pick", j, refs[i]) for j, i in enumerate(picks)]
        effects.append(N.tag("coverage", N.s2a(r2), stop))
        return effects, (n, (len(picks), (N.s2a(r2), N.from_list(picks))))
    raise ValueError("unknown event")


def select_event(page_events):
    """The pass-2 event built from the pass-1 events (each [%page [ref sig]])."""
    return N.tag("select", N.from_list([ev[1] for ev in page_events]))


def radius_text(r2):
    """sqrt(r2) in signature units, 6 decimals, from integers only (identical everywhere)."""
    r = fx.sqrt(r2)                      # Q32.32
    micro = (r * 1_000_000) >> fx.F
    return f"{micro // 1_000_000}.{micro % 1_000_000:06d}"


def coverage(r2, stop, k, stop_r2):
    return {
        "method": "k-center greedy, farthest-first traversal from the first page (Gonzalez 1985)",
        "picks": k,
        "radius": radius_text(r2),
        "radius2_q32": r2,
        "stop": STOP_NAMES[stop],
        "stop_radius": radius_text(stop_r2),
        "guarantee": "every page lies within `radius` of a pick; for any choice of the same number of "
                     "pages, the best achievable radius r* satisfies radius/2 <= r* <= radius "
                     "(radius <= 2 r*, certified by this run)",
        "optimal_radius_interval": [radius_text(r2 // 4), radius_text(r2)],
    }
