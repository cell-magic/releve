# Relevé · http://localhost:8765/edge.html

Observation `f4a058d7` · 2026-10-11T17:14:19+00:00 · criteria v3 · screenshot `7a6cb565f56e8a7f` · Chromium 141.0.7390.37  
13 surfaces · 5 fail · 1 review · 0 hint · 25 pass · first observation of this page

Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement.
To correct a line, change its verdict word or add a note after `//`, then run `releve correct`.

## Fail (5)

- **FAIL** image-alt · `body > main > section:nth-of-type(1) > div > ul > li:nth-of-type(2) > a > img` · no alt attribute → add alt; alt="" if the image is decorative {0982a92f}
- **FAIL** image-alt · `body > main > section:nth-of-type(2) > div > ul > li:nth-of-type(2) > a > img` · no alt attribute → add alt; alt="" if the image is decorative {389f8682}
- **FAIL** text-contrast · `body > main > p:nth-of-type(3)` · #aaaaaa on #ffffff · 2.32:1, needs 4.50:1 · “Horaires \/\/ fermé le lundi” → use #767676 {fc1e06ed}
- **FAIL** link-name · `body > main > section:nth-of-type(1) > div > ul > li:nth-of-type(2) > a` · link without a name → give the link text, an image alt, or aria-label {8dc7f284}
- **FAIL** link-name · `body > main > section:nth-of-type(2) > div > ul > li:nth-of-type(2) > a` · link without a name → give the link text, an image alt, or aria-label {6c0ea2e8}

## Review (1)

- **REVIEW** text-contrast · `body > main > p:nth-of-type(2)` · #808080 on #ffffff · 3.97:1, needs 4.50:1 · “Half faded” · partly transparent (opacity 0.50), may be mid-animation {731deb3e}

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
- presentation: 1 of 1 pass
- image-alt: 0 of 2 pass
- text-contrast: 3 of 5 pass
- link-name: 0 of 2 pass
- link-distinct: n/a · no links on the page
- button-name: 2 of 2 pass
- label-in-name: n/a · no name given by the code over a visible label
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
- image-weight: 2 of 2 pass
- image-format: 2 of 2 pass

## Footprint

- 26 elements · 2 requests · 2 kB transferred · 0 third-party hosts

## Reading

- 10 events · 2 shown and not said · 1 said and not shown
- depth 8: the longest run the markup obliges
- the page says 61 bytes; 27 bytes travel for each
- one at a time, by ear: 8 steps
- up to 4 at a time: 8 steps as the page stands · 8 with nothing failing (between 8 and 8 at this depth and size)
