-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
{-# LANGUAGE OverloadedStrings #-}
-- | Dating a record from outside: the hash of its latest record is sent to a
--   time-stamping authority under RFC 3161, and the authority's signed reply
--   is kept in the record. Nothing else leaves: a hash says nothing of what
--   it was made from. The work is OpenSSL's and curl's, called as they are
--   called by hand, so that anyone can do it again without relevé.
module Stamp (authority, request, check, export) where

import Control.Exception (IOException, try)
import Data.Bits (shiftL, shiftR, (.&.), (.|.))
import qualified Data.ByteString as B
import qualified Data.ByteString.Char8 as BC
import Data.Char (isSpace)
import Data.List (isInfixOf)
import qualified Data.Map.Strict as M
import Data.Text (Text)
import qualified Data.Text as T
import Data.Word (Word8)
import System.Directory (doesDirectoryExist, doesFileExist, getTemporaryDirectory, removeFile)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO (hClose, openBinaryTempFile)
import System.Process (readProcessWithExitCode)
import Releve.Types (Stamp (..))

-- | The authority asked unless another is named: free, answering under
--   RFC 3161, and signed under roots every system already holds.
authority :: String
authority = "http://timestamp.digicert.com"

run :: String -> [String] -> IO (Either String String)
run cmd args = do
  r <- try (readProcessWithExitCode cmd args "") :: IO (Either IOException (ExitCode, String, String))
  pure $ case r of
    Left _ -> Left (cmd <> " not found")
    Right (ExitSuccess, out, _) -> Right out
    Right (_, out, err) -> Left (cmd <> ": " <> trim (if null err then out else err))
  where trim = reverse . dropWhile isSpace . reverse . dropWhile isSpace

scratch :: String -> IO FilePath
scratch suffix = do
  dir <- getTemporaryDirectory
  (path, h) <- openBinaryTempFile dir ("releve" <> suffix)
  hClose h
  pure path

-- | The authority's signed time for a record's hash, checked before it is kept.
request :: String -> Text -> IO (Either String Stamp)
request tsa hash = do
  q <- scratch ".tsq"
  r <- scratch ".tsr"
  out <- sequence' [ run "openssl" ["ts", "-query", "-digest", T.unpack hash, "-sha256", "-cert", "-out", q]
                   , run "curl" ["-s", "-S", "--fail", "--max-time", "30", "-H", "Content-Type: application/timestamp-query", "--data-binary", "@" <> q, "-o", r, tsa]
                   , run "openssl" ["ts", "-reply", "-in", r, "-text"] ]
  result <- case out of
    Left e -> pure (Left e)
    Right text
      | not ("Status: Granted." `isInfixOf` text) -> pure (Left "the authority did not grant the request")
      | otherwise -> case [ l | l <- lines text, "Time stamp:" `isInfixOf` l ] of
          l : _ | Just time <- iso (words (drop 1 (dropWhile (/= ':') l))) -> do
            ok <- verifies hash r
            reply <- B.readFile r
            pure $ case ok of
              Right () -> Right (Stamp hash (T.pack tsa) time (base64 reply))
              Left e -> Left e
          _ -> pure (Left "the reply gives no time")
  mapM_ remove [q, r]
  pure result
  where
    sequence' = foldl (\acc a -> acc >>= either (pure . Left) (const a)) (pure (Right ""))

-- | "Oct 16 20:24:45 2026 GMT", as OpenSSL writes it, in ISO 8601.
iso :: [String] -> Maybe Text
iso [mon, day, hms, year, "GMT"] | Just m <- M.lookup mon months =
  Just (T.pack (year <> "-" <> m <> "-" <> pad day <> "T" <> hms <> "Z"))
  where pad d = if length d == 1 then '0' : d else d
iso _ = Nothing

months :: M.Map String String
months = M.fromList (zip (words "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec") [ (if k < 10 then "0" else "") <> show k | k <- [1 :: Int ..] ])

