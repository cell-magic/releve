/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

import { useCallback, useEffect, useState } from 'react'

export type View = 'read' | 'record' | 'help'
export type Overlay = 'none' | 'plate' | 'fork'
export type Route = { view: View; overlay: Overlay }

/** /read/:id · /plate/:id · /stop/:id · /record · /help, parsed, no router library. */
export function parse(path: string): Route {
  const [head] = path.split('/').filter(Boolean)
  switch (head) {
    case 'record':
      return { view: 'record', overlay: 'none' }
    case 'help':
      return { view: 'help', overlay: 'none' }
    case 'plate':
      return { view: 'read', overlay: 'plate' }
    case 'stop':
      return { view: 'read', overlay: 'fork' }
    default:
      return { view: 'read', overlay: 'none' }
  }
}

export function useRoute() {
  const [route, setRoute] = useState<Route>(() => parse(window.location.pathname))

  const navigate = useCallback((path: string) => {
    if (path !== window.location.pathname) window.history.pushState({}, '', path)
    setRoute(parse(path))
  }, [])

  useEffect(() => {
    const onPop = () => setRoute(parse(window.location.pathname))
    window.addEventListener('popstate', onPop)
    return () => window.removeEventListener('popstate', onPop)
  }, [])

  return { route, navigate }
}
