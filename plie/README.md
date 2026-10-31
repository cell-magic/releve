# plié

A small pure language. Each source is written once and translated three ways:

- into **Haskell**, which runs it (`releve core`);
- into **JavaScript**, which runs it in a browser (`record/verifier.html`);
- into **Lean 4**, where its properties are to be proved.

RADAR's core is written in it (`record/*.plie`): the canonical JSON text, the
chain, the month's Merkle tree, the published roots, the beacon-seeded order,
the readings and the verifier. What judges and checks therefore has one
source, not one copy per language.

## The language

The language is the common ground of Haskell and Lean, and no more.

```
module Merkle where

import Json

data Step = OnLeft Bytes | OnRight Bytes

nodeHash : Bytes -> Bytes -> Bytes
nodeHash l r = sha256 (byte 1 ++ l ++ r)

pairUp : List Bytes -> List Bytes
pairUp xs = case xs of
  | a :: b :: rest -> nodeHash a b :: pairUp rest
  | _ -> xs
```

- **Declarations**, each starting in the first column: `module`, `import`,
  `data` (a sum of products, with type parameters), a signature `name : Type`,
  and a definition `name x y = expression`. Every definition has a signature.
- **Expressions**:
  - application; `\x -> e`; `let x = e in e`; `if c then a else b`;
  - `case e of`, with its alternatives `| pattern -> e` aligned under one
    another;
  - list literals `[a, b]`; integer and text literals;
  - the operators `|| && == /= < <= > >= :: ++ + - *`. Comparisons do not chain.
- **Patterns**: a variable, `_`, an integer or text literal, `[]`,
  `head :: tail`, and a constructor with its fields.
- **Types**: `Int` (unbounded), `Bool`, `Text`, `Bytes`, `List a`, `Maybe a`,
  `Pair a b`, data types, functions. Types are written as Lean writes them:
  `x : Int` for a type, `x :: xs` for a list.
- **No floats, no effects, no input or output.** A program is a function, and
  the same input gives the same output in every translation.
- **Reserved names:** a name that is a keyword or builtin in Haskell, Lean or
  JavaScript is refused, and so is any prelude name.

## The prelude

Each name means the same in each language. Its three definitions are
`prelude/Plie/Prelude.hs`, `prelude/Plie/Prelude.lean` and `prelude/plie.js`.

| group | names |
|---|---|
| Int | `div mod` (rounding toward minus infinity), `abs min max showInt readInt` |
| Bool | `not` |
| lists | `length map filter foldl reverse take drop sum all any elem concat range zip nth sortBy` (stable), `fromMaybe fst snd` |
| Text | `textLength` (code points), `utf8 split startsWith endsWith asciiLower joinText trim`, `jsonQuote` (RFC 8785 escaping), `ltUtf16` (RFC 8785 key order) |
| Bytes | `sha256 byte be64 hex unhex bytesLength` |

- Text is compared by code point, bytes byte by byte.
- SHA-256 is the one cryptographic primitive. In Lean it is opaque: a proof
  may rely on its being a function, never on what it computes.

## The world

A function of type `Json -> Json` is an **entry point**: the world may call
it.

- `prelude/Plie/Bridge.hs` and `prelude/bridge.js` read JSON in, call the
  function by name, and write its answer as canonical text (RFC 8785).
- A number that is not an integer is refused at the door.
- `releve core FUNCTION < input.json` calls the Haskell version;
  `node plie/run.mjs COMPILED.js FUNCTION` calls the JavaScript one.

## The compiler

```
python plie/plie.py hs   OUT_DIR FILE.plie ...           # one Haskell module per file
python plie/plie.py lean OUT_DIR FILE.plie ...           # one Lean 4 file per file
python plie/plie.py js   OUT_FILE PRELUDE FILE.plie ...  # one JavaScript module
```

- Mutually recursive definitions are grouped for Lean.
- A recursion Lean cannot see as structural becomes `partial def`, and nothing
  can then be proved of it. The record's Merkle tree, chain and roots list are
  written with structural recursion only, so that it can be.
- `record/build.sh` translates `record/` and keeps the results in
  `record/gen/`.

## What holds, and what does not yet

`tests/plie.py` checks that:
- the Haskell and JavaScript versions give the same bytes on inputs chosen to
  separate them (negative division, emoji, UTF-16 key order, control
  characters);
- the versions kept in `record/gen/` are the ones their sources give;
- the compiler refuses what it must.

**The Lean output has not been compiled.** No Lean was installed where it was
written, so nothing about it is proved yet. Which theorems come first is set
out in `HANDOVER.md`.
