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
                ┌──────────────────────────────────┼──────────────────────────────────┐
              facts                              report                              atlas
   what the page is: one checkable     the same, for the person       what the page could become:
   line per finding, for a reviewer    whose page it is: a page       structure, constraints, changes,
                │                      of HTML, English or French     as data for study
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
   be lighter. The tool does not guess. Where it cannot decide, it puts the
   question, in words a person answers with yes or no; a failure it can
   show is never put as a question.
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

## The three outputs

**facts** is a Markdown document made for proofreading. Each finding is one
line:

```
- **FAIL** text-contrast · `p.lead` · #999999 on #ffffff · 2.84:1, needs 4.50:1 · “Nos services” → use #767676 {5af26a21}
```

To correct it, change the verdict word, add a note after `//`, and pipe
the file back through `releve correct`. Lines left untouched record
nothing. A line changed in a way that cannot be read is refused, and
nothing is recorded: a decision is never dropped in silence.

A question asked of the page as a whole, such as whether information is
given by colour alone, comes back word for word on every page built on the
same template. Pages share a template when they load the same style sheets
and scripts, at the same sizes, and carry the same style sheets written into
them; fonts are left out, since a browser fetches only those a page uses.
With `--all`, such a question is asked once, under "the whole site", and
one answer covers every page counted with it, recorded as one event. The
answer holds on each of those pages, and on their later observations, while
the page keeps that template; a page that changes it is asked again, and so
is a page first seen later. A question about what a page holds, its images,
its fields, its tables, its language, stays with the page.

**report** is one page of HTML, without script, in English or in French,
for the person whose pages they are. The method comes before the findings.
Each finding stands with its remedy, under its criterion and what that
criterion is for; the lightest work comes first; and the page ends on what
was not looked at. Read from a corpus, it says what changed since the
last observation. Read from standard input (`releve report en -`), it
writes the report and keeps nothing.

**declarations** lists the criteria that no rule can see from a page and
that hold for a whole site: the 64 RGESN 2024 criteria on how the service
is decided, built, hosted and run, the 5 RGAA criteria on a set of pages
(navigation systems, menus, site map, search), paragraphs 2 to 4 of
article 50 of the AI Act, for what an AI system does beyond the page, and
9 provisions other laws and standards add to what a page shows: WCAG 1.2.4
(live captions) and 3.2.6 (consistent help), article 13(2) of the European Accessibility Act, §4 of the
BITV 2.0, section 14 of the AODA, §1798.135 of the CPRA and §7025 of its
regulations, article 25 of the DSA and article 24 of the PIPL. Each line
holds the owner's answer, yes, no, n/a or open, a note after `//`, and
what the latest observation saw that bears on it. Edited and piped back
through `releve declare`, the changed lines become events that hold for
the whole record. The questions are this tool's
short form; the official text prevails, and every report links to it.

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
releve declarations corpus.jsonl > d.md    # the RGESN criteria no rule can see, to declare
releve declare corpus.jsonl < d.md         # the owner's answers become events
releve report fr corpus.jsonl > report.html # for the pages' owner; en or fr
releve atlas corpus.jsonl > atlas.jsonl
releve verify corpus.jsonl
releve stamp corpus.jsonl                 # dated by a time-stamping authority (RFC 3161); needs openssl and curl
releve guide en > criteria.html             # what each criterion is for
releve frameworks                           # each law and standard, and what of it is addressed (JSON lines)

