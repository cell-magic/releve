# Changes

## 0.11.0

The RADAR record (D-033): what was observed apart from what it reads as, chained, gathered
each month under a dated root, drawn from a public beacon, and checked by anyone.
Criteria stay at v10.

- **plié** (`plie/`): a small pure language, the common ground of Haskell and Lean 4, in
  which the record's core is written once (`record/*.plie`) and folded into Haskell
  (`releve core`), JavaScript (`record/verifier.html`) and Lean (`record/gen/lean`, not yet
  checked). `tests/plie.py` holds the Haskell and JavaScript folds to the same bytes.
- **The record** (`releve-record/2`, `record/schema/`): an `observation` frozen in shape
  (bytes in all and by request; each request's origin, type, bytes, status and whether it
  came before any interaction; the accessibility tree counted), the rule results
  (`releve rules -`), and `readings`, each a function of those: WCAG by success criterion
  (fail, review, hint; no percentage), dependencies by registrable domain (public suffix
  list pinned), legibility, energy (coefficient named, never on a stamp).
  `python -m record recompute` rebuilds them and compares bytes; records of 0.10 are read.
- **The chain and the month**: canonical bytes under RFC 8785, SHA-256; `prev`, `baseline`,
  `chain_status`; the month's Merkle tree under RFC 6962; its root dated under RFC 3161, the
  authority a setting; the published roots, an append-only list (RFC 4998 renewal left room
  for, not done); a bundle per record. `python -m record verify` names each check.
- **The selection**: the candidates are committed to and the commitment dated before the
  cycle begins; the round is the cycle's, drand quicknet's first after its first second
  (`releve-draw/1`), its BLS signature checked; the order it gives is the one the selector
  reads. The calendar fixes the moment, so drawing again gives nothing: a later commitment
  takes the same round, and is dated too late. Without a round, the record says
  "selection not beacon-seeded".
- **One way to write each list**: a candidate is admitted only in its one written form
  (lowercase host, no default port, no fragment, no dot segment, escapes in uppercase),
  and once; the observation's requests are kept in one order, not the network's. The
  verifier checks both (`canonical`), so a record's bytes carry nothing its meaning does not.
- **What changed on a page** (`record/Changes.plie`, `python -m record changes`): two
  records of one page compared as signed differences, derived from what the member
  holds, never kept. They are a Z-set in one form, and add: changes from a to b, then b
  to c, are those from a to c.
- **BLS in the browser** (`record/bls`): the drand round's signature checked by one Rust
  source, as `releve-bls` on the command line and as WebAssembly in `verifier.html`
  (no import, two exports, reproducible build, the compiled crates' notice carried
  within). It replaces py_ecc and its five dependencies.
- **Sealed types in plié**: a constructor used only in its own module, kept by the
  compiler and by GHC's export lists. A `Seed` can come only from a beacon's
  randomness, so the page order can only be the round's.
- **The owner's mandate**: a record observed under it says so, and so does the report.
- **The observer** keeps each request's status and moment and counts the accessibility tree.
- **"Sealed" is "chained"**: `releve verify` and the service say what the free chain is.
- **BOUNDARY.md** and `tests/boundary.py`: what is open, what is closed, kept apart.
- **survive**, from 0.10.1, is carried in: whether an image's provenance markers survive its
  delivery (`survive/`).

## 0.10.1

Whether an image's provenance markers survive the site's delivery.

