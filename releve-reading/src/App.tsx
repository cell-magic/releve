/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

import { useCallback, useEffect, useRef, useState } from 'react'
import { source } from './api'
import { downloadCsv } from './export'
import { useSession } from './state'
import { STATIONS, STATION_NAMES, parse, useRoute } from './router'
import type { Station } from './router'
import { Dialog } from './components/Dialog'
import { Fork } from './components/Fork'
import { HelpView } from './components/HelpView'
import { Plate } from './components/Plate'
import { Timbre } from './components/Timbre'
import { RecordView } from './components/RecordView'
import { StandingLine } from './components/StandingLine'
import { ProbeView } from './components/ProbeView'
import { SpecimenView } from './components/SpecimenView'
import { WitnessView } from './components/WitnessView'
import { DriftView } from './components/DriftView'
import { RadarView } from './components/RadarView'

const reading = source.read()
const PANELS = reading.findings
const TOTAL = STATIONS.length

export default function App() {
  const band = useRef<HTMLOListElement>(null)
  const last = useRef<Station | null>(null)
  const sent = useRef(0)
  const [index, setIndex] = useState(() => STATIONS.indexOf(parse(window.location.pathname).station))
  const { state, dispatch } = useSession()
  const { route, navigate } = useRoute()

  const { station, overlay } = route
  const trapped = overlay !== 'none'

  // the ring: index and URL are two views of one position
  const go = useCallback(
    (next: number, push = true) => {
      const clamped = Math.max(0, Math.min(TOTAL - 1, next))
      const el = band.current
      const panel = el?.children[clamped] as HTMLElement | undefined
      if (el && panel) el.scrollTo({ left: panel.offsetLeft, behavior: 'instant' })
      sent.current = Date.now()
      setIndex(clamped)
      if (push) navigate('/' + STATIONS[clamped])
    },
    [navigate],
  )

  // a station named in the URL wins over a stale snap position
  useEffect(() => {
    const target = STATIONS.indexOf(station)
    if (target < 0) return
    setIndex(target)
    const el = band.current
    const panel = el?.children[target] as HTMLElement | undefined
    if (el && panel && Math.abs(el.scrollLeft - panel.offsetLeft) > 1) {
      el.scrollTo({ left: panel.offsetLeft, behavior: 'instant' })
    }
  }, [station])

  // settle after a trackpad swipe, then write the position into the URL
  useEffect(() => {
    const el = band.current
    if (!el) return
    let timer = 0
    const settle = () => {
      // a rotation just wrote itself into the track: its scroll event is not a swipe
      if (Date.now() - sent.current < 500) return
      const first = el.children[0] as HTMLElement | undefined
      if (!first) return
      const width = first.offsetWidth || 1
      const next = Math.max(0, Math.min(TOTAL - 1, Math.round(el.scrollLeft / width)))
      setIndex(next)
      navigate('/' + STATIONS[next])
    }
    const onScroll = () => {
      window.clearTimeout(timer)
      timer = window.setTimeout(settle, 140)
    }
    el.addEventListener('scroll', onScroll, { passive: true })
    return () => {
      el.removeEventListener('scroll', onScroll)
      window.clearTimeout(timer)
    }
  }, [navigate])

  // focus lands on the station heading when the position changes, never on boot
  useEffect(() => {
    const previous = last.current
    last.current = station
    if (!previous || previous === station) return
    const heading = document.querySelector(`[data-station="${station}"] h2`) as HTMLElement | null
    heading?.focus({ preventScroll: true })
  }, [station])

  // arrows rotate the ring; 1..5 jump; nothing fires inside a field
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
      } else if (/^[1-5]$/.test(event.key)) {
        event.preventDefault()
        go(Number(event.key) - 1)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [go, index, trapped])

  const closeOverlay = () => navigate('/' + station)
  const onStop = () => {
    dispatch({ type: 'stop' })
    closeOverlay()
  }
  const onExport = () => {
    downloadCsv(PANELS, reading.url, reading.observedAt)
    dispatch({ type: 'send' })
    navigate(`/${station}/plate`)
  }

  const counter = `${String(index + 1).padStart(2, '0')} / 0${TOTAL}`

  return (
    <div className="app" data-station={station} data-overlay={overlay}>
      <a className="skip" href="#stations">
        Skip to stations
      </a>

      <nav className="rail" aria-label="Ring stations">
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

        <div className="index" role="group" aria-label={`Station ${index + 1} of ${TOTAL}: ${STATION_NAMES[station]}`}>
          {STATIONS.map((name, i) => (
            <button
              key={name}
              type="button"
              aria-current={i === index ? 'true' : undefined}
              tabIndex={i === index ? 0 : -1}
              onClick={() => go(i)}
            >
              {String(i + 1).padStart(2, '0')}
            </button>
          ))}
        </div>

        {trapped ? (
          <>
            <span className="counter overlay" aria-label={overlay}>
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
            <button type="button" onClick={() => navigate(`/${station}/plate`)}>
              plate
            </button>
          </>
        )}

        <button type="button" onClick={() => navigate(`/${station}/help`)}>
          who answers
        </button>
        <button type="button" onClick={() => navigate(`/${station}/record`)}>
          record
        </button>
      </nav>

      <div className="scope-bar">
        <span className="verdict">
          {PANELS.filter((p) => p.variant === 'blocking').length} blocking ·{' '}
          {PANELS.filter((p) => p.variant === 'passing').length} passing · {reading.url}
        </span>
        <span className="contract">
          k-center sample · deterministic · human audit where marked · zero-AI ·{' '}
          {reading.observedAt}
        </span>
      </div>

      <p className="sr-only" role="status" aria-live="polite">
        Station {index + 1} of {TOTAL}: {STATION_NAMES[station]}
      </p>

      <ol className="band" ref={band} id="stations" tabIndex={-1}>
        <li className="panel station" aria-posinset={1} aria-setsize={TOTAL}>
          <ProbeView onSubmit={() => go(1)} />
        </li>
        <li className="panel station" aria-posinset={2} aria-setsize={TOTAL}>
          <SpecimenView findings={PANELS} url={reading.url} observedAt={reading.observedAt} />
        </li>
        <li className="panel station" aria-posinset={3} aria-setsize={TOTAL}>
          <WitnessView findings={PANELS} url={reading.url} observedAt={reading.observedAt} />
        </li>
        <li className="panel station" aria-posinset={4} aria-setsize={TOTAL}>
          <DriftView />
        </li>
        <li className="panel station" aria-posinset={5} aria-setsize={TOTAL}>
          <RadarView url={reading.url} onWrap={() => go(0)} />
        </li>
      </ol>

      <StandingLine
        session={state.session}
        receipts={state.receipts}
        onOpenFork={() => navigate(`/${station}/stop`)}
        onDormant={() => dispatch({ type: 'dormant' })}
        onResume={() => dispatch({ type: 'resume' })}
        onExport={onExport}
        onUndo={(id) => dispatch({ type: 'undo', id })}
      />

      {overlay === 'plate' && (
        <Plate state={state} onClose={closeOverlay} onSend={() => dispatch({ type: 'send' })} />
      )}
      {overlay === 'fork' && <Fork onClose={closeOverlay} onStop={onStop} />}
      {overlay === 'record' && (
        <Dialog title="Record" className="record" onClose={closeOverlay}>
          <RecordView state={state} />
        </Dialog>
      )}
      {overlay === 'help' && (
        <Dialog title="Who answers" className="help" onClose={closeOverlay}>
          <HelpView />
        </Dialog>
      )}
    </div>
  )
}
