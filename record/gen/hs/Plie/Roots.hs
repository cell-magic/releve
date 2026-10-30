-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- Written by plie/plie.py from Roots.plie. Do not edit: edit the source.
{-# LANGUAGE NoImplicitPrelude, OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-unused-matches -Wno-name-shadowing -Wno-unused-imports -Wno-incomplete-patterns -Wno-overlapping-patterns #-}
module Plie.Roots where

import Plie.Prelude
import Prelude (Show)
import qualified Data.Text as T
import Plie.Json

entryHash :: Json -> Text
entryHash e = (digest e)

chained :: Json -> [Json] -> Bool
chained before es = (case es of { [] -> True; (e : rest) -> ((if (isNull before) then (isNull (field (T.pack "prev_entry_hash") e)) else (((asText (field (T.pack "prev_entry_hash") e)) == (entryHash before)) && ((asText (field (T.pack "cycle") before)) < (asText (field (T.pack "cycle") e))))) && (chained e rest)) })

listed :: Text -> Text -> [Json] -> Bool
listed cycle rootHex es = (any (\e -> (((asText (field (T.pack "cycle") e)) == cycle) && ((asText (field (T.pack "root") e)) == rootHex))) es)

lastOf :: [Json] -> Json
lastOf es = (foldl (\acc e -> e) JNull es)

rootsAppend :: Json -> Json
rootsAppend input = (let es = (asList (field (T.pack "roots") input)) in (let before = (lastOf es) in (let e = (object [(entry (T.pack "cycle") (field (T.pack "cycle") input)), (entry (T.pack "root") (field (T.pack "root") input)), (entry (T.pack "token_hash") (field (T.pack "token_hash") input)), (entry (T.pack "prev_entry_hash") (if (isNull before) then JNull else (JText (entryHash before))))]) in (object [(entry (T.pack "format") (JText (T.pack "releve-roots/1"))), (entry (T.pack "entries") (JList (es <> [e])))]))))

