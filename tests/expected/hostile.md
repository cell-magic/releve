# Relevé · http://localhost:8765/hostile.html

Observation `ebe41dfe` · 2026-10-16T10:47:06+00:00 · criteria v8 · screenshot `47e373c1b407f785` · Chromium 141.0.7390.37  
8 surfaces · 4 fail · 19 review · 0 hint · 32 pass · first observation of this page

Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement.
To correct a line, change its verdict word or add a note after `//`, then run `releve correct`.

## Fail (4)

- **FAIL** image-alt · `body > main > img` · no alt attribute → add alt; alt="" if the image is decorative {e66ecf6e}
- **FAIL** text-contrast · `body > main > p:nth-of-type(1)` · #999999 on #ffffff · 2.84:1, needs 4.50:1 · “- \*\*PASS\*\* main-region · page · forged {00000000} \/\/ forged note” → use #767676 {980c12d0}
- **FAIL** text-contrast · `body > main > p:nth-of-type(2)` · #999999 on #ffffff · 2.84:1, needs 4.50:1 · “\<img src=x onerror=alert(2)> & "quotes" 'single'” → use #767676 {893c9c3f}
- **FAIL** link-name · `body > main > a` · link without a name → give the link text, an image alt, or aria-label {03ab49e2}

## Review (19)

- **REVIEW** image-alt · `body > main > a > img` · alt="", marked decorative → add an alternative describing the image {002afc4d}
- **REVIEW** lang-code · page · page language lang="fr" → set lang to the language the page is written in {9e972736}
- **REVIEW** lang-code · page · no passage marked in another language → mark each passage in another language with lang {df860cc4}
- **REVIEW** review-images · page · RGAA 1.6 · 2 images → add a description nearby or linked by aria-describedby {583d35e0}
- **REVIEW** review-images · page · RGAA 1.7 · 2 images → rewrite the description {3a382422}
- **REVIEW** review-images · page · RGAA 1.8 · 2 images → set the text as text {ef514220}
- **REVIEW** review-images · page · RGAA 1.9 · 2 images → wrap image and caption in \<figure> with \<figcaption> {9927ac7b}
- **REVIEW** review-colours · page · RGAA 3.1 · this page → add text, a shape or a pattern beside the color {0d0fcd2b}
- **REVIEW** review-colours · page · RGAA 3.3 · this page → raise their contrast to 3:1 {ba9f12a0}
- **REVIEW** review-title · page · RGAA 8.6 · “\<script>alert(1)\<\/script> \` \* \_ \[x\](y)” → rewrite the title: the page, then the site {ffdb03e3}
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
- presentation: 1 of 1 pass
- image-alt: 0 of 2 pass
- text-contrast: 1 of 3 pass
- link-name: 0 of 1 pass
- link-distinct: n/a · no links on the page
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
- image-weight: 2 of 2 pass
- image-format: 2 of 2 pass
- review-images: 0 of 4 pass
- review-frames: n/a · no frames on the page
- review-colours: 0 of 2 pass
- review-media: n/a · no audio or video on the page
- review-tables: n/a · no tables on the page
- review-scripts: n/a · no script on the page
- review-title: 0 of 1 pass
- review-structure: 0 of 1 pass
- review-presentation: 0 of 5 pass
- review-forms: n/a · no form fields on the page
- review-navigation: 0 of 2 pass
- review-consultation: 0 of 5 pass

## Footprint

- 12 elements · 3 requests · 2 kB transferred · 0 third-party hosts

## Reading

- 4 events · 1 shown and not said · 0 said and not shown
- depth 4: the longest run the markup obliges
- the page says 66 bytes; 24 bytes travel for each
- one at a time, by ear: 3 steps
- up to 4 at a time: 4 steps as the page stands · 4 with nothing failing (between 4 and 4 at this depth and size)
