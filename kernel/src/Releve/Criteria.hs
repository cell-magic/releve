-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
{-# LANGUAGE OverloadedStrings #-}
-- | The criteria. Each is a pure function from an observation to marks.
--   A criterion states its source; thresholds that are this tool's own
--   choice say so.
module Releve.Criteria (criteria, version) where

import Data.Char (isAlpha, isAlphaNum)
import Data.List (isSuffixOf, isPrefixOf)
import Data.Maybe (fromMaybe, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Text.Printf (printf)
import Releve.Colour
import Releve.Types

version :: Text
version = "2"

criteria :: [Criterion]
criteria =
  [ Criterion "page-title"    "The page has a title"                  "RGAA 8.5 · WCAG 2.4.2" pageTitle
  , Criterion "page-lang"     "The page states its language"          "RGAA 8.3 · WCAG 3.1.1" pageLang
  , Criterion "zoom"          "Zoom is not blocked"                   "RGAA 10.4 · WCAG 1.4.4" zoom
  , Criterion "reflow"        "No horizontal scrolling at 320 px"     "RGAA 10.11 · WCAG 1.4.10" reflowC
  , Criterion "main-region"   "The main content is marked"            "RGAA 12.6 · WCAG 2.4.1" mainRegion
  , Criterion "heading-order" "Heading levels follow each other"      "RGAA 9.1 · WCAG 1.3.1" headingOrder
  , Criterion "image-alt"     "Images carry a text alternative"       "RGAA 1.1–1.3 · WCAG 1.1.1" imageAlt
  , Criterion "text-contrast" "Text contrasts with its background"    "RGAA 3.2 · WCAG 1.4.3" contrast
  , Criterion "link-name"     "Links have a name"                     "RGAA 6.1–6.2 · WCAG 2.4.4" linkName
  , Criterion "button-name"   "Buttons have a name"                   "RGAA 11.9 · WCAG 4.1.2" buttonName
  , Criterion "control-label" "Form fields have a label"              "RGAA 11.1 · WCAG 1.3.1" controlLabel
  , Criterion "frame-title"   "Frames have a title"                   "RGAA 2.1 · WCAG 4.1.2" frameTitle
  , Criterion "autoplay"      "No sound starts by itself"             "RGAA 4.10 · WCAG 1.4.2" autoplayC
  , Criterion "unique-ids"    "Element ids are unique"                "RGAA 8.2" uniqueIds
  , Criterion "ai-disclosure" "Conversational AI is disclosed"        "AI Act art. 50(1)" aiDisclosure
  , Criterion "image-weight"  "Images are not larger than shown"      "RGESN · threshold 2× (tool)" imageWeight
  , Criterion "image-format"  "Heavy images use a modern format"      "RGESN · threshold 30 kB (tool)" imageFormat
  ]

-- helpers ---------------------------------------------------------------

visible :: Surface -> Bool
visible s = hidden s /= Just True

surfacesOf :: Text -> Observation -> [Surface]
surfacesOf k o = [s | s <- surfaces o, kind s == k, visible s]

blank :: Maybe Text -> Bool
blank = maybe True (T.null . T.strip)

on :: Surface -> Verdict -> Text -> Maybe Text -> Mark
on s = \v seen ch -> Mark v (Just s) seen ch

onPage :: Verdict -> Text -> Maybe Text -> Mark
onPage = \v seen ch -> Mark v Nothing seen ch

orNA :: Text -> [Mark] -> [Mark]
orNA what [] = [onPage NA ("no " <> what <> " on the page") Nothing]
orNA _ ms = ms

quote :: Text -> Text
quote t = "“" <> t <> "”"

int :: Double -> Text
int x = T.pack (show (round x :: Int))

dims :: [Double] -> Maybe (Double, Double)
dims (w : h : _) = Just (w, h)
dims _ = Nothing

shown :: Surface -> Maybe (Double, Double)
shown s = case box s of Just [_, _, w, h] -> Just (w, h); _ -> Nothing

-- page ------------------------------------------------------------------

pageTitle, pageLang, zoom, reflowC, mainRegion, uniqueIds :: Observation -> [Mark]

pageTitle o
  | blank t = [onPage Fail "the page has no title" (Just "add a <title> that names the page")]
  | otherwise = [onPage Pass (quote (fromMaybe "" t)) Nothing]
  where t = title (page o)

pageLang o = case T.strip <$> lang (page o) of
  Nothing -> [onPage Fail "no lang on <html>" (Just "set lang on <html>, e.g. lang=\"fr\"")]
  Just "" -> [onPage Fail "empty lang on <html>" (Just "set lang on <html>, e.g. lang=\"fr\"")]
  Just l | tag l -> [onPage Pass ("lang=" <> l) Nothing]
         | otherwise -> [onPage Review ("lang " <> quote l <> " is not a recognised language tag") Nothing]
  where
    tag l = case T.splitOn "-" l of
      (p : rest) -> T.length p `elem` [2, 3] && T.all isAlpha p && all (\x -> not (T.null x) && T.all isAlphaNum x) rest
      [] -> False

zoom o = case viewport (page o) of
  Nothing -> [onPage Pass "no viewport restriction" Nothing]
  Just v
    | blocked v -> [onPage Fail ("viewport " <> quote v) (Just "remove maximum-scale and user-scalable")]
    | otherwise -> [onPage Pass ("viewport " <> quote v) Nothing]
  where
    blocked v = any restricts [(T.strip k, T.strip (T.drop 1 x)) | p <- T.splitOn "," (T.toLower v), let (k, x) = T.breakOn "=" p]
    restricts ("user-scalable", x) = x `elem` ["no", "0"]
    restricts ("maximum-scale", x) = maybe False (< 2) (readD x)
    restricts _ = False
    readD x = case reads (T.unpack x) :: [(Double, String)] of [(d, "")] -> Just d; _ -> Nothing

reflowC o = case reflow (page o) of
  Nothing -> [onPage NA "not measured" Nothing]
  Just w | w > 321 -> [onPage Fail ("content is " <> int w <> " px wide in a 320 px viewport") (Just "remove horizontal scrolling at 320 px")]
         | otherwise -> [onPage Pass "content fits 320 px" Nothing]

mainRegion o
  | any ((== Just "main") . role) (surfacesOf "landmark" o) = [onPage Pass "main landmark present" Nothing]
  | otherwise = [onPage Review "no main landmark" (Just "wrap the main content in <main>")]

uniqueIds o = case dupIds (page o) of
  [] -> [onPage Pass "all ids unique" Nothing]
  ds -> [onPage Fail ("id " <> quote i <> " used " <> T.pack (show n) <> " times") (Just "give each element its own id") | (i, n) <- ds]

-- structure -------------------------------------------------------------

headingOrder :: Observation -> [Mark]
headingOrder o = case surfacesOf "heading" o of
  [] -> [onPage Review "no headings" (Just "structure the content with headings")]
  hs@(h : _) -> on h Pass (lv h) Nothing : zipWith step hs (drop 1 hs)
  where
    lvl = fromMaybe 1 . level
    lv s = "h" <> T.pack (show (lvl s)) <> maybe "" ((" " <>) . quote) (text s)
    step a b
      | lvl b > lvl a + 1 = on b Review ("h" <> T.pack (show (lvl a)) <> " then " <> lv b) (Just ("h" <> T.pack (show (lvl a + 1))))
      | otherwise = on b Pass (lv b) Nothing

-- images ----------------------------------------------------------------

imageAlt :: Observation -> [Mark]
imageAlt o = orNA "images" (map img (surfacesOf "img" o) ++ map graphic (surfacesOf "graphic" o))
  where
    img s = case T.strip <$> alt s of
      _ | role s `elem` [Just "presentation", Just "none"] -> on s Pass "role=presentation (decorative)" Nothing
      Nothing -> on s Fail "no alt attribute" (Just "add alt; alt=\"\" if the image is decorative")
      Just ""
        | maybe 0 (uncurry (*)) (shown s) >= 40000 -> on s Review "large image with alt=\"\" (declared decorative)" Nothing
        | otherwise -> on s Pass "alt=\"\" (decorative)" Nothing
      Just a
        | fileLike a -> on s Review ("alt " <> quote a <> " looks like a file name") (Just "describe what the image shows")
        | otherwise -> on s Pass ("alt " <> quote a) Nothing
    graphic s
      | blank (name s) = on s Fail "role=img without a name" (Just "add aria-label or <title>")
      | otherwise = on s Pass (quote (fromMaybe "" (name s))) Nothing
    fileLike a = let l = T.unpack (T.toLower a) in
      any (`isSuffixOf` l) [".jpg", ".jpeg", ".png", ".gif", ".webp", ".avif", ".svg"] || any (`isPrefixOf` l) ["img_", "dsc"]

imageWeight, imageFormat :: Observation -> [Mark]
imageWeight o = orNA "bitmap images" (mapMaybe judge [s | s <- surfaces o, kind s == "img", not (vector s)])
  where
    -- A vector image has no pixel size to exceed.
    vector s = mime s == Just "image/svg+xml" || maybe False (T.isSuffixOf ".svg" . T.toLower . T.takeWhile (/= '?')) (src s)
    judge s = do
      (nw, nh) <- natural s >>= dims
      (w, h) <- shown s
      if nw <= 0 || w <= 0 then Nothing else Just $
        if nw > 2 * w
          then on s Hint (int nw <> "×" <> int nh <> " px shown at " <> int w <> "×" <> int h) (Just ("serve at most " <> int (2 * w) <> "×" <> int (2 * h) <> " px"))
          else on s Pass (int nw <> "×" <> int nh <> " px shown at " <> int w <> "×" <> int h) Nothing

imageFormat o = orNA "weighed images" (mapMaybe judge [s | s <- surfaces o, kind s == "img"])
  where
    judge s = do
      m <- mime s
      b <- bytes s
      let seen = m <> ", " <> int (fromIntegral b / 1024) <> " kB"
      Just $ if m `elem` ["image/png", "image/jpeg", "image/gif", "image/bmp"] && b > 30720
        then on s Hint seen (Just "serve AVIF or WebP")
        else on s Pass seen Nothing

-- text ------------------------------------------------------------------

contrast :: Observation -> [Mark]
contrast o = orNA "text" (map judge (surfacesOf "text" o))
  where
    judge s = case (fg s, bg s) of
      _ | bgImage s == Just True -> on s Review ("text over a background image" <> snippet s) Nothing
      (Just f, Just b) ->
        let c = over f b; back = over b b; r = ratio c back
            need = if large s then 3 else 4.5
            seen = hex c <> " on " <> hex back <> " · " <> two r <> ":1, needs " <> two need <> ":1" <> snippet s
        in case opacity s of
             Just a | a < 1 -> on s Review (seen <> " · partly transparent (opacity " <> two a <> "), may be mid-animation") Nothing
             _ | r >= need -> on s Pass seen Nothing
               | otherwise -> on s Fail seen (("use " <>) . hex <$> nearest need c back)
      _ -> on s Review ("colours not readable" <> snippet s) Nothing
    large s = let px = fromMaybe 16 (size s); w = fromMaybe 400 (weight s) in px >= 24 || (px >= 18.66 && w >= 700)
    two :: Double -> Text
    two x = T.pack (printf "%.2f" (fromIntegral (floor (x * 100) :: Int) / 100 :: Double))
    snippet s = maybe "" ((" · " <>) . quote) (text s)

-- names -----------------------------------------------------------------

linkName, buttonName, controlLabel, frameTitle, autoplayC, aiDisclosure :: Observation -> [Mark]

linkName o = orNA "links" (map judge (surfacesOf "link" o))
  where
    judge s
      | blank (name s) = on s Fail "link without a name" (Just "give the link text, an image alt, or aria-label")
      | T.toLower n `elem` vague = on s Review ("link " <> quote n <> " depends on its context") (Just "name the destination")
      | otherwise = on s Pass (quote n) Nothing
      where n = T.strip (fromMaybe "" (name s))
    vague = [ "ici", "cliquez ici", "en savoir plus", "lire la suite", "plus", "voir", "voir plus", "lien"
            , "here", "click here", "read more", "more", "learn more", "link" ]

buttonName o = orNA "buttons" (map judge (surfacesOf "button" o))
  where judge s | blank (name s) = on s Fail "button without a name" (Just "give the button text or aria-label")
                | otherwise = on s Pass (quote (fromMaybe "" (name s))) Nothing

controlLabel o = orNA "form fields" (map judge (surfacesOf "control" o))
  where judge s | blank (name s) = on s Fail ("no label" <> maybe "" (\p -> "; placeholder " <> quote p <> " only") (placeholder s))
                                          (Just "associate a <label>, or add aria-label")
                | otherwise = on s Pass ("label " <> quote (fromMaybe "" (name s))) Nothing

frameTitle o = orNA "frames" (map judge (surfacesOf "iframe" o))
  where judge s | blank (name s) = on s Fail "frame without a title" (Just "add a title that says what the frame holds")
                | otherwise = on s Pass (quote (fromMaybe "" (name s))) Nothing

autoplayC o = orNA "audio or video" (map judge (surfacesOf "media" o))
  where judge s | autoplay s == Just True && muted s /= Just True = on s Fail "plays sound on load" (Just "add muted, or remove autoplay")
                | otherwise = on s Pass "no sound on load" Nothing

aiDisclosure o = case surfacesOf "widget" o of
  [] -> [onPage NA "no conversational widget detected" Nothing]
  ws -> [ on w Review ("conversational widget (" <> fromMaybe "?" (vendor w) <> "); disclosure wording on the page: " <> said)
               (if null ds then Just "if it is an AI system, say so to the user" else Nothing) | w <- ws ]
  where ds = disclosure (page o)
        said = if null ds then "none" else T.intercalate ", " (map quote ds)
