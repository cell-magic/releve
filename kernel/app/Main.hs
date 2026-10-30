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
import Releve.Statement
import Releve.Types
import Releve.Views
import Stamp
import qualified Plie.Bridge
import qualified Plie.Entries
import Data.Maybe (listToMaybe)

usage :: String
usage = unlines
  [ "releve — judge observed web pages; keep every reading"
  , ""
  , "  observe URL | releve ingest CORPUS    record observations (JSON lines on stdin)"
  , "  releve facts CORPUS [ID|URL|--all]    the checkable report, as Markdown"
  , "  releve report en|fr CORPUS [--ask]    the report for the pages' owner, as HTML;"
  , "                                        CORPUS may be - : observations on stdin, nothing kept;"
  , "                                        --ask: each point to decide with the controls to answer it"
  , "  releve statement en|fr CORPUS        draft accessibility statement and eco-design declaration,"
  , "                                        as HTML, for the owner to complete"
  , "  releve rules -                        the rule results of each observation on stdin, as JSON lines:"
  , "                                        per criterion, the WCAG success criteria it reads and how many"
  , "                                        marks it gave, by machine label (fail, review, hint); nothing kept"
  , "  releve core FUNCTION < input.json      a function of the record's core (written in plié, record/*.plie)"
  , "                                        on JSON, its answer as canonical JSON (RFC 8785)"
  , "  releve correct CORPUS < facts.md      record a person's edits to a report"
  , "  releve declarations CORPUS            the criteria no rule can see, with the owner's answers"
  , "  releve declare CORPUS < answers.md    record the owner's edits to the declarations"
  , "  releve atlas CORPUS                   every observation as study data (JSON lines)"
  , "  releve history CORPUS                 every point that stood open on each page, when it opened and"
  , "                                        when it was seen closed (JSON lines)"
  , "  releve verify CORPUS [--export DIR]   check the corpus seals and each time stamp; with --export,"
  , "                                        write each stamp's reply to DIR and the OpenSSL command that checks it"
  , "  releve stamp CORPUS [AUTHORITY]       have a time-stamping authority (RFC 3161) date the latest record;"
  , "                                        needs openssl and curl"
  , "  releve criteria                       list the criteria and their sources"
  , "  releve guide en|fr                    the criteria and what each is for, as HTML"
  , "  releve frameworks                     each law and standard, and how many of its provisions"
  , "                                        the criteria address (JSON lines)"
  , "  releve --version" ]

