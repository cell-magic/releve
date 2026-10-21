# SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
# SPDX-License-Identifier: EUPL-1.2
"""Structural signature of a rendered page (no content kept).

Counts structural elements with the standard-library HTML parser and maps
them to a short fixed-point vector. Template-defining structure (landmarks,
forms, tables, media) weighs more than content volume (paragraphs, links),
so pages built from one template land near each other whatever their text.
"""
from html.parser import HTMLParser
from hashlib import sha256
from . import fx
from . import noun as N

FEATURES = [
    # name, tags counted, weight
    ("header", ("header",), "1"), ("nav", ("nav",), "1"), ("main", ("main",), "1"),
    ("aside", ("aside",), "1"), ("footer", ("footer",), "1"),
    ("form", ("form",), "1"), ("field", ("input", "select", "textarea"), "1/2"),
    ("table", ("table",), "1"), ("media", ("video", "audio", "iframe"), "1"),
    ("h1", ("h1",), "1/2"), ("h2", ("h2",), "1/4"), ("h3", ("h3",), "1/4"),
    ("img", ("img",), "1/4"), ("p", ("p",), "1/8"), ("li", ("li",), "1/8"), ("a", ("a",), "1/8"),
]
DEPTH_W = "1/8"
VOID = {"input", "img", "br", "hr", "meta", "link", "source", "area", "base", "col", "embed", "wbr", "track", "param"}


class _Counter(HTMLParser):
    def __init__(self):
        super().__init__()
        self.counts, self.depth, self.max_depth = {}, 0, 0

    def handle_starttag(self, tag, attrs):
        self.counts[tag] = self.counts.get(tag, 0) + 1
        if tag not in VOID:
            self.depth += 1
            self.max_depth = max(self.max_depth, self.depth)

    def handle_endtag(self, tag):
        if tag not in VOID:
            self.depth = max(0, self.depth - 1)


def _log2_1p(n: int) -> int:
    return fx.div(fx.ln(fx.q(1 + n)), fx.LN2)


def counts(html: str):
    c = _Counter()
    c.feed(html)
    return c.counts, c.max_depth


def signature(html: str):
    cnt, depth = counts(html)
    out = []
    for _, tags, w in FEATURES:
        n = sum(cnt.get(t, 0) for t in tags)
        out.append(fx.mul(fx.q(w), _log2_1p(n)))
    out.append(fx.mul(fx.q(DEPTH_W), _log2_1p(depth)))
    return out


def ref(url: str) -> int:
    """A page reference: the first 16 bytes of SHA-256 of its URL, as an atom."""
    return int.from_bytes(sha256(url.encode()).digest()[:16], "big")


def digest(html: str) -> int:
    """The page's content: the first 16 bytes of SHA-256 of its UTF-8 text, as an atom."""
    return int.from_bytes(sha256(html.encode("utf-8")).digest()[:16], "big")


def event(url: str, html: str, content_digest: int = None):
    """[%page [ref [digest sig]]]. The digest binds the page's full content into the chain;
    content_digest is given when only a skeleton of the page is at hand."""
    d = digest(html) if content_digest is None else content_digest
    return N.tag("page", ref(url), d, N.from_list([N.s2a(x) for x in signature(html)]))
