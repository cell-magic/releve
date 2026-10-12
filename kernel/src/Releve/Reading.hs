-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
{-# LANGUAGE OverloadedStrings #-}
-- | The reading: how much a page gives its reader to take in, in what order
--   it must be taken, and how many steps that makes. Measured, not judged.
--
--   A page is a stream of events: a block of text, an image, a field. Each
--   says something or says nothing (the observer weighs it, in bits); the
--   markup declares which of them can be taken independently; and a reader
--   takes them a few at a time, fewer where the page fails them. Every
--   constant below is a stated convention.
module Releve.Reading (Reading (..), Misfit (..), Shape (..), reading, readingOf, aperture, ceiling') where

import Data.List (delete, groupBy, minimumBy, nub, sortOn)
import Data.Ord (comparing)
import Data.Maybe (listToMaybe, mapMaybe)
import qualified Data.Set as S
import Data.Text (Text)
import Releve.Types

-- conventions -------------------------------------------------------------

-- | An event registers when it says at least this many bits: one distinction.
threshold :: Double
threshold = 1

-- | The reference reader: holds at most this many events at once,
ceiling' :: Int
ceiling' = 4

-- | has this budget to spend on them,
budget :: Double
budget = 8

-- | and pays for each event 1 + sensitivity · misfit² · (1 + interference · rate).
sensitivity, interference :: Double
sensitivity = 6
interference = 0.15

-- | Failures that hold of the page as a whole: present in every window.
whole :: [Text]
whole = ["page-lang", "zoom", "reflow"]

-- | How many events the reference reader takes in one step, from a window of
--   that many ready events of which so many misfit. Never fewer than one.
aperture :: Int -> Int -> Int
aperture window misfits = max 1 (min ceiling' (floor (budget / cost)))
  where
    m = fromIntegral misfits / fromIntegral (max 1 window) :: Double
    rate = fromIntegral window / fromIntegral ceiling'
    cost = 1 + sensitivity * m * m * (1 + interference * rate)

-- what depends on what ------------------------------------------------------

-- | Events in series must be taken in order; events in parallel need not.
data Shape = One Ev | Series [Shape] | Parallel [Shape]

data Node = Leaf Ev | Box Text [Node]

nest :: [([(Text, Int)], Ev)] -> [Node]
nest [] = []
nest (([], e) : xs) = Leaf e : nest xs
nest xs@((c : _, _) : _) = Box (fst c) (nest [(drop 1 p, e) | (p, e) <- inside]) : nest rest
  where (inside, rest) = span ((== Just c) . listToMaybe . fst) xs

leaves :: [Node] -> [Ev]
leaves = concatMap (\x -> case x of Leaf e -> [e]; Box _ xs -> leaves xs)

-- | What the markup declares. A list's items are independent, an ordered
--   list's are not. Under a table's headers its cells are independent.
--   A form's fields are independent, each after its label, and its buttons
--   come last. Everything else follows the headings.
shape :: Node -> Shape
shape (Leaf e) = One e
shape (Box k xs) = case k of
  "list" -> Parallel (map shape xs)
  "olist" -> Series (map shape xs)
  "table" -> table
  "form" -> form
  _ -> flow xs
  where
    table =
      let ls = leaves xs; is c e = eCell e == Just c
          body | any (is "head") ls = Parallel [One e | e <- ls, not (is "head" e), not (is "caption" e)]
               | otherwise = Parallel [Series [One e | e <- leaves [x], not (is "caption" e)] | x <- xs]
      in Series [Series (map One (filter (is "caption") ls)), Parallel (map One (filter (is "head") ls)), body]
    form =
      let ls = leaves xs
          (buttons, others) = (filter ((== "button") . eKind) ls, filter ((/= "button") . eKind) ls)
          under l = [e | e <- others, eLabel e == Just (eN l)]
          labelled e = maybe False (`elem` map eN others) (eLabel e)
          units = [ if null (under e) then One e else Series [One e, Parallel (map One (under e))]
                  | e <- others, not (labelled e) ]
      in Series [Parallel units, Parallel (map One buttons)]

-- | A heading opens a section; sections of one level are independent of each
--   other, and each comes after what stands above it. Where there is no
--   heading, content is taken in document order, landmarks side by side.
flow :: [Node] -> Shape
flow xs = case mapMaybe level xs of
  [] -> Series [ if all landmark g then Parallel (map shape g) else Series (map shape g)
               | g <- groupBy (\a b -> landmark a && landmark b) xs ]
  ls -> let top = (== Just (minimum ls)) . level
            (before, rest) = break top xs
        in Series [flow before, Parallel [Series [shape h, flow body] | (h : body) <- sections top rest]]
  where
    level (Leaf e) = eLevel e
    level _ = Nothing
    landmark (Box k _) = k `elem` ["banner", "navigation", "main", "contentinfo", "complementary", "search"]
    landmark _ = False
    sections _ [] = []
    sections top (h : ys) = let (body, more) = break top ys in (h : body) : sections top more

-- | No empty group, no group of one.
tidy :: Shape -> Maybe Shape
tidy (One e) = Just (One e)
tidy (Series xs) = case mapMaybe tidy xs of [] -> Nothing; [x] -> Just x; ys -> Just (Series ys)
tidy (Parallel xs) = case mapMaybe tidy xs of [] -> Nothing; [x] -> Just x; ys -> Just (Parallel ys)

volume, depth :: Shape -> Int
volume (One _) = 1
volume (Series xs) = sum (map volume xs)
volume (Parallel xs) = sum (map volume xs)
depth (One _) = 1
depth (Series xs) = sum (map depth xs)
depth (Parallel xs) = maximum (map depth xs)

-- how long it takes -----------------------------------------------------------

-- | The events that can be taken now, in document order.
ready :: Shape -> [Ev]
ready (One e) = [e]
ready (Series xs) = concatMap ready (take 1 xs)
ready (Parallel xs) = concatMap ready xs

-- | Take the first n ready events away. What they made ready waits for the next step.
taken :: Int -> Shape -> (Int, Maybe Shape)
taken 0 s = (0, Just s)
taken n (One _) = (n - 1, Nothing)
taken n (Series []) = (n, Nothing)
taken n (Series (x : xs)) = case taken n x of
  (n', Just x') -> (n', Just (Series (x' : xs)))
  (n', Nothing) -> (n', if null xs then Nothing else Just (Series xs))
taken n (Parallel xs) = let (n', ys) = go n xs in (n', if null ys then Nothing else Just (Parallel ys))
  where
    go 0 rest = (0, rest)
    go k [] = (k, [])
    go k (y : rest) = let (k', y') = taken k y; (k'', rest') = go k' rest in (k'', maybe rest' (: rest') y')

-- | Steps the reference reader needs: at each one, the window is the first
--   events ready, and the aperture is what their misfit allows.
steps :: Int -> S.Set Int -> Maybe Shape -> Int
steps everywhere bad = go 0
  where
    go t Nothing = t
    go t (Just s) =
      let window = take ceiling' (ready s)
          misfits = min (length window) (everywhere + length (filter ((`S.member` bad) . eN) window))
      in go (t + 1 :: Int) (snd (taken (aperture (length window) misfits) s))

-- the reading -----------------------------------------------------------------

-- | A failure the reader meets: of which criterion, at which event (or of the page).
data Misfit = Misfit { mCriterion :: Text, mEvent :: Maybe Int }

data Reading = Reading
  { rEvents :: Int           -- ^ N: events that reach a reader, by eye or by ear
  , rUnsaid :: Int           -- ^ shown, and nothing said for them
  , rUnshown :: Int          -- ^ said, and not shown
  , rDepth :: Int            -- ^ D: the longest run the markup obliges
  , rBits :: Double          -- ^ H: what the page says
  , rLower, rUpper :: Int    -- ^ the least and the most steps at the reader's ceiling
  , rClear :: Int            -- ^ steps with nothing failing
  , rSteps :: Int            -- ^ steps as the page stands
  , rSerial :: Int           -- ^ steps one at a time, by ear
  , rMending :: [(Text, Int)] -- ^ the criteria in the order that gives back most at each turn, with the steps
                              --   left once each is mended after those before it
  , rShape :: Maybe Shape    -- ^ what must be taken in order, and what need not
  }

-- | The reading of an observation, under the verdicts that stand. An observer
--   that did not record the reading sequence gives none.
readingOf :: Observation -> [Finding] -> Maybe Reading
readingOf o fs = (\es -> reading es [Misfit (cId (fCrit f)) (fSurface f >>= ev) | f <- fs, fVerdict f == Fail]) <$> events o

reading :: [Ev] -> [Misfit] -> Reading
reading es misfits = Reading
  { rEvents = n, rUnsaid = count unsaid, rUnshown = count (\(e, b) -> heard b && not (eShown e))
  , rDepth = d, rBits = sum [b | (_, b) <- kept], rLower = max d (up n), rUpper = min n ((n + (ceiling' - 1) * d) `div` ceiling')
  , rClear = clear, rSteps = now, rSerial = count (heard . snd)
  , rMending = mending (nub [c | Misfit c e <- misfits, e /= Nothing || c `elem` whole]) misfits now
  , rShape = g
  }
  where
    heard = (>= threshold - 1e-9)
    seen e = eShown e && not (eKind e == "image" && eQuiet e == Just True)   -- declared decoration reaches no one
    unsaid (e, b) = seen e && not (heard b) && eQuiet e /= Just True
    kept = [(e, eBits e) | e <- es, heard (eBits e) || seen e]
    count p = length (filter p kept)
    g = tidy (flow (nest [(ePath e, e) | (e, _) <- sortOn (eN . fst) kept]))
    n = maybe 0 volume g
    d = maybe 0 depth g
    up x = (x + ceiling' - 1) `div` ceiling'
    load ms = steps (length (nub [c | Misfit c _ <- ms, c `elem` whole])) (S.fromList [i | Misfit c (Just i) <- ms, c `notElem` whole]) g
    now = load misfits
    clear = steps 0 S.empty g
    -- Each turn mends the criterion that leaves fewest steps, after those before it (the first
    -- in order when none gives back alone), so the gains add up and the last line is the page
    -- with nothing failing. Criteria that touch no event are left out: they cost no step.
    mending cs ms cur
      | cur <= clear || null cs = []
      | otherwise = (c, best) : mending (delete c cs) (without c ms) best
      where (best, c) = minimumBy (comparing fst) [(load (without k ms), k) | k <- cs]
    without c = filter ((/= c) . mCriterion)
