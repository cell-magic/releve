# Relevé · http://localhost:8765/fixture.html

Observation `ee10a85e` · 2026-09-22T13:55:45+00:00 · criteria v2 · screenshot `981c89df7885b7a7`  
29 surfaces · 13 fail · 5 review · 2 hint · 19 pass · first observation of this page

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

## Review (5)

- **REVIEW** main-region · page · no main landmark → wrap the main content in \<main> {f5adde0e}
- **REVIEW** heading-order · `body > h3` · h1 then h3 “Skipped a level” → h2 {d3953980}
- **REVIEW** image-alt · `body > img:nth-of-type(2)` · alt “IMG\_2031.jpg” looks like a file name → describe what the image shows {ce395394}
- **REVIEW** text-contrast · `body > div.banner:nth-of-type(1)` · text over a background image · “Text over a background image.” {804e767f}
- **REVIEW** link-name · `body > a` · link “en savoir plus” depends on its context → name the destination {85ed634e}

## Hint (2)

- **HINT** image-weight · `body > img:nth-of-type(1)` · 600×300 px shown at 100×50 → serve at most 200×100 px {b0acdb8f}
- **HINT** image-format · `body > img:nth-of-type(1)` · image\/png, 529 kB → serve AVIF or WebP {e7573373}

## By criterion

- page-title: 0 of 1 pass
- page-lang: 0 of 1 pass
- zoom: 0 of 1 pass
- reflow: 0 of 1 pass
- main-region: 0 of 1 pass
- heading-order: 1 of 2 pass
- image-alt: 1 of 4 pass
- text-contrast: 10 of 12 pass
- link-name: 1 of 3 pass
- button-name: 1 of 2 pass
- control-label: 1 of 2 pass
- frame-title: 0 of 1 pass
- autoplay: 0 of 1 pass
- unique-ids: 0 of 1 pass
- ai-disclosure: n/a · no conversational widget detected
- image-weight: 2 of 3 pass
- image-format: 2 of 3 pass

## Footprint

- 33 elements · 5 requests · 532 kB transferred · 0 third-party hosts
