# Compliance

How relevé, and the RADAR built on it, stand against the rules Bureau des
Surfaces observes and holds others to. Checked on 2026-10-31, on the tree this
file is committed with.

This file states what was checked and how. It is not a declaration of
conformity: as relevé's own reports say, a conformity statement takes a
complete evaluation, which includes a person using assistive technology.

## Summary

| rule | where it bears | how it stands | evidence |
|---|---|---|---|
| EUPL-1.2, REUSE 3.3 | every file of relevé | every file states its licence; open and closed kept apart | `reuse lint`, `tests/boundary.py` (0 problems, 220 files) |
| Free dependencies only | runtime and tests | all MIT, BSD-3-Clause, Apache-2.0, PSF-2.0 or MPL-2.0 | *Licences* below |
| Generative AI disclosed (NLnet's policy) | every commit | each commit made with a model names it; none at runtime | *How it is made*, README |
| WCAG 2.2 AA, RGAA 4.1.2 (EAA) | the pages relevé and RADAR hand out | no failure found by relevé's rules or by axe-core | `evidence/radar-v2/own-pages/` |
| GDPR, ePrivacy (CNIL) | the service, the status page, records, case files | nothing kept of a request; no cookie; no personal data in records | `tests/service.py`, `radar` tests, *Privacy* below |
| RGESN 2024 | the pages handed out | light single files, nothing fetched on load; hints only on transport | `evidence/radar-v2/own-pages/releve-facts.md` |
| AI Act, article 50 | relevé and RADAR | no AI system: every verdict is a rule in plain code | CLAUDE.md, README |
| The Bureau's own words | member-facing text | no "compliant", "certified", "accessible", "labelled", "validated", "approved" or their French forms | radar's word check |

## Licences

- relevé is under EUPL-1.2 (OSI-approved), in English and French (`LICENSE`,
  `LICENSE-FR.txt`).
- `reuse lint` passes.
- `tests/boundary.py` holds BOUNDARY.md: open code imports nothing closed, no
  closed file is kept here, and every source file names its licence.

Third-party data kept here, each named in `REUSE.toml` with its own licence:
- the public suffix list (MPL-2.0);
- one drand beacon round quoted from drand's tests (MIT or Apache-2.0).

Dependencies, with their licences as their packages state them:

| dependency | licence |
|---|---|
| Playwright | Apache-2.0 |
| cryptography | Apache-2.0 OR BSD-3-Clause |
| py_ecc and its dependencies (eth-typing, eth-utils, eth-hash, pydantic, pydantic-core, annotated-types, typing-inspection) | MIT |
| cytoolz, toolz | BSD-3-Clause |
| typing_extensions | PSF-2.0 |
| aeson, cryptohash-sha256 (Haskell) | BSD-3-Clause |

axe-core (MPL-2.0) is used to produce evidence and is not part of relevé.

Nothing in relevé is taken from other software.

## How it is made

No model runs when relevé observes, judges or checks.

The code is written by its maintainer, partly with a generative model. Every
commit written with a model says so (CLAUDE.md): the author line names the
model and its version, and the message ends with:
- the model and its maker;
- a summary of the prompt;
- whether a person changed the output;
- the trailer `Assisted-by`.

This was checked for every commit of the RADAR work, in both repositories.

## Accessibility

relevé observed its own pages, and those RADAR hands out:
- the record verifier;
- the receipt verifier;
- the status page, in French and in English;
- a member's page carrying the stamp.

Its rules found no failure. The points it leaves to a person were answered.
Two led to changes:
- page titles now name the page, then the site (RGAA 8.6);
- required fields say so in words (RGAA 11.10).

axe-core found no violation, in light and dark themes. The stamp has one
accessible name, and its ink is 17:1 on its own ground.

**Not done:** a test by a person with a screen reader (NVDA, VoiceOver). It is
the step before any statement of conformity.

## Privacy

- **The free service** keeps nothing of a request: no account, no cookie, no
  script, no log; counts by week only. `tests/service.py` checks it.
- **A RADAR record** holds no text from the page and no personal data. A
  request is kept as scheme and host only, and the schema refuses a path, a
  query or a header.
- **The member store** keeps five fields per site, and refuses any other.
- **The status page:**
  - it sets no cookie, runs no script and logs nothing;
  - it never reads the visitor's address;
  - the stamp's link sends no referrer;
  - the web server in front of it is to keep no request log, as
    `serve/install.sh` sets up for the free service.
- **Case files of the disclosure chain** (radar) hold public policy texts.
  Exhibits are kept by path and hash only, never copied. Its documentation
  says to minimise them and to delete them with the case.
- **Tests** use fixtures only. No personal address, key or token is in either
  repository's history.

## Eco-design

- The record verifier is one file of 40 kB.
- The status page is 1 kB, with no font, image or script.
- The stamp is inline SVG and fetches nothing.

relevé's sobriety rules found only transport hints on the local test server
(compression, HTTPS, HTTP/2, IPv6). In production these are the proxy's
(Caddy).

The energy reading names its coefficient and is never shown on a stamp.

## What remains for a person

- A screen-reader test of the pages above.
- Reading NLnet's current policy on generative AI against *How it is made*.
  It could not be reached from where this was checked; in particular, check
  whether it asks for full prompt logs as well as the per-commit summaries.
- The founder's open questions in REPORT.md.
