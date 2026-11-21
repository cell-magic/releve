/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

import { useCallback, useEffect, useState } from 'react'

export type Station = 'probe' | 'specimen' | 'witness' | 'drift' | 'radar'
export const STATIONS: readonly Station[] = ['probe', 'specimen', 'witness', 'drift', 'radar']
export const STATION_NAMES: Record<Station, string> = {
  probe: 'Probe',
  specimen: 'Specimen',
  witness: 'Witness',
  drift: 'Drift',
  radar: 'Radar',
}

export type Overlay = 'none' | 'plate' | 'fork' | 'record' | 'help'
export type Route = { station: Station; overlay: Overlay }

const isStation = (s: string | undefined): s is Station => STATIONS.includes(s as Station)

/** the URL word for each sheet, so /radar/stop reads like the control it came from */
const WORD: Partial<Record<string, Overlay>> = {
  plate: 'plate',
  stop: 'fork',
  fork: 'fork',
  record: 'record',
  help: 'help',
}
const overlayFor = (s: string | undefined): Overlay => (s && WORD[s]) || 'none'

/** /probe · /specimen · /witness · /drift · /radar, and /<station>/<overlay> for
 *  the four dialogs, so a shared link keeps both the seat and the open sheet. */
/** the surface lives at /reading/ on the report host; every path is relative to it */
export const BASE = ''

const strip = (path: string) =>
  path.startsWith(BASE) ? path.slice(BASE.length) || '/' : path

export function parse(path: string): Route {
  const parts = strip(path).split('/').filter(Boolean)
  const [a, b] = parts
  if (isStation(a)) return { station: a, overlay: overlayFor(b) }
  if (a && WORD[a]) return { station: 'probe', overlay: overlayFor(a) }
  return { station: 'probe', overlay: 'none' }
}

export function useRoute() {
  const [route, setRoute] = useState<Route>(() => parse(window.location.pathname))

  const navigate = useCallback((path: string) => {
    const target = BASE + path
    try {
      if (target !== window.location.pathname) window.history.pushState({}, '', target)
    } catch {
      // a viewing copy opened over file:// cannot write history; the ring still turns
    }
    setRoute(parse(path))
  }, [])

  useEffect(() => {
    const onPop = () => setRoute(parse(window.location.pathname))
    window.addEventListener('popstate', onPop)
    return () => window.removeEventListener('popstate', onPop)
  }, [])

  return { route, navigate }
}
