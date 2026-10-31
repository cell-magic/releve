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

def authorityHost (authority : String) : String :=
  (if (Plie.Prelude.startsWith "[" authority) then ((Plie.Prelude.fromMaybe "" (Plie.Prelude.nth (0 : Int) (Plie.Prelude.split "]" authority))) ++ "]") else (Plie.Prelude.fromMaybe "" (Plie.Prelude.nth (0 : Int) (Plie.Prelude.split ":" authority))))

def portFits (scheme : String) (port : String) : Bool :=
  ((port == "") || (((Plie.Prelude.readInt port) != none) && ((Plie.Prelude.not (Plie.Prelude.startsWith "0" port)) && ((Plie.Prelude.not ((scheme == "http") && (port == "80"))) && (Plie.Prelude.not ((scheme == "https") && (port == "443")))))))

def authorityPort (authority : String) : String :=
  (Plie.Prelude.joinText ":" (Plie.Prelude.drop (1 : Int) (Plie.Prelude.split ":" (if (Plie.Prelude.startsWith "[" authority) then (Plie.Prelude.joinText "]" (Plie.Prelude.drop (1 : Int) (Plie.Prelude.split "]" authority))) else authority))))

def hexDigits : List String :=
  ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"]

def upperEscape (after : String) : Bool :=
  (Plie.Prelude.any (fun a => (Plie.Prelude.any (fun b => (Plie.Prelude.startsWith (a ++ b) after)) Plie.hexDigits)) Plie.hexDigits)

def canonicalUrl (url : String) : Bool :=
  (let scheme := (if (Plie.Prelude.startsWith "https://" url) then "https" else (if (Plie.Prelude.startsWith "http://" url) then "http" else "")); (let rest := (Plie.Prelude.joinText "://" (Plie.Prelude.drop (1 : Int) (Plie.Prelude.split "://" url))); (let segments := (Plie.Prelude.split "/" rest); (let authority := (Plie.Prelude.fromMaybe "" (Plie.Prelude.nth (0 : Int) segments)); (let pathPart := (Plie.Prelude.joinText "/" (Plie.Prelude.drop (1 : Int) segments)); (let host := (Plie.authorityHost authority); ((scheme != "") && ((Plie.Prelude.ge (Plie.Prelude.length segments) (2 : Int)) && ((host != "") && (((Plie.Prelude.asciiLower authority) == authority) && ((Plie.Prelude.not (Plie.Prelude.endsWith ":" authority)) && (((Plie.Prelude.length (Plie.Prelude.split "?" authority)) == (1 : Int)) && (((Plie.Prelude.bytesLength (Plie.Prelude.utf8 authority)) == (Plie.Prelude.textLength authority)) && ((Plie.Prelude.not (Plie.Prelude.endsWith "." host)) && (((Plie.Prelude.length (Plie.Prelude.split "@" authority)) == (1 : Int)) && (((Plie.Prelude.length (Plie.Prelude.split "#" url)) == (1 : Int)) && ((Plie.portFits scheme (Plie.authorityPort authority)) && ((Plie.Prelude.all (fun seg => ((seg != ".") && (seg != ".."))) (Plie.Prelude.split "/" (Plie.Prelude.fromMaybe "" (Plie.Prelude.nth (0 : Int) (Plie.Prelude.split "?" pathPart))))) && (Plie.Prelude.all Plie.upperEscape (Plie.Prelude.drop (1 : Int) (Plie.Prelude.split "%" url)))))))))))))))))))))

def commitmentOf (input : Json) : Json :=
  (let urls := (Plie.Prelude.map Plie.asText (Plie.asList (Plie.field "candidates" input))); (Plie.object [(Plie.entry "commitment" (Json.JText (Plie.commitment urls))), (Plie.entry "candidates" (Plie.texts (Plie.dedupe (Plie.Prelude.sortBy (fun a b => (Plie.Prelude.lt a b)) urls)))), (Plie.entry "refused" (Plie.texts (Plie.Prelude.filter (fun u => (Plie.Prelude.not (Plie.canonicalUrl u))) urls)))]))

def firstRoundAfter (t : Int) : Int :=
  ((Plie.Prelude.div (t - (1692803367 : Int)) (3 : Int)) + (2 : Int))

def daysFrom (y : Int) (m : Int) (d : Int) : Int :=
  (let y1 := (if (Plie.Prelude.le m (2 : Int)) then (y - (1 : Int)) else y); (let era := (Plie.Prelude.div y1 (400 : Int)); (let yoe := (y1 - (era * (400 : Int))); (let doy := (((Plie.Prelude.div (((153 : Int) * (Plie.Prelude.mod (m + (9 : Int)) (12 : Int))) + (2 : Int)) (5 : Int)) + d) - (1 : Int)); ((((((era * (146097 : Int)) + (yoe * (365 : Int))) + (Plie.Prelude.div yoe (4 : Int))) - (Plie.Prelude.div yoe (100 : Int))) + doy) - (719468 : Int))))))

def cycleStart (cycle : String) : Int :=
  (let parts := (Plie.Prelude.split "-" cycle); (match (Plie.Prelude.readInt (Plie.Prelude.fromMaybe "" (Plie.Prelude.nth (0 : Int) parts))) with | none => ((0 : Int) - (1 : Int)) | (some y) => (match (Plie.Prelude.readInt (Plie.Prelude.fromMaybe "" (Plie.Prelude.nth (1 : Int) parts))) with | none => ((0 : Int) - (1 : Int)) | (some m) => (if (((Plie.Prelude.length parts) == (2 : Int)) && ((Plie.Prelude.ge m (1 : Int)) && (Plie.Prelude.le m (12 : Int)))) then ((Plie.daysFrom y m (1 : Int)) * (86400 : Int)) else ((0 : Int) - (1 : Int))))))

def drawOf (input : Json) : Json :=
  (let start := (Plie.cycleStart (Plie.asText (Plie.field "cycle" input))); (Plie.object [(Plie.entry "rule" (Json.JText "releve-draw/1")), (Plie.entry "start" (Json.JInt start)), (Plie.entry "round" (Json.JInt (Plie.firstRoundAfter start)))]))

end Plie
