# Changes

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
