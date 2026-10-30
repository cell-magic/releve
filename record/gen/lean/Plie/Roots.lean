-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- Written by plie/plie.py from Roots.plie. Do not edit: edit the source.
import Plie.Prelude
import Plie.Json

namespace Plie
open Plie.Prelude

def entryHash (e : Json) : String :=
  (Plie.digest e)

def chained (before : Json) (es : List Json) : Bool :=
  (match es with | [] => true | (e :: rest) => ((if (Plie.isNull before) then (Plie.isNull (Plie.field "prev_entry_hash" e)) else (((Plie.asText (Plie.field "prev_entry_hash" e)) == (Plie.entryHash before)) && (Plie.Prelude.lt (Plie.asText (Plie.field "cycle" before)) (Plie.asText (Plie.field "cycle" e))))) && (Plie.chained e rest)))

def listed (cycle : String) (rootHex : String) (es : List Json) : Bool :=
  (Plie.Prelude.any (fun e => (((Plie.asText (Plie.field "cycle" e)) == cycle) && ((Plie.asText (Plie.field "root" e)) == rootHex))) es)

def lastOf (es : List Json) : Json :=
  (Plie.Prelude.foldl (fun acc e => e) Json.JNull es)

def rootsAppend (input : Json) : Json :=
  (let es := (Plie.asList (Plie.field "roots" input)); (let before := (Plie.lastOf es); (let e := (Plie.object [(Plie.entry "cycle" (Plie.field "cycle" input)), (Plie.entry "root" (Plie.field "root" input)), (Plie.entry "token_hash" (Plie.field "token_hash" input)), (Plie.entry "prev_entry_hash" (if (Plie.isNull before) then Json.JNull else (Json.JText (Plie.entryHash before))))]); (Plie.object [(Plie.entry "format" (Json.JText "releve-roots/1")), (Plie.entry "entries" (Json.JList (es ++ [e])))]))))

end Plie
