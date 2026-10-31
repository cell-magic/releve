# RADAR v2 — plan (D-033), as built

Six amendments, after A0 (BOUNDARY.md and its check). Each piece is on the side
BOUNDARY.md gives it:
- **open** in relevé: `record/`, `plie/`, `observe/`, `kernel/`, `receipt/`;
- **closed** in `radar`, beside relevé, which uses relevé as a library.

There is one commit per amendment in each repository, in the order the
dependencies impose:

- relevé: A2, A3, A4, A5, then the release.
- radar: A5, A6, A3, A1.

## What changed from the first plan

- **The core is written in plié** (`plie/`, `record/*.plie`), a small pure
  language translated three ways: Haskell (`releve core`), JavaScript
  (`record/verifier.html`) and Lean 4 (`record/gen/lean`, not yet compiled).
  The verifier, readings, chain, tree and roots list therefore have one
  source, not a Python copy and a JavaScript copy. Python is the edge:
  files, network, OpenSSL, BLS.
- **The candidates are dated before the beacon.** The run commits to the
  candidate list and time-stamps the commitment (RFC 3161). It then takes
  drand's first round after that time. The verifier checks the round really
  is the first one after, so nobody could choose pages, or a round, once the
  randomness was known.
- **The chain is built from what is kept.** The next record's `prev` and
  `baseline` come from the last record's hash and baseline, which is all the
  Bureau keeps. No record is needed.
- **Context violations are read from the markup.** Chrome drops a role it
  finds out of context, so the accessibility tree cannot show it.

## Amendments, files, side, tests

| | piece | files | side | tests |
|---|---|---|---|---|
| A2 | observation frozen in shape; rule results as data; readings as functions of both; recompute | `observe/observe.py`, `observe/aria.js`, `kernel/app/Main.hs` (`releve rules`), `record/schema/`, `record/schema.py`, `record/observation.py`, `record/Readings.plie`, `record/psl.py`, `record/data/` | open | `tests/conduct.py`, `tests/record.py` |
| A3 | RFC 8785 hash, chain, RFC 6962 tree, published roots, RFC 3161 client, renewal stub; "chained" | `record/Json.plie`, `Chain.plie`, `Merkle.plie`, `Roots.plie`, `record/tsa.py`, `record/roots.py`; `serve/serve.py`, README | open | `tests/record.py`, `tests/service.py`, `tests/run.py` |
| A3 | the month as an operation; root publication | `radar/monthly.py`, `radar/config.toml` | closed | end-to-end run (REPORT.md) |
| A4 | first drand round after the dated commitment; seed and order; BLS; "not beacon-seeded"; verifier (CLI and page) | `record/Seed.plie`, `record/Verify.plie`, `record/beacon.py`, `record/run.py`, `record/verify.py`, `record/cli.py`, `record/ui.html` → `record/verifier.html` | open | `tests/record.py`, `tests/plie.py` |
| A5 | the record and the report say "observed under the owner's mandate" | `record/run.py`, `kernel/src/Releve/Report.hs` | open | `tests/record.py`, `tests/run.py` |
| A5 | store (only the allowed fields); sign-up with the mandate apart from the voice | `radar/store.py`, `radar/signup.py` | closed | `radar/tests/run.py` |
| A1 | stamp: self-hosted inline SVG, one name, nothing fetched; status page on click | `radar/stamp.py`, `radar/status.py` | closed | `radar/tests/run.py`; screenshots, axe-core, network log |
| A6 | mirror: off below 20; median, leave-one-out sensitivity, bucket at least as wide | `radar/mirror.py` | closed | `radar/tests/run.py` |

## Dependencies

- **The BLS check** (`record/bls`, since the first plan replaced py_ecc).
  BLS12-381 pairings and RFC 9380 hash-to-G1 have no standard-library
  equivalent, and a hand-written pairing is the greater risk. It uses the
  `bls12_381` and `sha2` crates (MIT or Apache-2.0), in one Rust source built
  twice: for the command line, and as WebAssembly for the browser.
- **Public suffix list** (MPL-2.0, data). It is what tells first parties
  from third parties by registrable domain. Pinned in `record/data/`, named
  in REUSE.toml, licence text in `LICENSES/MPL-2.0.txt`.
- **Node** runs the JavaScript fold in the tests. **faketime** sets the test
  authority's clock. **axe-core** is used for evidence only, outside both
  repositories. None of these is a runtime dependency of relevé.
