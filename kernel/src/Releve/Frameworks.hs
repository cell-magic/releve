-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
{-# LANGUAGE OverloadedStrings #-}
-- | The texts a site may answer to, each as the provisions it is made of, and
--   how many of them the rules, the reviewer's questions and the owner's
--   declarations address. A text built on WCAG is the WCAG success criteria it
--   names, and what it asks beyond them. The RGAA reaches WCAG through the
--   correspondence the RGAA itself states. Addressed means a rule reads it, a
--   question puts it to a person, or the owner answers it; it says nothing of
--   whether a site conforms.
module Releve.Frameworks (Framework (..), frameworks, coverage, addressed, touched, crosswalk, wcag20, wcag21, wcag22) where

import Data.Char (isDigit)
import Data.List (nub, (\\))
import qualified Data.Set as S
import Data.Text (Text)
import qualified Data.Text as T
import Releve.Criteria (criteria)
import Releve.Declarations (Item (..), items, cited, unbinding)
import Releve.Types

data Framework = Framework
  { fName :: Text, fWhere :: Phrase, fBasis :: Phrase, fUrl :: Text
  , fParts :: [Text] }   -- ^ its provisions, each as "WCAG 1.1.1", "RGAA 1.1", "BITV 2.0 §4", or a rule's id

-- | The WCAG success criteria of levels A and AA: those of 2.0, then those 2.1 added, then 2.2,
--   which added six and made 4.1.1 obsolete.
wcag20, wcag21, wcag22 :: [Text]
wcag20 = T.words "1.1.1 1.2.1 1.2.2 1.2.3 1.2.4 1.2.5 1.3.1 1.3.2 1.3.3 1.4.1 1.4.2 1.4.3 1.4.4 1.4.5 2.1.1 2.1.2 2.2.1 2.2.2 2.3.1 \
                 \2.4.1 2.4.2 2.4.3 2.4.4 2.4.5 2.4.6 2.4.7 3.1.1 3.1.2 3.2.1 3.2.2 3.2.3 3.2.4 3.3.1 3.3.2 3.3.3 3.3.4 4.1.1 4.1.2"
wcag21 = wcag20 ++ T.words "1.3.4 1.3.5 1.4.10 1.4.11 1.4.12 1.4.13 2.1.4 2.5.1 2.5.2 2.5.3 2.5.4 4.1.3"
wcag22 = (wcag21 \\ ["4.1.1"]) ++ T.words "2.4.11 2.5.7 2.5.8 3.2.6 3.3.7 3.3.8"

-- | Each RGAA 4.1.2 criterion and the WCAG success criteria it answers to, as the
--   RGAA's own data states them (DINUM, criteres.json, Licence Ouverte 2.0).
crosswalk :: [(Text, [Text])]
crosswalk = [ (r, T.splitOn "," w) | (r, w) <- map (fmap (T.drop 1) . T.breakOn "=") (T.words table) ]
  where
    table = "1.1=1.1.1 1.2=1.1.1,4.1.2 1.3=1.1.1,4.1.2 1.4=1.1.1 1.5=1.1.1 1.6=1.1.1 1.7=1.1.1 1.8=1.4.5 1.9=1.1.1,4.1.2 2.1=4.1.2 2.2=4.1.2 \
            \3.1=1.3.1,1.4.1 3.2=1.4.3 3.3=1.4.11 4.1=1.2.1,1.2.3 4.2=1.2.1,1.2.3 4.3=1.2.2 4.4=1.2.2 4.5=1.2.5 4.6=1.2.5 4.7=1.1.1 4.8=1.1.1 \
            \4.9=1.1.1 4.10=1.4.2 4.11=2.1.1,2.1.2 4.12=2.1.1,2.1.2 4.13=4.1.2 5.1=1.3.1 5.2=1.3.1 5.3=1.3.2,4.1.2 5.4=1.3.1 5.5=1.3.1 5.6=1.3.1 \
            \5.7=1.3.1 5.8=1.3.1 6.1=1.1.1,2.4.4,2.5.3 6.2=1.1.1,2.4.4 7.1=2.5.3,4.1.2 7.2=1.1.1,4.1.2 7.3=1.3.1,2.1.1,2.4.7 7.4=3.2.1,3.2.2 \
            \7.5=4.1.3 8.1=4.1.1 8.2=4.1.1,4.1.2 8.3=3.1.1 8.4=3.1.1 8.5=2.4.2 8.6=2.4.2 8.7=3.1.2 8.8=3.1.2 8.9=1.3.1 8.10=1.3.2 \
            \9.1=1.3.1,2.4.1,2.4.6,4.1.2 9.2=1.3.1 9.3=1.3.1 9.4=1.3.1 10.1=1.3.1,1.3.2 10.2=1.1.1,1.3.1 10.3=1.3.2,2.4.3 10.4=1.4.4 10.5=1.4.3 \
            \10.6=1.4.1 10.7=1.4.1,2.4.7 10.8=1.3.2,4.1.2 10.9=1.3.3,1.4.1 10.10=1.3.3,1.4.1 10.11=1.4.10 10.12=1.4.12 10.13=1.4.13 10.14=2.1.1 \
            \11.1=1.3.1,2.4.6,3.3.2,4.1.2 11.2=2.4.6,2.5.3,3.3.2 11.3=3.2.4 11.4=3.3.2 11.5=1.3.1,3.3.2 11.6=1.3.1,3.3.2 11.7=1.3.1,3.3.2 \
            \11.8=1.3.1 11.9=2.5.3,4.1.2 11.10=3.3.1,3.3.2 11.11=3.3.3 11.12=3.3.4 11.13=1.3.5 12.1=2.4.5 12.2=3.2.3 12.3=2.4.5 12.4=2.4.5,3.2.3 \
            \12.5=3.2.3 12.6=1.3.1,2.4.1,4.1.2 12.7=2.4.1,2.4.3,3.2.3 12.8=2.4.3 12.9=2.1.1,2.1.2 12.10=2.1.4 12.11=2.1.1 13.1=2.2.1,2.2.2 \
            \13.2=3.2.1 13.3=1.1.1,1.3.1,1.3.2,2.4.1,2.4.3,3.1.1,4.1.2 13.4=1.1.1,1.3.1,1.3.2,2.4.1,2.4.3,3.1.1,4.1.2 13.5=1.1.1 13.6=1.1.1 \
            \13.7=2.3.1 13.8=2.2.1,2.2.2 13.9=1.3.4 13.10=2.5.1 13.11=2.5.2 13.12=2.5.4"

-- | The RGESN 2024: how many criteria each of its nine families holds.
rgesn :: [Text]
rgesn = [ T.pack (show f) <> "." <> T.pack (show k) | (f, n) <- zip [1 :: Int ..] [10, 10, 7, 15, 8, 7, 4, 10, 7], k <- [1 .. n :: Int] ]

-- | Every provision addressed: the numbers the rules and questions cite, the
--   declared criteria, the WCAG criteria these reach, and the rules themselves.
addressed :: S.Set Text
addressed = S.fromList $ map ("RGAA " <>) rgaa ++ map ("RGESN " <>) (touched "RGESN" ++ ids "RGESN") ++ map ("WCAG " <>) wcag
                         ++ map ("AI Act " <>) (touched "art." ++ ids "AI Act" ++ map fst unbinding) ++ map cited items ++ map cId criteria
  where
    ids ref = [iId i | i <- items, iRef i == ref]
    rgaa = touched "RGAA" ++ ids "RGAA"
    wcag = concat [ws | (r, ws) <- crosswalk, r `elem` rgaa] ++ touched "WCAG" ++ ids "WCAG"

-- | How many of a text's provisions are addressed, out of how many.
coverage :: Framework -> (Int, Int)
coverage f = (length (filter (`S.member` addressed) (fParts f)), length (fParts f))

-- | The numbers of one referential that the criteria cite, after its name; a span counted whole.
touched :: Text -> [Text]
touched ref = nub (concatMap (spans . drop 1 . dropWhile (/= ref) . T.words . en . cRef) criteria)
  where
    spans = concatMap range . takeWhile numbered . filter (/= "·")
    numbered w = T.any isDigit (T.take 1 w)
    range w = case T.splitOn "–" w of
      [a, b] | [ta, na] <- T.splitOn "." a, [_, nb] <- T.splitOn "." b, Just x <- int' na, Just y <- int' nb -> [ta <> "." <> T.pack (show k) | k <- [x .. y]]
      _ -> [w]
    int' x = case reads (T.unpack x) :: [(Int, String)] of [(k, "")] -> Just k; _ -> Nothing

frameworks :: [Framework]
frameworks =
  [ Framework "WCAG 2.2 AA" ("Worldwide: the W3C's current standard, ISO/IEC 40500:2025" // "Monde : la norme actuelle du W3C, ISO/IEC 40500:2025")
      ("levels A and AA" // "niveaux A et AA") "https://www.w3.org/TR/WCAG22/" (w wcag22)
  , Framework "WCAG 2.1 AA" ("Worldwide: the version the laws below refer to" // "Monde : la version à laquelle renvoient les textes suivants")
      ("levels A and AA" // "niveaux A et AA") "https://www.w3.org/TR/WCAG21/" (w wcag21)
  , Framework "EN 301 549 · EAA" ("European Union: products and services under the European Accessibility Act, and public bodies" // "Union européenne : produits et services relevant de l'acte européen sur l'accessibilité, et organismes publics")
      ("EN 301 549 V3.2.1 chapter 9, WCAG 2.1 AA; Directive 2019/882 article 13(2)" // "EN 301 549 V3.2.1 chapitre 9, WCAG 2.1 AA ; directive 2019/882 article 13(2)")
      "https://eur-lex.europa.eu/eli/dir/2019/882/oj" (w wcag21 ++ ["EAA article 13(2)"])
  , Framework "RGAA 4.1.2" ("France: public bodies and large companies" // "France : organismes publics et grandes entreprises")
      ("106 criteria, built on WCAG 2.1 AA" // "106 critères, fondés sur WCAG 2.1 AA") "https://accessibilite.numerique.gouv.fr/methode/criteres-et-tests/" (map (("RGAA " <>) . fst) crosswalk)
  , Framework "BITV 2.0" ("Germany: federal public bodies" // "Allemagne : organismes publics fédéraux")
      ("EN 301 549, WCAG 2.1 AA; §4, German Sign Language and Easy German" // "EN 301 549, WCAG 2.1 AA ; §4, langue des signes allemande et allemand facile")
      "https://www.gesetze-im-internet.de/bitv_2_0/" (w wcag21 ++ ["BITV 2.0 §4"])
  , Framework "Section 508" ("United States: federal agencies" // "États-Unis : agences fédérales")
      ("Revised 508 Standards, WCAG 2.0 AA" // "Revised 508 Standards, WCAG 2.0 AA") "https://www.access-board.gov/ict/" (w wcag20)
  , Framework "ADA Title II" ("United States: state and local governments" // "États-Unis : États et collectivités locales")
      ("28 CFR 35.200, WCAG 2.1 AA" // "28 CFR 35.200, WCAG 2.1 AA") "https://www.ecfr.gov/current/title-28/chapter-I/part-35/subpart-H" (w wcag21)
  , Framework "ADA Title III" ("United States: businesses open to the public" // "États-Unis : établissements ouverts au public")
      ("no standard in the rule; courts and settlements refer to WCAG 2.1 AA" // "aucune norme dans le règlement ; tribunaux et accords renvoient à WCAG 2.1 AA")
      "https://www.ada.gov/resources/web-guidance/" (w wcag21)
  , Framework "AODA" ("Ontario: public bodies and organizations of 50 employees or more" // "Ontario : organismes publics et organisations de 50 salariés ou plus")
      ("O. Reg. 191/11 section 14, WCAG 2.0 AA but 1.2.4 and 1.2.5; the Act's section 14 report" // "O. Reg. 191/11 article 14, WCAG 2.0 AA hors 1.2.4 et 1.2.5 ; rapport de l'article 14 de la loi")
      "https://www.ontario.ca/laws/regulation/110191" (w (wcag20 \\ ["1.2.4", "1.2.5"]) ++ ["AODA section 14"])
  , Framework "JIS X 8341-3:2016" ("Japan: the national standard" // "Japon : la norme nationale")
      ("identical to WCAG 2.0, levels A and AA" // "identique à WCAG 2.0, niveaux A et AA") "https://www.jisc.go.jp/" (w wcag20)
  , Framework "DDA 1992" ("Australia: the Human Rights Commission's advisory notes 4.1" // "Australie : notes consultatives 4.1 de la Commission des droits de l'homme")
      ("WCAG 2.0 AA" // "WCAG 2.0 AA") "https://humanrights.gov.au/our-work/disability-rights/world-wide-web-access-disability-discrimination-act-advisory-notes-ver-41-2014" (w wcag20)
  , Framework "RGESN 2024" ("France: the eco-design referential" // "France : le référentiel d'écoconception")
      ("78 criteria in nine families" // "78 critères en neuf familles") "https://ecoresponsable.numerique.gouv.fr/publications/referentiel-general-ecoconception/" (map ("RGESN " <>) rgesn)
  , Framework "AI Act article 50" ("European Union: transparency of AI systems" // "Union européenne : transparence des systèmes d'IA")
      ("seven paragraphs" // "sept paragraphes") "https://eur-lex.europa.eu/eli/reg/2024/1689/oj#art_50" ["AI Act 50(" <> T.pack (show k) <> ")" | k <- [1 .. 7 :: Int]]
  , Framework "GDPR · ePrivacy" ("European Union: consent to cookies and trackers" // "Union européenne : consentement aux traceurs")
      ("GDPR article 7, ePrivacy Directive article 5(3), CNIL guidelines 2020-091" // "RGPD article 7, directive ePrivacy article 5(3), lignes directrices CNIL 2020-091")
      "https://eur-lex.europa.eu/eli/reg/2016/679/oj" ["consent-choice", "third-parties"]
  , Framework "CCPA · CPRA" ("California: businesses under the California Consumer Privacy Act" // "Californie : entreprises soumises au California Consumer Privacy Act")
      ("Civil Code §1798.135; regulations §7004(a)(2) and §7025" // "Civil Code §1798.135 ; règlement §7004(a)(2) et §7025")
      "https://cppa.ca.gov/regulations/" ["consent-choice", "CPRA §1798.135", "CPRA regulations §7025"]
  , Framework "DSA article 25" ("European Union: online platforms" // "Union européenne : plateformes en ligne")
      ("interfaces that deceive or manipulate" // "interfaces trompeuses ou manipulatrices") "https://eur-lex.europa.eu/eli/reg/2022/2065/oj" ["DSA article 25"]
  , Framework "PIPL article 24" ("China: automated decisions on personal information" // "Chine : décisions automatisées sur les données personnelles")
      ("transparency, fairness, and a way to refuse personalised targeting" // "transparence, équité, et un moyen de refuser le ciblage personnalisé")
      "https://www.cac.gov.cn/2021-08/20/c_1631050028355286.htm" ["PIPL article 24"] ]
  where w = map ("WCAG " <>)
