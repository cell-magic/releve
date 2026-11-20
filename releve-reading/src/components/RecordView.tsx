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
          ? 'Frozen. Export open until 14 March 2028; nothing is deleted before then.'
          : 'Export always open, in open formats.'}
      </p>
    </div>
  )
}
