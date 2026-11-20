/* SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
   SPDX-License-Identifier: EUPL-1.2 */

import '@fontsource/archivo/latin-400.css'
import '@fontsource/archivo/latin-500.css'
import '@fontsource/archivo/latin-600.css'
import '@fontsource/ibm-plex-mono/latin-400.css'
import '@fontsource/ibm-plex-mono/latin-600.css'
import './styles.css'

import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
