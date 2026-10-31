# RADAR v2 (D-033): report

All six amendments are built, after A0, in two repositories:

- **relevé** (open, EUPL-1.2), branch `radar-v2`, pushed to GitHub as
  `claude/eloquent-dijkstra-fj4uo3`;
- **radar** (closed, beside relevé), branch `radar-v2`, pushed to a private
  repository of its own; never to this public one.

Nothing is deployed or published.

The checks pass on the final tree (`evidence/radar-v2/suite/summary.txt`):

| suite | result |
|---|---|
| `tests/run.py` | 98 ok |
| `tests/conduct.py` | 31 ok |
| `tests/service.py` | 47 ok |
| `tests/boundary.py` | 265 files, 0 problems |
| `tests/plie.py` | 21 of 21 |
| `tests/record.py` | 48 of 48 |
| `tests/survive.py` (0.10.1) | 41 of 41 |
| `reuse lint` | compliant |
| `radar/tests/run.py` | 24 of 24 |
| `radar/tests/test_disclosure_chain.py` | 8 of 8 |
| `radar/tests/test_changes.py` | 6 of 6 |

## The environment, and what it changes

| what | what was done instead | what remains |
|---|---|---|
| The network policy denies drand, DigiCert's TSA, publicsuffix.org and public sites. | The end-to-end run uses three local sites (`127.0.0.1`, `.2`, `.3`, port 80). | A live run on 3 public sites, below. |
| No live drand round can be fetched. | One real quicknet round (12040883, 2024-10-14 17:13:33 UTC), taken from drand's own test code (`tests/beacon/`). Its BLS signature verifies. | The live fetch path (`record/beacon.py`) is written but has not been exercised. |
| No real TSA is reachable. | The tests' own RFC 3161 authority, with its clock set by `faketime` to 17:13:30 that day, so that 12040883 is the first round after the commitment, as the first draw rule demanded. Since the draw rule of the cycle (below), `tests/record.py` also uses a beacon of its own. | The DigiCert path has not been exercised. |
| The sandbox ships Chromium for Playwright 1.63.0; the repo pins 1.64.0. | Local runs used 1.63.0. | `requirements.txt` keeps its pin. CI uses 1.64.0. |
| Installing Lean was refused here. | The Lean output (`record/gen/lean/`) is written. | It has never been compiled. |
| Surface Core and the site repository are not reachable. | — | See *Deferred*. |

## What changed, by amendment

**A0, the boundary.**
- `BOUNDARY.md` states the open, closed and excluded sides.
- `tests/boundary.py` (a CI job, and listed in CLAUDE.md) fails on: an open
  file importing a closed path, a missing SPDX header, or a closed directory
  or closed-licensed file in the open repository. It now also reads `.plie`,
  `.lean` and `.mjs`.
- Shown failing on four planted violations, then passing:
  `evidence/radar-v2/a0/`.
- `radar` was created with a README saying it is closed and depends on relevé.
- `receipt/` is a **vendored copy** of Surface Core's selector 0.3.1
  (`surface-core/select-1`), and the live service imports this copy. Nothing
  was moved or merged.

**plié, the language the core is written in.**
- `plie/plie.py` translates each source into Haskell, which runs in
  `releve core`; JavaScript, which runs in `record/verifier.html`; and Lean.
- The prelude (`plie/prelude/`) fixes each name's meaning in each language.
  SHA-256 is the one cryptographic primitive.
- `tests/plie.py` holds the Haskell and JavaScript versions to the same bytes,
  and the generated files kept in the repository to their sources.
- `HANDOVER.md` puts five questions to a logician.

**A2, observation apart from readings.**
- The observer records each request's status and whether it was sent before
  the robot's first gesture (the robot never answers a consent prompt). It
  counts the accessibility tree, through CDP, from the markup.
- `releve rules -` gives the rule results as data, with labels fail, review
  and hint only.
