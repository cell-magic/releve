# RADAR v2 — plan (D-033)

Six amendments, after A0 (BOUNDARY.md and its check, committed). Each piece
goes on the side BOUNDARY.md gives it: **open** in relevé (`record/`, new;
`observe/`, `kernel/`, `receipt/`), **closed** in `radar` (beside relevé,
uses it as a library). One commit per amendment in each repository touched,
in the order dependencies impose: A2, A3, A4, A5, A1, A6.

## Inventory that shapes the plan

- relevé is the only repository reachable from this session; Surface Core
  (`engine-build`) and the site are not. relevé and Surface Core are **not
  merged**: `receipt/` is a vendored copy of Surface Core's selector 0.3.1
  (`surface-core/select-1`), and the live service imports that copy. The
  selector is left unchanged; what Surface Core's own verifier must mirror is
  listed under A4.
- The selector has no seed: farthest-first traversal from the first page in
  crawl order. Seeding therefore means seeding that order (A4).
- No RADAR code existed: no sign-up, stamp, monthly run, status page.
- Records today: relevé's corpus, a JSON-lines chain (SHA-256 over the
  previous hash and the event's bytes as written). `releve verify` prints
  "sealed"; that word goes (A3).
- Signing keys: only the per-bundle ECDSA P-256 key of the WACZ
  (`receipt/bundle.py`), generated, used once, discarded. No Bureau key, no
  Ed25519. Its docstring points to the retired Bureau Seal (D-034).
- Network policy of this session denies drand, DigiCert's TSA,
  publicsuffix.org and arbitrary sites. Evidence is made on local sites, a
  local OpenSSL TSA and a drand quicknet round published in drand's own test
  code (round 12040883), each labelled so; the live run is deferred, with its
  commands, in REPORT.md.

## A2 — record: observation apart from readings

| piece | files | side |
|---|---|---|
| observer records each request's status and whether it fired before any interaction, and the accessibility-tree counts (CDP `Accessibility.getFullAXTree`) | `observe/observe.py`, `observe/aria.js` | open |
| kernel: `releve rules -`, the rule results of each observation as JSON, machine labels fail / review / hint | `kernel/app/Main.hs`, `kernel/src/Releve/Kernel.hs` | open |
| schema `releve-record/2` (JSON Schema, versioned file), stdlib validator | `record/schema/record-2.schema.json`, `record/schema.py` | open |
| observation block; reader of 0.10 corpus records (backward compatible) | `record/observation.py` | open |
| readings: `wcag` (rule results by success criterion, no percentage), `dependencies` (first/third party by registrable domain), `legibility`, `energy` | `record/readings.py`, `record/psl.py` | open |
| pinned public suffix list (VERSION 2026-10-28_13-15-55_UTC, commit 9dfbe81), energy coefficients naming their source and version | `record/data/` | open |
| `python -m record recompute`: readings rebuilt offline, byte-compared | `record/cli.py` | open |

Tests: `tests/record.py` (schema, observation shape, no query strings or
header values, readings pure, recompute byte-equal, v1 reader, energy never
on member-facing output); `tests/conduct.py` (status, pre-interaction, AX
counts on a local page).

## A3 — chain, monthly root, published roots, verifier

| piece | files | side |
|---|---|---|
| canonical bytes RFC 8785 (JCS; records hold no floats), record hash SHA-256 | `record/jcs.py`, `record/chain.py` | open |
| `prev`, `baseline`, `chain_status` (unbroken / reset) on each record | `record/chain.py` | open |
| Merkle tree, RFC 6962 (leaf 0x00, node 0x01), leaves ordered by record hash; inclusion paths and their check | `record/merkle.py` | open |
| RFC 3161 client, TSA URL from config (DigiCert by default), token checked with OpenSSL | `record/tsa.py` | open |
| published roots: append-only list {cycle, root, token_hash, prev_entry_hash}, its check; RFC 4998 renewal as a stub | `record/roots.py` | open |
| bundle per record: record, inclusion path, root, token | `record/bundle.py` | open |
| verifier, CLI and `record/verifier.html`: record hash → prev link → inclusion path → root → published → TSA token, each named | `record/verify.py`, `record/verify.js`, `record/ui.html`, `record/build.sh` | open |
| "sealed" becomes "chained" for the free chain | `kernel/app/Main.hs`, `serve/serve.py`, README, tests | open |
| monthly batch as an operation: build the tree over the cycle's records, timestamp the root, append to the roots list, emit bundles, update the store | `radar/monthly.py`, `radar/config.toml` | closed |
| root publication: the static roots file for the site | `radar/publish.py` | closed |

