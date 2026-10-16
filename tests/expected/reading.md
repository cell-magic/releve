# Relevé · http://localhost:8765/reading.html

Observation `2096bd57` · 2026-10-16T10:47:30+00:00 · criteria v8 · screenshot `b99cd51906b48b4a` · Chromium 141.0.7390.37  
54 surfaces · 6 fail · 28 review · 0 hint · 75 pass · first observation of this page

Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement.
To correct a line, change its verdict word or add a note after `//`, then run `releve correct`.

## Fail (6)

- **FAIL** image-alt · `#main > img` · no alt attribute → add alt; alt="" if the image is decorative {2df2dc8e}
- **FAIL** text-contrast · `#main > ul:nth-of-type(2) > li.pale:nth-of-type(1)` · #aaaaaa on #ffffff · 2.32:1, needs 4.50:1 · “Pale one” → use #767676 {df9f5b37}
- **FAIL** text-contrast · `#main > ul:nth-of-type(2) > li.pale:nth-of-type(2)` · #aaaaaa on #ffffff · 2.32:1, needs 4.50:1 · “Pale two” → use #767676 {e498e6a9}
- **FAIL** text-contrast · `#main > ul:nth-of-type(2) > li.pale:nth-of-type(3)` · #aaaaaa on #ffffff · 2.32:1, needs 4.50:1 · “Pale three” → use #767676 {53a7a049}
- **FAIL** text-contrast · `#main > ul:nth-of-type(2) > li.pale:nth-of-type(4)` · #aaaaaa on #ffffff · 2.32:1, needs 4.50:1 · “Pale four” → use #767676 {f4432bf5}
- **FAIL** focus-visible · `body > a.unseen` · no visible focus → add a :focus-visible outline that contrasts with its surroundings {57470045}

## Review (28)

- **REVIEW** image-alt · `#main > p:nth-of-type(2) > img` · alt="", marked decorative → add an alternative describing the image {4aab7636}
- **REVIEW** lang-code · page · page language lang="en" → set lang to the language the page is written in {037a9ec3}
- **REVIEW** lang-code · page · no passage marked in another language → mark each passage in another language with lang {df860cc4}
- **REVIEW** review-images · page · RGAA 1.6 · 2 images → add a description nearby or linked by aria-describedby {583d35e0}
- **REVIEW** review-images · page · RGAA 1.7 · 2 images → rewrite the description {3a382422}
- **REVIEW** review-images · page · RGAA 1.8 · 2 images → set the text as text {ef514220}
- **REVIEW** review-images · page · RGAA 1.9 · 2 images → wrap image and caption in \<figure> with \<figcaption> {9927ac7b}
- **REVIEW** review-colours · page · RGAA 3.1 · this page → add text, a shape or a pattern beside the color {0d0fcd2b}
- **REVIEW** review-colours · page · RGAA 3.3 · this page → raise their contrast to 3:1 {ba9f12a0}
- **REVIEW** review-tables · page · RGAA 5.1 · 1 table → add a summary linked by aria-describedby or in the caption {c7c5875f}
- **REVIEW** review-tables · page · RGAA 5.2 · 1 table → rewrite the summary {b5712f94}
- **REVIEW** review-tables · page · RGAA 5.4 · 1 table → use \<caption> {833b6507}
- **REVIEW** review-tables · page · RGAA 5.5 · 1 table → rewrite the title {f8301b52}
- **REVIEW** review-title · page · RGAA 8.6 · “A page with a declared order” → rewrite the title: the page, then the site {ffdb03e3}
- **REVIEW** review-structure · page · RGAA 9.4 · this page → mark quotations with \<q> or \<blockquote> {78b9d89c}
- **REVIEW** review-presentation · page · RGAA 10.3 · this page → order the code as the page reads {28d2af9d}
- **REVIEW** review-presentation · page · RGAA 10.9 · this page → add text to the shape, size or position {ea5933eb}
- **REVIEW** review-presentation · page · RGAA 10.10 · this page → put the text equivalent in the code {2d827e46}
- **REVIEW** review-presentation · page · RGAA 10.13 · this page → close it with Escape; keep it while hovered {b8a9d60f}
- **REVIEW** review-presentation · page · RGAA 10.14 · this page → show it on :focus-within as on :hover {49d9faa2}
- **REVIEW** review-forms · page · RGAA 11.3 · 2 form fields → name them alike {edd043dc}
- **REVIEW** review-forms · page · RGAA 11.4 · 2 form fields → place the name beside the field {89e9da4a}
- **REVIEW** review-forms · page · RGAA 11.10 · 2 form fields → state required fields and formats; name each error {65b0422d}
- **REVIEW** review-forms · page · RGAA 11.11 · 2 form fields → suggest the correction {b4ef0857}
- **REVIEW** review-forms · page · RGAA 11.12 · 2 form fields → add a review step before sending {daf591d6}
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
- heading-order: 5 of 5 pass
- heading-look: 1 of 1 pass
- list-look: 1 of 1 pass
- empty-blocks: 1 of 1 pass
- presentation: 1 of 1 pass
- image-alt: 0 of 2 pass
- text-contrast: 31 of 35 pass
- link-name: 4 of 4 pass
- link-distinct: 1 of 1 pass
- button-name: 1 of 1 pass
- label-in-name: n/a · no name given by the code over words shown
- control-label: 2 of 2 pass
- group-legend: n/a · no group of fields on the page
- field-group: n/a · no radio buttons on the page
- autocomplete: 1 of 1 pass
- table-headers: 1 of 1 pass
- frame-title: n/a · no frames on the page
- autoplay: n/a · no audio or video on the page
- media-captions: n/a · no video on the page
- unique-ids: 1 of 1 pass
- tab-order: 1 of 1 pass
- hidden-focus: 1 of 1 pass
- focus-visible: 0 of 1 pass
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
- review-tables: 0 of 4 pass
- review-scripts: n/a · no script on the page
- review-title: 0 of 1 pass
- review-structure: 0 of 1 pass
- review-presentation: 0 of 5 pass
- review-forms: 0 of 7 pass
- review-navigation: 0 of 2 pass
- review-consultation: 0 of 5 pass

## Footprint

- 69 elements · 2 requests · 4 kB transferred · 0 third-party hosts

## Reading

- 39 events · 1 shown and not said · 1 said and not shown
- depth 8: the longest run the markup obliges
- the page says 189 bytes; 24 bytes travel for each
- one at a time, by ear: 38 steps
- up to 4 at a time: 16 steps as the page stands · 13 with nothing failing (between 10 and 15 at this depth and size)
- mending, in order: text-contrast leaves 13 steps
