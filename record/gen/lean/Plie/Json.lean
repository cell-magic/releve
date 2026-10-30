-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- Written by plie/plie.py from Json.plie. Do not edit: edit the source.
import Plie.Prelude

namespace Plie
open Plie.Prelude

inductive Json where
  | JNull : Json
  | JBool : Bool → Json
  | JInt : Int → Json
  | JText : String → Json
  | JList : (List Json) → Json
  | JObj : (List (Pair String Json)) → Json
  deriving Repr, BEq, Inhabited

def fieldIn (k : String) (fs : List (Pair String Json)) : Json :=
  (match fs with | [] => Json.JNull | (f :: rest) => (if ((Plie.Prelude.fst f) == k) then (Plie.Prelude.snd f) else (Plie.fieldIn k rest)))

def field (k : String) (j : Json) : Json :=
  (match j with | (.JObj fs) => (Plie.fieldIn k fs) | _ => Json.JNull)

def has (k : String) (j : Json) : Bool :=
  (match j with | (.JObj fs) => (Plie.Prelude.any (fun f => ((Plie.Prelude.fst f) == k)) fs) | _ => false)

def path (ks : List String) (j : Json) : Json :=
  (Plie.Prelude.foldl (fun x k => (Plie.field k x)) j ks)

def asInt (j : Json) : Int :=
  (match j with | (.JInt n) => n | _ => (0 : Int))

def asText (j : Json) : String :=
  (match j with | (.JText t) => t | _ => "")

def asBool (j : Json) : Bool :=
  (match j with | (.JBool b) => b | _ => false)

def asList (j : Json) : List Json :=
  (match j with | (.JList xs) => xs | _ => [])

def isNull (j : Json) : Bool :=
  (match j with | .JNull => true | _ => false)

def entry (k : String) (v : Json) : Pair String Json :=
  (Pair.Pair k v)

def object (fs : List (Pair String Json)) : Json :=
  (Json.JObj fs)

def texts (ts : List String) : Json :=
  (Json.JList (Plie.Prelude.map Json.JText ts))

def ints (ns : List Int) : Json :=
  (Json.JList (Plie.Prelude.map Json.JInt ns))

mutual
partial def canonical (j : Json) : String :=
  (match j with | .JNull => "null" | (.JBool b) => (if b then "true" else "false") | (.JInt n) => (Plie.Prelude.showInt n) | (.JText t) => (Plie.Prelude.jsonQuote t) | (.JList xs) => ("[" ++ ((Plie.Prelude.joinText "," (Plie.Prelude.map Plie.canonical xs)) ++ "]")) | (.JObj fs) => ("{" ++ ((Plie.Prelude.joinText "," (Plie.Prelude.map Plie.member (Plie.Prelude.sortBy (fun a b => (Plie.Prelude.ltUtf16 (Plie.Prelude.fst a) (Plie.Prelude.fst b))) fs))) ++ "}")))

partial def member (f : Pair String Json) : String :=
  ((Plie.Prelude.jsonQuote (Plie.Prelude.fst f)) ++ (":" ++ (Plie.canonical (Plie.Prelude.snd f))))

end

def canonicalBytes (j : Json) : Bytes :=
  (Plie.Prelude.utf8 (Plie.canonical j))

def digest (j : Json) : String :=
  (Plie.Prelude.hex (Plie.Prelude.sha256 (Plie.canonicalBytes j)))

end Plie
