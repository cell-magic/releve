-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
{-# LANGUAGE OverloadedStrings #-}
-- | The criteria. Each is a pure function from an observation to marks.
--   A criterion states its source and what it is for; thresholds that are
--   this tool's own choice say so. Whatever a mark says, it says in each
--   language of the reports, and in plain words: what HTML calls a thing
--   (<label>, aria-label) is written as HTML writes it, and nowhere else.
module Releve.Criteria (criteria, version) where

import Data.Char (isAlpha, isAlphaNum, isDigit, isSpace)
import Data.List (isSuffixOf, isPrefixOf, nub, sortOn)
import qualified Data.Map.Strict as M
import Data.Maybe (fromMaybe, isNothing, listToMaybe, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Text.Printf (printf)
import Releve.Checklist
import Releve.Colour
import Releve.Types

version :: Text
version = "6"

criteria :: [Criterion]
criteria =
  [ Criterion "page-title" ("The page has a title" // "La page a un titre") "RGAA 8.5 · WCAG 2.4.2" Light
      ("Shown in tabs, bookmarks, search results, and first by screen readers."
       // "Affiché dans les onglets, les favoris, les résultats de recherche, et lu en premier par les lecteurs d'écran.")
      pageTitle
  , Criterion "page-lang" ("The page states its language" // "La page déclare sa langue") "RGAA 8.3 · WCAG 3.1.1" Light
      ("Sets screen reader voice, hyphenation and translation."
       // "Règle la voix du lecteur d'écran, la césure et la traduction.")
      pageLang
  , Criterion "doctype" ("The page declares its document type" // "La page déclare son type de document") "RGAA 8.1" Light
      ("Keeps the browser in standards mode."
       // "Maintient le navigateur en mode standard.")
      doctypeC
  , Criterion "zoom" ("Zoom is not blocked" // "L'agrandissement n'est pas bloqué") "RGAA 10.4 · WCAG 1.4.4" Light
      ("Enlarging the page is the only adjustment some readers have."
       // "Agrandir la page est le seul réglage dont disposent certains lecteurs.")
      zoom
  , Criterion "reflow" ("No horizontal scrolling at 320 px" // "Pas de défilement horizontal à 320 px") "RGAA 10.11 · WCAG 1.4.10 · RGESN 2.5" Heavy
      ("320 px is a small phone, or a page zoomed to 400%. Content scrolls one way only."
       // "320 px : un petit téléphone, ou une page zoomée à 400 %. Le contenu défile dans un seul sens.")
      reflowC
  , Criterion "main-region" ("The main content is marked" // "Le contenu principal est balisé") "RGAA 9.2 · 12.6 · WCAG 2.4.1" Light
      ("Lets a reader skip what every page repeats."
       // "Permet de passer ce que chaque page répète.")
      mainRegion
  , Criterion "skip-link" ("A link leads to the main content" // "Un lien mène au contenu principal") "RGAA 12.7 · WCAG 2.4.1" Light
      ("Spares keyboard users the repeated links on every page."
       // "Évite au clavier les liens répétés à chaque page.")
      skipLink
  , Criterion "heading-order" ("Heading levels follow each other" // "Les niveaux de titre se suivent") "RGAA 9.1 · WCAG 1.3.1" Medium
      ("Headings are the page's table of contents for assistive technology."
       // "Les titres sont la table des matières de la page pour les technologies d'assistance.")
      headingOrder
  , Criterion "heading-look" ("What looks like a heading is one" // "Ce qui a l'air d'un titre en est un") ("RGAA 9.1 · WCAG 1.3.1 · thresholds (tool)" // "RGAA 9.1 · WCAG 1.3.1 · seuils (outil)") Light
      ("A heading styled but not marked is invisible to assistive technology."
       // "Un titre stylé mais non balisé est invisible aux technologies d'assistance.")
      headingLook
  , Criterion "list-look" ("What looks like a list is one" // "Ce qui a l'air d'une liste en est une") "RGAA 9.3 · WCAG 1.3.1" Light
      ("A marked list states its length and allows moving item to item."
       // "Une liste balisée annonce sa longueur et se parcourt élément par élément.")
      listLook
  , Criterion "empty-blocks" ("No element is used as a gap" // "Aucun élément ne sert d'espace") "RGAA 8.9 · WCAG 1.3.1" Light
      ("Empty elements are still announced. Spacing belongs in CSS."
       // "Les éléments vides restent annoncés. L'espacement relève du CSS.")
      emptyBlocks
  , Criterion "presentation" ("Appearance is left to the style sheet" // "L'apparence est confiée à la feuille de styles") "RGAA 10.1 · WCAG 1.3.1" Medium
      ("Styling in markup overrides the reader's own settings."
       // "Le style écrit dans le balisage écrase les réglages du lecteur.")
      presentation
  , Criterion "image-alt" ("Images carry a text alternative" // "Les images portent une alternative textuelle") "RGAA 1.1–1.3 · WCAG 1.1.1" Light
      ("What an image says to screen readers, search engines and slow connections."
       // "Ce que dit une image aux lecteurs d'écran, aux moteurs de recherche et aux connexions lentes.")
      imageAlt
  , Criterion "text-contrast" ("Text contrasts with its background" // "Le texte contraste avec son fond") "RGAA 3.2 · WCAG 1.4.3" Light
      ("Legibility in sunlight, on worn screens, and for low or color-deficient vision."
       // "Lisibilité au soleil, sur écran usé, et pour les vues faibles ou daltoniennes.")
      contrast
  , Criterion "link-name" ("Links have a name" // "Les liens ont un intitulé") "RGAA 6.1–6.2 · WCAG 2.4.4" Light
      ("Screen readers list links out of context. The name is all that remains."
       // "Les lecteurs d'écran listent les liens hors contexte. Seul l'intitulé reste.")
      linkName
  , Criterion "link-distinct" ("Links to different places differ in name" // "Des liens vers des lieux différents diffèrent d'intitulé") "RGAA 6.1 · WCAG 2.4.4" Medium
      ("Identical names for different destinations cannot be told apart."
       // "Des intitulés identiques vers des destinations différentes ne se distinguent pas.")
      linkDistinct
  , Criterion "button-name" ("Buttons have a name" // "Les boutons ont un intitulé") "RGAA 11.9 · WCAG 4.1.2" Light
      ("An unnamed button is announced as “button”, nothing more."
       // "Un bouton sans intitulé est annoncé « bouton », rien de plus.")
      buttonName
  , Criterion "label-in-name" ("The words shown are in the name" // "Les mots montrés figurent dans le nom") "RGAA 6.1 · 11.2 · 11.9 · WCAG 2.5.3" Light
      ("Voice commands use the visible words. They must be in the coded name."
       // "Les commandes vocales reprennent les mots visibles. Ils doivent figurer dans le nom codé.")
      labelInName
  , Criterion "control-label" ("Form fields have a name" // "Les champs de formulaire ont un intitulé") "RGAA 11.1 · WCAG 1.3.1" Light
      ("The visible name states what the field expects and enlarges its target."
       // "Le nom visible dit ce que le champ attend et agrandit sa zone cliquable.")
      controlLabel
  , Criterion "group-legend" ("Groups of fields have a legend" // "Les groupes de champs ont une légende") "RGAA 11.6 · WCAG 1.3.1" Light
      ("The legend names the question a set of choices answers."
       // "La légende nomme la question à laquelle répondent les choix.")
      groupLegend
  , Criterion "field-group" ("Choices of one question are grouped" // "Les choix d'une même question sont regroupés") "RGAA 11.5 · WCAG 1.3.1" Medium
      ("Choices to one question are announced together."
       // "Les choix d'une même question sont annoncés ensemble.")
      fieldGroup
  , Criterion "autocomplete" ("Fields for personal data state their purpose" // "Les champs de données personnelles déclarent leur finalité") "RGAA 11.13 · WCAG 1.3.5" Light
      ("Declared purposes let browsers fill fields: less typing, fewer errors."
       // "Les finalités déclarées permettent le remplissage automatique : moins de saisie, moins d'erreurs.")
      autocompleteC
  , Criterion "table-headers" ("Data tables declare their headers" // "Les tableaux de données déclarent leurs en-têtes") "RGAA 5.3 · 5.6–5.8 · WCAG 1.3.1" Medium
      ("Headers announce each cell with its row and column."
       // "Les en-têtes annoncent chaque cellule avec sa ligne et sa colonne.")
      tableHeaders
  , Criterion "frame-title" ("Frames have a title" // "Les cadres ont un titre") "RGAA 2.1 · WCAG 4.1.2" Light
      ("The title says what a frame contains before it is entered."
       // "Le titre dit ce que contient un cadre avant d'y entrer.")
      frameTitle
  , Criterion "autoplay" ("No sound starts by itself" // "Aucun son ne démarre seul") "RGAA 4.10 · WCAG 1.4.2" Light
      ("Sound that starts alone drowns out the screen reader."
       // "Un son qui démarre seul couvre le lecteur d'écran.")
      autoplayC
  , Criterion "media-captions" ("Videos carry captions" // "Les vidéos portent des sous-titres") "RGAA 4.3 · WCAG 1.2.2" Heavy
      ("Speech and sound for those who cannot hear, or have sound off."
       // "La parole et les sons pour qui n'entend pas, ou coupe le son.")
      mediaCaptions
  , Criterion "unique-ids" ("Element ids are unique" // "Les id des éléments sont uniques") "RGAA 8.2" Light
      ("Field names, descriptions and anchors point by id. Duplicates point wrong."
       // "Noms de champs, descriptions et ancres pointent par id. Les doublons pointent mal.")
      uniqueIds
  , Criterion "tab-order" ("The keyboard follows the order of the page" // "Le clavier suit l'ordre de la page") "RGAA 12.8 · WCAG 2.4.3" Medium
      ("A positive tabindex pulls an element out of reading order."
       // "Un tabindex positif sort l'élément de l'ordre de lecture.")
      tabOrder
  , Criterion "hidden-focus" ("Nothing hidden takes the focus" // "Rien de caché ne prend le focus") "RGAA 10.8 · WCAG 4.1.2" Medium
      ("Focus on hidden content lands on something never announced."
       // "Le focus sur un contenu caché tombe sur un élément jamais annoncé.")
      hiddenFocusC
  , Criterion "focus-visible" ("The focus can be seen" // "Le focus se voit") "RGAA 10.7 · WCAG 2.4.7" Light
      ("The focus mark is a keyboard user's only position indicator."
       // "La marque du focus est le seul repère de position au clavier.")
      focusVisible
  , Criterion "keyboard-trap" ("The keyboard can leave what it enters" // "Le clavier peut quitter ce où il entre") "RGAA 12.9 · WCAG 2.1.2" Medium
      ("Without a mouse, a trap makes the rest of the page unreachable."
       // "Sans souris, un piège rend le reste de la page inaccessible.")
      keyboardTrap
  , Criterion "lang-code" ("Language codes are valid and right" // "Les codes de langue sont valides et justes") "RGAA 8.4 · 8.7 · 8.8 · WCAG 3.1.1 · 3.1.2" Light
      ("A wrong code reads the text in the wrong voice." // "Un code erroné lit le texte avec la mauvaise voix.")
      langCode
  , Criterion "direction" ("Right-to-left text declares its direction" // "Le texte de droite à gauche déclare son sens") "RGAA 8.10 · WCAG 1.3.2" Light
      ("Without a declared direction, punctuation and numbers land on the wrong side." // "Sans sens déclaré, ponctuation et chiffres tombent du mauvais côté.")
      direction
  , Criterion "text-spacing" ("Text survives wider spacing" // "Le texte résiste à un espacement élargi") "RGAA 10.12 · WCAG 1.4.12" Medium
      ("Readers with dyslexia or low vision widen spacing. Fixed boxes then cut the text." // "Les lecteurs dyslexiques ou malvoyants élargissent l'espacement. Les boîtes fixes coupent alors le texte.")
      textSpacing
  , Criterion "motion" ("What moves can be stopped" // "Ce qui bouge peut être arrêté") "RGAA 13.8 · WCAG 2.2.2" Medium
      ("Endless motion pulls attention away and cannot be read past." // "Un mouvement sans fin détourne l'attention et gêne la lecture.")
      motion
  , Criterion "clickable" ("What the pointer clicks, the keyboard reaches" // "Ce que le pointeur clique, le clavier l'atteint") "RGAA 7.3 · WCAG 2.1.1" Medium
      ("An action reachable only by pointer is closed to keyboards and switches." // "Une action accessible au seul pointeur est fermée au clavier et aux contacteurs.")
      clickableC
  , Criterion "generated-text" ("Words stay without the style sheet" // "Les mots restent sans feuille de styles") "RGAA 10.2 · WCAG 1.3.1" Light
      ("Words set in CSS vanish without styles and are not always read aloud." // "Les mots posés en CSS disparaissent sans styles et ne sont pas toujours lus.")
      generatedText
  , Criterion "paired-colours" ("A text colour comes with a background" // "Une couleur de texte vient avec un fond") "RGAA 10.5" Light
      ("A reader's own background under a set text colour can make it unreadable." // "Le fond choisi par le lecteur sous une couleur imposée peut rendre le texte illisible.")
      pairedColours
  , Criterion "link-visible" ("Links stand out from the text around them" // "Les liens se distinguent du texte qui les entoure") "RGAA 10.6 · WCAG 1.4.1" Light
      ("A link that looks like its sentence is found by chance." // "Un lien qui ressemble à sa phrase se trouve par hasard.")
      linkVisible
  , Criterion "cryptic" ("Emoji have a text alternative" // "Les émojis ont une alternative textuelle") "RGAA 13.5 · 13.6" Light
      ("Screen readers announce emoji by their official name, which may not be the meaning." // "Les lecteurs d'écran annoncent un émoji par son nom officiel, qui n'est pas toujours son sens.")
      cryptic
  , Criterion "captcha" ("A CAPTCHA has another way through" // "Un CAPTCHA a une autre voie") "RGAA 1.4 · 1.5 · WCAG 1.1.1" Heavy
      ("A visual test with no alternative locks out anyone who cannot see it." // "Un test visuel sans alternative exclut quiconque ne le voit pas.")
      captcha
  , Criterion "documents" ("Office documents are accessible" // "Les documents bureautiques sont accessibles") "RGAA 13.3 · 13.4" Heavy
      ("A PDF without structure is a picture of text." // "Un PDF sans structure est une image de texte.")
      documents
  , Criterion "no-popup" ("No window opens by itself" // "Aucune fenêtre ne s'ouvre seule") "RGAA 13.2 · WCAG 3.2.1" Medium
      ("Unrequested windows move the reader without notice."
       // "Une fenêtre non demandée déplace le lecteur à son insu.")
      noPopup
  , Criterion "refresh" ("The page does not reload or leave on a timer" // "La page ne se recharge ni ne s'en va après un délai") "RGAA 13.1 · WCAG 2.2.1" Light
      ("Timed reloads and redirects take control from the reader."
       // "Rechargements et redirections minutés retirent le contrôle au lecteur.")
      refreshC
  , Criterion "ai-disclosure" ("Conversational AI is disclosed" // "L'IA conversationnelle est signalée") "AI Act art. 50(1)" Medium
      ("The AI Act requires telling people when they talk to a machine."
       // "Le règlement sur l'IA impose de dire à une personne qu'elle échange avec une machine.")
      aiDisclosure
  , Criterion "ai-image" ("Images made by AI say so" // "Les images produites par IA le disent") "AI Act art. 50(2) · 50(4)" Medium
      ("AI-made or altered images must be disclosed. The file often states its origin."
       // "Les images produites ou modifiées par IA doivent être signalées. Le fichier indique souvent son origine.")
      aiImage
  , Criterion "asks-on-arrival" ("Nothing is asked of the device on arrival" // "Rien n'est demandé à l'appareil à l'arrivée") "RGESN 4.13 · 6.6 · AI Act art. 50(3)" Light
      ("Permission requests before any action are answered blind."
       // "Une demande d'autorisation avant toute action reçoit une réponse à l'aveugle.")
      asksOnArrival
  , Criterion "third-parties" ("Third parties wait for consent" // "Les tiers attendent le consentement") "RGESN 4.4" Medium
      ("Each third party opens a connection to another company before consent."
       // "Chaque tiers ouvre une connexion vers une autre entreprise avant le consentement.")
      thirdPartiesC
  , Criterion "media-autoplay" ("Nothing plays by itself" // "Rien ne se lance seul") "RGESN 4.1" Light
      ("Autoplay downloads and decodes media no one asked for."
       // "La lecture automatique télécharge et décode un média que personne n'a demandé.")
      mediaAutoplay
  , Criterion "endless" ("The page has an end" // "La page a une fin") ("RGESN 4.2 · threshold one screen, twice (tool)" // "RGESN 4.2 · seuil un écran, deux fois (outil)") Medium
      ("Infinite scroll has no fixed weight and no reachable footer."
       // "Le défilement infini n'a ni poids fixe ni pied de page accessible.")
      endless
  , Criterion "fonts" ("Fonts are few and light" // "Les polices sont peu nombreuses et légères") "RGESN 4.8" Light
      ("Each font file delays text. Reference limit: two families, four variants, 400 kB."
       // "Chaque fichier de police retarde le texte. Limite du référentiel : deux familles, quatre variantes, 400 ko.")
      fontsC
  , Criterion "compression" ("Text travels compressed" // "Le texte voyage compressé") ("RGESN 6.3 · threshold 1 kB (tool)" // "RGESN 6.3 · seuil 1 ko (outil)") Light
      ("Text compresses to a third or less. Uncompressed, the rest is waste."
       // "Le texte se compresse au tiers ou moins. Non compressé, le reste est perdu.")
      compression
  , Criterion "caching" ("What does not change is kept by the browser" // "Ce qui ne change pas est gardé par le navigateur") "RGESN 6.2" Light
      ("Cached files are not fetched again on the next page or visit."
       // "Un fichier en cache n'est pas rechargé à la page ou à la visite suivante.")
      caching
  , Criterion "protocol" ("The page travels by current protocols" // "La page voyage par des protocoles actuels") "RGESN 3.3 · 6.7" Medium
      ("HTTP/2 and 3 share one connection. TLS 1.3 connects faster. IPv6 avoids address translation."
       // "HTTP/2 et 3 partagent une connexion. TLS 1.3 se connecte plus vite. IPv6 évite la traduction d'adresse.")
      protocolC
  , Criterion "lazy-images" ("Images far down the page wait to be reached" // "Les images loin dans la page attendent d'être atteintes") ("RGESN 6.5 · threshold two screens (tool)" // "RGESN 6.5 · seuil deux écrans (outil)") Light
      ("Images far below the fold cost every reader, are seen by few."
       // "Les images loin sous la ligne de flottaison coûtent à tous, sont vues par peu.")
      lazyImages
  , Criterion "image-weight" ("Images are not larger than shown" // "Les images ne dépassent pas leur taille d'affichage") ("RGESN 6.4 · threshold 2× (tool)" // "RGESN 6.4 · seuil 2× (outil)") Light
      ("Undisplayed pixels still travel, decode and use memory and battery."
       // "Les pixels non affichés voyagent, se décodent et consomment mémoire et batterie.")
      imageWeight
  , Criterion "image-format" ("Heavy images use a modern format" // "Les images lourdes utilisent un format récent") ("RGESN 5.1 · threshold 30 kB (tool)" // "RGESN 5.1 · seuil 30 ko (outil)") Light
      ("AVIF and WebP carry the same image in fewer bytes."
       // "AVIF et WebP portent la même image en moins d'octets.")
      imageFormat
  ] ++ checklist

-- helpers ---------------------------------------------------------------

visible :: Surface -> Bool
visible s = hidden s /= Just True

surfacesOf :: Text -> Observation -> [Surface]
surfacesOf k o = [s | s <- surfaces o, kind s == k, visible s]

blank :: Maybe Text -> Bool
blank = maybe True (T.null . T.strip)

on :: Surface -> Verdict -> Phrase -> Maybe Phrase -> Mark
on s = \v seen ch -> Mark v (Just s) seen ch Nothing

onPage :: Verdict -> Phrase -> Maybe Phrase -> Mark
onPage = \v seen ch -> Mark v Nothing seen ch Nothing

-- | A mark that puts its question to a person.
asking :: Phrase -> Mark -> Mark
asking q m = m { mAsk = Just q }

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
    -- A rule can see whether an image has a text alternative, and whether it is declared decorative;
    -- only a person can see whether the image is decorative, and whether its alternative says what it shows.
    img s = case T.strip <$> alt s of
      _ | tiny s -> on s Pass ("under 4 px, carries no information" // "moins de 4 px, ne porte aucune information") Nothing
      _ | role s `elem` [Just "presentation", Just "none"] -> decorative s ("role=presentation, marked decorative" // "role=presentation, marquée décorative")
      Nothing -> on s Fail ("no alt attribute" // "pas d'attribut alt") (Just ("add alt; alt=\"\" if the image is decorative" // "ajouter alt ; alt=\"\" si l'image est décorative"))
      Just "" -> decorative s ("alt=\"\", marked decorative" // "alt=\"\", marquée décorative")
      Just a
        | fileLike a -> asking pertinent (on s Review ("alt " <> quote a <> (", a file name" // ", un nom de fichier")) (Just ("rewrite the alternative to describe the image" // "réécrire l'alternative pour décrire l'image")))
        | otherwise -> asking pertinent (on s Review ("alt " <> quote a) (Just ("rewrite the alternative to describe the image" // "réécrire l'alternative pour décrire l'image")))
    graphic s
      | blank (name s) = on s Fail ("role=img without a name" // "role=img sans nom") (Just ("add aria-label or <title>" // "ajouter aria-label ou <title>"))
      | otherwise = asking pertinent (on s Review (quote (fromMaybe "" (name s))) (Just ("rewrite the name to describe the image" // "réécrire le nom pour décrire l'image")))
    decorative s seen = asking ("Is the image decorative?" // "L'image est-elle décorative ?")
      (on s Review seen (Just ("add an alternative describing the image" // "ajouter une alternative qui décrit l'image")))
    pertinent = "Does the alternative describe the image?" // "L'alternative décrit-elle l'image ?"
    tiny s = maybe False (\(w, h) -> w < 4 || h < 4) (shown s)
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
--   words shown must be in it. Case and punctuation do not count; a caption of
--   one character is a symbol and is left alone.
labelInName o = recorded o . orNA ("no name given by the code over words shown" // "aucun nom donné par le code par-dessus des mots montrés") $
  [ if plain l `T.isInfixOf` plain n
      then on s Pass (quote n <> (" holds " // " contient ") <> quote l) Nothing
      else on s Fail (("shows " // "montre ") <> quote l <> (", is named " // ", se nomme ") <> quote n)
             (Just ("begin the name with the visible words" // "commencer le nom par les mots visibles"))
  | k <- ["link", "button", "control"], s <- surfacesOf k o
  , by s `elem` [Just "aria-label", Just "aria-labelledby"]
  , Just l <- [label s], Just n <- [name s], T.length (plain l) > 1, not (any ("…" `T.isSuffixOf`) [l, n]) ]

controlLabel o = orNA ("no form fields on the page" // "aucun champ de formulaire dans la page") (map judge (surfacesOf "control" o))
  where judge s | blank (name s) = on s Fail (("field without a name" // "champ sans intitulé") <> maybe "" (\p -> ("; placeholder " // " ; seulement un texte indicatif, ") <> quote p <> (" only" // "")) (placeholder s))
                                          (Just ("associate a <label>, or add aria-label" // "associer un <label>, ou ajouter aria-label"))
                | otherwise = on s Pass (quote (fromMaybe "" (name s))) Nothing

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

-- page, read in 0.5 -------------------------------------------------------

-- | Facts the observer has recorded since 0.5. An older observation is not judged on them.
since5 :: Observation -> Maybe a -> (a -> [Mark]) -> [Mark]
since5 _ x k = maybe [onPage NA ("not recorded by the observer of that time" // "non relevé par l'observateur d'alors") Nothing] k x

-- | A language code: a primary subtag of two letters that ISO 639-1 lists, or of three letters; then subtags of one to eight.
validLang :: Text -> Bool
validLang t = case T.splitOn "-" (T.toLower (T.strip t)) of
  p : rest -> (if T.length p == 2 then p `elem` iso639 else T.length p == 3 && T.all isAlpha p)
              && all (\x -> T.length x >= 1 && T.length x <= 8 && T.all isAlphaNum x) rest
  [] -> False
  where
    iso639 = T.words "aa ab ae af ak am an ar as av ay az ba be bg bh bi bm bn bo br bs ca ce ch co cr cs cu cv cy da de dv dz ee el en eo es et eu \
      \fa ff fi fj fo fr fy ga gd gl gn gu gv ha he hi ho hr ht hu hy hz ia id ie ig ii ik io is it iu ja jv ka kg ki kj kk kl km kn ko kr ks ku kv \
      \kw ky la lb lg li ln lo lt lu lv mg mh mi mk ml mn mr ms mt my na nb nd ne ng nl nn no nr nv ny oc oj om or os pa pi pl ps pt qu rm rn ro \
      \ru rw sa sc sd se sg si sk sl sm sn so sq sr ss st su sv sw ta te tg th ti tk tl tn to tr ts tt tw ty ug uk ur uz ve vi vo wa wo xh yi yo \
      \za zh zu"

langCode, direction, textSpacing, motion, clickableC, generatedText, pairedColours, linkVisible, cryptic, captcha, documents :: Observation -> [Mark]
langCode o = since5 o (langs (page o)) $ \ls -> case T.strip <$> lang (page o) of
  Nothing -> [onPage NA ("the page states no language" // "la page ne déclare pas de langue") Nothing]
  Just "" -> [onPage NA ("the page states no language" // "la page ne déclare pas de langue") Nothing]
  Just l ->
    (if validLang l
       then asking (("Is the page written in " // "La page est-elle écrite en ") <> code l <> ("?" // " ?"))
              (onPage Review (("page language " // "langue de la page ") <> code l) (Just ("set lang to the language the page is written in" // "régler lang sur la langue de la page")))
       else onPage Fail (("page language " // "langue de la page ") <> code l <> (", not a language code" // ", pas un code de langue")) (Just ("use an ISO 639 code, such as en or fr" // "utiliser un code ISO 639, comme en ou fr")))
    : [ if validLang v
          then if ownName v x
            then onSel o x Pass (quote (shownAt x) <> (" names its language in that language" // " nomme sa langue dans cette langue")) Nothing
            else asking (("Is this passage in " // "Ce passage est-il en ") <> code v <> ("?" // " ?")) (onSel o x Review (("passage marked " // "passage marqué ") <> code v) (Just ("set lang to the passage's language" // "régler lang sur la langue du passage")))
          else onSel o x Fail (code v <> (", not a language code" // ", pas un code de langue")) (Just ("use an ISO 639 code" // "utiliser un code ISO 639"))
      | (x, v) <- ls ]
    ++ [ asking ("Is every passage in another language marked with lang?" // "Chaque passage dans une autre langue est-il marqué par lang ?")
           (onPage Review (case length ls of
                             0 -> "no passage marked in another language" // "aucun passage marqué dans une autre langue"
                             1 -> "1 passage marked in another language" // "1 passage marqué dans une autre langue"
                             n -> both (num n) <> (" passages marked in another language" // " passages marqués dans une autre langue")) (Just ("mark each passage in another language with lang" // "marquer chaque passage dans une autre langue avec lang"))) ]
  where code x = both ("lang=\"" <> x <> "\"")
        shownAt x = head ([n | s <- surfaces o, sel s == x, Just n <- [name s], not (T.null (T.strip n))] ++ [""])
        ownName v x = let n = T.toCaseFold (T.strip (shownAt x))
                      in not (T.null n) && lookup (T.toLower (T.takeWhile (/= '-') v)) endonyms == Just n

-- | Each language's name for itself, as a language switcher shows it.
endonyms :: [(Text, Text)]
endonyms = [ (c, T.toCaseFold n) | (c, n) <-
  [ ("ar", "العربية"), ("bg", "български"), ("br", "brezhoneg"), ("ca", "català"), ("co", "corsu"), ("cs", "čeština")
  , ("cy", "cymraeg"), ("da", "dansk"), ("de", "deutsch"), ("el", "ελληνικά"), ("en", "english"), ("es", "español")
  , ("et", "eesti"), ("eu", "euskara"), ("fa", "فارسی"), ("fi", "suomi"), ("fr", "français"), ("ga", "gaeilge")
  , ("gl", "galego"), ("he", "עברית"), ("hi", "हिन्दी"), ("hr", "hrvatski"), ("hu", "magyar"), ("is", "íslenska")
  , ("it", "italiano"), ("ja", "日本語"), ("ko", "한국어"), ("lb", "lëtzebuergesch"), ("lt", "lietuvių"), ("lv", "latviešu")
  , ("mt", "malti"), ("nb", "norsk bokmål"), ("nl", "nederlands"), ("nn", "nynorsk"), ("no", "norsk"), ("oc", "occitan")
  , ("pl", "polski"), ("pt", "português"), ("ro", "română"), ("ru", "русский"), ("sk", "slovenčina"), ("sl", "slovenščina")
  , ("sv", "svenska"), ("th", "ไทย"), ("tr", "türkçe"), ("uk", "українська"), ("vi", "tiếng việt"), ("zh", "中文") ] ]

direction o = since5 o (rtl (page o)) $ \r -> case (chars r, marked r) of
  (0, _) -> [onPage NA ("no right-to-left script on the page" // "aucune écriture de droite à gauche dans la page") Nothing]
  (n, True) -> [onPage Pass (both (num n) <> (" right-to-left characters; direction declared" // " caractères de droite à gauche ; sens déclaré")) Nothing]
  (n, False) -> [onPage Fail (both (num n) <> (" right-to-left characters; no direction declared" // " caractères de droite à gauche ; aucun sens déclaré")) (Just ("add dir=\"rtl\" to each right-to-left passage" // "ajouter dir=\"rtl\" à chaque passage de droite à gauche"))]

textSpacing o = since5 o (spaced (page o)) $ \ss -> case ss of
  [] -> [onPage Pass ("no text cut with wider spacing" // "aucun texte coupé avec un espacement élargi") Nothing]
  _ -> [ onSel o x Fail ("text cut once spacing is widened" // "texte coupé une fois l'espacement élargi") (Just ("let the box grow with its text: no fixed height with overflow hidden" // "laisser la boîte suivre son texte : pas de hauteur fixe avec overflow hidden")) | x <- ss ]

motion o = since5 o (moving (page o)) $ \ms -> case ms of
  [] -> [onPage Pass ("no looping animation found" // "aucune animation en boucle trouvée") Nothing]
  _ -> [ asking ("Can it be paused, stopped or hidden?" // "Peut-on la mettre en pause, l'arrêter ou la masquer ?")
           (onSel o x Review ("moves without end" // "bouge sans fin") (Just ("add a pause control, or stop it within 5 seconds" // "ajouter une commande de pause, ou l'arrêter sous 5 secondes"))) | x <- ms ]

clickableC o = since5 o (clickable (page o)) $ \cs -> case cs of
  [] -> [onPage Pass ("nothing clickable is out of the keyboard's reach" // "rien de cliquable n'échappe au clavier") Nothing]
  _ -> [ if k == "handler"
           then onSel o x Fail ("acts on click; no key reaches it" // "agit au clic ; aucune touche ne l'atteint") (Just remedy)
           else asking ("Is it decoration only, with no action on click?" // "Est-ce une décoration, sans action au clic ?")
                  (onSel o x Review ("pointer cursor; no key reaches it" // "curseur de pointage ; aucune touche ne l'atteint") (Just remedy))
       | (x, k) <- cs ]
  where remedy = "use a <button> or a link" // "utiliser un <button> ou un lien"

generatedText o = since5 o (generated (page o)) $ \gs -> case gs of
  [] -> [onPage Pass ("no words set by the style sheet" // "aucun mot posé par la feuille de styles") Nothing]
  _ -> [ asking ("Is this text decoration only?" // "Ce texte est-il purement décoratif ?")
           (onSel o x Review (quote w <> (" set by the style sheet" // " posé par la feuille de styles")) (Just ("move the words into the page" // "placer les mots dans la page"))) | (x, w) <- gs ]

pairedColours o = since5 o (unpaired (page o)) $ \us -> case us of
  [] -> [onPage Pass ("every text colour has a background" // "chaque couleur de texte a un fond") Nothing]
  _ -> [ onSel o x Fail ("text colour set, no background set" // "couleur de texte posée, aucun fond posé") (Just ("set a background colour on it or on a parent" // "poser une couleur de fond sur lui ou sur un parent")) | x <- us ]

linkVisible o = since5 o (blended (page o)) $ \bs -> case bs of
  [] -> [onPage Pass ("links in running text stand out" // "les liens du texte courant se distinguent") Nothing]
  _ -> [ onSel o x Fail ("looks like the text around it: no underline, contrast under 3:1" // "ressemble au texte autour : pas de soulignement, contraste sous 3:1")
           (Just ("underline it, or set it at 3:1 against the text around it" // "le souligner, ou le porter à 3:1 face au texte autour")) | x <- bs ]

cryptic o = since5 o (emoji (page o)) $ \n -> case n of
  0 -> [onPage NA ("no emoji on the page" // "aucun émoji dans la page") Nothing]
  _ -> [asking ("Does each emoji have a text alternative, or is it decoration?" // "Chaque émoji a-t-il une alternative textuelle, ou est-il décoratif ?")
          (onPage Review (both (num n) <> (" emoji on the page" // " émojis dans la page")) (Just ("wrap meaningful emoji in role=\"img\" with aria-label" // "entourer les émojis porteurs de sens de role=\"img\" avec aria-label")))]

captcha o = case [r | r <- concat (resources (network o)), any (`T.isInfixOf` T.toLower (xUrl r)) marks] of
  [] -> [onPage NA ("no CAPTCHA loaded" // "aucun CAPTCHA chargé") Nothing]
  r : _ ->
    [ asking ("Is there another way through it, by sound or by another test?" // "Existe-t-il une autre voie, sonore ou par un autre test ?")
        (onPage Review (("CAPTCHA from " // "CAPTCHA de ") <> both (host (xUrl r))) (Just ("offer an audio test or another way through" // "proposer un test audio ou une autre voie")))
    , asking ("Does its text alternative say what it is and what it is for?" // "Son alternative dit-elle ce qu'il est et à quoi il sert ?")
        (onPage Review ("its text alternative" // "son alternative textuelle") (Just ("say what the test is and what it is for" // "dire ce qu'est le test et à quoi il sert"))) ]
  where
    marks = ["recaptcha", "hcaptcha", "turnstile", "challenges.cloudflare", "friendlycaptcha", "captcha"]
    host u = case T.splitOn "/" u of _ : _ : h : _ -> h; _ -> u

documents o = case [s | s <- surfacesOf "link" o, Just h <- [href s], any (`T.isSuffixOf` T.toLower (T.takeWhile (`notElem` ("?#" :: String)) h)) exts] of
  [] -> [onPage NA ("no office document linked" // "aucun document bureautique lié") Nothing]
  ds -> [ asking ("Is this document accessible, or is an accessible version offered with the same content?" // "Ce document est-il accessible, ou une version accessible au même contenu est-elle proposée ?")
            (on s Review (both (file (fromMaybe "" (href s)))) (Just ("tag the document, or offer an accessible version" // "baliser le document, ou proposer une version accessible"))) | s <- ds ]
  where exts = [".pdf", ".doc", ".docx", ".odt", ".xls", ".xlsx", ".ods", ".ppt", ".pptx", ".odp", ".rtf"]

-- | The keyboard walk, recorded since observer 0.5. An older observation is not judged on it.
walked :: Observation -> (Keys -> [Mark]) -> [Mark]
walked o k = maybe [onPage NA ("not recorded by the observer of that time" // "non relevé par l'observateur d'alors") Nothing] k (keys (page o))

-- | A stop "shows nothing" when not one pixel of the screen differs between the element focused and
--   the element left: any change anywhere counts as seen, so the rule may miss an unseen focus,
--   and never names a seen one.
focusVisible :: Observation -> [Mark]
focusVisible o = walked o $ \k -> case (checked k, unseen k) of
  (0, _) -> [onPage NA ("nothing on the page takes the focus" // "rien dans la page ne prend le focus") Nothing]
  (n, []) -> [onPage Pass (both (num n) <> (if n == 1 then " stop, focus visible" // " arrêt, focus visible" else " stops, focus visible at each" // " arrêts, focus visible à chacun")) Nothing]
  (_, ss) -> [ onSel o x Fail ("no visible focus" // "focus invisible")
                 (Just ("add a :focus-visible outline that contrasts with its surroundings" // "ajouter un contour :focus-visible contrasté")) | x <- ss ]

keyboardTrap :: Observation -> [Mark]
keyboardTrap o = walked o $ \k -> case (ended k, trap k) of
  ("stuck", Just x) -> [onSel o x Fail ("focus held: Tab, Shift+Tab and Escape blocked" // "focus retenu : Tab, Maj+Tab et Échap bloqués")
                         (Just ("release Tab and Shift+Tab" // "libérer Tab et Maj+Tab"))]
  ("loop", Just x) -> [asking ("Does the cycle have a stated exit?" // "Le circuit a-t-il une sortie indiquée ?")
                         (onSel o x Review (("focus cycles after " <> num (stops k) <> " stops; the rest of the page is unreachable")
                                             // ("le focus tourne après " <> num (stops k) <> " arrêts ; le reste de la page est inaccessible"))
                            (Just ("release Tab, or state the exit key" // "libérer Tab, ou indiquer la touche de sortie")))]
  _ | stops k == 0 -> [onPage NA ("nothing on the page takes the focus" // "rien dans la page ne prend le focus") Nothing]
  ("frame", _) -> [onPage Review (both (num (stops k)) <> (" stops, then an external frame, not followed" // " arrêts, puis un cadre externe, non suivi")) Nothing]
  ("cap", _) -> [onPage Pass ("first " <> num (stops k) <> " stops lead on; walk ended there" // num (stops k) <> " premiers arrêts sans blocage ; parcours arrêté là") Nothing]
  _ -> [onPage Pass ((num (stops k) <> (if stops k == 1 then " stop" else " stops") <> ", no trap")
                     // (num (stops k) <> (if stops k == 1 then " arrêt" else " arrêts") <> ", aucun piège")) Nothing]

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
