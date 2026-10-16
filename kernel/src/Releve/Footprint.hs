-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
{-# LANGUAGE OverloadedStrings #-}

-- | What a page costs to deliver, measured and not scored: document nodes,
--   requests, kilobytes on the wire, the hosts it calls on, and the longest
--   chain of requests, each asked for by the one before. Comparable only under
--   the same measurement conditions.
module Releve.Footprint (Footprint (..), footprint, named) where

import Data.List (foldl')
import qualified Data.Map.Strict as M
import Data.Text (Text)
import qualified Data.Text as T
import Releve.Types

data Footprint = Footprint { elements, calls :: Int, kilobytes :: Double, hosts :: [Text], chain :: [Text] }

footprint :: Observation -> Footprint
footprint o = Footprint (dom (page o)) (requests n) (fromIntegral (transfer n) / 1024) (thirdParties n) (longest (concat (resources n)))
  where n = network o

-- | The longest run of requests in which each was asked for by the one before, first request first.
--   A link the browser does not report is not counted: the chain may be longer than this, never shorter.
longest :: [Resource] -> [Text]
longest rs = foldl' (\best r -> let c = up (xUrl r) [] in if length c > length best then c else best) [] rs
  where
    asked = M.fromListWith (\_ first -> first) [(xUrl r, xFrom r) | r <- rs]
    up u seen
      | u `elem` seen || length seen >= 50 = seen
      | otherwise = case M.lookup u asked of
          Just (Just f) | M.member f asked -> up f (u : seen)
          _ -> u : seen

-- | A file by the last part of its address.
named :: Text -> Text
named u = let path = T.takeWhile (`notElem` ("?#" :: String)) u
              parts = filter (not . T.null) (T.splitOn "/" path)
          in case reverse parts of
               x : _ | length parts > 2 -> x
               [x, _] -> x
               _ -> u
