-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- Written by plie/plie.py from Merkle.plie. Do not edit: edit the source.
{-# LANGUAGE NoImplicitPrelude, OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-unused-matches -Wno-name-shadowing -Wno-unused-imports -Wno-incomplete-patterns -Wno-overlapping-patterns #-}
module Plie.Merkle where

import Plie.Prelude
import Prelude (Show)
import qualified Data.Text as T
import Plie.Json

data Step = OnLeft ByteString | OnRight ByteString deriving (Eq, Show)
leafHash :: ByteString -> ByteString
leafHash d = (sha256 ((byte (0 :: Integer)) <> d))

nodeHash :: ByteString -> ByteString -> ByteString
nodeHash l r = (sha256 ((byte (1 :: Integer)) <> (l <> r)))

pairUp :: [ByteString] -> [ByteString]
pairUp xs = (case xs of { (a : (b : rest)) -> ((nodeHash a b) : (pairUp rest)); _ -> xs })

climb :: [ByteString] -> [ByteString] -> ByteString
climb fuel level = (case level of { [] -> (sha256 (utf8 (T.pack ""))); (h : more) -> (case more of { [] -> h; _ -> (case fuel of { [] -> h; (f : rest) -> (climb rest (pairUp level)) }) }) })

ordered :: [ByteString] -> [ByteString]
ordered ds = (sortBy (\a b -> (a < b)) ds)

root :: [ByteString] -> ByteString
root ds = (let ls = (map leafHash (ordered ds)) in (climb ls ls))

pathAt :: [ByteString] -> Integer -> [ByteString] -> [Step]
pathAt fuel i level = (case fuel of { [] -> []; (f : rest) -> (if ((length level) < (2 :: Integer)) then [] else (let sibling = (if ((mod i (2 :: Integer)) == (0 :: Integer)) then (mapMaybe OnRight (nth (i + (1 :: Integer)) level)) else (mapMaybe OnLeft (nth (i - (1 :: Integer)) level))) in (sibling <> (pathAt rest (div i (2 :: Integer)) (pairUp level))))) })

mapMaybe :: (ByteString -> Step) -> (Maybe ByteString) -> [Step]
mapMaybe f m = (case m of { (Just x) -> [(f x)]; (Nothing) -> [] })

position :: ByteString -> [ByteString] -> Integer
position d ds = (length (filter (\x -> (x < d)) (ordered ds)))

pathOf :: ByteString -> [ByteString] -> [Step]
pathOf d ds = (let ls = (map leafHash (ordered ds)) in (pathAt ls (position d ds) ls))

rootFrom :: ByteString -> [Step] -> ByteString
rootFrom d steps = (foldl (\acc s -> (up acc s)) (leafHash d) steps)

up :: ByteString -> Step -> ByteString
up acc s = (case s of { (OnLeft x) -> (nodeHash x acc); (OnRight x) -> (nodeHash acc x) })

stepJson :: Step -> Json
stepJson s = (case s of { (OnLeft x) -> (object [(entry (T.pack "left") (JText (hex x)))]); (OnRight x) -> (object [(entry (T.pack "right") (JText (hex x)))]) })

stepOf :: Json -> Maybe Step
stepOf j = (if (has (T.pack "left") j) then (mapStep OnLeft (unhex (asText (field (T.pack "left") j)))) else (if (has (T.pack "right") j) then (mapStep OnRight (unhex (asText (field (T.pack "right") j)))) else Nothing))

mapStep :: (ByteString -> Step) -> (Maybe ByteString) -> Maybe Step
mapStep f m = (case m of { (Just x) -> (if ((bytesLength x) == (32 :: Integer)) then (Just (f x)) else Nothing); (Nothing) -> Nothing })

merkleBatch :: Json -> Json
merkleBatch input = (let ds = (hexes (asList (field (T.pack "leaves") input))) in (object [(entry (T.pack "root") (JText (hex (root ds)))), (entry (T.pack "size") (JInt (length ds))), (entry (T.pack "paths") (object (map (\d -> (entry (hex d) (JList (map stepJson (pathOf d ds))))) (ordered ds))))]))

hexes :: [Json] -> [ByteString]
hexes js = (concat (map (\j -> (maybeList (unhex (asText j)))) js))

maybeList :: (Maybe ByteString) -> [ByteString]
maybeList m = (case m of { (Just x) -> [x]; (Nothing) -> [] })

