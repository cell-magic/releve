-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
{-# LANGUAGE OverloadedStrings #-}
-- | The criteria that no rule can see from a page and that hold for a whole
--   site: the RGESN 2024 criteria on how a service is decided, built, hosted and
--   run, the RGAA 4.1.2 criteria on a set of pages, and the duties of article 50
--   of the AI Act that bear on what no page shows. The owner declares them,
--   once for the whole record. Each comes with what the observation did see that
--   bears on it. The questions are this tool's short form; the official texts,
--   under Licence Ouverte 2.0, prevail and are linked from every report.
module Releve.Declarations (Item (..), items, family, official, cited, slug, unbinding, covered) where

import Data.Char (isAlphaNum)
import Data.List (nub)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Releve.Types

data Item = Item { iRef :: Text, iId :: Text, iAsk :: Phrase, iSeen :: Observation -> Maybe Phrase }

-- | How a declaration names its criterion: the referential, then the number.
cited :: Item -> Text
cited i = iRef i <> " " <> iId i

-- | A name for a criterion fit for a form field: "rgesn-1-3", "ai-act-50-2".
slug :: Item -> Text
slug = T.intercalate "-" . filter (not . T.null) . T.split (not . isAlphaNum) . T.toLower . cited

-- | The address of a criterion in the official referential.
official :: Item -> Text
official i
  | iRef i == "RGAA" = "https://accessibilite.numerique.gouv.fr/methode/criteres-et-tests/#" <> iId i
  | iRef i == "AI Act" = "https://eur-lex.europa.eu/eli/reg/2024/1689/oj#art_50"
  | otherwise = "https://ecoresponsable.numerique.gouv.fr/publications/referentiel-general-ecoconception/critere/" <> iId i <> "/"

-- | The family a criterion is listed under: the RGAA ones under navigation.
family :: Item -> Phrase
family it | iRef it == "RGAA" = "Navigation across pages" // "Navigation entre les pages"
family it | iRef it == "AI Act" = "Artificial intelligence, beyond the page" // "Intelligence artificielle, au-delà de la page"
family it = case T.takeWhile (/= '.') (iId it) of
  "1" -> "Strategy" // "Stratégie"
  "2" -> "Specifications" // "Spécifications"
  "3" -> "Architecture" // "Architecture"
  "4" -> "Interface" // "UX/UI"
  "5" -> "Content" // "Contenus"
  "6" -> "Front end" // "Frontend"
  "7" -> "Back end" // "Backend"
  "8" -> "Hosting" // "Hébergement"
  _ -> "Algorithms" // "Algorithmie"

items :: [Item]
items =
  [ q "1.1" ("Has the service's usefulness been weighed against its environmental impact?" // "L'utilité du service a-t-elle été évaluée au regard de ses impacts environnementaux ?") none
  , q "1.2" ("Are the target users, business needs and user expectations defined?" // "Les utilisateurs cibles, besoins métiers et attentes sont-ils définis ?") none
  , q "1.3" ("Is there a named eco-design lead?" // "Un référent en écoconception est-il désigné ?") none
  , q "1.4" ("Is the eco-design approach reviewed regularly?" // "La démarche d'écoconception est-elle revue régulièrement ?") none
  , q "1.5" ("Are there targets for reducing the service's own impact?" // "Des objectifs de réduction des impacts du service sont-ils fixés ?") none
  , q "1.6" ("Is data collected only as needed?" // "La donnée est-elle collectée au strict nécessaire ?") fields
  , q "1.7" ("Is encryption matched to need?" // "Le chiffrement est-il adapté au besoin ?") tlsSeen
  , q "1.8" ("Is the service open source where it can be?" // "Le service est-il ouvert en open source là où il le peut ?") none
  , q "1.9" ("Is the service built on open, interoperable standards?" // "Le service repose-t-il sur des standards ouverts et interopérables ?") none
  , q "1.10" ("Does the service use documented, open APIs to work with hardware?" // "Le service utilise-t-il des API ouvertes et documentées pour le matériel ?") none
  , q "2.1" ("Are the supported device profiles listed?" // "Les profils de terminaux pris en charge sont-ils listés ?") none
  , q "2.2" ("Does the service work on older devices?" // "Le service fonctionne-t-il sur des terminaux anciens ?") weight'
  , q "2.3" ("Does the service work on a slow connection or offline?" // "Le service fonctionne-t-il en bas débit ou hors connexion ?") weight'
  , q "2.4" ("Does the service work on older systems and browsers?" // "Le service fonctionne-t-il sur des systèmes et navigateurs anciens ?") none
  , q "2.6" ("Do design and code reviews include reducing each feature's impact?" // "Les revues de conception et de code visent-elles à réduire l'impact de chaque fonctionnalité ?") none
  , q "2.7" ("Is there a maintenance and decommissioning plan?" // "Une stratégie de maintenance et de décommissionnement est-elle prévue ?") none
  , q "2.8" ("Are suppliers required to reduce their impact?" // "Les fournisseurs sont-ils tenus de réduire leurs impacts ?") none
  , q "2.9" ("Was the impact of ready-made interface components weighed?" // "L'impact des composants d'interface prêts à l'emploi a-t-il été pris en compte ?") scripts
  , q "2.10" ("Was the impact of third-party services weighed when choosing them?" // "L'impact des services tiers a-t-il été pris en compte dans leur choix ?") thirds
  , q "3.1" ("Is the architecture designed to reduce its own impact?" // "L'architecture est-elle conçue pour réduire ses propres impacts ?") none
  , q "3.2" ("Do resources scale with actual use?" // "Les ressources s'adaptent-elles à l'usage réel ?") none
  , q "3.4" ("Are corrective updates guaranteed for the planned life of devices and software?" // "Les mises à jour correctives sont-elles garanties pendant la durée de vie prévue ?") none
  , q "3.5" ("Can corrective updates be installed apart from feature updates?" // "Les mises à jour correctives s'installent-elles indépendamment des évolutives ?") none
  , q "3.6" ("Are updates incremental?" // "Les mises à jour sont-elles incrémentielles ?") none
  , q "3.7" ("Are development, staging and test environments sized to need?" // "Les environnements de développement, préproduction et test sont-ils dimensionnés au besoin ?") none
  , q "4.3" ("Is the path to each main feature as short as it can be?" // "Le parcours vers chaque fonctionnalité principale est-il optimisé ?") none
  , q "4.5" ("Are native components used for the most part?" // "Les composants natifs sont-ils majoritairement utilisés ?") none
  , q "4.6" ("Does all video, audio and animation carry information?" // "Toute vidéo, tout son et toute animation portent-ils une information ?") media
  , q "4.7" ("Is the lightest format chosen among text, image, audio and video?" // "Le format le plus sobre est-il choisi entre texte, image, son et vidéo ?") media
  , q "4.9" ("Are server requests limited while the user types?" // "Les requêtes serveur sont-elles limitées pendant la saisie ?") fields
  , q "4.10" ("Is the expected input format shown before sending?" // "Le format de saisie attendu est-il indiqué avant l'envoi ?") fields
  , q "4.11" ("Are expected file size and format shown before upload?" // "Le poids et le format de fichier attendus sont-ils indiqués avant l'envoi ?") uploads
  , q "4.12" ("Are users told when a feature has a high environmental impact?" // "L'utilisateur est-il informé quand une fonctionnalité a un impact important ?") none
  , q "4.14" ("Is the interface free of manipulative patterns?" // "L'interface est-elle exempte de procédés manipulatoires ?") none
  , q "4.15" ("Can users track and reduce the impact of their own use?" // "L'utilisateur peut-il suivre et réduire l'impact de ses usages ?") none
  , q "5.2" ("Is image compression matched to content and display?" // "La compression des images est-elle adaptée au contenu et à l'affichage ?") images
  , q "5.3" ("Is each video's resolution matched to content and display?" // "La définition de chaque vidéo est-elle adaptée au contenu et à l'affichage ?") media
  , q "5.4" ("Is video compression efficient for content and display?" // "La compression des vidéos est-elle efficace et adaptée ?") media
  , q "5.5" ("Do videos offer an audio-only mode?" // "Les vidéos proposent-elles un mode « écoute seule » ?") media
  , q "5.6" ("Is audio compression matched to content and listening?" // "La compression des contenus audio est-elle adaptée ?") media
  , q "5.7" ("Is each document in a format suited to its use?" // "Chaque document est-il dans un format adapté à son usage ?") documents
  , q "5.8" ("Is there a plan to archive or delete outdated content?" // "Une stratégie d'archivage ou de suppression des contenus obsolètes existe-t-elle ?") none
  , q "6.1" ("Is there a weight and request budget per screen?" // "Un poids et un nombre de requêtes maximums par écran sont-ils fixés ?") weight'
  , q "7.1" ("Is the most used data cached on the server?" // "Les données les plus utilisées sont-elles mises en cache côté serveur ?") none
  , q "7.2" ("Are retention periods set for data and documents?" // "Des durées de conservation sont-elles fixées pour les données et documents ?") none
  , q "7.3" ("Are users told when processing runs in the background?" // "L'utilisateur est-il informé d'un traitement en arrière-plan ?") none
  , q "7.4" ("Does any consensus mechanism minimize its resource use?" // "Le mécanisme de consensus éventuel minimise-t-il ses ressources ?") none
  , q "8.1" ("Does the host have a plan to reduce its footprint?" // "L'hébergeur a-t-il une démarche de réduction de son empreinte ?") host
  , q "8.2" ("Does the host manage its equipment sustainably?" // "L'hébergeur a-t-il une politique de gestion durable des équipements ?") host
  , q "8.3" ("Is the host's PUE (power usage effectiveness) minimized?" // "Le PUE de l'hébergeur est-il minimisé ?") host
  , q "8.4" ("Is the host's WUE (water usage effectiveness) minimized?" // "Le WUE de l'hébergeur est-il minimisé ?") host
  , q "8.5" ("Is the host's electricity documented and mostly renewable?" // "L'électricité de l'hébergeur est-elle documentée et majoritairement renouvelable ?") host
  , q "8.6" ("Is the hosting location consistent with the service's activity?" // "La localisation de l'hébergement est-elle cohérente avec l'activité du service ?") host
  , q "8.7" ("Does the host put server heat to use?" // "L'hébergeur valorise-t-il la chaleur des serveurs ?") host
  , q "8.8" ("Are hot and cold data stored apart?" // "Les données chaudes et froides sont-elles hébergées séparément ?") none
  , q "8.9" ("Is data duplicated only where needed?" // "Les données ne sont-elles dupliquées que si nécessaire ?") none
  , q "8.10" ("Are deferred computations and transfers timed to reduce impact?" // "Les calculs et transferts asynchrones sont-ils planifiés pour réduire leur impact ?") none
  , q "9.1" ("Was the need for model training questioned?" // "La nécessité d'une phase d'entraînement a-t-elle été interrogée ?") none
  , q "9.2" ("Is model complexity proportionate to actual use?" // "La complexité du modèle est-elle proportionnée à l'usage réel ?") none
  , q "9.3" ("Is the amount of training kept down?" // "La quantité d'entraînement est-elle limitée ?") none
  , q "9.4" ("Is training data limited to what is needed?" // "Les données d'entraînement sont-elles limitées au nécessaire ?") none
  , q "9.5" ("Is retraining timed to need?" // "La fréquence de réentraînement est-elle adaptée au besoin ?") none
  , q "9.6" ("Are models compressed?" // "Les modèles sont-ils compressés ?") none
  , q "9.7" ("Is inference optimized for resources and users?" // "L'inférence est-elle optimisée en ressources et selon les utilisateurs ?") none
  ]
  ++
  [ r "12.1" ("Does the site offer at least two ways to find a page: menu, search, or site map?" // "Le site offre-t-il au moins deux moyens de trouver une page : menu, recherche ou plan du site ?") none
  , r "12.2" ("Are the menu and navigation bars in the same place on every page?" // "Le menu et les barres de navigation sont-ils au même endroit sur chaque page ?") none
  , r "12.3" ("Does the site map list the site's pages and lead to them?" // "Le plan du site liste-t-il les pages du site et y mène-t-il ?") none
  , r "12.4" ("Is the site map reached the same way from every page?" // "Le plan du site s'atteint-il de la même façon depuis chaque page ?") none
  , r "12.5" ("Is the search reached the same way from every page?" // "La recherche s'atteint-elle de la même façon depuis chaque page ?") none
  ]
  ++
  [ a "50(2)" ("If the service provides an AI system that generates sound, images, video or text, are its outputs marked, in a form a machine can read, as artificially generated?"
               // "Si le service fournit un système d'IA qui produit du son, des images, de la vidéo ou du texte, ses productions sont-elles marquées, sous une forme lisible par machine, comme générées artificiellement ?") none
  , a "50(3)" ("If the service recognizes emotions or sorts people by biometric traits, are the people exposed told how it works?"
               // "Si le service reconnaît des émotions ou classe des personnes selon des traits biométriques, les personnes exposées sont-elles informées de son fonctionnement ?") asking
  , a "50(4)" ("Are deep fakes, in image, sound or video, and AI-written text published to inform the public disclosed as such, unless a person holds editorial responsibility for the text?"
               // "Les hypertrucages, en image, en son ou en vidéo, et le texte écrit par IA publié pour informer le public sont-ils signalés comme tels, sauf si une personne assume la responsabilité éditoriale du texte ?") origins
  ]
  where
    q = Item "RGESN"
    r = Item "RGAA"
    a = Item "AI Act"
    none _ = Nothing
    n = T.pack . show
    rs o = concat (resources (network o))
    kb x = n (round (fromIntegral x / 1024 :: Double) :: Int)
    -- What the observation saw that bears on the question; nothing where it saw nothing.
    tlsSeen o = (\t -> ("served over " <> t) // ("servi en " <> t)) <$> tls (page o)
    weight' o = Just ((n (requests (network o)) <> " requests, " <> kb (transfer (network o)) <> " kB, " <> n (dom (page o)) <> " elements")
                      // (n (requests (network o)) <> " requêtes, " <> kb (transfer (network o)) <> " ko, " <> n (dom (page o)) <> " éléments"))
    thirds o = case thirdParties (network o) of
      [] -> Just ("no third-party host" // "aucun hôte tiers")
      hs -> Just (both (T.intercalate ", " hs))
    scripts o = case [r | r <- rs o, xKind r == "Script"] of
      [] -> Just ("no script" // "aucun script")
      xs -> Just ((n (length xs) <> " scripts, " <> kb (sum (map xBytes xs)) <> " kB") // (n (length xs) <> " scripts, " <> kb (sum (map xBytes xs)) <> " ko"))
    images o = case [r | r <- rs o, "image/" `T.isPrefixOf` xMime r] of
      [] -> Nothing
      xs -> Just ((n (length xs) <> " images, " <> kb (sum (map xBytes xs)) <> " kB") // (n (length xs) <> " images, " <> kb (sum (map xBytes xs)) <> " ko"))
    media o = case [s | s <- surfaces o, kind s == "media"] of
      [] -> Just ("no audio or video on the page" // "ni son ni vidéo dans la page")
      xs -> Just ((n (length xs) <> " audio or video elements") // (n (length xs) <> " éléments audio ou vidéo"))
    fields o = case [s | s <- surfaces o, kind s == "control"] of
      [] -> Just ("no form field on the page" // "aucun champ de formulaire dans la page")
      xs -> Just ((n (length xs) <> " form fields") // (n (length xs) <> " champs de formulaire"))
    uploads o = case [s | s <- surfaces o, kind s == "control", itype s == Just "file"] of
      [] -> Just ("no file upload on the page" // "aucun envoi de fichier dans la page")
      xs -> Just ((n (length xs) <> " file upload fields") // (n (length xs) <> " champs d'envoi de fichier"))
    documents o = case nub [h | s <- surfaces o, kind s == "link", Just h <- [href s], any (`T.isSuffixOf` T.toLower (T.takeWhile (`notElem` ("?#" :: String)) h)) exts] of
      [] -> Just ("no linked document on the page" // "aucun document lié dans la page")
      xs -> Just ((n (length xs) <> " linked documents") // (n (length xs) <> " documents liés"))
    exts = [".pdf", ".doc", ".docx", ".odt", ".xls", ".xlsx", ".ods", ".ppt", ".pptx", ".odp"]
    asking o = case fromMaybe [] (asked (page o)) of
      [] -> Just ("the page asks nothing of the device on arrival" // "la page ne demande rien à l'appareil à l'arrivée")
      xs -> Just (("the page asks for " // "la page demande ") <> both (T.intercalate ", " xs))
    origins o = case [x | s <- surfaces o, kind s == "img", Just x <- [origin s]] of
      [] -> Just ("no image on the page states its origin" // "aucune image de la page ne déclare son origine")
      xs -> Just ((n (length xs) <> " images state their origin") // (n (length xs) <> " images déclarent leur origine"))
    host o = Just (both (fromMaybe (url o) (hostOf (url o))) <> (if ipv6 (page o) == Just True then " · IPv6" else ""))
    hostOf u = case T.splitOn "/" u of
      _ : _ : h : _ | not (T.null h) -> Just h
      _ -> Nothing

-- | The paragraphs of article 50 that place no duty on a site, and why.
unbinding :: [(Text, Phrase)]
unbinding =
  [ ("50(6)", "keeps the other rules on high-risk systems and on transparency in force" // "maintient les autres règles sur les systèmes à haut risque et sur la transparence")
  , ("50(7)", "is addressed to the Commission, which encourages codes of practice" // "s'adresse à la Commission, qui encourage les codes de bonne pratique") ]

-- | How many of a text's provisions are addressed, out of how many: by a rule
--   or a question (the numbers the criteria cite), by the owner's declaration,
--   or, for article 50, by saying that a paragraph binds no site.
covered :: [Text] -> Text -> (Int, Int)
covered touched' ref = case ref of
  "RGAA" -> (addressed, 106)
  "RGESN" -> (addressed, 78)
  _ -> (length (nub (filter (`elem` paragraphs) (touched' ++ declaredHere ++ map fst unbinding))), 7)
  where
    declaredHere = [iId i | i <- items, iRef i == ref || (ref == "art." && iRef i == "AI Act")]
    addressed = length (nub (touched' ++ declaredHere))
    paragraphs = ["50(" <> T.pack (show k) <> ")" | k <- [1 .. 7 :: Int]]
