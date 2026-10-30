-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- Written by plie/plie.py from Merkle.plie. Do not edit: edit the source.
import Plie.Prelude
import Plie.Json

namespace Plie
open Plie.Prelude

inductive Step where
  | OnLeft : Bytes → Step
  | OnRight : Bytes → Step
  deriving Repr, BEq, Inhabited

def leafHash (d : Bytes) : Bytes :=
  (Plie.Prelude.sha256 ((Plie.Prelude.byte (0 : Int)) ++ d))

def nodeHash (l : Bytes) (r : Bytes) : Bytes :=
  (Plie.Prelude.sha256 ((Plie.Prelude.byte (1 : Int)) ++ (l ++ r)))

def pairUp (xs : List Bytes) : List Bytes :=
  (match xs with | (a :: (b :: rest)) => ((Plie.nodeHash a b) :: (Plie.pairUp rest)) | _ => xs)

def climb (fuel : List Bytes) (level : List Bytes) : Bytes :=
  (match level with | [] => (Plie.Prelude.sha256 (Plie.Prelude.utf8 "")) | (h :: more) => (match more with | [] => h | _ => (match fuel with | [] => h | (f :: rest) => (Plie.climb rest (Plie.pairUp level)))))

def ordered (ds : List Bytes) : List Bytes :=
  (Plie.Prelude.sortBy (fun a b => (Plie.Prelude.lt a b)) ds)

def root (ds : List Bytes) : Bytes :=
  (let ls := (Plie.Prelude.map Plie.leafHash (Plie.ordered ds)); (Plie.climb ls ls))

def mapMaybe (f : Bytes → Step) (m : Option Bytes) : List Step :=
  (match m with | (some x) => [(f x)] | none => [])

def pathAt (fuel : List Bytes) (i : Int) (level : List Bytes) : List Step :=
  (match fuel with | [] => [] | (f :: rest) => (if (Plie.Prelude.lt (Plie.Prelude.length level) (2 : Int)) then [] else (let sibling := (if ((Plie.Prelude.mod i (2 : Int)) == (0 : Int)) then (Plie.mapMaybe Step.OnRight (Plie.Prelude.nth (i + (1 : Int)) level)) else (Plie.mapMaybe Step.OnLeft (Plie.Prelude.nth (i - (1 : Int)) level))); (sibling ++ (Plie.pathAt rest (Plie.Prelude.div i (2 : Int)) (Plie.pairUp level))))))

def position (d : Bytes) (ds : List Bytes) : Int :=
  (Plie.Prelude.length (Plie.Prelude.filter (fun x => (Plie.Prelude.lt x d)) (Plie.ordered ds)))

def pathOf (d : Bytes) (ds : List Bytes) : List Step :=
  (let ls := (Plie.Prelude.map Plie.leafHash (Plie.ordered ds)); (Plie.pathAt ls (Plie.position d ds) ls))

def up (acc : Bytes) (s : Step) : Bytes :=
  (match s with | (.OnLeft x) => (Plie.nodeHash x acc) | (.OnRight x) => (Plie.nodeHash acc x))

def rootFrom (d : Bytes) (steps : List Step) : Bytes :=
  (Plie.Prelude.foldl (fun acc s => (Plie.up acc s)) (Plie.leafHash d) steps)

def stepJson (s : Step) : Json :=
  (match s with | (.OnLeft x) => (Plie.object [(Plie.entry "left" (Json.JText (Plie.Prelude.hex x)))]) | (.OnRight x) => (Plie.object [(Plie.entry "right" (Json.JText (Plie.Prelude.hex x)))]))

def mapStep (f : Bytes → Step) (m : Option Bytes) : Option Step :=
  (match m with | (some x) => (if ((Plie.Prelude.bytesLength x) == (32 : Int)) then (some (f x)) else none) | none => none)

def stepOf (j : Json) : Option Step :=
  (if (Plie.has "left" j) then (Plie.mapStep Step.OnLeft (Plie.Prelude.unhex (Plie.asText (Plie.field "left" j)))) else (if (Plie.has "right" j) then (Plie.mapStep Step.OnRight (Plie.Prelude.unhex (Plie.asText (Plie.field "right" j)))) else none))

def maybeList (m : Option Bytes) : List Bytes :=
  (match m with | (some x) => [x] | none => [])

def hexes (js : List Json) : List Bytes :=
  (Plie.Prelude.concat (Plie.Prelude.map (fun j => (Plie.maybeList (Plie.Prelude.unhex (Plie.asText j)))) js))

def merkleBatch (input : Json) : Json :=
  (let ds := (Plie.hexes (Plie.asList (Plie.field "leaves" input))); (Plie.object [(Plie.entry "root" (Json.JText (Plie.Prelude.hex (Plie.root ds)))), (Plie.entry "size" (Json.JInt (Plie.Prelude.length ds))), (Plie.entry "paths" (Plie.object (Plie.Prelude.map (fun d => (Plie.entry (Plie.Prelude.hex d) (Json.JList (Plie.Prelude.map Plie.stepJson (Plie.pathOf d ds))))) (Plie.ordered ds))))]))

end Plie
