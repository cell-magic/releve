-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- Written by plie/plie.py from Changes.plie. Do not edit: edit the source.
{-# LANGUAGE NoImplicitPrelude, OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-unused-matches -Wno-name-shadowing -Wno-unused-imports -Wno-incomplete-patterns -Wno-overlapping-patterns #-}
module Plie.Changes (marks, criteriaOf, union, change, ruleChanges, readingValue, thirdParties, domainChanges, moved, measureChanges, early, consolidate, kindOf, keyOf, merged, changesAdd, changesOf) where

import Plie.Prelude
import Prelude (Show)
import qualified Data.Text as T
import Plie.Json

marks :: Text -> Text -> [Json] -> Integer
marks criterion label rules = (foldl (\n r -> (if ((asText (field (T.pack "criterion") r)) == criterion) then (n + (asInt (field label r))) else n)) (0 :: Integer) rules)

criteriaOf :: [Json] -> [Text]
criteriaOf rules = (map (\r -> (asText (field (T.pack "criterion") r))) rules)

union :: [Text] -> [Text] -> [Text]
union xs ys = (xs <> (filter (\y -> (not (elem y xs))) ys))

change :: Text -> Text -> Integer -> Json
change kind key delta = (object [(entry (T.pack "kind") (JText kind)), (entry (T.pack "key") (JText key)), (entry (T.pack "delta") (JInt delta))])

ruleChanges :: [Json] -> [Json] -> [Json]
ruleChanges before after = (concat (map (\c -> (concat (map (\l -> (let d = ((marks c l after) - (marks c l before)) in (if (d == (0 :: Integer)) then [] else [(change l c d)]))) [(T.pack "fail"), (T.pack "review"), (T.pack "hint")]))) (union (criteriaOf after) (criteriaOf before))))

readingValue :: Text -> Json -> Json
readingValue name r = (foldl (\v x -> (if ((asText (field (T.pack "name") x)) == name) then (field (T.pack "value") x) else v)) JNull (asList (field (T.pack "readings") r)))

thirdParties :: Json -> [Text]
thirdParties r = (map (\d -> (asText (field (T.pack "domain") d))) (filter (\d -> ((asText (field (T.pack "party") d)) == (T.pack "third"))) (asList (field (T.pack "domains") (readingValue (T.pack "dependencies") r)))))

domainChanges :: Json -> Json -> [Json]
domainChanges before after = (let b = (thirdParties before) in (let a = (thirdParties after) in ((map (\d -> (change (T.pack "third-party") d (1 :: Integer))) (filter (\d -> (not (elem d b))) a)) <> (map (\d -> (change (T.pack "third-party") d ((0 :: Integer) - (1 :: Integer)))) (filter (\d -> (not (elem d a))) b)))))

moved :: Text -> Integer -> Integer -> [Json]
moved key before after = (if (after == before) then [] else [(change (T.pack "measure") key (after - before))])

measureChanges :: Json -> Json -> [Json]
measureChanges before after = ((moved (T.pack "bytes") (asInt (path [(T.pack "observation"), (T.pack "bytes"), (T.pack "total")] before)) (asInt (path [(T.pack "observation"), (T.pack "bytes"), (T.pack "total")] after))) <> ((moved (T.pack "requests") (length (asList (path [(T.pack "observation"), (T.pack "requests")] before))) (length (asList (path [(T.pack "observation"), (T.pack "requests")] after)))) <> ((moved (T.pack "before-interaction") (early before) (early after)) <> (moved (T.pack "obstacles") (asInt (field (T.pack "obstacles") (readingValue (T.pack "legibility") before))) (asInt (field (T.pack "obstacles") (readingValue (T.pack "legibility") after)))))))

early :: Json -> Integer
early r = (length (filter (\q -> (asBool (field (T.pack "pre_interaction") q))) (asList (path [(T.pack "observation"), (T.pack "requests")] r))))

consolidate :: [Json] -> [Json]
consolidate cs = (let sorted = (sortBy (\x y -> (((kindOf x) < (kindOf y)) || (((kindOf x) == (kindOf y)) && ((keyOf x) < (keyOf y))))) cs) in (reverse (filter (\c -> ((asInt (field (T.pack "delta") c)) /= (0 :: Integer))) (foldl merged [] sorted))))

kindOf :: Json -> Text
kindOf c = (asText (field (T.pack "kind") c))

keyOf :: Json -> Text
keyOf c = (asText (field (T.pack "key") c))

merged :: [Json] -> Json -> [Json]
merged acc c = (case acc of { [] -> [c]; (top : rest) -> (if (((kindOf top) == (kindOf c)) && ((keyOf top) == (keyOf c))) then ((change (kindOf c) (keyOf c) ((asInt (field (T.pack "delta") top)) + (asInt (field (T.pack "delta") c)))) : rest) else (c : acc)) })

changesAdd :: Json -> Json
changesAdd input = (object [(entry (T.pack "changes") (JList (consolidate (concat (map asList (asList (field (T.pack "changes") input)))))))])

changesOf :: Json -> Json
changesOf input = (let b = (field (T.pack "before") input) in (let a = (field (T.pack "after") input) in (let same = (((asText (field (T.pack "url") b)) == (asText (field (T.pack "url") a))) && ((asText (field (T.pack "site") b)) == (asText (field (T.pack "site") a)))) in (object [(entry (T.pack "page") (field (T.pack "url") a)), (entry (T.pack "from") (field (T.pack "cycle") b)), (entry (T.pack "to") (field (T.pack "cycle") a)), (entry (T.pack "compared") (JBool same)), (entry (T.pack "changes") (JList (if same then (consolidate ((ruleChanges (asList (field (T.pack "rules") b)) (asList (field (T.pack "rules") a))) <> ((domainChanges b a) <> (measureChanges b a)))) else [])))]))))

