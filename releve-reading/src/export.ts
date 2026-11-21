/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

/**
 * The reading as a file. Nine rows, six columns, RFC 4180 quoting, CRLF, UTF-8 with
 * no BOM: a spreadsheet opens it, a diff reads it, and nothing about it depends on
 * this page still existing.
 */
import type { Panel } from './fixtures'

const HEAD = ['number', 'state', 'statement', 'consequence', 'fix', 'gloss']

const cell = (value: string) => '"' + value.replace(/"/g, '""') + '"'

export function toCsv(findings: readonly Panel[]): string {
  const rows = [
    HEAD,
    ...findings.map((f) => [f.ordinal, f.variant, f.statement, f.consequence, f.fix, f.gloss]),
  ]
  return rows.map((row) => row.map(cell).join(',')).join('\r\n') + '\r\n'
}

const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December']

/** 21 November 2026 -> 2026-11-21: a name that sorts and that no locale reorders. */
export function fileName(url: string, observedAt: string): string {
  const host = url.replace(/^https?:\/\//, '').replace(/[^a-z0-9.]+/gi, '-').replace(/-+$/, '')
  const [day, month, year] = observedAt.slice(0, observedAt.indexOf(',')).split(' ')
  const mm = String(MONTHS.indexOf(month) + 1).padStart(2, '0')
  return `releve-${host}-${year}-${mm}-${day.padStart(2, '0')}.csv`
}

/** A download that fails quiet: a browser that blocks it must not take the surface
 *  down with it, since the same reading is on the page and in the plate. */
export function downloadCsv(findings: readonly Panel[], url: string, observedAt: string): void {
  try {
    const blob = new Blob([toCsv(findings)], { type: 'text/csv;charset=utf-8' })
    const href = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = href
    a.download = fileName(url, observedAt)
    a.rel = 'noopener'
    document.body.appendChild(a)
    a.click()
    a.remove()
    setTimeout(() => URL.revokeObjectURL(href), 10_000)
  } catch {
    /* the reader still has the plate */
  }
}
