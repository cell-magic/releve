-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- Written by plie/plie.py from Readings.plie. Do not edit: edit the source.
import Plie.Prelude
import Plie.Json

namespace Plie
open Plie.Prelude

def scParts (sc : String) : List Int :=
  (Plie.Prelude.map (fun p => (Plie.Prelude.fromMaybe (0 : Int) (Plie.Prelude.readInt p))) (Plie.Prelude.split "." sc))

def lexLess (xs : List Int) (ys : List Int) : Bool :=
  (match xs with | [] => (match ys with | [] => false | _ => true) | (x :: xr) => (match ys with | [] => false | (y :: yr) => (if (Plie.Prelude.lt x y) then true else (if (Plie.Prelude.lt y x) then false else (Plie.lexLess xr yr)))))

def scBefore (a : String) (b : String) : Bool :=
  (Plie.lexLess (Plie.scParts a) (Plie.scParts b))

def marked (label : String) (rule : Json) : Int :=
  (Plie.asInt (Plie.field label rule))

def labelOf (rules : List Json) : Json :=
  (if (Plie.Prelude.any (fun r => (Plie.Prelude.gt (Plie.marked "fail" r) (0 : Int))) rules) then (Json.JText "fail") else (if (Plie.Prelude.any (fun r => (Plie.Prelude.gt (Plie.marked "review" r) (0 : Int))) rules) then (Json.JText "review") else (if (Plie.Prelude.any (fun r => (Plie.Prelude.gt (Plie.marked "hint" r) (0 : Int))) rules) then (Json.JText "hint") else Json.JNull)))

def uniqueTexts (ts : List String) : List String :=
  (Plie.Prelude.foldl (fun acc t => (if (Plie.Prelude.elem t acc) then acc else (acc ++ [t]))) [] ts)

def wcag (rules : List Json) : Json :=
  (let scs := (Plie.uniqueTexts (Plie.Prelude.concat (Plie.Prelude.map (fun r => (Plie.Prelude.map Plie.asText (Plie.asList (Plie.field "wcag" r)))) rules))); (Json.JList (Plie.Prelude.map (fun sc => (let on := (Plie.Prelude.filter (fun r => (Plie.Prelude.elem (Json.JText sc) (Plie.asList (Plie.field "wcag" r)))) rules); (Plie.object [(Plie.entry "sc" (Json.JText sc)), (Plie.entry "label" (Plie.labelOf on)), (Plie.entry "criteria" (Plie.texts (Plie.Prelude.map (fun r => (Plie.asText (Plie.field "criterion" r))) (Plie.Prelude.filter (fun r => (Plie.Prelude.gt (((Plie.marked "fail" r) + (Plie.marked "review" r)) + (Plie.marked "hint" r)) (0 : Int))) on))))]))) (Plie.Prelude.sortBy Plie.scBefore scs))))

def hostOf (origin : String) : String :=
  (let rest := (Plie.Prelude.fromMaybe origin (Plie.Prelude.nth (1 : Int) (Plie.Prelude.split "://" origin))); (if (Plie.Prelude.startsWith "[" rest) then ((Plie.Prelude.fromMaybe rest (Plie.Prelude.nth (0 : Int) (Plie.Prelude.split "]" rest))) ++ "]") else (Plie.Prelude.asciiLower (Plie.Prelude.fromMaybe rest (Plie.Prelude.nth (0 : Int) (Plie.Prelude.split ":" rest))))))

def isAddress (host : String) : Bool :=
  ((Plie.Prelude.startsWith "[" host) || (Plie.Prelude.all (fun l => ((Plie.Prelude.gt (Plie.Prelude.textLength l) (0 : Int)) && ((Plie.Prelude.readInt l) != none))) (Plie.Prelude.split "." host)))

def lastLabels (k : Int) (labels : List String) : String :=
  (Plie.Prelude.joinText "." (Plie.Prelude.drop ((Plie.Prelude.length labels) - k) labels))

def suffixLength (rules : List String) (labels : List String) : Int :=
  (let n := (Plie.Prelude.length labels); (let ks := (Plie.Prelude.range (1 : Int) (n + (1 : Int))); (let excepted := (Plie.Prelude.filter (fun k => (Plie.Prelude.elem ("!" ++ (Plie.lastLabels k labels)) rules)) ks); (if (Plie.Prelude.gt (Plie.Prelude.length excepted) (0 : Int)) then ((Plie.Prelude.foldl Plie.Prelude.max (0 : Int) excepted) - (1 : Int)) else (Plie.Prelude.foldl Plie.Prelude.max (1 : Int) (Plie.Prelude.filter (fun k => ((Plie.Prelude.elem (Plie.lastLabels k labels) rules) || ((Plie.Prelude.gt k (1 : Int)) && (Plie.Prelude.elem ("*." ++ (Plie.lastLabels (k - (1 : Int)) labels)) rules)))) ks))))))

def registrable (rules : List String) (host : String) : String :=
  (if (Plie.isAddress host) then host else (let labels := (Plie.Prelude.split "." host); (let s := (Plie.suffixLength rules labels); (if (Plie.Prelude.gt (Plie.Prelude.length labels) s) then (Plie.lastLabels (s + (1 : Int)) labels) else host))))

