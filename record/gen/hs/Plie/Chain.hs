-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- Written by plie/plie.py from Chain.plie. Do not edit: edit the source.
{-# LANGUAGE NoImplicitPrelude, OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-unused-matches -Wno-name-shadowing -Wno-unused-imports -Wno-incomplete-patterns -Wno-overlapping-patterns #-}
module Plie.Chain (recordHash, linked, chainNext, canonicalOf) where

import Plie.Prelude
import Prelude (Show)
import qualified Data.Text as T
import Plie.Json

recordHash :: Json -> Text
recordHash r = (digest r)

linked :: Json -> Json -> Bool
linked previous r = (let prev = (field (T.pack "prev") r) in (let status = (asText (field (T.pack "chain_status") r)) in (if (isNull prev) then ((status == (T.pack "reset")) || ((status == (T.pack "unbroken")) && (isNull previous))) else ((status == (T.pack "unbroken")) && ((not (isNull previous)) && (((asText prev) == (recordHash previous)) && (((asText (field (T.pack "site") previous)) == (asText (field (T.pack "site") r))) && ((asText (field (T.pack "baseline") previous)) == (asText (field (T.pack "baseline") r))))))))))

chainNext :: Json -> Json
chainNext input = (let last = (field (T.pack "last") input) in (let reset = (asBool (field (T.pack "reset") input)) in (let date = (asText (field (T.pack "date") input)) in (if ((isNull last) || reset) then (object [(entry (T.pack "prev") JNull), (entry (T.pack "baseline") (JText date)), (entry (T.pack "chain_status") (JText (if (isNull last) then (T.pack "unbroken") else (T.pack "reset"))))]) else (object [(entry (T.pack "prev") (field (T.pack "hash") last)), (entry (T.pack "baseline") (field (T.pack "baseline") last)), (entry (T.pack "chain_status") (JText (T.pack "unbroken")))])))))

canonicalOf :: Json -> Json
canonicalOf j = (object [(entry (T.pack "canonical") (JText (canonical j))), (entry (T.pack "hash") (JText (digest j)))])

