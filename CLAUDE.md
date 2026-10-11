# Working on relevé

For any session of a generative model that works in this repository. People
may read it too: it is the house rule, written down.

## What holds

- No model runs when relevé observes or judges. Every verdict is a rule in
  plain code, and the same corpus read by the same release gives the same
  report.
- The criteria change only with their version; `tests/run.py` refuses one
  without the other.
- The observer's conduct (README, *Conduct*) is code, and `tests/conduct.py`
  checks it. It is never loosened to make a page readable.
- The service keeps nothing: no account, no cookie, no script, no log of who
  asked or of what. `tests/service.py` checks it.
- Every file states its licence, in an SPDX header or in `REUSE.toml`.
  EUPL-1.2 throughout; dependencies under free licences only; nothing taken
  from other software.
- One way to do each thing. Clean, laconic code; no option without a need.

## Before a commit

```sh
python tests/run.py        # the kernel, against recorded pages
python tests/conduct.py    # the observer, against local sites that say no
python tests/service.py    # the service: a report out, nothing left behind
reuse lint
```

All four pass. A change of judgement shows as a diff in `tests/expected/`
and is accepted on purpose (`--accept`), never in passing.

## Each commit says how it was made

The author is the maintainer *with* the model, by name and version:

```
Author: Anna Teterkina with Claude Opus 5.5 <anna@bureaudessurfaces.fr>
```

and the message ends with three lines before any trailer:

```
Model: the model and its maker, and who directed the session.
Prompt (summary): what was asked, in one sentence.
Output: this commit, as the model wrote it. Or: what a person changed after.
```

This is the form asked for by NLnet's policy on generative AI
(https://nlnet.nl/foundation/policies/generativeAI/). A commit written by a
person alone carries none of it.
