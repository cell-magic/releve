-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
{-# LANGUAGE OverloadedStrings #-}
-- | The corpus: an append-only file of events, one JSON record per line,
--   each record sealing the one before it. Nothing in it is ever rewritten;
--   every report is recomputed from it.
--
--   A seal covers the event's bytes exactly as they stand in the file, so
--   verification never depends on how a JSON library re-encodes them.
module Releve.Corpus (Record (..), sha, next, verify, load, append) where

import qualified Crypto.Hash.SHA256 as SHA
import Data.Aeson
import Data.Aeson.Types (parseEither)
import qualified Data.ByteString as B
import qualified Data.ByteString.Char8 as BC
import qualified Data.ByteString.Lazy as BL
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8)
import System.Directory (doesFileExist)
import Text.Printf (printf)

data Record = Record { rSeq :: Int, rPrev :: Text, rHash :: Text, rRaw :: B.ByteString, rEvent :: Value }

sha :: B.ByteString -> Text
sha = T.pack . concatMap (printf "%02x") . B.unpack . SHA.hash

seal :: Text -> B.ByteString -> Text
seal p raw = sha (encodeUtf8 p <> raw)

genesis :: Text
genesis = T.replicate 64 "0"

next :: [Record] -> Value -> Record
next rs e = Record (length rs) p (seal p raw) raw e
  where
    p = if null rs then genesis else rHash (last rs)
    raw = BL.toStrict (encode e)

-- | Either the sequence number of the first broken record, or the count.
verify :: [Record] -> Either Int Int
verify = go 0 genesis
  where
    go n _ [] = Right n
    go n p (Record s pr h raw _ : rs)
      | s /= n || pr /= p || h /= seal pr raw = Left n
      | otherwise = go (n + 1) h rs

marker :: B.ByteString
marker = ",\"event\":"

-- | The line layout is fixed: seq, prev and hash first, the event last,
--   so the event's bytes can be taken back exactly.
line :: Record -> B.ByteString
line r = BL.toStrict (encode (object ["seq" .= rSeq r, "prev" .= rPrev r, "hash" .= rHash r]))
  `withEvent` rRaw r
  where withEvent hdr raw = B.init hdr <> marker <> raw <> "}"

parse :: B.ByteString -> Either String Record
parse l = do
  let (hdr, rest) = B.breakSubstring marker l
  raw <- maybe (Left "no event") (Right . fst) (B.unsnoc (B.drop (B.length marker) rest))
  (s, p, h) <- eitherDecodeStrict (hdr <> "}") >>= parseEither header
  e <- eitherDecodeStrict raw
  pure (Record s p h raw e)
  where header = withObject "record" $ \o -> (,,) <$> o .: "seq" <*> o .: "prev" <*> o .: "hash"

load :: FilePath -> IO [Record]
load path = do
  exists <- doesFileExist path
  if not exists then pure [] else do
    ls <- filter (not . B.null) . map (BC.dropWhileEnd (== '\r')) . BC.lines <$> B.readFile path
    pure [either (\m -> error (path <> ":" <> show i <> ": " <> m)) id (parse l) | (i, l) <- zip [1 :: Int ..] ls]

append :: FilePath -> Record -> IO ()
append path r = B.appendFile path (line r <> "\n")
