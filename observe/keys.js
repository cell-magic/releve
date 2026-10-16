// SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
// SPDX-License-Identifier: EUPL-1.2
// Runs inside the rendered page, once per Tab: where the focus stands now.
// Returns facts only; no verdicts. The place of an element is written as
// extract.js writes it, by the same lines, so that the two name it alike.
() => {
  const ids = new Map();
  for (const n of document.querySelectorAll("[id]")) ids.set(n.id, (ids.get(n.id) || 0) + 1);

  function path(el) {
    const parts = [];
    for (let n = el; n && n.nodeType === 1; n = n.parentElement) {
      if (n.id && ids.get(n.id) === 1) { parts.unshift("#" + CSS.escape(n.id)); break; }
      let p = n.tagName.toLowerCase();
      const cls = [...n.classList].filter(c => /^[a-zA-Z][\w-]{1,30}$/.test(c)).slice(0, 2);
      if (cls.length) p += "." + cls.join(".");
      const sib = n.parentElement ? [...n.parentElement.children].filter(c => c.tagName === n.tagName) : [];
      if (sib.length > 1) p += `:nth-of-type(${sib.indexOf(n) + 1})`;
      parts.unshift(p);
      if (n.tagName === "BODY") break;
    }
    return parts.join(" > ");
  }

  let el = document.activeElement;
  while (el && el.shadowRoot && el.shadowRoot.activeElement) el = el.shadowRoot.activeElement;
  if (!el || el === document.body || el === document.documentElement) return { at: null };
  const tag = el.tagName.toLowerCase();
  const r = el.getBoundingClientRect();
  // What the page's own content lays over the focused element: where every point of it that is on the
  // screen lies under one other element that does not hold it, that element (WCAG 2.4.11).
  const W = innerWidth, H = innerHeight, points = [];
  for (const fx of [0.15, 0.5, 0.85]) for (const fy of [0.2, 0.5, 0.8]) {
    const x = r.x + r.width * fx, y = r.y + r.height * fy;
    if (x >= 0 && y >= 0 && x < W && y < H) points.push([x, y]);
  }
  const over = points.map(([x, y]) => { let n = document.elementFromPoint(x, y); while (n && n.shadowRoot && n.shadowRoot.elementFromPoint(x, y) && n.shadowRoot.elementFromPoint(x, y) !== n) n = n.shadowRoot.elementFromPoint(x, y); return n; })
    .map(n => !n || n === el || el.contains(n) || n.contains(el) || (n.control === el) ? null : n);
  let by = null;
  if (points.length && over.every(Boolean)) {
    const top = n => { for (let x = n; x && x.nodeType === 1; x = x.parentElement) if (/fixed|sticky/.test(getComputedStyle(x).position)) return x; return n; };
    const covers = [...new Set(over.map(top))];
    if (covers.length === 1) by = path(covers[0]);
  }
  return { at: path(el), frame: tag === "iframe" || tag === "frame", box: [r.x, r.y, r.width, r.height], by };
}
