-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- Written by plie/plie.py from Chain.plie. Do not edit: edit the source.
import Plie.Prelude
import Plie.Json

namespace Plie
open Plie.Prelude

def recordHash (r : Json) : String :=
  (Plie.digest r)

def linked (previous : Json) (r : Json) : Bool :=
  (let prev := (Plie.field "prev" r); (let status := (Plie.asText (Plie.field "chain_status" r)); (if (Plie.isNull prev) then ((status == "reset") || ((status == "unbroken") && (Plie.isNull previous))) else ((status == "unbroken") && ((Plie.Prelude.not (Plie.isNull previous)) && (((Plie.asText prev) == (Plie.recordHash previous)) && (((Plie.asText (Plie.field "site" previous)) == (Plie.asText (Plie.field "site" r))) && ((Plie.asText (Plie.field "baseline" previous)) == (Plie.asText (Plie.field "baseline" r))))))))))

def chainNext (input : Json) : Json :=
  (let last := (Plie.field "last" input); (let reset := (Plie.asBool (Plie.field "reset" input)); (let date := (Plie.asText (Plie.field "date" input)); (if ((Plie.isNull last) || reset) then (Plie.object [(Plie.entry "prev" Json.JNull), (Plie.entry "baseline" (Json.JText date)), (Plie.entry "chain_status" (Json.JText (if (Plie.isNull last) then "unbroken" else "reset")))]) else (Plie.object [(Plie.entry "prev" (Plie.field "hash" last)), (Plie.entry "baseline" (Plie.field "baseline" last)), (Plie.entry "chain_status" (Json.JText "unbroken"))])))))

def canonicalOf (j : Json) : Json :=
  (Plie.object [(Plie.entry "canonical" (Json.JText (Plie.canonical j))), (Plie.entry "hash" (Json.JText (Plie.digest j)))])

end Plie
