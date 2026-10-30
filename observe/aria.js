// SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
// SPDX-License-Identifier: EUPL-1.2
// What the page's markup says of roles, read in the page itself: role values no
// WAI-ARIA 1.2 role answers to, roles set outside the context they require (a browser
// quietly drops such a role, so the tree it builds cannot show them; an element's own
// role, as HTML gives it, counts the same), and controls a
// reader can reach while the page hides them from assistive technology. The tree itself
// is read by the observer through the browser (CDP). Counts only; nothing kept.
([valid, context]) => {
  const roles = new Set(valid);
  const native = { UL: "list", OL: "list", MENU: "list", TABLE: "table", TR: "row", TBODY: "rowgroup", THEAD: "rowgroup",
                   TFOOT: "rowgroup", SELECT: "listbox", DATALIST: "listbox", OPTGROUP: "group", FIELDSET: "group", DETAILS: "group",
                   LI: "listitem", OPTION: "option", TD: "cell", TH: "columnheader" };
  const roleOf = (el) => (el.getAttribute("role") || "").trim().toLowerCase().split(/\s+/)[0] || native[el.tagName] || "";
  const passing = new Set(["", "generic", "none", "presentation"]);
  let misplaced = 0;
  for (const el of document.querySelectorAll("[role], li, option, tr, td, th, tbody, thead, tfoot")) {
    const need = context[roleOf(el)];
    if (!need) continue;
    let up = el.parentElement;
    while (up && passing.has(roleOf(up))) up = up.parentElement;
    if (!up || !need.includes(roleOf(up))) misplaced++;
  }
  const known = (r) => roles.has(r) || /^doc-[a-z]+$/.test(r) || /^graphics-(document|object|symbol)$/.test(r);
  let invalid = 0;
  for (const el of document.querySelectorAll("[role]")) {
    const tokens = el.getAttribute("role").trim().toLowerCase().split(/\s+/).filter(Boolean);
    if (tokens.length && !tokens.some(known)) invalid++;
  }
  // Reachable: what a pointer or a key can act on, rendered and not disabled.
  const reach = "a[href], area[href], button, input:not([type=hidden]), select, textarea, summary, iframe, " +
                "[contenteditable]:not([contenteditable=false]), [tabindex]:not([tabindex='-1'])";
  let hidden = 0;
  for (const el of document.querySelectorAll(reach)) {
    if (el.disabled || !el.getClientRects().length || getComputedStyle(el).visibility === "hidden") continue;
    // A focusable element keeps its role whatever role=none says (WAI-ARIA 1.2, 9.3): only aria-hidden hides it.
    if (el.closest("[aria-hidden=true]")) hidden++;
  }
  return { invalid, misplaced, hidden };
}
