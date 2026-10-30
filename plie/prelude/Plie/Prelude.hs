-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
{-# LANGUAGE NoImplicitPrelude, OverloadedStrings #-}
-- | The plié prelude, in Haskell: what each of its names means. Plie.lean and plie.js
--   say the same, name for name; tests/plie.py holds the folds to the same answers.
--   Integers are unbounded; text is compared by code point, bytes by byte.
module Plie.Prelude
  ( Bool (..), Maybe (..), Eq ((==), (/=)), Ord ((<), (<=), (>), (>=)), Integer, Text, ByteString, Pair (..)
  , (+), (-), (*), (&&), (||), (<>)
  , div, mod, abs, min, max, not, showInt, readInt
  , length, map, filter, foldl, reverse, take, drop, sum, all, any, elem, concat, range, zip, nth, sortBy, fromMaybe, fst, snd
  , textLength, utf8, split, startsWith, endsWith, asciiLower, joinText, trim, jsonQuote, ltUtf16
  , sha256, byte, be64, hex, unhex, bytesLength
  ) where

import Prelude (Bool (..), Maybe (..), Eq ((==), (/=)), Ord ((<), (<=), (>), (>=)), Integer, (+), (-), (*), (&&), (||), (<>), (.), fromIntegral, otherwise, (<$>))
import qualified Prelude as P
import qualified Crypto.Hash.SHA256 as SHA
import qualified Data.ByteString as B
import Data.ByteString (ByteString)
import qualified Data.Char as C
import qualified Data.List as L
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Bits (shiftR, (.&.))

data Pair a b = Pair a b deriving (Eq, P.Show)

div, mod, min, max :: Integer -> Integer -> Integer
div = P.div
mod = P.mod
min = P.min
max = P.max

abs :: Integer -> Integer
abs = P.abs

not :: Bool -> Bool
not = P.not

showInt :: Integer -> Text
showInt = T.pack . P.show

readInt :: Text -> Maybe Integer
readInt t | not (T.null t) && T.all C.isDigit t = Just (P.read (T.unpack t))
          | otherwise = Nothing

length :: [a] -> Integer
length = fromIntegral . P.length

map :: (a -> b) -> [a] -> [b]
map = P.map

filter :: (a -> Bool) -> [a] -> [a]
filter = P.filter

foldl :: (b -> a -> b) -> b -> [a] -> b
foldl = L.foldl'

reverse :: [a] -> [a]
reverse = P.reverse

take, drop :: Integer -> [a] -> [a]
take n = P.take (fromIntegral n)
drop n = P.drop (fromIntegral n)

sum :: [Integer] -> Integer
sum = L.foldl' (+) 0

all, any :: (a -> Bool) -> [a] -> Bool
all = P.all
any = P.any

elem :: Eq a => a -> [a] -> Bool
elem = P.elem

concat :: [[a]] -> [a]
concat = P.concat

-- | The integers from a up to b, b left out.
range :: Integer -> Integer -> [Integer]
range a b = if a >= b then [] else [a .. b - 1]

zip :: [a] -> [b] -> [Pair a b]
zip = P.zipWith Pair

nth :: Integer -> [a] -> Maybe a
nth i xs = if i < 0 then Nothing else case P.drop (fromIntegral i) xs of { (x : _) -> Just x; [] -> Nothing }

-- | A stable sort by a strict order: of two elements neither before the other, the first stays first.
sortBy :: (a -> a -> Bool) -> [a] -> [a]
sortBy lt = L.sortBy (\a b -> if lt a b then P.LT else if lt b a then P.GT else P.EQ)

fromMaybe :: a -> Maybe a -> a
fromMaybe d = P.maybe d (\x -> x)

fst :: Pair a b -> a
fst (Pair a _) = a

snd :: Pair a b -> b
snd (Pair _ b) = b

textLength :: Text -> Integer
textLength = fromIntegral . T.length

utf8 :: Text -> ByteString
utf8 = TE.encodeUtf8

-- | The pieces of a text between each occurrence of a separator that is not empty.
split :: Text -> Text -> [Text]
split sep t = if T.null sep then [t] else T.splitOn sep t

startsWith, endsWith :: Text -> Text -> Bool
startsWith p t = T.isPrefixOf p t
endsWith s t = T.isSuffixOf s t

-- | A to Z become a to z; nothing else changes.
asciiLower :: Text -> Text
asciiLower = T.map (\c -> if c >= 'A' && c <= 'Z' then C.chr (C.ord c + 32) else c)

joinText :: Text -> [Text] -> Text
joinText = T.intercalate

-- | Spaces, tabs, line feeds and carriage returns taken from both ends.
trim :: Text -> Text
trim = T.dropAround (`P.elem` [' ', '\t', '\n', '\r'])

-- | A text as JSON writes it under RFC 8785: quotes, backslash, and the controls below U+0020
--   escaped, \b \t \n \f \r by their letter and the others as \u00xx; nothing else.
jsonQuote :: Text -> Text
jsonQuote t = T.concat ["\"", T.concatMap one t, "\""]
  where
    one c = case c of
      '"' -> "\\\""
      '\\' -> "\\\\"
      '\b' -> "\\b"
      '\t' -> "\\t"
      '\n' -> "\\n"
      '\f' -> "\\f"
      '\r' -> "\\r"
      _ | C.ord c < 0x20 -> T.pack (("\\u00" :: P.String) P.++ [hexDigit (C.ord c `shiftR` 4), hexDigit (C.ord c .&. 15)])
        | otherwise -> T.singleton c

-- | The order RFC 8785 sorts object keys in: by UTF-16 code units.
ltUtf16 :: Text -> Text -> Bool
ltUtf16 a b = units a < units b
  where units = P.concatMap unit . T.unpack
        unit c = let n = C.ord c in if n < 0x10000 then [n] else let m = n - 0x10000 in [0xD800 + m `P.div` 0x400, 0xDC00 + m `P.mod` 0x400]

sha256 :: ByteString -> ByteString
sha256 = SHA.hash

-- | One byte, from 0 to 255; anything else is taken modulo 256.
byte :: Integer -> ByteString
byte n = B.singleton (fromIntegral (n `P.mod` 256))

-- | A number as 8 bytes, big-endian, modulo 2^64.
be64 :: Integer -> ByteString
be64 n = B.pack [fromIntegral ((n `shiftR` (8 * k)) `P.mod` 256) | k <- [7, 6 .. 0]]

hex :: ByteString -> Text
hex = T.pack . P.concatMap (\w -> [hexDigit (fromIntegral w `shiftR` 4), hexDigit (fromIntegral w .&. 15)]) . B.unpack

hexDigit :: P.Int -> P.Char
hexDigit k = ("0123456789abcdef" :: P.String) P.!! k

-- | Lowercase or uppercase hexadecimal, two digits a byte; anything else is Nothing.
unhex :: Text -> Maybe ByteString
unhex t = if P.odd (T.length t) then Nothing else B.pack <$$> go (T.unpack t)
  where
    go (a : b : r) = do { x <- val a; y <- val b; rest <- go r; Just (fromIntegral (x * 16 + y) : rest) }
    go _ = Just []
    val c | C.isDigit c = Just (C.ord c - 48) | c >= 'a' && c <= 'f' = Just (C.ord c - 87) | c >= 'A' && c <= 'F' = Just (C.ord c - 55) | otherwise = Nothing
    f <$$> m = P.fmap f m

bytesLength :: ByteString -> Integer
bytesLength = fromIntegral . B.length
