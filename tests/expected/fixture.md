# Relevé · http://localhost:8765/fixture.html

Observation `81e0244c` · 2026-10-16T10:46:58+00:00 · criteria v7 · screenshot `c331abf4b86e8edc` · Chromium 141.0.7390.37  
29 surfaces · 15 fail · 41 review · 3 hint · 37 pass · first observation of this page

Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement.
To correct a line, change its verdict word or add a note after `//`, then run `releve correct`.

## Fail (15)

- **FAIL** page-title · page · the page has no title → add a \<title> that names the page {e7e6f619}
- **FAIL** page-lang · page · no lang on \<html> → set lang on \<html>, e.g. lang="fr" {d1097b6b}
- **FAIL** zoom · page · viewport “width=device-width, initial-scale=1, maximum-scale=1” → remove maximum-scale and user-scalable {d1af5b6b}
- **FAIL** reflow · page · content is 600 px wide in a 320 px viewport → remove horizontal scrolling at 320 px {36da95a1}
- **FAIL** image-alt · `body > img:nth-of-type(1)` · no alt attribute → add alt; alt="" if the image is decorative {aec20425}
- **FAIL** image-alt · `body > svg` · role=img without a name → add aria-label or \<title> {70716e29}
- **FAIL** text-contrast · `body > p.pale:nth-of-type(1)` · #999999 on #ffffff · 2.84:1, needs 4.50:1 · “Pale text that fails contrast.” → use #767676 {5af26a21}
- **FAIL** link-name · `body > header > nav > a:nth-of-type(2)` · link without a name → give the link text, an image alt, or aria-label {b254e44b}
- **FAIL** button-name · `body > button:nth-of-type(1)` · button without a name → give the button text or aria-label {f8e6f54f}
- **FAIL** control-label · `body > form > input:nth-of-type(1)` · field without a name; placeholder “Votre e-mail” only → associate a \<label>, or add aria-label {256aafa2}
- **FAIL** frame-title · `body > iframe` · frame without a title → add a title that says what the frame holds {3229c18c}
- **FAIL** autoplay · `body > video` · plays sound on load → add muted, or remove autoplay {834334b1}
- **FAIL** unique-ids · page · id “dup” used 2 times → give each element its own id {4b8179e0}
- **FAIL** paired-colours · `body > p.pale:nth-of-type(1)` · text colour set, no background set → set a background colour on it or on a parent {53dc264c}
- **FAIL** paired-colours · `body > p.ok:nth-of-type(2)` · text colour set, no background set → set a background colour on it or on a parent {4713f7a8}

## Review (41)

- **REVIEW** main-region · page · no main landmark → wrap the main content in \<main> {f5adde0e}
- **REVIEW** heading-order · `body > h3` · h1 then h3 “Skipped a level” → h2 {d3953980}
- **REVIEW** image-alt · `body > header > nav > a:nth-of-type(2) > img` · alt="", marked decorative → add an alternative describing the image {b2a324a2}
- **REVIEW** image-alt · `body > img:nth-of-type(2)` · alt “IMG\_2031.jpg”, a file name → rewrite the alternative to describe the image {ce395394}
- **REVIEW** text-contrast · `body > div.banner:nth-of-type(1)` · text over a background image · “Text over a background image.” {804e767f}
- **REVIEW** link-name · `body > a` · link “en savoir plus” depends on its context → name the destination {85ed634e}
- **REVIEW** autocomplete · `body > form > input:nth-of-type(1)` · the field “email” declares no purpose → if it asks for the visitor's own data, add autocomplete="email" {2b08a85f}
- **REVIEW** autocomplete · `#n` · the field “Nom” declares no purpose → if it asks for the visitor's own data, add autocomplete="family-name" {c010fbf7}
- **REVIEW** media-captions · `body > video` · video without a caption track → if it carries speech, add \<track kind="captions"> {4600a9c9}
- **REVIEW** review-images · page · RGAA 1.6 · 3 images → add a description nearby or linked by aria-describedby {0526aa1f}
- **REVIEW** review-images · page · RGAA 1.7 · 3 images → rewrite the description {282f8865}
- **REVIEW** review-images · page · RGAA 1.8 · 3 images → set the text as text {224a0e03}
- **REVIEW** review-images · page · RGAA 1.9 · 3 images → wrap image and caption in \<figure> with \<figcaption> {ce091c94}
- **REVIEW** review-frames · page · RGAA 2.2 · 1 frame → rewrite the frame's title {164fa3f6}
- **REVIEW** review-colours · page · RGAA 3.1 · this page → add text, a shape or a pattern beside the color {0d0fcd2b}
- **REVIEW** review-colours · page · RGAA 3.3 · this page → raise their contrast to 3:1 {ba9f12a0}
- **REVIEW** review-media · page · RGAA 4.1 · 1 audio or video element → add a transcript {d40e83c6}
- **REVIEW** review-media · page · RGAA 4.2 · 1 audio or video element → rewrite it to match {4a1e2a64}
- **REVIEW** review-media · page · RGAA 4.4 · 1 audio or video element → correct the captions {e5fe0fcc}
- **REVIEW** review-media · page · RGAA 4.5 · 1 audio or video element → add an audio description {199dd846}
- **REVIEW** review-media · page · RGAA 4.6 · 1 audio or video element → rewrite the audio description {20aff219}
- **REVIEW** review-media · page · RGAA 4.7 · 1 audio or video element → name the media beside it {75a437cd}
- **REVIEW** review-media · page · RGAA 4.8 · 1 audio or video element → add an alternative {178e99ac}
- **REVIEW** review-media · page · RGAA 4.9 · 1 audio or video element → rewrite the alternative {fe1ecd45}
- **REVIEW** review-media · page · RGAA 4.11 · 1 audio or video element → use a player whose controls take the focus {bfdbcf38}
- **REVIEW** review-media · page · RGAA 4.12 · 1 audio or video element → make its controls reachable by keyboard {9845b426}
- **REVIEW** review-media · page · RGAA 4.13 · 1 audio or video element → give its controls names and roles {570dcd1a}
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

