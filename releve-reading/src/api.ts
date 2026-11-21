/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

/**
 * What the surface needs from the service, and nothing else.
 *
 * The service today answers a posted address with an HTML report of the same nine
 * judgments, and the only JSON it emits is the receipt that replays the observation
 * bundle — not the reading. So the seam is declared here, its one implementation is
 * the fixtures, and the components read `source`. When the service grows a JSON view
 * of the findings, its shape lands in this file and nowhere else.
 */
import { PANELS, PRICE } from './fixtures'
import type { Panel } from './fixtures'

export type Reading = {
  /** the page that was read, as the reader typed it */
  url: string
  /** absolute, to the minute: a reading without a date is an opinion */
  observedAt: string
  price: string
  findings: readonly Panel[]
}

export type ReadingSource = {
  read: () => Reading
}

export const source: ReadingSource = {
  read: () => ({
    url: 'example.org/',
    observedAt: '21 November 2026, 10:42',
    price: PRICE,
    findings: PANELS,
  }),
}
