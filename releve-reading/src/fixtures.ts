/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

// One finding per constraint class. The copy keeps the shape the brief asks for:
// a class, the component it hits, the rule that makes it bite, the exact place, the
// witness, and the remedy. No number here is scored or averaged.

export type Variant = 'blocking' | 'passing'

export type Panel = {
  ordinal: string
  variant: Variant
  /** the rule family that makes this a defect: RGAA 5, RGESN, AI Act 50, GDPR 13 */
  defectClass: string
  component: string
  trigger: string
  /** selector, DOM path, or byte count — where a developer goes */
  locator: string
  /** the falsifying payload, kept short enough to read at a glance */
  snippet: string
  remediation: string
}

export const PRICE_EUR = 10
export const PRICE = `€${PRICE_EUR.toFixed(2)}`

export const PANELS: readonly Panel[] = [
  {
    ordinal: '01',
    variant: 'blocking',
    defectClass: 'Digital sobriety',
    component: 'Third-party requests',
    trigger: 'Consent bypass · RGESN',
    locator: '4 requests fire before the consent prompt',
    snippet: 'GET https://analytics.example.com/collect\nGET https://ads.example.com/pixel',
    remediation: 'Hold every request until the visitor answers the consent prompt.',
  },
  {
    ordinal: '02',
    variant: 'blocking',
    defectClass: 'Dark pattern',
    component: 'Consent banner',
    trigger: 'Asymmetric cost',
    locator: 'div#cookie-banner button.accept vs a.settings',
    snippet: '<button class="accept">Accept all</button>\n<a href="/settings">Manage</a>',
    remediation: 'Put refuse beside accept, at the same size, in one step.',
  },
  {
    ordinal: '03',
    variant: 'blocking',
    defectClass: 'Accessibility',
    component: 'Body text',
    trigger: 'RGAA 5 · WCAG 1.4.3 contrast',
    locator: 'p.lead (colour #6d6459 on #fbf9f4) — 2.9:1',
    snippet: 'measured 2.9:1\nrequired 4.5:1',
    remediation: 'Darken the text colour until it reaches 4.5 to 1 against the page behind it.',
  },
  {
    ordinal: '04',
    variant: 'blocking',
    defectClass: 'Accessibility · machine legibility',
    component: 'Images',
    trigger: 'RGAA 5 · no description',
    locator: '14 of 22 <img> nodes carry no alt',
    snippet: '<img src="/assets/hero-banner.jpg">\n<img src="/assets/logo-partner.png">',
    remediation: 'Write one line per image saying what it shows.',
  },
  {
    ordinal: '05',
    variant: 'blocking',
    defectClass: 'Accessibility',
    component: 'Overlay widget (surcouche)',
    trigger: 'RGAA 5 · Arcom enforcement',
    locator: 'script[src*="accessibe"]',
    snippet: '<script src="https://acsbapp.com/apps/app/dist/js/app.js"></script>',
    remediation: 'Remove the overlay and fix the underlying semantics: an overlay cannot repair a DOM.',
  },
  {
    ordinal: '06',
    variant: 'blocking',
    defectClass: 'AI transparency',
    component: 'Chat widget',
    trigger: 'AI Act Art. 50(5) · since 2 Aug 2026',
    locator: 'iframe#intercom-widget — no disclosure node',
    snippet: '<iframe src="https://chat.example.com/widget" title="Chat"></iframe>',
    remediation: 'Say a machine answers, on the widget itself, before the first reply.',
  },
  {
    ordinal: '07',
    variant: 'blocking',
    defectClass: 'Privacy',
    component: 'Transfer notice',
    trigger: 'GDPR Art. 13',
    locator: 'div.privacy-summary',
    snippet: 'We share data with our trusted partners to improve your experience.',
    remediation: 'Name the seven companies that receive the data in the notice itself.',
  },
  {
    ordinal: '08',
    variant: 'passing',
    defectClass: 'Digital sobriety',
    component: 'DOM depth',
    trigger: 'Structural bloat',
    locator: 'deepest node: 12 levels (ceiling 32)',
    snippet: '<body><main><article>…</article></main></body>',
    remediation: 'Nothing to do. The depth held at 12 on this reading.',
  },
  {
    ordinal: '09',
    variant: 'blocking',
    defectClass: 'Compliance',
    component: 'Accessibility statement',
    trigger: 'EU directive 2016/2102 · since 28 Jun 2025',
    locator: 'footer a[href*="accessibility"] — not found',
    snippet: '/* selector matched no node */',
    remediation: 'Publish one: what works, what fails, whom to write to.',
  },
]

export const SESSION = {
  seenBy: 'no one yet',
  price: PRICE,
  paidThrough: '20 December 2026',
  nextCharge: '21 December 2026',
}
