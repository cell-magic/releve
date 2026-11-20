/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

import { SESSION } from '../fixtures'
import type { Receipt, SessionState } from '../types'

/** The colophon. Its first segment is the state, and the state is also the way
 *  into the fork — the surface has no separate leaving control. */
export function StandingLine({
  session,
  receipts,
  onOpenFork,
  onDormant,
  onResume,
  onExport,
  onUndo,
}: {
  session: SessionState
  receipts: Receipt[]
  onOpenFork: () => void
  onDormant: () => void
  onResume: () => void
  onExport: () => void
  onUndo: (id: number) => void
}) {
  return (
    <div className="line">
      <div className="left">
        <div className="segs">
          <span className="seg">
            <button type="button" className="state" onClick={onOpenFork}>
              {session}
            </button>
            <span className="sep" aria-hidden="true">
              {' · '}
            </span>
          </span>
          <span className="seg tone-cost">
            {SESSION.price}
            <span className="sep" aria-hidden="true">
              {' · '}
            </span>
          </span>
          <span className="seg">
            paid through {SESSION.paidThrough}
            <span className="sep" aria-hidden="true">
              {' · '}
            </span>
          </span>
          <span className="seg">next charge {SESSION.nextCharge}</span>
        </div>

        {receipts.map((receipt) => (
          <p className="receipt" key={receipt.id}>
            {receipt.at} · {receipt.fact}{' '}
            {receipt.undo && (
              <button type="button" className="undo" onClick={() => onUndo(receipt.id)}>
                Undo
              </button>
            )}
          </p>
        ))}
      </div>

      <div className="acts">
        <span className="act">
          <button type="button" onClick={onExport}>
            Export all
          </button>
          <span className="sep" aria-hidden="true">
            {' · '}
          </span>
        </span>
        <span className="act">
          {session === 'active' ? (
            <button type="button" onClick={onDormant}>
              Go dormant
            </button>
          ) : (
            <button type="button" onClick={onResume}>
              Resume
            </button>
          )}
          {session === 'active' && (
            <span className="sep" aria-hidden="true">
              {' · '}
            </span>
          )}
        </span>
        {session === 'active' && (
          <span className="act">
            <button type="button" className="stop" onClick={onOpenFork}>
              Stop
            </button>
          </span>
        )}
      </div>
    </div>
  )
}
