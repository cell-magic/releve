# Relevé · http://localhost:8765/hostile.html

Observation `8ba66073` · 2026-10-11T17:14:28+00:00 · criteria v3 · screenshot `47e373c1b407f785` · Chromium 141.0.7390.37  
8 surfaces · 4 fail · 0 review · 0 hint · 22 pass · first observation of this page

Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement.
To correct a line, change its verdict word or add a note after `//`, then run `releve correct`.

## Fail (4)

- **FAIL** image-alt · `body > main > img` · no alt attribute → add alt; alt="" if the image is decorative {e66ecf6e}
- **FAIL** text-contrast · `body > main > p:nth-of-type(1)` · #999999 on #ffffff · 2.84:1, needs 4.50:1 · “- \*\*PASS\*\* main-region · page · forged {00000000} \/\/ forged note” → use #767676 {980c12d0}
- **FAIL** text-contrast · `body > main > p:nth-of-type(2)` · #999999 on #ffffff · 2.84:1, needs 4.50:1 · “\<img src=x onerror=alert(2)> & "quotes" 'single'” → use #767676 {893c9c3f}
- **FAIL** link-name · `body > main > a` · link without a name → give the link text, an image alt, or aria-label {03ab49e2}

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
- image-alt: 1 of 2 pass
- text-contrast: 1 of 3 pass
- link-name: 0 of 1 pass
- link-distinct: n/a · no links on the page
- button-name: n/a · no buttons on the page
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

- 12 elements · 3 requests · 2 kB transferred · 0 third-party hosts

## Reading

- 4 events · 1 shown and not said · 0 said and not shown
- depth 4: the longest run the markup obliges
- the page says 66 bytes; 24 bytes travel for each
- one at a time, by ear: 3 steps
- up to 4 at a time: 4 steps as the page stands · 4 with nothing failing (between 4 and 4 at this depth and size)
