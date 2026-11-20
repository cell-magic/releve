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

Panels are `min(42rem, 90vw)` wide with a 1px hairline on their right, so two
columns are visible at 1440 and the strip keeps showing where it is — it never
reads as a tunnel. Below 640px the axis becomes a column and the page scrolls,
as the report shell does.

The gloss is the panel's own footnote at every width: 13px mono in `--quiet`,
under the fix, numbered with a sup. There is no rail that swaps it.

The top rail carries `first · prev · next`, the index of nine numbers (the
current one underlined, `aria-current`), then the plate and the two views. Above
1100px the index carries the position and the `04 / 09` counter is hidden; below
it the index hides and the counter returns. A vertical wheel turns the axis,
unless the panel under the pointer scrolls first — the report shell's behaviour,
transposed.

## Routes

`/read/:id` the strip · `/plate/:id` the plate overlay · `/stop/:id` the fork ·
`/record` the account's own log · `/help` who answers, and the Count.
`src/router.ts` parses them in twenty lines; overlays are routes, so Escape and
the back button close them the same way.

`src/state.ts` is the session machine: `active`, `dormant`, `left`. Stop writes a
receipt on the colophon (`14 March 2026, 10:42 · Stopped. €6.00 returned for 18
unused days.` + Undo); Undo reverses the stop and its refund. Dormant is the same
line minus the controls that would create something, never greyed.

## Tools

```sh
python tools/shoot.py http://localhost:4173/ shots reading   # screenshots + acceptance metrics
python tools/walk.py  http://localhost:4173/                 # 22 flow checks, real events
python tools/sample.py shots/reading-light.png               # dominant colours, 3-bit buckets
```

`walk.py` is the one that matters: it drives the built app with dispatched keys
and clicks and asserts focus lands on close, Tab is trapped in the plate and the
fork only, Escape returns focus, a stop writes its receipt, Undo reverses it, and
the record and count render.

## Data

`src/fixtures.ts` holds the nine panels and the session. Every string is
provisional. The only product constant is `PRICE_EUR = 10`; there is no
per-finding price anywhere, and there must not be.
