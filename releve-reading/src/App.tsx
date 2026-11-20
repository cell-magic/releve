/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

import { useCallback, useEffect, useRef, useState } from 'react'
import { PANELS, SESSION } from './fixtures'

const TOTAL = PANELS.length

export default function App() {
  const band = useRef<HTMLOListElement>(null)
  const [index, setIndex] = useState(0)

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

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      const active = document.activeElement
      const tag = active?.tagName ?? ''
      if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' || (active as HTMLElement)?.isContentEditable)
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
  }, [go, index])

  const current = PANELS[index]
  const counter = `${current.ordinal} / ${String(TOTAL).padStart(2, '0')}`
  const segs: { text: string; tone?: 'cost' }[] = [
    { text: SESSION.state },
    { text: SESSION.price, tone: 'cost' },
    { text: `paid through ${SESSION.paidThrough}` },
    { text: `next charge ${SESSION.nextCharge}` },
  ]
  const acts: { label: string; solid?: boolean }[] = [
    { label: 'Export all' },
    { label: 'Go dormant' },
    { label: 'Stop', solid: true },
  ]

  return (
    <div className="app">
      <nav className="rail" aria-label="Position" data-count={counter}>
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
        <span className="counter" aria-label={counter}>
          {counter}
        </span>
        <button type="button">who answers</button>
      </nav>

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

      <div className="line">
        <div className="segs">
          {segs.map((seg, i) => (
            <span className={seg.tone ? `seg tone-${seg.tone}` : 'seg'} key={seg.text}>
              {seg.text}
              {i < segs.length - 1 && (
                <span className="sep" aria-hidden="true">
                  {' · '}
                </span>
              )}
            </span>
          ))}
        </div>
        <div className="acts">
          {acts.map((act, i) => (
            <span className="act" key={act.label}>
              <button type="button" className={act.solid ? 'stop' : undefined}>
                {act.label}
              </button>
              {i < acts.length - 1 && (
                <span className="sep" aria-hidden="true">
                  {' · '}
                </span>
              )}
            </span>
          ))}
        </div>
      </div>
    </div>
  )
}
