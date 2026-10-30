#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The RADAR record, checked without a browser: its schema, its canonical bytes (RFC 8785),
its readings and their recomputation, its chain, the month's tree (RFC 6962), the published
roots, the beacon and the order it gives, the commitment dated before the round, and the
verifier, on a record made whole from a recorded page; then each piece tampered with, and
the verifier failing at the check that names it. Needs releve (RELEVE), OpenSSL, faketime,
and py_ecc for the BLS check. No network: the authority is the tests' own, its clock set
before the recorded round of drand quicknet (tests/beacon/), the only round it may take."""
import copy, hashlib, json, os, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path[:0] = [str(ROOT), str(ROOT / "tests")]
from authority import authority  # noqa: E402
from receipt import sampler  # noqa: E402
from record import beacon, core, observation, psl, schema, tsa, verify  # noqa: E402
from record.cli import recompute  # noqa: E402
from record.run import ENERGY, MANDATED, drawn, rules_of  # noqa: E402

checks = []
ROUND = json.loads((ROOT / "tests" / "beacon" / "quicknet-12040883.json").read_text())
H = lambda b: hashlib.sha256(b).digest()


def check(name, ok, detail=""):
    checks.append(bool(ok))
    print(("ok    " if ok else "FAIL  ") + name + ("" if ok or not detail else f"\n      {detail}"))


def rfc6962(ls):
    if not ls:
        return H(b"")
    if len(ls) == 1:
        return H(b"\0" + ls[0])
    k = 1
    while k * 2 < len(ls):
        k *= 2
    return H(b"\1" + rfc6962(ls[:k]) + rfc6962(ls[k:]))


def raw_page():
    """A recorded page's observation, with what observer 0.6 adds: each request's status and moment, the tree's counts."""
    raw = json.loads((ROOT / "tests" / "observations" / "page.jsonl").read_text().splitlines()[0])
    for i, r in enumerate(raw["network"]["resources"]):
        r.update(status=200, pre=i < 2)
        r["url"] = r["url"] + "?session=SECRET#x"  # a query must never reach the record
    raw["page"]["ax"] = {"version": "aria-1.2", "interactive": 6, "named": 4, "unnamed": 2, "invalid_roles": 1,
                         "context_violations": 0, "hidden_interactive": 1}
    return raw


