-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- Written by plie/plie.py from Readings.plie. Do not edit: edit the source.
{-# LANGUAGE NoImplicitPrelude, OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-unused-matches -Wno-name-shadowing -Wno-unused-imports -Wno-incomplete-patterns -Wno-overlapping-patterns #-}
module Plie.Readings where

import Plie.Prelude
import Prelude (Show)
import qualified Data.Text as T
import Plie.Json

scParts :: Text -> [Integer]
scParts sc = (map (\p -> (fromMaybe (0 :: Integer) (readInt p))) (split (T.pack ".") sc))

scBefore :: Text -> Text -> Bool
scBefore a b = (lexLess (scParts a) (scParts b))

lexLess :: [Integer] -> [Integer] -> Bool
lexLess xs ys = (case xs of { [] -> (case ys of { [] -> False; _ -> True }); (x : xr) -> (case ys of { [] -> False; (y : yr) -> (if (x < y) then True else (if (y < x) then False else (lexLess xr yr))) }) })

marked :: Text -> Json -> Integer
marked label rule = (asInt (field label rule))

labelOf :: [Json] -> Json
labelOf rules = (if (any (\r -> ((marked (T.pack "fail") r) > (0 :: Integer))) rules) then (JText (T.pack "fail")) else (if (any (\r -> ((marked (T.pack "review") r) > (0 :: Integer))) rules) then (JText (T.pack "review")) else (if (any (\r -> ((marked (T.pack "hint") r) > (0 :: Integer))) rules) then (JText (T.pack "hint")) else JNull)))

wcag :: [Json] -> Json
wcag rules = (let scs = (uniqueTexts (concat (map (\r -> (map asText (asList (field (T.pack "wcag") r)))) rules))) in (JList (map (\sc -> (let on = (filter (\r -> (elem (JText sc) (asList (field (T.pack "wcag") r)))) rules) in (object [(entry (T.pack "sc") (JText sc)), (entry (T.pack "label") (labelOf on)), (entry (T.pack "criteria") (texts (map (\r -> (asText (field (T.pack "criterion") r))) (filter (\r -> ((((marked (T.pack "fail") r) + (marked (T.pack "review") r)) + (marked (T.pack "hint") r)) > (0 :: Integer))) on))))]))) (sortBy scBefore scs))))

uniqueTexts :: [Text] -> [Text]
uniqueTexts ts = (foldl (\acc t -> (if (elem t acc) then acc else (acc <> [t]))) [] ts)

hostOf :: Text -> Text
hostOf origin = (let rest = (fromMaybe origin (nth (1 :: Integer) (split (T.pack "://") origin))) in (if (startsWith (T.pack "[") rest) then ((fromMaybe rest (nth (0 :: Integer) (split (T.pack "]") rest))) <> (T.pack "]")) else (asciiLower (fromMaybe rest (nth (0 :: Integer) (split (T.pack ":") rest))))))

isAddress :: Text -> Bool
isAddress host = ((startsWith (T.pack "[") host) || (all (\l -> (((textLength l) > (0 :: Integer)) && ((readInt l) /= Nothing))) (split (T.pack ".") host)))

lastLabels :: Integer -> [Text] -> Text
lastLabels k labels = (joinText (T.pack ".") (drop ((length labels) - k) labels))

suffixLength :: [Text] -> [Text] -> Integer
suffixLength rules labels = (let n = (length labels) in (let ks = (range (1 :: Integer) (n + (1 :: Integer))) in (let excepted = (filter (\k -> (elem ((T.pack "!") <> (lastLabels k labels)) rules)) ks) in (if ((length excepted) > (0 :: Integer)) then ((foldl max (0 :: Integer) excepted) - (1 :: Integer)) else (foldl max (1 :: Integer) (filter (\k -> ((elem (lastLabels k labels) rules) || ((k > (1 :: Integer)) && (elem ((T.pack "*.") <> (lastLabels (k - (1 :: Integer)) labels)) rules)))) ks))))))

registrable :: [Text] -> Text -> Text
registrable rules host = (if (isAddress host) then host else (let labels = (split (T.pack ".") host) in (let s = (suffixLength rules labels) in (if ((length labels) > s) then (lastLabels (s + (1 :: Integer)) labels) else host))))

dependencies :: [Text] -> Text -> Text -> [Json] -> Json
dependencies rules version site requests = (let mine = (registrable rules (hostOf site)) in (let domainOf = (\q -> (registrable rules (hostOf (asText (field (T.pack "origin") q))))) in (let domains = (sortBy (\a b -> (a < b)) (uniqueTexts (map domainOf requests))) in (object [(entry (T.pack "psl") (JText version)), (entry (T.pack "site") (JText mine)), (entry (T.pack "domains") (JList (map (\d -> (let qs = (filter (\q -> ((domainOf q) == d)) requests) in (object [(entry (T.pack "domain") (JText d)), (entry (T.pack "party") (JText (if (d == mine) then (T.pack "first") else (T.pack "third")))), (entry (T.pack "requests") (JInt (length qs))), (entry (T.pack "bytes") (JInt (sum (map (\q -> (asInt (field (T.pack "bytes") q))) qs)))), (entry (T.pack "pre_interaction") (JInt (length (filter (\q -> (asBool (field (T.pack "pre_interaction") q))) qs))))]))) domains)))]))))

legibility :: Json -> Json
legibility ax = (let n = (asInt (field (T.pack "interactive") ax)) in (let named = (asInt (field (T.pack "named") ax)) in (object [(entry (T.pack "interactive") (JInt n)), (entry (T.pack "named") (JInt named)), (entry (T.pack "unnamed") (JInt (n - named))), (entry (T.pack "invalid_roles") (field (T.pack "invalid_roles") ax)), (entry (T.pack "context_violations") (field (T.pack "context_violations") ax)), (entry (T.pack "hidden_interactive") (field (T.pack "hidden_interactive") ax)), (entry (T.pack "obstacles") (JInt ((((n - named) + (asInt (field (T.pack "invalid_roles") ax))) + (asInt (field (T.pack "context_violations") ax))) + (asInt (field (T.pack "hidden_interactive") ax)))))])))

decimal9 :: Integer -> Text
decimal9 nano = ((showInt (div nano (1000000000 :: Integer))) <> ((T.pack ".") <> (pad9 (showInt (mod nano (1000000000 :: Integer))))))

pad9 :: Text -> Text
pad9 t = ((joinText (T.pack "") (map (\k -> (T.pack "0")) (range (textLength t) (9 :: Integer)))) <> t)

energy :: Json -> Integer -> Json
energy coefficient bytes = (let num = (asInt (path [(T.pack "kwh_per_gb"), (T.pack "num")] coefficient)) in (let den = (asInt (path [(T.pack "kwh_per_gb"), (T.pack "den")] coefficient)) in (let d = (den * (1000000000 :: Integer)) in (let nano = (if (d > (0 :: Integer)) then (div ((((bytes * num) * (1000000000 :: Integer)) * (2 :: Integer)) + d) ((2 :: Integer) * d)) else (0 :: Integer)) in (object [(entry (T.pack "bytes") (JInt bytes)), (entry (T.pack "kwh") (JText (decimal9 nano))), (entry (T.pack "coefficient") (object [(entry (T.pack "source") (field (T.pack "source") coefficient)), (entry (T.pack "version") (field (T.pack "version") coefficient)), (entry (T.pack "kwh_per_gb") (field (T.pack "kwh_per_gb") coefficient))]))])))))

reading :: Text -> Integer -> Json -> Json
reading name version value = (object [(entry (T.pack "name") (JText name)), (entry (T.pack "version") (JInt version)), (entry (T.pack "value") value)])

readingsOf :: Json -> Json
readingsOf input = (let o = (field (T.pack "observation") input) in (let psl = (field (T.pack "psl") input) in (JList [(reading (T.pack "wcag") (1 :: Integer) (wcag (asList (field (T.pack "rules") input)))), (reading (T.pack "dependencies") (1 :: Integer) (dependencies (map asText (asList (field (T.pack "rules") psl))) (asText (field (T.pack "version") psl)) (asText (field (T.pack "site") input)) (asList (field (T.pack "requests") o)))), (reading (T.pack "legibility") (1 :: Integer) (legibility (field (T.pack "ax") o))), (reading (T.pack "energy") (1 :: Integer) (energy (field (T.pack "energy") input) (asInt (path [(T.pack "bytes"), (T.pack "total")] o))))])))

