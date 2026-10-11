# Relevé · http://localhost:8765/names.html

Observation `d205b3c3` · 2026-10-11T17:42:06+00:00 · criteria v5 · screenshot `145463d2a82d3273` · Chromium 141.0.7390.37  
31 surfaces · 4 fail · 5 review · 0 hint · 44 pass · first observation of this page

Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement.
To correct a line, change its verdict word or add a note after `//`, then run `releve correct`.

## Fail (4)

- **FAIL** label-in-name · `body > nav > ul > li:nth-of-type(3) > a` · shows “Prices”, is named “Tarifs 2026” → begin the name with the visible words {8c4b8aab}
- **FAIL** label-in-name · `#content > p:nth-of-type(2) > button:nth-of-type(1)` · shows “Send”, is named “Submit the form” → begin the name with the visible words {70cbc967}
- **FAIL** label-in-name · `#e` · shows “Your address”, is named “E-mail” → begin the name with the visible words {7d8d56c1}
- **FAIL** hidden-focus · `#content > div > a` · takes the focus under aria-hidden → take it out of the tab order, or remove aria-hidden {e6ad7dd1}

## Review (5)

- **REVIEW** link-name · `#content > ul > li:nth-of-type(3) > a` · link “read more” depends on its context → name the destination {368b6d3f}
- **REVIEW** link-name · `#content > ul > li:nth-of-type(4) > a` · link “read more” depends on its context → name the destination {f4c95753}
- **REVIEW** link-distinct · `#content > ul > li:nth-of-type(1) > a` · “Annual report” names 2 links that lead to 2 places → name each destination {d6ac7800}
- **REVIEW** link-distinct · `#content > ul > li:nth-of-type(2) > a` · “Annual report” names 2 links that lead to 2 places → name each destination {22241570}
- **REVIEW** tab-order · `#content > p:nth-of-type(3) > a` · tabindex above 0 → order the code as the page reads, and use tabindex="0" {b0559813}

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
- image-alt: n/a · no images on the page
- text-contrast: 14 of 14 pass
- link-name: 8 of 10 pass
- link-distinct: 0 of 2 pass
- button-name: 2 of 2 pass
- label-in-name: 1 of 4 pass
- control-label: 1 of 1 pass
- group-legend: n/a · no group of fields on the page
- field-group: n/a · no radio buttons on the page
- autocomplete: 1 of 1 pass
- table-headers: n/a · no tables on the page
- frame-title: n/a · no frames on the page
- autoplay: n/a · no audio or video on the page
- media-captions: n/a · no video on the page
- unique-ids: 1 of 1 pass
- tab-order: 0 of 1 pass
- hidden-focus: 0 of 1 pass
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

- 39 elements · 1 request · 2 kB transferred · 0 third-party hosts

## Reading

- 16 events · 0 shown and not said · 0 said and not shown
- depth 10: the longest run the markup obliges
- the page says 84 bytes; 30 bytes travel for each
- one at a time, by ear: 15 steps
- up to 4 at a time: 10 steps as the page stands · 10 with nothing failing (between 10 and 11 at this depth and size)
