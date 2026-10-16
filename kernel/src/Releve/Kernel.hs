-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
{-# LANGUAGE OverloadedStrings #-}
-- | The fold. State is a function of the corpus and nothing else:
--   the same corpus always yields the same findings.
module Releve.Kernel (Obs (..), State, Pool (..), build, observations, latest, resolve, assess, previous, declared, builtOn, host, pools, governing) where

import Data.Aeson (Result (..), fromJSON)
import Data.Char (toLower)
import Data.List (nub, sort, sortOn)
import qualified Data.Map.Strict as M
import Data.Maybe (isJust, listToMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8)
import Releve.Checklist (wholePage)
import Releve.Corpus
import Releve.Criteria
import Releve.Types

data Obs = Obs { oId :: Text, oSeq :: Int, oBody :: Observation }

data State = State
  { byPage :: M.Map Text [Obs]          -- oldest first
  , byId :: M.Map Text Obs
  , fixes :: [(Int, Correction)]       -- in corpus order
  , said :: M.Map Text Declaration }    -- the latest answer to each declared criterion

build :: [Record] -> Either String State
build = foldl step (Right (State M.empty M.empty [] M.empty))
  where
    step (Left e) _ = Left e
    step (Right st) r = case fromJSON (rEvent r) of
      Error e -> Left ("record " <> show (rSeq r) <> ": " <> e)
      Success (Observed o) ->
        let x = Obs (T.take 8 (rHash r)) (rSeq r) o
        in Right st { byPage = M.insertWith (flip (++)) (url o) [x] (byPage st), byId = M.insert (oId x) x (byId st) }
      Success (Corrected c) -> Right st { fixes = fixes st ++ [(rSeq r, c)] }
      Success (Declared d) -> Right st { said = M.insert (dCriterion d) d (said st) }

-- | The owner's answers in force, by criterion; a withdrawn one is not among them.
declared :: State -> M.Map Text Declaration
declared = M.filter ((/= "open") . dAnswer) . said

observations :: State -> [Obs]
observations = sortOn oSeq . M.elems . byId

-- | The latest observation of every page, in the order pages first appeared.
latest :: State -> [Obs]
latest st = [last xs | xs <- sortOn (map oSeq . take 1) (M.elems (byPage st)), not (null xs)]

-- | An observation by id prefix or page URL (latest); the latest overall by default.
resolve :: State -> Maybe Text -> Maybe Obs
resolve st Nothing = listToMaybe (reverse (observations st))
resolve st (Just ref) = case M.lookup ref (byPage st) of
  Just xs -> listToMaybe (reverse xs)
  Nothing -> listToMaybe [o | o <- observations st, ref `T.isPrefixOf` oId o]

-- | Earlier observations of the same page, newest first.
previous :: State -> Obs -> [Obs]
previous st o = reverse (takeWhile ((< oSeq o) . oSeq) (M.findWithDefault [] (url (oBody o)) (byPage st)))

-- | Every mark of every criterion, with a stable identity: the criterion
--   and the surface it concerns, so the same defect keeps its id across time.
judged :: Observation -> [(Text, Criterion, Mark)]
judged o = concat [ [(ident c ms m, c, m) | m <- ms] | c <- criteria, let ms = cJudge c o ]
  where
    ident c ms m = T.take 8 . sha . encodeUtf8 $ cId c <> ":" <> place ms m
    place ms m = case mSurface m of
      Just s -> key s
      Nothing | length [() | x <- ms, null (mSurface x)] > 1 -> "page:" <> en (mSeen m)
              | otherwise -> "page"

assess :: State -> Obs -> [Finding]
assess st o = [ mk i c m | (i, c, m) <- judged (oBody o) ]
  where
    before = previous st o
    lastKeys = maybe [] (map key . surfaces . oBody) (listToMaybe before)
    earlier = [ [i | (i, v) <- applied st p, open v] | p <- before ]
    mk i c m =
      let fix = correction st o i (en (mSeen m))
          lapsed = null fix && maybe False ((/= mVerdict m) . verdict) (listToMaybe (readings st o i))
          v | lapsed = Review
            | otherwise = maybe (mVerdict m) verdict fix
          fresh = not (null before) && maybe False ((`notElem` lastKeys) . key) (mSurface m)
          age = if open v then length (takeWhile (i `elem`) earlier) else 0
      in Finding i c (mVerdict m) v (fix >>= note) (mSurface m) (mSeen m) (mChange m) fresh age lapsed (mAsk m)
    open v = v `elem` [Fail, Review, Hint]

-- | Each finding's verdict after a person's corrections, without history.
applied :: State -> Obs -> [(Text, Verdict)]
applied st o = [ (i, maybe (mVerdict m) verdict (correction st o i (en (mSeen m)))) | (i, _, m) <- judged (oBody o) ]

-- | A person's readings of a finding, on this observation and on earlier ones
--   of the same page: the nearest observation first; within it, the latest.
--   Then the answers given once for pages that share a template, the latest
--   first: a page's own reading comes before what was said of it with others.
readings :: State -> Obs -> Text -> [Correction]
readings st o i = own ++ shared
  where
    scope = zip (oId o : map oId (previous st o)) [0 :: Int ..]
    own = map snd (sortOn fst [ ((d, negate n), c) | (n, c) <- fixes st, finding c == i, null (covers c), Just d <- [lookup (obs c) scope] ])
    shared = map snd (sortOn (negate . fst) [ (n, c) | (n, c) <- fixes st, finding c == i, Just xs <- [covers c], any ((`elem` xs) . fst) scope ])

-- | The correction that governs a finding: one made on this observation, or
--   the nearest earlier one made while what is seen read the same.
--
--   What is seen can change because the page changed, or because the judge
--   words it differently. Either way an earlier reading that differed from the
--   machine's no longer applies, and the machine's must not quietly replace
--   it: `assess` hands such a finding back to a person, as a Review.
--
--   An answer given for pages that share a template governs while the page is
--   still built on it: one that changed its styles or scripts is asked again.
correction :: State -> Obs -> Text -> Text -> Maybe Correction
correction st o i s = listToMaybe [ c | c <- readings st o i, governs c ]
  where
    governs c = case covers c of
      Nothing -> obs c == oId o || seen c == s
      Just _ -> isJust (template c) && template c == builtOn (oBody o) && seen c == s

-- | The correction that governs a finding, if any.
governing :: State -> Obs -> Finding -> Maybe Correction
governing st o f = correction st o (fId f) (en (fSeen f))

-- | The address's host, in lower case.
host :: Observation -> Text
host o = T.map toLower (T.takeWhile (`notElem` ("/?#" :: String)) (snd (T.breakOnEnd "://" (url o))))

-- | What a page is built on: its host, the style sheets and scripts it loads, each
--   with its size, and the style sheets written into it. Fonts are left out: a
--   browser fetches only those a page's words use. So is the text of inline
--   scripts, where sites write each page's own data. Unknown before observer 0.5.
builtOn :: Observation -> Maybe Text
builtOn o = do
  rs <- resources (network o)
  sheets <- inline (page o)
  let parts = sort [ xKind r <> " " <> xUrl r <> " " <> T.pack (show (xBytes r)) | r <- rs, xKind r `elem` ["Stylesheet", "Script"] ]
  pure (T.take 16 (sha (encodeUtf8 (T.intercalate "\n" (host o : ("inline " <> sheets) : parts)))))

-- | A question asked once for the pages that share a template: one asked of
--   the page as a whole, word for word the same, open or answered for them
--   together, on two pages or more, or answered once already. Its key names
--   it in the documents.
data Pool = Pool { pKey :: Text, pTemplate :: Text, pHost :: Text, pFinding :: Finding, pEntries :: [(Obs, Finding)] }

pools :: State -> [Pool]
pools st =
  [ Pool (T.take 8 t) t h f entries
  | (t, h, i, s) <- nub [ k | (k, _) <- candidates ]
  , let entries = [ e | (k, e) <- candidates, k == (t, h, i, s) ]
  , (_, f) : _ <- [entries]
  , length entries > 1 || any (\(o, g) -> maybe False (isJust . covers) (governing st o g)) entries ]
  where
    candidates =
      [ ((t, host (oBody o), fId f, en (fSeen f)), (o, f))
      | o <- latest st, Just t <- [builtOn (oBody o)], f <- assess st o
      , cId (fCrit f) `elem` ("consent-choice" : wholePage), null (fSurface f), fMachine f == Review
      , fVerdict f == Review || maybe False (isJust . covers) (governing st o f) ]
