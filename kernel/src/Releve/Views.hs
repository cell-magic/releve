-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
{-# LANGUAGE OverloadedStrings #-}
-- | The two readings of an observation.
--   facts: what the page is, one checkable line per finding, for a person.
--   atlas: what the page could become, as data, for later study.
module Releve.Views (facts, atlas, corrections) where

import Control.Monad (foldM)
import Data.Aeson
import Data.Char (isPunctuation, isSymbol)
import Data.List (sortOn)
import qualified Data.Map.Strict as M
import Data.Maybe (fromMaybe, listToMaybe, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Releve.Criteria (criteria, version)
import Releve.Footprint
import Releve.Kernel
import Releve.Types

-- facts -------------------------------------------------------------------

facts :: State -> Obs -> Text
facts st o = T.unlines $
  [ "# Relevé · " <> url b, ""
  , "Observation `" <> oId o <> "` · " <> at b <> " · criteria v" <> version
      <> maybe "" (\h -> " · screenshot `" <> T.take 16 h <> "`") (shot b)
      <> maybe "" (" · " <>) (browser b)
      <> maybe "" (\m -> " · under mandate " <> esc m) (mandate b) <> "  "
  , T.intercalate " · " (T.pack (show (length (surfaces b))) <> " surfaces" : [count v | v <- [Fail, Review, Hint, Pass]])
      <> " · " <> since, ""
  , "Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement."
  , "To correct a line, change its verdict word or add a note after `//`, then run `releve correct`."
  ]
  ++ concat [section v | v <- [Fail, Review, Hint]]
  ++ overruled
  ++ ["", "## By criterion", ""] ++ passes
  ++ ["", "## Footprint", ""] ++ weight
  where
    b = oBody o
    fs = assess st o
    count v = T.pack (show (length [f | f <- fs, fVerdict f == v])) <> " " <> T.toLower (word v)
    since = case previous st o of
      [] -> "first observation of this page"
      (p : _) -> "since `" <> oId p <> "`: " <> T.pack (show (length [f | f <- fs, fNew f, fVerdict f /= Pass])) <> " open on new surfaces"
    section v = case sortOn place [f | f <- fs, fVerdict f == v] of
      [] -> []
      xs -> ["", "## " <> T.toTitle (word v) <> " (" <> T.pack (show (length xs)) <> ")", ""] ++ map line xs
    overruled = case sortOn place [f | f <- fs, fVerdict f == Pass, fMachine f /= Pass] of
      [] -> []
      xs -> ["", "## Passed on review (" <> T.pack (show (length xs)) <> ")", ""] ++ map line xs
    place f = (position (cId (fCrit f)), maybe 0 order (fSurface f))
    position c = fromMaybe 0 (lookup c (zip (map cId criteria) [0 :: Int ..]))
    line f = T.concat
      [ "- **", word (fVerdict f), "** ", cId (fCrit f), " · ", locus f, " · ", esc (fSeen f)
      , maybe "" ((" → " <>) . esc) (fChange f)
      , if fNew f then " · new" else ""
      , if fAge f > 0 then " · standing " <> T.pack (show (fAge f)) else ""
      , if fVerdict f /= fMachine f then " · machine said " <> word (fMachine f) else ""
      , maybe "" ((" // " <>) . esc) (fNote f)
      , " {", fId f, "}" ]
    locus f = maybe "page" (\s -> "`" <> T.replace "`" "'" (sel s) <> "`") (fSurface f)
    passes =
      [ "- " <> cId c <> ": " <> summary c | c <- criteria ]
    summary c = case [f | f <- fs, cId (fCrit f) == cId c] of
      xs | all ((== NA) . fVerdict) xs -> "n/a · " <> esc (maybe "" fSeen (listToMaybe xs))
         | otherwise -> T.pack (show (length [f | f <- xs, fVerdict f == Pass])) <> " of " <> T.pack (show (length xs)) <> " pass"
    Footprint e r kb hs = footprint b
    weight =
      [ "- " <> plural e "element" <> " · " <> plural r "request" <> " · "
          <> T.pack (show (round kb :: Int)) <> " kB transferred · " <> plural (length hs) "third-party host" ]
      ++ [ "- third-party hosts: " <> T.intercalate ", " hs | not (null hs) ]

plural :: Int -> Text -> Text
plural n w = T.pack (show n) <> " " <> w <> (if n == 1 then "" else "s")

-- | Backslash-escape Markdown punctuation in text that came from a page.
esc :: Text -> Text
esc = T.concatMap (\c -> if c `elem` ("\\`*_[]</" :: String) then T.pack ['\\', c] else T.singleton c)

unesc :: Text -> Text
unesc t = case T.uncons t of
  Just ('\\', r) | Just (c, r') <- T.uncons r, isPunctuation c || isSymbol c -> T.cons c (unesc r')
  Just (c, r) -> T.cons c (unesc r)
  Nothing -> ""

-- | Read an edited facts document back: the changes a person made become
--   corrections. Lines they did not touch produce nothing. A document may
--   hold several reports; each header sets the observation for the lines
--   beneath it.
corrections :: State -> Text -> Either Text [Correction]
corrections st doc = do
  (_, found, cs) <- foldM step (Nothing, False, []) (T.lines doc)
  if found then Right (reverse cs) else Left "no observation id in the header"
  where
    step (cur, found, cs) l
      | "Observation `" `T.isPrefixOf` l = do
          let ref = T.takeWhile (/= '`') (T.drop 1 (snd (T.breakOn "`" l)))
          o <- maybe (Left ("unknown observation " <> ref)) Right (resolve st (Just ref))
          pure (Just (o, M.fromList [(fId f, f) | f <- assess st o]), True, cs)
      | Just (o, known) <- cur, Just c <- edit o known l = pure (cur, found, c : cs)
      | otherwise = pure (cur, found, cs)
    edit o known l = do
      rest <- T.stripPrefix "- **" l
      v <- readWord (T.takeWhile (/= '*') rest)
      let (body, idPart) = T.breakOnEnd " {" l
      i <- T.stripSuffix "}" (T.strip idPart)
      f <- M.lookup i known
      let n = case T.breakOnEnd " // " (T.dropEnd 2 body) of
                ("", _) -> Nothing
                (_, x) -> let x' = T.strip (unesc x) in if T.null x' then Nothing else Just x'
      if v == fVerdict f && n == fNote f then Nothing
        else Just (Correction (oId o) i v n (fSeen f))

-- atlas -------------------------------------------------------------------

atlas :: State -> Obs -> Value
atlas st o = object
  [ "observation" .= oId o, "url" .= url b, "requested" .= fromMaybe (url b) (requested b)
  , "at" .= at b, "criteria" .= version, "browser" .= browser b
  , "shape" .= mapMaybe token (sortOn order (surfaces b))
  , "footprint" .= object ["elements" .= e, "requests" .= r, "kilobytes" .= kb, "thirdParties" .= hs]
  , "change" .= object
      [ "since" .= (oId <$> listToMaybe (previous st o))
      , "new" .= length fresh
      , "fits" .= length [k | k <- fresh, k `notElem` broken]
      , "breaks" .= length [k | k <- fresh, k `elem` broken] ]
  , "findings" .= [ finding f | f <- fs, fVerdict f /= Pass || fMachine f /= Pass, fVerdict f /= NA ]
  , "passes" .= M.fromListWith (+) [(cId (fCrit f), 1 :: Int) | f <- fs, fVerdict f == Pass]
  ]
  where
    b = oBody o
    fs = assess st o
    Footprint e r kb hs = footprint b
    lastKeys = maybe [] (map key . surfaces . oBody) (listToMaybe (previous st o))
    fresh = if null (previous st o) then [] else [key x | x <- surfaces b, key x `notElem` lastKeys]
    broken = [key x | f <- fs, fVerdict f == Fail, Just x <- [fSurface f]]
    token x = case kind x of
      "landmark" -> role x
      "heading" -> (\n -> "h" <> T.pack (show n)) <$> level x
      "control" -> Just "field"
      "button" -> Just "button"
      "img" -> Just "image"
      "media" -> Just "media"
      "iframe" -> Just "frame"
      _ -> Nothing
    finding f = object
      [ "id" .= fId f, "criterion" .= cId (fCrit f), "machine" .= fMachine f, "verdict" .= fVerdict f
      , "note" .= fNote f, "seen" .= fSeen f, "change" .= fChange f, "new" .= fNew f, "age" .= fAge f
      , "surface" .= fSurface f ]
