-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- Written by plie/plie.py from Seed.plie. Do not edit: edit the source.
import Plie.Prelude
import Plie.Json

namespace Plie
open Plie.Prelude

-- sealed: its constructor is used in Seed alone (plié checks it, GHC's export list too)
inductive Seed where
  | Seed : Bytes → Seed
  deriving Repr, BEq, Inhabited

def seedOf (randomness : Bytes) (site : String) (cycle : String) : Seed :=
  (Seed.Seed (Plie.Prelude.sha256 (randomness ++ ((Plie.Prelude.utf8 site) ++ (Plie.Prelude.utf8 cycle)))))

def seedHex (s : Seed) : String :=
  (match s with | (.Seed b) => (Plie.Prelude.hex b))

def placeOf (s : Seed) (url : String) : Bytes :=
  (match s with | (.Seed b) => (Plie.Prelude.sha256 (b ++ (Plie.Prelude.utf8 url))))

def orderBy (seed : Seed) (urls : List String) : List String :=
  (Plie.Prelude.sortBy (fun a b => (Plie.Prelude.lt (Plie.placeOf seed a) (Plie.placeOf seed b))) urls)

def dedupe (xs : List String) : List String :=
  (Plie.Prelude.reverse (Plie.Prelude.foldl (fun acc x => (if ((Plie.Prelude.nth (0 : Int) acc) == (some x)) then acc else (x :: acc))) [] xs))

def commitment (urls : List String) : String :=
  (Plie.digest (Plie.texts (Plie.dedupe (Plie.Prelude.sortBy (fun a b => (Plie.Prelude.lt a b)) urls))))

def orderOf (input : Json) : Json :=
  (let r := (Plie.Prelude.fromMaybe (Plie.Prelude.utf8 "") (Plie.Prelude.unhex (Plie.asText (Plie.field "randomness" input)))); (let urls := (Plie.Prelude.map Plie.asText (Plie.asList (Plie.field "candidates" input))); (let seed := (Plie.seedOf r (Plie.asText (Plie.field "site" input)) (Plie.asText (Plie.field "cycle" input))); (Plie.object [(Plie.entry "seed" (Json.JText (Plie.seedHex seed))), (Plie.entry "order" (Plie.texts (Plie.orderBy seed urls))), (Plie.entry "commitment" (Json.JText (Plie.commitment urls)))]))))

def commitmentOf (input : Json) : Json :=
  (let urls := (Plie.Prelude.map Plie.asText (Plie.asList (Plie.field "candidates" input))); (Plie.object [(Plie.entry "commitment" (Json.JText (Plie.commitment urls))), (Plie.entry "candidates" (Plie.texts (Plie.dedupe (Plie.Prelude.sortBy (fun a b => (Plie.Prelude.lt a b)) urls))))]))

def firstRoundAfter (t : Int) : Int :=
  ((Plie.Prelude.div (t - (1692803367 : Int)) (3 : Int)) + (2 : Int))

end Plie
