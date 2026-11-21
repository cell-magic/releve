/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

import { useState } from 'react'

/** Station 01. One field, one button, and the specimen presets that get a
 *  first-time visitor into a reading without typing. */
export function ProbeView({ onSubmit }: { onSubmit: (url: string) => void }) {
  const [url, setUrl] = useState('')
  const presets = [
    ['Nothing Flagged', 'works without a mouse'],
    ['The Corner Button', 'sits over errors it does not fix'],
    ['The 4 MB Front Page', 'loads megabytes of background code'],
  ]
  return (
    <div className="station-view" data-station="probe">
      <h2 tabIndex={-1}>Probe</h2>
      {/* TODO: wire POST /probe — no probe endpoint is mounted in this build */}
      <form
        className="probe-form"
        onSubmit={(event) => {
          event.preventDefault()
          onSubmit(url)
        }}
      >
        <label className="sr-only" htmlFor="probe-url">
          Public URL
        </label>
        <input
          id="probe-url"
          type="text"
          inputMode="url"
          placeholder="example.fr"
          value={url}
          onChange={(event) => setUrl(event.target.value)}
          spellCheck={false}
          autoComplete="url"
        />
        <button type="submit">Run probe</button>
      </form>
      <p className="scope-line">
        Public URLs only. Nothing is saved once the tab closes. No AI runs anywhere in the check.
      </p>

      <p className="label">Specimens</p>
      <ul className="presets">
        {presets.map(([name, note]) => (
          <li key={name}>
            <button type="button" onClick={() => onSubmit('')}>
              <span className="preset-name">{name}</span>
              <span className="preset-note">{note}</span>
            </button>
          </li>
        ))}
      </ul>
    </div>
  )
}
