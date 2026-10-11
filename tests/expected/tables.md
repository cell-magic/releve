# Relevé · http://localhost:8765/tables.html

Observation `2a139335` · 2026-10-11T17:42:20+00:00 · criteria v4 · screenshot `aba3d0c3bae2700c` · Chromium 141.0.7390.37  
36 surfaces · 5 fail · 1 review · 0 hint · 49 pass · first observation of this page

Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement.
To correct a line, change its verdict word or add a note after `//`, then run `releve correct`.

## Fail (5)

- **FAIL** presentation · page · attribute border used 1 time → move it to the style sheet {36f0f6fb}
- **FAIL** presentation · page · attribute width used 1 time → move it to the style sheet {6b83792a}
- **FAIL** presentation · page · attribute align used 1 time → move it to the style sheet {1b225bf7}
- **FAIL** table-headers · `body > main > table:nth-of-type(3)` · headers in rows and in columns, 3 without scope or id → give each \<th> scope="col" or scope="row" {2ffee13c}
- **FAIL** table-headers · `body > main > table:nth-of-type(6)` · a layout table carries data-table markup → remove caption, th, scope and headers from it {872c20b3}

## Review (1)

- **REVIEW** table-headers · `body > main > table:nth-of-type(2)` · table of 3 × 2 without a header cell → a data table declares its headers with \<th>; a layout table carries role="presentation" {6f3b6401}

## By criterion

- page-title: 1 of 1 pass
- page-lang: 1 of 1 pass
- doctype: 1 of 1 pass
- zoom: 1 of 1 pass
- reflow: 1 of 1 pass
- main-region: 1 of 1 pass
- skip-link: 1 of 1 pass
- heading-order: 1 of 1 pass
- heading-look: 1 of 1 pass
- list-look: 1 of 1 pass
- empty-blocks: 1 of 1 pass
- presentation: 0 of 3 pass
- image-alt: n/a · no images on the page
- text-contrast: 28 of 28 pass
- link-name: n/a · no links on the page
- link-distinct: n/a · no links on the page
- button-name: n/a · no buttons on the page
- label-in-name: n/a · no name given by the code over a visible label
- control-label: n/a · no form fields on the page
- group-legend: n/a · no group of fields on the page
- field-group: n/a · no radio buttons on the page
- autocomplete: n/a · no field that asks for personal data
- table-headers: 3 of 6 pass
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

- 64 elements · 1 request · 2 kB transferred · 0 third-party hosts

## Reading

- 28 events · 0 shown and not said · 0 said and not shown
- depth 16: the longest run the markup obliges
- the page says 69 bytes; 30 bytes travel for each
- one at a time, by ear: 28 steps
- up to 4 at a time: 16 steps as the page stands · 16 with nothing failing (between 16 and 19 at this depth and size)
