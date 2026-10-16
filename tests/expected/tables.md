# Relevé · http://localhost:8765/tables.html

Observation `3da4888e` · 2026-10-16T10:47:38+00:00 · criteria v6 · screenshot `aba3d0c3bae2700c` · Chromium 141.0.7390.37  
36 surfaces · 5 fail · 19 review · 0 hint · 55 pass · first observation of this page

Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement.
To correct a line, change its verdict word or add a note after `//`, then run `releve correct`.

## Fail (5)

- **FAIL** presentation · page · attribute border used 1 time → move it to the style sheet {36f0f6fb}
- **FAIL** presentation · page · attribute width used 1 time → move it to the style sheet {6b83792a}
- **FAIL** presentation · page · attribute align used 1 time → move it to the style sheet {1b225bf7}
- **FAIL** table-headers · `body > main > table:nth-of-type(3)` · headers in rows and in columns, 3 without scope or id → give each \<th> scope="col" or scope="row" {2ffee13c}
- **FAIL** table-headers · `body > main > table:nth-of-type(6)` · a layout table carries data-table markup → remove caption, th, scope and headers from it {872c20b3}

## Review (19)

- **REVIEW** table-headers · `body > main > table:nth-of-type(2)` · table of 3 × 2 without a header cell → a data table declares its headers with \<th>; a layout table carries role="presentation" {6f3b6401}
- **REVIEW** lang-code · page · page language lang="en" → set lang to the language the page is written in {037a9ec3}
- **REVIEW** lang-code · page · no passage marked in another language → mark each passage in another language with lang {df860cc4}
- **REVIEW** review-colours · page · RGAA 3.1 · this page → add text, a shape or a pattern beside the color {0d0fcd2b}
- **REVIEW** review-colours · page · RGAA 3.3 · this page → raise their contrast to 3:1 {ba9f12a0}
- **REVIEW** review-tables · page · RGAA 5.1 · 6 tables → add a summary linked by aria-describedby or in the caption {c4f0c0e9}
- **REVIEW** review-tables · page · RGAA 5.2 · 6 tables → rewrite the summary {8e252408}
- **REVIEW** review-tables · page · RGAA 5.4 · 6 tables → use \<caption> {8c370277}
- **REVIEW** review-tables · page · RGAA 5.5 · 6 tables → rewrite the title {3013d540}
- **REVIEW** review-title · page · RGAA 8.6 · “Tables” → rewrite the title: the page, then the site {ffdb03e3}
- **REVIEW** review-structure · page · RGAA 9.4 · this page → mark quotations with \<q> or \<blockquote> {78b9d89c}
- **REVIEW** review-presentation · page · RGAA 10.3 · this page → order the code as the page reads {28d2af9d}
- **REVIEW** review-presentation · page · RGAA 10.9 · this page → add text to the shape, size or position {ea5933eb}
- **REVIEW** review-presentation · page · RGAA 10.10 · this page → put the text equivalent in the code {2d827e46}
- **REVIEW** review-presentation · page · RGAA 10.13 · this page → close it with Escape; keep it while hovered {b8a9d60f}
- **REVIEW** review-presentation · page · RGAA 10.14 · this page → show it on :focus-within as on :hover {49d9faa2}
- **REVIEW** review-navigation · page · RGAA 12.11 · this page → make it reachable with Tab {879ef122}
- **REVIEW** review-consultation · page · RGAA 13.7 · this page → remove the flashing {8ea4a450}
- **REVIEW** review-consultation · page · RGAA 13.9 · this page → remove the orientation lock {04984447}

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
- label-in-name: n/a · no name given by the code over words shown
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
- focus-visible: n/a · nothing on the page takes the focus
- keyboard-trap: n/a · nothing on the page takes the focus
- lang-code: 0 of 2 pass
- direction: n/a · no right-to-left script on the page
- text-spacing: 1 of 1 pass
- motion: 1 of 1 pass
- clickable: 1 of 1 pass
- generated-text: 1 of 1 pass
- paired-colours: 1 of 1 pass
- link-visible: 1 of 1 pass
- cryptic: n/a · no emoji on the page
- captcha: n/a · no CAPTCHA loaded
- documents: n/a · no office document linked
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
- review-images: n/a · no images on the page
- review-frames: n/a · no frames on the page
- review-colours: 0 of 2 pass
- review-media: n/a · no audio or video on the page
- review-tables: 0 of 4 pass
- review-scripts: n/a · no script on the page
- review-title: 0 of 1 pass
- review-structure: 0 of 1 pass
- review-presentation: 0 of 5 pass
- review-forms: n/a · no form fields on the page
- review-navigation: 0 of 2 pass
- review-consultation: 0 of 5 pass

## Footprint

- 64 elements · 1 request · 2 kB transferred · 0 third-party hosts

## Reading

- 28 events · 0 shown and not said · 0 said and not shown
- depth 16: the longest run the markup obliges
- the page says 69 bytes; 30 bytes travel for each
- one at a time, by ear: 28 steps
- up to 4 at a time: 16 steps as the page stands · 16 with nothing failing (between 16 and 19 at this depth and size)
