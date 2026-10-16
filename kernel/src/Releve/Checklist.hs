-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
{-# LANGUAGE OverloadedStrings #-}
-- | The RGAA 4.1.2 criteria that no rule decides from what a page shows. Each
--   is put to the reviewer as one question for the page, and is not put where
--   the page holds nothing it applies to: no video, no question on video. The
--   questions are this tool's short form; the official text prevails.
module Releve.Checklist (checklist, wholePage) where

import Data.Maybe (isJust)
import Data.Text (Text)
import qualified Data.Text as T
import Releve.Types hiding (scripted)
import qualified Releve.Types as P

-- | A theme: its title, what makes it apply, and its questions with their remedies.
data Theme = Theme
  { tId :: Text, tTitle :: Phrase, tApplies :: Observation -> Maybe Phrase, tNone :: Phrase
  , tItems :: [(Text, Phrase, Phrase)] }

checklist :: [Criterion]
checklist = map criterion themes
  where
    criterion th = Criterion (tId th) (tTitle th) (both ("RGAA " <> T.intercalate " · " [i | (i, _, _) <- tItems th])) Medium
      ("Criteria only a reviewer can decide, one question each." // "Critères que seul un relecteur peut trancher, une question chacun.")
      (judge th)
    judge th o = case tApplies th o of
      Nothing -> [Mark NA Nothing (tNone th) Nothing Nothing]
      Just seen -> [ case unasked i o of
                       Just why -> Mark NA Nothing (both ("RGAA " <> i <> " · ") <> why) Nothing Nothing
                       Nothing -> Mark Review Nothing (both ("RGAA " <> i <> " · ") <> seen) (Just fix) (Just q)
                   | (i, q, fix) <- tItems th ]

-- | Why a question is not put to this page, though its theme applies: what it asks
--   about cannot exist there. Shortcuts, gestures and motion need a script.
unasked :: Text -> Observation -> Maybe Phrase
unasked i o
  | i `elem` ["12.10", "13.10", "13.11", "13.12"], not (scripted o) = Just noScript
  | i == "11.7", not (any ((== Just True) . grouped) fields) = Just ("no group of fields" // "aucun groupe de champs")
  | i == "11.8", not (any ((`elem` [Just "select-one", Just "select-multiple"]) . itype) fields) = Just ("no list of options" // "aucune liste d'options")
  | otherwise = Nothing
  where fields = [s | s <- surfaces o, kind s == "control", hidden s /= Just True]

-- | Whether the page runs script: in its markup, or fetched. An observation
--   that did not count the markup's script is taken to have some.
scripted :: Observation -> Bool
scripted o = maybe True (> 0) (P.scripted (page o)) || any ((== "Script") . xKind) (concat (resources (network o)))

noScript :: Phrase
noScript = "no script on the page" // "aucun script dans la page"

-- | The themes asked of the page as a whole, not of elements counted on it:
--   what a site's template decides as much as any one page. Pages built on the
--   same template are asked these once.
wholePage :: [Text]
wholePage = ["review-colours", "review-scripts", "review-structure", "review-presentation", "review-navigation", "review-consultation"]

themes :: [Theme]
themes =
  [ Theme "review-images" ("Images, reviewed" // "Images, à relire") (count "img" ("image" // "image", "images" // "images")) ("no images on the page" // "aucune image dans la page")
      [ ("1.6", "Does every image that carries detailed information have a detailed description?" // "Chaque image porteuse d'une information détaillée a-t-elle une description détaillée ?", "add a description nearby or linked by aria-describedby" // "ajouter une description proche ou reliée par aria-describedby")
      , ("1.7", "Does each detailed description say what the image shows?" // "Chaque description détaillée dit-elle ce que montre l'image ?", "rewrite the description" // "réécrire la description")
      , ("1.8", "Is text shown as an image replaced by styled text where possible?" // "Le texte en image est-il remplacé par du texte stylé quand c'est possible ?", "set the text as text" // "composer le texte en texte")
      , ("1.9", "Is each caption tied to its image by figure and figcaption?" // "Chaque légende est-elle reliée à son image par figure et figcaption ?", "wrap image and caption in <figure> with <figcaption>" // "placer image et légende dans <figure> avec <figcaption>") ]
  , Theme "review-frames" ("Frames, reviewed" // "Cadres, à relire") (count "iframe" ("frame" // "cadre", "frames" // "cadres")) ("no frames on the page" // "aucun cadre dans la page")
      [ ("2.2", "Does each frame's title say what it contains?" // "Le titre de chaque cadre dit-il ce qu'il contient ?", "rewrite the frame's title" // "réécrire le titre du cadre") ]
  , Theme "review-colours" ("Colors, reviewed" // "Couleurs, à relire") always ("" // "")
      [ ("3.1", "Is no information given by color alone?" // "Aucune information n'est-elle donnée par la seule couleur ?", "add text, a shape or a pattern beside the color" // "ajouter un texte, une forme ou un motif à la couleur")
      , ("3.3", "Do interface parts and informative graphics contrast at 3:1?" // "Les composants d'interface et graphiques porteurs d'information contrastent-ils à 3:1 ?", "raise their contrast to 3:1" // "porter leur contraste à 3:1") ]
  , Theme "review-media" ("Media, reviewed" // "Médias, à relire") (count "media" ("audio or video element" // "élément audio ou vidéo", "audio or video elements" // "éléments audio ou vidéo")) ("no audio or video on the page" // "ni son ni vidéo dans la page")
      [ ("4.1", "Does each recorded audio or video have a transcript or audio description where needed?" // "Chaque média enregistré a-t-il, si nécessaire, une transcription ou une audiodescription ?", "add a transcript" // "ajouter une transcription")
      , ("4.2", "Does each transcript or audio description match the media?" // "Chaque transcription ou audiodescription correspond-elle au média ?", "rewrite it to match" // "la réécrire pour qu'elle corresponde")
      , ("4.4", "Do the captions match what is said?" // "Les sous-titres correspondent-ils à ce qui est dit ?", "correct the captions" // "corriger les sous-titres")
      , ("4.5", "Does each video have a synchronized audio description where needed?" // "Chaque vidéo a-t-elle, si nécessaire, une audiodescription synchronisée ?", "add an audio description" // "ajouter une audiodescription")
      , ("4.6", "Does the audio description say what the picture shows?" // "L'audiodescription dit-elle ce que montre l'image ?", "rewrite the audio description" // "réécrire l'audiodescription")
      , ("4.7", "Is each media clearly identified by the text around it?" // "Chaque média est-il clairement identifié par le texte qui l'entoure ?", "name the media beside it" // "nommer le média à côté de lui")
      , ("4.8", "Does each non-temporal media, such as a map or 3D view, have an alternative where needed?" // "Chaque média non temporel, comme une carte ou une vue 3D, a-t-il si nécessaire une alternative ?", "add an alternative" // "ajouter une alternative")
      , ("4.9", "Does each such alternative give the same information?" // "Chaque alternative donne-t-elle la même information ?", "rewrite the alternative" // "réécrire l'alternative")
      , ("4.11", "Can each recorded media be controlled by keyboard and pointer?" // "Chaque média enregistré se contrôle-t-il au clavier et au pointeur ?", "use a player whose controls take the focus" // "utiliser un lecteur dont les commandes prennent le focus")
      , ("4.12", "Can each non-temporal media be used by keyboard and pointer?" // "Chaque média non temporel s'utilise-t-il au clavier et au pointeur ?", "make its controls reachable by keyboard" // "rendre ses commandes accessibles au clavier")
      , ("4.13", "Is each media usable with assistive technology?" // "Chaque média est-il utilisable avec les technologies d'assistance ?", "give its controls names and roles" // "donner à ses commandes un nom et un rôle") ]
  , Theme "review-tables" ("Tables, reviewed" // "Tableaux, à relire") (count "table" ("table" // "tableau", "tables" // "tableaux")) ("no tables on the page" // "aucun tableau dans la page")
      [ ("5.1", "Does each complex data table have a summary?" // "Chaque tableau de données complexe a-t-il un résumé ?", "add a summary linked by aria-describedby or in the caption" // "ajouter un résumé relié par aria-describedby ou dans la légende")
      , ("5.2", "Does each summary say how the table is read?" // "Chaque résumé dit-il comment lire le tableau ?", "rewrite the summary" // "réécrire le résumé")
      , ("5.4", "Is each data table's title tied to it by caption or aria-labelledby?" // "Le titre de chaque tableau de données lui est-il relié par caption ou aria-labelledby ?", "use <caption>" // "utiliser <caption>")
      , ("5.5", "Does each table's title say what it holds?" // "Le titre de chaque tableau dit-il ce qu'il contient ?", "rewrite the title" // "réécrire le titre") ]
  , Theme "review-scripts" ("Scripts, reviewed" // "Scripts, à relire") (\o -> if scripted o then always o else Nothing) noScript
      [ ("7.1", "Does each scripted component expose its name, role and state?" // "Chaque composant scripté expose-t-il son nom, son rôle et son état ?", "use native elements, or the matching ARIA pattern" // "utiliser des éléments natifs, ou le motif ARIA correspondant")
      , ("7.2", "Where a script has an alternative, does it give the same function?" // "Quand un script a une alternative, donne-t-elle la même fonction ?", "make the alternative complete" // "compléter l'alternative")
      , ("7.4", "Is the user warned of, or in control of, any change of context a script starts?" // "L'utilisateur est-il averti ou maître de tout changement de contexte lancé par un script ?", "start changes of context on a button only" // "ne lancer de changement de contexte que sur un bouton")
      , ("7.5", "Are status messages announced by assistive technology?" // "Les messages de statut sont-ils annoncés par les technologies d'assistance ?", "put them in role=\"status\" or role=\"alert\"" // "les placer dans role=\"status\" ou role=\"alert\"") ]
  , Theme "review-title" ("Page title, reviewed" // "Titre de page, à relire") (\o -> if isJust (title (page o)) && title (page o) /= Just "" then Just (maybe "" (\x -> ("“" // "« ") <> both x <> ("”" // " »")) (title (page o))) else Nothing) ("the page has no title" // "la page n'a pas de titre")
      [ ("8.6", "Does the title say what the page is, and on which site?" // "Le titre dit-il ce qu'est la page, et sur quel site ?", "rewrite the title: the page, then the site" // "réécrire le titre : la page, puis le site") ]
  , Theme "review-structure" ("Quotations, reviewed" // "Citations, à relire") always ("" // "")
      [ ("9.4", "Is every quotation marked with q or blockquote?" // "Chaque citation est-elle marquée par q ou blockquote ?", "mark quotations with <q> or <blockquote>" // "marquer les citations par <q> ou <blockquote>") ]
  , Theme "review-presentation" ("Presentation, reviewed" // "Présentation, à relire") always ("" // "")
      [ ("10.3", "Does the page still make sense with styles off?" // "La page reste-t-elle compréhensible sans styles ?", "order the code as the page reads" // "ordonner le code comme la page se lit")
      , ("10.9", "Is no information given by shape, size or position alone?" // "Aucune information n'est-elle donnée par la seule forme, taille ou position ?", "add text to the shape, size or position" // "ajouter un texte à la forme, la taille ou la position")
      , ("10.10", "Where shape, size or position carry information, is a text equivalent in the code?" // "Quand forme, taille ou position portent une information, un équivalent textuel est-il dans le code ?", "put the text equivalent in the code" // "placer l'équivalent textuel dans le code")
      , ("10.13", "Can content shown on hover or focus be dismissed, hovered and kept?" // "Le contenu affiché au survol ou au focus peut-il être fermé, survolé et maintenu ?", "close it with Escape; keep it while hovered" // "le fermer par Échap ; le maintenir tant qu'il est survolé")
      , ("10.14", "Can content shown by CSS alone be shown by keyboard too?" // "Le contenu affiché par le seul CSS peut-il l'être au clavier ?", "show it on :focus-within as on :hover" // "l'afficher sur :focus-within comme sur :hover") ]
  , Theme "review-forms" ("Forms, reviewed" // "Formulaires, à relire") (count "control" ("form field" // "champ de formulaire", "form fields" // "champs de formulaire")) ("no form fields on the page" // "aucun champ de formulaire dans la page")
      [ ("11.3", "Do fields with the same function have the same name across pages?" // "Les champs de même fonction ont-ils le même intitulé d'une page à l'autre ?", "name them alike" // "les nommer de la même façon")
      , ("11.4", "Is each field's name set right beside it?" // "L'intitulé de chaque champ est-il placé juste à côté ?", "place the name beside the field" // "placer l'intitulé à côté du champ")
      , ("11.7", "Does each group's legend name the question it answers?" // "La légende de chaque groupe nomme-t-elle la question à laquelle il répond ?", "rewrite the legend" // "réécrire la légende")
      , ("11.8", "Are the options of each list grouped where they belong together?" // "Les options de chaque liste sont-elles regroupées quand elles vont ensemble ?", "group them with <optgroup>" // "les regrouper avec <optgroup>")
      , ("11.10", "Are required fields and expected formats shown, and errors named?" // "Les champs requis et formats attendus sont-ils indiqués, et les erreurs nommées ?", "state required fields and formats; name each error" // "indiquer champs requis et formats ; nommer chaque erreur")
      , ("11.11", "Do error messages suggest a correction where one is known?" // "Les messages d'erreur proposent-ils une correction quand elle est connue ?", "suggest the correction" // "proposer la correction")
      , ("11.12", "Can data be checked, corrected or confirmed before a form with legal or financial effect is sent?" // "Les données peuvent-elles être vérifiées, corrigées ou confirmées avant l'envoi d'un formulaire à effet juridique ou financier ?", "add a review step before sending" // "ajouter une étape de vérification avant l'envoi") ]
  , Theme "review-navigation" ("Navigation, reviewed" // "Navigation, à relire") always ("" // "")
      [ ("12.10", "Can single-key shortcuts be turned off or remapped?" // "Les raccourcis à une seule touche peuvent-ils être désactivés ou modifiés ?", "add a modifier key, or a setting to turn them off" // "ajouter une touche de modification, ou un réglage pour les désactiver")
      , ("12.11", "Is content shown on hover, focus or activation reachable by keyboard?" // "Le contenu affiché au survol, au focus ou à l'activation est-il accessible au clavier ?", "make it reachable with Tab" // "le rendre accessible avec Tab") ]
  , Theme "review-consultation" ("Consultation, reviewed" // "Consultation, à relire") always ("" // "")
      [ ("13.7", "Does nothing flash more than three times a second?" // "Rien ne clignote-t-il plus de trois fois par seconde ?", "remove the flashing" // "retirer le clignotement")
      , ("13.9", "Can the page be used in both portrait and landscape?" // "La page s'utilise-t-elle en portrait comme en paysage ?", "remove the orientation lock" // "retirer le blocage d'orientation")
      , ("13.10", "Can every multi-point or path gesture be done with a single point too?" // "Chaque geste complexe peut-il aussi se faire d'un seul point ?", "add buttons for each gesture" // "ajouter des boutons pour chaque geste")
      , ("13.11", "Can a single-pointer action be cancelled before it completes?" // "Une action au pointeur peut-elle être annulée avant d'aboutir ?", "act on release, not on press" // "agir au relâchement, pas à l'appui")
      , ("13.12", "Can features that use device motion be used another way?" // "Les fonctions liées au mouvement de l'appareil s'utilisent-elles autrement ?", "add a control, and a setting to turn motion off" // "ajouter une commande, et un réglage pour désactiver le mouvement") ]
  ]
  where
    always _ = Just ("this page" // "cette page")
    count k (one, many) o = case length [s | s <- surfaces o, kind s == k, hidden s /= Just True] of
      0 -> Nothing
      n -> Just (both (T.pack (show n)) <> " " <> (if n == 1 then one else many))
