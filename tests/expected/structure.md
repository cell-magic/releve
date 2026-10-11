# Relevé · http://localhost:8765/structure.html

Observation `c8522d60` · 2026-10-11T17:42:18+00:00 · criteria v5 · screenshot `7d6520591fc7f158` · Chromium 141.0.7390.37  
25 surfaces · 8 fail · 5 review · 0 hint · 38 pass · first observation of this page

Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement.
To correct a line, change its verdict word or add a note after `//`, then run `releve correct`.

## Fail (8)

- **FAIL** main-region · page · 2 main landmarks are visible → keep one \<main>; give the others the hidden attribute {f5adde0e}
- **FAIL** empty-blocks · page · 2 empty paragraphs → remove them; spacing belongs to the style sheet {428e052e}
- **FAIL** empty-blocks · page · 1 empty heading → remove it; spacing belongs to the style sheet {eb2f0f2f}
- **FAIL** presentation · page · attribute bgcolor used 1 time → move it to the style sheet {edf44776}
- **FAIL** presentation · page · \<center> used 1 time → move it to the style sheet {efd5fb57}
- **FAIL** presentation · page · \<font> used 1 time → move it to the style sheet {33184aee}
- **FAIL** presentation · page · attribute color used 1 time → move it to the style sheet {ff9632c6}
- **FAIL** no-popup · page · tried to open 1 window by itself → open a window on the reader's action only {b8861d84}

## Review (5)

- **REVIEW** heading-look · `body > main:nth-of-type(1) > div.big:nth-of-type(1)` · “Set large and not marked” is set at 28 px, the running text at 16 px, and it is not a heading → if it titles what follows, mark it h1 to h6 {7d2e3189}
- **REVIEW** heading-look · `body > main:nth-of-type(1) > div.bold:nth-of-type(2)` · “Set bold before plain text” is set bolder than the text that follows, and it is not a heading → if it titles what follows, mark it h1 to h6 {3b219feb}
- **REVIEW** list-look · `body > main:nth-of-type(1) > p:nth-of-type(5)` · 3 lines in a row begin like list items, from “• First of three” → mark them as a list: \<ul> or \<ol>, with \<li> {f8749eed}
- **REVIEW** media-captions · `body > main:nth-of-type(1) > video:nth-of-type(1)` · video without a caption track → if it carries speech, add \<track kind="captions"> {7efdc26e}
- **REVIEW** refresh · page · reloads itself every 600 s → let the reader stop or delay it {63673dfe}

## By criterion

- page-title: 1 of 1 pass
- page-lang: 1 of 1 pass
- doctype: 1 of 1 pass
- zoom: 1 of 1 pass
- reflow: 1 of 1 pass
- main-region: 0 of 1 pass
- skip-link: 1 of 1 pass
- heading-order: 2 of 2 pass
- heading-look: 0 of 2 pass
- list-look: 0 of 1 pass
- empty-blocks: 0 of 2 pass
- presentation: 0 of 4 pass
- image-alt: n/a · no images on the page
- text-contrast: 19 of 19 pass
- link-name: n/a · no links on the page
- link-distinct: n/a · no links on the page
- button-name: n/a · no buttons on the page
- label-in-name: n/a · no name given by the code over words shown
- control-label: n/a · no form fields on the page
- group-legend: n/a · no group of fields on the page
- field-group: n/a · no radio buttons on the page
- autocomplete: n/a · no field that asks for personal data
- table-headers: n/a · no tables on the page
- frame-title: n/a · no frames on the page
- autoplay: 2 of 2 pass
- media-captions: 1 of 2 pass
- unique-ids: 1 of 1 pass
- tab-order: 1 of 1 pass
- hidden-focus: 1 of 1 pass
- no-popup: 0 of 1 pass
- refresh: 0 of 1 pass
- ai-disclosure: n/a · no conversational widget detected
- ai-image: n/a · no image states its origin
- asks-on-arrival: 1 of 1 pass
- third-parties: 1 of 1 pass
- media-autoplay: 2 of 2 pass
- endless: 1 of 1 pass
- fonts: n/a · no font is downloaded
- compression: n/a · read from this machine: how it is served is not judged
- caching: n/a · read from this machine: how it is served is not judged
- protocol: n/a · read from this machine: how it is served is not judged
- lazy-images: n/a · no image below the second screen
- image-weight: n/a · no bitmap images on the page
- image-format: n/a · no weighed images on the page

## Footprint

- 39 elements · 3 requests · 4 kB transferred · 0 third-party hosts

## Reading

- 21 events · 2 shown and not said · 0 said and not shown
- depth 18: the longest run the markup obliges
- the page says 254 bytes; 15 bytes travel for each
- one at a time, by ear: 19 steps
- up to 4 at a time: 18 steps as the page stands · 18 with nothing failing (between 18 and 18 at this depth and size)
