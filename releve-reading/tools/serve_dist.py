#!/usr/bin/env python3
"""Serve dist/ at /reading/ with the same fallback Caddy uses in production.

`vite preview` serves the bundle at the origin root even when `base` is set, so
the mounted paths cannot be exercised locally with it. This is thirty lines of
stdlib and it matches the host: a file if the file exists, index.html otherwise.

    python tools/serve_dist.py --port 4173
"""

import argparse
import http.server
import os
import socketserver
import sys

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "dist")
MOUNT = "/reading"
TYPES = {
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".woff2": "font/woff2",
    ".woff": "font/woff",
    ".svg": "image/svg+xml",
    ".json": "application/json",
    ".ico": "image/x-icon",
    ".md": "text/markdown; charset=utf-8",
    ".csv": "text/csv; charset=utf-8",
}


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self) -> None:
        self.reply(head_only=False)

    def do_HEAD(self) -> None:
        self.reply(head_only=True)

    def reply(self, head_only: bool) -> None:
        path = self.path.split("?")[0]
        if not path.startswith(MOUNT):
            return self.simple(404, b"not here\n", head_only)
        rest = path[len(MOUNT):].lstrip("/")
        target = os.path.normpath(os.path.join(ROOT, rest)) if rest else os.path.join(ROOT, "index.html")
        if os.path.isdir(target):
            target = os.path.join(target, "index.html")
        if not os.path.isfile(target):
            # the route is a station, not a file: the ring renders it
            target = os.path.join(ROOT, "index.html")
        if not os.path.isfile(target):
            return self.simple(500, b"dist/ is missing\n", head_only)
        body = b"" if head_only else open(target, "rb").read()
        kind = TYPES.get(os.path.splitext(target)[1], "application/octet-stream")
        self.send_response(200)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        if body:
            self.wfile.write(body)

    def simple(self, code: int, body: bytes, head_only: bool) -> None:
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if not head_only:
            self.wfile.write(body)

    def log_message(self, *args) -> None:
        pass


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=4173)
    port = parser.parse_args().port
    socketserver.TCPServer.allow_reuse_address = True
    if not os.path.isdir(ROOT):
        print("dist/ is missing: run npm run build", file=sys.stderr)
        return 1
    with socketserver.ThreadingTCPServer(("127.0.0.1", port), Handler) as httpd:
        print(f"http://127.0.0.1:{port}{MOUNT}/", flush=True)
        httpd.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
