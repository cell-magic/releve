-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- Written by plie/plie.py from Verify.plie. Do not edit: edit the source.
import Plie.Prelude
import Plie.Json
import Plie.Merkle
import Plie.Chain
import Plie.Roots
import Plie.Seed

namespace Plie
open Plie.Prelude

inductive Check where
  | Check : String → Json → String → Check
  deriving Repr, BEq, Inhabited

def checkJson (c : Check) : Json :=
  (match c with | (.Check name ok detail) => (Plie.object [(Plie.entry "check" (Json.JText name)), (Plie.entry "ok" ok), (Plie.entry "detail" (Json.JText detail))]))

def okOf (c : Check) : Json :=
  (match c with | (.Check name ok detail) => ok)

def pass (name : String) (ok : Bool) (good : String) (bad : String) : Check :=
  (Check.Check name (Json.JBool ok) (if ok then good else bad))

def unchecked (name : String) (why : String) : Check :=
  (Check.Check name Json.JNull why)

def hex32 (t : String) : Bool :=
  (match (Plie.Prelude.unhex t) with | (some b) => ((Plie.Prelude.bytesLength b) == (32 : Int)) | none => false)

def quicknet : String :=
  "52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971"

def beaconName (chain : String) : String :=
  (if (chain == Plie.quicknet) then "drand quicknet" else ("the chain " ++ (chain ++ " (named at the edge, not quicknet)")))

def flag (b : Bool) : Int :=
  (if b then (1 : Int) else (0 : Int))

def requestBefore (q : Json) (p : Json) : Bool :=
  (let a := (Plie.asText (Plie.field "origin" q)); (let b := (Plie.asText (Plie.field "origin" p)); (if (a != b) then (Plie.Prelude.lt a b) else (let s := (Plie.asText (Plie.field "type" q)); (let t := (Plie.asText (Plie.field "type" p)); (if (s != t) then (Plie.Prelude.lt s t) else (let u := (Plie.asInt (Plie.field "status" q)); (let v := (Plie.asInt (Plie.field "status" p)); (if (u != v) then (Plie.Prelude.lt u v) else (let x := (Plie.flag (Plie.asBool (Plie.field "pre_interaction" q))); (let y := (Plie.flag (Plie.asBool (Plie.field "pre_interaction" p))); (if (x != y) then (Plie.Prelude.lt x y) else (Plie.Prelude.lt (Plie.asInt (Plie.field "bytes" q)) (Plie.asInt (Plie.field "bytes" p)))))))))))))))

def canonicalRecord (r : Json) : Bool :=
  (let cs := (Plie.Prelude.map Plie.asText (Plie.asList (Plie.field "candidates" (Plie.field "selection" r)))); (let qs := (Plie.asList (Plie.path ["observation", "requests"] r)); ((Plie.Prelude.all Plie.canonicalUrl cs) && ((Plie.Prelude.all (fun p => (Plie.Prelude.lt (Plie.Prelude.fst p) (Plie.Prelude.snd p))) (Plie.Prelude.zip cs (Plie.Prelude.drop (1 : Int) cs))) && (Plie.Prelude.all (fun p => (Plie.Prelude.not (Plie.requestBefore (Plie.Prelude.snd p) (Plie.Prelude.fst p)))) (Plie.Prelude.zip qs (Plie.Prelude.drop (1 : Int) qs)))))))

def justs (ms : List (Option Step)) : List Step :=
  (Plie.Prelude.concat (Plie.Prelude.map (fun m => (match m with | (some s) => [s] | none => [])) ms))

def edgeCheck (name : String) (e : Json) (expected : String) (good : String) : Check :=
  (if ((Plie.isNull e) || (Plie.isNull (Plie.field "ok" e))) then (Plie.unchecked name (if (Plie.isNull e) then "not checked here" else (Plie.asText (Plie.field "detail" e)))) else (Plie.pass name ((Plie.asBool (Plie.field "ok" e)) && ((Plie.asText (Plie.field "imprint" e)) == expected)) good (if (Plie.asBool (Plie.field "ok" e)) then ("the token covers something else than " ++ expected) else (Plie.asText (Plie.field "detail" e)))))

