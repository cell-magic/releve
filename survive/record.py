# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The record of whether provenance markers survive a site's delivery (CONTRACT.md).

Each class of each asset is in one of four states:

  PRESENT               the delivered bytes carry it.
  STRIPPED_AT_DELIVERY  the delivered bytes lack it; the origin, reached by probe 2, has it.
  ABSENT_AT_ORIGIN      the delivered bytes lack it, and so does the origin: only when a
                        probe-2 response arrived, succeeded and was not edge-transformed.
  ORIGIN_UNOBSERVABLE   the delivered bytes lack it, and the origin was not seen: no probe
                        was due, or it was refused, failed, or came back still transformed.

An asset's state is its classes' first by RANK. The body is everything but `observed_at`,
`root` and `signed`; `root` is SHA-256 of the body's RFC 8785 bytes, so two runs of one
surface agree on it whenever they agree on what they saw. Assets are ordered by
normalised absolute address, then state, then role: never by the DOM, a file system or a
map. Integers and text only: no float enters, so the canonical bytes are those of
json.dumps with sorted keys, which RFC 8785 gives for such values."""
import hashlib, json, urllib.parse

from survive.markers import CLASSES

STATES = ("STRIPPED_AT_DELIVERY", "ABSENT_AT_ORIGIN", "ORIGIN_UNOBSERVABLE", "PRESENT")
RANK = {s: i for i, s in enumerate(STATES)}


def normalised(url):
    """An absolute address in one spelling: scheme and host in lowercase, no default port, no fragment, a path."""
    p = urllib.parse.urlsplit(url)
    host = (p.hostname or "").lower()
    host = f"[{host}]" if ":" in host else host
    port = "" if p.port in (None, {"http": 80, "https": 443}.get(p.scheme.lower())) else f":{p.port}"
    return urllib.parse.urlunsplit((p.scheme.lower(), host + port, p.path or "/", p.query, ""))


def class_state(delivered, origin):
    """One class's state, from its delivered size and its origin size (None: the origin was not seen)."""
    if delivered:
        return "PRESENT"
    if origin is None:
        return "ORIGIN_UNOBSERVABLE"
    return "STRIPPED_AT_DELIVERY" if origin else "ABSENT_AT_ORIGIN"


def asset(url, role, delivered, origin, transformer, vector):
    """One asset as the record keeps it. `delivered`, `origin`: {class: bytes}; origin None when unseen."""
    classes = {c: {"delivered": delivered[c], "origin": None if origin is None else origin[c],
                   "state": class_state(delivered[c], None if origin is None else origin[c])} for c in CLASSES}
    return {"url": url, "role": role, "classes": classes, "state": min((v["state"] for v in classes.values()), key=RANK.get),
            "transformer": transformer, "vector": vector}


def ordered(assets):
    return sorted(assets, key=lambda a: (normalised(a["url"]), RANK[a["state"]], a["role"]))


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False)


def document(scope, assets, probes, warnings, observed_at):
    """The record: its body, the time it was observed, its root, and that it is not signed."""
    scope = dict(scope, probes=sorted(scope["probes"]))
    body = {"run_id": hashlib.sha256(canonical(scope).encode("utf-8")).hexdigest(), "scope": scope,
            "assets": ordered(assets),
            "probe2": {"attempted": len(probes), "status": sorted(p["status"] for p in probes),
                       "still_transformed": sum(p["still_transformed"] for p in probes)},
            "warnings": sorted(set(warnings))}
    return dict(body, observed_at=observed_at, root=root(body), signed=False)


def body(doc):
    return {k: v for k, v in doc.items() if k not in ("observed_at", "root", "signed")}


def root(b):
    return hashlib.sha256(canonical(b).encode("utf-8")).hexdigest()


def fixlist(doc, markup=()):
    """What to fix, in rank and nothing else: classes stripped at delivery, then absent at origin, then the
    markup findings given; what could not be measured is listed apart, as unmeasured, never as a fault."""
    rows = [{"url": a["url"], "role": a["role"], "class": c, "state": v["state"]}
            for a in doc["assets"] for c, v in sorted(a["classes"].items())]
    pick = lambda s: [r for r in rows if r["state"] == s]
    return {"ranked": pick("STRIPPED_AT_DELIVERY") + pick("ABSENT_AT_ORIGIN") + [{"markup": m} for m in sorted(markup)],
            "unmeasured": pick("ORIGIN_UNOBSERVABLE")}


def problems(doc):
    """What in a record breaks the contract's absolutes, as sentences; empty if all holds."""
    out = []
    s = doc.get("scope", {}).get("settle", {})
    if set(s) != {"idle", "quiet", "cap", "capped", "active_pollers"} or (s.get("idle"), s.get("quiet"), s.get("cap")) != (500, 1000, 15000):
        out.append("the scope lacks the settle triple (idle 500, quiet 1000, cap 15000) and its outcome")
    if doc.get("assets") != ordered(doc.get("assets", [])):
        out.append("the assets are not in the frozen order")
    for a in doc.get("assets", []):
        for c, v in a["classes"].items():
            if v["state"] == "ABSENT_AT_ORIGIN" and (v["origin"] is None or doc["probe2"]["attempted"] == 0):
                out.append(f"{a['url']}: {c} is ABSENT_AT_ORIGIN without a successful, untransformed probe 2")
            if v["state"] != class_state(v["delivered"], v["origin"]):
                out.append(f"{a['url']}: {c} is {v['state']}, which its sizes do not give")
    if doc.get("root") != root(body(doc)):
        out.append("the root is not the hash of the body")
    return out
