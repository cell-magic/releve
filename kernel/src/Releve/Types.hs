-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
{-# LANGUAGE DeriveGeneric, DeriveAnyClass, OverloadedStrings, LambdaCase #-}
-- | The vocabulary. An observation is what a page showed; a finding is
--   what one criterion says about one surface of it.
module Releve.Types where

import Control.Applicative ((<|>))
import Data.Aeson
import Data.Char (toLower)
import Data.String (IsString (..))
import Data.Text (Text)
import qualified Data.Text as T
import GHC.Generics (Generic)

type RGBA = [Double]  -- r g b in 0..255, alpha in 0..1

-- | The languages reports are written in.
data Lang = En | Fr deriving (Eq, Show)

-- | The same thing, said in each of them. A literal alone reads the same in
--   both: a number, a tag, words quoted from the page.
data Phrase = Phrase { en :: Text, fr :: Text } deriving (Eq, Show)

instance Semigroup Phrase where Phrase a b <> Phrase c d = Phrase (a <> c) (b <> d)
instance Monoid Phrase where mempty = Phrase "" ""
instance IsString Phrase where fromString s = Phrase (T.pack s) (T.pack s)

infix 1 //
(//) :: Text -> Text -> Phrase
(//) = Phrase

say :: Lang -> Phrase -> Text
say En = en
say Fr = fr

both :: Text -> Phrase
both t = Phrase t t

-- | A country, from its two letters, as a sentence says it after "from": "from Switzerland", "depuis la Suisse".
country :: Text -> Phrase
country cc = maybe (both cc) (uncurry Phrase) (lookup cc
  [ ("CH", ("Switzerland", "la Suisse")), ("FR", ("France", "la France")), ("DE", ("Germany", "l'Allemagne")), ("NL", ("the Netherlands", "les Pays-Bas"))
  , ("BE", ("Belgium", "la Belgique")), ("LU", ("Luxembourg", "le Luxembourg")), ("IE", ("Ireland", "l'Irlande")), ("AT", ("Austria", "l'Autriche"))
  , ("ES", ("Spain", "l'Espagne")), ("IT", ("Italy", "l'Italie")), ("FI", ("Finland", "la Finlande")), ("SE", ("Sweden", "la Suède"))
  , ("GB", ("the United Kingdom", "le Royaume-Uni")), ("US", ("the United States", "les États-Unis")), ("CA", ("Canada", "le Canada")) ])

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
  , by :: Maybe Text, label :: Maybe Text, href :: Maybe Text          -- ^ where the name comes from; the visible label; where a link leads
  , auto :: Maybe Text, hint :: Maybe Text, set :: Maybe Text, grouped :: Maybe Bool
  , controls :: Maybe Bool, tracks :: Maybe [Text]
  , rows :: Maybe Int, cols :: Maybe Int, heads :: Maybe Int, across :: Maybe Bool, bare :: Maybe Int, marks :: Maybe Int
  , lazy :: Maybe Bool, origin :: Maybe Text, manifest :: Maybe Bool   -- ^ loaded when reached; what the file says of its making
  , excepted :: Maybe Text  -- ^ why a target's size is not the author's: "inline", set in a sentence; "native", drawn by the browser
  } deriving (Show, Generic, FromJSON)

instance ToJSON Surface where
  toJSON = genericToJSON defaultOptions { omitNothingFields = True }

-- | One thing the page gives its reader to take in at once: a block of text,
--   an image, a field, a button, a player, a frame. What it says to assistive
--   technology (an extract, its length in words, its weight in bits), whether
--   it is shown, and where the markup places it.
data Ev = Ev
  { eN :: Int, eSel :: Text, eKind :: Text, eShown :: Bool, eSaid :: Text, eWords :: Int, eBits :: Double
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
  -- recorded since observer 0.4; `opened` tells an observation that has them from one that has not
  , doctype :: Maybe Text, styling :: Maybe [(Text, Int)], empties :: Maybe [(Text, Int)]
  , tabbed :: Maybe [Text], hiddenFocus :: Maybe [Text], skip :: Maybe Text, before :: Maybe Int, mains :: Maybe Int
  , refresh :: Maybe Text, opened :: Maybe Int
  , asked :: Maybe [Text], grows :: Maybe [Double], tls :: Maybe Text, ipv6 :: Maybe Bool
  , keys :: Maybe Keys  -- ^ recorded since observer 0.5
  -- also since observer 0.5: languages within the page, right-to-left script, emoji, words set by the style
  -- sheet, colours without a background, links that blend in, clicks no key reaches, what moves without end,
  -- text cut once a reader widens its spacing, and how much script the markup carries
  , langs :: Maybe [(Text, Text)], rtl :: Maybe Rtl, emoji :: Maybe Int, generated :: Maybe [(Text, Text)]
  , unpaired :: Maybe [Text], blended :: Maybe [Text], clickable :: Maybe [(Text, Text)], moving :: Maybe [Text], spaced :: Maybe [Text]
  , scripted :: Maybe Int
  , inline :: Maybe Text  -- ^ a digest of the style sheets written into the page
  , consent :: Maybe Consent  -- ^ recorded since observer 0.6
  } deriving (Show, Generic, FromJSON, ToJSON)

-- | A prompt for consent to cookies and trackers on arrival, whose it is, whether
--   it sits in a frame the page cannot read into, and the choices it offers at
--   once: what each does (accept, reject, settings), link or button, its area in
--   px², and its look (filled, outlined, plain).
data Consent = Consent { prompt :: Bool, cmp :: Maybe Text, framed :: Maybe Bool, choices :: Maybe [(Text, Text, Text, Int, Text)] }
  deriving (Show, Generic, FromJSON, ToJSON)

data Rtl = Rtl { chars :: Int, marked :: Bool } deriving (Show, Generic, FromJSON, ToJSON)

-- | The page taken by the keyboard alone, Tab after Tab from the top: how many
--   stops were reached, how the walk ended, where the focus could not leave,
--   which stops showed nothing when they took the focus, and which lay hidden.
data Keys = Keys
  { stops :: Int, ended :: Text, trap :: Maybe Text, checked :: Int, unseen :: [Text]
  , obscured :: Maybe [(Text, Text)]  -- ^ stops the page's own content lay over whole, and what did; since observer 0.7
  } deriving (Show, Generic, FromJSON, ToJSON)

-- | One response of those that brought the page: what it is, what it weighs,
--   how it travelled, whether the browser may keep it, whose it is.
data Resource = Resource
  { xUrl :: Text, xKind :: Text, xMime :: Text, xBytes :: Int, xProto :: Text, xEncoded :: Text, xCached :: Bool, xThird :: Bool
  , xFrom :: Maybe Text  -- ^ the address that asked for it, recorded since observer 0.5
  } deriving (Show, Generic)

instance FromJSON Resource where parseJSON = genericParseJSON evJSON
instance ToJSON Resource where toJSON = genericToJSON evJSON

data Network = Network
  { requests :: Int, transfer :: Int, thirdParties :: [Text]
  , resources :: Maybe [Resource]  -- ^ recorded since observer 0.4
  } deriving (Show, Generic, FromJSON, ToJSON)

data Observation = Observation
  { url :: Text, at :: Text, agent :: Text, page :: Page, network :: Network
  , surfaces :: [Surface], shot :: Maybe Text
  , events :: Maybe [Ev]     -- ^ the reading sequence; observers before 0.4 did not record it
  , mandate :: Maybe Text    -- ^ the owner's written leave to observe despite robots.txt
  , requested :: Maybe Text  -- ^ the address asked for, which a redirect may have left behind
  , browser :: Maybe Text    -- ^ what rendered the page: rendering is part of the reading
  , from :: Maybe Text       -- ^ the country the page was seen from, as two letters: a site may answer by country
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
  -- | An answer given once for pages that share a template: the observations it was given on,
  --   and the template they were built on. It holds on those pages, and on their later
  --   observations, while the template stays the same. Since 0.5; absent, the answer is the page's own.
  , covers :: Maybe [Text], template :: Maybe Text
  } deriving (Show, Generic, FromJSON)

instance ToJSON Correction where
  toJSON = genericToJSON defaultOptions { omitNothingFields = True }
  toEncoding = genericToEncoding defaultOptions { omitNothingFields = True }

-- | The owner's answer to a criterion that no rule can see from a page:
--   "yes", "no", "n/a", or "open" to withdraw one. It holds for the whole record
--   until the next answer to the same criterion.
data Declaration = Declaration { dCriterion :: Text, dAnswer :: Text, dNote :: Maybe Text } deriving (Show, Generic)

instance FromJSON Declaration where parseJSON = genericParseJSON evJSON
instance ToJSON Declaration where toJSON = genericToJSON evJSON

data Event = Observed Observation | Corrected Correction | Declared Declaration | Stamped Stamp deriving Show

-- | A time-stamping authority's answer (RFC 3161) over the record before this
--   one: its hash, the authority asked, the time it gave, and its signed reply,
--   kept whole so that anyone can check it again with OpenSSL.
data Stamp = Stamp { stHead :: Text, stTsa :: Text, stTime :: Text, stReply :: Text } deriving Show

instance ToJSON Stamp where
  toJSON s = object ["head" .= stHead s, "tsa" .= stTsa s, "time" .= stTime s, "reply" .= stReply s]

instance FromJSON Stamp where
  parseJSON = withObject "stamp" $ \o -> Stamp <$> o .: "head" <*> o .: "tsa" <*> o .: "time" <*> o .: "reply"

instance ToJSON Event where
  toJSON = \case
    Observed o  -> object ["observed" .= o]
    Corrected c -> object ["corrected" .= c]
    Declared d  -> object ["declared" .= d]
    Stamped s   -> object ["stamped" .= s]

instance FromJSON Event where
  parseJSON = withObject "event" $ \o ->
    (Observed <$> o .: "observed") <|> (Corrected <$> o .: "corrected") <|> (Declared <$> o .: "declared") <|> (Stamped <$> o .: "stamped")

-- | What one criterion says about one surface. Where only a person can
--   decide, the question they answer: yes means it holds, no that it does not.
data Mark = Mark
  { mVerdict :: Verdict, mSurface :: Maybe Surface, mSeen :: Phrase, mChange :: Maybe Phrase, mAsk :: Maybe Phrase }

-- | How much work mending it usually is.
data Effort = Light | Medium | Heavy deriving (Eq, Ord, Show)

-- | A criterion: what it checks, where the rule comes from, what it is for,
--   and the rule itself.
data Criterion = Criterion
  { cId :: Text, cTitle :: Phrase, cRef :: Phrase, cEffort :: Effort, cWhy :: Phrase
  , cJudge :: Observation -> [Mark] }

data Finding = Finding
  { fId :: Text, fCrit :: Criterion, fMachine :: Verdict, fVerdict :: Verdict
  , fNote :: Maybe Text, fSurface :: Maybe Surface, fSeen :: Phrase, fChange :: Maybe Phrase
  , fNew :: Bool, fAge :: Int
  , fLapsed :: Bool  -- ^ a person read it otherwise before what is seen changed
  , fAsk :: Maybe Phrase  -- ^ the question a person answers, where the rule cannot decide
  }