def edgeBls (e : Json) : Check :=
  (if ((Plie.isNull e) || (Plie.isNull (Plie.field "ok" e))) then (Plie.unchecked "beacon-signature" (if (Plie.isNull e) then "the round's BLS signature is not checked here; the command line checks it" else (Plie.asText (Plie.field "detail" e)))) else (Plie.pass "beacon-signature" (Plie.asBool (Plie.field "ok" e)) (Plie.asText (Plie.field "detail" e)) (Plie.asText (Plie.field "detail" e))))

def inOrder (xs : List String) (ys : List String) : Bool :=
  (match xs with | [] => true | (x :: xr) => (match ys with | [] => false | (y :: yr) => (if (x == y) then (Plie.inOrder xr yr) else (Plie.inOrder xs yr))))

def selection (r : Json) (edge : Json) : List Check :=
  (let sel := (Plie.field "selection" r); (let beacon := (Plie.field "beacon" r); (if ((Plie.asText (Plie.field "status" beacon)) == "unavailable") then [(Plie.unchecked "beacon" "selection not beacon-seeded: the record says the beacon could not be reached")] else (let rnd := (Plie.asText (Plie.field "randomness" beacon)); (let sig := (Plie.Prelude.fromMaybe (Plie.Prelude.utf8 "") (Plie.Prelude.unhex (Plie.asText (Plie.field "signature" beacon)))); (let round := (Plie.asInt (Plie.field "round" beacon)); (let given := (Plie.orderOf (Plie.object [(Plie.entry "randomness" (Json.JText rnd)), (Plie.entry "site" (Plie.field "site" r)), (Plie.entry "cycle" (Plie.field "cycle" r)), (Plie.entry "candidates" (Plie.field "candidates" sel))])); (let order := (Plie.Prelude.map Plie.asText (Plie.asList (Plie.field "order" sel))); (let picks := (Plie.Prelude.map Plie.asText (Plie.asList (Plie.field "picks" sel))); (let read := (Plie.Prelude.map Plie.asText (Plie.asList (Plie.field "read" sel))); (let committed := (Plie.field "commitment" sel); (let chain := (if (Plie.isNull (Plie.field "chain" edge)) then Plie.quicknet else (Plie.asText (Plie.field "chain" edge))); (let start := (Plie.cycleStart (Plie.asText (Plie.field "cycle" r))); [(Plie.pass "beacon-round" (((Plie.asText (Plie.field "chain" beacon)) == chain) && (((Plie.Prelude.hex (Plie.Prelude.sha256 sig)) == rnd) && (Plie.Prelude.gt round (0 : Int)))) ("the round is of " ++ ((Plie.beaconName chain) ++ ", and its randomness is the hash of its signature")) ("the round is not of " ++ ((Plie.beaconName chain) ++ ", or its randomness is not the hash of its signature"))), (Plie.edgeBls (Plie.field "bls" edge)), (Plie.pass "order" (((Plie.field "order" given) == (Plie.field "order" sel)) && (((Plie.field "seed" given) == (Plie.field "seed" sel)) && ((Plie.inOrder read order) && ((Plie.Prelude.gt (Plie.Prelude.length picks) (0 : Int)) && (((Plie.Prelude.nth (0 : Int) picks) == (Plie.Prelude.nth (0 : Int) read)) && ((Plie.Prelude.all (fun p => (Plie.Prelude.elem p read)) picks) && (Plie.Prelude.elem (Json.JText (Plie.asText (Plie.field "url" r))) (Plie.asList (Plie.field "picks" sel))))))))) "the order is the one the round gives, the pages read follow it, the first pick heads them, and the page is among the picks" "the order, the seed or the picks are not those the round gives"), (Plie.edgeCheck "committed" (Plie.field "commitment_tsa" edge) (Plie.asText (Plie.field "hash" committed)) "the candidates were committed to, and the commitment dated by the authority"), (Plie.pass "before-beacon" (((Plie.asText (Plie.field "commitment" given)) == (Plie.asText (Plie.field "hash" committed))) && ((Plie.Prelude.ge start (0 : Int)) && ((Plie.Prelude.lt (Plie.asInt (Plie.field "time" committed)) start) && ((round == (Plie.firstRoundAfter start)) && ((Plie.isNull (Plie.field "commitment_tsa" edge)) || ((Plie.isNull (Plie.field "time" (Plie.field "commitment_tsa" edge))) || ((Plie.asInt (Plie.field "time" (Plie.field "commitment_tsa" edge))) == (Plie.asInt (Plie.field "time" committed))))))))) "the candidates were dated before the cycle began, and the round is the first after it: the cycle fixed the round, not the Bureau" "the candidates were not dated before the cycle began, the round is not the cycle's, or the candidates are not those committed to")])))))))))))))