## Hint (3)

- **HINT** media-autoplay · `body > video` · starts by itself → let the reader start it {4e2a1395}
- **HINT** image-weight · `body > img:nth-of-type(1)` · 600×300 px shown at 100×50 → serve at most 200×100 px {b0acdb8f}
- **HINT** image-format · `body > img:nth-of-type(1)` · image\/png, 529 kB → serve AVIF or WebP {e7573373}

## By criterion

- page-title: 0 of 1 pass
- page-lang: 0 of 1 pass
- doctype: 1 of 1 pass
- zoom: 0 of 1 pass
- reflow: 0 of 1 pass
- main-region: 0 of 1 pass
- skip-link: n/a · no main landmark to lead to
- heading-order: 1 of 2 pass
- heading-look: 1 of 1 pass
- list-look: 1 of 1 pass
- empty-blocks: 1 of 1 pass
- presentation: 1 of 1 pass
- image-alt: 0 of 4 pass
- text-contrast: 10 of 12 pass
- link-name: 1 of 3 pass
- link-distinct: 1 of 1 pass
- button-name: 1 of 2 pass
- label-in-name: n/a · no name given by the code over words shown
- control-label: 1 of 2 pass
- group-legend: n/a · no group of fields on the page
- field-group: n/a · no radio buttons on the page
- autocomplete: 0 of 2 pass
- table-headers: n/a · no tables on the page
- frame-title: 0 of 1 pass
- autoplay: 0 of 1 pass
- media-captions: 0 of 1 pass
- unique-ids: 0 of 1 pass
- tab-order: 1 of 1 pass
- hidden-focus: 1 of 1 pass
- focus-visible: 1 of 1 pass
- keyboard-trap: 1 of 1 pass
- lang-code: n/a · the page states no language
- direction: n/a · no right-to-left script on the page
- text-spacing: 1 of 1 pass
- motion: 1 of 1 pass
- clickable: 1 of 1 pass
- generated-text: 1 of 1 pass
- paired-colours: 0 of 2 pass
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
- media-autoplay: 0 of 1 pass
- endless: 1 of 1 pass
- fonts: n/a · no font is downloaded
- compression: n/a · read from this machine: how it is served is not judged
- caching: n/a · read from this machine: how it is served is not judged
- protocol: n/a · read from this machine: how it is served is not judged
- lazy-images: n/a · no image below the second screen
- image-weight: 2 of 3 pass
- image-format: 2 of 3 pass
- review-images: 0 of 4 pass
- review-frames: 0 of 1 pass
- review-colours: 0 of 2 pass
- review-media: 0 of 11 pass
- review-tables: n/a · no tables on the page
- review-scripts: n/a · no script on the page
- review-title: n/a · the page has no title
- review-structure: 0 of 1 pass
- review-presentation: 0 of 5 pass
- review-forms: 0 of 7 pass
- review-navigation: 0 of 2 pass
- review-consultation: 0 of 5 pass

## Footprint

- 33 elements · 5 requests · 532 kB transferred · 0 third-party hosts

## Reading

- 17 events · 5 shown and not said · 0 said and not shown
- depth 16: the longest run the markup obliges
- the page says 126 bytes; 4323 bytes travel for each
- one at a time, by ear: 12 steps
- up to 4 at a time: 17 steps as the page stands · 16 with nothing failing (between 16 and 16 at this depth and size)
- mending, in order: page-lang leaves 17 steps, zoom leaves 17 steps, reflow leaves 16 steps
