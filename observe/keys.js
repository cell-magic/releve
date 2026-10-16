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
  return { at: path(el), frame: tag === "iframe" || tag === "frame", box: [r.x, r.y, r.width, r.height] };
}
