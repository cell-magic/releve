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

  // The name assistive technology is given, and where it comes from.
  function naming(el) {
    const from = (by, t) => (t = txt(t)) ? [t, by] : null;
    const lb = el.getAttribute("aria-labelledby");
    const given = (lb && from("aria-labelledby", byIds(lb))) || from("aria-label", el.getAttribute("aria-label"));
    if (given) return given;
    const tag = el.tagName.toLowerCase(), title = () => from("title", el.title) || ["", null];
    if (tag === "img" || (tag === "input" && el.type === "image")) return from("alt", el.getAttribute("alt")) || title();
    if (tag === "svg") { const t = el.querySelector("title"); return from("content", t && t.textContent) || title(); }
    if (tag === "iframe" || tag === "frame") return title();
    if (tag === "input" && ["submit", "reset", "button"].includes(el.type))
      return from("value", el.value) || [el.type === "button" ? "" : el.type, null]; // browsers label submit/reset by default
    if (["input", "select", "textarea"].includes(tag))
      return from("label", el.labels ? [...el.labels].map(x => x.innerText).join(" ") : "") || title();
    return from("content", el.innerText)
      || from("content", [...el.querySelectorAll("img[alt], [aria-label], svg title")]
        .map(n => n.getAttribute("alt") || n.getAttribute("aria-label") || n.textContent).join(" "))
      || title();
  }
  const accName = el => naming(el)[0];

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

  // What each event says, weighed in bits by an adaptive code of the page's own words, read in
  // order: a word already used costs the logarithm of its rarity so far; a new word costs the
  // surprise of novelty and five bits a letter. The text itself is kept as an extract only.
  const used = new Map();
  let read = 0;
  const weigh = said => {
    const words = said.toLowerCase().split(/[^\p{L}\p{N}]+/u).filter(Boolean);
    let bits = 0;
    for (const w of words) {
      const c = used.get(w), v = used.size;
      bits += c ? Math.log2((read + v) / c) : (v ? Math.log2((read + v) / v) : 0) + 5 * ([...w].length + 1);
      used.set(w, (c || 0) + 1);
      read++;
    }
    return [words.length, Math.round(bits * 1000) / 1000];
  };
  // The event an element belongs to: its own, the first inside it, or the one around it.
  function eventAt(el) {
    let e = eventOf.get(el);
    if (!e) for (const [k, x] of eventOf) if (el.contains(k)) { e = x; break; }
    for (let n = el.parentElement; !e && n; n = n.parentElement) e = eventOf.get(n);
    return e ? e.n : null;
  }
  const events = stream.map(e => {
    const el = e.el, cs = getComputedStyle(el), r = el.getBoundingClientRect();
    const said = e.kind ? e.name : txt(e.words.join(" ")), [words, bits] = weigh(said);
    const hd = el.closest("h1, h2, h3, h4, h5, h6, [role=heading]");
    const cell = el.closest("th, td, caption, [role=columnheader], [role=rowheader], [role=cell], [role=gridcell]");
    const label = e.kind === "field" && el.labels && el.labels[0] ? eventAt(el.labels[0]) : null;
    return Object.assign({
      n: e.n, sel: path(el), kind: e.kind || (e.text ? "text" : "image"), shown: e.shown, said: clip(said), words, bits,
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
      add("img", { alt: el.hasAttribute("alt") ? clip(el.getAttribute("alt")) : null, src: el.currentSrc || el.src, lazy: el.loading === "lazy",
                   natural: [el.naturalWidth, el.naturalHeight] });
    else if ((tag === "svg" && role === "img") || (role === "img" && tag !== "svg"))
      add("graphic", { name: clip(accName(el)) });
    if (tag === "iframe" || tag === "frame") add("iframe", { name: clip(accName(el)) });
    if (tag === "video" || tag === "audio")
      add("media", { autoplay: el.autoplay, muted: el.muted || el.hasAttribute("muted"), itype: tag, controls: el.controls,
                     tracks: [...el.querySelectorAll("track")].map(t => t.kind) });
    if (((tag === "a" && el.hasAttribute("href")) || role === "link") && role !== "button") {
      const [name, by] = naming(el);
      add("link", { name: clip(name), by, label: clip(el.innerText), href: el.href ? String(el.href).slice(0, 300) : null });
    }
    if (tag === "button" || role === "button" || (tag === "input" && ["submit", "reset", "button", "image"].includes(el.type))) {
      const [name, by] = naming(el);
      add("button", { name: clip(name), by, label: clip(tag === "input" ? el.value : el.innerText) });
    }
    if ((tag === "input" && !["hidden", "submit", "reset", "button", "image"].includes(el.type))
        || tag === "select" || tag === "textarea" || role === "textbox" || role === "combobox") {
      const [name, by] = naming(el);
      add("control", { name: clip(name), by, label: clip(el.labels ? [...el.labels].map(x => x.innerText).join(" ") : ""),
                       itype: el.type || tag, placeholder: el.hasAttribute("placeholder") ? clip(el.getAttribute("placeholder")) : null,
                       auto: el.getAttribute("autocomplete"), hint: clip([el.getAttribute("name"), el.id].filter(Boolean).join(" ")),
                       set: ["radio", "checkbox"].includes(el.type) ? el.getAttribute("name") : null,
                       grouped: !!el.closest('fieldset, [role="group"], [role="radiogroup"]') });
    }
    if (tag === "fieldset" || role === "group" || role === "radiogroup") {
      const legend = tag === "fieldset" && [...el.children].find(c => c.tagName === "LEGEND");
      add("group", { name: clip(naming(el)[1] && /^aria/.test(naming(el)[1]) ? accName(el) : legend && legend.innerText) });
    }
    if ((tag === "table" && !el.closest("svg")) || role === "table" || role === "grid") {
      const mine = q => [...el.querySelectorAll(q)].filter(n => n.closest('table, [role="table"], [role="grid"]') === el);
      const rows = mine('tr, [role="row"]'), heads = mine('th, [role="columnheader"], [role="rowheader"]');
      const top = rows[0] ? heads.filter(h => rows[0].contains(h)).length : 0;
      const caption = mine("caption")[0];
      add("table", {
        name: clip(naming(el)[1] && /^aria/.test(naming(el)[1]) ? accName(el) : caption && caption.innerText),
        rows: rows.length, cols: Math.max(0, ...rows.map(r => [...r.children].reduce((n, c) => n + (c.colSpan || 1), 0))),
        heads: heads.length, across: top > 0 && heads.length > top,
        bare: heads.filter(h => !h.hasAttribute("scope") && !h.id && !h.getAttribute("role")).length,
        marks: mine("caption, thead, tfoot, th, [scope], [headers]").length + (el.hasAttribute("summary") ? 1 : 0),
      });
    }
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

  // Markup that only styles: the tags and attributes HTML has left to style sheets.
  const html5 = !!document.doctype && document.doctype.name.toLowerCase() === "html" && !document.doctype.publicId;
  const TAGS = ["basefont", "big", "blink", "center", "font", "marquee", "s", "strike", "tt"].concat(html5 ? [] : ["u"]);
  const ATTRS = ["align", "alink", "background", "bgcolor", "border", "cellpadding", "cellspacing", "char", "charoff", "clear",
                 "color", "compact", "frameborder", "hspace", "link", "marginheight", "marginwidth", "text", "valign", "vlink", "vspace"];
  const SIZED = ["img", "object", "embed", "canvas", "svg"];
  const styling = new Map(), tally = k => styling.set(k, (styling.get(k) || 0) + 1);
  const all = document.body ? [document.body, ...document.body.querySelectorAll("*")] : [];
  for (const n of all) {
    if (n.namespaceURI !== "http://www.w3.org/1999/xhtml") continue;
    const tag = n.tagName.toLowerCase();
    if (TAGS.includes(tag)) tally(tag);
    for (const a of ATTRS) if (n.hasAttribute(a)) tally("@" + a);
    if (n.hasAttribute("size") && tag !== "select") tally("@size");
    for (const a of ["width", "height"]) if (n.hasAttribute(a) && !SIZED.includes(tag)) tally("@" + a);
  }

  // Elements that hold nothing: a paragraph or a heading used as a gap.
  const bare = n => !txt(n.textContent) && !n.querySelector("img, svg, input, button, select, textarea, iframe, video, audio, object, canvas")
    && n.getClientRects().length > 0 && !["presentation", "none"].includes(n.getAttribute("role"));
  const empties = [["p", "p"], ["heading", "h1, h2, h3, h4, h5, h6"]]
    .map(([k, q]) => [k, [...document.querySelectorAll(q)].filter(bare).length]).filter(([, n]) => n > 0);

  const FOCUS = 'a[href], button:not([disabled]), input:not([type="hidden"]):not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex^="-"])';
  const some = list => list.slice(0, 20).map(path);
  const tabbed = some(all.filter(n => parseInt(n.getAttribute("tabindex")) > 0));
  const hiddenFocus = some([...document.querySelectorAll('[aria-hidden="true"]')]
    .flatMap(h => [h, ...h.querySelectorAll("*")]).filter(n => n.matches(FOCUS) && n.getClientRects().length > 0 && getComputedStyle(n).visibility !== "hidden"));

  // A link that leads to the main content, or past what stands before it.
  const mains = [...document.querySelectorAll('main, [role="main"]')].filter(n => n.getClientRects().length > 0);
  const before = mains[0] ? [...document.querySelectorAll(FOCUS)].filter(n => n.getClientRects().length > 0
    && (n.compareDocumentPosition(mains[0]) & Node.DOCUMENT_POSITION_FOLLOWING) && !n.contains(mains[0])).length : 0;
  let skip = null;
  if (mains[0]) for (const a of [...document.querySelectorAll('a[href^="#"]')].slice(0, 12)) {
    const id = decodeURIComponent(a.getAttribute("href").slice(1)), t = id && document.getElementById(id);
    if (t && (a.compareDocumentPosition(mains[0]) & Node.DOCUMENT_POSITION_FOLLOWING)
        && (t === mains[0] || mains[0].contains(t) || t.contains(mains[0]) || t.nextElementSibling === mains[0])) {
      skip = clip(accName(a)) || "#" + id;
      break;
    }
  }

  // Languages within the page: every element that declares one other than the page's.
  const own = (document.documentElement.getAttribute("lang") || "").trim().toLowerCase();
  const langs = [...document.querySelectorAll("body [lang], body [xml\\:lang]")]
    .map(n => [path(n), (n.getAttribute("lang") || n.getAttribute("xml:lang") || "").trim()])
    .filter(([, l]) => l.toLowerCase() !== own).slice(0, 30);

  // Text in a right-to-left script, and whether anything declares the direction.
  const said = (document.body ? document.body.innerText : "").slice(0, 200000);
  const rtl = { chars: (said.match(/[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]/g) || []).length,
                marked: !!document.querySelector('[dir="rtl" i], bdo') };
  const emoji = (said.match(/\p{Extended_Pictographic}/gu) || []).length;

  // Words set by the style sheet alone, before or after an element: lost when styles are off.
  const generated = [];
  for (const n of all) {
    if (generated.length >= 20) break;
    if (!rendered(n)) continue;
    for (const at of ["::before", "::after"]) {
      const c = getComputedStyle(n, at).content;
      if (c && c !== "none" && c !== "normal" && /^["'].*[\p{L}\p{N}].*["']$/u.test(c)) { generated.push([path(n), clip(c.slice(1, -1))]); break; }
    }
  }

  // Text whose colour is set while no background is, on it or around it.
  // A colour the author set: not the browser's own black, nor its blue and purple for links.
  const inked = (c, el) => { const [r, g, b] = rgba(c); const k = r + "," + g + "," + b;
    return k !== "0,0,0" && !(el.closest("a[href]") && (k === "0,0,238" || k === "85,26,139")); };
  const grounded = el => { for (let n = el; n && n.nodeType === 1; n = n.parentElement) {
      const cs = getComputedStyle(n); if (rgba(cs.backgroundColor)[3] > 0 || (cs.backgroundImage && cs.backgroundImage !== "none")) return true; }
    return false; };
  const unpaired = [];
  for (const n of all) {
    if (unpaired.length >= 20) break;
    if (![...n.childNodes].some(c => c.nodeType === 3 && c.textContent.trim()) || !rendered(n)) continue;
    if (inked(getComputedStyle(n).color, n) && !grounded(n)) unpaired.push(path(n));
  }

  // Links set within running text that differ from it neither by underline, nor border, nor a contrast of 3:1.
  const lum = ([r, g, b]) => { const f = v => (v /= 255) <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b); };
  const ratio = (a, b) => { const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); };
  const blended = [];
  for (const a of document.querySelectorAll("p a[href], li a[href], td a[href], dd a[href]")) {
    if (blended.length >= 20) break;
    const host = a.parentElement;
    if (!rendered(a) || ![...host.childNodes].some(c => c !== a && c.nodeType === 3 && c.textContent.trim())) continue;
    const ca = getComputedStyle(a), ch = getComputedStyle(host);
    const marked = /underline/.test(ca.textDecorationLine) || parseFloat(ca.borderBottomWidth) > 0 || /underline/.test(ch.textDecorationLine)
      || parseInt(ca.fontWeight) - parseInt(ch.fontWeight) >= 300 || ca.fontStyle !== ch.fontStyle;
    if (!marked && ratio(rgba(ca.color), rgba(ch.color)) < 3) blended.push(path(a));
  }

  // What the pointer can click and the keyboard cannot reach: a pointer cursor on an element no key can focus.
  const reachable = n => n.matches(FOCUS) || !!n.closest("a[href], button, label, summary, select, input, textarea, [tabindex]");
  const clickable = [];
  for (const n of all) {
    if (clickable.length >= 20) break;
    if (!rendered(n) || reachable(n) || n.querySelector(FOCUS)) continue;
    const pointer = getComputedStyle(n).cursor === "pointer" && (!n.parentElement || getComputedStyle(n.parentElement).cursor !== "pointer");
    if (n.hasAttribute("onclick")) clickable.push([path(n), "handler"]);
    else if (pointer) clickable.push([path(n), "pointer"]);
  }

  // What moves by itself without end: looping animations on what is shown, marquees, looping videos that play alone.
  const looping = (document.getAnimations ? document.getAnimations() : [])
    .filter(x => x.effect && x.effect.getComputedTiming().iterations === Infinity && x.playState === "running"
            && x.effect.target && x.effect.target.nodeType === 1 && rendered(x.effect.target))
    .map(x => path(x.effect.target));
  const moving = [...new Set([...looping, ...[...document.querySelectorAll("marquee, blink, video[autoplay][loop]")].filter(rendered).map(path)])].slice(0, 20);

  // How much script the page carries in its markup: script elements that run, handlers written as attributes,
  // and javascript: links. Scripts fetched from elsewhere are also in the network record.
  const RUNS = /^((text|application)\/(x-)?(java|ecma)script|module)$/i;
  const scripted = [...document.scripts].filter(x => !x.type.trim() || RUNS.test(x.type.trim())).length
    + [...document.querySelectorAll("*")].filter(n => [...n.attributes].some(a => a.name.startsWith("on"))).length
    + document.querySelectorAll('a[href^="javascript:" i]').length;

  // The style sheets written into the page, as one digest (cyrb53): with the files it loads, what makes its template.
  const digest = text => {
    let h1 = 0xdeadbeef, h2 = 0x41c6ce57;
    for (let i = 0; i < text.length; i++) {
      const c = text.charCodeAt(i);
      h1 = Math.imul(h1 ^ c, 2654435761); h2 = Math.imul(h2 ^ c, 1597334677);
    }
    h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
    h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
    return (h2 >>> 0).toString(16).padStart(8, "0") + (h1 >>> 0).toString(16).padStart(8, "0");
  };
  const inline = digest([...document.querySelectorAll("style")].map(x => x.textContent).join("\n"));

  // A prompt for consent to cookies and trackers, as it stands on arrival, and the choices it offers at once:
  // each with what it does, whether it is a link or a button, its area and its look. The observer consents to nothing.
  const deep = (root, sel) => [...root.querySelectorAll(sel),
    ...[...(root.shadowRoot ? [root.shadowRoot] : []), ...[...root.querySelectorAll("*")].filter(n => n.shadowRoot).map(n => n.shadowRoot)].flatMap(r => deep(r, sel))];
  const up = n => n.parentElement || (n.getRootNode && n.getRootNode().host) || null;
  const CMP = [["didomi"], ["onetrust", /onetrust|optanon|cookielaw/], ["axeptio"], ["cookiebot", /cookiebot|cybot/], ["tarteaucitron"], ["usercentrics"],
    ["quantcast", /qc-cmp/], ["sourcepoint", /sp_message|sp-cc/], ["trustarc", /trustarc|truste/], ["iubenda"], ["complianz", /cmplz/], ["cookieyes", /cky-|cookieyes/],
    ["osano"], ["klaro"], ["orejime"], ["borlabs"], ["termly"]].map(([v, re]) => [v, re || new RegExp(v)]);
  const vendorOf = s => (CMP.find(([, re]) => re.test(s.toLowerCase())) || [null])[0];
  const signOf = n => [n.id, typeof n.className === "string" ? n.className : "", n.getAttribute("aria-label"), n.tagName === "IFRAME" ? n.src + " " + n.title + " " + n.name : ""].join(" ");
  const ABOUT = /cookie|consent|tracker|traceur|témoin|vie privée|confidentialité|datenschutz|einwilligung|consentimiento|privacidad|consenso|riservatezza/i;
  const fixedish = n => { for (let x = n; x && x.nodeType === 1; x = up(x)) if (/fixed|sticky/.test(getComputedStyle(x).position)) return true; return false; };
  const told = n => (n.innerText || "") + " " + (n.shadowRoot ? n.shadowRoot.textContent : "");
  const KINDS = [
    ["reject", /reject|refuse|decline|deny|disagree|no,? thanks|(only|just) (the )?(necessary|essential|required)|(necessary|essential|required)( cookies)? only|without accept|refuser|continuer sans|non merci|ablehnen|nein danke|nur (notwendige|erforderliche|essenzielle)|rechaz|rifiut|solo (necessari|essenziali)/i],
    ["settings", /setting|preference|customi[sz]|manage|option|choose|choice|details|more info|learn more|paramètr|paramétr|personnalis|gérer|préférence|choisir|en savoir plus|einstellung|anpassen|verwalten|configur|preferencia|personaliz|gestisci|impostazion/i],
    ["accept", /accept|agree|allow|consent|got it|^ok\b|okay|understand|accepter|j'accepte|d'accord|autoriser|akzeptier|zustimm|einverstanden|erlauben|acept|accett/i]];
  const ground = n => { for (let x = n; x && x.nodeType === 1; x = up(x)) { const c = rgba(getComputedStyle(x).backgroundColor); if (c[3] > 0.5) return c; } return [255, 255, 255, 1]; };
  const lookOf = el => { const cs = getComputedStyle(el), b = rgba(cs.backgroundColor), g = up(el) ? ground(up(el)) : [255, 255, 255, 1];
    if ((b[3] > 0.5 && b.slice(0, 3).some((v, i) => Math.abs(v - g[i]) > 8)) || cs.backgroundImage !== "none") return "filled";
    return parseFloat(cs.borderTopWidth) > 0 && cs.borderTopStyle !== "none" && rgba(cs.borderTopColor)[3] > 0 ? "outlined" : "plain"; };
  const choicesOf = box => deep(box, 'button, a[href], [role="button"], input[type="button"], input[type="submit"]').filter(rendered).flatMap(el => {
    const nm = txt(accName(el) || el.value), k = KINDS.find(([, re]) => re.test(nm)), r = el.getBoundingClientRect();
    return k ? [[k[0], el.tagName === "A" && el.getAttribute("role") !== "button" ? "link" : "button", clip(nm), Math.round(r.width * r.height), lookOf(el)]] : []; });
  const consent = (() => {
    const boxes = deep(document, "[id], [class], [role], dialog, [aria-modal]").filter(n => {
      const sign = signOf(n), named = /cookie|consent|gdpr|rgpd|privacy/i.test(sign) || vendorOf(sign);
      return !/^(HTML|BODY|MAIN)$/.test(n.tagName) && (named || n.matches('[role="dialog"], [role="alertdialog"], dialog[open], [aria-modal="true"]')) && rendered(n)
        && ABOUT.test(told(n)) && told(n).length < 4000 && (vendorOf(sign) || fixedish(n) || n.matches('dialog, [role="dialog"], [role="alertdialog"]')); })
      .map(n => ({ n, cs: choicesOf(n), k: 0, w: told(n).length })).filter(x => x.cs.length);
    for (const x of boxes) x.k = new Set(x.cs.map(c => c[0])).size;
    const vendor = n => { for (let x = n; x; x = up(x)) { const v = vendorOf(signOf(x)); if (v) return v; } return null; };
    if (boxes.length) {
      const best = boxes.reduce((a, b) => b.k > a.k || (b.k === a.k && b.w < a.w) ? b : a);   // every kind of choice, in the least text
      return { prompt: true, cmp: vendor(best.n), framed: false, choices: best.cs };
    }
    const frame = [...document.querySelectorAll("iframe")].find(f => rendered(f) && (vendorOf(signOf(f)) || /consent|cookie|privacy-mgmt/i.test(signOf(f))));
    return frame ? { prompt: true, cmp: vendorOf(signOf(frame)), framed: true, choices: [] } : { prompt: false };
  })();

  const vp = document.querySelector('meta[name="viewport"]');
  const refresh = document.querySelector('meta[http-equiv="refresh" i]');
  return {
    page: {
      lang: document.documentElement.getAttribute("lang"),
      title: clip(document.title),
      viewport: vp ? txt(vp.getAttribute("content")) : null,
      dom: document.getElementsByTagName("*").length,
      dupIds: [...ids].filter(([, n]) => n > 1),
      disclosure, truncated,
      doctype: document.doctype ? txt(document.doctype.name + " " + document.doctype.publicId) : null,
      styling: [...styling], empties, tabbed, hiddenFocus, skip, before, mains: mains.length,
      refresh: refresh ? txt(refresh.getAttribute("content")) : null,
      opened: window.__opened || 0, asked: window.__asked || [],
      langs, rtl, emoji, generated, unpaired, blended, clickable, moving, scripted, inline, consent,
    },
    surfaces, events, sources,
  };
}
