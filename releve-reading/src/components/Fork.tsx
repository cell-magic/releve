/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

import { Dialog } from './Dialog'

/** Replaces the band. Two outlined buttons, the null option first, no primary:
 *  the surface never pushes a reader toward leaving. */
export function Fork({ onClose, onStop }: { onClose: () => void; onStop: () => void }) {
  return (
    <Dialog title="Stop" className="fork" onClose={onClose}>
      <p className="fork-line">
        RADAR stops reading this page. Nothing further is charged — the period already paid for runs
        to 20 December 2026 and is not refunded — and the record stays readable and exportable until
        21 November 2028.
      </p>
      <div className="fork-actions">
        <button type="button" onClick={onClose}>
          Keep reading
        </button>
        <button type="button" onClick={onStop}>
          End the subscription
        </button>
      </div>
    </Dialog>
  )
}
