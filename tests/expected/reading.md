# Relevé · http://localhost:8765/reading.html

Observation `5608a4d2` · 2026-10-11T17:42:15+00:00 · criteria v4 · screenshot `b99cd51906b48b4a` · Chromium 141.0.7390.37  
54 surfaces · 5 fail · 0 review · 0 hint · 69 pass · first observation of this page

Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement.
To correct a line, change its verdict word or add a note after `//`, then run `releve correct`.

## Fail (5)

- **FAIL** image-alt · `#main > img` · no alt attribute → add alt; alt="" if the image is decorative {2df2dc8e}
- **FAIL** text-contrast · `#main > ul:nth-of-type(2) > li.pale:nth-of-type(1)` · #aaaaaa on #ffffff · 2.32:1, needs 4.50:1 · “Pale one” → use #767676 {df9f5b37}
- **FAIL** text-contrast · `#main > ul:nth-of-type(2) > li.pale:nth-of-type(2)` · #aaaaaa on #ffffff · 2.32:1, needs 4.50:1 · “Pale two” → use #767676 {e498e6a9}
- **FAIL** text-contrast · `#main > ul:nth-of-type(2) > li.pale:nth-of-type(3)` · #aaaaaa on #ffffff · 2.32:1, needs 4.50:1 · “Pale three” → use #767676 {53a7a049}
- **FAIL** text-contrast · `#main > ul:nth-of-type(2) > li.pale:nth-of-type(4)` · #aaaaaa on #ffffff · 2.32:1, needs 4.50:1 · “Pale four” → use #767676 {f4432bf5}

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
- image-alt: 1 of 2 pass
- text-contrast: 31 of 35 pass
- link-name: 4 of 4 pass
- link-distinct: 1 of 1 pass
- button-name: 1 of 1 pass
- label-in-name: n/a · no name given by the code over a visible label
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

## Footprint

- 69 elements · 2 requests · 4 kB transferred · 0 third-party hosts

## Reading

- 39 events · 1 shown and not said · 1 said and not shown
- depth 8: the longest run the markup obliges
- the page says 189 bytes; 24 bytes travel for each
- one at a time, by ear: 38 steps
- up to 4 at a time: 16 steps as the page stands · 13 with nothing failing (between 10 and 15 at this depth and size)
- mending text-contrast alone gives back 3 steps