- Schema `releve-record/2` (`record/schema/`): the observation block is
  frozen. Every request is scheme and host only; a path, port or query is
  refused by the schema.
- Readings (`record/Readings.plie`), each a pure function of the observation
  and the rule results:
  - the WCAG table, with no percentage;
  - dependencies by registrable domain, under the pinned public suffix list
    2026-10-28 `9dfbe81`;
  - legibility;
  - energy, from a coefficient that names Sustainable Web Design v3, never on
    the stamp.
- `python -m record recompute` rebuilds the readings and compares bytes.
  Records of 0.10 are read, with what they did not record named.

**A3, chain, monthly root, published roots.**
- RFC 8785 canonical bytes and SHA-256 record hash; `prev`, `baseline` and
  `chain_status`.
- The month's tree follows RFC 6962, with leaves sorted by hash. It is built
  level by level, which gives the same tree as the RFC's split (checked for
  every size up to 2048).
- The root is dated by an RFC 3161 authority set in `radar/config.toml`
  (DigiCert now; a qualified eIDAS provider is a change to that one line).
- The published roots are an append-only list. RFC 4998 renewal has a stub
  interface (`record/roots.py`).
- Each delivered bundle holds the record, its path, the root and the token.
- The verifier (`python -m record verify`, `record/verifier.html`) names each
  check. The monthly operation and root publication are in `radar/monthly.py`.
- "Sealed" became "chained" everywhere the free chain is spoken of.

**A4, the beacon.**
- The candidates are committed to and the commitment is dated **before** the
  cycle begins.
- The round is the cycle's, quicknet's first after the cycle's first second
  (`releve-draw/1`), and its BLS signature is checked (`record/bls`). At
  first it was the first round after the commitment: see *No freedom left in
  a record*, below.
- seed = SHA-256(randomness ‖ site ‖ cycle). The candidates are read in
  SHA-256(seed ‖ url) order, and the unchanged selector picks from what was
  read in that order.
- The record keeps the chain hash, round, randomness, signature, commitment
  and its token, order, pages read and picks.
- The verifier re-derives all of it. Without a round, the record says
  "selection not beacon-seeded".
- `verifier.html` checks the round offline: right chain, randomness equal to
  the hash of the signature, the cycle's round, and the BLS signature, with
  the same Rust code as the command line.

**A5, the owner's mandate.**
- `mandate.granted` and `mandate.date` are kept per site
  (`radar/store.py`), apart from the consultation-voice checkbox
  (`radar/signup.py`), which the per-site store refuses to hold.
- When the mandate is granted, the robot runs with the mandate path. Records
  and reports say "observed under the owner's mandate" / "observé sous mandat
  du propriétaire".
- No sign-up form existed, so this is the data model and the robot path only.

**A1, the stamp.**
- `radar/stamp.py` emits one snippet: inline SVG on its own white ground,
  ink 17:1, inside a link to `status/<chain id>`. It loads no image, font,
  style sheet or script, and the link sends no referrer.
- It has one accessible name: "RADAR — Bureau des Surfaces, observé depuis
  octobre 2024" (EN: "observed since October 2024").
- The mark is a **placeholder** (a rounded square).
- `radar/status.py` answers a click with active, lapsed or reset and their
  dates. It sets no cookie, runs no script, keeps no log, and does not read
  the visitor's address.
- No design in relevé served a stamp on page load.

**A6, the mirror.**
- `radar/mirror.py` is off below 20 members.
- Each measure's median is published with its leave-one-out sensitivity, in a
  1-2-5 bucket at least as wide. Exact fractions, no noise, no names.

## Evidence

Everything is in `evidence/radar-v2/`; the session's logs also sit in its
scratchpad.

- **Unit tests per amendment, and full suite output:** `suite/*.log` and
  `suite/summary.txt`.