Tests: `tests/record.py` (JCS vectors from RFC 8785, Merkle against
hand-built trees, tamper: one byte of a record, of a path, of the roots list
→ the right check fails), `radar/tests/test_monthly.py`; `record/verifier.html`
run in Chromium against the same bundles.

## A4 — selection seeded from a public beacon

| piece | files | side |
|---|---|---|
| drand quicknet: first round after the run starts, bounded retries, BLS check (RFC 9380 hash to G1) | `record/beacon.py` | open |
| seed = SHA-256(randomness ‖ site id ‖ cycle id); candidate order = by SHA-256(seed ‖ url); the selector runs on that order | `record/select.py` | open |
| record keeps chain hash, round, randomness, signature; if no round, the record says "selection not beacon-seeded" | `record/run.py` | open |
| verifier re-derives the order and the first pick; with the bundle, replays the whole selection | `record/verify.py`, `record/verify.js` | open |

Browser: `verifier.html` checks the round against the chain's schedule and the
randomness against the signature's hash, and says it does not check the BLS
signature; the CLI does. Surface Core's verifier must mirror: the order rule
(`releve-order/1`), and that `surface-core/select-1` is unchanged.

## A5 — owner's mandate

| piece | files | side |
|---|---|---|
| record: `mandate {granted, date}` and the statement "observed under the owner's mandate" / "observé sous mandat du propriétaire" | `record/run.py`, schema | open |
| report says it too | `kernel/src/Releve/Report.hs` | open |
| member store, per site only: url, last record hash and date, baseline date, mandate granted + date; sign-up form model with the mandate distinct from the consultation-voice checkbox | `radar/store.py`, `radar/signup.py` | closed |
| the monthly run passes `--mandate` for a site whose mandate is granted | `radar/monthly.py` | closed |

## A1 — stamp, self-hosted

| piece | files | side |
|---|---|---|
| generator: one HTML snippet, inline SVG, no external request; one accessible name, FR/EN; placeholder mark (no vector of the founder's emblem exists in the repos) | `radar/stamp.py` | closed |
| status page: answers on click with active / lapsed / reset and dates; no cookie, no script, no log | `radar/status.py` | closed |
| chain id: opaque, derived from the site's address | `radar/store.py` | closed |
| word check over every member-facing template | `radar/tests/test_words.py` | closed |

No design in relevé serves a stamp image on page load; the site repository,
where one might be, is not reachable (REPORT.md).

## A6 — mirror

| piece | files | side |
|---|---|---|
| off below 20 members; median per metric; leave-one-out sensitivity; published value rounded to a bucket at least that wide; exact arithmetic (fractions), no noise, no names, no ranks | `radar/mirror.py` | closed |

## Dependencies

- `py_ecc==8.0.0` (MIT; brings eth-typing, eth-utils, eth-hash, cytoolz,
  pydantic, all MIT or BSD): BLS12-381 pairings and RFC 9380 hash-to-G1 have
  no standard-library equivalent, and a hand-written pairing is the greater
  risk; used by the beacon check only (`record/requirements.txt`).
- Public suffix list (MPL-2.0, data, not code): required to tell first from
  third parties by registrable domain; pinned file, named in REUSE.toml.
- Everything else: the standard library and OpenSSL, as before. axe-core is
  used for evidence only, outside the repositories.