def firstFailure (cs : List Check) : Json :=
  (match cs with | [] => Json.JNull | (c :: rest) => (match c with | (.Check name ok detail) => (if (ok == (Json.JBool false)) then (Json.JText name) else (Plie.firstFailure rest))))

def verifyBundle (input : Json) : Json :=
  (let b := (Plie.field "bundle" input); (let r := (Plie.field "record" b); (let h := (Plie.asText (Plie.field "record_hash" b)); (let previous := (Plie.field "previous" input); (let rootHex := (Plie.asText (Plie.field "root" b)); (let steps := (Plie.Prelude.map Plie.stepOf (Plie.asList (Plie.field "path" b))); (let edge := (Plie.field "edge" input); (let roots := (Plie.asList (Plie.field "entries" (Plie.field "roots" input))); (let token := (Plie.Prelude.fromMaybe (Plie.Prelude.utf8 "") (Plie.Prelude.unhex (Plie.asText (Plie.field "token" b)))); (let checks := ([(Plie.pass "record-hash" (((Plie.recordHash r) == h) && (Plie.hex32 h)) "the record's canonical bytes hash to the hash it is delivered with" "the record does not hash to the hash it is delivered with: it is not the record that was chained"), (Plie.pass "canonical" (Plie.canonicalRecord r) "each candidate is written in its one way, once and in order, and the requests are in their one order" "a candidate is not written in its one way, or not once and in order, or the requests are not in their one order"), (if ((Plie.isNull previous) && (Plie.Prelude.not (Plie.isNull (Plie.field "prev" r)))) then (Plie.unchecked "prev-link" "the record names a previous record; give it to check the link") else (Plie.pass "prev-link" (Plie.linked previous r) "the record follows from the one before it" "the record does not follow from the one before it")), (Plie.pass "inclusion-path" ((Plie.Prelude.all (fun s => (s != none)) steps) && ((Plie.Prelude.hex (Plie.rootFrom (Plie.Prelude.fromMaybe (Plie.Prelude.utf8 "") (Plie.Prelude.unhex h)) (Plie.justs steps))) == rootHex)) "the path leads from the record's hash to the root" "the path does not lead from the record's hash to the root"), (Plie.pass "root" ((Plie.hex32 rootHex) && ((Plie.asText (Plie.field "cycle" b)) == (Plie.asText (Plie.field "cycle" r)))) "the root is the root of the record's own cycle" "the root is not one of the record's cycle"), (Plie.pass "published" ((Plie.chained Json.JNull roots) && ((Plie.listed (Plie.asText (Plie.field "cycle" b)) rootHex roots) && (Plie.Prelude.any (fun e => (((Plie.asText (Plie.field "root" e)) == rootHex) && ((Plie.asText (Plie.field "token_hash" e)) == (Plie.Prelude.hex (Plie.Prelude.sha256 token))))) roots))) "the root and its token stand in the published list, and the list runs unbroken" "the root, or its token, is not in the published list, or the list does not run unbroken"), (Plie.edgeCheck "tsa-token" (Plie.field "tsa" edge) rootHex "the time-stamp token covers the root, under the authority's signature")] ++ (Plie.selection r edge)); (let oks := (Plie.Prelude.map Plie.okOf checks); (Plie.object [(Plie.entry "ok" (Json.JBool (Plie.Prelude.all (fun o => (o == (Json.JBool true))) oks))), (Plie.entry "checks" (Json.JList (Plie.Prelude.map Plie.checkJson checks))), (Plie.entry "first_failure" (Plie.firstFailure checks))]))))))))))))

end Plie
