# Relevé · http://localhost:8765/targets.html

Observation `fc3acf54` · 2026-10-16T18:56:04+00:00 · criteria v9 · screenshot `91b2bcb81a8a0957` · Chromium 141.0.7390.37  
23 surfaces · 16 fail · 30 review · 0 hint · 54 pass · first observation of this page

Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement.
To correct a line, change its verdict word or add a note after `//`, then run `releve correct`.

## Fail (16)

- **FAIL** empty-blocks · page · 2 empty paragraphs → remove them; spacing belongs to the style sheet {d826b93f}
- **FAIL** focus-visible · `#user` · no visible focus → add a :focus-visible outline that contrasts with its surroundings {0b0b0b00}
- **FAIL** focus-visible · `#pass` · no visible focus → add a :focus-visible outline that contrasts with its surroundings {81ccfa65}
- **FAIL** focus-visible · `#keep` · no visible focus → add a :focus-visible outline that contrasts with its surroundings {1b024543}
- **FAIL** focus-visible · `body > main > form > p:nth-of-type(4) > button` · no visible focus → add a :focus-visible outline that contrasts with its surroundings {dcea01a5}
- **FAIL** focus-visible · `body > main > p.far:nth-of-type(4) > a` · no visible focus → add a :focus-visible outline that contrasts with its surroundings {88834fea}
- **FAIL** focus-visible · `body > main > p:nth-of-type(5) > a` · no visible focus → add a :focus-visible outline that contrasts with its surroundings {7a3335c2}
- **FAIL** focus-obscured · `#user` · hidden under body > div.banner → leave it room, with scroll-padding beside a fixed header or banner, or move what covers it {091c56c2}
- **FAIL** focus-obscured · `#pass` · hidden under body > div.banner → leave it room, with scroll-padding beside a fixed header or banner, or move what covers it {5d764f22}
- **FAIL** focus-obscured · `#keep` · hidden under body > div.banner → leave it room, with scroll-padding beside a fixed header or banner, or move what covers it {4407bfa7}
- **FAIL** focus-obscured · `body > main > form > p:nth-of-type(4) > button` · hidden under body > div.banner → leave it room, with scroll-padding beside a fixed header or banner, or move what covers it {9b4d0216}
- **FAIL** focus-obscured · `body > main > p.far:nth-of-type(4) > a` · hidden under body > div.banner → leave it room, with scroll-padding beside a fixed header or banner, or move what covers it {8957a0cd}
- **FAIL** focus-obscured · `body > main > p:nth-of-type(5) > a` · hidden under body > div.banner → leave it room, with scroll-padding beside a fixed header or banner, or move what covers it {770c146d}
- **FAIL** target-size · `body > main > p.icons:nth-of-type(1) > a:nth-of-type(1)` · 16 × 16 px; “Two” 20 px from its centre → make it 24 × 24 px or more, or leave it room {72c5d4a2}
- **FAIL** target-size · `body > main > p.icons:nth-of-type(1) > a:nth-of-type(2)` · 16 × 16 px; “One” 20 px from its centre → make it 24 × 24 px or more, or leave it room {11141c22}
- **FAIL** target-size · `body > main > p.icons:nth-of-type(1) > a:nth-of-type(3)` · 16 × 16 px; “Two” 20 px from its centre → make it 24 × 24 px or more, or leave it room {67882321}

## Review (30)

