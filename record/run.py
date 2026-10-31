# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""One site's run in one cycle, as the instrument makes it: the records of the pages picked.

  1. The candidate pages, each written in its one way, are committed to (SHA-256 of their
     canonical list) and the commitment dated by a time-stamping authority (RFC 3161),
     before the cycle begins.
  2. The beacon round taken is the cycle's: the first one after the cycle begins
     (releve-draw/1, record/Seed.plie), whatever the moment of the commitment; its
     randomness gives the order the candidates are read in.
  3. The candidates are observed in that order, by the observer and under its conduct;
     the owner's mandate, when granted, opens what robots.txt closes, on that site alone.
  4. The selector (receipt/, surface-core/select-1) picks pages from what was observed.
  5. Each picked page becomes a record: its observation, the rules' results (releve rules),
     its readings, its selection and beacon, its mandate, its place in the site's chain.

Nothing is kept here: the records are returned, with the pages as served for whoever asked."""
import json, subprocess, sys, time, urllib.parse
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path[:0] = [str(ROOT / "observe"), str(ROOT)]
import observe as observer  # noqa: E402
from receipt import sampler  # noqa: E402
from record import SCHEMA, beacon, core, observation, psl, schema, tsa  # noqa: E402

UNSEEDED = {"en": "selection not beacon-seeded", "fr": "sélection non tirée d'une balise publique"}
MANDATED = {"en": "observed under the owner's mandate", "fr": "observé sous mandat du propriétaire"}
ENERGY = json.loads((Path(__file__).with_name("data") / "energy.json").read_text(encoding="utf-8"))


class Unsigned(Exception):
    """A beacon round whose signature does not hold: nothing is drawn from it."""


class Late(Exception):
    """A commitment dated once its cycle has begun: the cycle's round may be known, so nothing is drawn."""


def release():
    out = subprocess.run([core.releve(), "--version"], capture_output=True, text=True).stdout.split()
    return out[1], out[-1].lstrip("v")  # "releve 0.11.0 · criteria v10"


def rules_of(raws):
    out = subprocess.run([core.releve(), "rules", "-"], input="\n".join(json.dumps(r) for r in raws).encode("utf-8"),
                         capture_output=True, check=True).stdout.decode("utf-8").splitlines()
    return [json.loads(l)["rules"] for l in out]


def drawn(cycle, recorded=None):
    """The beacon block of a cycle's records: its round (releve-draw/1), checked; or the statement that
    there is none. `recorded`: rounds already published, by number, for a run that replays them."""
    r = core.call("drawOf", {"cycle": cycle})["round"]
    got = (recorded or {}).get(r) if recorded is not None else beacon.fetch(r)
    if got is None:
        return {"status": "unavailable", "statement": UNSEEDED, "tried": len(beacon.RELAYS)}
    if beacon.bls(r, got["signature"]) is False:
        raise Unsigned(f"round {r} is not signed by the beacon's key")
    return {"chain": beacon.trusted()[0], "round": r, "randomness": got["randomness"], "signature": got["signature"]}


def site_of(url):
    """A site, as the store names it: scheme and host, with the port if one is given."""
    p = urllib.parse.urlsplit(url)
    return f"{p.scheme.lower()}://{p.netloc.lower()}"


def run(site, cycle, candidates, budget, browser, *, contact, last=None, reset=False, mandate=None, seen_from=None,
        tsa_url=tsa.DEFAULT, recorded=None, today=None):
    """The records of one site in one cycle, in the order picked, and the pages as served (url, html), in the order read.
    last: what is kept of the site's last record, {"hash", "baseline"}, or None; mandate: {"granted": bool, "date"} or None."""
    committed = core.call("commitmentOf", {"candidates": candidates})
    if committed["refused"]:
        raise ValueError("candidates not written in their one way (record/Seed.plie, canonicalUrl): " + ", ".join(committed["refused"][:5]))
    token = tsa.stamp(committed["commitment"], tsa_url)
    when = tsa.time_of(token)
    start = core.call("drawOf", {"cycle": cycle})["start"]
    if not 0 <= when < start:
        raise Late(f"the commitment is dated {when}, not before cycle {cycle} begins ({start}): its round may already be known")
    block = drawn(cycle, recorded)
    seeded = "round" in block
    order = core.call("orderOf", {"randomness": block.get("randomness", ""), "site": site, "cycle": cycle,
                                  "candidates": committed["candidates"]})
    reading = order["order"] if seeded else committed["candidates"]
    agent = f"{observer.AGENT}; +{contact}"
    granted = bool(mandate and mandate.get("granted"))
    rules, paced = {}, 0.0

    def closed(url):
        """Why the robot may not go to an address, or None: robots.txt, unless the owner's mandate covers its site."""
        where = observer.place(url)
        if where is None:
            return "not a web address"
        if granted and site_of(url) == site:
            return None
        if where[0] not in rules:
            rules[where[0]] = observer.robots(where[0], agent)
        if rules[where[0]] is None:
            return "robots.txt unreachable"
        return None if rules[where[0]].can_fetch(observer.AGENT, url) else "robots.txt refuses"

    seen = []
    for url in reading:
        if closed(url):
            continue
        time.sleep(max(0, observer.PAUSE - (time.monotonic() - paced)))
        try:
            raw, html = observer.observe(browser, url, agent, None, closed)
        except Exception:  # a page left alone, or that fails to load, is not read; `read` says which were
            continue
        finally:
            paced = time.monotonic()
        if granted:
            raw["mandate"] = f"owner's mandate of {mandate['date']}"
        if seen_from:
            raw["from"] = seen_from
        seen.append((raw, html))
    if not seen:
        return [], []
    picked, receipt, _ = sampler.run([(r["url"], h) for r, h in seen], budget)
    raws = {r["url"]: r for r, _ in seen}
    chosen = [raws[u] for u in picked]
    results = rules_of(chosen)
    rel, criteria = release()
    lists = psl.load()
    selection = {"protocol": "surface-core/select-1", "order_rule": "releve-order/1", "draw_rule": "releve-draw/1",
                 "candidates": committed["candidates"],
                 "commitment": {"hash": committed["commitment"], "time": when, "tsa": tsa_url, "token": token.hex()},
                 "budget": budget, "seed": order["seed"] if seeded else None, "order": reading,
                 "read": [r["url"] for r, _ in seen], "picks": picked,
                 "receipt": receipt["head"]}
    day = today or datetime.now(timezone.utc).date().isoformat()
    records = []
    for raw, result in zip(chosen, results):
        obs = observation.block(raw)
        record = {"schema": SCHEMA, "site": site, "cycle": cycle, "url": raw["url"], "requested": raw["requested"], "at": raw["at"],
                  "agent": raw["agent"], "browser": raw["browser"], "release": rel, "criteria": criteria,
                  **({"from": seen_from} if seen_from else {}),
                  "observation": obs, "rules": result,
                  "readings": core.call("readingsOf", {"observation": obs, "rules": result, "site": site, "psl": lists, "energy": ENERGY}),
                  "selection": selection, "beacon": block,
                  "mandate": {"granted": True, "date": mandate["date"], "statement": MANDATED} if granted else {"granted": False},
                  **core.call("chainNext", {"last": last, "date": day, "reset": reset})}
        wrong = schema.problems(record)
        if wrong:
            raise ValueError("the record does not hold to its schema: " + "; ".join(wrong[:5]))
        records.append(record)
        last, reset = {"hash": core.canonical(record)[1], "baseline": record["baseline"]}, False
    return records, [(r["url"], h) for r, h in seen]