def dependencies (rules : List String) (version : String) (site : String) (requests : List Json) : Json :=
  (let mine := (Plie.registrable rules (Plie.hostOf site)); (let domainOf := (fun q => (Plie.registrable rules (Plie.hostOf (Plie.asText (Plie.field "origin" q))))); (let domains := (Plie.Prelude.sortBy (fun a b => (Plie.Prelude.lt a b)) (Plie.uniqueTexts (Plie.Prelude.map domainOf requests))); (Plie.object [(Plie.entry "psl" (Json.JText version)), (Plie.entry "site" (Json.JText mine)), (Plie.entry "domains" (Json.JList (Plie.Prelude.map (fun d => (let qs := (Plie.Prelude.filter (fun q => ((domainOf q) == d)) requests); (Plie.object [(Plie.entry "domain" (Json.JText d)), (Plie.entry "party" (Json.JText (if (d == mine) then "first" else "third"))), (Plie.entry "requests" (Json.JInt (Plie.Prelude.length qs))), (Plie.entry "bytes" (Json.JInt (Plie.Prelude.sum (Plie.Prelude.map (fun q => (Plie.asInt (Plie.field "bytes" q))) qs)))), (Plie.entry "pre_interaction" (Json.JInt (Plie.Prelude.length (Plie.Prelude.filter (fun q => (Plie.asBool (Plie.field "pre_interaction" q))) qs))))]))) domains)))]))))

def legibility (ax : Json) : Json :=
  (let n := (Plie.asInt (Plie.field "interactive" ax)); (let named := (Plie.asInt (Plie.field "named" ax)); (Plie.object [(Plie.entry "interactive" (Json.JInt n)), (Plie.entry "named" (Json.JInt named)), (Plie.entry "unnamed" (Json.JInt (n - named))), (Plie.entry "invalid_roles" (Plie.field "invalid_roles" ax)), (Plie.entry "context_violations" (Plie.field "context_violations" ax)), (Plie.entry "hidden_interactive" (Plie.field "hidden_interactive" ax)), (Plie.entry "obstacles" (Json.JInt ((((n - named) + (Plie.asInt (Plie.field "invalid_roles" ax))) + (Plie.asInt (Plie.field "context_violations" ax))) + (Plie.asInt (Plie.field "hidden_interactive" ax)))))])))

def pad9 (t : String) : String :=
  ((Plie.Prelude.joinText "" (Plie.Prelude.map (fun k => "0") (Plie.Prelude.range (Plie.Prelude.textLength t) (9 : Int)))) ++ t)

def decimal9 (nano : Int) : String :=
  ((Plie.Prelude.showInt (Plie.Prelude.div nano (1000000000 : Int))) ++ ("." ++ (Plie.pad9 (Plie.Prelude.showInt (Plie.Prelude.mod nano (1000000000 : Int))))))

def energy (coefficient : Json) (bytes : Int) : Json :=
  (let num := (Plie.asInt (Plie.path ["kwh_per_gb", "num"] coefficient)); (let den := (Plie.asInt (Plie.path ["kwh_per_gb", "den"] coefficient)); (let d := (den * (1000000000 : Int)); (let nano := (if (Plie.Prelude.gt d (0 : Int)) then (Plie.Prelude.div ((((bytes * num) * (1000000000 : Int)) * (2 : Int)) + d) ((2 : Int) * d)) else (0 : Int)); (Plie.object [(Plie.entry "bytes" (Json.JInt bytes)), (Plie.entry "kwh" (Json.JText (Plie.decimal9 nano))), (Plie.entry "coefficient" (Plie.object [(Plie.entry "source" (Plie.field "source" coefficient)), (Plie.entry "version" (Plie.field "version" coefficient)), (Plie.entry "kwh_per_gb" (Plie.field "kwh_per_gb" coefficient))]))])))))

def reading (name : String) (version : Int) (value : Json) : Json :=
  (Plie.object [(Plie.entry "name" (Json.JText name)), (Plie.entry "version" (Json.JInt version)), (Plie.entry "value" value)])

def readingsOf (input : Json) : Json :=
  (let o := (Plie.field "observation" input); (let psl := (Plie.field "psl" input); (Json.JList [(Plie.reading "wcag" (1 : Int) (Plie.wcag (Plie.asList (Plie.field "rules" input)))), (Plie.reading "dependencies" (1 : Int) (Plie.dependencies (Plie.Prelude.map Plie.asText (Plie.asList (Plie.field "rules" psl))) (Plie.asText (Plie.field "version" psl)) (Plie.asText (Plie.field "site" input)) (Plie.asList (Plie.field "requests" o)))), (Plie.reading "legibility" (1 : Int) (Plie.legibility (Plie.field "ax" o))), (Plie.reading "energy" (1 : Int) (Plie.energy (Plie.field "energy" input) (Plie.asInt (Plie.path ["bytes", "total"] o))))])))

end Plie
