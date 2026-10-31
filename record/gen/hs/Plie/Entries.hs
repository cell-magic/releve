-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- Written by plie/plie.py. Do not edit: edit the sources.
module Plie.Entries (entries) where

import qualified Data.Text as T
import Plie.Json (Json)
import qualified Plie.Chain
import qualified Plie.Changes
import qualified Plie.Merkle
import qualified Plie.Readings
import qualified Plie.Roots
import qualified Plie.Seed
import qualified Plie.Verify

-- | Every function from Json to Json, by name: what the world may call.
entries :: [(T.Text, Json -> Json)]
entries = [(T.pack "merkleBatch", Plie.Merkle.merkleBatch), (T.pack "orderOf", Plie.Seed.orderOf), (T.pack "commitmentOf", Plie.Seed.commitmentOf), (T.pack "chainNext", Plie.Chain.chainNext), (T.pack "canonicalOf", Plie.Chain.canonicalOf), (T.pack "rootsAppend", Plie.Roots.rootsAppend), (T.pack "legibility", Plie.Readings.legibility), (T.pack "readingsOf", Plie.Readings.readingsOf), (T.pack "changesOf", Plie.Changes.changesOf), (T.pack "verifyBundle", Plie.Verify.verifyBundle)]
