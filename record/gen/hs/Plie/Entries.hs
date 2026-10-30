-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- Written by plie/plie.py. Do not edit: edit the sources.
module Plie.Entries (entries) where

import qualified Data.Text as T
import Plie.Json (Json)
import qualified Plie.Chain
import qualified Plie.Merkle
import qualified Plie.Readings
import qualified Plie.Roots

-- | Every function from Json to Json, by name: what the world may call.
entries :: [(T.Text, Json -> Json)]
entries = [(T.pack "merkleBatch", Plie.Merkle.merkleBatch), (T.pack "chainNext", Plie.Chain.chainNext), (T.pack "canonicalOf", Plie.Chain.canonicalOf), (T.pack "rootsAppend", Plie.Roots.rootsAppend), (T.pack "legibility", Plie.Readings.legibility), (T.pack "readingsOf", Plie.Readings.readingsOf)]
