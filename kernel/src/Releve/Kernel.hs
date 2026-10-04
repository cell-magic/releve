-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
{-# LANGUAGE OverloadedStrings #-}
-- | The fold. State is a function of the corpus and nothing else:
--   the same corpus always yields the same findings.
module Releve.Kernel (Obs (..), State, build, observations, latest, resolve, assess, previous) where

import Data.Aeson (Result (..), fromJSON)
import Data.List (sortOn)
import qualified Data.Map.Strict as M
import Data.Maybe (listToMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8)
import Releve.Corpus
import Releve.Criteria
import Releve.Types

data Obs = Obs { oId :: Text, oSeq :: Int, oBody :: Observation }

data State = State
  { byPage :: M.Map Text [Obs]          -- oldest first
  , byId :: M.Map Text Obs
  , fixes :: [(Int, Correction)] }      -- in corpus order

build :: [Record] -> Either String State
build = foldl step (Right (State M.empty M.empty []))
  where
    step (Left e) _ = Left e
    step (Right st) r = case fromJSON (rEvent r) of
      Error e -> Left ("record " <> show (rSeq r) <> ": " <> e)
      Success (Observed o) ->
        let x = Obs (T.take 8 (rHash r)) (rSeq r) o
        in Right st { byPage = M.insertWith (flip (++)) (url o) [x] (byPage st), byId = M.insert (oId x) x (byId st) }
      Success (Corrected c) -> Right st { fixes = fixes st ++ [(rSeq r, c)] }

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
      Nothing | length [() | x <- ms, null (mSurface x)] > 1 -> "page:" <> mSeen m
              | otherwise -> "page"

assess :: State -> Obs -> [Finding]
assess st o = [ mk i c m | (i, c, m) <- judged (oBody o) ]
  where
    before = previous st o
    lastKeys = maybe [] (map key . surfaces . oBody) (listToMaybe before)
    earlier = [ [i | (i, v) <- applied st p, open v] | p <- before ]
    mk i c m =
      let fix = correction st o i (mSeen m)
          lapsed = null fix && maybe False ((/= mVerdict m) . verdict) (listToMaybe (readings st o i))
          v | lapsed = Review
            | otherwise = maybe (mVerdict m) verdict fix
          fresh = not (null before) && maybe False ((`notElem` lastKeys) . key) (mSurface m)
          age = if open v then length (takeWhile (i `elem`) earlier) else 0
      in Finding i c (mVerdict m) v (fix >>= note) (mSurface m) (mSeen m) (mChange m) fresh age lapsed
    open v = v `elem` [Fail, Review, Hint]

-- | Each finding's verdict after a person's corrections, without history.
applied :: State -> Obs -> [(Text, Verdict)]
applied st o = [ (i, maybe (mVerdict m) verdict (correction st o i (mSeen m))) | (i, _, m) <- judged (oBody o) ]

-- | A person's readings of a finding, on this observation and on earlier ones
--   of the same page: the nearest observation first; within it, the latest.
readings :: State -> Obs -> Text -> [Correction]
readings st o i = map snd (sortOn fst [ ((d, negate n), c) | (n, c) <- fixes st, finding c == i, Just d <- [lookup (obs c) scope] ])
  where scope = zip (oId o : map oId (previous st o)) [0 :: Int ..]

-- | The correction that governs a finding: one made on this observation, or
--   the nearest earlier one made while what is seen read the same.
--
--   What is seen can change because the page changed, or because the judge
--   words it differently. Either way an earlier reading that differed from the
--   machine's no longer applies, and the machine's must not quietly replace
--   it: `assess` hands such a finding back to a person, as a Review.
correction :: State -> Obs -> Text -> Text -> Maybe Correction
correction st o i s = listToMaybe [ c | c <- readings st o i, obs c == oId o || seen c == s ]
