#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""The RADAR record, checked without a browser: its schema, its canonical bytes (RFC 8785),
its readings and their recomputation, its chain, the month's tree (RFC 6962), the published
roots, the beacon and the order it gives, the commitment dated before the cycle whose round
it is, the lists each in their one order, and the verifier, on a record made whole from a
recorded page; then each piece tampered with, and the verifier failing at the check that
names it; then the laws: what does not depend on order. Needs releve
(RELEVE), OpenSSL, faketime, releve-bls and the tests' beacon (cargo build --release --bins
--examples in record/bls), Node for the WebAssembly, and Chromium for verifier.html.

No network. The authority is the tests' own, its clock set before the cycle begins. The
beacon is the tests' own too, on quicknet's scheme and schedule under a key of their own
(record/bls/examples/beacon.rs, named to relevé in RELEVE_BEACON): a cycle's round falls on
the cycle's first seconds, and no recorded quicknet round does. The one recorded quicknet
round (tests/beacon/) holds the BLS check to quicknet's own key, here and in the browser."""
import calendar, contextlib, copy, hashlib, json, os, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path[:0] = [str(ROOT), str(ROOT / "tests")]
from authority import authority  # noqa: E402
from receipt import sampler  # noqa: E402
from record import beacon, core, observation, psl, schema, tsa, verify  # noqa: E402
from record.cli import recompute  # noqa: E402
from record.run import ENERGY, MANDATED, Late, drawn, rules_of, run  # noqa: E402

checks = []
ROUND = json.loads((ROOT / "tests" / "beacon" / "quicknet-12040883.json").read_text())
H = lambda b: hashlib.sha256(b).digest()
SIGNER = ROOT / "record" / "bls" / "target" / "release" / "examples" / "beacon"
SECRET = "1729"  # the tests' beacon's key, of the tests' own


def own(r):
    """Round r of the tests' own beacon."""
    sig = subprocess.run([SIGNER, SECRET, str(r)], capture_output=True, text=True, check=True).stdout.strip()
    return {"round": r, "signature": sig, "randomness": hashlib.sha256(bytes.fromhex(sig)).hexdigest()}


def own_beacon(dir):
    """The tests' own beacon, named to relevé in RELEVE_BEACON: its chain (the hash of its key) and its key."""
    key = subprocess.run([SIGNER, SECRET], capture_output=True, text=True, check=True).stdout.strip()
    named = dir / "beacon.json"
    named.write_text(json.dumps({"chain": hashlib.sha256(bytes.fromhex(key)).hexdigest(), "key": key}))
    os.environ["RELEVE_BEACON"] = str(named)
    return beacon.trusted()[0]


