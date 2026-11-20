/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

import { COUNT_NOTE, COUNT_ROWS } from '../types'

/** Who answers, and the service's own figures. A reading surface that hides its
 *  own numbers has no standing to report anyone else's. */
export function HelpView() {
  return (
    <main className="view">
      <h1>Who answers</h1>
      <p>
        One person reads the page and writes the finding. A rule set decides what counts as found;
        no model takes part in the reading. A reply comes within a working day.
      </p>

      <h2>Count</h2>
      <p className="view-note">{COUNT_NOTE}</p>
      <table className="table count">
        <tbody>
          {COUNT_ROWS.map(([key, value]) => (
            <tr key={key}>
              <th scope="row">{key}</th>
              <td className="num">{value}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </main>
  )
}
