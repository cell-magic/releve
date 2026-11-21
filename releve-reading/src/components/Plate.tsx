/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

import { PLATE_ROWS, type State } from '../types'
import { Dialog } from './Dialog'

/** The outward surface: a white sheet in either scheme, light values pinned
 *  inside it. The stamp exists only once the plate has left the private area. */
export function Plate({
  state,
  onClose,
  onSend,
}: {
  state: State
  onClose: () => void
  onSend: () => void
}) {
  return (
    <Dialog title="Plate" className="plate" onClose={onClose}>
      <dl className="plate-dl">
        {PLATE_ROWS.map(([term, value]) => (
          <div className="plate-row" key={term}>
            <dt>{term}</dt>
            <dd>{value}</dd>
          </div>
        ))}
      </dl>

      {state.sent && (
        <p className="stamp">
          <span>observed 21 November 2026, 10:42</span>
          <span>left the private area</span>
        </p>
      )}

      <div className="dialog-actions">
        <button type="button" onClick={onSend} disabled={state.sent}>
          {state.sent ? 'Exported' : 'Export'}
        </button>
      </div>
    </Dialog>
  )
}
