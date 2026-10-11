# Relevé · http://localhost:8765/quirks.html

Observation `d09dc21e` · 2026-10-11T17:42:12+00:00 · criteria v5 · screenshot `4d6d183a71bb0913` · Chromium 141.0.7390.37  
8 surfaces · 2 fail · 1 review · 0 hint · 22 pass · first observation of this page

Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement.
To correct a line, change its verdict word or add a note after `//`, then run `releve correct`.

## Fail (2)

- **FAIL** doctype · page · no doctype → begin the document with \<!doctype html> {a5d205fc}
- **FAIL** presentation · page · \<u> used 1 time → move it to the style sheet {4fa18193}

## Review (1)

- **REVIEW** skip-link · page · 1 link or control stands before the main content, and no link leads past → add, first in the page, a link to the main content {cd3538ff}

## By criterion

- page-title: 1 of 1 pass
- page-lang: 1 of 1 pass
- doctype: 0 of 1 pass
- zoom: 1 of 1 pass
- reflow: 1 of 1 pass
- main-region: 1 of 1 pass
- skip-link: 0 of 1 pass
- heading-order: 1 of 1 pass
- heading-look: 1 of 1 pass
- list-look: 1 of 1 pass
- empty-blocks: 1 of 1 pass
- presentation: 0 of 1 pass
- image-alt: n/a · no images on the page
- text-contrast: 4 of 4 pass
- link-name: 1 of 1 pass
- link-distinct: 1 of 1 pass
- button-name: n/a · no buttons on the page
- label-in-name: n/a · no name given by the code over words shown
- control-label: n/a · no form fields on the page
- group-legend: n/a · no group of fields on the page
- field-group: n/a · no radio buttons on the page
- autocomplete: n/a · no field that asks for personal data
- table-headers: n/a · no tables on the page
- frame-title: n/a · no frames on the page
- autoplay: n/a · no audio or video on the page
- media-captions: n/a · no video on the page
- unique-ids: 1 of 1 pass
- tab-order: 1 of 1 pass
- hidden-focus: 1 of 1 pass
- no-popup: 1 of 1 pass
- refresh: n/a · no timed refresh declared
- ai-disclosure: n/a · no conversational widget detected
- ai-image: n/a · no image states its origin
- asks-on-arrival: 1 of 1 pass
- third-parties: 1 of 1 pass
- media-autoplay: n/a · no audio or video on the page
- endless: 1 of 1 pass
- fonts: n/a · no font is downloaded
- compression: n/a · read from this machine: how it is served is not judged
- caching: n/a · read from this machine: how it is served is not judged
- protocol: n/a · read from this machine: how it is served is not judged
- lazy-images: n/a · no image below the second screen
- image-weight: n/a · no bitmap images on the page
- image-format: n/a · no weighed images on the page

## Footprint

- 12 elements · 1 request · 1 kB transferred · 0 third-party hosts

## Reading

- 3 events · 0 shown and not said · 0 said and not shown
- depth 2: the longest run the markup obliges
- the page says 31 bytes; 27 bytes travel for each
- one at a time, by ear: 3 steps
- up to 4 at a time: 2 steps as the page stands · 2 with nothing failing (between 2 and 2 at this depth and size)
