# relevé

Observe a rendered web page. Say what it is. Say what it could become. Keep every reading.

A *relevé* is a measured survey: the drawing an architect makes of a building
as it stands, before anyone proposes to change it. This tool makes one for
web pages, against accessibility, AI-transparency and sobriety criteria.

## Why

A page is a surface. What it is to its reader is what it renders: the
colours on screen, the names a screen reader announces, the bytes that
travel. It is not what its source code intends. relevé looks at the
rendered page only.

Most checking tools blur three acts: looking, judging and remembering.
relevé keeps them apart, because each has its own failure mode. Looking is
unreliable: pages change, networks wobble. Judging should be exact:
the same evidence, the same verdict, always. Remembering must be
tamper-evident, because a report is a claim someone may rely on.

```
page ──observe──▶ observation ──releve ingest──▶ corpus   (append-only, sealed)
                                                   │
                         ┌─────────────────────────┴─────────────────────────┐
                       facts                                               atlas
          what the page is: one checkable                what the page could become:
          line per finding, for a person                 structure, constraints, changes,
                         │                                as data for study
               edits ──releve correct──▶ corpus
```

## Principles

1. **Look at the surface.** Observation happens in a real browser: the
   rendered tree, computed colours composited against their actual
   backgrounds, bytes measured on the wire, the layout re-measured at 320 px.
2. **Record once, judge purely.** An observation is written once. Judgement
   is a pure function of the corpus and of the judge, so the same corpus
   read by the same release yields the same report today and in five
   years, and new criteria can be run against old observations. Every
   report names the criteria version that judged it, and the tests refuse
   criteria that changed under an unchanged version. No model is trained
   or consulted: every verdict comes from a rule written in plain code.
3. **Overwrite nothing.** The corpus only grows. Each record seals the one
   before it (SHA-256), so any alteration is detectable (`releve verify`).
   Reports are never stored; they are recomputed.
4. **Every line carries its evidence.** A finding names the element, the
   value observed and the rule applied. Checking a claim takes a glance,
   not a search.
5. **Say where judgement ends.** `FAIL` means a stated rule is broken.
   `REVIEW` means a person must decide: a machine cannot know whether an
   image is decorative. `HINT` means nothing is broken, but something could
   be lighter. The tool does not guess.
6. **Corrections are events, not edits.** A person's reading of a finding is
   appended to the corpus like any observation. It holds for that page from
   then on, for as long as what is seen reads the same. Where the person
   and the machine disagree, both verdicts are kept. When what is seen
   changes, because the page did or because the judge words it otherwise,
   a reading that differed from the machine's no longer applies, and the
   machine's does not quietly replace it: the finding returns as `REVIEW`.
7. **Change is what matters.** When a page is observed again, findings on
   surfaces new since the last observation are marked, and each open finding
   says how many observations it has stood through.
8. **A finding points at its remedy.** Where one exists, each finding names
   the smallest change that satisfies it: the nearest compliant colour, or
   the size an image should be served at.

## The two outputs

**facts** is a Markdown document made for proofreading. Each finding is one
line:

```
- **FAIL** text-contrast · `p.lead` · #999999 on #ffffff · 2.84:1, needs 4.50:1 · “Nos services” → use #767676 {5af26a21}
```

To correct it, change the verdict word, add a note after `//`, and pipe
the file back through `releve correct`. Lines left untouched record
nothing. A line changed in a way that cannot be read is refused, and
nothing is recorded: a decision is never dropped in silence.

**atlas** is JSON lines, one per observation: the page's shape (its
landmarks, headings and controls in reading order), its footprint, what
changed since the previous observation, and every open finding with the
full surface it concerns, the proposed change, and the person's verdict
next to the machine's. It is a dataset of how page structure meets its
constraints, and of what it would take to reconcile them.

## Use

Requirements: Python ≥ 3.10 with Playwright, and GHC ≥ 9.2 with cabal.

```sh
pip install -r observe/requirements.txt && playwright install chromium
cabal install                     # builds `releve`; or take a built one from the Releases page

python observe/observe.py https://example.org --contact https://you.example/robot | releve ingest corpus.jsonl
releve facts corpus.jsonl > facts.md       # proofread, edit
releve correct corpus.jsonl < facts.md     # your edits become events
releve atlas corpus.jsonl > atlas.jsonl
releve verify corpus.jsonl
```

`observe` takes several URLs and writes one line per page, so any crawler
can feed it. `--contact` is required: it is the page where site owners
read what the robot does and reach whoever runs it. `releve facts` takes an observation id or a URL, and defaults
to the latest; `--all` gives the latest report of every page in one
document, which `releve correct` reads back section by section.

Everything is UTF-8 with line feeds, on every system. Windows PowerShell 5
re-encodes what passes through `|` and `>`: use `cmd`, or PowerShell 7.

## Tests

```sh
python tests/run.py            # the kernel against recorded pages: no browser, no network
python tests/run.py --record   # re-record the test pages after changing the observer
python tests/conduct.py        # the observer against local sites that say no
```

`tests/pages/` holds pages with known defects and edge cases, each
commented with the reading it should produce. The recorded observations
and expected reports sit beside them, so any change in judgement shows up
as a diff to review.

## Criteria (v2)

