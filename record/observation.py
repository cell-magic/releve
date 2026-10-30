# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The observation block of a record, frozen in shape: bytes in total and by request; each
request by its origin (scheme and host, nothing more: no port, path, query, cookie or
header), its type, its bytes, its HTTP status, and whether it was sent before any
interaction; the accessibility tree, counted. Built from what observe/observe.py wrote.

Records of relevé 0.10 (a corpus line, `observed`) are read too: what they did not record
(status, the moment of a request, the tree) is None, said so, and never guessed."""
import json, urllib.parse


def origin(url):
    """Scheme and host of an address, lowercase; nothing else of it."""
    p = urllib.parse.urlsplit(url)
    host = (p.hostname or "").lower()
    return f"{p.scheme.lower()}://" + (f"[{host}]" if ":" in host else host)


def block(raw):
    """The observation block, from one line of the observer's output."""
    requests = [{"origin": origin(r["url"]), "type": r["kind"], "bytes": int(r["bytes"]), "status": int(r["status"]),
                 "pre_interaction": bool(r["pre"])} for r in raw["network"]["resources"]]
    ax = raw["page"]["ax"]
    return {"bytes": {"total": sum(q["bytes"] for q in requests)}, "requests": requests,
            "ax": {k: ax[k] for k in ("version", "interactive", "named", "unnamed", "invalid_roles", "context_violations", "hidden_interactive")}}


def from_v1(line):
    """A relevé 0.10 corpus line holding an observation, as an observation block in which what
    was not recorded is None. None for a line that holds something else."""
    event = json.loads(line)["event"]
    raw = event.get("observed")
    if raw is None:
        return None
    requests = [{"origin": origin(r["url"]), "type": r["kind"], "bytes": int(r["bytes"]), "status": r.get("status"),
                 "pre_interaction": r.get("pre")} for r in (raw["network"].get("resources") or [])]
    return {"url": raw["url"], "at": raw["at"],
            "observation": {"bytes": {"total": sum(q["bytes"] for q in requests)}, "requests": requests, "ax": raw["page"].get("ax")},
            "not_recorded": [k for k, missing in (("status", any(q["status"] is None for q in requests)),
                                                    ("pre_interaction", any(q["pre_interaction"] is None for q in requests)),
                                                    ("ax", raw["page"].get("ax") is None)) if missing]}
