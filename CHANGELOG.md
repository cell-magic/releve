# Changes

## 0.3.0

Judgement is unchanged: criteria stay at v2, and the recorded test pages give
the same verdicts as under 0.2.

- **Where a page leads.** Every document a page asks the browser for, by
  redirect, refresh or script, is requested only if `robots.txt` admits its
  address. A mandate covers the site it was given for (whatever the scheme,
  port or `www`), never another.
- **A site that pushes back is left alone.** After a 429, a 503 or a challenge
  page, the rest of that site's pages are skipped for the run.
- **Web addresses only.** An address without `http://` or `https://` is
  refused; before, it reached the browser without a look at `robots.txt`.
- **Challenge pages** are recognised by how their title begins, not by any
  title that contains "un instant".
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
