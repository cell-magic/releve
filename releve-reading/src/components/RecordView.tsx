/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

import { SESSION } from '../fixtures'
import type { State } from '../types'

export function RecordView({ state }: { state: State }) {
  const left = state.session === 'left'
  return (
    <div className="station-view">
      <h1>Record</h1>
      <p className="view-note">Seen by: {SESSION.seenBy}</p>
      <p className="view-note">Read again on the 1st. Next reading: 1 December 2026.</p>

      <table className="table record">
        <tbody>
          {state.record.map((row) => (
            <tr key={row.at + row.fact}>
              <th scope="row">{row.at}</th>
              <td>{row.fact}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <p className="view-note">
        {left
          ? 'Frozen. Kept and exportable until 21 November 2028.'
          : 'Export always open, in open formats.'}
      </p>
    </div>
  )
}
