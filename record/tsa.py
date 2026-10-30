# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""Dating a hash from outside, under RFC 3161: the hash, and nothing else, goes to a
time-stamping authority; its signed token comes back and is checked with OpenSSL, as anyone
can check it again without relevé. The authority is a setting (`url`): DigiCert's free one
unless another is named; a qualified provider under eIDAS replaces it by naming it, with no
change of code. The roots that sign tokens are the system's, or those RELEVE_CA names."""
import calendar, os, re, subprocess, tempfile, urllib.request
from pathlib import Path

DEFAULT = "http://timestamp.digicert.com"
ROOTS = ["/etc/ssl/certs", "/etc/ssl/cert.pem", "/etc/pki/tls/certs/ca-bundle.crt", "/usr/local/etc/openssl/cert.pem"]


def roots():
    for p in ([os.environ["RELEVE_CA"]] if os.environ.get("RELEVE_CA") else []) + ROOTS:
        if os.path.isdir(p):
            return ["-CApath", p]
        if os.path.isfile(p):
            return ["-CAfile", p]
    raise RuntimeError("no root certificates found; name them in RELEVE_CA")


def openssl(*args, data=None):
    r = subprocess.run(["openssl", *args], input=data, capture_output=True)
    return r.returncode, r.stdout, r.stderr.decode("utf-8", "replace")


def stamp(digest_hex, url=DEFAULT, timeout=30):
    """The authority's token over a SHA-256 digest (hex), checked before it is returned: its DER bytes."""
    with tempfile.TemporaryDirectory() as d:
        q, rep = Path(d, "q.tsq"), Path(d, "r.tsr")
        code, _, err = openssl("ts", "-query", "-digest", digest_hex, "-sha256", "-cert", "-out", str(q))
        if code:
            raise RuntimeError("openssl: " + err.strip())
        req = urllib.request.Request(url, data=q.read_bytes(), headers={"Content-Type": "application/timestamp-query"})
        with urllib.request.urlopen(req, timeout=timeout) as answer:
            rep.write_bytes(answer.read())
        code, text, err = openssl("ts", "-reply", "-in", str(rep), "-text")
        if code or b"Status: Granted." not in text:
            raise RuntimeError("the authority did not grant the request")
        tok = Path(d, "t.der")
        code, _, err = openssl("ts", "-reply", "-in", str(rep), "-token_out", "-out", str(tok))
        if code:
            raise RuntimeError("openssl: " + err.strip())
        token = tok.read_bytes()
    ok, why = check(token, digest_hex)
    if not ok:
        raise RuntimeError(why)
    return token


def time_of(token):
    """The time a token says it was signed, in seconds since 1970 (UTC); None if it cannot be read.
    Which digest it covers is shown by check(), against the digest it must cover."""
    with tempfile.TemporaryDirectory() as d:
        f = Path(d, "t.der")
        f.write_bytes(token)
        code, text, _ = openssl("ts", "-reply", "-in", str(f), "-token_in", "-text")
    when = re.search(r"Time stamp: (\w{3}) +(\d+) (\d\d):(\d\d):(\d\d)(?:\.\d+)? (\d{4}) GMT", text.decode("utf-8", "replace")) if not code else None
    if not when:
        return None
    mon = "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split().index(when.group(1)) + 1
    return calendar.timegm((int(when.group(6)), mon, int(when.group(2)), int(when.group(3)), int(when.group(4)), int(when.group(5))))


def check(token, digest_hex):
    """Whether a token is the authority's, signed under a root this system trusts, over this digest."""
    with tempfile.TemporaryDirectory() as d:
        f = Path(d, "t.der")
        f.write_bytes(token)
        code, text, err = openssl("ts", "-verify", "-digest", digest_hex, "-in", str(f), "-token_in", *roots())
    if code == 0 and b"Verification: OK" in text:
        return True, "the token verifies"
    return False, "the token does not verify over " + digest_hex + ": " + (err.strip().splitlines() or ["no reason given"])[-1]