def main():
    tmp = Path(tempfile.mkdtemp())
    os.environ["RELEVE_CA"] = str(authority(tmp / "tsa", 8768, clock="@2024-10-14 17:13:30"))
    url = "http://127.0.0.1:8768"

    # ---- canonical bytes
    rfc = {"€": "Euro Sign", "\r": "Carriage Return", "דּ": "Hebrew Letter Dalet With Dagesh", "1": "One",
           "\U0001f600": "Emoji: Grinning Face", "\u0080": "Control", "ö": "Latin Small Letter O With Diaeresis"}
    text, _ = core.canonical(rfc)
    check("canonical keys in RFC 8785's order (its 3.2.3 example)",
          [k for k in json.loads(text)] == ["\r", "1", "\u0080", "ö", "€", "\U0001f600", "דּ"])
    check("canonical text has no whitespace, and the same value gives the same bytes",
          core.canonical({"b": [1, None, True], "a": "é"})[0] == '{"a":"é","b":[1,null,true]}' == core.canonical({"a": "é", "b": [1, None, True]})[0])

    # ---- the tree
    ok = True
    for n in (0, 1, 2, 3, 4, 5, 6, 7, 9, 16, 17, 31):
        leaves = [H(bytes([n, i])) for i in range(n)]
        out = core.call("merkleBatch", {"leaves": [x.hex() for x in leaves]})
        ok &= out["root"] == rfc6962(sorted(leaves)).hex()
        for x in leaves:
            acc = H(b"\0" + x)
            for s in out["paths"][x.hex()]:
                acc = H(b"\1" + bytes.fromhex(s["left"]) + acc) if "left" in s else H(b"\1" + acc + bytes.fromhex(s["right"]))
            ok &= acc.hex() == out["root"]
    check("the month's root is RFC 6962's over the sorted leaves, and every path leads to it (0 to 31 leaves)", ok)

    # ---- a record made whole
    raw = raw_page()
    html = (ROOT / "tests" / "pages" / "page.html").read_text(encoding="utf-8")
    site = observation.origin(raw["url"])
    candidates = [raw["url"], site + "/b", site + "/a"]
    committed = core.call("commitmentOf", {"candidates": candidates})
    token = tsa.stamp(committed["commitment"], url)
    when = tsa.time_of(token)
    block = drawn(when, {ROUND["round"]: ROUND})
    check("the round taken is the first after the commitment's date", block.get("round") == ROUND["round"] == beacon.first_after(when))
    check("its BLS signature holds under quicknet's key", beacon.bls(block["round"], block["signature"]) is True)
    check("a signature moved to another round does not", beacon.bls(block["round"] + 1, block["signature"]) is False)
    order = core.call("orderOf", {"randomness": block["randomness"], "site": site, "cycle": "2024-10", "candidates": committed["candidates"]})
    again = core.call("orderOf", {"randomness": block["randomness"], "site": site, "cycle": "2024-10", "candidates": list(reversed(candidates))})
    other = core.call("orderOf", {"randomness": block["randomness"], "site": site, "cycle": "2024-11", "candidates": candidates})
    check("the order is the round's, whatever order the candidates came in", order == again)
    check("another cycle draws another seed", other["seed"] != order["seed"])
    pages = [(u, html if u == raw["url"] else html.replace("<main", "<main><nav>x</nav><table><tr><td>x</td></tr></table")) for u in order["order"]]
    picked, receipt, _ = sampler.run(pages, 1)
    rules = rules_of([raw])[0]
    obs = observation.block(raw)
    check("an observation keeps scheme and host of each request, never its path or query",
          all(q["origin"] == site for q in obs["requests"]) and "SECRET" not in json.dumps(obs) and "session" not in json.dumps(obs))
    check("the rule results carry machine labels only", all(set(r) == {"criterion", "wcag", "fail", "review", "hint"} for r in rules))
    lists = psl.load()
    readings = core.call("readingsOf", {"observation": obs, "rules": rules, "site": site, "psl": lists, "energy": ENERGY})
    wcag = next(r for r in readings if r["name"] == "wcag")["value"]
    check("the WCAG reading labels criteria fail, review or hint, and gives no share",
          {w["label"] for w in wcag} <= {"fail", "review", "hint", None} and "%" not in json.dumps(wcag) and "coverage" not in json.dumps(wcag))
    record = {"schema": "releve-record/2", "site": site, "cycle": "2024-10", "url": raw["url"], "requested": raw["requested"], "at": raw["at"],
              "agent": raw["agent"], "browser": raw["browser"], "release": "0.11.0", "criteria": "10", "from": "CH",
              "observation": obs, "rules": rules, "readings": readings,
              "selection": {"protocol": "surface-core/select-1", "order_rule": "releve-order/1", "candidates": committed["candidates"],
                            "commitment": {"hash": committed["commitment"], "time": when, "tsa": url, "token": token.hex()},
                            "budget": 1, "seed": order["seed"], "order": order["order"], "read": order["order"], "picks": picked,
                            "receipt": receipt["head"]},
              "beacon": block, "mandate": {"granted": True, "date": "2024-10-01", "statement": MANDATED},
              **core.call("chainNext", {"last": None, "date": "2024-10-14", "reset": False})}
    record["url"] = picked[0]
    check("the record holds to its schema", not schema.problems(record), schema.problems(record))
    check("a field the schema does not name is refused", schema.problems({**record, "cookie": "x"}))
    check("a request with a path is refused by the schema",
          schema.problems({**record, "observation": {**obs, "requests": [{**obs["requests"][0], "origin": site + "/x?y"}]}}))
    same, size, _, _ = recompute(record)
    check(f"recompute rebuilds the readings byte for byte ({size} bytes)", same)
    moved = copy.deepcopy(record)
    moved["observation"]["requests"][0]["bytes"] += 1
    check("recompute sees a reading that no longer follows from its observation", not recompute(moved)[0])

    # ---- the month: two records of the site, chained, and a record of another site
    _, h1 = core.canonical(record)
    second = {**copy.deepcopy(record), **core.call("chainNext", {"last": {"hash": h1, "baseline": record["baseline"]}, "date": "2024-11-14"}),
              "cycle": "2024-10"}
    _, h2 = core.canonical(second)
    stranger = {**copy.deepcopy(record), "site": "http://example.test", **core.call("chainNext", {"last": None, "date": "2024-10-14"})}
    _, h3 = core.canonical(stranger)
    batch = core.call("merkleBatch", {"leaves": [h1, h2, h3]})
    root_token = tsa.stamp(batch["root"], url)
    roots = core.call("rootsAppend", {"roots": [], "cycle": "2024-09", "root": "00" * 32, "token_hash": "11" * 32})
    roots = core.call("rootsAppend", {"roots": roots["entries"], "cycle": "2024-10", "root": batch["root"],
                                      "token_hash": hashlib.sha256(root_token).hexdigest()})
    bundle = lambda r, h: {"format": "releve-bundle/1", "record": r, "record_hash": h, "cycle": "2024-10", "root": batch["root"],
                           "path": batch["paths"][h], "token": root_token.hex()}
    b1, b2 = bundle(record, h1), bundle(second, h2)
    names = lambda cs: [c[0] for c in cs]
    cs, ok = verify.verify(b2, roots, previous=record)
    verify.show(cs)
    check("the verifier passes a record whole, every check named", ok and names(cs) == ["schema", "record-hash", "prev-link", "inclusion-path", "root",
          "published", "tsa-token", "beacon-round", "beacon-signature", "order", "committed", "before-beacon"])
    cs, ok = verify.verify(b1, roots)
    check("the first record of a chain passes without a previous one", ok)
    cs, ok = verify.verify(b2, roots)
    check("a record that names a previous one, given none, says the link is not checked", dict((c[0], c[1]) for c in cs)["prev-link"] is None and not ok)

    def fails_at(name, b, rs=roots, previous=record, want=None):
        cs, ok = verify.verify(b, rs, previous)
        failed = [c[0] for c in cs if c[1] is False]
        check(f"tampered {name}: fails at {want}", not ok and failed[:1] == [want], f"failed: {failed}")

    t = copy.deepcopy(b2)
    t["record"]["observation"]["bytes"]["total"] += 1  # one byte of the record
    fails_at("record (one value)", t, want="record-hash")
    t = copy.deepcopy(b2)
    step = t["path"][0]
    side = "left" if "left" in step else "right"
    step[side] = step[side][:-1] + ("0" if step[side][-1] != "0" else "1")  # one hex digit of the path
    fails_at("path (one digit)", t, want="inclusion-path")
    rs = copy.deepcopy(roots)
    rs["entries"][0]["root"] = "01" + "00" * 31  # one byte of an earlier entry
    fails_at("roots list (an earlier entry)", b2, rs, want="published")
    rs = copy.deepcopy(roots)
    rs["entries"][1]["root"] = rs["entries"][1]["root"][:-1] + "0"
    fails_at("roots list (the month's root)", b2, rs, want="published")
    t = copy.deepcopy(b2)
    t["token"] = t["token"][:-2] + ("00" if t["token"][-2:] != "00" else "01")
    fails_at("root token", t, want="published")
    fails_at("previous record", b2, previous={**record, "baseline": "2024-09-01"}, want="prev-link")
    # the selection, tampered and hashed again, so that only the selection's own checks can see it
    def resealed(change):
        r = copy.deepcopy(second)
        change(r)
        _, h = core.canonical(r)
        b = core.call("merkleBatch", {"leaves": [h1, h, h3]})
        tok = tsa.stamp(b["root"], url)
        rs = core.call("rootsAppend", {"roots": roots["entries"][:1], "cycle": "2024-10", "root": b["root"], "token_hash": hashlib.sha256(tok).hexdigest()})
        return {"format": "releve-bundle/1", "record": r, "record_hash": h, "cycle": "2024-10", "root": b["root"], "path": b["paths"][h], "token": tok.hex()}, rs
    b, rs = resealed(lambda r: r["selection"]["order"].reverse())
    fails_at("order, rehashed", b, rs, want="order")
    b, rs = resealed(lambda r: r["beacon"].update(randomness="00" * 32))
    fails_at("beacon randomness, rehashed", b, rs, want="beacon-round")
    b, rs = resealed(lambda r: r["beacon"].update(round=r["beacon"]["round"] + 1))
    fails_at("beacon round, rehashed (a later round chosen)", b, rs, want="beacon-signature")
    b, rs = resealed(lambda r: r["selection"]["candidates"].append(site + "/late"))
    fails_at("candidates, rehashed (a page added after the round)", b, rs, want="order")
    b, rs = resealed(lambda r: r["selection"]["commitment"].update(time=r["selection"]["commitment"]["time"] + 600))
    fails_at("commitment time, rehashed", b, rs, want="before-beacon")
    unseeded = core.call("verifyBundle", {"bundle": {**b2, "record": {**b2["record"], "beacon": {"status": "unavailable"}}}, "previous": record,
                                          "roots": roots, "edge": verify.edge(b2)})
    check("a record whose beacon could not be reached says so, and is not taken as seeded",
          [c for c in unseeded["checks"] if c["check"] == "beacon"][0]["detail"].startswith("selection not beacon-seeded"))

    # ---- records of relevé 0.10
    with tempfile.TemporaryDirectory() as d:
        corpus = Path(d, "c")
        import subprocess
        subprocess.run([core.releve(), "ingest", corpus], input=(ROOT / "tests" / "observations" / "page.jsonl").read_bytes(), capture_output=True, check=True)
        v1 = [observation.from_v1(l) for l in corpus.read_text().splitlines()]
        v1 = [v for v in v1 if v]
        check("a relevé 0.10 record reads, saying what it did not record", v1 and set(v1[0]["not_recorded"]) == {"status", "pre_interaction", "ax"})
    print(f"{sum(checks)} of {len(checks)} hold")
    return 0 if all(checks) else 1


if __name__ == "__main__":
    sys.exit(main())
