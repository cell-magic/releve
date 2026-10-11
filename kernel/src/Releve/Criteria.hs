-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
{-# LANGUAGE OverloadedStrings #-}
-- | The criteria. Each is a pure function from an observation to marks.
--   A criterion states its source and what it is for; thresholds that are
--   this tool's own choice say so. Whatever a mark says, it says in each
--   language of the reports.
module Releve.Criteria (criteria, version) where

import Data.Char (isAlpha, isAlphaNum, isDigit, isSpace)
import Data.List (isSuffixOf, isPrefixOf, nub, sortOn)
import qualified Data.Map.Strict as M
import Data.Maybe (fromMaybe, isNothing, listToMaybe, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Text.Printf (printf)
import Releve.Colour
import Releve.Types

version :: Text
version = "4"

criteria :: [Criterion]
criteria =
  [ Criterion "page-title" ("The page has a title" // "La page a un titre") "RGAA 8.5 · WCAG 2.4.2" Light
      ("The title is what a browser tab, a bookmark, a search result and a screen reader's first words show of the page."
       // "Le titre est ce que montrent de la page un onglet, un favori, un résultat de recherche et les premiers mots d'un lecteur d'écran.")
      pageTitle
  , Criterion "page-lang" ("The page states its language" // "La page déclare sa langue") "RGAA 8.3 · WCAG 3.1.1" Light
      ("The declared language sets the voice a screen reader speaks with, the hyphenation, and the translation a browser offers."
       // "La langue déclarée règle la voix d'un lecteur d'écran, la césure, et la traduction que propose le navigateur.")
      pageLang
  , Criterion "doctype" ("The page declares its document type" // "La page déclare son type de document") "RGAA 8.1" Light
      ("The doctype asks the browser to lay the page out by the standard; without it, rendering falls back on the quirks of the 1990s."
       // "Le doctype demande au navigateur de composer la page selon le standard ; sans lui, le rendu retombe dans les particularités des années 1990.")
      doctypeC
  , Criterion "zoom" ("Zoom is not blocked" // "L'agrandissement n'est pas bloqué") "RGAA 10.4 · WCAG 1.4.4" Light
      ("A reader who needs larger text enlarges the page; a viewport that forbids it removes the one adjustment they have."
       // "Qui a besoin d'un texte plus grand agrandit la page ; un viewport qui l'interdit retire le seul réglage disponible.")
      zoom
  , Criterion "reflow" ("No horizontal scrolling at 320 px" // "Pas de défilement horizontal à 320 px") "RGAA 10.11 · WCAG 1.4.10 · RGESN 2.5" Heavy
      ("At 320 px wide, the width of a small phone or of a desktop page enlarged four times, content is read by scrolling one way only."
       // "À 320 px de large, largeur d'un petit téléphone ou d'une page agrandie quatre fois, le contenu se lit en ne défilant que dans un sens.")
      reflowC
  , Criterion "main-region" ("The main content is marked" // "Le contenu principal est balisé") "RGAA 9.2 · 12.6 · WCAG 2.4.1" Light
      ("A marked main region lets a reader go straight to the content, past what every page repeats."
       // "Une zone principale balisée permet d'aller droit au contenu, au-delà de ce que chaque page répète.")
      mainRegion
  , Criterion "skip-link" ("A link leads to the main content" // "Un lien mène au contenu principal") "RGAA 12.7 · WCAG 2.4.1" Light
      ("A first link to the main content spares a keyboard user every repeated link, on every page."
       // "Un premier lien vers le contenu principal épargne à qui navigue au clavier tous les liens répétés, à chaque page.")
      skipLink
  , Criterion "heading-order" ("Heading levels follow each other" // "Les niveaux de titre se suivent") "RGAA 9.1 · WCAG 1.3.1" Medium
      ("Headings are the page's table of contents: assistive technology lists them and jumps between them, level by level."
       // "Les titres sont la table des matières de la page : les technologies d'assistance les listent et sautent de l'un à l'autre, niveau par niveau.")
      headingOrder
  , Criterion "heading-look" ("What looks like a heading is one" // "Ce qui a l'air d'un titre en est un") ("RGAA 9.1 · WCAG 1.3.1 · thresholds (tool)" // "RGAA 9.1 · WCAG 1.3.1 · seuils (outil)") Light
      ("Text that looks like a heading and is not marked as one titles the page for the eye only."
       // "Un texte qui a l'air d'un titre sans être balisé comme tel ne titre la page que pour l'œil.")
      headingLook
  , Criterion "list-look" ("What looks like a list is one" // "Ce qui a l'air d'une liste en est une") "RGAA 9.3 · WCAG 1.3.1" Light
      ("A marked list announces how many items it holds and lets a reader move from one to the next."
       // "Une liste balisée annonce combien d'éléments elle contient et permet de passer de l'un au suivant.")
      listLook
  , Criterion "empty-blocks" ("No element is used as a gap" // "Aucun élément ne sert d'espace") "RGAA 8.9 · WCAG 1.3.1" Light
      ("An element that holds nothing is still announced, or counted, by assistive technology: spacing belongs to the style sheet."
       // "Un élément vide reste annoncé, ou compté, par les technologies d'assistance : l'espacement relève de la feuille de styles.")
      emptyBlocks
  , Criterion "presentation" ("Appearance is left to the style sheet" // "L'apparence est confiée à la feuille de styles") "RGAA 10.1 · WCAG 1.3.1" Medium
      ("Appearance written into the markup cannot be adapted by a reader's own styles; left to the style sheet, it can."
       // "Une apparence écrite dans le balisage échappe aux styles du lecteur ; confiée à la feuille de styles, elle s'y adapte.")
      presentation
  , Criterion "image-alt" ("Images carry a text alternative" // "Les images portent une alternative textuelle") "RGAA 1.1–1.3 · WCAG 1.1.1" Light
      ("The text alternative is what an image says where it cannot be seen: to a screen reader, to a search engine, on a slow connection."
       // "L'alternative textuelle est ce que dit une image là où elle ne peut être vue : à un lecteur d'écran, à un moteur de recherche, sur une connexion lente.")
      imageAlt
  , Criterion "text-contrast" ("Text contrasts with its background" // "Le texte contraste avec son fond") "RGAA 3.2 · WCAG 1.4.3" Light
      ("Contrast decides whether text is read in sunlight, on a worn screen, by eyes that have aged or that see colours differently."
       // "Le contraste décide si un texte se lit au soleil, sur un écran fatigué, par des yeux qui ont vieilli ou qui voient autrement les couleurs.")
      contrast
  , Criterion "link-name" ("Links have a name" // "Les liens ont un intitulé") "RGAA 6.1–6.2 · WCAG 2.4.4" Light
      ("A link's name is all a reader has when links are listed out of their context, which is how assistive technology offers them."
       // "L'intitulé d'un lien est tout ce dont dispose un lecteur quand les liens sont listés hors de leur contexte, comme le proposent les technologies d'assistance.")
      linkName
  , Criterion "link-distinct" ("Links to different places differ in name" // "Des liens vers des lieux différents diffèrent d'intitulé") "RGAA 6.1 · WCAG 2.4.4" Medium
      ("Two links with one name and two destinations cannot be told apart in a list of links."
       // "Deux liens de même intitulé menant à deux destinations ne se distinguent pas dans une liste de liens.")
      linkDistinct
  , Criterion "button-name" ("Buttons have a name" // "Les boutons ont un intitulé") "RGAA 11.9 · WCAG 4.1.2" Light
      ("A button without a name is announced as “button”, and nothing says what it does."
       // "Un bouton sans intitulé est annoncé « bouton », et rien ne dit ce qu'il fait.")
      buttonName
  , Criterion "label-in-name" ("The visible label is in the name" // "L'intitulé visible figure dans le nom") "RGAA 6.1 · 11.2 · 11.9 · WCAG 2.5.3" Light
      ("Someone who speaks to their device says what they see; the command works only if the visible words are in the name the code gives."
       // "Qui commande son appareil à la voix dit ce qu'il voit ; la commande n'aboutit que si les mots visibles figurent dans le nom donné par le code.")
      labelInName
  , Criterion "control-label" ("Form fields have a label" // "Les champs de formulaire ont une étiquette") "RGAA 11.1 · WCAG 1.3.1" Light
      ("A label says what a field expects, stays when typing begins, and enlarges the area a finger or a pointer can aim at."
       // "L'étiquette dit ce qu'attend un champ, demeure quand la saisie commence, et agrandit la zone que vise un doigt ou un pointeur.")
      controlLabel
  , Criterion "group-legend" ("Groups of fields have a legend" // "Les groupes de champs ont une légende") "RGAA 11.6 · WCAG 1.3.1" Light
      ("A legend names the question that a set of choices answers; without it each choice is announced alone."
       // "La légende nomme la question à laquelle répond un ensemble de choix ; sans elle chaque choix est annoncé seul.")
      groupLegend
  , Criterion "field-group" ("Choices of one question are grouped" // "Les choix d'une même question sont regroupés") "RGAA 11.5 · WCAG 1.3.1" Medium
      ("Choices that belong to one question are grouped so that they are announced, and understood, together."
       // "Les choix d'une même question se regroupent pour être annoncés, et compris, ensemble.")
      fieldGroup
  , Criterion "autocomplete" ("Fields for personal data state their purpose" // "Les champs de données personnelles déclarent leur finalité") "RGAA 11.13 · WCAG 1.3.5" Light
      ("A declared purpose lets the browser fill a field for the reader: less typing, fewer errors, and help for those who struggle with either."
       // "Une finalité déclarée permet au navigateur de remplir le champ pour le lecteur : moins de saisie, moins d'erreurs, et une aide pour qui peine à l'une ou l'autre.")
      autocompleteC
  , Criterion "table-headers" ("Data tables declare their headers" // "Les tableaux de données déclarent leurs en-têtes") "RGAA 5.3 · 5.6–5.8 · WCAG 1.3.1" Medium
      ("Header cells are what lets a cell be announced with its column and its row; without them a table is a run of values."
       // "Les cellules d'en-tête permettent d'annoncer une cellule avec sa colonne et sa ligne ; sans elles un tableau est une suite de valeurs.")
      tableHeaders
  , Criterion "frame-title" ("Frames have a title" // "Les cadres ont un titre") "RGAA 2.1 · WCAG 4.1.2" Light
      ("A frame holds another document; its title says which, before the reader enters it."
       // "Un cadre contient un autre document ; son titre dit lequel, avant que le lecteur y entre.")
      frameTitle
  , Criterion "autoplay" ("No sound starts by itself" // "Aucun son ne démarre seul") "RGAA 4.10 · WCAG 1.4.2" Light
      ("Sound that starts alone covers the voice of a screen reader, which is how its user hears the page."
       // "Un son qui démarre seul couvre la voix du lecteur d'écran, par laquelle son utilisateur entend la page.")
      autoplayC
  , Criterion "media-captions" ("Videos carry captions" // "Les vidéos portent des sous-titres") "RGAA 4.3 · WCAG 1.2.2" Heavy
      ("Captions carry speech and sound to those who do not hear them, and to anyone reading with the sound off."
       // "Les sous-titres portent la parole et les sons à qui ne les entend pas, et à quiconque lit sans le son.")
      mediaCaptions
  , Criterion "unique-ids" ("Element ids are unique" // "Les id des éléments sont uniques") "RGAA 8.2" Light
      ("Labels, descriptions and in-page links point at an element by its id; a repeated id makes them point at the wrong one."
       // "Étiquettes, descriptions et liens internes désignent un élément par son id ; un id répété les fait désigner le mauvais.")
      uniqueIds
  , Criterion "tab-order" ("The keyboard follows the order of the page" // "Le clavier suit l'ordre de la page") "RGAA 12.8 · WCAG 2.4.3" Medium
      ("The keyboard follows the order of the code; a positive tabindex takes an element out of that order and puts it first."
       // "Le clavier suit l'ordre du code ; un tabindex positif sort un élément de cet ordre et le place en tête.")
      tabOrder
  , Criterion "hidden-focus" ("Nothing hidden takes the focus" // "Rien de caché ne prend le focus") "RGAA 10.8 · WCAG 4.1.2" Medium
      ("Content hidden from assistive technology and still reached by the keyboard leaves the reader on something that is not announced."
       // "Un contenu caché aux technologies d'assistance mais atteint au clavier laisse le lecteur sur un élément qui n'est pas annoncé.")
      hiddenFocusC
  , Criterion "no-popup" ("No window opens by itself" // "Aucune fenêtre ne s'ouvre seule") "RGAA 13.2 · WCAG 3.2.1" Medium
      ("A window that opens by itself moves the reader somewhere they did not choose, and may not be noticed at all."
       // "Une fenêtre qui s'ouvre seule déplace le lecteur là où il n'a pas choisi d'aller, parfois sans qu'il s'en aperçoive.")
      noPopup
  , Criterion "refresh" ("The page does not reload or leave on a timer" // "La page ne se recharge ni ne s'en va après un délai") "RGAA 13.1 · WCAG 2.2.1" Light
      ("A page that reloads or leaves on a timer takes the reader's place, and their time, away from them."
       // "Une page qui se recharge ou s'en va après un délai retire au lecteur sa place, et son temps.")
      refreshC
  , Criterion "ai-disclosure" ("Conversational AI is disclosed" // "L'IA conversationnelle est signalée") "AI Act art. 50(1)" Medium
      ("A person has to know when the other party to a conversation is a machine: the AI Act requires that they be told."
       // "Une personne doit savoir quand son interlocuteur est une machine : le règlement sur l'IA impose de le lui dire.")
      aiDisclosure
  , Criterion "ai-image" ("Images made by AI say so" // "Les images produites par IA le disent") "AI Act art. 50(2) · 50(4)" Medium
      ("An image generated or altered by an AI system has to be disclosed as such to those who see it; the file itself often says where it comes from."
       // "Une image produite ou modifiée par un système d'IA doit être signalée comme telle à qui la voit ; le fichier lui-même dit souvent d'où il vient.")
      aiImage
  , Criterion "asks-on-arrival" ("Nothing is asked of the device on arrival" // "Rien n'est demandé à l'appareil à l'arrivée") "RGESN 4.13 · 6.6 · AI Act art. 50(3)" Light
      ("A request for location, camera or notifications before the reader has done anything is answered without knowing why it is asked."
       // "Une demande de position, de caméra ou de notifications avant que le lecteur ait rien fait reçoit une réponse sans qu'il sache pourquoi on la lui pose.")
      asksOnArrival
  , Criterion "third-parties" ("Third parties wait for consent" // "Les tiers attendent le consentement") "RGESN 4.4" Medium
      ("Each third party is a connection to another company's servers, opened for every reader before they have said anything."
       // "Chaque tiers est une connexion aux serveurs d'une autre entreprise, ouverte pour chaque lecteur avant qu'il ait rien dit.")
      thirdPartiesC
  , Criterion "media-autoplay" ("Nothing plays by itself" // "Rien ne se lance seul") "RGESN 4.1" Light
      ("Media that starts by itself is downloaded and decoded for readers who did not ask for it."
       // "Un média qui se lance seul est téléchargé et décodé pour des lecteurs qui ne l'ont pas demandé.")
      mediaAutoplay
  , Criterion "endless" ("The page has an end" // "La page a une fin") ("RGESN 4.2 · threshold one screen, twice (tool)" // "RGESN 4.2 · seuil un écran, deux fois (outil)") Medium
      ("A page that grows each time its end is reached has none: its weight is whatever the reader's patience allows, and its footer is never reached."
       // "Une page qui s'allonge chaque fois qu'on atteint sa fin n'en a pas : son poids est ce que permet la patience du lecteur, et son pied de page n'est jamais atteint.")
      endless
  , Criterion "fonts" ("Fonts are few and light" // "Les polices sont peu nombreuses et légères") "RGESN 4.8" Light
      ("Each font file is fetched before the text it sets shows as designed; two fonts in four variants, or 400 kB, is the reference's limit."
       // "Chaque fichier de police est chargé avant que le texte qu'il compose s'affiche tel que dessiné ; deux polices en quatre variantes, ou 400 ko, est la limite du référentiel.")
      fontsC
  , Criterion "compression" ("Text travels compressed" // "Le texte voyage compressé") ("RGESN 6.3 · threshold 1 kB (tool)" // "RGESN 6.3 · seuil 1 ko (outil)") Light
      ("Text compresses to a third of its size or less; sent as it is, the rest travels for nothing."
       // "Le texte se compresse au tiers de sa taille ou moins ; envoyé tel quel, le reste voyage pour rien.")
      compression
  , Criterion "caching" ("What does not change is kept by the browser" // "Ce qui ne change pas est gardé par le navigateur") "RGESN 6.2" Light
      ("A file the browser may keep is not fetched again on the next page, nor on the next visit."
       // "Un fichier que le navigateur peut garder n'est pas rechargé à la page suivante, ni à la visite suivante.")
      caching
  , Criterion "protocol" ("The page travels by current protocols" // "La page voyage par des protocoles actuels") "RGESN 3.3 · 6.7" Medium
      ("HTTP/2 and 3 carry a page's files over one connection; TLS 1.3 opens it in fewer exchanges; IPv6 reaches readers without address translation."
       // "HTTP/2 et 3 portent les fichiers d'une page sur une seule connexion ; TLS 1.3 l'ouvre en moins d'échanges ; IPv6 joint les lecteurs sans traduction d'adresse.")
      protocolC
  , Criterion "lazy-images" ("Images far down the page wait to be reached" // "Les images loin dans la page attendent d'être atteintes") ("RGESN 6.5 · threshold two screens (tool)" // "RGESN 6.5 · seuil deux écrans (outil)") Light
      ("An image far below the screen is paid for by every reader and seen by those who scroll to it."
       // "Une image loin sous l'écran est payée par chaque lecteur et vue par ceux qui défilent jusqu'à elle.")
      lazyImages
  , Criterion "image-weight" ("Images are not larger than shown" // "Les images ne dépassent pas leur taille d'affichage") ("RGESN 6.4 · threshold 2× (tool)" // "RGESN 6.4 · seuil 2× (outil)") Light
      ("Pixels that are never displayed still travel, are decoded and held in memory, on the reader's connection and battery."
       // "Les pixels jamais affichés voyagent, sont décodés et gardés en mémoire quand même, sur la connexion et la batterie du lecteur.")
      imageWeight
  , Criterion "image-format" ("Heavy images use a modern format" // "Les images lourdes utilisent un format récent") ("RGESN 5.1 · threshold 30 kB (tool)" // "RGESN 5.1 · seuil 30 ko (outil)") Light
      ("Recent formats carry the same picture in a fraction of the bytes."
       // "Les formats récents portent la même image en une fraction des octets.")
      imageFormat
  ]

-- helpers ---------------------------------------------------------------

visible :: Surface -> Bool
visible s = hidden s /= Just True

surfacesOf :: Text -> Observation -> [Surface]
surfacesOf k o = [s | s <- surfaces o, kind s == k, visible s]

blank :: Maybe Text -> Bool
blank = maybe True (T.null . T.strip)

on :: Surface -> Verdict -> Phrase -> Maybe Phrase -> Mark
on s = \v seen ch -> Mark v (Just s) seen ch

onPage :: Verdict -> Phrase -> Maybe Phrase -> Mark
onPage = \v seen ch -> Mark v Nothing seen ch

-- | On the surface at that place in the page; on the page, naming the place, where no surface stands there.
onSel :: Observation -> Text -> Verdict -> Phrase -> Maybe Phrase -> Mark
onSel o x v seen ch = case [s | s <- surfaces o, sel s == x] of
  s : _ -> on s v seen ch
  [] -> onPage v (both (x <> " · ") <> seen) ch

orNA :: Phrase -> [Mark] -> [Mark]
orNA none [] = [onPage NA none Nothing]
orNA _ ms = ms

-- | Facts the observer has recorded since 0.4. An older observation is not judged on them.
recorded :: Observation -> [Mark] -> [Mark]
recorded o ms
  | isNothing (opened (page o)) = [onPage NA ("not recorded by the observer of that time" // "non relevé par l'observateur d'alors") Nothing]
  | otherwise = ms

quote :: Text -> Phrase
quote t = "“" <> t <> "”" // "« " <> t <> " »"

int :: Double -> Text
int x = T.pack (show (round x :: Int))

num :: Int -> Text
num = T.pack . show

dims :: [Double] -> Maybe (Double, Double)
dims (w : h : _) = Just (w, h)
dims _ = Nothing

shown :: Surface -> Maybe (Double, Double)
shown s = case box s of Just [_, _, w, h] -> Just (w, h); _ -> Nothing

-- | Words as they compare: lower case, punctuation left out.
plain :: Text -> Text
plain = T.unwords . T.words . T.map (\c -> if isAlphaNum c then c else ' ') . T.toLower

-- page ------------------------------------------------------------------

pageTitle, pageLang, doctypeC, zoom, reflowC, mainRegion, skipLink, uniqueIds :: Observation -> [Mark]

pageTitle o
  | blank t = [onPage Fail ("the page has no title" // "la page n'a pas de titre")
                 (Just ("add a <title> that names the page" // "ajouter un <title> qui nomme la page"))]
  | otherwise = [onPage Pass (quote (fromMaybe "" t)) Nothing]
  where t = title (page o)

pageLang o = case T.strip <$> lang (page o) of
  Nothing -> [onPage Fail ("no lang on <html>" // "pas d'attribut lang sur <html>") (Just setIt)]
  Just "" -> [onPage Fail ("empty lang on <html>" // "attribut lang vide sur <html>") (Just setIt)]
  Just l | tag l -> [onPage Pass (both ("lang=" <> l)) Nothing]
         | otherwise -> [onPage Review (("lang " // "lang ") <> quote l <> (" is not a recognised language tag" // " n'est pas un code de langue reconnu")) Nothing]
  where
    setIt = "set lang on <html>, e.g. lang=\"fr\"" // "déclarer lang sur <html>, par exemple lang=\"fr\""
    tag l = case T.splitOn "-" l of
      (p : rest) -> T.length p `elem` [2, 3] && T.all isAlpha p && all (\x -> not (T.null x) && T.all isAlphaNum x) rest
      [] -> False

doctypeC o = recorded o $ case T.words . T.toLower <$> doctype (page o) of
  Nothing -> [onPage Fail ("no doctype" // "pas de doctype") (Just ("begin the document with <!doctype html>" // "commencer le document par <!doctype html>"))]
  Just ("html" : _) -> [onPage Pass "doctype html" Nothing]
  Just ws -> [onPage Fail (both ("doctype " <> T.unwords ws)) (Just ("declare <!doctype html>" // "déclarer <!doctype html>"))]

zoom o = case viewport (page o) of
  Nothing -> [onPage Pass ("no viewport restriction" // "aucune restriction dans viewport") Nothing]
  Just v
    | blocked v -> [onPage Fail ("viewport " <> quote v) (Just ("remove maximum-scale and user-scalable" // "retirer maximum-scale et user-scalable"))]
    | otherwise -> [onPage Pass ("viewport " <> quote v) Nothing]
  where
    blocked v = any restricts [(T.strip k, T.strip (T.drop 1 x)) | p <- T.splitOn "," (T.toLower v), let (k, x) = T.breakOn "=" p]
    restricts ("user-scalable", x) = x `elem` ["no", "0"]
    restricts ("maximum-scale", x) = maybe False (< 2) (readD x)
    restricts _ = False

readD :: Text -> Maybe Double
readD x = case reads (T.unpack x) :: [(Double, String)] of [(d, "")] -> Just d; _ -> Nothing

reflowC o = case reflow (page o) of
  Nothing -> [onPage NA ("not measured" // "non mesuré") Nothing]
  Just w | w > 321 -> [onPage Fail ("content is " <> int w <> " px wide in a 320 px viewport" // "le contenu mesure " <> int w <> " px de large dans une fenêtre de 320 px")
                         (Just ("remove horizontal scrolling at 320 px" // "supprimer le défilement horizontal à 320 px"))]
         | otherwise -> [onPage Pass ("content fits 320 px" // "le contenu tient dans 320 px") Nothing]

mainRegion o
  | Just n <- mains (page o), n > 1 =
      [onPage Fail (num n <> " main landmarks are visible" // num n <> " zones principales sont visibles")
         (Just ("keep one <main>; give the others the hidden attribute" // "garder un seul <main> ; donner aux autres l'attribut hidden"))]
  | any ((== Just "main") . role) (surfacesOf "landmark" o) = [onPage Pass ("main landmark present" // "zone principale balisée") Nothing]
  | otherwise = [onPage Review ("no main landmark" // "pas de zone principale balisée") (Just ("wrap the main content in <main>" // "placer le contenu principal dans <main>"))]

-- | A link to the main content, or nothing before it that a keyboard would have to pass.
skipLink o = recorded o $ case (mains (page o), skip (page o), fromMaybe 0 (before (page o))) of
  (Just n, Just s, _) | n > 0 -> [onPage Pass (quote s) Nothing]
  (Just n, Nothing, 0) | n > 0 -> [onPage Pass ("nothing to pass before the main content" // "rien à franchir avant le contenu principal") Nothing]
  (Just n, Nothing, k) | n > 0 ->
    [onPage Review (num k <> (if k == 1 then " link or control stands" else " links or controls stand") <> " before the main content, and no link leads past"
                    // num k <> (if k == 1 then " lien ou commande précède" else " liens ou commandes précèdent") <> " le contenu principal, et aucun lien ne permet de passer outre")
       (Just ("add, first in the page, a link to the main content" // "ajouter, en tête de page, un lien vers le contenu principal"))]
  _ -> [onPage NA ("no main landmark to lead to" // "pas de zone principale où mener") Nothing]

uniqueIds o = case dupIds (page o) of
  [] -> [onPage Pass ("all ids unique" // "tous les id sont uniques") Nothing]
  ds -> [onPage Fail (("id " // "id ") <> quote i <> (" used " <> num n <> " times" // " utilisé " <> num n <> " fois"))
           (Just ("give each element its own id" // "donner à chaque élément son propre id")) | (i, n) <- ds]

-- structure -------------------------------------------------------------

headingOrder, headingLook, listLook, emptyBlocks, presentation :: Observation -> [Mark]

headingOrder o = case surfacesOf "heading" o of
  [] -> [onPage Review ("no headings" // "aucun titre") (Just ("structure the content with headings" // "structurer le contenu par des titres"))]
  hs@(h : _) -> on h Pass (lv h) Nothing : zipWith step hs (drop 1 hs)
  where
    lvl = fromMaybe 1 . level
    lv s = both ("h" <> num (lvl s)) <> maybe "" ((" " <>) . quote) (text s)
    step a b
      | lvl b > lvl a + 1 = on b Review (("h" <> num (lvl a) <> " then " // "h" <> num (lvl a) <> " puis ") <> lv b) (Just (both ("h" <> num (lvl a + 1))))
      | otherwise = on b Pass (lv b) Nothing

-- | The surface that stands for an event in a report: the first text of it.
onEvent :: Observation -> Ev -> Verdict -> Phrase -> Maybe Phrase -> Mark
onEvent o e v seen ch = case [s | s <- surfaces o, ev s == Just (eN e), kind s == "text"] of
  s : _ -> on s v seen ch
  [] -> onPage v (both (eSel e <> " · ") <> seen) ch

-- | Running text: shown, not a heading, not a control.
prose :: Observation -> [Ev]
prose o = [e | e <- fromMaybe [] (events o), eKind e == "text", eShown e, not (T.null (T.strip (eSaid e)))]

-- | Short text set larger than the page's running text, or bolder than what
--   follows it, and not marked as a heading. The size of running text is the
--   one most characters are set in. 1.2× and twelve words are this tool's.
headingLook o = case events o of
  Nothing -> [onPage NA ("not recorded by the observer of that time" // "non relevé par l'observateur d'alors") Nothing]
  Just _ | null running -> [onPage NA ("no running text on the page" // "pas de texte courant dans la page") Nothing]
         | otherwise -> orPass (mapMaybe judge (zip running (map Just (drop 1 running) ++ [Nothing])))
  where
    running = [e | e <- prose o, isNothing (eLevel e)]
    body = fst . last . sortOn snd . M.toList $ M.fromListWith (+) [(eSize e, T.length (eSaid e)) | e <- running]
    short e = eWords e <= 12
    loose e = not (any ((`elem` ["item", "navigation", "table", "form"]) . fst) (ePath e)) && isNothing (eCell e)
    closed e = maybe False ((`elem` (".,;:" :: String)) . snd) (T.unsnoc (T.strip (eSaid e)))
    judge (e, next)
      | not (short e && loose e) || isNothing next = Nothing
      | eSize e >= 1.2 * body =
          Just (onEvent o e Review (quote (eSaid e) <> (" is set at " <> int (eSize e) <> " px, the running text at " <> int body <> " px, and it is not a heading"
                                                   // " est composé en " <> int (eSize e) <> " px, le texte courant en " <> int body <> " px, et ce n'est pas un titre")) mark)
      | eWeight e >= 600 && eSize e >= body && not (closed e) && maybe False (\n -> eWeight n < 600 && isNothing (eLevel n)) next =
          Just (onEvent o e Review (quote (eSaid e) <> (" is set bolder than the text that follows, and it is not a heading"
                                                   // " est composé plus gras que le texte qui suit, et ce n'est pas un titre")) mark)
      | otherwise = Nothing
    mark = Just ("if it titles what follows, mark it h1 to h6" // "s'il titre ce qui suit, le baliser h1 à h6")
    orPass [] = [onPage Pass ("no unmarked text looks like a heading" // "aucun texte non balisé n'a l'air d'un titre") Nothing]
    orPass ms = ms

-- | Lines in a row that begin with a bullet, a dash or a number, outside any list.
listLook o = case events o of
  Nothing -> [onPage NA ("not recorded by the observer of that time" // "non relevé par l'observateur d'alors") Nothing]
  Just _ -> case [r | r <- runs (prose o), length r >= 2] of
    [] -> [onPage Pass ("no unmarked lines look like a list" // "aucune suite de lignes non balisée n'a l'air d'une liste") Nothing]
    rs -> [ onEvent o e Review ((num (length r) <> " lines in a row begin like list items, from " // num (length r) <> " lignes de suite commencent comme des éléments de liste, depuis ") <> quote (T.take 40 (eSaid e)))
              (Just ("mark them as a list: <ul> or <ol>, with <li>" // "les baliser en liste : <ul> ou <ol>, avec <li>")) | r@(e : _) <- rs ]
  where
    runs [] = []
    runs es = let (r, rest) = span bulleted es in [r | not (null r)] ++ runs (drop (if null r then 1 else 0) rest)
    bulleted e = not (any ((== "item") . fst) (ePath e)) && marker (T.strip (eSaid e))
    marker t = case T.uncons t of
      Just (c, r) | c `elem` ("•·▪■□◦‣⁃-–—*►▶→»" :: String) -> spaced r
                  | isDigit c -> let r' = T.dropWhile isDigit r in T.length t - T.length r' <= 2 && closer r'
                  | isAlpha c -> ")" `T.isPrefixOf` r && spaced (T.drop 1 r)
      _ -> False
    closer r = case T.uncons r of Just (c, r') | c `elem` (".)" :: String) -> spaced r'; _ -> False
    spaced r = maybe False (isSpace . fst) (T.uncons r) && not (T.null (T.strip r))

emptyBlocks o = recorded o $ case fromMaybe [] (empties (page o)) of
  [] -> [onPage Pass ("no empty paragraph or heading" // "aucun paragraphe ni titre vide") Nothing]
  es -> [ onPage Fail (what k n) (Just ((if n == 1 then "remove it" else "remove them") <> "; spacing belongs to the style sheet"
                                       // (if n == 1 then "le retirer" else "les retirer") <> " ; l'espacement relève de la feuille de styles")) | (k, n) <- es ]
  where
    what "p" n = num n <> (if n == 1 then " empty paragraph" else " empty paragraphs") // num n <> (if n == 1 then " paragraphe vide" else " paragraphes vides")
    what _ n = num n <> (if n == 1 then " empty heading" else " empty headings") // num n <> (if n == 1 then " titre vide" else " titres vides")

presentation o = recorded o $ case fromMaybe [] (styling (page o)) of
  [] -> [onPage Pass ("no styling tag or attribute" // "aucune balise ni attribut de présentation") Nothing]
  ks -> [ onPage Fail (what k <> times n) (Just ("move it to the style sheet" // "le confier à la feuille de styles")) | (k, n) <- ks ]
  where
    what k = case T.stripPrefix "@" k of
      Just a -> "attribute " <> a // "attribut " <> a
      Nothing -> both ("<" <> k <> ">")
    times n = " used " <> num n <> (if n == 1 then " time" else " times") // " utilisé " <> num n <> " fois"

-- images ----------------------------------------------------------------

imageAlt :: Observation -> [Mark]
imageAlt o = orNA ("no images on the page" // "aucune image dans la page") (map img (surfacesOf "img" o) ++ map graphic (surfacesOf "graphic" o))
  where
    img s = case T.strip <$> alt s of
      _ | role s `elem` [Just "presentation", Just "none"] -> on s Pass ("role=presentation (decorative)" // "role=presentation (décorative)") Nothing
      Nothing -> on s Fail ("no alt attribute" // "pas d'attribut alt") (Just ("add alt; alt=\"\" if the image is decorative" // "ajouter alt ; alt=\"\" si l'image est décorative"))
      Just ""
        | maybe 0 (uncurry (*)) (shown s) >= 40000 -> on s Review ("large image with alt=\"\" (declared decorative)" // "grande image avec alt=\"\" (déclarée décorative)") Nothing
        | otherwise -> on s Pass ("alt=\"\" (decorative)" // "alt=\"\" (décorative)") Nothing
      Just a
        | fileLike a -> on s Review ("alt " <> quote a <> (" looks like a file name" // " ressemble à un nom de fichier")) (Just ("describe what the image shows" // "décrire ce que montre l'image"))
        | otherwise -> on s Pass ("alt " <> quote a) Nothing
    graphic s
      | blank (name s) = on s Fail ("role=img without a name" // "role=img sans nom") (Just ("add aria-label or <title>" // "ajouter aria-label ou <title>"))
      | otherwise = on s Pass (quote (fromMaybe "" (name s))) Nothing
    fileLike a = let l = T.unpack (T.toLower a) in
      any (`isSuffixOf` l) [".jpg", ".jpeg", ".png", ".gif", ".webp", ".avif", ".svg"] || any (`isPrefixOf` l) ["img_", "dsc"]

imageWeight, imageFormat :: Observation -> [Mark]
imageWeight o = orNA ("no bitmap images on the page" // "aucune image matricielle dans la page") (mapMaybe judge [s | s <- surfaces o, kind s == "img", not (vector s)])
  where
    -- A vector image has no pixel size to exceed.
    vector s = mime s == Just "image/svg+xml" || maybe False (T.isSuffixOf ".svg" . T.toLower . T.takeWhile (/= '?')) (src s)
    judge s = do
      (nw, nh) <- natural s >>= dims
      (w, h) <- shown s
      let seen = int nw <> "×" <> int nh <> " px shown at " <> int w <> "×" <> int h // int nw <> "×" <> int nh <> " px affichée en " <> int w <> "×" <> int h
      if nw <= 0 || w <= 0 then Nothing else Just $
        if nw > 2 * w
          then on s Hint seen (Just ("serve at most " <> int (2 * w) <> "×" <> int (2 * h) <> " px" // "servir au plus " <> int (2 * w) <> "×" <> int (2 * h) <> " px"))
          else on s Pass seen Nothing

imageFormat o = orNA ("no weighed images on the page" // "aucune image pesée dans la page") (mapMaybe judge [s | s <- surfaces o, kind s == "img"])
  where
    judge s = do
      m <- mime s
      b <- bytes s
      let kb = int (fromIntegral b / 1024)
          seen = m <> ", " <> kb <> " kB" // m <> ", " <> kb <> " ko"
      Just $ if m `elem` ["image/png", "image/jpeg", "image/gif", "image/bmp"] && b > 30720
        then on s Hint seen (Just ("serve AVIF or WebP" // "servir en AVIF ou en WebP"))
        else on s Pass seen Nothing

-- text ------------------------------------------------------------------

contrast :: Observation -> [Mark]
contrast o = orNA ("no text on the page" // "aucun texte dans la page") (map judge (surfacesOf "text" o))
  where
    judge s = case (fg s, bg s) of
      _ | bgImage s == Just True -> on s Review (("text over a background image" // "texte sur une image de fond") <> snippet s) Nothing
      (Just f, Just b) ->
        let c = over f b; back = over b b; r = ratio c back
            need = if large s then 3 else 4.5
            seen = (hex c <> " on " <> hex back <> " · " <> two r <> ":1, needs " <> two need <> ":1"
                    // hex c <> " sur " <> hex back <> " · " <> comma (two r) <> ":1, seuil " <> comma (two need) <> ":1") <> snippet s
        in case opacity s of
             Just a | a < 1 -> on s Review (seen <> (" · partly transparent (opacity " <> two a <> "), may be mid-animation"
                                                     // " · en partie transparent (opacité " <> comma (two a) <> "), peut-être en cours d'animation")) Nothing
             _ | r >= need -> on s Pass seen Nothing
               | otherwise -> on s Fail seen ((\x -> "use " <> hex x // "utiliser " <> hex x) <$> nearest need c back)
      _ -> on s Review (("colours not readable" // "couleurs non lisibles par le contrôle") <> snippet s) Nothing
    large s = let px = fromMaybe 16 (size s); w = fromMaybe 400 (weight s) in px >= 24 || (px >= 18.66 && w >= 700)
    two :: Double -> Text
    two x = T.pack (printf "%.2f" (fromIntegral (floor (x * 100) :: Int) / 100 :: Double))
    comma = T.replace "." ","
    snippet s = maybe "" ((" · " <>) . quote) (text s)

-- names -----------------------------------------------------------------

linkName, linkDistinct, buttonName, labelInName, controlLabel, groupLegend, fieldGroup, autocompleteC :: Observation -> [Mark]

vague :: [Text]
vague = [ "ici", "cliquez ici", "en savoir plus", "lire la suite", "plus", "voir", "voir plus", "lien"
        , "here", "click here", "read more", "more", "learn more", "link" ]

linkName o = orNA ("no links on the page" // "aucun lien dans la page") (map judge (surfacesOf "link" o))
  where
    judge s
      | blank (name s) = on s Fail ("link without a name" // "lien sans intitulé") (Just ("give the link text, an image alt, or aria-label" // "donner au lien un texte, un alt d'image ou un aria-label"))
      | T.toLower n `elem` vague = on s Review (("link " // "le lien ") <> quote n <> (" depends on its context" // " dépend de son contexte")) (Just ("name the destination" // "nommer la destination"))
      | otherwise = on s Pass (quote n) Nothing
      where n = T.strip (fromMaybe "" (name s))

-- | One name, several destinations. A name already too vague to stand alone is left to link-name.
linkDistinct o = recorded o . orNA ("no links on the page" // "aucun lien dans la page") $
  case [ on s Review (quote n <> (" names " <> num (length hs) <> " links that lead to " <> num (length (nub hs)) <> " places"
                                 // " nomme " <> num (length hs) <> " liens qui mènent à " <> num (length (nub hs)) <> " lieux"))
              (Just ("name each destination" // "nommer chaque destination"))
       | (s, n) <- named, let hs = M.findWithDefault [] (T.toLower n) places, length (nub hs) > 1 ] of
    [] | null named -> []
       | otherwise -> [onPage Pass ("each name leads to one place" // "chaque intitulé mène à un seul lieu") Nothing]
    ms -> ms
  where
    named = [ (s, n) | s <- surfacesOf "link" o, Just n <- [T.strip <$> name s], not (T.null n), T.toLower n `notElem` vague, not ("…" `T.isSuffixOf` n) ]
    places = M.fromListWith (flip (++)) [ (T.toLower n, [place h]) | (s, n) <- named, Just h <- [href s] ]
    -- Mail to one address is one place, whatever subject the link proposes.
    place h = if any (`T.isPrefixOf` h) ["mailto:", "tel:"] then T.takeWhile (/= '?') h else h

buttonName o = orNA ("no buttons on the page" // "aucun bouton dans la page") (map judge (surfacesOf "button" o))
  where judge s | blank (name s) = on s Fail ("button without a name" // "bouton sans intitulé") (Just ("give the button text or aria-label" // "donner au bouton un texte ou un aria-label"))
                | otherwise = on s Pass (quote (fromMaybe "" (name s))) Nothing

-- | Where the code gives a name of its own (aria-label, aria-labelledby), the
--   words shown must be in it. Case and punctuation do not count; a label of
--   one character is a symbol and is left alone.
labelInName o = recorded o . orNA ("no name given by the code over a visible label" // "aucun nom donné par le code par-dessus un intitulé visible") $
  [ if plain l `T.isInfixOf` plain n
      then on s Pass (quote n <> (" holds " // " contient ") <> quote l) Nothing
      else on s Fail (("shows " // "montre ") <> quote l <> (", is named " // ", se nomme ") <> quote n)
             (Just ("begin the name with the visible words" // "commencer le nom par les mots visibles"))
  | k <- ["link", "button", "control"], s <- surfacesOf k o
  , by s `elem` [Just "aria-label", Just "aria-labelledby"]
  , Just l <- [label s], Just n <- [name s], T.length (plain l) > 1, not (any ("…" `T.isSuffixOf`) [l, n]) ]

controlLabel o = orNA ("no form fields on the page" // "aucun champ de formulaire dans la page") (map judge (surfacesOf "control" o))
  where judge s | blank (name s) = on s Fail (("no label" // "pas d'étiquette") <> maybe "" (\p -> ("; placeholder " // " ; seulement un texte indicatif, ") <> quote p <> (" only" // "")) (placeholder s))
                                          (Just ("associate a <label>, or add aria-label" // "associer un <label>, ou ajouter aria-label"))
                | otherwise = on s Pass (("label " // "étiquette ") <> quote (fromMaybe "" (name s))) Nothing

groupLegend o = recorded o . orNA ("no group of fields on the page" // "aucun groupe de champs dans la page") $ map judge (surfacesOf "group" o)
  where judge s | blank (name s) = on s Fail ("group of fields without a legend" // "groupe de champs sans légende") (Just ("add a <legend>, or aria-label on the group" // "ajouter un <legend>, ou aria-label sur le groupe"))
                | otherwise = on s Pass (quote (fromMaybe "" (name s))) Nothing

-- | Radio buttons that share a name answer one question.
fieldGroup o = recorded o . orNA ("no radio buttons on the page" // "aucun bouton radio dans la page") $
  [ case [s | s <- ss, grouped s /= Just True] of
      loose@(s : _) | length ss > 1 ->
        on s Review ((num (length loose) <> " radio buttons named " // num (length loose) <> " boutons radio nommés ") <> quote n <> (" stand outside any group" // " sont hors de tout groupe"))
          (Just ("wrap them in a <fieldset> with a <legend>" // "les placer dans un <fieldset> avec un <legend>"))
      _ -> on (head ss) Pass (quote n <> (" · " <> num (length ss) <> " grouped" // " · " <> num (length ss) <> " regroupés")) Nothing
  | (n, ss) <- M.toList sets ]
  where
    sets = M.fromListWith (flip (++)) [ (n, [s]) | s <- surfacesOf "control" o, itype s == Just "radio", Just n <- [set s] ]

-- | The purposes a field can declare (HTML, autofill field names).
purposes :: [Text]
purposes = T.words "name honorific-prefix given-name additional-name family-name honorific-suffix nickname username new-password \
  \current-password one-time-code organization-title organization street-address address-line1 address-line2 address-line3 \
  \address-level4 address-level3 address-level2 address-level1 country country-name postal-code cc-name cc-given-name \
  \cc-additional-name cc-family-name cc-number cc-exp cc-exp-month cc-exp-year cc-csc cc-type transaction-currency \
  \transaction-amount language bday bday-day bday-month bday-year sex url photo tel tel-country-code tel-national \
  \tel-area-code tel-local tel-local-prefix tel-local-suffix tel-extension email impp"

-- | A field's declared purpose is checked against the list. A field that asks
--   for a person's data by its type, its name or its label, and declares none,
--   is put to a person: whose data it asks for is not something a rule knows.
autocompleteC o = recorded o . orNA ("no field that asks for personal data" // "aucun champ ne demandant une donnée personnelle") $ mapMaybe judge (surfacesOf "control" o)
  where
    judge s = case (T.words . T.toLower <$> auto s, asks s) of
      (Just ws, _) | ws `notElem` [["on"], ["off"], []] ->
        Just $ case [w | w <- ws, not ("section-" `T.isPrefixOf` w), w `notElem` ["shipping", "billing", "home", "work", "mobile", "fax", "pager", "webauthn"]] of
          [w] | w `elem` purposes -> on s Pass (both ("autocomplete=\"" <> T.unwords ws <> "\"")) Nothing
          _ -> on s Fail ("autocomplete=\"" <> T.unwords ws <> "\" is not a purpose a field can declare" // "autocomplete=\"" <> T.unwords ws <> "\" n'est pas une finalité qu'un champ peut déclarer")
                 ((\p -> "use autocomplete=\"" <> p <> "\"" // "utiliser autocomplete=\"" <> p <> "\"") <$> asks s)
      (_, Just p) -> Just (on s Review (("the field " // "le champ ") <> quote (fromMaybe "" (listToMaybe (mapMaybe nonBlank [name s, hint s, itype s]))) <> (" declares no purpose" // " ne déclare aucune finalité"))
                             (Just ("if it asks for the visitor's own data, add autocomplete=\"" <> p <> "\"" // "s'il demande une donnée du visiteur lui-même, ajouter autocomplete=\"" <> p <> "\"")))
      _ -> Nothing
    nonBlank t = if blank t then Nothing else t
    asks s
      | itype s `elem` map Just ["checkbox", "radio", "file", "range", "color"] = Nothing
      | otherwise = listToMaybe (mapMaybe (`lookup` byType) [fromMaybe "" (itype s)]
                                 ++ [p | w <- T.words (plain (fromMaybe "" (hint s) <> " " <> fromMaybe "" (name s))), Just p <- [lookup w byWord]])
    byType = [("email", "email"), ("tel", "tel")]
    byWord = concat
      [ ws "email" "email mail courriel", ws "tel" "tel telephone téléphone phone mobile portable"
      , ws "given-name" "prenom prénom firstname given", ws "family-name" "nom lastname surname family"
      , ws "name" "name fullname", ws "street-address" "adresse address street rue", ws "postal-code" "postal zip zipcode postcode cp"
      , ws "address-level2" "ville city town", ws "country-name" "pays country", ws "bday" "naissance birthday birthdate bday"
      , ws "organization" "organisation organization company société societe entreprise", ws "username" "username login identifiant" ]
    ws p = map (\w -> (w, p)) . T.words

tableHeaders, frameTitle, autoplayC, mediaCaptions, tabOrder, hiddenFocusC, noPopup, refreshC, aiDisclosure :: Observation -> [Mark]

-- | A table of two rows and two columns or more is taken for data unless it
--   says it is layout. Headers in one row or one column need no scope
--   (RGAA 5.7, particular case); headers in both do.
tableHeaders o = recorded o . orNA ("no tables on the page" // "aucun tableau dans la page") $ map judge (surfacesOf "table" o)
  where
    judge s
      | role s `elem` [Just "presentation", Just "none"] =
          if n marks > 0
            then on s Fail ("a layout table carries data-table markup" // "un tableau de mise en forme porte un balisage de tableau de données")
                   (Just ("remove caption, th, scope and headers from it" // "en retirer caption, th, scope et headers"))
            else on s Pass ("layout table, declared" // "tableau de mise en forme, déclaré") Nothing
      | n heads == 0 && n rows >= 2 && n cols >= 2 =
          on s Review (size' <> (" without a header cell" // " sans cellule d'en-tête"))
            (Just ("a data table declares its headers with <th>; a layout table carries role=\"presentation\"" // "un tableau de données déclare ses en-têtes par <th> ; un tableau de mise en forme porte role=\"presentation\""))
      | across s == Just True && n bare > 0 =
          on s Fail ("headers in rows and in columns, " <> num (n bare) <> " without scope or id" // "en-têtes en lignes et en colonnes, dont " <> num (n bare) <> " sans scope ni id")
            (Just ("give each <th> scope=\"col\" or scope=\"row\"" // "donner à chaque <th> scope=\"col\" ou scope=\"row\""))
      | otherwise = on s Pass (size' <> (" · " <> num (n heads) <> " header cells" // " · " <> num (n heads) <> " cellules d'en-tête")) Nothing
      where
        n f = fromMaybe 0 (f s)
        size' = "table of " <> num (n rows) <> " × " <> num (n cols) // "tableau de " <> num (n rows) <> " × " <> num (n cols)

frameTitle o = orNA ("no frames on the page" // "aucun cadre dans la page") (map judge (surfacesOf "iframe" o))
  where judge s | blank (name s) = on s Fail ("frame without a title" // "cadre sans titre") (Just ("add a title that says what the frame holds" // "ajouter un title qui dit ce que contient le cadre"))
                | otherwise = on s Pass (quote (fromMaybe "" (name s))) Nothing

autoplayC o = orNA ("no audio or video on the page" // "ni audio ni vidéo dans la page") (map judge (surfacesOf "media" o))
  where judge s | autoplay s == Just True && muted s /= Just True = on s Fail ("plays sound on load" // "du son démarre au chargement") (Just ("add muted, or remove autoplay" // "ajouter muted, ou retirer autoplay"))
                | otherwise = on s Pass ("no sound on load" // "pas de son au chargement") Nothing

-- | A caption track is read from the markup. Whether a video carries speech
--   is not something a rule knows.
mediaCaptions o = recorded o . orNA ("no video on the page" // "aucune vidéo dans la page") $
  [ if any (`elem` ["captions", "subtitles"]) (fromMaybe [] (tracks s))
      then on s Pass ("caption track present" // "piste de sous-titres présente") Nothing
      else on s Review ("video without a caption track" // "vidéo sans piste de sous-titres")
             (Just ("if it carries speech, add <track kind=\"captions\">" // "si elle porte de la parole, ajouter <track kind=\"captions\">"))
  | s <- surfacesOf "media" o, itype s == Just "video" ]

tabOrder o = recorded o $ case fromMaybe [] (tabbed (page o)) of
  [] -> [onPage Pass ("no tabindex above 0" // "aucun tabindex supérieur à 0") Nothing]
  ss -> [ onSel o s Review ("tabindex above 0" // "tabindex supérieur à 0")
            (Just ("order the code as the page reads, and use tabindex=\"0\"" // "ordonner le code comme la page se lit, et utiliser tabindex=\"0\"")) | s <- ss ]

hiddenFocusC o = recorded o $ case fromMaybe [] (hiddenFocus (page o)) of
  [] -> [onPage Pass ("nothing under aria-hidden takes the focus" // "rien sous aria-hidden ne prend le focus") Nothing]
  ss -> [ onSel o s Fail ("takes the focus under aria-hidden" // "prend le focus sous aria-hidden")
            (Just ("take it out of the tab order, or remove aria-hidden" // "le sortir de l'ordre de tabulation, ou retirer aria-hidden")) | s <- ss ]

noPopup o = recorded o $ case fromMaybe 0 (opened (page o)) of
  0 -> [onPage Pass ("opens no window by itself" // "n'ouvre aucune fenêtre d'elle-même") Nothing]
  n -> [onPage Fail ("tried to open " <> num n <> (if n == 1 then " window" else " windows") <> " by itself" // "a tenté d'ouvrir " <> num n <> (if n == 1 then " fenêtre" else " fenêtres") <> " d'elle-même")
          (Just ("open a window on the reader's action only" // "n'ouvrir une fenêtre qu'à l'action du lecteur"))]

-- | <meta http-equiv="refresh">: a delay, then perhaps an address.
refreshC o = recorded o $ case refresh (page o) of
  Nothing -> [onPage NA ("no timed refresh declared" // "aucun rafraîchissement temporisé déclaré") Nothing]
  Just c -> case readD (T.strip (T.takeWhile (`notElem` (";," :: String)) c)) of
    Just d | d > 0 && "url" `T.isInfixOf` T.toLower c ->
               [onPage Fail ("leaves for another address after " <> int d <> " s" // "part vers une autre adresse après " <> int d <> " s")
                  (Just ("redirect at once, from the server" // "rediriger aussitôt, depuis le serveur"))]
           | d > 0 -> [onPage Review ("reloads itself every " <> int d <> " s" // "se recharge toutes les " <> int d <> " s")
                         (Just ("let the reader stop or delay it" // "laisser le lecteur l'arrêter ou le retarder"))]
    _ -> [onPage Pass (both ("refresh " <> c)) Nothing]

aiDisclosure o = case surfacesOf "widget" o of
  [] -> [onPage NA ("no conversational widget detected" // "aucun agent conversationnel détecté") Nothing]
  ws -> [ on w Review (("conversational widget (" <> fromMaybe "?" (vendor w) <> "); disclosure wording on the page: " // "agent conversationnel (" <> fromMaybe "?" (vendor w) <> ") ; mention sur la page : ") <> said)
               (if null ds then Just ("if it is an AI system, say so to the user" // "s'il s'agit d'un système d'IA, le dire à l'utilisateur") else Nothing) | w <- ws ]
  where ds = disclosure (page o)
        said = if null ds then "none" // "aucune" else foldr1 (\a b -> a <> ", " <> b) (map quote ds)

-- sobriety --------------------------------------------------------------

aiImage, asksOnArrival, thirdPartiesC, mediaAutoplay, endless, fontsC, compression, caching, protocolC, lazyImages :: Observation -> [Mark]

-- | What an image file says of its own making is read; whether the page says
--   it too is put to a person, with the page's wording.
aiImage o = recorded o . orNA ("no image states its origin" // "aucune image ne déclare son origine") $ mapMaybe judge (surfacesOf "img" o)
  where
    judge s = case (origin s, manifest s) of
      (Just x, _) | x /= "algorithmicMedia" ->
        Just (on s Review (("the file states its origin: " <> x <> "; disclosure wording on the page: " // "le fichier déclare son origine : " <> x <> " ; mention sur la page : ") <> said)
                (if null ds then Just ("say, beside the image, that it was generated by AI" // "dire, près de l'image, qu'elle a été produite par IA") else Nothing))
      (Just x, _) -> Just (on s Pass (both ("origin: " <> x)) Nothing)
      (Nothing, Just True) -> Just (on s Pass ("carries a provenance manifest (C2PA), with no synthetic origin stated" // "porte un manifeste de provenance (C2PA), sans origine synthétique déclarée") Nothing)
      _ -> Nothing
    ds = disclosure (page o)
    said = if null ds then "none" // "aucune" else foldr1 (\a b -> a <> ", " <> b) (map quote ds)

asksOnArrival o = recorded o $ case fromMaybe [] (asked (page o)) of
  [] -> [onPage Pass ("asks nothing of the device on arrival" // "ne demande rien à l'appareil à l'arrivée") Nothing]
  as -> [ onPage Review (("asks for " // "demande ") <> what a <> (" on arrival" // " dès l'arrivée"))
            (Just ("ask when the reader starts what needs it" // "demander quand le lecteur lance ce qui en a besoin")) | a <- as ]
  where
    what "notifications" = "notifications" // "les notifications"
    what "location" = "the device's location" // "la position de l'appareil"
    what "camera or microphone" = "the camera or the microphone" // "la caméra ou le microphone"
    what a = both a

-- | The robot gives no consent: whatever third party answered did so without one.
thirdPartiesC o = case thirdParties (network o) of
  [] -> [onPage Pass ("no third party is called" // "aucun tiers n'est appelé") Nothing]
  hs -> [onPage Review (num (length hs) <> (if length hs == 1 then " third-party host" else " third-party hosts") <> " answered before any consent was given: " <> T.intercalate ", " hs
                        // num (length hs) <> (if length hs == 1 then " hôte tiers a répondu" else " hôtes tiers ont répondu") <> " avant tout consentement : " <> T.intercalate ", " hs)
          (Just ("call each one only once the reader has agreed, unless the page cannot work without it" // "n'appeler chacun qu'une fois l'accord du lecteur donné, sauf si la page ne peut fonctionner sans lui"))]

mediaAutoplay o = orNA ("no audio or video on the page" // "ni audio ni vidéo dans la page") (map judge (surfacesOf "media" o))
  where judge s | autoplay s == Just True = on s Hint ("starts by itself" <> (if muted s == Just True then ", muted" else "") // "se lance seul" <> (if muted s == Just True then ", sans le son" else ""))
                                              (Just ("let the reader start it" // "laisser le lecteur le lancer"))
                | otherwise = on s Pass ("waits to be started" // "attend d'être lancé") Nothing

endless o = case grows (page o) of
  Just [a, b, c] | b - a >= 800 && c - b >= 800 ->
    [onPage Hint ("grew from " <> int a <> " to " <> int b <> ", then to " <> int c <> " px, each time its end was reached" // "est passée de " <> int a <> " à " <> int b <> ", puis à " <> int c <> " px, chaque fois que sa fin était atteinte")
       (Just ("load more on request: a button, or pages" // "charger la suite à la demande : un bouton, ou des pages"))]
  Just hs | not (null hs) -> [onPage Pass ("ends at " <> int (last hs) <> " px" // "s'achève à " <> int (last hs) <> " px") Nothing]
  _ -> [onPage NA ("not recorded by the observer of that time" // "non relevé par l'observateur d'alors") Nothing]

-- | The responses that brought the page; an observer that did not record them is not judged on them.
carried :: Observation -> ([Resource] -> [Mark]) -> [Mark]
carried o f = maybe [onPage NA ("not recorded by the observer of that time" // "non relevé par l'observateur d'alors") Nothing] f (resources (network o))

-- | A page read from this machine says nothing of how it would be served.
served :: Observation -> [Mark] -> [Mark]
served o ms
  | host `elem` ["localhost", "127.0.0.1", "[::1]"] = [onPage NA ("read from this machine: how it is served is not judged" // "lue depuis cette machine : la façon dont elle est servie n'est pas jugée") Nothing]
  | otherwise = ms
  where host = T.takeWhile (`notElem` (":/" :: String)) (T.drop 3 (snd (T.breakOn "://" (url o))))

kb :: Int -> Text
kb b = int (fromIntegral b / 1024)

-- | The file an address names, for a line of a report.
file :: Text -> Text
file u = let p = T.takeWhile (`notElem` ("?#" :: String)) (T.drop 3 (snd (T.breakOn "://" u))) in T.takeEnd 60 p

-- | Twelve lines at most for one criterion; what is past them is counted.
few :: Phrase -> [Mark] -> [Mark]
few more ms = take 12 ms ++ [onPage Hint (both (num (length ms - 12) <> " ") <> more) Nothing | length ms > 12]

fontsC o = carried o $ \rs -> case [r | r <- rs, xKind r == "Font"] of
  [] -> [onPage NA ("no font is downloaded" // "aucune police n'est téléchargée") Nothing]
  fs | length fs <= 4 || weight' <= 400 * 1024 -> [onPage Pass seen Nothing]
     | otherwise -> [onPage Hint seen (Just ("keep to two fonts in four variants, or to 400 kB" // "s'en tenir à deux polices en quatre variantes, ou à 400 ko"))]
    where weight' = sum (map xBytes fs)
          seen = num (length fs) <> (if length fs == 1 then " font file, " else " font files, ") <> kb weight' <> " kB" // num (length fs) <> (if length fs == 1 then " fichier de police, " else " fichiers de police, ") <> kb weight' <> " ko"

compression o = served o . carried o $ \rs ->
  let text r = not (xThird r) && xBytes r > 1024 && (xKind r `elem` ["Document", "Stylesheet", "Script"] || any (`T.isInfixOf` xMime r) ["svg", "json", "xml", "text/"])
      bare = [r | r <- rs, text r, T.null (xEncoded r)]
  in case filter text rs of
       [] -> [onPage NA ("no text resource of its own above 1 kB" // "aucune ressource textuelle propre au-dessus de 1 ko") Nothing]
       ts | null bare -> [onPage Pass (num (length ts) <> " text resources, all compressed" // num (length ts) <> " ressources textuelles, toutes compressées") Nothing]
          | otherwise -> few ("more travel uncompressed" // "autres voyagent sans compression")
              [ onPage Hint (both (file (xUrl r)) <> (" · " <> kb (xBytes r) <> " kB, not compressed" // " · " <> kb (xBytes r) <> " ko, sans compression"))
                  (Just ("serve it with Brotli or gzip" // "le servir avec Brotli ou gzip")) | r <- bare ]

caching o = served o . carried o $ \rs ->
  let static r = not (xThird r) && xKind r `elem` ["Stylesheet", "Script", "Image", "Font", "Media"]
      loose = [r | r <- rs, static r, not (xCached r)]
  in case filter static rs of
       [] -> [onPage NA ("no static file of its own" // "aucun fichier statique propre") Nothing]
       ss | null loose -> [onPage Pass (num (length ss) <> " static files, all of which the browser may keep" // num (length ss) <> " fichiers statiques, que le navigateur peut tous garder") Nothing]
          | otherwise -> few ("more may not be kept" // "autres ne peuvent être gardés")
              [ onPage Hint (both (file (xUrl r)) <> (" may not be kept by the browser" // " ne peut être gardé par le navigateur"))
                  (Just ("send Cache-Control with a lifetime, or a validator (ETag, Last-Modified)" // "envoyer Cache-Control avec une durée, ou un validateur (ETag, Last-Modified)")) | r <- loose ]

protocolC o = served o . carried o $ \rs ->
  let own = [r | r <- rs, not (xThird r)]
      old = [r | r <- own, "http/1" `T.isPrefixOf` T.toLower (xProto r)]
      homes = nub [T.takeWhile (/= '/') (T.drop 3 (snd (T.breakOn "://" (xUrl r)))) | r <- own, xKind r `elem` ["Stylesheet", "Script", "Image", "Font", "Media"]]
      found = concat
        [ [onPage Hint ("served over HTTP, without encryption" // "servie en HTTP, sans chiffrement") (Just ("serve it over HTTPS" // "la servir en HTTPS")) | "http://" `T.isPrefixOf` url o]
        , [onPage Hint ("negotiated " <> t // "a négocié " <> t) (Just ("enable TLS 1.3" // "activer TLS 1.3")) | Just t <- [tls (page o)], t `notElem` ["TLS 1.3", "QUIC"]]
        , [onPage Hint (num (length old) <> " of its " <> num (length own) <> " own responses came over HTTP/1" // num (length old) <> " de ses " <> num (length own) <> " réponses propres sont venues en HTTP/1")
             (Just ("enable HTTP/2 or HTTP/3" // "activer HTTP/2 ou HTTP/3")) | not (null old)]
        , [onPage Hint ("its name has no IPv6 address" // "son nom n'a pas d'adresse IPv6") (Just ("publish an AAAA record" // "publier un enregistrement AAAA")) | ipv6 (page o) == Just False]
        , [onPage Hint ("its own static files come from " <> num (length homes) <> " domains: " <> T.intercalate ", " homes // "ses fichiers statiques propres viennent de " <> num (length homes) <> " domaines : " <> T.intercalate ", " homes)
             (Just ("serve them from one" // "les servir depuis un seul")) | length homes > 1] ]
  in if null found then [onPage Pass ("HTTPS, " <> fromMaybe "TLS" (tls (page o)) <> ", HTTP/2 or 3, IPv6, one domain" // "HTTPS, " <> fromMaybe "TLS" (tls (page o)) <> ", HTTP/2 ou 3, IPv6, un seul domaine") Nothing] else found

-- | Below the second screen of a page 800 px high, an image should wait.
lazyImages o = recorded o . orNA ("no image below the second screen" // "aucune image sous le deuxième écran") $
  [ if lazy s == Just True
      then on s Pass ("waits to be reached, " <> int y <> " px down" // "attend d'être atteinte, à " <> int y <> " px")
             Nothing
      else on s Hint ("starts " <> int y <> " px down the page and is loaded on arrival" // "commence à " <> int y <> " px dans la page et se charge dès l'arrivée")
             (Just ("add loading=\"lazy\"" // "ajouter loading=\"lazy\""))
  | s <- surfacesOf "img" o, Just (_ : y : _) <- [box s], y >= 1600, maybe False (not . ("data:" `T.isPrefixOf`)) (src s) ]
