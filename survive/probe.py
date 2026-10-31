# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""Probe 2: the file behind a transformed image, asked for once, plainly.

It is sent only when the surface names a transformer: an edge header on the delivered
response, or a recognised wrapper in the image's address. The wrapper is stripped (an
absolute `url=` parameter URL-decoded), and the target asked for with
`Cache-Control: no-transform` and an `Accept` that names no image format, so that nothing
is transcoded on the way. One hop: a redirect is an answer, not a road. A 5 s timeout of
its own, apart from the surface's settle cap. robots.txt is asked first, as for any page.

An absolute target is reached only over http or https, and never at a loopback, private,
link-local or unique-local address (nor the unspecified one); the address checked is the
address connected to. A relative target is the image's own origin, which the browser has
already fetched. A probe answered with an edge-modification header is still transformed:
what it holds is not the origin, and the origin stays unobserved."""
import http.client, ipaddress, socket, ssl, urllib.parse

# Response headers that say an edge modified the bytes, and the transformer each names.
EDGE = {"cf-polished": "cloudflare-polish", "cf-resized": "cloudflare-images",
        "x-akamai-transformed": "akamai-image-manager", "x-fastly-imageopto-api": "fastly-image-optimizer"}
IMGIX = {"auto", "fit", "crop", "w", "h", "q", "fm", "dpr", "rect", "ar", "ixlib", "s"}  # imgix's transform parameters
SHUT = [ipaddress.ip_network(n) for n in ("127.0.0.0/8", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16",
                                          "0.0.0.0/8", "::1/128", "fc00::/7", "::/128")]
TIMEOUT = 5.0
HEAVIEST = 8_000_000


def edge(headers):
    """The transformer an edge-modification header names, or None. `headers`: names in lowercase."""
    return next((name for h, name in EDGE.items() if h in headers), None)


def wrapper(url):
    """(transformer, target, absolute) for an address wrapped by a known transformer, or None."""
    p = urllib.parse.urlsplit(url)
    query = urllib.parse.parse_qsl(p.query, keep_blank_values=True)
    if p.path == "/_next/image":
        target = dict(query).get("url")
        return ("next-image", *resolved(url, target)) if target else None
    if p.path.startswith("/cdn-cgi/image/"):
        rest = p.path[len("/cdn-cgi/image/"):].split("/", 1)
        if len(rest) != 2 or not rest[1]:
            return None
        target = urllib.parse.unquote(rest[1])  # an absolute address, or a path from the site's root
        return ("cloudflare-images", *resolved(url, target if urllib.parse.urlsplit(target).scheme else "/" + target))
    kept = [(k, v) for k, v in query if k not in IMGIX]
    if (p.hostname or "").endswith(".imgix.net") and len(kept) < len(query) or any(k == "ixlib" for k, _ in query):
        return "imgix", urllib.parse.urlunsplit((p.scheme, p.netloc, p.path, urllib.parse.urlencode(kept), "")), False
    return None


def resolved(base, target):
    """The target as an absolute address, and whether it was given absolute (and so must be vetted)."""
    absolute = bool(urllib.parse.urlsplit(target).scheme)
    return urllib.parse.urljoin(base, target), absolute


def refused(url):
    """Why an absolute target may not be reached, or None; with the address to connect to."""
    p = urllib.parse.urlsplit(url)
    if p.scheme not in ("http", "https") or not p.hostname:
        return "not http or https", None
    try:
        port = p.port or (443 if p.scheme == "https" else 80)
        found = {a[4][0] for a in socket.getaddrinfo(p.hostname, port, type=socket.SOCK_STREAM)}
    except (OSError, ValueError):
        return "does not resolve", None
    for a in sorted(found):
        ip = ipaddress.ip_address(a.split("%")[0])
        ip = ip.ipv4_mapped or ip if ip.version == 6 else ip
        if any(ip in n for n in SHUT):
            return "a loopback, private or link-local address", None
    return None, sorted(found)[0]


def fetch(url, agent, connect_to=None):
    """One plain request: (status as text, response headers in lowercase, body or None). No redirect is followed."""
    p = urllib.parse.urlsplit(url)
    port = p.port or (443 if p.scheme == "https" else 80)
    host = connect_to or p.hostname
    try:
        sock = socket.create_connection((host, port), timeout=TIMEOUT)
        if p.scheme == "https":
            sock = ssl.create_default_context().wrap_socket(sock, server_hostname=p.hostname)
        conn = http.client.HTTPConnection(p.hostname, port, timeout=TIMEOUT)
        conn.sock = sock
        conn.request("GET", urllib.parse.urlunsplit(("", "", p.path or "/", p.query, "")),
                     headers={"Host": p.netloc, "User-Agent": agent, "Accept": "*/*", "Accept-Encoding": "identity",
                              "Cache-Control": "no-transform"})
        r = conn.getresponse()
        headers = {k.lower(): v for k, v in r.getheaders()}
        body = r.read(HEAVIEST + 1) if r.status == 200 else None
        conn.close()
    except socket.timeout:
        return "timeout", {}, None
    except (OSError, http.client.HTTPException, ssl.SSLError):
        return "error", {}, None
    return str(r.status), headers, (body if body is not None and len(body) <= HEAVIEST else None)
