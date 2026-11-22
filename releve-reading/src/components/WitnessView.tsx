/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

import { useState } from 'react'
import { SPECIMEN } from '../fixtures'
import type { Panel } from '../fixtures'
import { buildBrief, copyText, downloadTicket } from '../export'

/** Station 03. Only blocking findings are open. Everything stable folds into
 *  one row at the bottom, so the page does not grow with the pass count. */
export function WitnessView({
  findings,
  url,
  observedAt,
}: {
  findings: readonly Panel[]
  url: string
  observedAt: string
}) {
  const blocking = findings.filter((f) => f.variant === 'blocking')
  const passing = findings.filter((f) => f.variant === 'passing')
  const [copied, setCopied] = useState<'idle' | 'yes' | 'no'>('idle')

  return (
    <div className="station-view" data-station="witness">
      <h2 tabIndex={-1}>Witness</h2>

      <div className="action-bar">
        <button
          type="button"
          className="action"
          onClick={async () => {
            const ok = await copyText(
              buildBrief(findings, url, observedAt, SPECIMEN.hash),
            )
            setCopied(ok ? 'yes' : 'no')
          }}
        >
          {copied === 'yes' ? 'Brief copied' : copied === 'no' ? 'Copy blocked by the browser' : 'Copy brief'}
        </button>
        {/* TODO: mount the WASM kernel at /reading/verifier.html, then this becomes a link */}
        <span className="action is-todo" data-todo="wasm-kernel" aria-disabled="true">
          Local verify — no kernel in this build
        </span>
      </div>

      <ol className="register">
        {blocking.map((panel) => (
          <li key={panel.ordinal} className="defect" data-variant={panel.variant}>
            <h3 className="defect-title">
              <span className="ord" aria-hidden="true">{panel.ordinal}</span>
              <span className="class">{panel.defectClass}</span> —{' '}
              <span className="comp">{panel.component}</span> —{' '}
              <span className="trig">{panel.trigger}</span>
            </h3>
            <p className="defect-locator">{panel.locator}</p>
            <details className="defect-evidence" open>
              <summary>Inspect witness</summary>
              <div className="ev-body">
                <pre><code>{panel.snippet.replace(/\\n/g, '\n')}</code></pre>
                <p className="remediation">{panel.remediation}</p>
                <button
                  type="button"
                  className="dev-ticket"
                  onClick={() => downloadTicket(panel, url, observedAt)}
                >
                  Export developer ticket
                </button>
              </div>
            </details>
          </li>
        ))}
      </ol>

      <details className="stable">
        <summary>{passing.length} deterministic check stable — expand register</summary>
        <ol className="register">
          {passing.map((panel) => (
            <li key={panel.ordinal} className="defect" data-variant={panel.variant}>
              <h3 className="defect-title">
                <span className="ord" aria-hidden="true">{panel.ordinal}</span>
                <span className="class">{panel.defectClass}</span> —{' '}
                <span className="comp">{panel.component}</span> —{' '}
                <span className="trig">{panel.trigger}</span>
              </h3>
              <p className="defect-locator">{panel.locator}</p>
            </li>
          ))}
        </ol>
      </details>


    </div>
  )
}
