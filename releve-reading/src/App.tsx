/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

import { useCallback, useEffect, useRef, useState } from 'react'
import { PANELS, SESSION } from './fixtures'
import { useSession } from './state'
import { useRoute } from './router'
import { Fork } from './components/Fork'
import { HelpView } from './components/HelpView'
import { Plate } from './components/Plate'
import { RecordView } from './components/RecordView'
import { StandingLine } from './components/StandingLine'

const TOTAL = PANELS.length

export default function App() {
  const band = useRef<HTMLOListElement>(null)
  const [index, setIndex] = useState(0)
  const { state, dispatch } = useSession()
  const { route, navigate } = useRoute()

  const { view, overlay } = route
  const reading = view === 'read'
  const trapped = overlay !== 'none'

  const go = useCallback((next: number) => {
    const el = band.current
    if (!el) return
    const clamped = Math.max(0, Math.min(TOTAL - 1, next))
    const panel = el.children[clamped] as HTMLElement | undefined
    if (!panel) return
    el.scrollTo({ left: panel.offsetLeft, behavior: 'instant' })
    setIndex(clamped)
  }, [])

  // settle: the strip is static after first paint, only the index moves
  useEffect(() => {
    const el = band.current
    if (!el) return
    let timer = 0
    const settle = () => {
      const first = el.children[0] as HTMLElement | undefined
      if (!first) return
      const width = first.offsetWidth || 1
      setIndex(Math.max(0, Math.min(TOTAL - 1, Math.round(el.scrollLeft / width))))
    }
    const onScroll = () => {
      window.clearTimeout(timer)
      timer = window.setTimeout(settle, 120)
    }
    el.addEventListener('scroll', onScroll, { passive: true })
    return () => {
      el.removeEventListener('scroll', onScroll)
      window.clearTimeout(timer)
    }
  }, [reading])

  // focus inside a panel wins over a stale snap position
  useEffect(() => {
    const el = band.current
    if (!el) return
    const onFocus = (event: FocusEvent) => {
      const panel = (event.target as HTMLElement | null)?.closest('.panel')
      if (!panel) return
      el.scrollLeft = (panel as HTMLElement).offsetLeft
    }
    el.addEventListener('focusin', onFocus)
    return () => el.removeEventListener('focusin', onFocus)
  }, [reading])

  // arrows and Home move one panel, and only outside overlays and inputs
  useEffect(() => {
    if (!reading || trapped) return
    const onKey = (event: KeyboardEvent) => {
      const active = document.activeElement
      const tag = active?.tagName ?? ''
      if (
        tag === 'INPUT' ||
        tag === 'TEXTAREA' ||
        tag === 'SELECT' ||
        (active as HTMLElement | null)?.isContentEditable
      )
        return
      if (event.key === 'ArrowRight') {
        event.preventDefault()
        go(index + 1)
      } else if (event.key === 'ArrowLeft') {
        event.preventDefault()
        go(index - 1)
      } else if (event.key === 'Home') {
        event.preventDefault()
        go(0)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [go, index, reading, trapped])

  const current = PANELS[index]
  const counter = `${current.ordinal} / ${String(TOTAL).padStart(2, '0')}`

  const closeOverlay = () => navigate('/read/1')
  const openPlate = () => navigate('/plate/1')
  const openFork = () => navigate('/stop/1')

  const onStop = () => {
    dispatch({ type: 'stop' })
    closeOverlay()
  }
  const onExport = () => {
    dispatch({ type: 'send' })
    openPlate()
  }

  return (
    <div className="app">
      <nav className="rail" aria-label="Position" data-count={counter}>
        {reading ? (
          <>
            <button className="first dir" type="button" onClick={() => go(0)}>
              first
            </button>
            <button
              className="dir"
              type="button"
              onClick={() => go(index - 1)}
              disabled={index === 0}
            >
              prev
            </button>
            <button
              className="dir"
              type="button"
              onClick={() => go(index + 1)}
              disabled={index === TOTAL - 1}
            >
              next
            </button>
            <span className="spacer" />
            {trapped ? (
              <>
                <span className="counter" aria-label={counter}>
                  {overlay}
                </span>
                <button type="button" onClick={closeOverlay}>
                  close
                </button>
              </>
            ) : (
              <>
                <span className="counter" aria-label={counter}>
                  {counter}
                </span>
                <button type="button" onClick={openPlate}>
                  plate
                </button>
              </>
            )}
          </>
        ) : (
          <>
            <button type="button" onClick={() => navigate('/read/1')}>
              back to reading
            </button>
            <span className="spacer" />
            <span className="counter">{view}</span>
          </>
        )}
        <button type="button" onClick={() => navigate('/help')}>
          who answers
        </button>
        <button type="button" onClick={() => navigate('/record')}>
          record
        </button>
      </nav>

      {reading ? (
        <>
          <ol className="band" ref={band}>
            {PANELS.map((panel, i) => (
              <li
                className="panel"
                key={panel.ordinal}
                aria-posinset={i + 1}
                aria-setsize={TOTAL}
                data-variant={panel.variant}
              >
                <span className="ordinal" aria-hidden="true">
                  {panel.ordinal}
                </span>
                <p className="head">
                  {panel.variant === 'absent' ? 'absent · risk' : panel.variant}
                  <span className="seenby-inline"> · seen by {SESSION.seenBy}</span>
                </p>
                <div className="panel-inner">
                  <div className="finding">
                    <p className="statement">{panel.statement}</p>
                    <p className="body">{panel.consequence}</p>
                    <p className="body">{panel.fix}</p>
                  </div>
                  <p className="gloss-src">
                    <sup>1</sup>
                    {panel.gloss}
                  </p>
                </div>
                <div className="margin-col">
                  <div className="seenby">Seen by: {SESSION.seenBy}</div>
                  <p className="foot">
                    <sup>1</sup>
                    {panel.gloss}
                  </p>
                </div>
              </li>
            ))}
          </ol>

          <div className="gloss" aria-hidden="true">
            {current.gloss}
          </div>
        </>
      ) : view === 'record' ? (
        <RecordView state={state} />
      ) : (
        <HelpView />
      )}

      <StandingLine
        session={state.session}
        receipts={state.receipts}
        onOpenFork={openFork}
        onDormant={() => dispatch({ type: 'dormant' })}
        onResume={() => dispatch({ type: 'resume' })}
        onExport={onExport}
        onUndo={(id) => dispatch({ type: 'undo', id })}
      />

      {overlay === 'plate' && (
        <Plate state={state} onClose={closeOverlay} onSend={() => dispatch({ type: 'send' })} />
      )}
      {overlay === 'fork' && <Fork onClose={closeOverlay} onStop={onStop} />}
    </div>
  )
}
