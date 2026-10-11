-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
{-# LANGUAGE DeriveGeneric, DeriveAnyClass, OverloadedStrings, LambdaCase #-}
-- | The vocabulary. An observation is what a page showed; a finding is
--   what one criterion says about one surface of it.
module Releve.Types where

import Control.Applicative ((<|>))
import Data.Aeson
import Data.Char (toLower)
import Data.Text (Text)
import qualified Data.Text as T
import GHC.Generics (Generic)

type RGBA = [Double]  -- r g b in 0..255, alpha in 0..1

data Surface = Surface
  { kind :: Text, key :: Text, sel :: Text, order :: Int
  , box :: Maybe [Double], hidden :: Maybe Bool, role :: Maybe Text
  , name :: Maybe Text, alt :: Maybe Text, text :: Maybe Text, level :: Maybe Int
  , itype :: Maybe Text, placeholder :: Maybe Text
  , fg :: Maybe RGBA, bg :: Maybe RGBA, bgImage :: Maybe Bool
  , size :: Maybe Double, weight :: Maybe Int, opacity :: Maybe Double
  , src :: Maybe Text, natural :: Maybe [Double], bytes :: Maybe Int, mime :: Maybe Text
  , autoplay :: Maybe Bool, muted :: Maybe Bool, vendor :: Maybe Text
  , ev :: Maybe Int  -- ^ the event it belongs to
  } deriving (Show, Generic, FromJSON)

instance ToJSON Surface where
  toJSON = genericToJSON defaultOptions { omitNothingFields = True }

-- | One thing the page gives its reader to take in at once: a block of text,
--   an image, a field, a button, a player, a frame. What it says to assistive
--   technology, whether it is shown, and where the markup places it.
data Ev = Ev
  { eN :: Int, eSel :: Text, eKind :: Text, eShown :: Bool, eSaid :: Text
  , eQuiet :: Maybe Bool          -- ^ it says nothing, and is declared to
  , eLevel :: Maybe Int           -- ^ of the heading it is, if it is one
  , ePath :: [(Text, Int)]        -- ^ the landmarks, lists, tables and forms around it, outermost first
  , eCell :: Maybe Text, eLabel :: Maybe Int
  , eBox :: [Double], eSize :: Double, eWeight :: Int
  } deriving (Show, Generic)

evJSON :: Options
evJSON = defaultOptions { fieldLabelModifier = map toLower . drop 1, omitNothingFields = True }

instance FromJSON Ev where parseJSON = genericParseJSON evJSON
instance ToJSON Ev where toJSON = genericToJSON evJSON

data Page = Page
  { lang :: Maybe Text, title :: Maybe Text, viewport :: Maybe Text
  , reflow :: Maybe Double, dom :: Int, dupIds :: [(Text, Int)]
  , disclosure :: [Text], truncated :: Maybe Bool
  } deriving (Show, Generic, FromJSON, ToJSON)

data Network = Network
  { requests :: Int, transfer :: Int, thirdParties :: [Text]
  } deriving (Show, Generic, FromJSON, ToJSON)

data Observation = Observation
  { url :: Text, at :: Text, agent :: Text, page :: Page, network :: Network
  , surfaces :: [Surface], shot :: Maybe Text
  , events :: Maybe [Ev]     -- ^ the reading sequence; observers before 0.4 did not record it
  , mandate :: Maybe Text    -- ^ the owner's written leave to observe despite robots.txt
  , requested :: Maybe Text  -- ^ the address asked for, which a redirect may have left behind
  , browser :: Maybe Text    -- ^ what rendered the page: rendering is part of the reading
  } deriving (Show, Generic, FromJSON)

instance ToJSON Observation where
  toJSON = genericToJSON defaultOptions { omitNothingFields = True }

-- | Fail: a stated rule is broken. Review: a person must decide.
--   Hint: nothing is broken, something could be lighter. NA: nothing to judge.
data Verdict = Fail | Review | Hint | Pass | NA
  deriving (Eq, Ord, Show, Enum, Bounded)

word :: Verdict -> Text
word = T.toUpper . T.pack . show

readWord :: Text -> Maybe Verdict
readWord w = lookup (T.toUpper (T.strip w)) [(word v, v) | v <- [minBound ..]]

instance ToJSON Verdict where toJSON = toJSON . T.toLower . word
instance FromJSON Verdict where
  parseJSON = withText "verdict" $ maybe (fail "unknown verdict") pure . readWord

-- | A person's reading of one finding. It applies to the observation it
--   names and to later ones of the same page while the observed value is
--   unchanged.
data Correction = Correction
  { obs :: Text, finding :: Text, verdict :: Verdict, note :: Maybe Text, seen :: Text
  } deriving (Show, Generic, FromJSON, ToJSON)

data Event = Observed Observation | Corrected Correction deriving Show

instance ToJSON Event where
  toJSON = \case
    Observed o  -> object ["observed" .= o]
    Corrected c -> object ["corrected" .= c]

instance FromJSON Event where
  parseJSON = withObject "event" $ \o ->
    (Observed <$> o .: "observed") <|> (Corrected <$> o .: "corrected")

-- | What one criterion says about one surface.
data Mark = Mark
  { mVerdict :: Verdict, mSurface :: Maybe Surface, mSeen :: Text, mChange :: Maybe Text }

data Criterion = Criterion
  { cId :: Text, cTitle :: Text, cRef :: Text, cJudge :: Observation -> [Mark] }

data Finding = Finding
  { fId :: Text, fCrit :: Criterion, fMachine :: Verdict, fVerdict :: Verdict
  , fNote :: Maybe Text, fSurface :: Maybe Surface, fSeen :: Text, fChange :: Maybe Text
  , fNew :: Bool, fAge :: Int
  , fLapsed :: Bool  -- ^ a person read it otherwise before what is seen changed
  }
