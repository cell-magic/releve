// SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
// SPDX-License-Identifier: EUPL-1.2
// Runs inside the rendered page. Returns facts only; no verdicts.
({ limit, phrases }) => {
  const txt = s => (s || "").replace(/\s+/g, " ").trim();
  const clip = s => { s = txt(s); return s.length > 80 ? s.slice(0, 79) + "…" : s; };

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

  const byIds = list => txt(list.split(/\s+/).map(i => {
    const n = document.getElementById(i); return n ? n.textContent : "";
  }).join(" "));

  function accName(el) {
    const lb = el.getAttribute("aria-labelledby");
    if (lb) { const t = byIds(lb); if (t) return t; }
    const al = txt(el.getAttribute("aria-label"));
    if (al) return al;
    const tag = el.tagName.toLowerCase();
    if (tag === "img" || (tag === "input" && el.type === "image")) return txt(el.getAttribute("alt")) || txt(el.title);
    if (tag === "svg") { const t = el.querySelector("title"); return txt(t && t.textContent) || txt(el.title); }
    if (tag === "iframe" || tag === "frame") return txt(el.title);
    if (tag === "input" && ["submit", "reset", "button"].includes(el.type))
      return txt(el.value) || (el.type === "button" ? "" : el.type); // browsers label submit/reset by default
    if (["input", "select", "textarea"].includes(tag))
      return txt(el.labels ? [...el.labels].map(x => x.innerText).join(" ") : "") || txt(el.title);
    let t = txt(el.innerText);
    if (!t) t = txt([...el.querySelectorAll("img[alt], [aria-label], svg title")]
      .map(n => n.getAttribute("alt") || n.getAttribute("aria-label") || n.textContent).join(" "));
    return t || txt(el.title);
  }

  const cv = document.createElement("canvas"); cv.width = cv.height = 1;
  const cx = cv.getContext("2d", { willReadFrequently: true });
  function rgba(c) {
    const m = c.match(/^rgba?\(([\d.]+)[, ]+([\d.]+)[, ]+([\d.]+)(?:[, /]+([\d.]+%?))?\)$/);
    if (m) {
      const a = m[4] === undefined ? 1 : m[4].endsWith("%") ? parseFloat(m[4]) / 100 : parseFloat(m[4]);
      return [+m[1], +m[2], +m[3], a];
    }
    cx.clearRect(0, 0, 1, 1); cx.fillStyle = "#000"; cx.fillStyle = c; cx.fillRect(0, 0, 1, 1);
    const d = cx.getImageData(0, 0, 1, 1).data;
    return [d[0], d[1], d[2], d[3] / 255];
  }

  function backdrop(el) {
    const layers = [];
    for (let n = el; n && n.nodeType === 1; n = n.parentElement) {
      const cs = getComputedStyle(n);
      if (cs.backgroundImage && cs.backgroundImage !== "none") return [null, true];
      const c = rgba(cs.backgroundColor);
      if (c[3] > 0) { layers.push(c); if (c[3] >= 1) break; }
    }
    let base = [255, 255, 255];
    for (const c of layers.reverse()) base = base.map((v, i) => c[3] * c[i] + (1 - c[3]) * v);
    return [base.map(Math.round).concat([1]), false];
  }

  function opacity(el) {
    let o = 1;
    for (let n = el; n && n.nodeType === 1; n = n.parentElement) o *= parseFloat(getComputedStyle(n).opacity);
    return o;
  }

  const ROLES = { header: "banner", nav: "navigation", main: "main", footer: "contentinfo", aside: "complementary" };
  const LANDMARKS = new Set(["banner", "navigation", "main", "contentinfo", "complementary", "search"]);
  const surfaces = [];
  let order = 0, truncated = false;

  for (const el of document.body ? document.body.querySelectorAll("*") : []) {
    order++;
    if (surfaces.length >= limit) { truncated = true; break; }
    const tag = el.tagName.toLowerCase();
    if (["script", "style", "noscript", "template", "option"].includes(tag)) continue;
    const role = el.getAttribute("role");
    const cs = getComputedStyle(el);
    const r = el.getBoundingClientRect();
    const hidden = !!el.closest('[aria-hidden="true"]') || el.getClientRects().length === 0 || cs.visibility === "hidden";
    const base = {
      sel: path(el), order, role,
      box: [Math.round(r.x + scrollX), Math.round(r.y + scrollY), Math.round(r.width), Math.round(r.height)],
      hidden,
    };
    const add = (kind, extra) => surfaces.push(Object.assign({ kind }, base, extra));

    if (tag === "img")
      add("img", { alt: el.hasAttribute("alt") ? txt(el.getAttribute("alt")) : null, src: el.currentSrc || el.src,
                   natural: [el.naturalWidth, el.naturalHeight] });
    else if ((tag === "svg" && role === "img") || (role === "img" && tag !== "svg"))
      add("graphic", { name: accName(el) });
    if (tag === "iframe" || tag === "frame") add("iframe", { name: accName(el) });
    if (tag === "video" || tag === "audio")
      add("media", { autoplay: el.autoplay, muted: el.muted || el.hasAttribute("muted") });
    if (((tag === "a" && el.hasAttribute("href")) || role === "link") && role !== "button")
      add("link", { name: accName(el) });
    if (tag === "button" || role === "button" || (tag === "input" && ["submit", "reset", "button", "image"].includes(el.type)))
      add("button", { name: accName(el) });
    if ((tag === "input" && !["hidden", "submit", "reset", "button", "image"].includes(el.type))
        || tag === "select" || tag === "textarea" || role === "textbox" || role === "combobox")
      add("control", { name: accName(el), itype: el.type || tag, placeholder: el.hasAttribute("placeholder") ? clip(el.getAttribute("placeholder")) : null });
    if (/^h[1-6]$/.test(tag) || role === "heading")
      add("heading", { level: role === "heading" ? parseInt(el.getAttribute("aria-level")) || 2 : +tag[1],
                       text: clip(el.innerText) });
    const lm = role && LANDMARKS.has(role) ? role : ROLES[tag];
    if (lm) add("landmark", { role: lm });

    if (!hidden && !el.closest("svg") && r.width > 1 && r.height > 1) {
      const own = txt([...el.childNodes].filter(n => n.nodeType === 3).map(n => n.textContent).join(" "));
      const fade = opacity(el);
      const inactive = !!el.closest(':disabled, [aria-disabled="true"]');
      if (own && fade > 0.01 && !inactive) {
        const [bg, bgImage] = backdrop(el);
        const fg = rgba(cs.color);
        fg[3] *= fade;
        add("text", Object.assign({ text: clip(own), fg, bg, bgImage, size: parseFloat(cs.fontSize),
                                    weight: parseInt(cs.fontWeight) || 400 }, fade < 1 ? { opacity: fade } : {}));
      }
    }
  }

  const body = document.body ? document.body.innerText : "";
  const low = body.toLowerCase();
  const disclosure = phrases.filter(p => low.includes(p));
  if (/\bIA\b/.test(body)) disclosure.push("IA");
  if (/\bAI\b/.test(body)) disclosure.push("AI");

  const sources = [...document.scripts].map(s => s.src).filter(Boolean)
    .concat([...document.querySelectorAll("iframe[src]")].map(f => f.src))
    .concat([...new Set([...document.querySelectorAll("*")].map(n => n.tagName.toLowerCase()).filter(t => t.includes("-")))]);

  const vp = document.querySelector('meta[name="viewport"]');
  return {
    page: {
      lang: document.documentElement.getAttribute("lang"),
      title: txt(document.title),
      viewport: vp ? txt(vp.getAttribute("content")) : null,
      dom: document.getElementsByTagName("*").length,
      dupIds: [...ids].filter(([, n]) => n > 1),
      disclosure, truncated,
    },
    surfaces, sources,
  };
}
