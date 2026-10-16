# Relevé · http://localhost:8765/keyboard.html

Observation `0d5846cd` · 2026-10-16T10:47:10+00:00 · criteria v6 · screenshot `518436acc78dbd65` · Chromium 141.0.7390.37  
16 surfaces · 3 fail · 33 review · 0 hint · 42 pass · first observation of this page

Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement.
To correct a line, change its verdict word or add a note after `//`, then run `releve correct`.

## Fail (3)

- **FAIL** focus-visible · `body > main > p:nth-of-type(4) > button.bare` · no visible focus → add a :focus-visible outline that contrasts with its surroundings {134f91e8}
- **FAIL** focus-visible · `body > main > p:nth-of-type(6) > span.hold` · no visible focus → add a :focus-visible outline that contrasts with its surroundings {cab2a99a}
- **FAIL** keyboard-trap · `body > main > p:nth-of-type(6) > span.hold` · focus held: Tab, Shift+Tab and Escape blocked → release Tab and Shift+Tab {1279a36e}

## Review (33)

- **REVIEW** image-alt · `body > main > img:nth-of-type(1)` · alt “The harbour at dawn” → rewrite the alternative to describe the image {32805ed0}
- **REVIEW** image-alt · `body > main > img:nth-of-type(2)` · alt="", marked decorative → add an alternative describing the image {fbcdbc1e}
- **REVIEW** lang-code · page · page language lang="en" → set lang to the language the page is written in {037a9ec3}
- **REVIEW** lang-code · page · no passage marked in another language → mark each passage in another language with lang {df860cc4}
- **REVIEW** review-images · page · RGAA 1.6 · 2 images → add a description nearby or linked by aria-describedby {583d35e0}
- **REVIEW** review-images · page · RGAA 1.7 · 2 images → rewrite the description {3a382422}
- **REVIEW** review-images · page · RGAA 1.8 · 2 images → set the text as text {ef514220}
- **REVIEW** review-images · page · RGAA 1.9 · 2 images → wrap image and caption in \<figure> with \<figcaption> {9927ac7b}
- **REVIEW** review-colours · page · RGAA 3.1 · this page → add text, a shape or a pattern beside the color {0d0fcd2b}
- **REVIEW** review-colours · page · RGAA 3.3 · this page → raise their contrast to 3:1 {ba9f12a0}
- **REVIEW** review-scripts · page · RGAA 7.1 · this page → use native elements, or the matching ARIA pattern {04d649b5}
- **REVIEW** review-scripts · page · RGAA 7.2 · this page → make the alternative complete {c7bc7cd2}
- **REVIEW** review-scripts · page · RGAA 7.4 · this page → start changes of context on a button only {ad1847d8}
- **REVIEW** review-scripts · page · RGAA 7.5 · this page → put them in role="status" or role="alert" {213dbec2}
- **REVIEW** review-title · page · RGAA 8.6 · “Keyboard” → rewrite the title: the page, then the site {ffdb03e3}
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
- **REVIEW** review-navigation · page · RGAA 12.10 · this page → add a modifier key, or a setting to turn them off {1114b1f0}
- **REVIEW** review-navigation · page · RGAA 12.11 · this page → make it reachable with Tab {879ef122}
- **REVIEW** review-consultation · page · RGAA 13.7 · this page → remove the flashing {8ea4a450}
- **REVIEW** review-consultation · page · RGAA 13.9 · this page → remove the orientation lock {04984447}
- **REVIEW** review-consultation · page · RGAA 13.10 · this page → add buttons for each gesture {37fe54af}
- **REVIEW** review-consultation · page · RGAA 13.11 · this page → act on release, not on press {e41e32b7}
- **REVIEW** review-consultation · page · RGAA 13.12 · this page → add a control, and a setting to turn motion off {ba389baa}

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
- text-contrast: 8 of 8 pass
- link-name: 2 of 2 pass
- link-distinct: 1 of 1 pass
- button-name: 1 of 1 pass
- label-in-name: n/a · no name given by the code over words shown
- control-label: 1 of 1 pass
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
- focus-visible: 0 of 2 pass
- keyboard-trap: 0 of 1 pass
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
- image-weight: 2 of 2 pass
- image-format: 2 of 2 pass
- review-images: 0 of 4 pass
- review-frames: n/a · no frames on the page
- review-colours: 0 of 2 pass
- review-media: n/a · no audio or video on the page
- review-tables: n/a · no tables on the page
- review-scripts: 0 of 4 pass
- review-title: 0 of 1 pass
- review-structure: 0 of 1 pass
- review-presentation: 0 of 5 pass
- review-forms: 0 of 7 pass
- review-navigation: 0 of 2 pass
- review-consultation: 0 of 5 pass

## Footprint

- 25 elements · 3 requests · 3 kB transferred · 0 third-party hosts

## Reading

- 10 events · 0 shown and not said · 0 said and not shown
- depth 10: the longest run the markup obliges
- the page says 120 bytes; 23 bytes travel for each
- one at a time, by ear: 10 steps
- up to 4 at a time: 10 steps as the page stands · 10 with nothing failing (between 10 and 10 at this depth and size)
