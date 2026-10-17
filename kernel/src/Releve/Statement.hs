-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
{-# LANGUAGE OverloadedStrings #-}
-- | Two drafts the owner completes and publishes under their own name: an
--   accessibility statement on the model of the RGAA, and an eco-design
--   declaration on the 78 criteria of the RGESN. Each carries what the record
--   shows, and marks what only the owner can state. Neither says whether the
--   site conforms: that takes a complete evaluation, and the owner's word.
module Releve.Statement (statements) where

import Data.List (nub)
import qualified Data.Map.Strict as M
import Data.Maybe (listToMaybe, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Releve.Criteria (criteria, version)
import Releve.Declarations
import Releve.Frameworks
import Releve.Kernel
import Releve.Report (codify, date, esc, hostOf, style, typography)
import Releve.Types

-- | How one rule reads one page: the worst of its findings there, the reviewer's answers included.
reading :: [Finding] -> Verdict
reading fs
  | any ((== Fail) . fVerdict) fs = Fail
  | any ((== Review) . fVerdict) fs = Review
  | all ((== NA) . fVerdict) fs = NA
  | otherwise = Pass

statements :: Lang -> Text -> State -> Text
statements l release st = T.unlines $
  [ "<!doctype html>", "<html lang=\"" <> (if l == En then "en" else "fr") <> "\">", "<head>", "<meta charset=\"utf-8\">"
  , "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
  , "<title>" <> t ("Draft statements · " // "Projets de déclarations · ") <> esc site <> "</title>"
  , "<style>", style, "mark { color: inherit; background: #fff1a8; padding: 0 .15rem; }", "</style>", "</head>", "<body>", "<main>"
  , "<h1>" <> t ("Draft statements · " // "Projets de déclarations · ") <> esc site <> "</h1>"
  , p (t ("Two drafts, for the owner to complete and publish under their own name. They carry what the record of " // "Deux projets, que le responsable complète et publie sous son nom. Ils reprennent ce que montre le relevé de ")
       <> t (both (num (length pages)) <> (" pages shows, read from " // " pages, lu du ")) <> esc (date l first) <> t (" to " // " au ") <> esc (date l lastAt) <> t (". " // ". ")
       <> field ("Marked" // "Surligné") <> t (": what only the owner can state. Whether the site conforms is the owner's to state, after a complete evaluation; this record does not establish it."
                                          // " : ce que seul le responsable peut énoncer. La conformité du site relève du responsable, après une évaluation complète ; ce relevé ne l'établit pas.")) ]
  ++ dating
  ++ accessibility
  ++ ecodesign
  ++ [ "<p class=\"meta\">relevé " <> esc release <> " · " <> t ("criteria v" // "critères v") <> esc version <> "</p>", "</main>", "</body>", "</html>" ]
  where
    t = codify . typography l . say l
    p x = "<p>" <> x <> "</p>"
    num = T.pack . show
    field x = "<mark>" <> t x <> "</mark>"
    pages = latest st
    bodies = map oBody pages
    site = maybe "" host (listToMaybe bodies)
    first = minimum ("9999" : map at (concatMap (map oBody . previous st) pages ++ bodies))
    lastAt = maximum ("" : map at bodies)
    perRule c = [ reading [f | f <- assess st o, cId (fCrit f) == cId c] | o <- pages ]
    tally v c = length (filter (== v) (perRule c))
    n = length pages
    ofPages k = both (num k) <> (" of " // " sur ") <> both (num n) <> (" pages" // " pages")

    dating = case reverse (stamps st) of
      [] -> []
      (k, x) : _ -> [ "<p class=\"meta\">" <> t ("The record is dated " // "Le relevé est daté du ") <> esc (date l (stTime x)) <> t (" by " // " par ") <> esc (hostOf (stTsa x))
                      <> t (", an outside time-stamping authority (RFC 3161), up to record " // ", autorité d'horodatage extérieure (RFC 3161), jusqu'à l'enregistrement ") <> num (k - 1)
                      <> ", <code>" <> esc (T.take 8 (stHead x)) <> "</code>.</p>" ]

    -- The accessibility statement, section by section as the RGAA's model sets them out.
    seeing c = not (null (cites "RGAA" c ++ cites "WCAG" c))
    failing = [ (c, tally Fail c) | c <- criteria, seeing c, tally Fail c > 0 ]
    asked = sum [ tally Review c | c <- criteria, seeing c ]
    accessibility =
      [ "<h2>" <> t ("Accessibility statement" // "Déclaration d'accessibilité") <> "</h2>"
      , p (field ("Name of the entity" // "Nom de l'entité")
           <> t (" undertakes to make its online services accessible, in accordance with article 47 of law no. 2005-102 of 11 February 2005. "
                 // " s'engage à rendre ses services en ligne accessibles, conformément à l'article 47 de la loi n° 2005-102 du 11 février 2005. ")
           <> t ("This statement applies to " // "Cette déclaration d'accessibilité s'applique à ") <> esc site <> t ("." // "."))
      , p (t ("For a service under the European Accessibility Act, the information of its annex V, on how the service meets the accessibility requirements, also goes in the general terms and conditions: "
              // "Pour un service relevant de l'acte européen sur l'accessibilité, les informations de son annexe V, sur la façon dont le service satisfait aux exigences d'accessibilité, figurent aussi dans les conditions générales : ")
           <> field ("where they are published" // "où elles sont publiées") <> t ("." // "."))
      , "<h3>" <> t ("State of conformity" // "État de conformité") <> "</h3>"
      , p (field ("The state of conformity with the RGAA 4.1.2, as a complete evaluation finds it, and the share of criteria respected" // "L'état de conformité au RGAA 4.1.2, tel qu'une évaluation complète le constate, et le taux de critères respectés")
           <> t (". The rules of this record touch " // ". Les règles de ce relevé touchent ") <> t (both (num (length (touched "RGAA"))) <> (" of the 106 criteria, on " // " des 106 critères, sur ") <> both (num n)
                <> (" pages; a complete evaluation reads every criterion, on a sample of pages chosen for it." // " pages ; une évaluation complète lit chaque critère, sur un échantillon de pages choisi pour elle.")))
      , "<h3>" <> t ("Content that is not accessible" // "Contenus non accessibles") <> "</h3>"
      , p (t ("Failures the rules observed, by criterion:" // "Manquements constatés par les règles, par critère :")) ]
      ++ (if null failing then [p (t ("None on the pages observed." // "Aucun sur les pages observées."))]
          else ["<ul>"] ++ [ "<li>" <> t (cTitle c) <> " · " <> t (cRef c) <> " · " <> t (ofPages k) <> "</li>" | (c, k) <- failing ] ++ ["</ul>"])
      ++ [ p (t (both (num asked) <> (if asked == 1 then " point is left to the reviewer in the report; once answered, it enters this list or leaves it." // " point est laissé au relecteur dans le rapport ; une fois tranché, il entre dans cette liste ou en sort."
                                                    else " points are left to the reviewer in the report; once answered, each enters this list or leaves it." // " points sont laissés au relecteur dans le rapport ; une fois tranché, chacun entre dans cette liste ou en sort."))) | asked > 0 ]
      ++ [ p (field ("Derogations for disproportionate burden, and content outside the scope of the law, each with its reason and an accessible alternative"
                     // "Dérogations pour charge disproportionnée, et contenus non soumis à l'obligation d'accessibilité, chacun avec sa raison et une alternative accessible"))
         , "<h3>" <> t ("How this statement was established" // "Établissement de cette déclaration d'accessibilité") <> "</h3>"
         , p (t ("Established on " // "Cette déclaration a été établie le ") <> field ("date of publication" // "date de publication") <> t ("." // "."))
         , "<ul>"
         , "<li>" <> t ("Technologies the site relies on: " // "Technologies utilisées pour la réalisation du site : ") <> field ("HTML, CSS, JavaScript, as the case may be" // "HTML, CSS, JavaScript, selon le cas") <> "</li>"
         , "<li>" <> t ("Test environment: " // "Environnement de test : ") <> esc (T.intercalate ", " (nub (mapMaybe browser bodies)))
           <> t (", at 1280 px and 320 px wide, then by keyboard alone" // ", à 1280 px et 320 px de large, puis au clavier seul")
           <> t (case nub (mapMaybe from bodies) of [cc] -> let Phrase e f = country cc in Phrase (", from " <> e) (", depuis " <> f); _ -> "") <> "</li>"
         , "<li>" <> t ("Tools: relevé " // "Outils : relevé ") <> esc release <> t (", criteria v" // ", critères v") <> esc version <> t (", and " // ", et ") <> field ("the tools and assistive technologies of the complete evaluation" // "les outils et technologies d'assistance de l'évaluation complète") <> "</li>"
         , "<li>" <> t ("Pages observed:" // "Pages observées :") <> "<ul>" <> T.concat [ "<li><a href=\"" <> esc (url b) <> "\">" <> esc (url b) <> "</a></li>" | b <- bodies ] <> "</ul></li>"
         , "</ul>"
         , "<h3>" <> t ("Feedback and contact" // "Retour d'information et contact") <> "</h3>"
         , p (t ("If you cannot reach a content or a service, contact " // "Si vous n'arrivez pas à accéder à un contenu ou à un service, vous pouvez contacter ") <> field ("the person in charge, by email address or form" // "le responsable, par adresse électronique ou formulaire")
              <> t (", to be directed to an accessible alternative or to obtain the content in another form." // ", pour être orienté vers une alternative accessible ou obtenir le contenu sous une autre forme."))
         , "<h3>" <> t ("Remedies" // "Voies de recours") <> "</h3>"
         , p (t ("If you have reported to the person in charge an accessibility defect that keeps you from a content or a service, and have not had a satisfactory answer, you can:"
                 // "Cette procédure est à utiliser dans le cas suivant : vous avez signalé au responsable du site internet un défaut d'accessibilité qui vous empêche d'accéder à un contenu ou à un des services, et vous n'avez pas obtenu de réponse satisfaisante. Vous pouvez :"))
         , "<ul>"
         , "<li>" <> t ("write to the Défenseur des droits: " // "écrire un message au Défenseur des droits : ") <> "<a href=\"https://formulaire.defenseurdesdroits.fr/\">formulaire.defenseurdesdroits.fr</a></li>"
         , "<li>" <> t ("contact the delegate of the Défenseur des droits in your region: " // "contacter le délégué du Défenseur des droits dans votre région : ") <> "<a href=\"https://www.defenseurdesdroits.fr/saisir/delegues\">defenseurdesdroits.fr/saisir/delegues</a></li>"
         , "<li>" <> t ("send a letter, free of charge, without a stamp: Défenseur des droits, Libre réponse 71120, 75342 Paris CEDEX 07." // "envoyer un courrier par la poste, gratuit, sans timbre : Défenseur des droits, Libre réponse 71120, 75342 Paris CEDEX 07.") <> "</li>"
         , "</ul>" ]

    -- The eco-design declaration: each of the 78 criteria, read by rule on the pages or declared by the owner.
    said = declared st
    byRule x = [ c | c <- criteria, x `elem` cites "RGESN" c ]
    ruled x = case byRule x of
      [] -> Nothing
      cs -> let worst v = sum [tally v c | c <- cs]
            in Just $ if worst Fail > 0 then (Fail, t ("by rule: not met on " // "par règle : non tenu sur ") <> t (ofPages (maximum [tally Fail c | c <- cs])))
                      else if worst Review > 0 then (Review, t ("by rule: left to the reviewer on " // "par règle : laissé au relecteur sur ") <> t (ofPages (maximum [tally Review c | c <- cs])))
                      else if all (\c -> tally NA c == n) cs then (NA, t ("by rule: nothing to judge on the pages observed" // "par règle : rien à juger sur les pages observées"))
                      else (Pass, t ("by rule: held on the " // "par règle : tenu sur les ") <> t (both (num n) <> (" pages observed" // " pages observées")))
    owned x = case M.lookup ("RGESN " <> x) said of
      Just d -> Just (dAnswer d, t (case dAnswer d of "yes" -> "declared: yes" // "déclaré : oui"; "no" -> "declared: no" // "déclaré : non"; "n/a" -> "declared: not applicable" // "déclaré : sans objet"; _ -> "declared: open" // "déclaré : ouvert")
                                   <> maybe "" (\note -> " · <em>" <> esc note <> "</em>") (dNote d))
      Nothing | any (\i -> iRef i == "RGESN" && iId i == x) items -> Just ("open", field ("to declare" // "à déclarer"))
      Nothing -> Nothing
    line x = "<li><a href=\"https://ecoresponsable.numerique.gouv.fr/publications/referentiel-general-ecoconception/critere/" <> x <> "/\">RGESN " <> x <> "</a> · "
             <> (case [s | Just (_, s) <- [ruled x]] ++ [s | Just (_, s) <- [owned x]] of [] -> t ("not addressed" // "non traité"); xs -> T.intercalate " · " xs) <> "</li>"
    families = [ ("Strategy" // "Stratégie"), ("Specifications" // "Spécifications"), ("Architecture" // "Architecture"), ("Interface" // "UX/UI"), ("Content" // "Contenus")
               , ("Front end" // "Frontend"), ("Back end" // "Backend"), ("Hosting" // "Hébergement"), ("Algorithms" // "Algorithmie") ]
    inFamily k = [ x | x <- rgesn, T.takeWhile (/= '.') x == num k ]
    rules' = [ v | x <- rgesn, Just (v, _) <- [ruled x] ]
    owners = [ a | x <- rgesn, Just (a, _) <- [owned x] ]
    count' v xs = length (filter (== v) xs)
    ecodesign =
      [ "<h2>" <> t ("Eco-design declaration" // "Déclaration d'écoconception") <> "</h2>"
      , p (field ("Name of the entity" // "Nom de l'entité") <> t (" declares how " // " déclare comment ") <> esc site
           <> t (" answers the 78 criteria of the RGESN 2024, the general referential for the eco-design of digital services. Person in charge of eco-design: "
                 // " répond aux 78 critères du RGESN 2024, le référentiel général d'écoconception de services numériques. Référent écoconception : ")
           <> field ("name and contact" // "nom et contact") <> t (". Objectives: " // ". Objectifs : ") <> field ("what the service sets out to reduce, and by when" // "ce que le service entend réduire, et à quelle échéance") <> t ("." // "."))
      , p ("<strong>" <> t (both (num (length rules')) <> (" criteria read by rule: " // " critères lus par règle : ")) <> T.intercalate ", "
             [ t (both (num (count' v rules')) <> w) | (v, w) <- [(Pass, " held" // " tenus"), (Fail, " not met on some pages" // " non tenus sur certaines pages"), (Review, " left to the reviewer" // " laissés au relecteur"), (NA, " with nothing to judge" // " sans objet constaté")], count' v rules' > 0 ]
           <> t (". " // ". ") <> t (both (num (length owners)) <> (" for the owner to declare: " // " à déclarer par le responsable : ")) <> T.intercalate ", "
             [ t (both (num (count' a owners)) <> w) | (a, w) <- [("yes", " yes" // " oui"), ("no", " no" // " non"), ("n/a", " not applicable" // " sans objet"), ("open", " still open" // " encore ouverts")], count' a owners > 0 ]
           <> t ("." // ".") <> "</strong>")
      , p (t ("A criterion held by rule holds on the pages observed, by the rule's reading of it; the criterion may ask more. The official text prevails."
              // "Un critère tenu par règle l'est sur les pages observées, selon la lecture qu'en fait la règle ; le critère peut demander davantage. Le texte officiel prévaut.")) ]
      ++ concat [ ["<h3>" <> t f <> "</h3>", "<ul>"] ++ map line (inFamily k) ++ ["</ul>"] | (k, f) <- zip [1 :: Int ..] families ]
