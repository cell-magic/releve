# Relevé · http://localhost:8765/page.html

Observation `46ce2831` · 2026-10-16T10:47:19+00:00 · criteria v10 · screenshot `69b8f09771544ffb` · Chromium 141.0.7390.37  
22 surfaces · 8 fail · 31 review · 0 hint · 42 pass · first observation of this page

Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement.
To correct a line, change its verdict word or add a note after `//`, then run `releve correct`.

## Fail (8)

- **FAIL** lang-code · `body > main > p:nth-of-type(1) > span:nth-of-type(2)` · lang="english", not a language code → use an ISO 639 code {b4d12936}
- **FAIL** direction · page · 8 right-to-left characters; no direction declared → add dir="rtl" to each right-to-left passage {08741d5a}
- **FAIL** text-spacing · `body > main > p.box:nth-of-type(4)` · text cut once spacing is widened → let the box grow with its text: no fixed height with overflow hidden {e1ae6777}
- **FAIL** clickable · `body > main > p:nth-of-type(6) > span.tap` · acts on click; no key reaches it → use a \<button> or a link {2f28ba8c}
- **FAIL** paired-colours · `body > main > p.tinted:nth-of-type(8)` · text colour set, no background set → set a background colour on it or on a parent {97449be7}
- **FAIL** paired-colours · `body > main > p.plain:nth-of-type(9)` · text colour set, no background set → set a background colour on it or on a parent {36a90114}
- **FAIL** paired-colours · `body > main > p.plain:nth-of-type(9) > a` · text colour set, no background set → set a background colour on it or on a parent {551c30af}
- **FAIL** link-visible · `body > main > p.plain:nth-of-type(9) > a` · looks like the text around it: no underline, contrast under 3:1 → underline it, or set it at 3:1 against the text around it {ca0c625e}

## Review (31)

- **REVIEW** text-contrast · `body > main > p:nth-of-type(5) > span.pulse` · #505050 on #ffffff · 8.04:1, needs 4.50:1 · “New” · partly transparent (opacity 0.68), may be mid-animation {56c8ffd4}
- **REVIEW** lang-code · page · page language lang="en" → set lang to the language the page is written in {037a9ec3}
- **REVIEW** lang-code · page · 3 passages marked in another language → mark each passage in another language with lang {4cd658e3}
- **REVIEW** lang-code · `body > main > p:nth-of-type(1) > span:nth-of-type(1)` · passage marked lang="de" → set lang to the passage's language {86f7f914}
- **REVIEW** motion · `body > main > p:nth-of-type(5) > span.pulse` · moves without end → add a pause control, or stop it within 5 seconds {c0ece8b1}
- **REVIEW** generated-text · `body > main > p.price:nth-of-type(7)` · “From” set by the style sheet → move the words into the page {d1d6d109}
- **REVIEW** cryptic · page · 1 emoji on the page → wrap meaningful emoji in role="img" with aria-label {76cf9400}
- **REVIEW** captcha · page · CAPTCHA from localhost:8765 → offer an audio test or another way through {8b654d04}
- **REVIEW** captcha · page · its text alternative → say what the test is and what it is for {96d9948c}
- **REVIEW** documents · `body > main > p:nth-of-type(11) > a` · localhost:8765\/report.pdf → tag the document, or offer an accessible version {d301488a}
- **REVIEW** review-colours · page · RGAA 3.1 · this page → add text, a shape or a pattern beside the color {0d0fcd2b}
- **REVIEW** review-colours · page · RGAA 3.3 · this page → raise their contrast to 3:1 {ba9f12a0}
- **REVIEW** review-scripts · page · RGAA 7.1 · this page → use native elements, or the matching ARIA pattern {04d649b5}
- **REVIEW** review-scripts · page · RGAA 7.2 · this page → make the alternative complete {c7bc7cd2}
- **REVIEW** review-scripts · page · RGAA 7.4 · this page → start changes of context on a button only {ad1847d8}
- **REVIEW** review-scripts · page · RGAA 7.5 · this page → put them in role="status" or role="alert" {213dbec2}
- **REVIEW** review-title · page · RGAA 8.6 · “Page” → rewrite the title: the page, then the site {ffdb03e3}
- **REVIEW** review-structure · page · RGAA 9.4 · this page → mark quotations with \<q> or \<blockquote> {78b9d89c}
- **REVIEW** review-presentation · page · RGAA 10.3 · this page → order the code as the page reads {28d2af9d}
- **REVIEW** review-presentation · page · RGAA 10.9 · this page → add text to the shape, size or position {ea5933eb}
- **REVIEW** review-presentation · page · RGAA 10.10 · this page → put the text equivalent in the code {2d827e46}
- **REVIEW** review-presentation · page · RGAA 10.13 · this page → close it with Escape; keep it while hovered {b8a9d60f}
- **REVIEW** review-presentation · page · RGAA 10.14 · this page → show it on :focus-within as on :hover {49d9faa2}
- **REVIEW** review-navigation · page · RGAA 12.10 · this page → add a modifier key, or a setting to turn them off {1114b1f0}
- **REVIEW** review-navigation · page · RGAA 12.11 · this page → make it reachable with Tab {879ef122}
- **REVIEW** review-consultation · page · RGAA 13.7 · this page → remove the flashing {8ea4a450}
- **REVIEW** review-consultation · page · RGAA 13.9 · this page → remove the orientation lock {04984447}
- **REVIEW** review-consultation · page · RGAA 13.10 · this page → add buttons for each gesture {37fe54af}
- **REVIEW** review-consultation · page · RGAA 13.11 · this page → act on release, not on press {e41e32b7}
- **REVIEW** review-consultation · page · RGAA 13.12 · this page → add a control, and a setting to turn motion off {ba389baa}
- **REVIEW** review-consultation · page · WCAG 2.5.7 · this page → add buttons or a tap-to-place alternative {b1d1a7c2}

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
- text-contrast: 16 of 17 pass
- link-name: 3 of 3 pass
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
- focus-visible: 1 of 1 pass
- focus-obscured: n/a · not recorded by the observer of that time
- target-size: n/a · not recorded by the observer of that time
- authentication: n/a · no password or code field on the page
- keyboard-trap: 1 of 1 pass
- lang-code: 1 of 5 pass
- direction: 0 of 1 pass
- text-spacing: 0 of 1 pass
- motion: 0 of 1 pass
- clickable: 0 of 1 pass
- generated-text: 0 of 1 pass
- paired-colours: 0 of 3 pass
- link-visible: 0 of 1 pass
- cryptic: 0 of 1 pass
- captcha: 0 of 2 pass
- documents: 0 of 1 pass
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
- review-scripts: 0 of 4 pass
- review-title: 0 of 1 pass
- review-structure: 0 of 1 pass
- review-presentation: 0 of 5 pass
- review-forms: n/a · no form fields on the page
- review-navigation: 0 of 2 pass
- review-consultation: 0 of 6 pass

## Footprint

- 28 elements · 2 requests · 3 kB transferred · 0 third-party hosts

## Reading

- 12 events · 0 shown and not said · 0 said and not shown
- depth 12: the longest run the markup obliges
- the page says 158 bytes; 20 bytes travel for each
- one at a time, by ear: 12 steps
- up to 4 at a time: 12 steps as the page stands · 12 with nothing failing (between 12 and 12 at this depth and size)