- **End-to-end run** on 3 local sites. Site 3's robots.txt says no and its
  owner's mandate says yes; it was observed, and its records say so.
  - `record-excerpt.json`: observation, readings, chain fields, beacon fields,
    selection, inclusion path.
  - `merkle-batch.json`: 6 leaves, root `76adb68e…`.
  - `roots.json`: the published roots file.
  - `mirror.json`: off, 3 members.
  - `bundles/`: two chained bundles of site 2.
  - `verify.log`: all six bundles pass every check; the chained ones were
    verified with their previous record.
- **Tamper tests:** `tamper.log`. One byte of a record fails `record-hash`;
  one byte of a path fails `inclusion-path`; one byte of the roots list fails
  `published`. `tests/record.py` adds:
  - a later round chosen fails `beacon-signature`;
  - a page added after the round fails `order`;
  - a commitment dated later fails `before-beacon` (and since, a later round
    drawn again, signed and its order followed, fails it too);
  - a page twice in two spellings, and requests in arrival order, fail
    `canonical`;
  - a forged previous record fails `prev-link`;
  - a changed token fails `published`.
- **Recompute:** `recompute.log`, all six records byte-equal, plus the
  record tests.
- **Browser verifier:** `verifier-html.log` and `verifier-html.png`: the same
  verdicts, and no network request.
- **Stamp:**
  - `stamp-fr-16px.png`, `stamp-fr-32px.png`, `stamp-en-16px.png`,
    `stamp-en-32px.png`;
  - `stamp-evidence.json`: axe-core 4.10.3 on `member-page.html`, **no
    violation** (22 rules passed);
  - the network log of the page load: **one request, the member's own page,
    none to the Bureau**; the click then opens the status page, and only it.
    `status-page.png` shows that page.

**After D-033: no freedom left in a record.** Read against one question:
what in a record could differ while its meaning stays the same, or be chosen
while it looks drawn? Three answers, each closed, each with its test
(`tests/record.py`).
- *The moment of the draw.* The round was the first after the commitment,
  and the commitment's moment was the Bureau's: it could commit again, every
  3 seconds, until an order suited it, and no verifier would see. The round
  is now the cycle's (`releve-draw/1`), and the candidates are dated before
  the cycle begins. Drawing again gives the same round, too late. A later
  round, signed and its order followed throughout, fails `before-beacon`.
- *Two spellings of one page.* Candidates were kept as written, so
  `https://x.fr/a`, `https://X.fr/a` and `https://x.fr/a#top` were three
  places in the order, three chances to be picked. A candidate is now
  admitted only in its one written form, once (`canonicalUrl`,
  `record/Seed.plie`); the run refuses any other before committing.
- *The order of arrival.* The requests were kept in the order the network
  gave them: up to log₂(n!) bits a record (about 272 for 60 requests) that
  no reading uses and the observer could have set. They are kept in one
  order. The verifier's `canonical` check holds both lists.
- Changes between two records became a Z-set in one form, so they add:
  from a to b, then b to c, they are those from a to c; the other way they
  are negated. With relevé 0.10.1's boundary, diffing is closed: the code,
  its laws and their tests moved to radar (`radar/changes.py`), where they
  give the same bytes as the plié version did.
- Laws now tested: the readings, the month's root and the commitment do not
  depend on the order their inputs come in.
- **What remains:** several candidate lists, each dated before a cycle,
  could be made and one kept once the round is known. Only publishing the
  commitments before the cycle begins would show there was one. It is
  bounded by the lists prepared beforehand, not by the rounds, as it was.
- **The tests' own beacon.** No recorded quicknet round falls on a cycle's
  first seconds, and drand cannot be reached from here. So the tests sign
  rounds under a key of their own, on quicknet's scheme and schedule
  (`record/bls/examples/beacon.rs`), named to relevé in `RELEVE_BEACON`, as
  `RELEVE_CA` names their authority. The verifier then names the chain it
  trusted as not quicknet's. Quicknet's own key is still held to its
  recorded round, on the command line, in WebAssembly and in the page.