- **survive** (`survive/`, `python -m survive URL --contact URL`): one record per
  page (`survive/CONTRACT.md`). Each image's C2PA, EXIF and IPTC markers are
  read from the delivered bytes, by presence and size (JPEG APP11 JUMBF, APP1,
  APP13 8BIM, XMP; PNG caBX, eXIf; ISO-BMFF's C2PA uuid box). Where an edge
  transformer stands between, the file behind it is asked for once (probe 2:
  the wrapper stripped, no-transform, one hop, 5 s, never a loopback or
  private address), and each class is present, stripped at delivery, absent
  at origin (only after a probe that succeeded untransformed), or
  unobservable. The surface is taken once settled (idle 500, quiet 1000,
  cap 15000 ms), and the scope says how. Assets in one order; the root is
  SHA-256 of the body's canonical bytes, and two runs of one surface give the
  same. Unsigned, and it says so. A fix-list helper ranks what to fix.
- **BOUNDARY.md**: what of the instrument is open, here, and what is not.
- **tests/survive.py**: five local sites, the whole truth table, each run
  twice to its stored root; the contract's absolutes, each broken once; the
  record path read for randomness, clocks and locales. No new dependency.
- The kernel is unchanged; criteria stay at v10.

## 0.10.0

Each report comes with the page as it was served, and a way to check it.

- **The service** hands back, with each report, the page the robot was
  served: whole, in a WACZ bundle signed with ECDSA P-256 when it was made,
  with the receipt that replays it (a SHA-256 chain over the page's
  address, content and structure) and `verifier.html`, one file that checks
  both offline. The record keeps the receipt's head, dated with the rest.
  Nothing of the page is kept by the service.
- **receipt/** holds the selector, the receipt and the bundle, in Python,
  with the verifier's sources; `receipt/build.sh` builds the verifier, and
  CI checks that the file handed out is the one its sources build. Its one
  new dependency is `cryptography`, pinned.
- **The observer** returns the page's HTML beside its observation, taken
  once the page has loaded, before anything is measured. The observation,
  and so the record, holds none of it.
- **The kernel** keeps the receipt's head in an observation. Criteria stay
  at v10.

## 0.9.7

The robot stops at a certificate anyone could have signed.

- **The observer** refuses a page when its address, a redirect on the way or
  anything it loads is served under one of the eight eMudhra intermediates
  whose private keys were found and published in October 2026; the reason
  names the authority. The conduct checks now serve such a page, and an
  ordinary one beside it, over TLS under a root of their own, and see the
  first refused and the second observed (on Linux, where the tests can name a
  root to Chromium).
- **The browser** is Playwright 1.64.0 and the Chromium it brings, in place
  of 1.56.0 of November 2025. It is part of the reading, so it is taken on
  purpose, with the checks run. Criteria stay at v10.
- **The build** runs on macOS 15 by name: the latest macOS image linked
  nothing since 17 October.

## 0.9.6

The security gate before the repository goes public.

- **The service** opens a record handed back no further than twenty times the
  largest request. A file of a few megabytes that opened into gigabytes
  filled the memory before it was cut; it is now refused, in a fraction of a
  second. A check of the service holds it.
- **The report:** a check that a page writing markup and the report's own
  syntax is shown as text in the HTML report, in each language.
- **SECURITY.md:** how to report a vulnerability privately, and when an answer
  comes. Dependabot proposes newer versions weekly; none is taken without the
  checks. Criteria stay at v10.

## 0.9.5

The robot reaches the web from the country it names, not from where it is served.

- **Egress:** `serve/egress.sh` makes a second, small machine in that country
  the robot's only way out. Pages, what they load, robots.txt and the names
  they look up leave through a WireGuard tunnel; without the tunnel they go
  nowhere, never from the service's machine instead. The exit keeps no log
  and answers the service's machine only. `egress.sh check` shows it, on the
  machines. Criteria stay at v10.
- **Licence:** the French text of the EUPL-1.2, equally valid, beside the
  English one. CONTRIBUTING.md: issue reports open, code contributions closed
  until a contributor agreement is published.
- **Line endings:** text is stored and checked out with LF on every machine.

## 0.9.4

Axeptio's page, read through the service on 0.9.3, showed one more gap.

- **Consent prompts:** a refusal worded as closing without accepting
  ("Fermer sans accepter les cookies", Axeptio's own) is read as a refusal,
  not as accepting; so are its German, Spanish and Italian forms. Criteria
  stay at v10.

## 0.9.3

- **The observer** records a page it cannot picture in time without its
  picture, rather than waiting on it. 0.9.2 fell back on the browser's own
  picture of the screen; on Axeptio's page no picture came at all, the
  service's patience ran out, and the page was refused again. The keyboard
  walk goes on, without looking at the focus. Criteria stay at v10.

## 0.9.2

- **The observer** pictures a page that never settles. A font asked for
  after the page has loaded, and never delivered, held every screenshot
  until it timed out, and the page was refused (Axeptio's). The page's
  fingerprint is now the browser's own picture of the screen, and the
  keyboard walk goes on without looking at the focus. Criteria stay at v10.

## 0.9.1

Read on fourteen real sites through the service. Criteria move from v9 to
v10.

- **consent-choice.** Of several ways to accept, the most visible is
  weighed against the most visible way to refuse. Refusing that takes a
  subscription, a consent wall, is put to a person, with the CNIL's
  question: is a real and fair alternative offered, at a reasonable price?
- **The observer** leaves out the tabs of a prompt (Consent, Details,
  About): they show a panel and are no choice. A page too tall to draw whole
  in time is fingerprinted by its first screen, rather than refused.
- **Seen from.** `--from CC` names the country the robot reaches the web
  from; the record keeps it, and the report and the drafts say it. Where no
  prompt for consent is seen, the report says from where, since many sites
  ask only visitors from the European Union.

## 0.9.0

What a record shows over time, and the statements it can feed. Criteria
stay at v9.

- **releve statement en|fr.** Two drafts from the record, for the owner to
  complete and publish: an accessibility statement on the RGAA's model,
  with the failures the rules observed by criterion and page count, the
  test environment, the pages, and the remedies before the Défenseur des
  droits; and an eco-design declaration giving each of the 78 RGESN
  criteria as read by rule or declared by the owner. The owner's part is
  marked; no conformity is stated.
- **releve history.** Every point that stood open on a page, when it opened,
  when and how it closed, by the page or by the reviewer's answer, and the
  time stamp of the closing reading. The report says the same in words.
- **The service** hands over the drafts with each report, drawn from the
  record and kept nowhere.
- **The observer** no longer stops on a control whose box the page does not
  draw (`display: contents`): its name is read before its weight. Pages of
  several news and shop sites failed on it.

## 0.8.0

Records dated from outside. Criteria stay at v9.

- **releve stamp.** The hash of the latest record goes to a time-stamping
  authority under RFC 3161, DigiCert's free one unless another is named;
  its signed reply, checked before it is kept, becomes the next record.
  OpenSSL and curl do the work, called as they are called by hand.
- **releve verify.** Each time stamp is checked again: it covers the record
  before it, and the authority's signature holds against the system's
  roots, or those `RELEVE_CA` names. `--export DIR` writes each reply with
  the OpenSSL command that checks it.
- **The report** gives the time, the authority and the record the stamp
  covers, and says how many records came after it.
- **The service** dates each record when it is made and when it is
  answered (`--authority`). With `--sky`, the illustration a look names is
  set above the date, its cloud dots moved by the signed reply
  (`serve/sky.py`): anyone can draw it again from the record.
- **install.sh** names DigiCert unless told otherwise (`--authority URL`,
  or `none`), installs openssl, and says whether the first report came
  back dated.
- **Tests.** A time-stamping authority of the tests' own (`tests/authority.py`),
  so that dating is checked with no network.

## 0.7.0

Criteria move from v8 to v9. WCAG 2.2 at levels A and AA, where the RGAA
stops: its six new criteria addressed, 55 of 55.

- **target-size, WCAG 2.5.8.** Each link, button and field at least 24 by
  24 px, or with a circle of 24 px about its centre that meets no other
  target. The observer records why a target's size is not the author's: a
  link set in a sentence, a checkbox the browser draws.
- **focus-obscured, WCAG 2.4.11.** At each Tab, the observer looks at what
  lies over the focused element; one element of the page's own over the
  whole of it, a fixed header or a banner, fails.
- **authentication, WCAG 3.3.8.** A password or code field puts the
  question: can a person sign in without remembering, copying or solving
  anything? A field set to `autocomplete="off"` says it turns password
  managers away.
- **Asked and declared.** WCAG 2.5.7 (dragging) joins the consultation
  questions where a page runs script, 3.3.7 (redundant entry) the form
  questions; 3.2.6 (consistent help) is declared for the site, beside the
  contact links seen.
- **Frameworks.** WCAG 2.2 AA is a framework of its own, ISO/IEC
  40500:2025; the laws that cite 2.1 or 2.0 keep their version.

## 0.6.0

Criteria move from v7 to v8. The laws and standards a site answers to
elsewhere, each written as its provisions, and a rule on how a prompt for
consent offers its choices.

- **Frameworks.** `releve frameworks` gives, for WCAG 2.1 AA, EN 301 549
  and the European Accessibility Act, the RGAA, the BITV 2.0, Section 508,
  ADA Titles II and III, the AODA, JIS X 8341-3, the Australian DDA, the
  RGESN, article 50 of the AI Act, the GDPR and ePrivacy, the CCPA as the
  CPRA amended it, article 25 of the DSA and article 24 of the PIPL, how
  many provisions rules, questions and declarations address, and which are
  left open. None is. The guide sets them out as a table. The RGAA reaches
  WCAG through the correspondence the RGAA's own data states.
- **Declared beyond the page.** WCAG 1.2.4 (live captions), the only
  WCAG 2.1 AA criterion the RGAA leaves aside, and seven provisions of other
  texts: EAA article 13(2), BITV 2.0 §4, AODA section 14, CPRA §1798.135
  and regulations §7025, DSA article 25, PIPL article 24. Each shows what
  the observation saw that bears on it, such as a "Do Not Sell or Share"
  or a "Leichte Sprache" link.
- **consent-choice.** The observer records a prompt for consent on
  arrival, inside open shadow roots too, and its first choices: what each
  does, link or button, its area, its look. Accepting with no way to refuse
  beside it fails. Refusing plainer than accepting, or less than half its
  area, is put to a person: "Is refusing as easy and as visible as
  accepting, from the first step?". Answered once for pages that share a
  template, like the other questions asked of a page as a whole.
- **Declarations, any text.** `releve declare` and the service read a
  declaration whatever its text's name: `d-bitv-2-0-4`, `d-cpra-1798-135`.
- **Tests.** `tests/run.py --record consent` re-records only the pages
  named.

## 0.5.1

Criteria move from v6 to v7. Article 50 of the AI Act, each of its seven
paragraphs addressed, as the RGAA and the RGESN are.

- **50(5), read.** The two rules that find AI on a page, a conversational
  widget or an image whose file states a synthetic origin, now put the
  question paragraph 5 asks: is the person told clearly, at the first
  exchange or where the image is first seen?
- **50(2), 50(3), 50(4), declared.** What no page shows is declared by the
  owner beside the RGESN and RGAA declarations: whether outputs of an AI
  system the service provides carry a machine-readable mark; whether people
  exposed to emotion recognition or biometric sorting are told; whether deep
  fakes and AI-written text published to inform the public are disclosed.
- **50(6), 50(7), said.** The first keeps other rules in force, the second is
  addressed to the Commission; neither places a duty on a site. The report
  and the guide say so, and count them.
- **The reach, in numbers.** The guide gives, beside what the rules touch,
  what rules, questions and declarations address together: 106 of 106, 78
  of 78, 7 of 7. A declaration's form field is named from its criterion,
  whatever the text: `d-rgesn-1-3`, `d-ai-act-50-2`.

## 0.5.0

Criteria move from v5 to v6: 46 rules where there were 44. A person now
answers what a rule cannot decide, in the report itself.

- **Open questions.** Where a rule cannot decide, the report asks:
  "Is the image decorative?", "Does the alternative describe the image?".
  Every image the rule cannot judge is now asked about, where an image
  with an alternative used to pass unread: RGAA 1.1 to 1.3 ask a person,
  and the report no longer answers for them. An image shorter or narrower
  than 4 px is taken to carry nothing.
- **Answered where it is read.** `releve report en|fr CORPUS --ask` gives
  each point to decide yes, no and a note. The service sets them in a form
  that sends the answers back with the record; they go through `releve
  correct`, the one way a reading is recorded, and the report comes back as
  it now stands. Only a point the rule itself left to a person is put as a
  question: a failure a rule can show is not argued away.
- **The reviewer's answers, labelled.** A report counts the reviewer's
  answers, marks each with the rule's reading, and lists what the reviewer
  confirmed under its own heading.
- **Plainer words.** Fixes, open questions and lighter options replace
  changes to make, points to decide and could be lighter.
- **An image with what stands around it.** A point to decide about an image
  shows its file, and the words the page says just before and after it.
- **The keyboard.** The observer takes each page by Tab, after recording it.
  Two rules read the walk: `focus-visible` (RGAA 10.7) fails a stop where not
  one pixel of the screen changes when it takes the focus, so it may miss an
  unseen focus and never names a seen one; `keyboard-trap` (RGAA 12.9) fails
  an element that Tab, Shift+Tab and Escape cannot leave, and asks a person
  whether a round that does not reach the rest of the page has a way out.
  Observations made before 0.5 are not judged on them.
- **Declarations.** The 64 RGESN criteria no rule can see from a page are
  declared by the service's owner: `releve declarations` lists them with the
  answers in force and what the latest observation saw, `releve declare`
  records the changed lines as events of the record. The report ends with
  them, linked to the official text; the service sets them in its form,
  answered already where they were. Rules and declarations together cover
  all 78 RGESN criteria, each once.
- **Every RGAA criterion, once.** Eleven new rules read what the observer
  now records: language codes (8.4, 8.7, 8.8), reading direction (8.10),
  text cut by wider spacing (10.12), endless motion (13.8), clicks no key
  reaches (7.3), words set by the style sheet (10.2), text colours without a
  background (10.5), links that blend into their sentence (10.6), emoji
  (13.5, 13.6), CAPTCHAs (1.4, 1.5) and office documents (13.3, 13.4).
  Twelve themes put the 47 criteria no rule decides to the reviewer, one
  question each, not applicable where the page holds nothing they apply to.
  The 5 criteria on a set of pages (12.1 to 12.5) are declared by the owner.
  Rules, questions and declarations cover the 106 criteria, each once.
- **Shorter words.** Each criterion's purpose is one plain statement; the
  method, the reading and the scope are said in fewer words.
- **The longest chain.** The observer records which address asked for each
  request. The footprint names the longest run of requests in which each
  waited on the one before, and says what it costs: as many round trips in
  a row, whatever the connection. A measure, not a verdict.
- **First run on a live site.** Twelve pages of bureaudessurfaces.fr, with
  what that run showed corrected. A question is put only where what it asks
  about can exist: the observer counts the script a page carries, and a page
  with none is not asked about scripted components, shortcuts, gestures or
  device motion (RGAA 7.1, 7.2, 7.4, 7.5, 12.10, 13.10 to 13.12); a form is
  asked about legends only with a group of fields (11.7), about option
  groups only with a list (11.8). A link whose words are its language's own
  name, "Français" marked `fr`, passes without a question. The longest chain
  names a site's home by its host. The observer writes its records in ASCII
  alone, so no shell can re-encode them on the way to a file. The criteria
  digest now covers the questions as well as the rules.
- **Asked once for the whole site.** On that run, 132 of 199 questions
  were the same 11 asked on each of 12 pages: what a page asks of itself
  as a whole (colours, quotations, presentation, hover content, flashing,
  orientation, scripts) is the template's to decide. Pages share a template
  when they load the same style sheets and scripts at the same sizes and
  carry the same inline style sheets; the observer records a digest of the
  latter. `releve facts --all`, the report and the service now put such a
  question once, for the pages that share it, and one answer, recorded as
  one event, covers every page counted with it. It holds on each while the
  page keeps that template: a page that changes it is asked again, and so is
  a page first seen later. Questions about what a page holds stay with the
  page. A correction records the observations it covers and the template.
- **The service's form, in the site's words.** URL, a note that it is
  required and starts with https://, the previous record marked optional,
  "Run report"; each field in its paragraph, its note tied to it. The
  record's size follows its link without brackets.

## 0.4.0

Criteria move from v2 to v5: 44 rules where there were 17. The English of
sixteen of the first seventeen is unchanged, so readings made under 0.3
still carry. The seventeenth, on form fields, now says "field without a
name", as links and buttons are said to be: a reading of it made under 0.3
comes back for review.

- **The report.** `releve report en|fr CORPUS` writes one page of HTML for
  the person whose pages they are: the method first, each finding with its
  remedy under its criterion and what that criterion is for, the lightest
  work first, then what was not looked at. With `-` for the corpus it reads
  observations from standard input and keeps nothing.
- **What holds, first.** Each page's report opens with what passes, then
  what is left: "38 checks pass · 8 changes to make · 5 points to decide ·
  nothing to lighten". A count of none is said in words.
- **The order of mending.** The reading no longer says what mending one
  criterion alone would give back, figures that could not be added up. It
  gives the criteria in the order that leaves fewest steps at each turn,
  each after those before it, down to the page with nothing failing: the
  gains add up.
- **Names that say what they do.** A report is titled "Report" ("État des
  lieux") and the address it covers. The service's form names what it
  gives: "Free page report", a button "Get the report", a field for the
  earlier record "to compare"; the record downloads as a ".gz file".
- **Two languages.** Whatever a rule says, it says in English and in
  French. `facts` stays in English, as the reviewer's working document.
- **Plain words, and no claim.** A report says nothing of audits,
  conformity, certificates, quality marks or guarantees, except that it is
  not an audit. What HTML itself writes (`<label>`, `aria-label`,
  `loading="lazy"`) is set as code in the report and the guide, and appears
  nowhere else. The checks hold every report to it.
- **The service is held to its own rules.** Its pages, read by the rules it
  applies to others, are asked for nothing; the check found its form too
  wide at 320 px before anyone else did.
- **As a page anyone can use.** `serve/serve.py` puts the whole of it
  behind a form: an address in, a report out. No account, no cookie, no
  script, no log. Whoever asks keeps the record, as a small sealed file, and
  hands it back to learn what changed. Only public addresses on the web's
  own ports are requested, by the page or by anything it loads.
- **Counts, kept to the service.** The service counts the reports it gives,
  by week: language, follow-ups, and the broad region a browser's language
  setting names. Nothing per request, no script, nothing on the reader's
  device, no page. `serve/counts.py` prints the weeks that have ended,
  small regions hidden. The proxy no longer passes the visitor's address on.
- **Putting it online.** `serve/install.sh` installs or renews the service
  on a machine given over to it: built apart, checked there, started only
  then, behind a proxy that logs no request, and put back as it was if the
  running service gives no report. A service whose browser cannot start
  now ends, to be started again, where it used to answer that the page was
  slow; whatever else fails, the answer says so; `HEAD` is answered.
- **Twenty-seven new rules.** From the RGAA: the document type, a link to
  the main content, text that looks like a heading or a list, elements used
  as gaps, styling in the markup, links of one name to several places, the
  visible label within the name, legends and groups of fields, the purpose
  a field declares, table headers, caption tracks, the keyboard's order,
  focus under aria-hidden, windows and reloads without the reader. From the
  RGESN: fonts, compression, caching, protocols, images loaded before they
  are reached, third parties before consent, media that starts alone, a
  page without an end, requests made of the device on arrival. From article
  50 of the AI Act: an image whose own file states a synthetic origin.
  They touch 36 of the 106 criteria of the RGAA, 14 of the 78 of the RGESN
  and four paragraphs of article 50. To touch is not to settle.
- **The reading.** Beside the verdicts, a measure: how much a page gives
  its reader to take in, the order its markup obliges, and the steps that
  makes for a reader who takes one thing at a time and for one who holds up
  to four. In `facts`, in `atlas` (with the order as a tree) and in the
  report.
- **The observer records more, and keeps less.** The reading sequence; how
  each response travelled; what image files say of their own making; what
  the page asks of the device on arrival. Of what a page says, extracts of
  80 characters at most are kept: names, labels, alternatives and titles
  are clipped, and what a block says is weighed and not kept. Surfaces
  whose name ran past 80 characters change identity once.
- **A page read from this machine** is not judged on how it is served.
- `releve guide en|fr`: the criteria and what each is for, on one page.
- Eight new test pages, each commented with the reading it should give; a
  third suite, `tests/service.py`.

## 0.3.1

Criteria stay at v2. Three corrections, each from an outside reading of the code.

- **A person's reading is never silently replaced.** A correction carries
  while what is seen reads the same. When it changes (the page did, or a
  release words the finding otherwise), a reading that differed from the
  machine's used to vanish and the machine's verdict returned unremarked.
  The finding now comes back as `REVIEW`, marked "read otherwise before this
  changed", until a person reads it again.
- **The footprint is the page's, not the observer's.** Requests and bytes are
  closed before the screenshot and the 320 px pass, which could fetch images
  of their own; redirect hops are counted; `data:` addresses are not
  requests. On a test page of known weight the count was 6 and is now the
  true 5.
- **The criteria cannot change under an unchanged version.** The tests keep a
  digest of the criteria beside their version number and refuse one without
  the other.

## 0.3.0

Judgement is unchanged: criteria stay at v2, and the recorded test pages give
the same verdicts as under 0.2.

- **Where a page leads.** Every document a page asks the browser for, by
  redirect, refresh or script, is requested only if `robots.txt` admits its
  address. A mandate covers the site it was given for (whatever the scheme,
  port or `www`), never another.
- **Nothing is sent, nothing is opened.** A form submitted by a page's own
  script is stopped before it leaves; `window.open` opens nothing. A page that
  tries to leave for a closed address, or renames itself to one, is not
  recorded.
- **A site that pushes back is left alone.** After a 429, a 503 or a challenge
  page, the rest of that site's pages are skipped for the run.
- **Web addresses only.** An address without `http://` or `https://` is
  refused; before, it reached the browser without a look at `robots.txt`.
- **Challenge pages** are recognised by how their title begins, not by any
  title that contains "un instant"; a challenge widget inside a form is not
  a wall.
- **A reviewer's edit is never dropped.** A finding's line that can no longer
  be read (a note after the id, an unknown verdict word) makes `correct`
  refuse the whole document and say which line. A note may contain ` // `.
- **What was asked, and what rendered.** An observation keeps the address
  requested beside the one reached, and the browser version that rendered it.
  Both appear in `atlas`; the browser appears in the `facts` header.
- **The same bytes on every system.** The observer and the kernel read and
  write UTF-8 with line feeds whatever the platform. Before, the observer
  used the system encoding, which mangled accented text on Windows.
- **Tests without a shell.** `tests/run.py` replaces `run.sh` and
  `observe.sh`; `--accept` and `--record` do what the scripts did.
- **Releases.** One binary per system, each under its own name:
  `releve-linux`, `releve-macos`, `releve-windows.exe`. Before, the Linux and
  macOS binaries shared a name and one replaced the other.
- A test page that writes in the report's own syntax: its text stays text.
- A damaged corpus is refused with the line at fault, not a stack trace.
- A page too large to read whole says so in `facts` and `atlas`.
- `releve --version`; `releve verify` also prints the head seal.
- Line breaks inside an `alt`, a title or a placeholder no longer break a report line.
- Pages are rendered without downloads and without service workers.
- Playwright is pinned in `observe/requirements.txt`.

## 0.2.0

- Footprint as raw measures (elements, requests, kilobytes, third-party
  hosts); no score.
- The observer's conduct written into the code and tested: `robots.txt`,
  pace, refusals, mandate, contact address.
- Criteria v2: `image-weight` judges bitmap images only.
- REUSE-compliant licence headers.
