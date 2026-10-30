# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""Report bundle: the pages a selection was computed from, as a signed WACZ the client keeps.

Layout (WACZ 1.1.1):
    archive/data.warc.gz      one WARC/1.1 resource record per page, in crawl order (one gzip member each)
    indexes/index.cdxj        CDXJ index of the records
    pages/pages.jsonl         crawl order, and whether each page is held in full or as a skeleton
    conditions.json           capture conditions (vantage, browser profile, proxy, user agent, tool)
    datapackage.json          every file above with its SHA-256 and size
    datapackage-digest.json   SHA-256 of datapackage.json, signed (signedData, anonymous format)

Minimisation. Picked pages are held in full: they are the evidence for findings. Every other
page is held as a tag skeleton: start and end tags only, no text, no attributes, no script or
style content, with the digest of the full page in its record header. The selector's
signature counts tags and nesting only, so a skeleton replays to the identical signature
(checked page by page here; a page whose skeleton would differ is kept in full and marked
so). The receipt's chain includes every page's content digest, so a full page that was
edited no longer replays, whatever key signs the bundle.

Signature. ECDSA P-256 with SHA-256 over the ASCII string "sha256:<hex>" of datapackage.json,
base64 DER, public key as base64 SubjectPublicKeyInfo DER (the encodings of the WACZ
reference signer). In open-source use the key is ephemeral: generated for the bundle and
discarded, so the signature proves the bundle is unchanged since it was made, not who made
it. No Bureau key signs anything (the Seal is retired, D-034): time comes from the RFC 3161
token over the record, identity from nothing but the chain.

