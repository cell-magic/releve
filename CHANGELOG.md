# Changes

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
