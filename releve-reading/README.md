# releve-reading

The reading surface: nine horizontal panels, one finding each, read left to right.
The report shell is a separate surface; this is the thing a visitor opens after a
page has been observed.

Stack: React + TypeScript + Vite, one stylesheet, no component library, no router,
no animation, no icons. Fonts are self-hosted woff2 (Archivo 400/500/600, IBM Plex
Mono 400/600, latin subset) via `@fontsource`, imported in `src/main.tsx`.

```sh
npm install
npm run dev        # http://localhost:5173
npm run build      # tsc --noEmit && vite build
npm run preview    # http://localhost:4173, serves dist/
python tools/shoot.py http://localhost:4173/ shots reading
```

Budget: total JS is ~72 kB gzipped against a 120 kB ceiling.

## Two palettes, neither derived from the other

`src/styles.css` opens with the light block and then the dark block inside
`@media (prefers-color-scheme: dark)`. Light is a printed page: paper, ink, one
hue, no accents. Dark is the same stock under a desk lamp: warm ground, lifted
accents, hairlines that are felt rather than seen. Nothing in dark is an inverse
of a light value.

Weight is role-based, not theme-based: exactly two 2px rules per screen, at the
masthead and the colophon. Everything else is a 1px hairline. Structural rules
take `--rule` in dark and `--ink` in light.

## Layout regimes

| Width / height | Where the gloss lives |
|---|---|
| ≥1100px | margin column, with `Seen by` above 1281px |
| 561–1099px, normal height | the gloss rail under the band |
| max-height 400px, or ≤560 wide and ≤520 tall | inline footnote under the fix; document scrolls, no rail |

Panel width is `calc(100% - 66px)` (44px under 400px wide) so the next panel's
ordinal is the peek. The ordinal sits at the left of its own gutter, so the same
element is legible on the current panel and on the one peeking in.

## Data

`src/fixtures.ts` holds the nine panels and the session. Every string is
provisional. The only product constant is `PRICE_EUR = 10`; there is no
per-finding price anywhere, and there must not be.
