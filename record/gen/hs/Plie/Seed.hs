-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- Written by plie/plie.py from Seed.plie. Do not edit: edit the source.
{-# LANGUAGE NoImplicitPrelude, OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-unused-matches -Wno-name-shadowing -Wno-unused-imports -Wno-incomplete-patterns -Wno-overlapping-patterns #-}
module Plie.Seed (Seed, seedOf, seedHex, placeOf, orderBy, commitment, dedupe, orderOf, commitmentOf, firstRoundAfter, daysFrom, cycleStart, drawOf, canonicalUrl, authorityHost, authorityPort, portFits, upperEscape, hexDigits) where

import Plie.Prelude
import Prelude (Show)
import qualified Data.Text as T
import Plie.Json

data Seed = Seed ByteString deriving (Eq, Show)
seedOf :: ByteString -> Text -> Text -> Seed
seedOf randomness site cycle = (Seed (sha256 (randomness <> ((utf8 site) <> (utf8 cycle)))))

seedHex :: Seed -> Text
seedHex s = (case s of { (Seed b) -> (hex b) })

placeOf :: Seed -> Text -> ByteString
placeOf s url = (case s of { (Seed b) -> (sha256 (b <> (utf8 url))) })

orderBy :: Seed -> [Text] -> [Text]
orderBy seed urls = (sortBy (\a b -> ((placeOf seed a) < (placeOf seed b))) urls)

commitment :: [Text] -> Text
commitment urls = (digest (texts (dedupe (sortBy (\a b -> (a < b)) urls))))

dedupe :: [Text] -> [Text]
dedupe xs = (reverse (foldl (\acc x -> (if ((nth (0 :: Integer) acc) == (Just x)) then acc else (x : acc))) [] xs))

orderOf :: Json -> Json
orderOf input = (let r = (fromMaybe (utf8 (T.pack "")) (unhex (asText (field (T.pack "randomness") input)))) in (let urls = (map asText (asList (field (T.pack "candidates") input))) in (let seed = (seedOf r (asText (field (T.pack "site") input)) (asText (field (T.pack "cycle") input))) in (object [(entry (T.pack "seed") (JText (seedHex seed))), (entry (T.pack "order") (texts (orderBy seed urls))), (entry (T.pack "commitment") (JText (commitment urls)))]))))

commitmentOf :: Json -> Json
commitmentOf input = (let urls = (map asText (asList (field (T.pack "candidates") input))) in (object [(entry (T.pack "commitment") (JText (commitment urls))), (entry (T.pack "candidates") (texts (dedupe (sortBy (\a b -> (a < b)) urls)))), (entry (T.pack "refused") (texts (filter (\u -> (not (canonicalUrl u))) urls)))]))

firstRoundAfter :: Integer -> Integer
firstRoundAfter t = ((div (t - (1692803367 :: Integer)) (3 :: Integer)) + (2 :: Integer))

daysFrom :: Integer -> Integer -> Integer -> Integer
daysFrom y m d = (let y1 = (if (m <= (2 :: Integer)) then (y - (1 :: Integer)) else y) in (let era = (div y1 (400 :: Integer)) in (let yoe = (y1 - (era * (400 :: Integer))) in (let doy = (((div (((153 :: Integer) * (mod (m + (9 :: Integer)) (12 :: Integer))) + (2 :: Integer)) (5 :: Integer)) + d) - (1 :: Integer)) in ((((((era * (146097 :: Integer)) + (yoe * (365 :: Integer))) + (div yoe (4 :: Integer))) - (div yoe (100 :: Integer))) + doy) - (719468 :: Integer))))))

cycleStart :: Text -> Integer
cycleStart cycle = (let parts = (split (T.pack "-") cycle) in (case (readInt (fromMaybe (T.pack "") (nth (0 :: Integer) parts))) of { (Nothing) -> ((0 :: Integer) - (1 :: Integer)); (Just y) -> (case (readInt (fromMaybe (T.pack "") (nth (1 :: Integer) parts))) of { (Nothing) -> ((0 :: Integer) - (1 :: Integer)); (Just m) -> (if (((length parts) == (2 :: Integer)) && ((m >= (1 :: Integer)) && (m <= (12 :: Integer)))) then ((daysFrom y m (1 :: Integer)) * (86400 :: Integer)) else ((0 :: Integer) - (1 :: Integer))) }) }))

drawOf :: Json -> Json
drawOf input = (let start = (cycleStart (asText (field (T.pack "cycle") input))) in (object [(entry (T.pack "rule") (JText (T.pack "releve-draw/1"))), (entry (T.pack "start") (JInt start)), (entry (T.pack "round") (JInt (firstRoundAfter start)))]))

canonicalUrl :: Text -> Bool
canonicalUrl url = (let scheme = (if (startsWith (T.pack "https://") url) then (T.pack "https") else (if (startsWith (T.pack "http://") url) then (T.pack "http") else (T.pack ""))) in (let rest = (joinText (T.pack "://") (drop (1 :: Integer) (split (T.pack "://") url))) in (let segments = (split (T.pack "/") rest) in (let authority = (fromMaybe (T.pack "") (nth (0 :: Integer) segments)) in (let pathPart = (joinText (T.pack "/") (drop (1 :: Integer) segments)) in (let host = (authorityHost authority) in ((scheme /= (T.pack "")) && (((length segments) >= (2 :: Integer)) && ((host /= (T.pack "")) && (((asciiLower authority) == authority) && ((not (endsWith (T.pack ":") authority)) && (((length (split (T.pack "?") authority)) == (1 :: Integer)) && (((bytesLength (utf8 authority)) == (textLength authority)) && ((not (endsWith (T.pack ".") host)) && (((length (split (T.pack "@") authority)) == (1 :: Integer)) && (((length (split (T.pack "#") url)) == (1 :: Integer)) && ((portFits scheme (authorityPort authority)) && ((all (\seg -> ((seg /= (T.pack ".")) && (seg /= (T.pack "..")))) (split (T.pack "/") (fromMaybe (T.pack "") (nth (0 :: Integer) (split (T.pack "?") pathPart))))) && (all upperEscape (drop (1 :: Integer) (split (T.pack "%") url)))))))))))))))))))))

authorityHost :: Text -> Text
authorityHost authority = (if (startsWith (T.pack "[") authority) then ((fromMaybe (T.pack "") (nth (0 :: Integer) (split (T.pack "]") authority))) <> (T.pack "]")) else (fromMaybe (T.pack "") (nth (0 :: Integer) (split (T.pack ":") authority))))

authorityPort :: Text -> Text
authorityPort authority = (joinText (T.pack ":") (drop (1 :: Integer) (split (T.pack ":") (if (startsWith (T.pack "[") authority) then (joinText (T.pack "]") (drop (1 :: Integer) (split (T.pack "]") authority))) else authority))))

portFits :: Text -> Text -> Bool
portFits scheme port = ((port == (T.pack "")) || (((readInt port) /= Nothing) && ((not (startsWith (T.pack "0") port)) && ((not ((scheme == (T.pack "http")) && (port == (T.pack "80")))) && (not ((scheme == (T.pack "https")) && (port == (T.pack "443"))))))))

upperEscape :: Text -> Bool
upperEscape after = (any (\a -> (any (\b -> (startsWith (a <> b) after)) hexDigits)) hexDigits)

hexDigits :: [Text]
hexDigits = [(T.pack "0"), (T.pack "1"), (T.pack "2"), (T.pack "3"), (T.pack "4"), (T.pack "5"), (T.pack "6"), (T.pack "7"), (T.pack "8"), (T.pack "9"), (T.pack "A"), (T.pack "B"), (T.pack "C"), (T.pack "D"), (T.pack "E"), (T.pack "F")]