| id | checks | source |
|---|---|---|
| page-title | the page has a title | RGAA 8.5 · WCAG 2.4.2 |
| page-lang | the page states its language | RGAA 8.3 · WCAG 3.1.1 |
| zoom | zoom is not blocked | RGAA 10.4 · WCAG 1.4.4 |
| reflow | no horizontal scrolling at 320 px | RGAA 10.11 · WCAG 1.4.10 |
| main-region | the main content is marked | RGAA 12.6 · WCAG 2.4.1 |
| heading-order | heading levels follow each other | RGAA 9.1 · WCAG 1.3.1 |
| image-alt | images carry a text alternative | RGAA 1.1–1.3 · WCAG 1.1.1 |
| text-contrast | text contrasts with its background | RGAA 3.2 · WCAG 1.4.3 |
| link-name | links have a name | RGAA 6.1–6.2 · WCAG 2.4.4 |
| button-name | buttons have a name | RGAA 11.9 · WCAG 4.1.2 |
| control-label | form fields have a label | RGAA 11.1 · WCAG 1.3.1 |
| frame-title | frames have a title | RGAA 2.1 · WCAG 4.1.2 |
| autoplay | no sound starts by itself | RGAA 4.10 · WCAG 1.4.2 |
| unique-ids | element ids are unique | RGAA 8.2 |
| ai-disclosure | conversational AI is disclosed | AI Act art. 50(1) |
| image-weight | bitmap images are not larger than shown | RGESN; 2× threshold is the tool's |
| image-format | heavy images use a modern format | RGESN; 30 kB threshold is the tool's |

Each criterion is one pure function in `kernel/src/Releve/Criteria.hs`.
Adding one means writing one function; nothing else changes.

## Scope and limits

- relevé is not a conformity audit. Automated observation covers part of
  what RGAA asks; much of it needs human judgement, which is why `REVIEW`
  exists.
- It observes one page, at one viewport (1280 × 800, then 320 px for
  reflow), at one moment. Interactive states (open menus, dialogs), shadow
  DOM and cross-origin frames are not observed.
- Contrast is computed against resolved background colours. Text over an
  image, or partly transparent text, is marked `REVIEW`; fully transparent
  text and text in disabled controls are not judged.
- A surface's identity follows its position in the document. Restructuring
  a page can make an unchanged element appear new.
- The footprint is measured, not scored: document nodes, requests,
  kilobytes and third-party hosts, comparable only under the same
  measurement conditions. It is the page as a reader's browser loads it at
  1280 px, scrolled once to its end: every redirect hop is a request, a
  `data:` address is not, and what the measuring itself fetches (the
  screenshot, the 320 px pass) is left out. Document nodes include those
  inside inline SVG, which some other tools leave out.
- Rule references are indicative; the rule texts prevail.

## Conduct

The observer's limits are written into `observe.py`, not left to
configuration, and `tests/conduct.py` checks each of them:

- It reads `robots.txt` before the first request to a site and obeys it
  (RFC 9309); a site that does not answer for it is left alone. Only the
  owner's written leave (`--mandate`) overrides it, and the leave is
  recorded in every observation it covers.
- It fetches one page at a time, at least one second apart per site,
  longer if `robots.txt` asks.
- It observes web addresses only (http, https).
- A page that answers with an error, or puts a challenge or CAPTCHA before
  its content, is left alone at once: no retry, no workaround. When the
  answer is the site pushing back (429, 503, a challenge), the whole site
  is left alone for the rest of the run.
- Wherever a page leads the browser, by redirect, refresh or script, the
  address is requested only if `robots.txt` admits it. The leave of one
  site's owner never extends to another site.
- What a page loads into itself (images, scripts, frames) is fetched as
  any browser would fetch it; `robots.txt` is consulted for pages, not for
  their parts.
- A page that tries to leave for a closed address at any moment, or sends
  a form by its own script, is not recorded; the form is never sent.
- It submits no forms, opens no windows, dismisses no dialogs, keeps no
  session, and names
  itself (`releve-observe/0.4`) with its operator's contact address.

It keeps only what judgement needs: text excerpts of at most 80
characters, and screenshots only when asked, stored locally. A corpus
still holds fragments of the pages observed; treat it as their data, not
yours.

relevé holds itself to what it checks. Its outputs are plain Markdown and
JSON, structured by headings and lists, with verdicts given as words and
never as colours alone. It sends no telemetry and makes no network
requests of its own beyond loading the pages it is asked to observe.

## How it was made

relevé was written with a generative AI model, and says so. The code, the
tests and this text were produced by Claude, a model made by Anthropic
(Opus 5 for release 0.1 in September 2026, Opus 5.5 since), in sessions
directed by Anna Teterkina. She set what the tool is for, the constraints
it works under and the standard it is held to; within them the design and
the wording are the model's. She maintains it and answers for it.

Each commit names the model, summarises the instruction it answered, and
is the model's output as written; `CLAUDE.md` holds the rule. The prompts themselves are kept by the
maintainer. Before 0.3 the code was read twice by a separate instance of
the model, and what it found was corrected.

No part was knowingly taken from other software. The output has not been
compared against existing code.

The published history begins at 0.2. Release 0.1 scored the footprint with
reference tables whose licence this one cannot carry; they were removed,
and the commits that held them are not published.

None of this touches how the tool works: when relevé observes and judges,
no model runs.

## Licence

European Union Public Licence 1.2 (`LICENSE`). Every file states its
licence, in an SPDX header or in `REUSE.toml`; `reuse lint` checks it.
