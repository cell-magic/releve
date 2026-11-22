/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

import { useState } from 'react'
import { PRICE } from '../fixtures'

/** Station 05. One strip, no columns, no tiers. The four invariants sit above
 *  the button where a reader can check them before committing. */
export function RadarView({ url, onWrap }: { url: string; onWrap: () => void }) {
  const [target, setTarget] = useState(url)
  const [email, setEmail] = useState('')
  const [state, setState] = useState<'idle' | 'closed'>('idle')

  return (
    <div className="station-view" data-station="radar">
      <h2 tabIndex={-1}>Radar</h2>

      {/* TODO: wire POST /radar — no billing endpoint is mounted in this build */}
      <form
        className="radar-form"
        onSubmit={(event) => {
          event.preventDefault()
          setState('closed')
        }}
      >
        <label htmlFor="radar-url">Public URL</label>
        <input
          id="radar-url"
          type="text"
          inputMode="url"
          value={target}
          onChange={(event) => setTarget(event.target.value)}
          spellCheck={false}
        />
        <label htmlFor="radar-email">Delivery email</label>
        <input
          id="radar-email"
          type="email"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          autoComplete="email"
        />
        <div className="radar-actions">
          <button type="submit" className="action">
            Activate radar — {PRICE}/mo
          </button>
          <button type="submit" className="action quiet">
            Arm free 30-day check
          </button>
        </div>
      </form>



      {state === 'closed' && (
        <p className="scope-line">
          No billing endpoint is mounted in this build. Nothing was sent.
        </p>
      )}

      <p className="wrap-cue">
        <button type="button" className="link" onClick={onWrap}>
          Next — probe another
        </button>
      </p>
    </div>
  )
}
