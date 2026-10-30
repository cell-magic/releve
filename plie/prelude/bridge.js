// SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
// SPDX-License-Identifier: EUPL-1.2
// Where plié meets the world, in JavaScript: JSON in, a function from Json to Json called by
// name, its answer out as canonical text (RFC 8785). A number that is not an integer is refused.
const J = (t, ...f) => ({ t, f });
export function json(v) {
  if (v === null) return J("JNull");
  if (typeof v === "boolean") return J("JBool", v);
  if (typeof v === "number") { if (!Number.isSafeInteger(v)) throw new Error("plié: a number that is not an integer"); return J("JInt", BigInt(v)); }
  if (typeof v === "string") return J("JText", v);
  if (Array.isArray(v)) return J("JList", v.map(json));
  return J("JObj", Object.keys(v).map((k) => ({ t: "Pair", f: [k, json(v[k])] })));
}
// Json back to plain JavaScript, for a page to read.
export function plain(j) {
  const [x] = j.f;
  switch (j.t) {
    case "JNull": return null;
    case "JBool": case "JText": return x;
    case "JInt": return Number(x);
    case "JList": return x.map(plain);
    default: return Object.fromEntries(x.map((p) => [p.f[0], plain(p.f[1])]));
  }
}
// The named function of a compiled module on a JSON text, its answer as canonical text.
export function call(mod, name, text) {
  const f = mod.entries[name];
  if (!f) throw new Error("plié: no such function " + name);
  return mod.$canonical(f(json(JSON.parse(text))));
}
