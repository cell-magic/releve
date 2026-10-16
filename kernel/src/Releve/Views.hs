-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
{-# LANGUAGE OverloadedStrings #-}
-- | The two readings of an observation.
--   facts: what the page is, one checkable line per finding, for a person.
--   atlas: what the page could become, as data, for later study.
module Releve.Views (facts, factsAll, atlas, corrections, declarations, declaring) where

import Control.Monad (foldM)
import Data.Aeson
import Data.Char (isPunctuation, isSymbol)
import Data.List (nub, sortOn)
import qualified Data.Map.Strict as M
import Data.Maybe (fromMaybe, listToMaybe, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Releve.Criteria (criteria, version)
import Releve.Declarations
import Releve.Footprint
import Releve.Kernel
import Releve.Reading
import Releve.Types

-- facts -------------------------------------------------------------------

facts :: State -> Obs -> Text
facts = factsOf []

-- | The latest report of every page, then, for pages that share a template,
--   the questions asked once for them all. A page's report leaves those out.
factsAll :: State -> Text
factsAll st = T.intercalate "\n---\n\n" (map page' (latest st) ++ map whole groups)
  where
    ps = pools st
    page' o = factsOf [fId f | p <- ps, (x, f) <- pEntries p, oId x == oId o] st o
    groups = nub (map pKey ps)
    whole k = let mine = [p | p <- ps, pKey p == k]; ws = nub [url (oBody o) | p <- mine, (o, _) <- pEntries p] in T.unlines $
      [ "# Relevé · the whole site · " <> maybe "" pHost (listToMaybe mine), ""
      , "Template `" <> k <> "` · " <> plural (length ws) "page" <> " built on the same style sheets and scripts", "" ]
      ++ [ "- " <> w | w <- ws ]
      ++ [ "", "Asked once for these pages. An answer holds on each page counted with it while the page keeps this template;"
         , "a page that changes its style sheets or scripts is asked again, and so is a page first seen later."
         , "To answer, change a line's verdict word or add a note after `//`, then run `releve correct`.", ""
         , "## Shared (" <> T.pack (show (length mine)) <> ")", "" ]
      ++ map shared mine
    shared p = let (v, n, mixed) = pooled p in T.concat
      [ "- **", word v, "** ", cId (fCrit (pFinding p)), " · ", plural (length (pEntries p)) "page"
      , if length (pEntries p) < length (nub [oId o | q <- ps, pKey q == pKey p, (o, _) <- pEntries q]) then " (" <> T.intercalate ", " [path' (url (oBody o)) | (o, _) <- pEntries p] <> ")" else ""
      , " · ", esc (T.replace " · this page" "" (en (fSeen (pFinding p)))), maybe "" ((" → " <>) . esc . en) (fChange (pFinding p))
      , if mixed then " · answered otherwise on some pages" else ""
      , maybe "" ((" // " <>) . esc) n, " {", fId (pFinding p), "}" ]
    path' u = let r = T.dropWhile (/= '/') (snd (T.breakOnEnd "://" u)) in if T.null r then "/" else r

-- | How a question asked once reads: the answer all its pages share, or open.
pooled :: Pool -> (Verdict, Maybe Text, Bool)
pooled p = case nub [ (fVerdict f, fNote f) | (_, f) <- pEntries p ] of
  [(v, n)] -> (v, n, False)
  _ -> (Review, Nothing, True)

factsOf :: [Text] -> State -> Obs -> Text
factsOf asked st o = T.unlines $
  [ "# Relevé · " <> url b, ""
  , "Observation `" <> oId o <> "` · " <> at b <> " · criteria v" <> version
      <> maybe "" (\h -> " · screenshot `" <> T.take 16 h <> "`") (shot b)
      <> maybe "" (" · " <>) (browser b)
      <> maybe "" (\m -> " · under mandate " <> esc m) (mandate b) <> "  "
  , T.intercalate " · " (T.pack (show (length (surfaces b))) <> " surfaces" : [count v | v <- [Fail, Review, Hint, Pass]])
      <> " · " <> since
      <> (if truncated (page b) == Just True then " · page too large: only its first surfaces were read" else ""), ""
  , "Automated observation of one rendered page; not a conformity audit. REVIEW lines need a person's judgement."
  , "To correct a line, change its verdict word or add a note after `//`, then run `releve correct`."
  ]
  ++ concat [section v | v <- [Fail, Review, Hint]]
  ++ overruled
  ++ (case length (nub asked) of
        0 -> []
        k -> ["", "## Shared (" <> T.pack (show k) <> ")", ""
             , plural k "question" <> " asked once for this page and others built on the same template: under “the whole site”."])
  ++ ["", "## By criterion", ""] ++ passes
  ++ ["", "## Footprint", ""] ++ weight
  ++ maybe [] (\r -> ["", "## Reading", ""] ++ lecture b r) (readingOf b fs)
  where
    b = oBody o
    fs = assess st o
    count v = T.pack (show (length [f | f <- fs, fVerdict f == v])) <> " " <> T.toLower (word v)
    since = case previous st o of
      [] -> "first observation of this page"
      (p : _) -> "since `" <> oId p <> "`: " <> T.pack (show (length [f | f <- fs, fNew f, fVerdict f /= Pass])) <> " open on new surfaces"
    own = [f | f <- fs, fId f `notElem` asked]
    section v = case sortOn place [f | f <- own, fVerdict f == v] of
      [] -> []
      xs -> ["", "## " <> T.toTitle (word v) <> " (" <> T.pack (show (length xs)) <> ")", ""] ++ map line xs
    overruled = case sortOn place [f | f <- own, fVerdict f == Pass, fMachine f /= Pass] of
      [] -> []
      xs -> ["", "## Passed on review (" <> T.pack (show (length xs)) <> ")", ""] ++ map line xs
    place f = (position (cId (fCrit f)), maybe 0 order (fSurface f))
    position c = fromMaybe 0 (lookup c (zip (map cId criteria) [0 :: Int ..]))
    line f = T.concat
      [ "- **", word (fVerdict f), "** ", cId (fCrit f), " · ", locus f, " · ", esc (en (fSeen f))
      , maybe "" ((" → " <>) . esc . en) (fChange f)
      , if fNew f then " · new" else ""
      , if fAge f > 0 then " · standing " <> T.pack (show (fAge f)) else ""
      , if fLapsed f then " · read otherwise before this changed" else ""
      , if fVerdict f /= fMachine f then " · machine said " <> word (fMachine f) else ""
      , maybe "" ((" // " <>) . esc) (fNote f)
      , " {", fId f, "}" ]
    locus f = maybe "page" (\s -> "`" <> T.replace "`" "'" (sel s) <> "`") (fSurface f)
    passes =
      [ "- " <> cId c <> ": " <> summary c | c <- criteria ]
    summary c = case [f | f <- fs, cId (fCrit f) == cId c] of
      xs | all ((== NA) . fVerdict) xs -> "n/a · " <> esc (maybe "" (en . fSeen) (listToMaybe xs))
         | otherwise -> T.pack (show (length [f | f <- xs, fVerdict f == Pass])) <> " of " <> T.pack (show (length xs)) <> " pass"
    Footprint e r kb hs ch = footprint b
    weight =
      [ "- " <> plural e "element" <> " · " <> plural r "request" <> " · "
          <> T.pack (show (round kb :: Int)) <> " kB transferred · " <> plural (length hs) "third-party host" ]
      ++ [ "- third-party hosts: " <> T.intercalate ", " hs | not (null hs) ]
      ++ [ "- longest chain: " <> plural (length ch) "request" <> ", each asked for by the one before · " <> esc (T.intercalate " → " (map named ch)) | length ch > 2 ]

lecture :: Observation -> Reading -> [Text]
lecture b r =
  [ "- " <> plural (rEvents r) "event" <> " · " <> n (rUnsaid r) <> " shown and not said · " <> n (rUnshown r) <> " said and not shown"
  , "- depth " <> n (rDepth r) <> ": the longest run the markup obliges"
  , "- the page says " <> plural spoken "byte" <> "; " <> plural (transfer (network b) `div` max 1 spoken) "byte" <> " travel for each"
  , "- one at a time, by ear: " <> plural (rSerial r) "step"
  , "- up to " <> n ceiling' <> " at a time: " <> plural (rSteps r) "step" <> " as the page stands · " <> n (rClear r)
      <> " with nothing failing (between " <> n (rLower r) <> " and " <> n (rUpper r) <> " at this depth and size)" ]
  ++ [ "- mending, in order: " <> T.intercalate ", " [ c <> " leaves " <> plural k "step" | (c, k) <- rMending r ] | not (null (rMending r)) ]
  where
    n = T.pack . show
    spoken = round (rBits r / 8) :: Int

-- | The order of a reading as data: an event by its number, a series, a parallel.
sequence' :: Shape -> Value
sequence' (One e) = toJSON (eN e)
sequence' (Series xs) = object ["series" .= map sequence' xs]
sequence' (Parallel xs) = object ["parallel" .= map sequence' xs]

plural :: Int -> Text -> Text
plural n w = T.pack (show n) <> " " <> w <> (if n == 1 then "" else "s")

-- | Text that came from a page, made safe for one line of Markdown:
--   punctuation backslash-escaped, line breaks turned into spaces.
esc :: Text -> Text
esc = T.concatMap $ \c -> case c of
  _ | c `elem` ("\\`*_[]</" :: String) -> T.pack ['\\', c]
    | c `elem` ("\n\r\x2028\x2029\x85" :: String) -> " "
    | otherwise -> T.singleton c

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
          let ref = between l
          o <- maybe (Left ("unknown observation " <> ref)) Right (resolve st (Just ref))
          pure (Just (M.fromList [ (fId f, (fVerdict f, fNote f, \v n -> Correction (oId o) (fId f) v n (en (fSeen f)) Nothing Nothing)) | f <- assess st o ]), True, cs)
      -- Questions asked once for pages that share a template: an answer covers every page counted with it.
      | "Template `" `T.isPrefixOf` l = do
          let ref = between l
          case [p | p <- pools st, pKey p == ref] of
            [] -> Left ("unknown template " <> ref <> ": its pages have changed since this document was made")
            mine -> pure (Just (M.fromList [ (fId f, (v0, n0, \v n -> Correction (oId (fst (head (pEntries p)))) (fId f) v n (en (fSeen f)) (Just [oId x | (x, _) <- pEntries p]) (Just (pTemplate p))))
                                          | p <- mine, let f = pFinding p, let (v0, n0, _) = pooled p ]), True, cs)
      | Just known <- cur = case reading known l of
          Just ((v0, n0, mk), v, n) | v == v0 && n == n0 -> pure (cur, found, cs)
                                    | otherwise -> pure (cur, found, mk v n : cs)
          -- A finding's line that no longer reads as one is an edit about to be lost: say so, record nothing.
          Nothing | any (\i -> ("{" <> i <> "}") `T.isInfixOf` l) (M.keys known) ->
                      Left ("this line cannot be read; keep its form, - **VERDICT** … // note {id}\n  " <> l)
                  | otherwise -> pure (cur, found, cs)
      | otherwise = pure (cur, found, cs)
    between l = T.takeWhile (/= '`') (T.drop 1 (snd (T.breakOn "`" l)))
    reading known l = do
      rest <- T.stripPrefix "- **" l
      v <- readWord (T.takeWhile (/= '*') rest)
      let (body, idPart) = T.breakOnEnd " {" l
      f <- T.stripSuffix "}" (T.strip idPart) >>= (`M.lookup` known)
      let n = case T.strip (unesc (T.drop 4 (snd (T.breakOn " // " (T.dropEnd 2 body))))) of
                "" -> Nothing
                x -> Just x
      pure (f, v, n)

-- atlas -------------------------------------------------------------------

atlas :: State -> Obs -> Value
atlas st o = object
  [ "observation" .= oId o, "url" .= url b, "requested" .= fromMaybe (url b) (requested b)
  , "at" .= at b, "criteria" .= version, "browser" .= browser b, "truncated" .= (truncated (page b) == Just True)
  , "shape" .= mapMaybe token (sortOn order (surfaces b))
  , "footprint" .= object ["elements" .= e, "requests" .= r, "kilobytes" .= kb, "thirdParties" .= hs, "chain" .= ch]
  , "change" .= object
      [ "since" .= (oId <$> listToMaybe (previous st o))
      , "new" .= length fresh
      , "fits" .= length [k | k <- fresh, k `notElem` broken]
      , "breaks" .= length [k | k <- fresh, k `elem` broken] ]
  , "findings" .= [ finding f | f <- fs, fVerdict f /= Pass || fMachine f /= Pass, fVerdict f /= NA ]
  , "passes" .= M.fromListWith (+) [(cId (fCrit f), 1 :: Int) | f <- fs, fVerdict f == Pass]
  , "reading" .= fmap (\r -> object
      [ "events" .= rEvents r, "unsaid" .= rUnsaid r, "unshown" .= rUnshown r, "depth" .= rDepth r
      , "bits" .= (round (rBits r) :: Int), "serial" .= rSerial r, "steps" .= rSteps r, "clear" .= rClear r
      , "lower" .= rLower r, "upper" .= rUpper r, "mending" .= [object ["criterion" .= c, "steps" .= k] | (c, k) <- rMending r]
      , "order" .= fmap sequence' (rShape r) ]) (readingOf b fs)
  ]
  where
    b = oBody o
    fs = assess st o
    Footprint e r kb hs ch = footprint b
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
      , "note" .= fNote f, "seen" .= en (fSeen f), "change" .= fmap en (fChange f), "new" .= fNew f, "age" .= fAge f, "lapsed" .= fLapsed f
      , "surface" .= fSurface f ]

-- declarations ------------------------------------------------------------

-- | The criteria no rule can see from a page, with the owner's answers in force
--   and what the latest observation saw, one line each: the document the owner
--   edits and gives back to `releve declare`.
declarations :: State -> Text
declarations st = T.unlines $
  [ "# Declarations · RGESN 2024 · RGAA 4.1.2", ""
  , T.pack (show (length items)) <> " criteria no rule can see from a page, declared by the service's owner for the whole record."
  , "To answer, set yes, no, n/a or open after the criterion and a note after `//`, then run `releve declare`."
  , "The official texts prevail: https://ecoresponsable.numerique.gouv.fr/publications/referentiel-general-ecoconception/ and https://accessibilite.numerique.gouv.fr/methode/criteres-et-tests/" ]
  ++ concat [ ["", "## " <> en (family f), ""] ++ [ line i | i <- items, family i == family f ] | f <- nub' items ]
  where
    nub' = foldl (\acc x -> if any ((== family x) . family) acc then acc else acc ++ [x]) []
    o = oBody <$> resolve st Nothing
    line i = let d = M.lookup (cited i) (declared st) in T.concat
      [ "- ", cited i, " · ", maybe "open" dAnswer d, " · ", esc (en (iAsk i))
      , maybe "" (\x -> " · seen: " <> esc (en x)) (o >>= iSeen i)
      , maybe "" ((" // " <>) . esc) (d >>= dNote) ]

-- | Read an edited declarations document back: each line whose answer or note
--   changed becomes a declaration. A line that cannot be read is refused, with
--   everything else: an owner's answer is never dropped in silence.
declaring :: State -> Text -> Either Text [Declaration]
declaring st doc = fmap concat (mapM one [l | l <- T.lines doc, any (`T.isPrefixOf` l) ["- RGESN ", "- RGAA "]])
  where
    known = map cited items
    one l = do
      let (i, after) = T.breakOn " · " (T.drop 2 l)
          answer' = T.strip (T.takeWhile (/= ' ') (T.drop 3 after))
          n = case T.strip (unesc (T.drop 4 (snd (T.breakOn " // " l)))) of
                "" -> Nothing
                x -> Just x
      if i `notElem` known then Left ("no such declared criterion: " <> i <> "\n  " <> l)
      else if answer' `notElem` ["yes", "no", "n/a", "open"] then Left ("the answer is yes, no, n/a or open\n  " <> l)
      else let now = M.lookup i (declared st)
               was = (maybe "open" dAnswer now, now >>= dNote)
           in pure [Declaration i answer' n | (answer', n) /= was, not (answer' == "open" && isNothing' now)]
    isNothing' = maybe True (const False)
