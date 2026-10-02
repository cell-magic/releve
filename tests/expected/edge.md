# Relevé · http://localhost:8765/edge.html

Observation `fe2f1025` · 2026-10-02T09:02:53+00:00 · criteria v2 · screenshot `153eacff906e27a0` · Chromium 141.0.7390.37  
13 surfaces · 5 fail · 1 review · 0 hint · 16 pass · first observation of this page

Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement.
To correct a line, change its verdict word or add a note after `//`, then run `releve correct`.

## Fail (5)

- **FAIL** image-alt · `body > main > section:nth-of-type(1) > div > ul > li:nth-of-type(2) > a > img` · no alt attribute → add alt; alt="" if the image is decorative {0982a92f}
- **FAIL** image-alt · `body > main > section:nth-of-type(2) > div > ul > li:nth-of-type(2) > a > img` · no alt attribute → add alt; alt="" if the image is decorative {389f8682}
- **FAIL** text-contrast · `body > main > p:nth-of-type(3)` · #aaaaaa on #ffffff · 2.32:1, needs 4.50:1 · “Horaires \/\/ fermé le lundi” → use #767676 {fc1e06ed}
- **FAIL** link-name · `body > main > section:nth-of-type(1) > div > ul > li:nth-of-type(2) > a` · link without a name → give the link text, an image alt, or aria-label {8dc7f284}
- **FAIL** link-name · `body > main > section:nth-of-type(2) > div > ul > li:nth-of-type(2) > a` · link without a name → give the link text, an image alt, or aria-label {6c0ea2e8}

## Review (1)

- **REVIEW** text-contrast · `body > main > p:nth-of-type(2)` · #808080 on #ffffff · 3.97:1, needs 4.50:1 · “Half faded” · partly transparent (opacity 0.50), may be mid-animation {731deb3e}

## By criterion

- page-title: 1 of 1 pass
- page-lang: 1 of 1 pass
- zoom: 1 of 1 pass
- reflow: 1 of 1 pass
- main-region: 1 of 1 pass
- heading-order: 1 of 1 pass
- image-alt: 0 of 2 pass
- text-contrast: 3 of 5 pass
- link-name: 0 of 2 pass
- button-name: 2 of 2 pass
- control-label: n/a · no form fields on the page
- frame-title: n/a · no frames on the page
- autoplay: n/a · no audio or video on the page
- unique-ids: 1 of 1 pass
- ai-disclosure: n/a · no conversational widget detected
- image-weight: 2 of 2 pass
- image-format: 2 of 2 pass

## Footprint

- 26 elements · 2 requests · 2 kB transferred · 0 third-party hosts