The machine receipt (receipt.json) stays outside the bundle; a verifier takes both.
"""
from __future__ import annotations
import base64, datetime, gzip, io, json, uuid, zipfile
from hashlib import sha256
from html.parser import HTMLParser
from urllib.parse import urlsplit

from . import signature as S
from . import sampler, __version__

SOFTWARE, VERSION = "surface-core", __version__


# ---- skeletons ----------------------------------------------------------------------

class _Skeleton(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.out = []

    def handle_starttag(self, tag, attrs):
        self.out.append(f"<{tag}>")

    def handle_endtag(self, tag):
        self.out.append(f"</{tag}>")

    def handle_startendtag(self, tag, attrs):
        self.out.append(f"<{tag}/>")


def skeleton(html: str) -> str:
    p = _Skeleton()
    p.feed(html)
    p.close()
    return "".join(p.out)


# ---- WARC / CDXJ ----------------------------------------------------------------------

def _record(kind, uri, date, payload: bytes, ctype, extra=()):
    digest = "sha256:" + sha256(payload).hexdigest()
    rid = uuid.uuid5(uuid.NAMESPACE_URL, f"{kind}|{uri}|{digest}")
    head = [f"WARC/1.1", f"WARC-Type: {kind}", f"WARC-Record-ID: <urn:uuid:{rid}>", f"WARC-Date: {date}"]
    if uri:
        head.append(f"WARC-Target-URI: {uri}")
    head += [f"Content-Type: {ctype}", f"WARC-Block-Digest: {digest}", *extra, f"Content-Length: {len(payload)}"]
    return ("\r\n".join(head) + "\r\n\r\n").encode() + payload + b"\r\n\r\n", digest


def _surt(url):
    u = urlsplit(url)
    host = (u.hostname or "").lower()
    if host.startswith("www."):
        host = host[4:]
    path = (u.path or "/") + ("?" + u.query if u.query else "")
    return ",".join(reversed(host.split("."))) + ")" + path.lower()


def _now():
    return datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).strftime("%Y-%m-%dT%H:%M:%SZ")


# ---- build ----------------------------------------------------------------------------

def build(pages, receipt, conditions=None, private_key=None, created=None) -> bytes:
    """pages: (url, html) in crawl order, as passed to the selector. receipt: its receipt
    (with "sample"). Returns the .wacz bytes. private_key: an EC P-256 key from
    `cryptography`; if None an ephemeral one is generated and discarded."""
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.hazmat.primitives import hashes, serialization

    created = created or _now()
    ts14 = created.replace("-", "").replace(":", "").replace("T", "")[:14]
    picked = set(receipt.get("sample", []))
    warc = io.BytesIO()
    info, _ = _record("warcinfo", None, created, json.dumps(
        {"software": f"{SOFTWARE} {VERSION}", "format": "WARC/1.1", "receipt_head": receipt["head"]},
        sort_keys=True).encode(), "application/json")
    warc.write(gzip.compress(info, mtime=0))
    cdx, lines = [], [json.dumps({"format": "json-pages-1.0", "id": "pages", "title": "Surface Core selection"})]
    for n, (url, html) in enumerate(pages, 1):
        full = url in picked
        body = html if full else skeleton(html)
        if not full and S.signature(body) != S.signature(html):
            body, full = html, True                      # skeleton would not replay: keep the page whole
        payload = body.encode("utf-8")
        content = "full" if full else "skeleton"
        source = format(S.digest(html), "032x")
        rec, digest = _record("resource", url, created, payload, "text/html; charset=utf-8",
                              (f"Surface-Core-Content: {content}", f"Surface-Core-Crawl-Order: {n}",
                               f"Surface-Core-Source-Digest: {source}"))
        offset = warc.tell()
        member = gzip.compress(rec, mtime=0)
        warc.write(member)
        cdx.append(f"{_surt(url)} {ts14} " + json.dumps({"url": url, "mime": "text/html", "status": "200",
                   "digest": digest, "length": str(len(member)), "offset": str(offset), "filename": "data.warc.gz"},
                   sort_keys=True))
        lines.append(json.dumps({"id": f"p{n}", "url": url, "ts": created, "crawl_order": n,
                                 "content": content, "picked": url in picked}))
    files = {
        "archive/data.warc.gz": warc.getvalue(),
        "indexes/index.cdxj": ("\n".join(sorted(cdx)) + "\n").encode(),
        "pages/pages.jsonl": ("\n".join(lines) + "\n").encode(),
        "conditions.json": json.dumps(conditions or {}, indent=1, sort_keys=True).encode(),
    }
    dp = {
        "profile": "data-package", "wacz_version": "1.1.1", "title": "Surface Core selection",
        "created": created, "software": f"{SOFTWARE} {VERSION}",
        "mainPageUrl": pages[0][0] if pages else "", "mainPageDate": created,
        "resources": [{"name": p.rsplit("/", 1)[-1], "path": p, "hash": "sha256:" + sha256(b).hexdigest(),
                       "bytes": len(b)} for p, b in files.items()],
    }
    dp_bytes = json.dumps(dp, indent=1).encode()
    h = "sha256:" + sha256(dp_bytes).hexdigest()
    key = private_key or ec.generate_private_key(ec.SECP256R1())
    sig = key.sign(h.encode("ascii"), ec.ECDSA(hashes.SHA256()))
    spki = key.public_key().public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)
    digest = {"path": "datapackage.json", "hash": h, "signedData": {
        "hash": h, "created": created, "software": SOFTWARE, "version": VERSION,
        "signature": base64.b64encode(sig).decode(), "publicKey": base64.b64encode(spki).decode()}}
    files["datapackage.json"] = dp_bytes
    files["datapackage-digest.json"] = json.dumps(digest, indent=1).encode()
    out = io.BytesIO()
    stamp = tuple(int(x) for x in (created[0:4], created[5:7], created[8:10], created[11:13], created[14:16], created[17:19]))
    with zipfile.ZipFile(out, "w", zipfile.ZIP_STORED) as z:
        for path, data in files.items():
            zi = zipfile.ZipInfo(path, date_time=stamp)
            zi.compress_type = zipfile.ZIP_STORED
            z.writestr(zi, data)
    return out.getvalue()


# ---- read and verify ------------------------------------------------------------------

def _warc_records(data: bytes):
    i = 0
    while i < len(data):
        j = data.index(b"\r\n\r\n", i)
        head = data[i:j].decode().split("\r\n")
        fields = dict(l.split(": ", 1) for l in head[1:])
        n = int(fields["Content-Length"])
        yield fields, data[j + 4:j + 4 + n]
        i = j + 4 + n + 4


def read(wacz: bytes):
    z = zipfile.ZipFile(io.BytesIO(wacz))
    files = {n: z.read(n) for n in z.namelist()}
    recs = {f["WARC-Target-URI"]: (f, body) for f, body in _warc_records(gzip.decompress(files["archive/data.warc.gz"]))
            if f["WARC-Type"] == "resource"}
    order = [json.loads(l) for l in files["pages/pages.jsonl"].decode().splitlines()[1:] if l.strip()]
    def page(p):
        f, body = recs[p["url"]]
        html = body.decode("utf-8")
        # a full page proves its own digest; a skeleton carries the digest of the page it came from
        return (p["url"], html) if f["Surface-Core-Content"] == "full" else (p["url"], html, f["Surface-Core-Source-Digest"])
    pages = [page(p) for p in order]
    content = {p["url"]: recs[p["url"]][0]["Surface-Core-Content"] for p in order}
    return dict(files=files, pages=pages, content=content,
                conditions=json.loads(files.get("conditions.json", b"{}")))


def verify(wacz: bytes, receipt: dict) -> dict:
    """Integrity (every listed hash), signature (ECDSA P-256 over the digest), replay (the
    selection reproduces the receipt), evidence (every picked page is held in full)."""
    fail = lambda why: dict(ok=False, integrity=False, signature=None, key=None, replay=False, evidence=False,
                            pages=0, conditions={}, problems=[why])
    try:
        z = zipfile.ZipFile(io.BytesIO(wacz))
        files = {n: z.read(n) for n in z.namelist()}
    except Exception as exc:
        return fail(f"the bundle file is damaged ({type(exc).__name__})")
    problems = []
    dp_bytes = files["datapackage.json"]
    dp, dg = json.loads(dp_bytes), json.loads(files["datapackage-digest.json"])
    integrity = all("sha256:" + sha256(files[r["path"]]).hexdigest() == r["hash"] for r in dp["resources"])
    integrity &= dg["hash"] == "sha256:" + sha256(dp_bytes).hexdigest()
    sd = dg.get("signedData", {})
    try:
        from cryptography.hazmat.primitives.asymmetric import ec
        from cryptography.hazmat.primitives import hashes, serialization
        pub = serialization.load_der_public_key(base64.b64decode(sd["publicKey"]))
        pub.verify(base64.b64decode(sd["signature"]), sd["hash"].encode("ascii"), ec.ECDSA(hashes.SHA256()))
        signed = sd["hash"] == dg["hash"] and set(sd) <= {"hash", "created", "software", "version", "signature", "publicKey"}
        fingerprint = sha256(base64.b64decode(sd["publicKey"])).hexdigest()[:16]
    except ImportError:
        signed, fingerprint = None, None
        problems.append("signature not checked: the `cryptography` package is not installed")
    except Exception:
        signed, fingerprint = False, None
    if not integrity:
        r = fail("a file differs from the hash listed for it"); r.update(signature=signed, key=fingerprint)
        return r
    b = read(wacz)
    replay = sampler.verify(b["pages"], receipt)
    evidence = all(b["content"].get(u) == "full" for u in receipt.get("sample", []))
    if signed is False: problems.append("the signature does not match the bundle")
    if not replay: problems.append("the selection does not replay to the receipt")
    if not evidence: problems.append("a picked page is not held in full")
    ok = integrity and signed is not False and replay and evidence
    return dict(ok=ok, integrity=integrity, signature=signed, key=fingerprint, replay=replay,
                evidence=evidence, pages=len(b["pages"]), conditions=b["conditions"], problems=problems)
