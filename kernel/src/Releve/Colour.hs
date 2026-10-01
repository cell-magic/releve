-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- | Contrast as WCAG defines it, and the nearest colour that satisfies it.
module Releve.Colour (ratio, over, nearest, hex) where

import Data.List (find)
import Data.Text (Text)
import qualified Data.Text as T
import Text.Printf (printf)

type RGB = (Double, Double, Double)

luminance :: RGB -> Double
luminance (r, g, b) = 0.2126 * c r + 0.7152 * c g + 0.0722 * c b
  where c v = let s = v / 255 in if s <= 0.03928 then s / 12.92 else ((s + 0.055) / 1.055) ** 2.4

ratio :: RGB -> RGB -> Double
ratio a b = (max la lb + 0.05) / (min la lb + 0.05)
  where (la, lb) = (luminance a, luminance b)

-- | A translucent foreground laid over an opaque background.
over :: [Double] -> [Double] -> RGB
over [r, g, b, a] [br, bgc, bb, _] = (m r br, m g bgc, m b bb) where m x y = a * x + (1 - a) * y
over [r, g, b] _ = (r, g, b)
over _ _ = (0, 0, 0)

-- | The smallest move of the foreground towards black or white that reaches
--   the required ratio against the background, in whole sRGB steps.
nearest :: Double -> RGB -> RGB -> Maybe RGB
nearest need f back = pick (walk (0, 0, 0)) (walk (255, 255, 255))
  where
    walk target = find ok [(t, toward target t) | t <- [0, 1 / 255 .. 1]]
    toward (tr, tg, tb) t = let (r, g, b) = f in (step r tr t, step g tg t, step b tb t)
    step v tv t = fromIntegral (round (v + t * (tv - v)) :: Int)
    ok (_, c) = ratio c back >= need
    pick (Just a) (Just b) = Just . snd $ if fst a <= fst b then a else b
    pick a b = snd <$> maybe b Just a

hex :: RGB -> Text
hex (r, g, b) = T.pack (printf "#%02x%02x%02x" (i r) (i g) (i b))
  where i = round :: Double -> Int
