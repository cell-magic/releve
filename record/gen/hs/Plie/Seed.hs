-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- Written by plie/plie.py from Seed.plie. Do not edit: edit the source.
{-# LANGUAGE NoImplicitPrelude, OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-unused-matches -Wno-name-shadowing -Wno-unused-imports -Wno-incomplete-patterns -Wno-overlapping-patterns #-}
module Plie.Seed where

import Plie.Prelude
import Prelude (Show)
import qualified Data.Text as T
import Plie.Json

seedOf :: ByteString -> Text -> Text -> ByteString
seedOf randomness site cycle = (sha256 (randomness <> ((utf8 site) <> (utf8 cycle))))

placeOf :: ByteString -> Text -> ByteString
placeOf seed url = (sha256 (seed <> (utf8 url)))

orderBy :: ByteString -> [Text] -> [Text]
orderBy seed urls = (sortBy (\a b -> ((placeOf seed a) < (placeOf seed b))) urls)

commitment :: [Text] -> Text
commitment urls = (digest (texts (dedupe (sortBy (\a b -> (a < b)) urls))))

dedupe :: [Text] -> [Text]
dedupe xs = (reverse (foldl (\acc x -> (if ((nth (0 :: Integer) acc) == (Just x)) then acc else (x : acc))) [] xs))

orderOf :: Json -> Json
orderOf input = (let r = (fromMaybe (utf8 (T.pack "")) (unhex (asText (field (T.pack "randomness") input)))) in (let urls = (map asText (asList (field (T.pack "candidates") input))) in (let seed = (seedOf r (asText (field (T.pack "site") input)) (asText (field (T.pack "cycle") input))) in (object [(entry (T.pack "seed") (JText (hex seed))), (entry (T.pack "order") (texts (orderBy seed urls))), (entry (T.pack "commitment") (JText (commitment urls)))]))))

commitmentOf :: Json -> Json
commitmentOf input = (let urls = (map asText (asList (field (T.pack "candidates") input))) in (object [(entry (T.pack "commitment") (JText (commitment urls))), (entry (T.pack "candidates") (texts (dedupe (sortBy (\a b -> (a < b)) urls))))]))

firstRoundAfter :: Integer -> Integer
firstRoundAfter t = ((div (t - (1692803367 :: Integer)) (3 :: Integer)) + (2 :: Integer))

