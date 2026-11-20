/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

// Placeholder throughout: the record, the count and the plate carry the shape of
// what the surface says, not its final wording. One price exists: PRICE_EUR.

export type SessionState = 'active' | 'dormant' | 'left'

export type Receipt = {
  id: number
  at: string
  fact: string
  undo: boolean
}

export type RecordRow = { at: string; fact: string }

export type State = {
  session: SessionState
  receipts: Receipt[]
  record: RecordRow[]
  /** true once the plate has left the private area: the stamp appears then */
  sent: boolean
}

export type Action =
  | { type: 'stop' }
  | { type: 'undo'; id: number }
  | { type: 'dormant' }
  | { type: 'resume' }
  | { type: 'send' }

export const NOW = '14 March 2026, 10:42'

/** The plate's seven rows, in fixed order: scope, jurisdiction, composition,
 *  undeclared, closed, record, handling. */
export const PLATE_ROWS: readonly (readonly [string, string])[] = [
  ['scope', 'This page, at the moment it was read. One page, not a sample.'],
  ['jurisdiction', 'France. EU law where it applies to a page that sells.'],
  ['composition', 'One observer and one rule set. No model takes part in the reading.'],
  ['undeclared', '2 of 9 findings cannot be closed by a rule: they name what a notice must say.'],
  ['closed', 'Nothing. No cookie, no account and no request log were kept.'],
  ['record', 'Kept 24 months after the account ends, then deleted with the export open.'],
  ['handling', 'No visitor data leaves the observation. The page is read as a visitor sees it.'],
] as const

/** The service's own figures. Unmeasured figures are omitted, never estimated. */
export const COUNT_ROWS: readonly (readonly [string, string])[] = [
  ['Median account age', '7 months'],
  ['Accounts ever dormant', '38%'],
  ['Of those, resumed', '61%'],
  ['Stopped within three periods', '29%'],
  ['Median time to a human reply', '4 hours'],
] as const

export const COUNT_NOTE = 'The service’s own figures, 3,140 accounts. Unmeasured figures omitted.'
