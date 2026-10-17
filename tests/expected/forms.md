# Relevé · http://localhost:8765/forms.html

Observation `e7a98527` · 2026-10-16T10:47:02+00:00 · criteria v10 · screenshot `82dd9fc6e34bafbe` · Chromium 141.0.7390.37  
41 surfaces · 2 fail · 24 review · 0 hint · 70 pass · first observation of this page

Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement.
To correct a line, change its verdict word or add a note after `//`, then run `releve correct`.

## Fail (2)

- **FAIL** group-legend · `body > main > form > fieldset:nth-of-type(2)` · group of fields without a legend → add a \<legend>, or aria-label on the group {379bc0bb}
- **FAIL** autocomplete · `#c` · autocomplete="e-mail" is not a purpose a field can declare → use autocomplete="email" {415dfbc6}

## Review (24)

- **REVIEW** field-group · `body > main > form > p:nth-of-type(1) > label:nth-of-type(1) > input` · 3 radio buttons named “colour” stand outside any group → wrap them in a \<fieldset> with a \<legend> {7c106751}
- **REVIEW** autocomplete · `#d` · the field “First name” declares no purpose → if it asks for the visitor's own data, add autocomplete="given-name" {aaa7d0b5}
- **REVIEW** autocomplete · `#e` · the field “Number to call” declares no purpose → if it asks for the visitor's own data, add autocomplete="tel" {06a56abe}
- **REVIEW** lang-code · page · page language lang="en" → set lang to the language the page is written in {037a9ec3}
- **REVIEW** lang-code · page · no passage marked in another language → mark each passage in another language with lang {df860cc4}
- **REVIEW** review-colours · page · RGAA 3.1 · this page → add text, a shape or a pattern beside the color {0d0fcd2b}
- **REVIEW** review-colours · page · RGAA 3.3 · this page → raise their contrast to 3:1 {ba9f12a0}
- **REVIEW** review-title · page · RGAA 8.6 · “Forms” → rewrite the title: the page, then the site {ffdb03e3}
- **REVIEW** review-structure · page · RGAA 9.4 · this page → mark quotations with \<q> or \<blockquote> {78b9d89c}
- **REVIEW** review-presentation · page · RGAA 10.3 · this page → order the code as the page reads {28d2af9d}
- **REVIEW** review-presentation · page · RGAA 10.9 · this page → add text to the shape, size or position {ea5933eb}
- **REVIEW** review-presentation · page · RGAA 10.10 · this page → put the text equivalent in the code {2d827e46}
- **REVIEW** review-presentation · page · RGAA 10.13 · this page → close it with Escape; keep it while hovered {b8a9d60f}
- **REVIEW** review-presentation · page · RGAA 10.14 · this page → show it on :focus-within as on :hover {49d9faa2}
- **REVIEW** review-forms · page · RGAA 11.3 · 16 form fields → name them alike {e30f00ba}
- **REVIEW** review-forms · page · RGAA 11.4 · 16 form fields → place the name beside the field {a352d47a}
- **REVIEW** review-forms · page · RGAA 11.7 · 16 form fields → rewrite the legend {5aaa5040}
- **REVIEW** review-forms · page · RGAA 11.10 · 16 form fields → state required fields and formats; name each error {97480f5a}
- **REVIEW** review-forms · page · RGAA 11.11 · 16 form fields → suggest the correction {b90ac4b8}
- **REVIEW** review-forms · page · RGAA 11.12 · 16 form fields → add a review step before sending {7429ae7e}
- **REVIEW** review-forms · page · WCAG 3.3.7 · 16 form fields → fill it in from the earlier step, or offer it to choose {f3b7f937}
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
- text-contrast: 19 of 19 pass
- link-name: n/a · no links on the page
- link-distinct: n/a · no links on the page
- button-name: 1 of 1 pass
- label-in-name: n/a · no name given by the code over words shown
- control-label: 16 of 16 pass
- group-legend: 2 of 3 pass
- field-group: 3 of 4 pass
- autocomplete: 2 of 5 pass
- table-headers: n/a · no tables on the page
- frame-title: n/a · no frames on the page
- autoplay: n/a · no audio or video on the page
- media-captions: n/a · no video on the page
- unique-ids: 1 of 1 pass
- tab-order: 1 of 1 pass
- hidden-focus: 1 of 1 pass
- focus-visible: 1 of 1 pass
- focus-obscured: n/a · not recorded by the observer of that time
- target-size: n/a · not recorded by the observer of that time
- authentication: n/a · no password or code field on the page
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
- documents: n/a · no office document linked
- no-popup: 1 of 1 pass
- refresh: n/a · no timed refresh declared
- ai-disclosure: n/a · no conversational widget detected
- ai-image: n/a · no image states its origin
- asks-on-arrival: 1 of 1 pass
- consent-choice: n/a · not recorded by the observer of that time
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
- review-forms: 0 of 8 pass
- review-navigation: 0 of 2 pass
- review-consultation: 0 of 6 pass

## Footprint

- 55 elements · 1 request · 3 kB transferred · 0 third-party hosts

## Reading

- 30 events · 0 shown and not said · 0 said and not shown
- depth 4: the longest run the markup obliges
- the page says 114 bytes; 26 bytes travel for each
- one at a time, by ear: 30 steps
- up to 4 at a time: 10 steps as the page stands · 10 with nothing failing (between 8 and 10 at this depth and size)
