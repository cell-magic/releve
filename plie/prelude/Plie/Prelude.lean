-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- The plié prelude, in Lean 4: what each of its names means, as Plie/Prelude.hs and
-- plie.js say it, written so that a proof can unfold it. Bytes are a list of bytes.
-- SHA-256 is opaque: a proof may rely on its being a function, never on what it computes;
-- what rests on collision resistance is stated as a hypothesis, where it is needed.

namespace Plie.Prelude

abbrev Bytes := List UInt8

inductive Pair (a b : Type) where
  | Pair : a → b → Pair a b
  deriving Repr, BEq, Inhabited

/-- Strict orders on the types plié compares: Int by value, Text by code point, Bytes by byte. -/
class Order (a : Type) where
  lt : a → a → Bool

instance : Order Int := ⟨fun x y => decide (x < y)⟩
instance : Order String := ⟨fun x y => decide (x.toList.map Char.toNat < y.toList.map Char.toNat)⟩
instance : Order Bytes := ⟨fun x y => decide (x.map UInt8.toNat < y.map UInt8.toNat)⟩

def lt {a : Type} [Order a] (x y : a) : Bool := Order.lt x y
def le {a : Type} [Order a] (x y : a) : Bool := !(Order.lt y x)
def gt {a : Type} [Order a] (x y : a) : Bool := Order.lt y x
def ge {a : Type} [Order a] (x y : a) : Bool := !(Order.lt x y)

def div (a b : Int) : Int := Int.fdiv a b
def mod (a b : Int) : Int := Int.fmod a b
def abs (a : Int) : Int := if a < 0 then -a else a
def min (a b : Int) : Int := if a ≤ b then a else b
def max (a b : Int) : Int := if a ≤ b then b else a
def not (b : Bool) : Bool := !b
def showInt (a : Int) : String := toString a
def readInt (t : String) : Option Int :=
  if t.length > 0 ∧ t.all Char.isDigit then some (t.toNat!) else none

def length {a : Type} (xs : List a) : Int := xs.length
def map {a b : Type} (f : a → b) (xs : List a) : List b := xs.map f
def filter {a : Type} (f : a → Bool) (xs : List a) : List a := xs.filter f
def foldl {a b : Type} (f : b → a → b) (z : b) (xs : List a) : b := xs.foldl f z
def reverse {a : Type} (xs : List a) : List a := xs.reverse
def take {a : Type} (n : Int) (xs : List a) : List a := xs.take n.toNat
def drop {a : Type} (n : Int) (xs : List a) : List a := xs.drop n.toNat
def sum (xs : List Int) : Int := xs.foldl (· + ·) 0
def all {a : Type} (f : a → Bool) (xs : List a) : Bool := xs.all f
def any {a : Type} (f : a → Bool) (xs : List a) : Bool := xs.any f
def elem {a : Type} [BEq a] (x : a) (xs : List a) : Bool := xs.contains x
def concat {a : Type} (xss : List (List a)) : List a := xss.flatten
def range (a b : Int) : List Int := (List.range (b - a).toNat).map (fun k => a + k)
def zip {a b : Type} (xs : List a) (ys : List b) : List (Pair a b) := List.zipWith Pair.Pair xs ys
def nth {a : Type} (i : Int) (xs : List a) : Option a := if i < 0 then none else xs[i.toNat]?
/-- A stable sort by a strict order. -/
def sortBy {a : Type} (lt : a → a → Bool) (xs : List a) : List a := xs.mergeSort (fun x y => !(lt y x))
def fromMaybe {a : Type} (d : a) (m : Option a) : a := m.getD d
def fst {a b : Type} : Pair a b → a | .Pair x _ => x
def snd {a b : Type} : Pair a b → b | .Pair _ y => y

def textLength (t : String) : Int := t.length
def utf8 (t : String) : Bytes := t.toUTF8.toList
def split (sep t : String) : List String := if sep.isEmpty then [t] else t.splitOn sep
def startsWith (p t : String) : Bool := t.startsWith p
def endsWith (s t : String) : Bool := t.endsWith s
def asciiLower (t : String) : String := t.map (fun c => if 'A' ≤ c ∧ c ≤ 'Z' then Char.ofNat (c.toNat + 32) else c)
def joinText (sep : String) (xs : List String) : String := sep.intercalate xs
def trim (t : String) : String :=
  let ws := fun (c : Char) => c = ' ' ∨ c = '\t' ∨ c = '\n' ∨ c = '\r'
  String.mk ((t.toList.dropWhile (fun c => decide (ws c))).reverse.dropWhile (fun c => decide (ws c))).reverse
def hexDigit (k : Nat) : Char := "0123456789abcdef".toList.getD k '0'
def jsonQuote (t : String) : String :=
  let one := fun (c : Char) =>
    if c = '"' then "\\\"" else if c = '\\' then "\\\\" else if c.toNat = 8 then "\\b"
    else if c = '\t' then "\\t" else if c = '\n' then "\\n" else if c.toNat = 12 then "\\f"
    else if c = '\r' then "\\r" else if c.toNat < 32 then String.mk ['\\', 'u', '0', '0', hexDigit (c.toNat / 16), hexDigit (c.toNat % 16)]
    else c.toString
  "\"" ++ String.join (t.toList.map one) ++ "\""
def utf16Units (t : String) : List Nat :=
  t.toList.flatMap (fun c => let n := c.toNat; if n < 0x10000 then [n] else [0xD800 + (n - 0x10000) / 0x400, 0xDC00 + (n - 0x10000) % 0x400])
def ltUtf16 (a b : String) : Bool := decide (utf16Units a < utf16Units b)

/-- SHA-256, opaque: proofs hold whatever function it is. -/
opaque sha256 : Bytes → Bytes
def byte (n : Int) : Bytes := [UInt8.ofNat (Int.toNat (Int.fmod n 256))]
def be64 (n : Int) : Bytes := (List.range 8).reverse.map (fun k => UInt8.ofNat ((Int.toNat (Int.fmod n (2 ^ 64)) / 2 ^ (8 * k)) % 256))
def hex (b : Bytes) : String := String.join (b.map (fun w => String.mk [hexDigit (w.toNat / 16), hexDigit (w.toNat % 16)]))
def hexVal (c : Char) : Option Nat :=
  if c.isDigit then some (c.toNat - 48) else if 'a' ≤ c ∧ c ≤ 'f' then some (c.toNat - 87)
  else if 'A' ≤ c ∧ c ≤ 'F' then some (c.toNat - 55) else none
def unhexList : List Char → Option Bytes
  | a :: b :: r => do let x ← hexVal a; let y ← hexVal b; let rest ← unhexList r; pure (UInt8.ofNat (x * 16 + y) :: rest)
  | [] => some []
  | [_] => none
def unhex (t : String) : Option Bytes := unhexList t.toList
def bytesLength (b : Bytes) : Int := b.length

end Plie.Prelude
