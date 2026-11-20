/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

import { Dialog } from './Dialog'

/** Replaces the band. Two outlined buttons, the null option first, no primary:
 *  the surface never pushes a reader toward leaving. */
export function Fork({ onClose, onStop }: { onClose: () => void; onStop: () => void }) {
  return (
    <Dialog title="Stop" className="fork" onClose={onClose}>
      <p className="fork-line">
        Stopping today: no further charges. €6.00 returned for 18 unused days. Everything stays
        readable and exportable until 14 March 2028.
      </p>
      <div className="fork-actions">
        <button type="button" onClick={onClose}>
          Keep reading
        </button>
        <button type="button" onClick={onStop}>
          Stop and keep the record
        </button>
      </div>
    </Dialog>
  )
}
