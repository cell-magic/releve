# Relevé · http://localhost:8765/names.html

Observation `62aabccb` · 2026-10-16T10:47:15+00:00 · criteria v7 · screenshot `145463d2a82d3273` · Chromium 141.0.7390.37  
31 surfaces · 4 fail · 26 review · 0 hint · 52 pass · first observation of this page

Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement.
To correct a line, change its verdict word or add a note after `//`, then run `releve correct`.

## Fail (4)

- **FAIL** label-in-name · `body > nav > ul > li:nth-of-type(3) > a` · shows “Prices”, is named “Tarifs 2026” → begin the name with the visible words {8c4b8aab}
- **FAIL** label-in-name · `#content > p:nth-of-type(2) > button:nth-of-type(1)` · shows “Send”, is named “Submit the form” → begin the name with the visible words {70cbc967}
- **FAIL** label-in-name · `#e` · shows “Your address”, is named “E-mail” → begin the name with the visible words {7d8d56c1}
- **FAIL** hidden-focus · `#content > div > a` · takes the focus under aria-hidden → take it out of the tab order, or remove aria-hidden {e6ad7dd1}

## Review (26)

- **REVIEW** link-name · `#content > ul > li:nth-of-type(3) > a` · link “read more” depends on its context → name the destination {368b6d3f}
- **REVIEW** link-name · `#content > ul > li:nth-of-type(4) > a` · link “read more” depends on its context → name the destination {f4c95753}
- **REVIEW** link-distinct · `#content > ul > li:nth-of-type(1) > a` · “Annual report” names 2 links that lead to 2 places → name each destination {d6ac7800}
- **REVIEW** link-distinct · `#content > ul > li:nth-of-type(2) > a` · “Annual report” names 2 links that lead to 2 places → name each destination {22241570}
- **REVIEW** tab-order · `#content > p:nth-of-type(3) > a` · tabindex above 0 → order the code as the page reads, and use tabindex="0" {b0559813}
- **REVIEW** lang-code · page · page language lang="en" → set lang to the language the page is written in {037a9ec3}
- **REVIEW** lang-code · page · no passage marked in another language → mark each passage in another language with lang {df860cc4}
- **REVIEW** documents · `#content > ul > li:nth-of-type(1) > a` · localhost:8765\/report-2025.pdf → tag the document, or offer an accessible version {bb7be59b}
- **REVIEW** documents · `#content > ul > li:nth-of-type(2) > a` · localhost:8765\/report-2024.pdf → tag the document, or offer an accessible version {2afceff7}
- **REVIEW** review-colours · page · RGAA 3.1 · this page → add text, a shape or a pattern beside the color {0d0fcd2b}
- **REVIEW** review-colours · page · RGAA 3.3 · this page → raise their contrast to 3:1 {ba9f12a0}
- **REVIEW** review-title · page · RGAA 8.6 · “Names” → rewrite the title: the page, then the site {ffdb03e3}
- **REVIEW** review-structure · page · RGAA 9.4 · this page → mark quotations with \<q> or \<blockquote> {78b9d89c}
- **REVIEW** review-presentation · page · RGAA 10.3 · this page → order the code as the page reads {28d2af9d}
- **REVIEW** review-presentation · page · RGAA 10.9 · this page → add text to the shape, size or position {ea5933eb}
- **REVIEW** review-presentation · page · RGAA 10.10 · this page → put the text equivalent in the code {2d827e46}
- **REVIEW** review-presentation · page · RGAA 10.13 · this page → close it with Escape; keep it while hovered {b8a9d60f}
- **REVIEW** review-presentation · page · RGAA 10.14 · this page → show it on :focus-within as on :hover {49d9faa2}
- **REVIEW** review-forms · page · RGAA 11.3 · 1 form field → name them alike {0b4c39c5}
- **REVIEW** review-forms · page · RGAA 11.4 · 1 form field → place the name beside the field {95990973}
- **REVIEW** review-forms · page · RGAA 11.10 · 1 form field → state required fields and formats; name each error {ba9fa8ea}
- **REVIEW** review-forms · page · RGAA 11.11 · 1 form field → suggest the correction {98d973b3}
- **REVIEW** review-forms · page · RGAA 11.12 · 1 form field → add a review step before sending {f7c65275}
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
- focus-visible: 1 of 1 pass
- keyboard-trap: 1 of 1 pass
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
- documents: 0 of 2 pass
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
- review-tables: n/a · no tables on the page
- review-scripts: n/a · no script on the page
- review-title: 0 of 1 pass
- review-structure: 0 of 1 pass
- review-presentation: 0 of 5 pass
- review-forms: 0 of 7 pass
- review-navigation: 0 of 2 pass
- review-consultation: 0 of 5 pass

## Footprint

- 39 elements · 1 request · 2 kB transferred · 0 third-party hosts

## Reading

- 16 events · 0 shown and not said · 0 said and not shown
- depth 10: the longest run the markup obliges
- the page says 84 bytes; 30 bytes travel for each
- one at a time, by ear: 15 steps
- up to 4 at a time: 10 steps as the page stands · 10 with nothing failing (between 10 and 11 at this depth and size)