@contextlib.contextmanager
def quicknet():
    """Quicknet trusted again, for its own recorded round."""
    named = os.environ.pop("RELEVE_BEACON", None)
    try:
        yield
    finally:
        if named:
            os.environ["RELEVE_BEACON"] = named


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
    os.environ["RELEVE_CA"] = str(authority(tmp / "tsa", 8768, clock="@2024-09-30 23:59:00"))
    url = "http://127.0.0.1:8768"
    chain = own_beacon(tmp)

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
    leaves = [H(bytes([7, i])).hex() for i in range(9)]
    check("the month's root does not depend on the order its leaves come in",
          core.call("merkleBatch", {"leaves": leaves})["root"] == core.call("merkleBatch", {"leaves": leaves[::-1]})["root"])

    # ---- a record made whole
    raw = raw_page()
    html = (ROOT / "tests" / "pages" / "page.html").read_text(encoding="utf-8")
    site = observation.origin(raw["url"])
    candidates = [raw["url"], site + "/b", site + "/a"]
    committed = core.call("commitmentOf", {"candidates": candidates})
    check("the commitment does not depend on the order or the repetition of the candidates",
          committed == core.call("commitmentOf", {"candidates": candidates[::-1] + candidates}) and not committed["refused"])
    token = tsa.stamp(committed["commitment"], url)
    when = tsa.time_of(token)
    draw = core.call("drawOf", {"cycle": "2024-10"})
    block = drawn("2024-10", {draw["round"]: own(draw["round"])})
    check("the cycle's round is the first after the cycle begins, and the commitment is dated before (releve-draw/1)",
          draw["start"] == 1727740800 and block.get("round") == draw["round"] == beacon.first_after(draw["start"]) and when < draw["start"]
          and block["chain"] == chain)
    js_fold = lambda fn, value: subprocess.run(["node", str(ROOT / "plie" / "run.mjs"), str(ROOT / "record" / "gen" / "record.js"), fn],
                                               input=json.dumps(value).encode("utf-8"), capture_output=True).stdout.decode("utf-8").strip()
    cycles = [f"{y}-{m:02d}" for y, m in ((1970, 1), (1999, 12), (2000, 2), (2000, 3), (2024, 2), (2024, 3), (2100, 2), (2100, 3), (2400, 2))]
    check("a cycle begins on its month's first second, UTC, in both folds (leap years and centuries among them)",
          all(core.call("drawOf", {"cycle": c})["start"] == calendar.timegm((int(c[:4]), int(c[5:]), 1, 0, 0, 0)) for c in cycles)
          and all(js_fold("drawOf", {"cycle": c}) == core.run("drawOf", {"cycle": c}) for c in cycles + ["2024-13", "2024"])
          and core.call("drawOf", {"cycle": "2024-13"})["start"] == core.call("drawOf", {"cycle": "2024"})["start"] == -1)
    spellings = ["https://x.fr/", "https://x.fr", "https://X.fr/", "https://x.fr/#top", "https://x.fr./", "https://x.fr:443/", "http://x.fr:80/",
                 "https://x.fr:8443/", "https://u@x.fr/", "https://x.fr/a/../b", "https://x.fr/a%2fb", "https://x.fr/a%2Fb", "https://café.fr/",
                 "https://xn--caf-dma.fr/", "ftp://x.fr/", "https://[::1]:8080/", "http://x.fr/a?q=1/2"]
    kept = {"https://x.fr/", "https://x.fr:8443/", "https://x.fr/a%2Fb", "https://xn--caf-dma.fr/", "https://[::1]:8080/", "http://x.fr/a?q=1/2"}
    check("a page address is admitted only in its one way, in both folds",
          set(spellings) - set(core.call("commitmentOf", {"candidates": spellings})["refused"]) == kept
          and js_fold("commitmentOf", {"candidates": spellings}) == core.run("commitmentOf", {"candidates": spellings}))
    with quicknet():
        check("quicknet's recorded round holds under quicknet's key", beacon.bls(ROUND["round"], ROUND["signature"]) is True)
        check("a signature moved to another round does not", beacon.bls(ROUND["round"] + 1, ROUND["signature"]) is False)
        check("nor does the tests' beacon's round, under quicknet's key", beacon.bls(block["round"], block["signature"]) is False)
    check("the tests' own beacon signs on quicknet's scheme, under its own key", beacon.bls(block["round"], block["signature"]) is True)
    try:
        run(observation.origin(raw_page()["url"]), "2024-09", candidates, 1, None, contact="tests", tsa_url=url, recorded={})
        late = False
    except Late:
        late = True
    check("a run whose commitment is dated once its cycle has begun draws nothing", late)
    try:
        run("http://localhost:8765", "2024-10", ["http://LOCALHOST:8765/a", "http://localhost:8765/a#x"], 1, None, contact="tests", tsa_url=url, recorded={})
        refused = False
    except ValueError as e:
        refused = "LOCALHOST" in str(e) and "#x" in str(e)
    check("a candidate not written in its one way is refused before anything is committed", refused)
    order = core.call("orderOf", {"randomness": block["randomness"], "site": site, "cycle": "2024-10", "candidates": committed["candidates"]})
    again = core.call("orderOf", {"randomness": block["randomness"], "site": site, "cycle": "2024-10", "candidates": list(reversed(candidates))})
    other = core.call("orderOf", {"randomness": block["randomness"], "site": site, "cycle": "2024-11", "candidates": candidates})
    check("the order is the round's, whatever order the candidates came in", order == again)
    check("another cycle draws another seed", other["seed"] != order["seed"])
    pages = [(u, html if u == raw["url"] else html.replace("<main", "<main><nav>x</nav><table><tr><td>x</td></tr></table")) for u in order["order"]]
    picked, receipt, _ = sampler.run(pages, 1)
    rules = rules_of([raw])[0]
    obs = observation.block(raw)
    turned = copy.deepcopy(raw)
    turned["network"]["resources"].reverse()
    check("the observation's requests are in their one order, whatever order they arrived in",
          observation.block(turned) == obs and [observation.order(q) for q in obs["requests"]] == sorted(observation.order(q) for q in obs["requests"]))
    check("an observation keeps scheme and host of each request, never its path or query",
          all(q["origin"] == site for q in obs["requests"]) and "SECRET" not in json.dumps(obs) and "session" not in json.dumps(obs))
    check("the rule results carry machine labels only", all(set(r) == {"criterion", "wcag", "fail", "review", "hint"} for r in rules))
    lists = psl.load()
    readings = core.call("readingsOf", {"observation": obs, "rules": rules, "site": site, "psl": lists, "energy": ENERGY})
    shuffled = {**obs, "requests": obs["requests"][::-1]}
    check("the readings do not depend on the order of the requests",
          core.call("readingsOf", {"observation": shuffled, "rules": rules, "site": site, "psl": lists, "energy": ENERGY}) == readings)
    wcag = next(r for r in readings if r["name"] == "wcag")["value"]
    check("the WCAG reading labels criteria fail, review or hint, and gives no share",
          {w["label"] for w in wcag} <= {"fail", "review", "hint", None} and "%" not in json.dumps(wcag) and "coverage" not in json.dumps(wcag))
    record = {"schema": "releve-record/2", "site": site, "cycle": "2024-10", "url": raw["url"], "requested": raw["requested"], "at": raw["at"],
              "agent": raw["agent"], "browser": raw["browser"], "release": "0.11.0", "criteria": "10", "from": "CH",
              "observation": obs, "rules": rules, "readings": readings,
              "selection": {"protocol": "surface-core/select-1", "order_rule": "releve-order/1", "draw_rule": "releve-draw/1",
                            "candidates": committed["candidates"],
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
    check("the verifier passes a record whole, every check named", ok and names(cs) == ["schema", "record-hash", "canonical", "prev-link", "inclusion-path",
          "root", "published", "tsa-token", "beacon-round", "beacon-signature", "order", "committed", "before-beacon"])
    check("the verifier says the beacon it trusted is not quicknet", chain in dict((c[0], c[2]) for c in cs)["beacon-round"])
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
    b, rs = resealed(lambda r: r["selection"]["candidates"].append(raw["url"] + "/zz"))
    fails_at("candidates, rehashed (a page added after the round)", b, rs, want="order")
    b, rs = resealed(lambda r: r["selection"]["candidates"].insert(0, site + "/a#top"))
    fails_at("candidates, rehashed (a page twice, in two spellings)", b, rs, want="canonical")
    b, rs = resealed(lambda r: r["observation"]["requests"].reverse())
    fails_at("requests, rehashed (in the order they arrived)", b, rs, want="canonical")
    b, rs = resealed(lambda r: r["selection"]["commitment"].update(time=r["selection"]["commitment"]["time"] + 600))
    fails_at("commitment time, rehashed (dated once the cycle began)", b, rs, want="before-beacon")

    def drawn_again(r):  # the Bureau draws again: a later round, signed, and its order followed throughout
        later = own(r["beacon"]["round"] + 20)
        r["beacon"].update(later)
        o = core.call("orderOf", {"randomness": later["randomness"], "site": r["site"], "cycle": r["cycle"], "candidates": r["selection"]["candidates"]})
        r["selection"].update(seed=o["seed"], order=o["order"], read=o["order"], picks=o["order"][:1])
        r["url"] = o["order"][0]
    b, rs = resealed(drawn_again)
    fails_at("beacon, rehashed (a later round, signed, its order followed)", b, rs, want="before-beacon")
    unseeded = core.call("verifyBundle", {"bundle": {**b2, "record": {**b2["record"], "beacon": {"status": "unavailable"}}}, "previous": record,
                                          "roots": roots, "edge": verify.edge(b2)})
    check("a record whose beacon could not be reached says so, and is not taken as seeded",
          [c for c in unseeded["checks"] if c["check"] == "beacon"][0]["detail"].startswith("selection not beacon-seeded"))

    # ---- the BLS check: one Rust source, the same verdicts as WebAssembly and on the command line
    wasm = ROOT / "record" / "bls" / "target" / "wasm32-unknown-unknown" / "release" / "releve_bls.wasm"
    script = ("const m = new WebAssembly.Module(require('fs').readFileSync(process.argv[1])); const x = new WebAssembly.Instance(m, {}).exports;"
              "const out = []; for (const [r, h] of JSON.parse(process.argv[2])) { const b = Uint8Array.from(h.match(/../g) || [], (c) => parseInt(c, 16));"
              "new Uint8Array(x.memory.buffer, x.buffer(), 64).set(b.subarray(0, 64)); out.push(x.quicknet(BigInt(r), b.length)); }"
              "console.log(JSON.stringify([WebAssembly.Module.imports(m).length, out]));")
    cases = [(ROUND["round"], ROUND["signature"]), (ROUND["round"] + 1, ROUND["signature"]), (ROUND["round"], ROUND["signature"][:-2] + "00")]
    imports, verdicts = json.loads(subprocess.run(["node", "-e", script, str(wasm), json.dumps(cases)], capture_output=True, text=True).stdout)
    with quicknet():
        native = [beacon.bls(r, h) for r, h in cases]
    check("the WebAssembly BLS check imports nothing, and gives the command line's verdicts",
          imports == 0 and [v == 1 for v in verdicts] == native == [True, False, False])
    real, real_roots = resealed(lambda r: r["beacon"].update(chain=beacon.CHAIN, **ROUND))
    try:
        from playwright.sync_api import sync_playwright
        with sync_playwright() as pw:
            browser = pw.chromium.launch()
            page = browser.new_page()
            asked = []
            page.on("request", lambda q: asked.append(q.url))
            page.goto((ROOT / "record" / "verifier.html").as_uri())
            moved = copy.deepcopy(real)
            moved["record"]["beacon"]["round"] += 1
            seen = [next(c for c in page.evaluate("([b, r, p]) => window.verifyRecord(b, r, p)", [x, real_roots, {"record": record}])["checks"]
                         if c["check"] == "beacon-signature")["ok"] for x in (real, moved)]
            browser.close()
        check("verifier.html checks the round's BLS signature itself, offline: it holds, and a moved round's does not",
              seen == [True, False] and not [u for u in asked if not u.startswith("file:")], f"{seen} {asked}")
    except ImportError:
        check("verifier.html checks the round's BLS signature (Playwright needed)", False)

    # ---- records of relevé 0.10
    with tempfile.TemporaryDirectory() as d:
        corpus = Path(d, "c")
        subprocess.run([core.releve(), "ingest", corpus], input=(ROOT / "tests" / "observations" / "page.jsonl").read_bytes(), capture_output=True, check=True)
        v1 = [observation.from_v1(l) for l in corpus.read_text().splitlines()]
        v1 = [v for v in v1 if v]
        check("a relevé 0.10 record reads, saying what it did not record", v1 and set(v1[0]["not_recorded"]) == {"status", "pre_interaction", "ax"})
    print(f"{sum(checks)} of {len(checks)} hold")
    return 0 if all(checks) else 1


if __name__ == "__main__":
    sys.exit(main())