-- | Where the roots that sign a reply are kept: RELEVE_CA if it is set,
--   else the first of the places systems keep them.
roots :: IO (Maybe [String])
roots = do
  named <- lookupEnv "RELEVE_CA"
  let places = maybe [] pure named <> ["/etc/ssl/certs", "/etc/ssl/cert.pem", "/etc/pki/tls/certs/ca-bundle.crt", "/usr/local/etc/openssl/cert.pem"
                                      , "C:\\Program Files\\Git\\mingw64\\etc\\ssl\\certs\\ca-bundle.crt", "C:\\Program Files\\Git\\usr\\ssl\\certs\\ca-bundle.crt"]
  found <- mapM (\p -> (,) p <$> ((,) <$> doesDirectoryExist p <*> doesFileExist p)) places
  pure (case [ if d then ["-CApath", p] else ["-CAfile", p] | (p, (d, f)) <- found, d || f ] of x : _ -> Just x; [] -> Nothing)

verifies :: Text -> FilePath -> IO (Either String ())
verifies hash reply = roots >>= \r -> case r of
  Nothing -> pure (Left "no root certificates found; name them in RELEVE_CA")
  Just ca -> do
    out <- run "openssl" (["ts", "-verify", "-digest", T.unpack hash, "-in", reply] <> ca)
    pure (case out of Right text | "Verification: OK" `isInfixOf` text -> Right (); Right _ -> Left "the signature does not verify"; Left e -> Left e)

-- | Each time stamp of a record checked again: it covers the record before
--   its own, and the authority's signature holds over that record's hash.
check :: [(Int, Text, Stamp)] -> IO [(Int, Stamp, Either String ())]
check xs = mapM one xs
  where
    one (n, prev, s)
      | prev /= stHead s = pure (n, s, Left "it names another record than the one before it")
      | otherwise = case unbase64 (stReply s) of
          Nothing -> pure (n, s, Left "its reply cannot be read")
          Just bytes -> do
            f <- scratch ".tsr"
            B.writeFile f bytes
            ok <- verifies (stHead s) f
            remove f
            pure (n, s, ok)

-- | Each reply written out as a file, for OpenSSL alone: the command that checks it.
export :: FilePath -> [(Int, Stamp)] -> IO [String]
export dir xs = mapM one xs
  where
    one (n, s) = do
      let f = dir </> ("stamp-" <> show n <> ".tsr")
      maybe (pure ()) (B.writeFile f) (unbase64 (stReply s))
      pure ("openssl ts -verify -digest " <> T.unpack (stHead s) <> " -in " <> f <> " -CApath /etc/ssl/certs")

remove :: FilePath -> IO ()
remove f = () <$ (try (removeFile f) :: IO (Either IOException ()))

alphabet :: B.ByteString
alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

base64 :: B.ByteString -> Text
base64 bs = T.pack (go (B.unpack bs))
  where
    enc :: Int -> Char
    enc i = BC.index alphabet i
    go (a : b : c : rest) = let n = w a `shiftL` 16 .|. w b `shiftL` 8 .|. w c in map (\k -> enc (n `shiftR` k .&. 63)) [18, 12, 6, 0] <> go rest
    go [a, b] = let n = w a `shiftL` 16 .|. w b `shiftL` 8 in map (\k -> enc (n `shiftR` k .&. 63)) [18, 12, 6] <> "="
    go [a] = let n = w a `shiftL` 16 in map (\k -> enc (n `shiftR` k .&. 63)) [18, 12] <> "=="
    go [] = ""
    w :: Word8 -> Int
    w = fromIntegral

unbase64 :: Text -> Maybe B.ByteString
unbase64 t = B.pack <$> go (T.unpack (T.filter (/= '=') t))
  where
    val c = fromIntegral <$> BC.elemIndex c alphabet :: Maybe Int
    go s = case splitAt 4 s of
      ([], _) -> Just []
      (chunk, rest) -> do
        vs <- mapM val chunk
        let n = foldl (\acc v -> acc `shiftL` 6 .|. v) 0 vs `shiftL` (6 * (4 - length vs))
            bytes = take (length vs - 1) [fromIntegral (n `shiftR` k .&. 255) | k <- [16, 8, 0]]
        (bytes <>) <$> go rest