- **The end-to-end evidence of D-033** (`evidence/radar-v2/bundles/`,
  `verify.log`) was made under the first draw rule. It verifies with the tree
  of D-033 (commit `0575d4f`), not under the cycle's rule.

**After D-033: the disclosure chain** (radar, `radar/disclosure_chain.py`,
EUPL-1.2 by request; its tests pass, 8 of 8).
- For a product behaviour it keeps four links: the behaviour; the policies
  that should disclose it, fetched and kept under their SHA-256; the vendor's
  own lookup; dated exhibits.
- Its verdict (disclosed, undisclosed, partially disclosed) is a written rule,
  and every input is logged so it can be derived again.
- `python -m radar chain add | verify | export`. `verify` refetches each
  policy and records whether it was amended after the observation; `export`
  writes a one-page summary with French and English headers.

## What the web server logs

The status page's own code logs nothing and does not read the visitor's
address. Whatever stands in front of it may still keep access logs: Caddy,
as `serve/install.sh` sets up for the free service, is configured there to
keep no request log. The same configuration must be used for the status
host. The stamp's link sends no `Referer`, so the member's page address never
reaches it.

## Signing keys after D-034

No RADAR path needs a Bureau signing key:
- records are chained by hash;
- months are dated by the authority's RFC 3161 signature;
- roots are published as a hash-linked list.

The only key in relevé is the WACZ bundle's ECDSA P-256 key. It is
generated per bundle and discarded, and proves only that the bundle is
unchanged since it was made. Its docstring now says so. Nothing was migrated
or deleted.

## Deferred

- **Live run on 3 public sites**, once the environment allows `api.drand.sh`
  (or another drand relay), `timestamp.digicert.com` and the sites. It is the
  same code with no recorded round and DigiCert as authority. From radar,
  with `RELEVE_HOME` set: `month(cycle, store, candidates, browser, config)`.
- **WACZ in the delivered bundle.** The verifier checks the seeded order and
  the first pick. A full replay of the selector needs the pages, which
  `receipt/` already bundles; `radar/monthly.py` does not attach them yet.
- **Surface Core's verifier must mirror two things:** the order rule
  (`releve-order/1`: candidates read by SHA-256(seed ‖ url)), and the
  `read`/`picks` fields; `surface-core/select-1` is unchanged.
- **Mirror at scale:** never run with 20 or more real members; unit-tested
  at 21.
- **A sign-up form** (only the model exists).
- **Lean:** compile `record/gen/lean`, then prove the first theorems
  (`HANDOVER.md`).

## Open questions for the founder

1. **The emblem.** No vector of the horizontal hourglass exists in the
   repositories; the stamp uses a placeholder. A vector, licensed for the
   stamp, replaces `MARK` in `radar/stamp.py`.
2. **Keys after D-034.** None is needed (above). Should the ephemeral WACZ
   key stay, or go, now that the RFC 3161 token dates the record?
3. **Qualified TSA.** Which eIDAS-qualified provider, and when? The switch is
   one line in `radar/config.toml`.
4. **drand in the browser.** *Answered since:* `verifier.html` checks the BLS
   signature itself, offline, with the same Rust code the command line uses
   (`record/bls`). The crates are dependencies, not copied, and their notice
   travels with the page.
5. **The consultation voice.** The per-site store may keep only five fields,
   so the voice is returned to whoever keeps members and not stored here.
   Where does it live?
6. **The energy coefficient.** Sustainable Web Design v3 (0.81 kWh per GB) is
   named. v4 exists, with different factors. Which one?
7. **`serve/install.sh` and `serve/egress.sh`.** Read strictly, they are
   deployment automation, which BOUNDARY.md calls closed. They stay open
   until you decide.
8. **`receipt/`.** It is a vendored copy of Surface Core's selector. Which
   repository is its home?
