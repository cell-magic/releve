-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
{-# LANGUAGE OverloadedStrings #-}
-- | releve — the impure edge: files in, text out. All judgement lives in
--   the pure modules; this file only moves bytes.
module Main (main) where

import Control.Monad (foldM_, forM_)
import Data.Aeson (Value, eitherDecodeStrict, encode, object, toJSON, (.=))
import qualified Data.Set as S
import qualified Data.ByteString.Char8 as BC
import qualified Data.ByteString.Lazy.Char8 as BL
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import System.Environment (getArgs)
import System.Exit (exitWith, ExitCode (..))
import System.IO (hPutStrLn, hSetEncoding, hSetNewlineMode, noNewlineTranslation, stderr, stdin, stdout, universalNewlineMode, utf8)
import Releve.Corpus
import Releve.Criteria (criteria, version)
import Releve.Frameworks
import Releve.Kernel
import Releve.Report
import Releve.Types
import Releve.Views

usage :: String
usage = unlines
  [ "releve — judge observed web pages; keep every reading"
  , ""
  , "  observe URL | releve ingest CORPUS    record observations (JSON lines on stdin)"
  , "  releve facts CORPUS [ID|URL|--all]    the checkable report, as Markdown"
  , "  releve report en|fr CORPUS [--ask]    the report for the pages' owner, as HTML;"
  , "                                        CORPUS may be - : observations on stdin, nothing kept;"
  , "                                        --ask: each point to decide with the controls to answer it"
  , "  releve correct CORPUS < facts.md      record a person's edits to a report"
  , "  releve declarations CORPUS            the criteria no rule can see, with the owner's answers"
  , "  releve declare CORPUS < answers.md    record the owner's edits to the declarations"
  , "  releve atlas CORPUS                   every observation as study data (JSON lines)"
  , "  releve verify CORPUS                  check the corpus seals"
  , "  releve criteria                       list the criteria and their sources"
  , "  releve guide en|fr                    the criteria and what each is for, as HTML"
  , "  releve frameworks                     each law and standard, and how many of its provisions"
  , "                                        the criteria address (JSON lines)"
  , "  releve --version" ]

-- | The release, as in releve.cabal; tests/run.py holds the two together.
release :: String
release = "0.6.0"

-- | The same bytes on every system: UTF-8, and line feeds alone on the way out.
plain :: IO ()
plain = do
  mapM_ (`hSetEncoding` utf8) [stdin, stdout, stderr]
  hSetNewlineMode stdin universalNewlineMode
  hSetNewlineMode stdout noNewlineTranslation

main :: IO ()
main = plain >> getArgs >>= \args -> case args of
  ["ingest", c] -> ingest c
  ["facts", c] -> withState c $ \st -> maybe (die "no observations") (TIO.putStr . facts st) (resolve st Nothing)
  ["facts", c, "--all"] -> withState c (TIO.putStr . factsAll)
  ["facts", c, ref] -> withState c $ \st -> maybe (die "no such observation") (TIO.putStr . facts st) (resolve st (Just (T.pack ref)))
  ("report" : l : c : rest) | Just lang <- lookup l [("en", En), ("fr", Fr)], rest `elem` [[], ["--ask"]] ->
    (if c == "-" then passing else records c) >>= either die (TIO.putStr . report lang (rest == ["--ask"]) (T.pack release)) . build
  ["correct", c] -> correct c
  ["declarations", c] -> withState c (TIO.putStr . declarations)
  ["declare", c] -> declare c
  ["atlas", c] -> withState c $ \st -> forM_ (observations st) (BL.putStrLn . encode . atlas st)
  ["verify", c] -> records c >>= \rs -> case verify rs of
    Right n -> putStrLn ("sealed · " <> show n <> (if n == 1 then " record" else " records")
                           <> concat [" · head " <> T.unpack (T.take 8 (rHash (last rs))) | not (null rs)])
    Left n -> die ("broken at record " <> show n)
  ["criteria"] -> do
    putStrLn ("criteria v" <> T.unpack version)
    forM_ criteria $ \k -> TIO.putStrLn (T.justifyLeft 20 ' ' (cId k) <> T.justifyLeft 46 ' ' (en (cTitle k)) <> en (cRef k))
  ["guide", l] | Just lang <- lookup l [("en", En), ("fr", Fr)] -> TIO.putStr (guide lang (T.pack release))
  ["frameworks"] -> forM_ frameworks $ \f -> let (a, n) = coverage f in BL.putStrLn . encode $ object
    [ "framework" .= fName f, "where" .= phrase (fWhere f), "basis" .= phrase (fBasis f), "source" .= fUrl f, "addressed" .= a, "of" .= n
    , "open" .= [x | x <- fParts f, not (S.member x addressed)] ]
  ["--version"] -> putStrLn ("releve " <> release <> " · criteria v" <> T.unpack version)
  _ -> hPutStrLn stderr usage >> exitWith (ExitFailure 2)

phrase :: Phrase -> Value
phrase x = object ["en" .= en x, "fr" .= fr x]

die :: String -> IO a
die m = hPutStrLn stderr ("releve: " <> m) >> exitWith (ExitFailure 1)

records :: FilePath -> IO [Record]
records c = load c >>= either (die . (<> "; the corpus is damaged there, restore it from a copy")) pure

-- | Observations read from stdin and sealed in memory: a corpus that is never written.
passing :: IO [Record]
passing = do
  ls <- filter (not . BC.null) . BC.lines <$> BC.getContents
  os <- either (die . ("not an observation: " <>)) pure (mapM eitherDecodeStrict ls) :: IO [Observation]
  pure (foldl (\rs o -> rs ++ [next rs (toJSON (Observed o))]) [] os)

sealed :: FilePath -> IO [Record]
sealed c = do
  rs <- records c
  either (\n -> die ("corpus broken at record " <> show n <> "; refusing to write")) (const (pure rs)) (verify rs)

withState :: FilePath -> (State -> IO ()) -> IO ()
withState c k = records c >>= either die k . build

ingest :: FilePath -> IO ()
ingest c = do
  rs <- sealed c
  ls <- filter (not . BC.null) . BC.lines <$> BC.getContents
  go rs ls
  where
    go _ [] = pure ()
    go rs (l : ls) = case eitherDecodeStrict l :: Either String Observation of
      Left e -> die ("not an observation: " <> e)
      Right o -> do
        let r = next rs (toJSON (Observed o))
        append c r
        TIO.putStrLn (T.take 8 (rHash r) <> "  " <> url o)
        go (rs ++ [r]) ls

correct :: FilePath -> IO ()
correct c = do
  rs <- sealed c
  doc <- TIO.getContents
  st <- either die pure (build rs)
  cs <- either (die . T.unpack) pure (corrections st doc)
  let add acc x = do
        let r = next acc (toJSON (Corrected x))
        append c r
        pure (acc ++ [r])
  foldM_ add rs cs
  hPutStrLn stderr (show (length cs) <> " correction" <> (if length cs == 1 then "" else "s") <> " recorded")

declare :: FilePath -> IO ()
declare c = do
  rs <- sealed c
  doc <- TIO.getContents
  st <- either die pure (build rs)
  ds <- either (die . T.unpack) pure (declaring st doc)
  let add acc x = do
        let r = next acc (toJSON (Declared x))
        append c r
        pure (acc ++ [r])
  foldM_ add rs ds
  hPutStrLn stderr (show (length ds) <> " declaration" <> (if length ds == 1 then "" else "s") <> " recorded")
