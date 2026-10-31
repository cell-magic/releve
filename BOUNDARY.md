# Boundary

What of the Bureau des Surfaces' work is open, what is closed, and what is
kept out of every Bureau repository. Decision D-026; this file is its text.
`tests/boundary.py` holds the repository to it, in CI and before a commit.

## Open: EUPL-1.2, public, in this repository

Anyone can read, run and check it. It is what a verdict and a record rest on.

- the deterministic rules and the rule engine (`kernel/`)
- the observer (`observe/`)
- the record format and its JSON Schema; canonical bytes, hashing and the
  chain; the RFC 3161 time-stamp client (`record/`, `kernel/app/Stamp.hs`)
- Merkle inclusion verification, and the published-roots format and its check
  (`record/`)
- the page selector and the replay of its beacon-seeded order (`receipt/`,
  `record/`)
- the WACZ bundle and receipt tooling (`receipt/`)
- the offline verifier, on the command line and as `verifier.html`
  (`record/`, `receipt/`)
- the public specification: README, this file, the schemas
- the free report service, as software anyone can run on their own machine
  (`serve/`); see *Open questions*

## Closed: the Bureau's, private, never in this repository

- RADAR: sign-up, the member store, the mandate and consultation-voice flags,
  the monthly batch as an operation, root publication, the stamp generator,
  the status page, mirror aggregation
- the services the Bureau operates, as operated: hosts, keys, configuration
- deployment automation for the Bureau's own machines
- client adapters and guard synthesis (`surface-core-lab`)

Closed code lives in its own repository (`radar`, beside this one) and uses
this one as a library.

## Excluded from every Bureau repository

The founder's personal research model, and anything derived from it.

## Rules

1. Open code never imports closed code. Closed code may depend on open code.
2. No closed directory, and no file under the closed licence marker
   (`LicenseRef-Bureau-Closed`), appears in this repository.
3. Every open source file carries an SPDX header naming EUPL-1.2. A file that
   cannot carry a comment is named in `REUSE.toml`, and so is third-party data
   kept here under its own free licence (the public suffix list, MPL-2.0; a
   drand round quoted from drand's tests, MIT or Apache-2.0).

`tests/boundary.py` fails on any of the three. The names it treats as closed
are these, as a directory or as a module imported:

```boundary
radar surface-core-lab surface_core_lab members signup mirror status-page stamp-generator bureau-ops
```

## Open questions

- `serve/install.sh` and `serve/egress.sh` install and route the free service
  on a machine. They name no Bureau host or key, and anyone can run them on
  their own; read strictly, they are deployment automation. They stay here,
  open, until the founder decides.
- `receipt/` is a vendored copy of Surface Core's selector (it states its own
  version, 0.3.1, and protocol `surface-core/select-1`); the live service
  imports this copy. Whether Surface Core's own repository holds the same
  code is not checked from here. Nothing is moved or merged until the founder
  decides.
