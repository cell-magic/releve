# Relevé · http://localhost:8765/fixture.html

Observation `c5885ab7` · 2026-10-11T17:41:57+00:00 · criteria v4 · screenshot `c331abf4b86e8edc` · Chromium 141.0.7390.37  
29 surfaces · 13 fail · 8 review · 3 hint · 31 pass · first observation of this page

Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement.
To correct a line, change its verdict word or add a note after `//`, then run `releve correct`.

## Fail (13)

- **FAIL** page-title · page · the page has no title → add a \<title> that names the page {e7e6f619}
- **FAIL** page-lang · page · no lang on \<html> → set lang on \<html>, e.g. lang="fr" {d1097b6b}
- **FAIL** zoom · page · viewport “width=device-width, initial-scale=1, maximum-scale=1” → remove maximum-scale and user-scalable {d1af5b6b}
- **FAIL** reflow · page · content is 600 px wide in a 320 px viewport → remove horizontal scrolling at 320 px {36da95a1}
- **FAIL** image-alt · `body > img:nth-of-type(1)` · no alt attribute → add alt; alt="" if the image is decorative {aec20425}
- **FAIL** image-alt · `body > svg` · role=img without a name → add aria-label or \<title> {70716e29}
- **FAIL** text-contrast · `body > p.pale:nth-of-type(1)` · #999999 on #ffffff · 2.84:1, needs 4.50:1 · “Pale text that fails contrast.” → use #767676 {5af26a21}
- **FAIL** link-name · `body > header > nav > a:nth-of-type(2)` · link without a name → give the link text, an image alt, or aria-label {b254e44b}
- **FAIL** button-name · `body > button:nth-of-type(1)` · button without a name → give the button text or aria-label {f8e6f54f}
- **FAIL** control-label · `body > form > input:nth-of-type(1)` · no label; placeholder “Votre e-mail” only → associate a \<label>, or add aria-label {256aafa2}
- **FAIL** frame-title · `body > iframe` · frame without a title → add a title that says what the frame holds {3229c18c}
- **FAIL** autoplay · `body > video` · plays sound on load → add muted, or remove autoplay {834334b1}
- **FAIL** unique-ids · page · id “dup” used 2 times → give each element its own id {4b8179e0}

## Review (8)

- **REVIEW** main-region · page · no main landmark → wrap the main content in \<main> {f5adde0e}
- **REVIEW** heading-order · `body > h3` · h1 then h3 “Skipped a level” → h2 {d3953980}
- **REVIEW** image-alt · `body > img:nth-of-type(2)` · alt “IMG\_2031.jpg” looks like a file name → describe what the image shows {ce395394}
- **REVIEW** text-contrast · `body > div.banner:nth-of-type(1)` · text over a background image · “Text over a background image.” {804e767f}
- **REVIEW** link-name · `body > a` · link “en savoir plus” depends on its context → name the destination {85ed634e}
- **REVIEW** autocomplete · `body > form > input:nth-of-type(1)` · the field “email” declares no purpose → if it asks for the visitor's own data, add autocomplete="email" {2b08a85f}
- **REVIEW** autocomplete · `#n` · the field “Nom” declares no purpose → if it asks for the visitor's own data, add autocomplete="family-name" {c010fbf7}
- **REVIEW** media-captions · `body > video` · video without a caption track → if it carries speech, add \<track kind="captions"> {4600a9c9}

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
- image-alt: 1 of 4 pass
- text-contrast: 10 of 12 pass
- link-name: 1 of 3 pass
- link-distinct: 1 of 1 pass
- button-name: 1 of 2 pass
- label-in-name: n/a · no name given by the code over a visible label
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

## Footprint

- 33 elements · 5 requests · 531 kB transferred · 0 third-party hosts

## Reading

- 17 events · 5 shown and not said · 0 said and not shown
- depth 16: the longest run the markup obliges
- the page says 126 bytes; 4319 bytes travel for each
- one at a time, by ear: 12 steps
- up to 4 at a time: 17 steps as the page stands · 16 with nothing failing (between 16 and 16 at this depth and size)