# or, keeping nothing:
python observe/observe.py https://example.org --contact https://you.example/robot | releve report en - > report.html
```

`observe` takes several URLs and writes one line per page, so any crawler
can feed it. `--contact` is required: it is the page where site owners
read what the robot does and reach whoever runs it. `releve facts` takes an observation id or a URL, and defaults
to the latest; `--all` gives the latest report of every page in one
document, which `releve correct` reads back section by section.

Everything is UTF-8 with line feeds, on every system. The observer writes
its records in ASCII alone, so they pass through any shell unchanged. Windows
PowerShell 5 still re-encodes the reports `releve` writes, and turns `>` into
UTF-16: use `cmd`, or PowerShell 7.

## As a page anyone can use

```sh
python serve/serve.py --contact https://you.example/robot      # then open http://127.0.0.1:8000/
```

`serve` puts the whole of it behind a form: the address of a page in, its
report out, in English or in French. The page it serves is static HTML,
without script.

- **Nothing is kept.** No account, no cookie, no log of who asked or of
  what was asked. An observation lives in memory for the time of the
  answer.
- **What is counted stays with whoever runs it.** Each report given adds
  one to the counts of its week: in which language, whether it followed a
  record handed back, and the broad region (Europe, Asia…) that the
  browser's language setting names, as in `fr-FR`. No address, no time
  finer than the week, nothing that ties a number to one request. No page
  shows them: `serve/counts.py FILE` prints the weeks that have ended, a
  region counted fewer than five times in a week shown as such.
  `--counts FILE` keeps them across restarts.
- **What a rule cannot decide is put to the person.** Each point to decide
  comes as a question with yes, no and a note, inside the report. The
  answers go back with the record, in the same form; they are written into
  it as that person's readings, beside what the rule said, and the report
  comes back as it now stands. No page is visited for that, and nothing is
  counted.
- **The owner declares what no page shows.** The report ends with the
  RGESN criteria that are declared, not observed, each with yes, no, not
  applicable and a note, the answer in force already chosen. They travel
  in the same form, and only what changed is written into the record.
- **The record belongs to whoever asked.** Each report offers its record
  as a small file. Handed back with the next request, it lets the report
  say what was mended, what is new and what stands. The record is the
  sealed corpus: one whose seals do not hold is refused.
- **It goes where a visitor could, and nowhere else.** Only public
  addresses on the web's own ports are requested, by the page or by
  anything the page loads. `robots.txt` is obeyed, and no mandate can be
  claimed through a form. One site is visited at most once every ten
  seconds; one page is observed at a time, and requests past the few that
  may wait are told to come back.

`--shell en=FILE --shell fr=FILE` sets the report in a page of your own
(`<!-- relevé -->` marks the place), `--static DIR` serves what that page
needs. One page takes two to ten seconds and, with the browser, up to
about one gigabyte of memory for a heavy one; two gigabytes are enough.

To put it online, on a machine given over to it (Ubuntu 24.04):

```sh
sudo bash serve/install.sh releve.you.example https://you.example/robot
```

`serve/install.sh` builds relevé in a folder of its own, runs the three
sets of checks there, and only then starts the service: a unit that keeps
none of its output, confined to what it needs, behind a proxy (Caddy) that
keeps no log of requests, failed ones included, and does not pass the
visitor's address on to the service. It then asks the running
service for a report and says what came back. Run again, it renews: the
service stays as it was until the checks pass, and returns to what it was
if no report comes back. `--playwright VERSION` brings a newer browser
than the one relevé was last tried with; a service in the open should not
run an old one. What it does not give is the browser's own sandbox: the
browser is confined by the unit, as a user that owns nothing, on a machine
that holds no data and no key. Keep that machine away from any private
network: the address check is made when a request is asked for, and the
unit's address filter is the second lock.

## Tests

```sh
python tests/run.py            # the kernel against recorded pages: no browser, no network
python tests/run.py --record [PAGE ...]   # re-record the test pages, or those named, after changing the observer
python tests/conduct.py        # the observer against local sites that say no
python tests/service.py        # the service against local sites: a report out, nothing left behind
```

`tests/pages/` holds pages with known defects and edge cases, each
commented with the reading it should produce. The recorded observations
and expected reports sit beside them, so any change in judgement shows up
as a diff to review.

## Criteria (v9)

| id | checks | source |
|---|---|---|
| page-title | the page has a title | RGAA 8.5 · WCAG 2.4.2 |
| page-lang | the page states its language | RGAA 8.3 · WCAG 3.1.1 |
| doctype | the page declares its document type | RGAA 8.1 |
| zoom | zoom is not blocked | RGAA 10.4 · WCAG 1.4.4 |
| reflow | no horizontal scrolling at 320 px | RGAA 10.11 · WCAG 1.4.10 · RGESN 2.5 |
| main-region | the main content is marked | RGAA 9.2 · 12.6 · WCAG 2.4.1 |
| skip-link | a link leads to the main content | RGAA 12.7 · WCAG 2.4.1 |
| heading-order | heading levels follow each other | RGAA 9.1 · WCAG 1.3.1 |
| heading-look | what looks like a heading is one | RGAA 9.1 · WCAG 1.3.1; the thresholds are the tool's |
| list-look | what looks like a list is one | RGAA 9.3 · WCAG 1.3.1 |
| empty-blocks | no element is used as a gap | RGAA 8.9 · WCAG 1.3.1 |
| presentation | appearance is left to the style sheet | RGAA 10.1 · WCAG 1.3.1 |
| image-alt | images carry a text alternative; a person says whether it is decorative, and whether the alternative says what the image says | RGAA 1.1–1.3 · WCAG 1.1.1 |
| text-contrast | text contrasts with its background | RGAA 3.2 · WCAG 1.4.3 |
| link-name | links have a name | RGAA 6.1–6.2 · WCAG 2.4.4 |
| link-distinct | links to different places differ in name | RGAA 6.1 · WCAG 2.4.4 |
| button-name | buttons have a name | RGAA 11.9 · WCAG 4.1.2 |
| label-in-name | the words shown are in the name | RGAA 6.1 · 11.2 · 11.9 · WCAG 2.5.3 |
| control-label | form fields have a name | RGAA 11.1 · WCAG 1.3.1 |
| group-legend | groups of fields have a legend | RGAA 11.6 · WCAG 1.3.1 |
| field-group | choices of one question are grouped | RGAA 11.5 · WCAG 1.3.1 |
| autocomplete | fields for personal data state their purpose | RGAA 11.13 · WCAG 1.3.5 |
| table-headers | data tables declare their headers | RGAA 5.3 · 5.6–5.8 · WCAG 1.3.1 |
| frame-title | frames have a title | RGAA 2.1 · WCAG 4.1.2 |
| autoplay | no sound starts by itself | RGAA 4.10 · WCAG 1.4.2 |
| media-captions | videos carry captions | RGAA 4.3 · WCAG 1.2.2 |
| unique-ids | element ids are unique | RGAA 8.2 |
| tab-order | the keyboard follows the order of the page | RGAA 12.8 · WCAG 2.4.3 |
| hidden-focus | nothing hidden takes the focus | RGAA 10.8 · WCAG 4.1.2 |
| focus-visible | the focus can be seen | RGAA 10.7 · WCAG 2.4.7 |
| focus-obscured | the focus is not hidden by the page's own content, such as a fixed header or a banner | WCAG 2.4.11 |
| target-size | targets are 24 × 24 px or more, or have room; a target in a sentence, or drawn by the browser, is the exception | WCAG 2.5.8 |
| authentication | signing in asks nothing to remember or copy; a field that turns password managers away says so | WCAG 3.3.8 |
| keyboard-trap | the keyboard can leave what it enters | RGAA 12.9 · WCAG 2.1.2 |
| lang-code | language codes are valid; a person says they are right | RGAA 8.4 · 8.7 · 8.8 · WCAG 3.1.1 · 3.1.2 |
| direction | right-to-left text declares its direction | RGAA 8.10 · WCAG 1.3.2 |
| text-spacing | text survives wider spacing | RGAA 10.12 · WCAG 1.4.12 |
| motion | what moves without end can be stopped | RGAA 13.8 · WCAG 2.2.2 |
| clickable | what the pointer clicks, the keyboard reaches | RGAA 7.3 · WCAG 2.1.1 |
| generated-text | words stay without the style sheet | RGAA 10.2 · WCAG 1.3.1 |
| paired-colours | a text colour comes with a background | RGAA 10.5 |
| link-visible | links stand out from the text around them | RGAA 10.6 · WCAG 1.4.1 |
| cryptic | emoji have a text alternative | RGAA 13.5 · 13.6 |
| captcha | a CAPTCHA has another way through | RGAA 1.4 · 1.5 · WCAG 1.1.1 |
| documents | office documents are accessible | RGAA 13.3 · 13.4 |
| no-popup | no window opens by itself | RGAA 13.2 · WCAG 3.2.1 |
| refresh | the page does not reload or leave on a timer | RGAA 13.1 · WCAG 2.2.1 |
| ai-disclosure | conversational AI is disclosed | AI Act art. 50(1) |
| ai-image | images made by AI say so | AI Act art. 50(2) · 50(4) |
| asks-on-arrival | nothing is asked of the device on arrival | RGESN 4.13 · 6.6 · AI Act art. 50(3) |
| consent-choice | refusing cookies is as easy as accepting them: accepting alone fails; refusing smaller, or plainer, is put to a person | GDPR article 7 · CNIL 2020-091 · CPRA regulations §7004(a)(2); the threshold (2× the area) is the tool's |
| third-parties | third parties wait for consent | RGESN 4.4 |
| media-autoplay | nothing plays by itself | RGESN 4.1 |
| endless | the page has an end | RGESN 4.2; the threshold (one screen, twice) is the tool's |
| fonts | fonts are few and light | RGESN 4.8 |
| compression | text travels compressed | RGESN 6.3; the threshold (1 kB) is the tool's |
| caching | what does not change is kept by the browser | RGESN 6.2 |
| protocol | the page travels by current protocols | RGESN 3.3 · 6.7 |
| lazy-images | images far down the page wait to be reached | RGESN 6.5; the threshold (two screens) is the tool's |
| image-weight | images are not larger than shown | RGESN 6.4; the threshold (2×) is the tool's |
| image-format | heavy images use a modern format | RGESN 5.1; the threshold (30 kB) is the tool's |
| review-images … review-consultation | twelve themes of questions, one per RGAA criterion no rule decides, and WCAG 2.5.7 (dragging) and 3.3.7 (redundant entry), put to the reviewer for each page, and once for pages that share a template where it asks of the page as a whole; a theme, or a question, is not applicable where the page holds nothing it applies to | RGAA 1.6–1.9 · 2.2 · 3.1 · 3.3 · 4.1–4.13 · 5.1–5.5 · 7.1–7.5 · 8.6 · 9.4 · 10.3 · 10.9 · 10.10 · 10.13 · 10.14 · 11.3–11.12 · 12.10 · 12.11 · 13.7 · 13.9–13.12 |

Rules, questions and declarations together cover each of the 106 RGAA
criteria and the 78 RGESN criteria once, and each of the 7 paragraphs of
article 50 of the AI Act: paragraphs 1 to 5 by rule, 2 to 4 also by the
owner's declaration for what no page shows, and 6 and 7, which place no duty
on a site, by saying so. `tests/run.py` holds them to it.
To cover a criterion is not to settle it: a question is settled by the
reviewer's answer, a declaration by the owner's.

### Dated from outside

A corpus seals each record to the one before it, so a record changed,
removed or put out of order breaks the chain. Seals say nothing of when.
`releve stamp` sends the hash of the latest record, and nothing else, to a
time-stamping authority under RFC 3161, DigiCert's free one unless another is
named, and keeps its signed reply as the next record. `releve verify` checks
each reply again: that it covers the record before it, and that the
authority's signature holds, against the roots the system already holds
(`RELEVE_CA` names others). `releve verify CORPUS --export DIR` writes each
reply out with the OpenSSL command that checks it, for anyone without relevé.

A reply from a qualified trust service provider, listed on the EU Trusted
List, carries under eIDAS a presumption that its date and the data it
covers are accurate; another is admissible as evidence all the same. The
authority is a setting: naming a qualified one changes no code.

The service dates each record it makes or answers. With `--sky`, it sets
above the date an illustration whose cloud dots are moved by the signed
reply, as `serve/sky.py` writes: a record changed, or dated otherwise, has
another sky.

### Frameworks

Laws and standards elsewhere are, for the most part, WCAG under another
name. `kernel/src/Releve/Frameworks.hs` writes each as the provisions it is
made of: the WCAG success criteria it names, and what it asks beyond them.
The RGAA reaches WCAG through the correspondence its own data states
(DINUM, `criteres.json`, Licence Ouverte 2.0); rules that cite WCAG add
theirs. A provision is addressed when a rule reads it, a question puts it to
the reviewer, or the owner declares it. `releve frameworks` gives the count,
and the guide sets it out as a table:

| text | where | provisions | addressed |
|---|---|---|---|
| WCAG 2.2 AA | the W3C's current standard, ISO/IEC 40500:2025 | 55 | 55 |
| WCAG 2.1 AA | the version the laws refer to | 50 | 50 |
| EN 301 549 · EAA | European Union | WCAG 2.1 AA, and article 13(2) | 51 |
| RGAA 4.1.2 | France | 106 criteria | 106 |
| BITV 2.0 | Germany, federal public bodies | WCAG 2.1 AA, and §4 | 51 |
| Section 508 | United States, federal agencies | WCAG 2.0 AA | 38 |
| ADA Title II | United States, state and local governments | WCAG 2.1 AA | 50 |
| ADA Title III | United States, businesses open to the public | no standard in the rule; WCAG 2.1 AA as courts cite it | 50 |
| AODA | Ontario | WCAG 2.0 AA but 1.2.4 and 1.2.5, and the section 14 report | 37 |
| JIS X 8341-3:2016 | Japan | WCAG 2.0 AA | 38 |
| DDA 1992 | Australia, advisory notes 4.1 | WCAG 2.0 AA | 38 |
| RGESN 2024 | France | 78 criteria | 78 |
| AI Act article 50 | European Union | 7 paragraphs | 7 |
| GDPR · ePrivacy | European Union, consent to trackers | consent-choice, third-parties | 2 |
| CCPA · CPRA | California | consent-choice, §1798.135, regulations §7025 | 3 |
| DSA article 25 | European Union, online platforms | declared | 1 |
| PIPL article 24 | China, automated decisions | declared | 1 |

Addressed says what a record covers. It says nothing of whether a site
conforms to any of them; the texts prevail.

Each criterion is one entry in `kernel/src/Releve/Criteria.hs`: what it
checks, its source, what it is for, and one pure function. Whatever a
criterion says, it says in English and in French. Adding one means writing
one entry; nothing else changes.

A report speaks in plain words and claims nothing for the page: no audit,
no conformity, no certificate, no quality mark, no guarantee. The one
thing it says of audits is that it is not one. What HTML itself calls a
thing (`<label>`, `aria-label`) is written as HTML writes it and set as
code, so that the words of the report are never taken for the words of
the language it reports on. `tests/run.py` holds every report and the
guide to this, in both languages.

## Scope and limits

- relevé is not a conformity audit. Automated observation covers part of
  what RGAA asks; much of it needs human judgement, which is why `REVIEW`
  exists.
- It observes one page, at one viewport (1280 × 800, then 320 px for
  reflow), at one moment. Interactive states (open menus, dialogs), shadow
  DOM and cross-origin frames are not observed; a prompt for consent is
  read inside open shadow roots too, and one in a frame from another site
  is named and put to a person.
- Contrast is computed against resolved background colours. Text over an
  image, or partly transparent text, is marked `REVIEW`; fully transparent
  text and text in disabled controls are not judged.
- A surface's identity follows its position in the document. Restructuring
  a page can make an unchanged element appear new.
- The footprint is measured, not scored: document nodes, requests,
  kilobytes and third-party hosts, comparable only under the same
  measurement conditions. It is the page as a reader's browser loads it at
  1280 px, scrolled to its end (and once more if reaching the end made it a
  screen longer): every redirect hop is a request, a
  `data:` address is not, and what the measuring itself fetches (the
  screenshot, the 320 px pass) is left out. Document nodes include those
  inside inline SVG, which some other tools leave out.
- The longest chain is read from what the browser says asked for each
  request: the document that names a file, or the script that fetched it.
  An image a script sets in the page is credited by the browser to the page
  itself, so the chain may be longer than shown, never shorter. A chain
  is named from three requests: the page and what it names is every page.
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
  itself (`releve-observe/0.5`) with its operator's contact address.
- Once a page is recorded, the text spacing a reader may set (WCAG 1.4.12)
  is put on and taken off again, and the text it cuts is noted.
- Once a page is recorded, it is taken by keyboard: Tab after Tab from the
  top, up to 120 times, and Shift+Tab and Escape where Tab holds still. At
  each of the first 30 stops the screen with the element focused is
  compared with the screen with it left. No other key is pressed: nothing
  is typed, chosen or activated, and what the keys open or move is not
  part of what was recorded.
- What a page asks of the device on arrival (notifications, location,
  camera) is noted and not granted. What an image file says of its own
  making is read from the bytes already fetched; nothing more is requested.
- Of what a page says it keeps extracts of 80 characters at most. What each
  block of the page says is weighed, in words and in bits, and not kept.

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
