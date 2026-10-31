# Handover: five questions for a logician

**The setting, once.** relevé observes public web pages and judges them by fixed
rules. Each month it issues every subscribing site a *record*: a JSON document
saying what was measured. Anyone must be able to check that record later
without trusting the issuer. The checker runs in two places: on a command line,
and in a web page opened offline. The issuer keeps nothing.

The logic that builds and checks records is written once, in **plié**, a small
pure functional language. It is translated mechanically into three languages:

- Haskell, to run on the command line;
- JavaScript, to run in the offline page;
- Lean 4, to prove things about it.

The language is:

- data types (sums of products), typed top-level definitions, λ, `let`, `if`,
  `case` on constructors and lists;
- unbounded integers, text, bytes, lists; no floats, no effects;
- a fixed library whose meaning is defined three times by hand, once per target
  (`plie/prelude/`). Its one cryptographic primitive is SHA-256.

A small example:

```
leafHash : Bytes -> Bytes
leafHash d = sha256 (byte 0 ++ d)
```

Each question below stands alone.

---

## 1. One meaning, three translations

**Context.** plié has no semantics of its own. Each translation is
syntax-directed. The Haskell output is type-checked by GHC, the Lean output by
Lean, and the JavaScript output not at all. That the three agree is checked
only by running Haskell and JavaScript on the same inputs and comparing bytes
(`tests/plie.py` passes). Equal outputs on tested inputs say nothing about
untested ones.

**My default without you:** take the Lean output as the reference, and keep
testing the other two against it.

**Question.** What is the least formal apparatus that makes "the three
translations compute the same function" a theorem rather than a test? The
candidates I see:

- (a) one big-step semantics for plié, with an adequacy proof per translation;
- (b) per-program translation validation, a certificate checked for each
  compiled program;
- (c) dropping two translations and extracting Haskell and JavaScript from Lean.

Which costs least for a language of this size, and which typing discipline
should that semantics assume: simple types with datatypes, or prenex
polymorphism?

**What your answer changes:** whether I write a semantics, a validator or an
extractor next, and whether plié gets a type checker of its own.

---

## 2. Recursion that halves

**Context.** The monthly records are combined into one Merkle tree (RFC 6962),
whose root is published. The tree over a list of n leaves is built by
splitting at the largest power of two below n, then recursing on the two
parts:

```
root hs = node (root (take k hs)) (root (drop k hs))   -- k = largest power of 2 < n
```

This terminates, but not by structural recursion, so Lean receives it as
`partial def` and nothing can then be proved about it. The workaround is fuel:
an extra argument that decreases by one each step and is set to n. It is
total, but every proof must then show the fuel never runs out.

**My default without you:** fuel, with a lemma that n steps are enough.

**Question.** For a language that must translate into Haskell, JavaScript and
Lean alike, how should recursion on a measure, rather than on structure,
appear in the source?

- (a) fuel;
- (b) well-founded recursion with the measure written in the source, which
  Lean checks and the other two ignore;
- (c) sized types;
- (d) forbid it, and rewrite the tree as a fold over levels, pairing adjacent
  nodes.

For (d): is pairing level by level, carrying an odd node up unchanged,
provably the same tree as splitting at the largest power of two? It is for
every n up to 2048, checked by brute force, but I have no proof.

**What your answer changes:** which recursion forms plié admits, and whether
the Merkle code is a fold.

---

## 3. A hash that cannot be injective

**Context.** In the proofs, SHA-256 is an opaque function from bytes to bytes.
Two properties of the checker matter:

- **Completeness:** the checker accepts every inclusion path the builder
  produces. This holds for any function whatsoever.
- **Soundness:** an accepted path proves that the record is in the tree. This
  needs collision resistance. Assuming "SHA-256 is injective" as an axiom would
  be inconsistent, since 2^256 outputs cannot cover unboundedly many inputs.

**My default without you:** state soundness as an extraction. If the checker
accepts a record that is not among the leaves, then two distinct byte strings
with the same hash can be computed from what it was given.

**Question.** Is that extraction the right way to state soundness in a proof
assistant, given that it says nothing about probability or efficiency? Is it
enough to state it constructively, as a total function from a forged proof to
a collision? The same question arises twice more:

