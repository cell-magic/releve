// SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
// SPDX-License-Identifier: EUPL-1.2
// Runs inside the rendered page, once: the text spacing a reader may set (WCAG 1.4.12)
// is put on, the elements whose text it cuts and that were not cut before are named,
// and the spacing is taken off again. Facts only; no verdicts. Elements are named as
// extract.js names them, by the same lines.
(css) => {
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

  const cut = () => [...document.querySelectorAll("body *")].filter(n => {
    if (![...n.childNodes].some(c => c.nodeType === 3 && c.textContent.trim()) || !n.getClientRects().length) return false;
    const cs = getComputedStyle(n), shut = v => v === "hidden" || v === "clip";
    return (shut(cs.overflowY) && n.scrollHeight > n.clientHeight + 2) || (shut(cs.overflowX) && n.scrollWidth > n.clientWidth + 2);
  });
  const before = new Set(cut());
  const s = document.createElement("style");
  s.textContent = css;
  document.head.append(s);
  const after = cut().filter(n => !before.has(n));
  s.remove();
  return after.slice(0, 20).map(path);
}
