/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

import { useCallback, useEffect, useRef, useState } from 'react'
import { PANELS } from './fixtures'
import { useSession } from './state'
import { useRoute } from './router'
import { Fork } from './components/Fork'
import { HelpView } from './components/HelpView'
import { Plate } from './components/Plate'
import { Timbre } from './components/Timbre'
import { RecordView } from './components/RecordView'
import { StandingLine } from './components/StandingLine'

const FINDINGS = PANELS.length
const RECORD_AT = FINDINGS
const HELP_AT = FINDINGS + 1
const TOTAL = FINDINGS + 2 // nine findings, then the record and who answers, one axis

export default function App() {
  const band = useRef<HTMLOListElement>(null)
  const [index, setIndex] = useState(0)
  const { state, dispatch } = useSession()
  const { route, navigate } = useRoute()

  const { view, overlay } = route
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
  }, [])

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
  }, [])

  // a vertical wheel turns the axis, unless the panel under the pointer scrolls first
  useEffect(() => {
    const el = band.current
    if (!el) return
    const onWheel = (event: WheelEvent) => {
      if (Math.abs(event.deltaY) <= Math.abs(event.deltaX)) return
      const panel = (event.target as HTMLElement | null)?.closest('.panel') as HTMLElement | null
      if (panel && panel.scrollHeight > panel.clientHeight) {
        const atTop = panel.scrollTop === 0 && event.deltaY < 0
        const atEnd = panel.scrollTop + panel.clientHeight >= panel.scrollHeight - 1 && event.deltaY > 0
        if (!atTop && !atEnd) return
      }
      event.preventDefault()
      el.scrollLeft += event.deltaY * (event.deltaMode === 1 ? 16 : 1)
    }
    el.addEventListener('wheel', onWheel, { passive: false })
    return () => el.removeEventListener('wheel', onWheel)
  }, [])

  // /record and /help are stations on this axis, never another page
  useEffect(() => {
    if (view === 'record') go(RECORD_AT)
    else if (view === 'help') go(HELP_AT)
  }, [go, view])

  // ?go=05 jumps to a finding, as the report's ?go=station does
  useEffect(() => {
    const match = /[?&]go=(\d{1,2})/.exec(window.location.search)
    if (!match) return
    const target = PANELS.findIndex((panel) => panel.ordinal === match[1].padStart(2, '0'))
    const timer = window.setTimeout(() => {
      if (target >= 0) go(target)
    }, 0)
    return () => window.clearTimeout(timer)
  }, [go])

  // arrows and Home move one station, and only outside overlays and inputs
  useEffect(() => {
    if (trapped) return
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
  }, [go, index, trapped])

  // one position, named: a finding by its number, a station by its name
  const counter =
    index < FINDINGS
      ? `${PANELS[index].ordinal} / ${String(FINDINGS).padStart(2, '0')}`
      : index === RECORD_AT
        ? 'record'
        : 'who answers'

  const closeOverlay = () => navigate('/read/1')
  const openPlate = () => navigate('/plate/1')
  const openFork = () => navigate('/stop/1')
  const openRecord = () => {
    go(RECORD_AT)
    navigate('/record')
  }
  const openHelp = () => {
    go(HELP_AT)
    navigate('/help')
  }

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
      <a className="skip" href="#findings">
        Skip to the findings
      </a>

      <nav className="rail" aria-label="Position">
        <span className="mark" role="img" aria-label="Bureau des Surfaces">
          <Timbre />
        </span>
        <button className="first dir" type="button" onClick={() => go(0)}>
          first
        </button>
        <button className="dir" type="button" onClick={() => go(index - 1)} disabled={index === 0}>
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

        <div className="index" role="group" aria-label={counter}>
          {PANELS.map((panel, i) => (
            <button
              key={panel.ordinal}
              type="button"
              aria-current={i === index ? 'true' : undefined}
              onClick={() => go(i)}
            >
              {panel.ordinal}
            </button>
          ))}
        </div>

        {trapped ? (
          <>
            <span className="counter overlay" aria-label={counter}>
              {overlay}
            </span>
            <button type="button" onClick={closeOverlay}>
              close
            </button>
          </>
        ) : (
          <>
            <span className="counter position" aria-label={counter}>
              {counter}
            </span>
            <button type="button" onClick={openPlate}>
              plate
            </button>
          </>
        )}

        <button type="button" onClick={openHelp}>
          who answers
        </button>
        <button type="button" onClick={openRecord}>
          record
        </button>
      </nav>

      <ol className="band" ref={band} id="findings" tabIndex={-1}>
        {PANELS.map((panel, i) => (
          <li
            className="panel"
            key={panel.ordinal}
            aria-posinset={i + 1}
            aria-setsize={TOTAL}
            data-variant={panel.variant}
          >
            <p className="head">
              <span className="num" aria-hidden="true">
                {panel.ordinal}
              </span>
              {panel.variant === 'absent' ? 'absent · risk' : panel.variant}
            </p>

            <div className="finding">
              <p className="statement">{panel.statement}</p>
              <p className="body">{panel.consequence}</p>
              <p className="body">{panel.fix}</p>
            </div>

            <p className="note">
              <sup>1</sup>
              {panel.gloss}
            </p>
          </li>
        ))}

        <li className="panel" aria-posinset={RECORD_AT + 1} aria-setsize={TOTAL}>
          <RecordView state={state} />
        </li>
        <li className="panel" aria-posinset={HELP_AT + 1} aria-setsize={TOTAL}>
          <HelpView />
        </li>
      </ol>

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
