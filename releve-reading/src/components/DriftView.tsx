/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

import { useState } from 'react'
import { DRIFT } from '../fixtures'

const GLYPH = { stable: '—', drift: '▲', blocking: '■' } as const

/** Station 04. Twelve readings as ticks. A static audit expires; this is the
 *  record of what changed after it was filed. */
export function DriftView() {
  const [active, setActive] = useState(DRIFT.length - 1)

  return (
    <div className="station-view" data-station="drift">
      <h2 tabIndex={-1}>Drift</h2>
      <p className="thesis">Compliance is not a state; it is a rate of drift.</p>

      <div className="ticks" role="group" aria-label="Twelve monthly readings">
        {DRIFT.map((entry, i) => (
          <button
            key={entry.label + i}
            type="button"
            className="tick"
            data-state={entry.state}
            aria-current={i === active ? 'true' : undefined}
            aria-label={`${entry.label}: ${entry.note}`}
            onClick={() => setActive(i)}
          >
            <span aria-hidden="true">{GLYPH[entry.state]}</span>
            <span className="tick-label">{entry.label}</span>
          </button>
        ))}
      </div>

      <div className="diff" style={{ marginTop: '2rem' }}>
        <p>Baseline recorded 21 Nov 2026. Monthly shifts appear here.</p>
      </div>
    </div>
  )
}
