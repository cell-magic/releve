# Handover: plié, the language RADAR's logic is to be written in

## What it is

A small pure language, the common syntactic fragment of Haskell and Lean 4. Each
source is translated ("folded") three ways:

- into **Haskell**, which runs it (the `releve` binary);
- into **JavaScript**, which runs it in the offline verifier page;
- into **Lean 4**, where its properties are to be proved.

The language:
- **Terms:** data types; typed top-level definitions; application, λ, `let`,
  `if`, `case` over constructors and lists; unbounded integers, no floats.
- **No type checker of its own:** GHC types the Haskell fold and Lean types
  the Lean fold. The JavaScript fold is untyped.
- **Recursion:** structural recursion is recognised syntactically (a call on
  the tail bound by a cons pattern). Anything else becomes `partial def` in
  Lean, where nothing can be proved of it.
- **Primitives:** a fixed prelude, defined three times (`plie/prelude/`).
  SHA-256 is the one cryptographic primitive, opaque in Lean.
- **Entry points:** every function the world may call has type `Json → Json`;
  input and output are JSON text, canonical under RFC 8785.

| file | role |
|---|---|
| `plie/plie.py` | parser and the three translators (stdlib Python) |
| `plie/prelude/` | the prelude in Haskell, Lean and JS; the JSON bridges |
| `record/Json.plie` | JSON values, field access, canonical text |
| `record/gen/` | the three folds, kept and checked against their sources |
| `tests/plie.py` | runs both executable folds on edge cases and compares bytes |

## Where it stands

- **Checked:** the Haskell and JavaScript folds give the same bytes on every
  conformance input (17 of 17 checks, last full run). That covers floor
  division, code-point text, UTF-16 key order, escaping and SHA-256.
- **Not checked:** the Lean fold has never been compiled. Installing Lean was
  refused in this session, so nothing in it is proved.
- **Planned but not yet written in plié:** Merkle tree and inclusion paths
  (RFC 6962), the record chain, the published-roots list, beacon seed and page
  order, the readings, the mirror (median with leave-one-out bound), and the
  status decision. The plan is in `PLAN.md`; the boundary rules are in
  `BOUNDARY.md`.

## Five questions

1. **A language of its own, or a shared fragment?** Today plié has no
   semantics of its own; it borrows two type checkers. Should it get its own
   typing and evaluation rules, against which each translation is shown
   adequate? And what is the least system that serves: simply typed with
   datatypes, or polymorphic?
2. **Totality.** Should general recursion go, leaving folds and structural
   recursion only, so every program is total and the Lean fold never needs
   `partial`? Is a syntactic criterion enough, or should it be a type
   discipline (sized types, or a primitive-recursive core)?
3. **Faithful translations.** The folds are held together by testing. Is the
   right next step translation validation per program, a proof that each
   translation preserves one operational semantics, or a single fold (Lean)
   from which the other two are extracted?
4. **What to prove first, and from what.** Which comes first: completeness
   (the verifier accepts a path the builder made), soundness (an accepted path
   proves inclusion), the mirror's published bucket being at least as wide as
   the sensitivity, or the roots list being append-only? Soundness needs
   collision resistance, but SHA-256 is opaque. How should that hypothesis be
   stated so it is honest and still usable?
5. **Verification as interaction.** The verifier checks a record against a
   path, a root, a list and a token, one check after another. Is there a
   better presentation, for instance verification as the interaction of two
   objects in the spirit of transcendental syntax, where a check is a
   successful encounter rather than a computed boolean? Would it change what
   needs proving?
