/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

/**
 * The reading as a file. Nine rows, six columns, RFC 4180 quoting, CRLF, UTF-8 with
 * no BOM: a spreadsheet opens it, a diff reads it, and nothing about it depends on
 * this page still existing.
 */
import type { Panel } from './fixtures'

const HEAD = ['number', 'state', 'class', 'component', 'trigger', 'locator', 'witness', 'remedy']

const cell = (value: string) => '"' + value.replace(/"/g, '""') + '"'

export function toCsv(findings: readonly Panel[]): string {
  const rows = [
    HEAD,
    ...findings.map((f) => [f.ordinal, f.variant, f.defectClass, f.component, f.trigger,
      f.locator, f.snippet.replace(/\\n/g, ' / '), f.remediation]),
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

/** One defect as a ticket a developer can act on without this page. A ticket that
 *  lists nine findings is a report, so this carries exactly one. */
export function ticketFor(finding: Panel, url: string, observedAt: string): string {
  return [
    `# ${finding.defectClass} — ${finding.component}`,
    '',
    `- page: ${url}`,
    `- observed: ${observedAt}`,
    `- state: ${finding.variant}`,
    `- trigger: ${finding.trigger}`,
    `- where: \`${finding.locator}\``,
    '',
    '## Evidence',
    '',
    '```',
    finding.snippet.replace(/\\n/g, '\n'),
    '```',
    '',
    '## Remedy',
    '',
    finding.remediation,
    '',
    '## Done when',
    '',
    `The rule that raised this no longer reports \`${finding.locator}\` on ${url}.`,
    '',
  ].join('\n')
}

export function ticketName(finding: Panel, url: string): string {
  const host = url.replace(/^https?:\/\//, '').replace(/[^a-z0-9.]+/gi, '-').replace(/-+$/, '')
  return `releve-ticket-${finding.ordinal}-${host}.md`
}

export function downloadTicket(finding: Panel, url: string, observedAt: string): void {
  try {
    const blob = new Blob([ticketFor(finding, url, observedAt)], { type: 'text/markdown;charset=utf-8' })
    const href = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = href
    a.download = ticketName(finding, url)
    a.rel = 'noopener'
    document.body.appendChild(a)
    a.click()
    a.remove()
    setTimeout(() => URL.revokeObjectURL(href), 10_000)
  } catch {
    /* the finding stays on the page */
  }
}

/** The four lines someone pastes into Slack: surface, class, triggers, proof. */
export function buildBrief(findings: readonly Panel[], url: string, observedAt: string, hash: string): string {
  const blocking = findings.filter((f) => f.variant === 'blocking')
  return [
    `Surface: ${url} (scanned ${observedAt}, EU egress, hash ${hash})`,
    `Class: ${blocking.length} blocking — ${blocking.slice(0, 3).map((f) => f.defectClass).join(', ')}`,
    `Triggers: ${blocking.slice(0, 3).map((f) => f.locator).join('; ')}`,
    `Reproducible locally, 0 bytes retained: https://releve.bureaudessurfaces.fr/witness`,
  ].join('\n')
}

/** The receipt is a ticket stub, not a summary: same facts, monospace, one block. */
export function buildReceipt(findings: readonly Panel[], url: string, observedAt: string, hash: string, archetype: string): string {
  const blocking = findings.filter((f) => f.variant === 'blocking').length
  return [
    `RELEVÉ — ${url}`,
    `${archetype} · ${blocking} blocking`,
    `${observedAt} · EU egress · sha256:${hash}`,
    `https://releve.bureaudessurfaces.fr/specimen`,
  ].join('\n')
}

export async function copyText(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text)
    return true
  } catch {
    const area = document.createElement('textarea')
    area.value = text
    area.setAttribute('readonly', '')
    area.style.position = 'fixed'
    area.style.opacity = '0'
    document.body.appendChild(area)
    area.select()
    const ok = document.execCommand('copy')
    area.remove()
    return ok
  }
}
