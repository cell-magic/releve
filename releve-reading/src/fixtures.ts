/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

// Placeholder data. Every string here is provisional: the copy in the brief is a
// shape (state + amount + absolute date + consequence), not a script. The one
// product constant the Bureau emits is PRICE_EUR. No per-finding money exists.

export type Variant = 'found' | 'missing' | 'absent'

export type Panel = {
  ordinal: string
  variant: Variant
  statement: string
  consequence: string
  fix: string
  /** at most 58 characters — two lines of 12px mono at 320px wide */
  gloss: string
}

export const PRICE_EUR = 10

export const PRICE = `€${PRICE_EUR.toFixed(2)}`

export const PANELS: readonly Panel[] = [
  {
    ordinal: '01',
    variant: 'found',
    statement: '4 trackers start before the visitor has agreed to anything.',
    consequence: 'Each request leaves before the page has asked.',
    fix: 'Hold every request until the visitor answers.',
    gloss: 'A tracker is a script that reports the visitor elsewhere.',
  },
  {
    ordinal: '02',
    variant: 'found',
    statement: 'Refusing cookies takes 3 clicks and accepting takes 1.',
    consequence: 'The easy path is the one that leaves with data.',
    fix: 'Put refuse beside accept, at the same size, in one step.',
    gloss: 'Consent is a choice made before anything runs, not after.',
  },
  {
    ordinal: '03',
    variant: 'found',
    statement:
      'Body text has a contrast of 2.9 to 1 against the page, and 4.5 to 1 is the floor.',
    consequence: 'A reader with low vision cannot read the paragraphs.',
    fix: 'Darken the text colour until it reaches 4.5 to 1.',
    gloss: 'Contrast is measured against the page behind the text.',
  },
  {
    ordinal: '04',
    variant: 'missing',
    statement: '14 of 22 images carry no description.',
    consequence: 'A screen reader announces each one as "image".',
    fix: 'Write one line per image saying what it shows.',
    gloss: 'Alt text says what an image shows, in one line.',
  },
  {
    ordinal: '05',
    variant: 'found',
    statement: 'The menu opens with a mouse and with nothing else.',
    consequence: 'A visitor without a mouse cannot reach any other page.',
    fix: 'Let the Enter key open it, and mark where the focus is.',
    gloss: 'Focus is where the keyboard is; it must be visible.',
  },
  {
    ordinal: '06',
    variant: 'missing',
    statement: '3 fields in the contact form have no name that software can read aloud.',
    consequence: 'The form is filled blind, one guess at a time.',
    fix: 'Tie each visible label to its field so it is spoken.',
    gloss: 'A label is the name software reads aloud for a field.',
  },
  {
    ordinal: '07',
    variant: 'found',
    statement:
      'The page sends visitor data to 7 other domains. The privacy notice is 1,400 words and names none of them.',
    consequence: 'A reader cannot consent to a transfer the notice never mentions.',
    fix: 'Name all 7 in the notice, or stop sending to the other 5.',
    gloss: 'A recipient is a domain that receives visitor data.',
  },
  {
    ordinal: '08',
    variant: 'absent',
    statement:
      'The chat window sends each message to 1 domain before it answers, and no line on the page says a machine replies.',
    consequence: 'From 2 August 2026 EU law applies to that conversation.',
    fix: 'Open the chat with one line: a machine is answering.',
    gloss: 'A disclosure is the line that says a machine replies.',
  },
  {
    ordinal: '09',
    variant: 'absent',
    statement:
      'No accessibility statement exists, and since 28 June 2025 EU law expects one from most pages that sell to consumers.',
    consequence: 'A reader who cannot use the page has nowhere to write.',
    fix: 'Publish one: what works, what fails, whom to write to.',
    gloss: 'A statement says what works, what fails, whom to write to.',
  },
]

export type SessionState = 'active' | 'dormant' | 'left'

export const SESSION: {
  state: SessionState
  price: string
  paidThrough: string
  nextCharge: string
  seenBy: string
} = {
  state: 'active',
  price: PRICE,
  paidThrough: '14 April 2026',
  nextCharge: '14 April 2026',
  seenBy: 'no one yet',
}
