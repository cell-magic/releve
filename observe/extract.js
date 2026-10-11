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

  // The reading sequence: one event for each thing the page gives its reader to take in at once.
  // A block of running text, an image, a field, a button, a player, a frame. Each says how it is
  // given: shown to the eye, said to assistive technology, both, or declared to carry nothing.
  const FIELDS = new Set(["textbox", "searchbox", "combobox", "listbox", "checkbox", "radio", "switch", "slider", "spinbutton"]);
  const SEALED = new Set(["svg", "select", "textarea", "iframe", "frame", "video", "audio", "object", "canvas"]);
  const CONTAINERS = { ol: "olist", ul: "list", menu: "list", dl: "list", li: "item", table: "table", tr: "row", form: "form" };
  const shows = new Map(), holders = new Map(), boxes = new Map();
  const display = n => { let d = shows.get(n); if (d === undefined) shows.set(n, d = getComputedStyle(n).display); return d; };
  const number = n => { let i = boxes.get(n); if (i === undefined) boxes.set(n, i = boxes.size); return i; };
  const quiet = n => !!n.closest('[aria-hidden="true"]');

  function atom(n) {
    const tag = n.tagName.toLowerCase(), role = n.getAttribute("role");
    if (tag === "button" || role === "button" || (tag === "input" && ["submit", "reset", "button", "image"].includes(n.type))) return "button";
    if ((tag === "input" && n.type !== "hidden") || tag === "select" || tag === "textarea" || FIELDS.has(role)) return "field";
    if (tag === "video" || tag === "audio") return "media";
    if (tag === "iframe" || tag === "frame") return "frame";
    return null;
  }

  // A box that breaks the line it stands in. An inline box, and one set inside a line, do not.
  const breaks = n => !/^(inline|contents|ruby)/.test(display(n));

  // The element whose event a node belongs to: the outermost control around it,
  // or else the innermost box that lays its text out in lines.
  function holder(el) {
    if (holders.has(el)) return holders.get(el);
    let block = null, held = null;
    for (let n = el; n && n !== document.documentElement; n = n.parentElement) {
      if (atom(n)) held = n;
      if (!block && breaks(n)) block = n;
    }
    const h = held || block || document.body;
    holders.set(el, h);
    return h;
  }

  const rendered = n => n.getClientRects().length > 0 && getComputedStyle(n).visibility !== "hidden";

  // Shown to the eye: not clipped away, not moved off the page, not transparent.
  function visible(el, upto) {
    for (let n = el; n; n = n.parentElement) {
      const r = n.getBoundingClientRect();
      if ((r.width <= 1 || r.height <= 1) && getComputedStyle(n).overflow !== "visible") return false;
      if (r.right + scrollX <= 0 || r.bottom + scrollY <= 0) return false;
      if (n === upto) break;
    }
    return opacity(el) > 0.01;
  }

  function place(el) {
    const steps = [];
    for (let n = el; n && n !== document.documentElement; n = n.parentElement) {
      const tag = n.tagName.toLowerCase(), role = n.getAttribute("role");
      if (role === "presentation" || role === "none") continue;
      let kind = role && LANDMARKS.has(role) ? role : ROLES[tag] || CONTAINERS[tag]
        || (role === "list" ? "list" : role === "listitem" ? "item" : role === "form" ? "form"
          : role === "table" || role === "grid" ? "table" : role === "row" ? "row" : null);
      let of = n;
      if (tag === "dt" || tag === "dd") {  // a term and what is said of it are one item
        kind = "item";
        while (of.tagName === "DD" && of.previousElementSibling) of = of.previousElementSibling;
      }
      if (kind) steps.unshift([kind, number(of)]);
    }
    return steps;
  }

  // A box's loose text is one event for each run of it: a box in its midst ends the run.
  const stream = [], open = new Map(), eventOf = new Map(), begun = new Set(), sealed = new Set();
  const event = (h, from) => {
    let e = open.get(h);
    if (!e) {
      e = { el: begun.has(h) ? from : h, kind: atom(h), words: [], text: false, shown: false, unsaid: false };
      begun.add(h); open.set(h, e); stream.push(e);
    }
    eventOf.set(from, e);
    if (!eventOf.has(h)) eventOf.set(h, e);
    return e;
  };
  const walker = document.body && document.createTreeWalker(document.body, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT, {
    acceptNode(n) {
      if (sealed.has(n.parentNode)) return NodeFilter.FILTER_REJECT;
      if (n.nodeType === 3) return NodeFilter.FILTER_ACCEPT;
      const tag = n.tagName.toLowerCase();
      if (["script", "style", "noscript", "template"].includes(tag) || display(n) === "none") return NodeFilter.FILTER_REJECT;
      if (SEALED.has(tag)) sealed.add(n);
      if (breaks(n) && n.parentElement && !atom(n)) open.delete(holder(n.parentElement));
      return NodeFilter.FILTER_ACCEPT;
    },
  });
  let truncated = false;
  for (let n = walker && walker.nextNode(); n; n = walker.nextNode()) {
    if (stream.length >= limit) { truncated = true; break; }
    if (n.nodeType === 3) {
      const t = txt(n.textContent);
      let p = n.parentElement;
      while (display(p) === "contents" && p.parentElement) p = p.parentElement;  // a box-less wrapper shows through its parent
      if (!t || !rendered(p)) continue;
      const h = holder(p), e = event(h, p);
      e.text = true;
      if (visible(p, h)) e.shown = true;
      if (!quiet(p)) e.words.push(t);
      continue;
    }
    const tag = n.tagName.toLowerCase(), role = n.getAttribute("role");
    const picture = tag === "img" || tag === "svg" || tag === "canvas" || role === "img";
    if (!(picture || atom(n)) || !rendered(n)) continue;
    const h = holder(n), e = event(h, n);
    if (h === n && e.kind) {
      e.shown = visible(n, n);
      e.name = quiet(n) ? "" : accName(n);
      e.unsaid = !e.name && !quiet(n);
    } else if (picture && !e.kind) {
      const name = accName(n);
      const mute = quiet(n) || role === "presentation" || role === "none"
        || (tag === "img" && n.hasAttribute("alt") && !name) || (tag === "svg" && role !== "img" && !name);
      if (visible(n, h)) e.shown = true;
      if (!mute && name) e.words.push(name);
      if (!mute && !name) e.unsaid = true;
    }
  }
  stream.forEach((e, i) => { e.n = i; });
  // The event an element belongs to: its own, the first inside it, or the one around it.
  function eventAt(el) {
    let e = eventOf.get(el);
    if (!e) for (const [k, x] of eventOf) if (el.contains(k)) { e = x; break; }
    for (let n = el.parentElement; !e && n; n = n.parentElement) e = eventOf.get(n);
    return e ? e.n : null;
  }
  const events = stream.map(e => {
    const el = e.el, cs = getComputedStyle(el), r = el.getBoundingClientRect();
    const said = (e.kind ? e.name : txt(e.words.join(" "))).slice(0, 2000);
    const hd = el.closest("h1, h2, h3, h4, h5, h6, [role=heading]");
    const cell = el.closest("th, td, caption, [role=columnheader], [role=rowheader], [role=cell], [role=gridcell]");
    const label = e.kind === "field" && el.labels && el.labels[0] ? eventAt(el.labels[0]) : null;
    return Object.assign({
      n: e.n, sel: path(el), kind: e.kind || (e.text ? "text" : "image"), shown: e.shown, said,
      path: place(el), box: [Math.round(r.x + scrollX), Math.round(r.y + scrollY), Math.round(r.width), Math.round(r.height)],
      size: parseFloat(cs.fontSize), weight: parseInt(cs.fontWeight) || 400,
    }, !said && !e.unsaid ? { quiet: true } : {},
       hd ? { level: hd.getAttribute("role") === "heading" ? parseInt(hd.getAttribute("aria-level")) || 2 : +hd.tagName[1] } : {},
       cell ? { cell: cell.tagName === "CAPTION" ? "caption" : /^(TH)$/.test(cell.tagName) || /header$/.test(cell.getAttribute("role") || "") ? "head" : "data" } : {},
       label !== null && label !== e.n ? { label } : {});
  });
  const surfaces = [];
  let order = 0;

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
      sel: path(el), order, role, ev: eventAt(el),
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
    surfaces, events, sources,
  };
}
