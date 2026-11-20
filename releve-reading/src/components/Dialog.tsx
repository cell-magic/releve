/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

import { useRef, type ReactNode } from 'react'
import { useFocusTrap } from '../useFocusTrap'

/** The shell both overlays share: scrim, keyline, close, Escape, focus trap.
 *  The plate and the fork are the only two things in the surface that trap focus. */
export function Dialog({
  title,
  className,
  trap = true,
  onClose,
  children,
}: {
  title: string
  className: string
  trap?: boolean
  onClose: () => void
  children: ReactNode
}) {
  const ref = useRef<HTMLElement | null>(null)
  useFocusTrap(ref, trap, onClose)

  return (
    <div className="scrim" onClick={onClose}>
      <section
        ref={ref}
        className={`dialog ${className}`}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        onClick={(event) => event.stopPropagation()}
      >
        <header className="dialog-head">
          <h2>{title}</h2>
          <button type="button" onClick={onClose}>
            close
          </button>
        </header>
        {children}
      </section>
    </div>
  )
}
