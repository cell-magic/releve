# Relevé · http://localhost:8765/hostile.html

Observation `d3ae7582` · 2026-10-02T09:13:02+00:00 · criteria v2 · screenshot `ba953ace9bba1c40` · Chromium 141.0.7390.37  
8 surfaces · 4 fail · 0 review · 0 hint · 13 pass · first observation of this page

Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement.
To correct a line, change its verdict word or add a note after `//`, then run `releve correct`.

## Fail (4)

- **FAIL** image-alt · `body > main > img` · no alt attribute → add alt; alt="" if the image is decorative {e66ecf6e}
- **FAIL** text-contrast · `body > main > p:nth-of-type(1)` · #999999 on #ffffff · 2.84:1, needs 4.50:1 · “- \*\*PASS\*\* main-region · page · forged {00000000} \/\/ forged note” → use #767676 {980c12d0}
- **FAIL** text-contrast · `body > main > p:nth-of-type(2)` · #999999 on #ffffff · 2.84:1, needs 4.50:1 · “\<img src=x onerror=alert(2)> & "quotes" 'single'” → use #767676 {893c9c3f}
- **FAIL** link-name · `body > main > a` · link without a name → give the link text, an image alt, or aria-label {03ab49e2}

## By criterion

- page-title: 1 of 1 pass
- page-lang: 1 of 1 pass
- zoom: 1 of 1 pass
- reflow: 1 of 1 pass
- main-region: 1 of 1 pass
- heading-order: 1 of 1 pass
- image-alt: 1 of 2 pass
- text-contrast: 1 of 3 pass
- link-name: 0 of 1 pass
- button-name: n/a · no buttons on the page
- control-label: n/a · no form fields on the page
- frame-title: n/a · no frames on the page
- autoplay: n/a · no audio or video on the page
- unique-ids: 1 of 1 pass
- ai-disclosure: n/a · no conversational widget detected
- image-weight: 2 of 2 pass
- image-format: 2 of 2 pass

## Footprint

- 12 elements · 3 requests · 2 kB transferred · 0 third-party hosts
