// SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
// SPDX-License-Identifier: EUPL-1.2
// The plié prelude, in JavaScript: what each of its names means, as Plie/Prelude.hs and
// Plie/Prelude.lean say it. Int is a BigInt, Text a string read by code point, Bytes a
// Uint8Array, a list an array, any other value {t: constructor, f: [fields]}. Curried.
import { sha256 as digest } from "../../receipt/verify.js";

const fail = (m) => { throw new Error("plié: " + m); };
const points = (s) => Array.from(s);  // code points, as Haskell's Text and Lean's String count them
export const $Nothing = { t: "Nothing", f: [] };
export const $Just = (x) => ({ t: "Just", f: [x] });
export const $Pair = (a) => (b) => ({ t: "Pair", f: [a, b] });

// equality and order: the same on every value of a type, structural
export function $equal(a, b) {
  if (typeof a === "bigint" || typeof a === "string" || typeof a === "boolean") return a === b;
  if (a instanceof Uint8Array) return b instanceof Uint8Array && a.length === b.length && a.every((x, i) => x === b[i]);
  if (Array.isArray(a)) return Array.isArray(b) && a.length === b.length && a.every((x, i) => $equal(x, b[i]));
  return a.t === b.t && a.f.length === b.f.length && a.f.every((x, i) => $equal(x, b.f[i]));
}
function compare(a, b) {  // Int, Text by code point, Bytes by byte
  if (typeof a === "bigint") return a < b ? -1 : a > b ? 1 : 0;
  const x = typeof a === "string" ? points(a).map((c) => c.codePointAt(0)) : a;
  const y = typeof b === "string" ? points(b).map((c) => c.codePointAt(0)) : b;
  for (let i = 0; i < Math.min(x.length, y.length); i++) if (x[i] !== y[i]) return x[i] < y[i] ? -1 : 1;
  return x.length - y.length < 0 ? -1 : x.length > y.length ? 1 : 0;
}
export const $eq = (a) => (b) => $equal(a, b);
export const $ne = (a) => (b) => !$equal(a, b);
export const $lt = (a) => (b) => compare(a, b) < 0;
export const $le = (a) => (b) => compare(a, b) <= 0;
export const $gt = (a) => (b) => compare(a, b) > 0;
export const $ge = (a) => (b) => compare(a, b) >= 0;
export const $add = (a) => (b) => a + b;
export const $sub = (a) => (b) => a - b;
export const $mul = (a) => (b) => a * b;
export const $cons = (x) => (xs) => [x, ...xs];
export const $append = (a) => (b) => {
  if (typeof a === "string") return a + b;
  if (a instanceof Uint8Array) { const o = new Uint8Array(a.length + b.length); o.set(a); o.set(b, a.length); return o; }
  return a.concat(b);
};

// Int
export const $div = (a) => (b) => { if (b === 0n) fail("division by zero"); const q = a / b; return (a % b !== 0n && (a < 0n) !== (b < 0n)) ? q - 1n : q; };
export const $mod = (a) => (b) => a - b * $div(a)(b);
export const $abs = (a) => (a < 0n ? -a : a);
export const $min = (a) => (b) => (a < b ? a : b);
export const $max = (a) => (b) => (a > b ? a : b);
export const $not = (a) => !a;
export const $showInt = (a) => a.toString();
export const $readInt = (t) => (/^[0-9]+$/.test(t) ? $Just(BigInt(t)) : $Nothing);

// lists
export const $length = (xs) => BigInt(xs.length);
export const $map = (f) => (xs) => xs.map((x) => f(x));
export const $filter = (f) => (xs) => xs.filter((x) => f(x));
export const $foldl = (f) => (z) => (xs) => xs.reduce((acc, x) => f(acc)(x), z);
export const $reverse = (xs) => [...xs].reverse();
export const $take = (n) => (xs) => (n <= 0n ? [] : xs.slice(0, Number(n)));
export const $drop = (n) => (xs) => (n <= 0n ? xs : xs.slice(Number(n)));
export const $sum = (xs) => xs.reduce((a, b) => a + b, 0n);
export const $all = (f) => (xs) => xs.every((x) => f(x));
export const $any = (f) => (xs) => xs.some((x) => f(x));
export const $elem = (x) => (xs) => xs.some((y) => $equal(x, y));
export const $concat = (xss) => [].concat(...xss);
export const $range = (a) => (b) => { const o = []; for (let i = a; i < b; i++) o.push(i); return o; };
export const $zip = (a) => (b) => a.slice(0, Math.min(a.length, b.length)).map((x, i) => $Pair(x)(b[i]));
export const $nth = (i) => (xs) => (i >= 0n && i < BigInt(xs.length) ? $Just(xs[Number(i)]) : $Nothing);
export const $sortBy = (lt) => (xs) => xs.map((x, i) => [x, i]).sort((p, q) => (lt(p[0])(q[0]) ? -1 : lt(q[0])(p[0]) ? 1 : p[1] - q[1])).map((p) => p[0]);
export const $fromMaybe = (d) => (m) => (m.t === "Just" ? m.f[0] : d);
export const $fst = (p) => p.f[0];
export const $snd = (p) => p.f[1];

// Text
export const $textLength = (t) => BigInt(points(t).length);
export const $utf8 = (t) => new TextEncoder().encode(t);
export const $split = (sep) => (t) => (sep === "" ? [t] : t.split(sep));
export const $startsWith = (p) => (t) => t.startsWith(p);
export const $endsWith = (s) => (t) => t.endsWith(s);
export const $asciiLower = (t) => t.replace(/[A-Z]/g, (c) => c.toLowerCase());
export const $joinText = (sep) => (xs) => xs.join(sep);
export const $trim = (t) => t.replace(/^[ \t\n\r]+|[ \t\n\r]+$/g, "");
export const $jsonQuote = (t) => '"' + points(t).map((c) => {
  const n = c.codePointAt(0);
  if (c === '"') return '\\"';
  if (c === "\\") return "\\\\";
  const short = { 8: "\\b", 9: "\\t", 10: "\\n", 12: "\\f", 13: "\\r" }[n];
  if (short) return short;
  return n < 0x20 ? "\\u00" + n.toString(16).padStart(2, "0") : c;
}).join("") + '"';
export const $ltUtf16 = (a) => (b) => a < b;  // JavaScript compares strings by UTF-16 code unit, as RFC 8785 orders keys

// Bytes
export const $sha256 = (b) => digest(b);
export const $byte = (n) => new Uint8Array([Number(((n % 256n) + 256n) % 256n)]);
export const $be64 = (n) => { const o = new Uint8Array(8); let x = ((n % (1n << 64n)) + (1n << 64n)) % (1n << 64n); for (let i = 7; i >= 0; i--) { o[i] = Number(x & 255n); x >>= 8n; } return o; };
export const $hex = (b) => Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");
export const $unhex = (t) => (/^([0-9a-fA-F]{2})*$/.test(t) ? $Just(Uint8Array.from(t.match(/../g) || [], (h) => parseInt(h, 16))) : $Nothing);
export const $bytesLength = (b) => BigInt(b.length);