- the chain of records, each naming its predecessor by hash;
- the list of published roots, each entry naming the previous one.

Is there one general lemma ("any hash-linked structure that verifies but
differs yields a collision") that all three instantiate?

**What your answer changes:** the shape of every security theorem, and
whether I prove three instances or one schema.

---

## 4. What the mirror can honestly promise

**Context.** Once at least 20 sites subscribe, a statistic is published for
each measure, such as total bytes per page:

- the median over sites;
- its *leave-one-out sensitivity*: the largest change in the median when any
  one site is removed;
- the published value is the median rounded to a bucket at least as wide as
  that sensitivity.

There is no noise; it is deterministic. The intent is that no single site
noticeably moves what is published. But a median near a bucket edge can still
cross the edge when one site leaves, so "removing one site never changes the
published bucket" is false as stated.

**My default without you:** prove only the arithmetic, namely that the bucket
is never narrower than the sensitivity, and describe the intent in words.

**Question.** What true, non-trivial statement relates the published bucket to
any single site's value? Some forms I can see:

- the published bucket changes by at most one step when one site leaves;
- a site's value can be recovered only to within the bucket width;
- the median is a Lipschitz function of the data in a suitable order.

Which can be proved, and which is worth publishing? If none holds without
noise, I would rather know and say so.

**What your answer changes:** the theorem attached to the mirror and the
sentence printed beside it, or a decision that the design needs changing.

---

## 5. Checking as an encounter

**Context.** A recipient holds:

- a record;
- an inclusion path;
- the month's root;
- the public list of past roots;
- a time-stamp token over the root, issued by a third party;
- the public random value (a drand beacon round) that chose which pages were
  observed.

The checker runs six tests in order: record hash, link to the previous record,
inclusion path, root, root present in the list, token. Each returns pass or
fail, and the first failure is named. Records also form a chain across months.

**My default without you:** a sequence of boolean checks, with a soundness
theorem per check (question 3).

**Question.** In the spirit of transcendental syntax, can this be presented as
the interaction of two objects, the record and the evidence around it? It
would count as genuine exactly when the interaction succeeds, with each of the
six tests a local part of one encounter. If so:

- does that give one correctness criterion in place of six;
- does it compose along the chain, so that checking month n+1 against month n
  is the same kind of encounter;
- does it express the one temporal fact the booleans miss: the list of
  candidate pages must be fixed *before* the random value is known, or the
  random choice proves nothing?

**What your answer changes:** whether the checker is restructured around one
criterion, and how "fixed before the beacon" enters the record and the proofs.

---

## Where the code stands

All of it is now written in plié, and the Haskell and JavaScript versions
agree on every test input:

- `record/Merkle.plie`: the tree, built level by level as in question 2;
- `record/Chain.plie` and `record/Roots.plie`: the hash-linked structures of
  question 3;
- `record/Verify.plie`: the six checks of question 5, then the selection
  checks;
- `radar/mirror.py`: the mirror of question 4, in Python on the closed side,
  with what it does not promise written in its docstring.

The "fixed before the beacon" fact of question 5 is now enforced:

- the candidate list is committed to and time-stamped before the cycle begins;
- the round is the cycle's, the first after its first second, so that the
  moment is no one's choice and drawing again gives nothing;
- the verifier checks both (check `before-beacon`).

Each list of a record is also written one way (check `canonical`), and the
changes between two records form a Z-set in one form. Three laws are tested
and are the next theorems: `consolidate` is idempotent and ignores order;
the readings do not depend on the order of the requests; changes add along
a chain of records.

What I would like proved first, in `record/gen/lean/`:

- completeness of `rootFrom`/`pathOf` (question 2);
- the collision extraction for `Merkle`, `Chain` and `Roots` (question 3).

Sealed types now exist (`sealed data`; plie/README.md): a minimal capability
discipline, kept by the compiler and by GHC. Question 4 still stands: is it the
right minimal one, and how should Lean keep it?

The Lean output is written but has never been compiled: no Lean was
installed where this was made. Its first job is to compile.
