/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

import { useReducer } from 'react'
import { NOW, type Action, type State } from './types'

const initial: State = {
  session: 'active',
  receipts: [],
  record: [{ at: '14 March 2026', fact: 'Page read. 11 checks run, 9 findings.' }],
  sent: false,
}

let nextId = 1

function reducer(state: State, action: Action): State {
  switch (action.type) {
    case 'stop': {
      if (state.session === 'left') return state
      const receipt = {
        id: nextId++,
        at: NOW,
        fact: 'Stopped. €6.00 returned for 18 unused days.',
        undo: true,
      }
      return {
        ...state,
        session: 'left',
        receipts: [receipt, ...state.receipts],
        record: [...state.record, { at: '14 March 2026', fact: 'Stopped. €6.00 returned.' }],
      }
    }
    case 'undo': {
      // a stop and its refund both reverse; the receipt itself does not survive
      return {
        ...state,
        session: 'active',
        receipts: state.receipts.filter((r) => r.id !== action.id),
        record: [...state.record, { at: '14 March 2026', fact: 'Stop reversed. €6.00 re-charged.' }],
      }
    }
    case 'dormant': {
      if (state.session !== 'active') return state
      return {
        ...state,
        session: 'dormant',
        receipts: [
          { id: nextId++, at: NOW, fact: 'Dormant. No charge scheduled.', undo: false },
          ...state.receipts,
        ],
        record: [...state.record, { at: '14 March 2026', fact: 'Went dormant. No charge scheduled.' }],
      }
    }
    case 'resume': {
      if (state.session === 'active') return state
      return {
        ...state,
        session: 'active',
        receipts: [
          { id: nextId++, at: NOW, fact: 'Resumed. €10.00 per month again.', undo: false },
          ...state.receipts,
        ],
        record: [...state.record, { at: '14 March 2026', fact: 'Resumed. €10.00 per month.' }],
      }
    }
    case 'send': {
      if (state.sent) return state
      return {
        ...state,
        sent: true,
        receipts: [
          { id: nextId++, at: NOW, fact: 'Plate exported. The stamp dates it.', undo: false },
          ...state.receipts,
        ],
      }
    }
    default:
      return state
  }
}

export function useSession() {
  const [state, dispatch] = useReducer(reducer, initial)
  return { state, dispatch }
}