-- | The release, as in releve.cabal; tests/run.py holds the two together.
release :: String
release = "0.10.0"

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
  ["statement", l, c] | Just lang <- lookup l [("en", En), ("fr", Fr)] -> withState c (TIO.putStr . statements lang (T.pack release))
  ["rules", "-"] -> do
    ls <- filter (not . BC.null) . BC.lines <$> BC.getContents
    os <- either (die . ("not an observation: " <>)) pure (mapM eitherDecodeStrict ls) :: IO [Observation]
    forM_ os $ \o -> BL.putStrLn . encode $ object
      [ "url" .= url o, "criteria" .= version, "release" .= release
      , "rules" .= [ object ["criterion" .= cId c, "wcag" .= wcagOf c, "fail" .= n Fail ms, "review" .= n Review ms, "hint" .= n Hint ms]
                   | (c, ms) <- markedBy o ] ]
  ["core", f] -> BC.getContents >>= either die TIO.putStrLn . Plie.Bridge.call Plie.Entries.entries (T.pack f)
  ["correct", c] -> correct c
  ["declarations", c] -> withState c (TIO.putStr . declarations)
  ["declare", c] -> declare c
  ["history", c] -> withState c $ \st -> forM_ (latest st) $ \o -> forM_ (history st o) $ \x ->
    let f = sFinding x; when' = fmap (at . oBody) in BL.putStrLn . encode $ object
      [ "page" .= url (oBody o), "finding" .= fId f, "criterion" .= cId (fCrit f), "where" .= fmap sel (fSurface f)
      , "seen" .= en (fSeen f), "verdict" .= T.toLower (T.pack (show (fVerdict f)))
      , "opened" .= when' (Just (sOpened x)), "opened_in" .= oId (sOpened x)
      , "closed" .= when' (sClosed x), "closed_in" .= fmap oId (sClosed x)
      , "closed_by" .= fmap (const (if sAnswered x then "answer" else "page" :: T.Text)) (sClosed x)
      , "dated" .= (sClosed x >>= datedBy st >>= \d -> Just (object ["time" .= stTime d, "tsa" .= stTsa d])) ]
  ["atlas", c] -> withState c $ \st -> forM_ (observations st) (BL.putStrLn . encode . atlas st)
  ("verify" : c : rest) | rest == [] || take 1 rest == ["--export"] && length rest == 2 -> records c >>= \rs -> case verify rs of
    Left n -> die ("broken at record " <> show n)
    Right n -> do
      putStrLn ("sealed · " <> show n <> (if n == 1 then " record" else " records")
                  <> concat [" · head " <> T.unpack (T.take 8 (rHash (last rs))) | not (null rs)])
      st <- either die pure (build rs)
      checked <- check [ (k, rPrev (rs !! k), x) | (k, x) <- stamps st ]
      forM_ checked $ \(k, x, ok) -> putStrLn ("dated · " <> T.unpack (stTime x) <> " · " <> T.unpack (stTsa x) <> " · covers record " <> show (k - 1)
                                                 <> either (" · NOT VERIFIED: " <>) (const " · signature verified") ok)
      case rest of
        [_, dir] -> export dir (stamps st) >>= mapM_ putStrLn
        _ -> pure ()
      if all (\(_, _, ok) -> either (const False) (const True) ok) checked then pure () else exitWith (ExitFailure 1)
  ("stamp" : c : rest) | length rest <= 1 -> do
    rs <- sealed c
    if null rs then die "nothing to date: the corpus is empty" else pure ()
    r <- request (maybe authority id (listToMaybe rest)) (rHash (last rs))
    case r of
      Left e -> die ("not dated: " <> e)
      Right x -> do
        append c (next rs (toJSON (Stamped x)))
        putStrLn ("dated · " <> T.unpack (stTime x) <> " · " <> T.unpack (stTsa x) <> " · covers record " <> show (length rs - 1) <> " · head " <> T.unpack (T.take 8 (stHead x)))
  ["criteria"] -> do
    putStrLn ("criteria v" <> T.unpack version)
    forM_ criteria $ \k -> TIO.putStrLn (T.justifyLeft 20 ' ' (cId k) <> T.justifyLeft 46 ' ' (en (cTitle k)) <> en (cRef k))
  ["guide", l] | Just lang <- lookup l [("en", En), ("fr", Fr)] -> TIO.putStr (guide lang (T.pack release))
  ["frameworks"] -> forM_ frameworks $ \f -> let (a, n) = coverage f in BL.putStrLn . encode $ object
    [ "framework" .= fName f, "where" .= phrase (fWhere f), "basis" .= phrase (fBasis f), "source" .= fUrl f, "addressed" .= a, "of" .= n
    , "open" .= [x | x <- fParts f, not (S.member x addressed)] ]
  ["--version"] -> putStrLn ("releve " <> release <> " · criteria v" <> T.unpack version)
  _ -> hPutStrLn stderr usage >> exitWith (ExitFailure 2)

-- | Each criterion's marks on an observation, as the machine gave them: no person's reading enters.
markedBy :: Observation -> [(Criterion, [Mark])]
markedBy o = [ (c, [m | (_, c', m) <- js, cId c' == cId c]) | c <- criteria ] where js = judged o

n :: Verdict -> [Mark] -> Int
n v = length . filter ((== v) . mVerdict)

-- | The WCAG success criteria a criterion reads: those it cites, and those its RGAA criteria answer to.
wcagOf :: Criterion -> [T.Text]
wcagOf c = S.toAscList (S.fromList (cites "WCAG" c <> concat [ws | r <- cites "RGAA" c, Just ws <- [lookup r crosswalk]]))

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
