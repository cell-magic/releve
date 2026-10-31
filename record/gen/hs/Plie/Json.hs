-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- Written by plie/plie.py from Json.plie. Do not edit: edit the source.
{-# LANGUAGE NoImplicitPrelude, OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-unused-matches -Wno-name-shadowing -Wno-unused-imports -Wno-incomplete-patterns -Wno-overlapping-patterns #-}
module Plie.Json (Json(..), field, fieldIn, has, path, asInt, asText, asBool, asList, isNull, entry, object, texts, ints, canonical, member, canonicalBytes, digest) where

import Plie.Prelude
import Prelude (Show)
import qualified Data.Text as T

data Json = JNull | JBool Bool | JInt Integer | JText Text | JList [Json] | JObj [Pair Text Json] deriving (Eq, Show)
field :: Text -> Json -> Json
field k j = (case j of { (JObj fs) -> (fieldIn k fs); _ -> JNull })

fieldIn :: Text -> [Pair Text Json] -> Json
fieldIn k fs = (case fs of { [] -> JNull; (f : rest) -> (if ((fst f) == k) then (snd f) else (fieldIn k rest)) })

has :: Text -> Json -> Bool
has k j = (case j of { (JObj fs) -> (any (\f -> ((fst f) == k)) fs); _ -> False })

path :: [Text] -> Json -> Json
path ks j = (foldl (\x k -> (field k x)) j ks)

asInt :: Json -> Integer
asInt j = (case j of { (JInt n) -> n; _ -> (0 :: Integer) })

asText :: Json -> Text
asText j = (case j of { (JText t) -> t; _ -> (T.pack "") })

asBool :: Json -> Bool
asBool j = (case j of { (JBool b) -> b; _ -> False })

asList :: Json -> [Json]
asList j = (case j of { (JList xs) -> xs; _ -> [] })

isNull :: Json -> Bool
isNull j = (case j of { (JNull) -> True; _ -> False })

entry :: Text -> Json -> Pair Text Json
entry k v = (Pair k v)

object :: [Pair Text Json] -> Json
object fs = (JObj fs)

texts :: [Text] -> Json
texts ts = (JList (map JText ts))

ints :: [Integer] -> Json
ints ns = (JList (map JInt ns))

canonical :: Json -> Text
canonical j = (case j of { (JNull) -> (T.pack "null"); (JBool b) -> (if b then (T.pack "true") else (T.pack "false")); (JInt n) -> (showInt n); (JText t) -> (jsonQuote t); (JList xs) -> ((T.pack "[") <> ((joinText (T.pack ",") (map canonical xs)) <> (T.pack "]"))); (JObj fs) -> ((T.pack "{") <> ((joinText (T.pack ",") (map member (sortBy (\a b -> (ltUtf16 (fst a) (fst b))) fs))) <> (T.pack "}"))) })

member :: (Pair Text Json) -> Text
member f = ((jsonQuote (fst f)) <> ((T.pack ":") <> (canonical (snd f))))

canonicalBytes :: Json -> ByteString
canonicalBytes j = (utf8 (canonical j))

digest :: Json -> Text
digest j = (hex (sha256 (canonicalBytes j)))

