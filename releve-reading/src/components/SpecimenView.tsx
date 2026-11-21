/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

import { useState } from 'react'
import { SPECIMEN } from '../fixtures'
import type { Panel } from '../fixtures'
import { buildReceipt, copyText } from '../export'

/** Station 02. The verdict is the first thing on the surface: state, count,
 *  time, hash. The class follows, then the three cells, then the stub. */
export function SpecimenView({
  findings,
  url,
  observedAt,
}: {
  findings: readonly Panel[]
  url: string
  observedAt: string
}) {
  const blocking = findings.filter((f) => f.variant === 'blocking')
  const [copied, setCopied] = useState<'idle' | 'yes' | 'no'>('idle')

  return (
    <div className="station-view" data-station="specimen">
      <h2 tabIndex={-1}>Specimen</h2>

      <dl className="verdict">
        <div>
          <dt>State</dt>
          <dd>
            <span className="glyph" aria-hidden="true">■</span> {blocking.length} blocking
          </dd>
        </div>
        <div>
          <dt>Snapshot</dt>
          <dd className="mono">sha256:{SPECIMEN.hash}</dd>
        </div>
      </dl>

      <section className="archetype" aria-labelledby="archetype-name">
        <p className="label">Class</p>
        <h3 id="archetype-name">{SPECIMEN.archetype.name}</h3>
        <p className="archetype-line">{SPECIMEN.archetype.line}</p>
        <details className="rules">
          <summary>Rule table</summary>
          <table>
            <thead>
              <tr>
                <th scope="col">Class</th>
                <th scope="col">Fires when</th>
              </tr>
            </thead>
            <tbody>
              {SPECIMEN.rules.map(([name, rule]) => (
                <tr key={name}>
                  <td>{name}</td>
                  <td className="mono">{rule}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </details>
      </section>

      <dl className="ledger">
        <div>
          <dt>Law — RGAA 5 / Art. 50</dt>
          <dd>
            {blocking.length} blocking. <span className="boundary">{SPECIMEN.boundary}</span>
          </dd>
        </div>
        <div>
          <dt>Energy — RGESN / weight</dt>
          <dd className="mono">
            {SPECIMEN.energy.bytes} · {SPECIMEN.energy.nodes} nodes · {SPECIMEN.energy.scripts}{' '}
            third-party scripts · {SPECIMEN.energy.delta}
          </dd>
        </div>
        <div>
          <dt>Perception — machine legibility</dt>
          <dd>
            {SPECIMEN.perception.overlays} · {SPECIMEN.perception.landmarks} ·{' '}
            {SPECIMEN.perception.targets}
          </dd>
        </div>
      </dl>

      <button
        type="button"
        className="action"
        onClick={async () => {
          const ok = await copyText(
            buildReceipt(findings, url, observedAt, SPECIMEN.hash, SPECIMEN.archetype.name),
          )
          setCopied(ok ? 'yes' : 'no')
        }}
      >
        {copied === 'yes' ? 'Receipt copied' : copied === 'no' ? 'Copy blocked by the browser' : 'Copy receipt'}
      </button>
    </div>
  )
}
