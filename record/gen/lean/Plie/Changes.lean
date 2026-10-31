-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- Written by plie/plie.py from Changes.plie. Do not edit: edit the source.
import Plie.Prelude
import Plie.Json

namespace Plie
open Plie.Prelude

def marks (criterion : String) (label : String) (rules : List Json) : Int :=
  (Plie.Prelude.foldl (fun n r => (if ((Plie.asText (Plie.field "criterion" r)) == criterion) then (n + (Plie.asInt (Plie.field label r))) else n)) (0 : Int) rules)

def criteriaOf (rules : List Json) : List String :=
  (Plie.Prelude.map (fun r => (Plie.asText (Plie.field "criterion" r))) rules)

def union (xs : List String) (ys : List String) : List String :=
  (xs ++ (Plie.Prelude.filter (fun y => (Plie.Prelude.not (Plie.Prelude.elem y xs))) ys))

def change (kind : String) (key : String) (delta : Int) : Json :=
  (Plie.object [(Plie.entry "kind" (Json.JText kind)), (Plie.entry "key" (Json.JText key)), (Plie.entry "delta" (Json.JInt delta))])

def ruleChanges (before : List Json) (after : List Json) : List Json :=
  (Plie.Prelude.concat (Plie.Prelude.map (fun c => (Plie.Prelude.concat (Plie.Prelude.map (fun l => (let d := ((Plie.marks c l after) - (Plie.marks c l before)); (if (d == (0 : Int)) then [] else [(Plie.change l c d)]))) ["fail", "review", "hint"]))) (Plie.union (Plie.criteriaOf after) (Plie.criteriaOf before))))

def readingValue (name : String) (r : Json) : Json :=
  (Plie.Prelude.foldl (fun v x => (if ((Plie.asText (Plie.field "name" x)) == name) then (Plie.field "value" x) else v)) Json.JNull (Plie.asList (Plie.field "readings" r)))

def thirdParties (r : Json) : List String :=
  (Plie.Prelude.map (fun d => (Plie.asText (Plie.field "domain" d))) (Plie.Prelude.filter (fun d => ((Plie.asText (Plie.field "party" d)) == "third")) (Plie.asList (Plie.field "domains" (Plie.readingValue "dependencies" r)))))

def domainChanges (before : Json) (after : Json) : List Json :=
  (let b := (Plie.thirdParties before); (let a := (Plie.thirdParties after); ((Plie.Prelude.map (fun d => (Plie.change "third-party" d (1 : Int))) (Plie.Prelude.filter (fun d => (Plie.Prelude.not (Plie.Prelude.elem d b))) a)) ++ (Plie.Prelude.map (fun d => (Plie.change "third-party" d ((0 : Int) - (1 : Int)))) (Plie.Prelude.filter (fun d => (Plie.Prelude.not (Plie.Prelude.elem d a))) b)))))

def moved (key : String) (before : Int) (after : Int) : List Json :=
  (if (after == before) then [] else [(Plie.change "measure" key (after - before))])

def early (r : Json) : Int :=
  (Plie.Prelude.length (Plie.Prelude.filter (fun q => (Plie.asBool (Plie.field "pre_interaction" q))) (Plie.asList (Plie.path ["observation", "requests"] r))))

def measureChanges (before : Json) (after : Json) : List Json :=
  ((Plie.moved "bytes" (Plie.asInt (Plie.path ["observation", "bytes", "total"] before)) (Plie.asInt (Plie.path ["observation", "bytes", "total"] after))) ++ ((Plie.moved "requests" (Plie.Prelude.length (Plie.asList (Plie.path ["observation", "requests"] before))) (Plie.Prelude.length (Plie.asList (Plie.path ["observation", "requests"] after)))) ++ ((Plie.moved "before-interaction" (Plie.early before) (Plie.early after)) ++ (Plie.moved "obstacles" (Plie.asInt (Plie.field "obstacles" (Plie.readingValue "legibility" before))) (Plie.asInt (Plie.field "obstacles" (Plie.readingValue "legibility" after)))))))

def changesOf (input : Json) : Json :=
  (let b := (Plie.field "before" input); (let a := (Plie.field "after" input); (let same := (((Plie.asText (Plie.field "url" b)) == (Plie.asText (Plie.field "url" a))) && ((Plie.asText (Plie.field "site" b)) == (Plie.asText (Plie.field "site" a)))); (Plie.object [(Plie.entry "page" (Plie.field "url" a)), (Plie.entry "from" (Plie.field "cycle" b)), (Plie.entry "to" (Plie.field "cycle" a)), (Plie.entry "compared" (Json.JBool same)), (Plie.entry "changes" (Json.JList (if same then ((Plie.ruleChanges (Plie.asList (Plie.field "rules" b)) (Plie.asList (Plie.field "rules" a))) ++ ((Plie.domainChanges b a) ++ (Plie.measureChanges b a))) else [])))]))))

end Plie
