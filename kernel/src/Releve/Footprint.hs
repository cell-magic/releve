-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2

-- | What a page costs to deliver, measured and not scored: document nodes,
--   requests, kilobytes on the wire, and the hosts it calls on. Comparable
--   only under the same measurement conditions.
module Releve.Footprint (Footprint (..), footprint) where

import Data.Text (Text)
import Releve.Types

data Footprint = Footprint { elements, calls :: Int, kilobytes :: Double, hosts :: [Text] }

footprint :: Observation -> Footprint
footprint o = Footprint (dom (page o)) (requests n) (fromIntegral (transfer n) / 1024) (thirdParties n)
  where n = network o
