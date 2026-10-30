-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- Written by plie/plie.py. Do not edit: edit the sources.
module Plie.Entries (entries) where

import qualified Data.Text as T
import Plie.Json (Json)
import qualified Plie.Readings

-- | Every function from Json to Json, by name: what the world may call.
entries :: [(T.Text, Json -> Json)]
entries = [(T.pack "legibility", Plie.Readings.legibility), (T.pack "readingsOf", Plie.Readings.readingsOf)]
