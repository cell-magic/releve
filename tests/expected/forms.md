# Relevé · http://localhost:8765/forms.html

Observation `63444cd1` · 2026-10-11T17:42:00+00:00 · criteria v5 · screenshot `82dd9fc6e34bafbe` · Chromium 141.0.7390.37  
41 surfaces · 2 fail · 3 review · 0 hint · 62 pass · first observation of this page

Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement.
To correct a line, change its verdict word or add a note after `//`, then run `releve correct`.

## Fail (2)

- **FAIL** group-legend · `body > main > form > fieldset:nth-of-type(2)` · group of fields without a legend → add a \<legend>, or aria-label on the group {379bc0bb}
- **FAIL** autocomplete · `#c` · autocomplete="e-mail" is not a purpose a field can declare → use autocomplete="email" {415dfbc6}

## Review (3)

- **REVIEW** field-group · `body > main > form > p:nth-of-type(1) > label:nth-of-type(1) > input` · 3 radio buttons named “colour” stand outside any group → wrap them in a \<fieldset> with a \<legend> {7c106751}
- **REVIEW** autocomplete · `#d` · the field “First name” declares no purpose → if it asks for the visitor's own data, add autocomplete="given-name" {aaa7d0b5}
- **REVIEW** autocomplete · `#e` · the field “Number to call” declares no purpose → if it asks for the visitor's own data, add autocomplete="tel" {06a56abe}

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
- image-alt: n/a · no images on the page
- text-contrast: 19 of 19 pass
- link-name: n/a · no links on the page
- link-distinct: n/a · no links on the page
- button-name: 1 of 1 pass
- label-in-name: n/a · no name given by the code over words shown
- control-label: 16 of 16 pass
- group-legend: 2 of 3 pass
- field-group: 3 of 4 pass
- autocomplete: 2 of 5 pass
- table-headers: n/a · no tables on the page
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
- image-weight: n/a · no bitmap images on the page
- image-format: n/a · no weighed images on the page

## Footprint

- 55 elements · 1 request · 3 kB transferred · 0 third-party hosts

## Reading

- 30 events · 0 shown and not said · 0 said and not shown
- depth 4: the longest run the markup obliges
- the page says 114 bytes; 26 bytes travel for each
- one at a time, by ear: 30 steps
- up to 4 at a time: 10 steps as the page stands · 10 with nothing failing (between 8 and 10 at this depth and size)
