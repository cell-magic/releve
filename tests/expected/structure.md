# Relevé · http://localhost:8765/structure.html

Observation `63eab70a` · 2026-10-16T10:47:34+00:00 · criteria v7 · screenshot `7d6520591fc7f158` · Chromium 141.0.7390.37  
25 surfaces · 8 fail · 38 review · 0 hint · 44 pass · first observation of this page

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

## Review (38)

- **REVIEW** heading-look · `body > main:nth-of-type(1) > div.big:nth-of-type(1)` · “Set large and not marked” is set at 28 px, the running text at 16 px, and it is not a heading → if it titles what follows, mark it h1 to h6 {7d2e3189}
- **REVIEW** heading-look · `body > main:nth-of-type(1) > div.bold:nth-of-type(2)` · “Set bold before plain text” is set bolder than the text that follows, and it is not a heading → if it titles what follows, mark it h1 to h6 {3b219feb}
- **REVIEW** list-look · `body > main:nth-of-type(1) > p:nth-of-type(5)` · 3 lines in a row begin like list items, from “• First of three” → mark them as a list: \<ul> or \<ol>, with \<li> {f8749eed}
- **REVIEW** media-captions · `body > main:nth-of-type(1) > video:nth-of-type(1)` · video without a caption track → if it carries speech, add \<track kind="captions"> {7efdc26e}
- **REVIEW** lang-code · page · page language lang="en" → set lang to the language the page is written in {037a9ec3}
- **REVIEW** lang-code · page · no passage marked in another language → mark each passage in another language with lang {df860cc4}
- **REVIEW** refresh · page · reloads itself every 600 s → let the reader stop or delay it {63673dfe}
- **REVIEW** review-colours · page · RGAA 3.1 · this page → add text, a shape or a pattern beside the color {0d0fcd2b}
- **REVIEW** review-colours · page · RGAA 3.3 · this page → raise their contrast to 3:1 {ba9f12a0}
- **REVIEW** review-media · page · RGAA 4.1 · 2 audio or video elements → add a transcript {4a941f5a}
- **REVIEW** review-media · page · RGAA 4.2 · 2 audio or video elements → rewrite it to match {2c3df1d0}
- **REVIEW** review-media · page · RGAA 4.4 · 2 audio or video elements → correct the captions {b7b9a2b0}
- **REVIEW** review-media · page · RGAA 4.5 · 2 audio or video elements → add an audio description {5c0e7f8f}
- **REVIEW** review-media · page · RGAA 4.6 · 2 audio or video elements → rewrite the audio description {ecbce533}
- **REVIEW** review-media · page · RGAA 4.7 · 2 audio or video elements → name the media beside it {85afc284}
- **REVIEW** review-media · page · RGAA 4.8 · 2 audio or video elements → add an alternative {87c34f93}
- **REVIEW** review-media · page · RGAA 4.9 · 2 audio or video elements → rewrite the alternative {ad64b25a}
- **REVIEW** review-media · page · RGAA 4.11 · 2 audio or video elements → use a player whose controls take the focus {96c8aa5c}
- **REVIEW** review-media · page · RGAA 4.12 · 2 audio or video elements → make its controls reachable by keyboard {5291104f}
- **REVIEW** review-media · page · RGAA 4.13 · 2 audio or video elements → give its controls names and roles {9a68ed93}
- **REVIEW** review-scripts · page · RGAA 7.1 · this page → use native elements, or the matching ARIA pattern {04d649b5}
- **REVIEW** review-scripts · page · RGAA 7.2 · this page → make the alternative complete {c7bc7cd2}
- **REVIEW** review-scripts · page · RGAA 7.4 · this page → start changes of context on a button only {ad1847d8}
- **REVIEW** review-scripts · page · RGAA 7.5 · this page → put them in role="status" or role="alert" {213dbec2}
- **REVIEW** review-title · page · RGAA 8.6 · “Structure” → rewrite the title: the page, then the site {ffdb03e3}
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
- focus-visible: n/a · nothing on the page takes the focus
- keyboard-trap: n/a · nothing on the page takes the focus
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
- review-images: n/a · no images on the page
- review-frames: n/a · no frames on the page
- review-colours: 0 of 2 pass
- review-media: 0 of 11 pass
- review-tables: n/a · no tables on the page
- review-scripts: 0 of 4 pass
- review-title: 0 of 1 pass
- review-structure: 0 of 1 pass
- review-presentation: 0 of 5 pass
- review-forms: n/a · no form fields on the page
- review-navigation: 0 of 2 pass
- review-consultation: 0 of 5 pass

## Footprint

- 39 elements · 3 requests · 3 kB transferred · 0 third-party hosts

## Reading

- 21 events · 2 shown and not said · 0 said and not shown
- depth 18: the longest run the markup obliges
- the page says 254 bytes; 12 bytes travel for each
- one at a time, by ear: 19 steps
- up to 4 at a time: 18 steps as the page stands · 18 with nothing failing (between 18 and 18 at this depth and size)
