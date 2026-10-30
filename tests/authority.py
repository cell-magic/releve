# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""A time-stamping authority of the tests' own, for run.py and service.py: no network."""
import subprocess, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TSA_CONFIG = """[ req ]
distinguished_name = dn
[ dn ]
[ ca ]
basicConstraints = critical,CA:true
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
[ signer ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,timeStamping
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid
[ tsa ]
default_tsa = here
[ here ]
serial = {dir}/serial
signer_cert = {dir}/tsa.crt
signer_key = {dir}/tsa.key
signer_digest = sha256
default_policy = 1.2.3.4.1
other_policies = 1.2.3.4.2
digests = sha256
accuracy = secs:1
ordering = no
tsa_name = no
ess_cert_id_chain = no
ess_cert_id_alg = sha256
"""


def authority(dir, port=8766, clock=None):
    """A time-stamping authority of the tests' own, under RFC 3161, answering on 127.0.0.1:port: a root,
    a signer under it, and OpenSSL answering each request. Its root is named to relevé in RELEVE_CA.
    `clock`, a time as faketime takes it, sets the authority's own clock: its certificates are made then,
    for four years, and every token it signs says that time. For the tests of records drawn from a
    beacon round already published; nothing else is moved."""
    dir.mkdir()
    (dir / "tsa.cnf").write_text(TSA_CONFIG.format(dir=dir.as_posix()))
    (dir / "serial").write_text("01\n")
    at = ["faketime", "-f", clock] if clock else []
    sh = lambda *a: subprocess.run([*at, "openssl", *a], cwd=dir, capture_output=True, check=True)
    for who, ext in (("ca", "ca"), ("tsa", "signer")):
        sh("req", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:P-256", "-nodes", "-keyout", f"{who}.key", "-out", f"{who}.csr",
           "-subj", f"/CN=relevé tests {who}", "-config", "tsa.cnf")
        sh("x509", "-req", "-in", f"{who}.csr", "-days", "1500" if clock else "30", "-out", f"{who}.crt", "-extfile", "tsa.cnf", "-extensions", ext,
           *(["-signkey", "ca.key"] if who == "ca" else ["-CA", "ca.crt", "-CAkey", "ca.key", "-CAcreateserial"]))

    class Answer(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_POST(self):
            (dir / "q.tsq").write_bytes(self.rfile.read(int(self.headers["Content-Length"])))
            sh("ts", "-reply", "-config", "tsa.cnf", "-queryfile", "q.tsq", "-out", "r.tsr")
            body = (dir / "r.tsr").read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "application/timestamp-reply")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
    server = ThreadingHTTPServer(("127.0.0.1", port), Answer)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return dir / "ca.crt"