- **REVIEW** authentication · `#pass` · password or code field, autocomplete="off" → let a password manager fill it: autocomplete="current-password" {87b605b4}
- **REVIEW** lang-code · page · page language lang="en" → set lang to the language the page is written in {037a9ec3}
- **REVIEW** lang-code · page · no passage marked in another language → mark each passage in another language with lang {df860cc4}
- **REVIEW** review-colours · page · RGAA 3.1 · this page → add text, a shape or a pattern beside the color {0d0fcd2b}
- **REVIEW** review-colours · page · RGAA 3.3 · this page → raise their contrast to 3:1 {ba9f12a0}
- **REVIEW** review-scripts · page · RGAA 7.1 · this page → use native elements, or the matching ARIA pattern {04d649b5}
- **REVIEW** review-scripts · page · RGAA 7.2 · this page → make the alternative complete {c7bc7cd2}
- **REVIEW** review-scripts · page · RGAA 7.4 · this page → start changes of context on a button only {ad1847d8}
- **REVIEW** review-scripts · page · RGAA 7.5 · this page → put them in role="status" or role="alert" {213dbec2}
- **REVIEW** review-title · page · RGAA 8.6 · “Targets” → rewrite the title: the page, then the site {ffdb03e3}
- **REVIEW** review-structure · page · RGAA 9.4 · this page → mark quotations with \<q> or \<blockquote> {78b9d89c}
- **REVIEW** review-presentation · page · RGAA 10.3 · this page → order the code as the page reads {28d2af9d}
- **REVIEW** review-presentation · page · RGAA 10.9 · this page → add text to the shape, size or position {ea5933eb}
- **REVIEW** review-presentation · page · RGAA 10.10 · this page → put the text equivalent in the code {2d827e46}
- **REVIEW** review-presentation · page · RGAA 10.13 · this page → close it with Escape; keep it while hovered {b8a9d60f}
- **REVIEW** review-presentation · page · RGAA 10.14 · this page → show it on :focus-within as on :hover {49d9faa2}
- **REVIEW** review-forms · page · RGAA 11.3 · 3 form fields → name them alike {d3083ead}
- **REVIEW** review-forms · page · RGAA 11.4 · 3 form fields → place the name beside the field {1c371c8c}
- **REVIEW** review-forms · page · RGAA 11.10 · 3 form fields → state required fields and formats; name each error {1d424ac4}
- **REVIEW** review-forms · page · RGAA 11.11 · 3 form fields → suggest the correction {be4e2b29}
- **REVIEW** review-forms · page · RGAA 11.12 · 3 form fields → add a review step before sending {bac441e2}
- **REVIEW** review-forms · page · WCAG 3.3.7 · 3 form fields → fill it in from the earlier step, or offer it to choose {b4cc3609}
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
- empty-blocks: 0 of 1 pass
- presentation: 1 of 1 pass
- image-alt: n/a · no images on the page
- text-contrast: 10 of 10 pass
- link-name: 7 of 7 pass
- link-distinct: 1 of 1 pass
- button-name: 1 of 1 pass
- label-in-name: n/a · no name given by the code over words shown
- control-label: 3 of 3 pass
- group-legend: n/a · no group of fields on the page
- field-group: n/a · no radio buttons on the page
- autocomplete: 1 of 1 pass
- table-headers: n/a · no tables on the page
- frame-title: n/a · no frames on the page
- autoplay: n/a · no audio or video on the page
- media-captions: n/a · no video on the page
- unique-ids: 1 of 1 pass
- tab-order: 1 of 1 pass
- hidden-focus: 1 of 1 pass
- focus-visible: 0 of 6 pass
- focus-obscured: 0 of 6 pass
- target-size: 6 of 9 pass
- authentication: 0 of 1 pass
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
- consent-choice: n/a · no prompt for consent on arrival
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
- review-forms: 0 of 8 pass
- review-navigation: 0 of 2 pass
- review-consultation: 0 of 6 pass

## Footprint

- 36 elements · 1 request · 2 kB transferred · 0 third-party hosts

## Reading

- 12 events · 0 shown and not said · 0 said and not shown
- depth 8: the longest run the markup obliges
- the page says 112 bytes; 21 bytes travel for each
- one at a time, by ear: 12 steps
- up to 4 at a time: 10 steps as the page stands · 8 with nothing failing (between 8 and 9 at this depth and size)
- mending, in order: focus-visible leaves 10 steps, focus-obscured leaves 8 steps
