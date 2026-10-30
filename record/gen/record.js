// SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
// SPDX-License-Identifier: EUPL-1.2
// Written by plie/plie.py. Do not edit: edit the sources.
import { $abs, $add, $all, $any, $append, $asciiLower, $be64, $byte, $bytesLength, $concat, $cons, $div, $drop, $elem, $endsWith, $eq, $filter, $foldl, $fromMaybe, $fst, $ge, $gt, $hex, $joinText, $jsonQuote, $le, $length, $lt, $ltUtf16, $map, $max, $min, $mod, $mul, $ne, $not, $nth, $range, $readInt, $reverse, $sha256, $showInt, $snd, $sortBy, $split, $startsWith, $sub, $sum, $take, $textLength, $trim, $unhex, $utf8, $zip } from "../../plie/prelude/plie.js";
// ---- Json
export const $field = $k => $j => ((s) => { if (s.t === "JObj") { const $fs = s.f[0]; return $fieldIn($k)($fs); } if (true) { return {t: "JNull", f: []}; } throw new Error("plié: no alternative matches"); })($j);
export const $fieldIn = $k => $fs => ((s) => { if (s.length === 0) { return {t: "JNull", f: []}; } if (s.length > 0) { const $f = s[0]; const $rest = s.slice(1); return ($eq($fst($f))($k) ? $snd($f) : $fieldIn($k)($rest)); } throw new Error("plié: no alternative matches"); })($fs);
export const $has = $k => $j => ((s) => { if (s.t === "JObj") { const $fs = s.f[0]; return $any(($f => $eq($fst($f))($k)))($fs); } if (true) { return false; } throw new Error("plié: no alternative matches"); })($j);
export const $path = $ks => $j => $foldl(($x => $k => $field($k)($x)))($j)($ks);
export const $asInt = $j => ((s) => { if (s.t === "JInt") { const $n = s.f[0]; return $n; } if (true) { return 0n; } throw new Error("plié: no alternative matches"); })($j);
export const $asText = $j => ((s) => { if (s.t === "JText") { const $t = s.f[0]; return $t; } if (true) { return ""; } throw new Error("plié: no alternative matches"); })($j);
export const $asBool = $j => ((s) => { if (s.t === "JBool") { const $b = s.f[0]; return $b; } if (true) { return false; } throw new Error("plié: no alternative matches"); })($j);
export const $asList = $j => ((s) => { if (s.t === "JList") { const $xs = s.f[0]; return $xs; } if (true) { return []; } throw new Error("plié: no alternative matches"); })($j);
export const $isNull = $j => ((s) => { if (s.t === "JNull") { return true; } if (true) { return false; } throw new Error("plié: no alternative matches"); })($j);
export const $entry = $k => $v => (x0 => x1 => ({t: "Pair", f: [x0, x1]}))($k)($v);
export const $object = $fs => (x0 => ({t: "JObj", f: [x0]}))($fs);
export const $texts = $ts => (x0 => ({t: "JList", f: [x0]}))($map((x0 => ({t: "JText", f: [x0]})))($ts));
export const $ints = $ns => (x0 => ({t: "JList", f: [x0]}))($map((x0 => ({t: "JInt", f: [x0]})))($ns));
export const $canonical = $j => ((s) => { if (s.t === "JNull") { return "null"; } if (s.t === "JBool") { const $b = s.f[0]; return ($b ? "true" : "false"); } if (s.t === "JInt") { const $n = s.f[0]; return $showInt($n); } if (s.t === "JText") { const $t = s.f[0]; return $jsonQuote($t); } if (s.t === "JList") { const $xs = s.f[0]; return $append("[")($append($joinText(",")($map($canonical)($xs)))("]")); } if (s.t === "JObj") { const $fs = s.f[0]; return $append("{")($append($joinText(",")($map($member)($sortBy(($a => $b => $ltUtf16($fst($a))($fst($b))))($fs))))("}")); } throw new Error("plié: no alternative matches"); })($j);
export const $member = $f => $append($jsonQuote($fst($f)))($append(":")($canonical($snd($f))));
export const $canonicalBytes = $j => $utf8($canonical($j));
export const $digest = $j => $hex($sha256($canonicalBytes($j)));
export const entries = {};
