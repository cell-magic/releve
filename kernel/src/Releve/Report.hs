-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
{-# LANGUAGE OverloadedStrings #-}
-- | The report: the latest reading of each page, as a document for the
--   person whose pages they are. One HTML page, without script, in the
--   language asked for. Method before findings; a finding with its remedy;
--   the lightest work first; and what was not looked at, said plainly.
module Releve.Report (report, guide, typography, touched) where

import Data.Char (isDigit)
import Data.List (nub, sortOn)
import Data.Maybe (listToMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Releve.Criteria (criteria, version)
import Releve.Footprint
import Releve.Kernel
import Releve.Reading
import Releve.Types

-- | A report on the latest observation of every page of the corpus.
report :: Lang -> Text -> State -> Text
report l release st = T.unlines $
  [ "<!doctype html>", "<html lang=\"" <> (if l == En then "en" else "fr") <> "\">", "<head>", "<meta charset=\"utf-8\">"
  , "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
  , "<title>" <> esc (heading') <> "</title>", "<style>", style, "</style>", "</head>", "<body>", "<main>"
  , "<h1>" <> esc heading' <> "</h1>"
  , p (t ((if single then "Automated observation of one rendered page" else "Automated observation of " <> num (length pages) <> " rendered pages")
           <> ", by rule. It is not a conformity audit: a rule decides what a rule can, and puts the rest to a person."
          // (if single then "Observation automatisée d'une page rendue" else "Observation automatisée de " <> num (length pages) <> " pages rendues")
           <> ", par des règles. Ce n'est pas un audit de conformité : une règle tranche ce qu'une règle peut trancher, et soumet le reste à une personne."))
  , "<h2>" <> t ("Method" // "Méthode") <> "</h2>"
  , p (t ("A browser opened each page as a reader's would, at 1280 px and again at 320 px, and recorded what it showed: the names assistive technology is given, the colours as rendered, the bytes that travelled. "
          // "Un navigateur a ouvert chaque page comme le ferait celui d'un lecteur, à 1280 px puis à 320 px, et a consigné ce qu'elle montrait : les noms donnés aux technologies d'assistance, les couleurs telles que rendues, les octets transférés. ")
       <> esc (num (length criteria)) <> t (" criteria then read that record. Each is a rule in plain code; no trained model takes part, so the same record gives the same report."
          // " critères ont ensuite lu ce relevé. Chacun est une règle en code clair ; aucun modèle entraîné n'intervient, de sorte que le même relevé donne le même rapport."))
  , "<dl>"
  , dt ("To mend" // "À corriger") <> dd ("a stated rule is broken; the remedy is given." // "une règle énoncée n'est pas respectée ; le remède est indiqué.")
  , dt ("To check" // "À vérifier") <> dd ("the rule has found what only a person can decide, and shows it." // "la règle a trouvé ce que seule une personne peut trancher, et le montre.")
  , dt ("Could be lighter" // "Pourrait être allégé") <> dd ("nothing is broken; fewer bytes would do the same." // "rien n'est enfreint ; moins d'octets feraient autant.")
  , "</dl>"
  ]
  ++ (if length pages > 1 then overview else [])
  ++ concatMap page' (zip [1 ..] pages)
  ++ [ "<h2>" <> t ("What was not looked at" // "Ce qui n'a pas été regardé") <> "</h2>"
     , p (t ("These rules touch " <> num (length (touched "RGAA")) <> " of the 106 criteria of the RGAA 4.1.2, " <> num (length (touched "RGESN")) <> " of the 78 of the RGESN 2024, and "
              <> num (length (touched "art.")) <> " paragraphs of article 50 of the AI Act. To touch a criterion is not to settle it: most ask for a person's judgement, or for a declaration of the owner's, beyond what a rule can see."
            // "Ces règles touchent " <> num (length (touched "RGAA")) <> " des 106 critères du RGAA 4.1.2, " <> num (length (touched "RGESN")) <> " des 78 du RGESN 2024, et "
              <> num (length (touched "art.")) <> " paragraphes de l'article 50 du règlement sur l'IA. Toucher un critère n'est pas le solder : la plupart demandent le jugement d'une personne, ou une déclaration du responsable du site, au-delà de ce qu'une règle peut voir."))
     , p (t ("One page was observed at one moment and at two widths. What appears only after an action (a menu opened, a form sent, a dialogue), what stands behind a login, and what lies inside frames from other sites were not observed."
            // "Une page a été observée à un moment donné et à deux largeurs. Ce qui n'apparaît qu'après une action (un menu ouvert, un formulaire envoyé, une boîte de dialogue), ce qui se trouve derrière une connexion, et ce que contiennent les cadres venus d'autres sites n'ont pas été observés."))
     , "<p class=\"meta\">relevé " <> esc release <> " · " <> t ("criteria v" // "critères v") <> esc version <> "</p>"
     , "</main>", "</body>", "</html>" ]
  where
    t = esc . typography l . say l
    p x = "<p>" <> x <> "</p>"
    dt x = "<dt>" <> t x <> "</dt>"
    dd x = "<dd>" <> t x <> "</dd>"
    pages = latest st
    single = length pages == 1
    heading' = case pages of
      [o] -> "Relevé · " <> url (oBody o)
      _ -> "Relevé · " <> say l (num (length pages) <> " pages" // num (length pages) <> " pages")
    hd :: Int -> Text -> Text
    hd n x = let k = num (if single then n else n + 1) in "<h" <> k <> ">" <> x <> "</h" <> k <> ">"

    overview =
      [ "<h2>" <> t ("The pages" // "Les pages") <> "</h2>", "<table>"
      , "<thead><tr><th scope=\"col\">" <> t ("Page" // "Page") <> "</th><th scope=\"col\">" <> t ("To mend" // "À corriger") <> "</th><th scope=\"col\">"
          <> t ("To check" // "À vérifier") <> "</th><th scope=\"col\">" <> t ("Lighter" // "À alléger") <> "</th></tr></thead>", "<tbody>" ]
      ++ [ "<tr><th scope=\"row\"><a href=\"#p" <> num i <> "\">" <> esc (url (oBody o)) <> "</a></th>" <> T.concat ["<td>" <> num (count v fs) <> "</td>" | v <- [Fail, Review, Hint]] <> "</tr>"
         | (i, o) <- zip [1 :: Int ..] pages, let fs = assess st o ]
      ++ ["</tbody>", "</table>"]

    count v fs = length [() | f <- fs, fVerdict f == v]

    page' :: (Int, Obs) -> [Text]
    page' (i, o) = let b = oBody o; fs = assess st o in
      [ if single then "" else "<h2 id=\"p" <> num i <> "\">" <> esc (url b) <> "</h2>"
      , "<p class=\"meta\">" <> t ("Observed on " // "Observée le ") <> esc (date l (at b)) <> maybe "" ((" · " <>) . esc) (browser b)
          <> (if truncated (page b) == Just True then t (" · page too large: only its first surfaces were read" // " · page trop grande : seules ses premières surfaces ont été lues") else "") <> "</p>"
      , p ("<strong>" <> T.intercalate " · "
            [ esc (num (count Fail fs)) <> " " <> t ("to mend" // "à corriger"), esc (num (count Review fs)) <> " " <> t ("to check" // "à vérifier")
            , esc (num (count Hint fs)) <> " " <> t ("could be lighter" // "à alléger"), esc (num (count Pass fs)) <> " " <> t ("checks pass" // "contrôles passent") ] <> "</strong>"
           <> since o fs) ]
      ++ concat [ group n title fs v | (n, title, v) <- [ (2 :: Int, "To mend" // "À corriger", Fail), (2, "To check" // "À vérifier", Review), (2, "Could be lighter" // "Pourrait être allégé", Hint) ] ]
      ++ [ hd 2 (t ("Criterion by criterion" // "Critère par critère")), "<ul>" ]
      ++ [ "<li>" <> t (cTitle c) <> " · " <> summary [f | f <- fs, cId (fCrit f) == cId c] <> "</li>" | c <- criteria ]
      ++ [ "</ul>", hd 2 (t ("Footprint" // "Empreinte")) ]
      ++ weight b
      ++ maybe [] (lecture b) (readingOf b fs)

    since o fs = case previous st o of
      [] -> ""
      (q : _) ->
        let open f = fVerdict f `elem` [Fail, Review, Hint]
            was = [fId f | f <- assess st q, open f]
            now = [fId f | f <- fs, open f]
        in "<br>" <> t ("Since the observation of " // "Depuis l'observation du ") <> esc (date l (at (oBody q))) <> t (": " // " : ")
             <> esc (num (length [x | x <- was, x `notElem` now])) <> t (" no longer found, " // " ne sont plus constatés, ")
             <> esc (num (length [x | x <- now, x `notElem` was])) <> t (" new, " // " nouveaux, ")
             <> esc (num (length [x | x <- now, x `elem` was])) <> t (" standing." // " persistent.")

    -- Within a verdict: the lightest work first, then the order of the criteria.
    group n title fs v = case [f | f <- fs, fVerdict f == v] of
      [] -> []
      xs -> hd n (t title <> " (" <> num (length xs) <> ")")
        : concat [ criterion (n + 1) c [f | f <- xs, cId (fCrit f) == cId c] | c <- sortOn cEffort criteria, any ((== cId c) . cId . fCrit) xs ]

    criterion n c xs =
      [ hd n (t (cTitle c))
      , "<p>" <> t (cWhy c) <> " <span class=\"meta\">" <> t (cRef c) <> " · " <> t (effort (cEffort c)) <> "</span></p>"
      , "<ul>" ]
      ++ [ "<li>" <> t (fSeen f) <> maybe "" (\ch -> "<br><strong>" <> t ("Change: " // "À changer : ") <> "</strong>" <> t ch) (fChange f)
             <> maybe "" (\s -> "<br><code>" <> esc (sel s) <> "</code>") (fSurface f)
             <> (if fNew f then " · " <> t ("new" // "nouveau") else "")
             <> (if fAge f > 0 then " · " <> t ("standing through " <> num (fAge f) <> (if fAge f == 1 then " observation" else " observations") // "persiste depuis " <> num (fAge f) <> (if fAge f == 1 then " observation" else " observations")) else "")
             <> maybe "" (\x -> "<br><em>" <> esc x <> "</em>") (fNote f)
             <> "</li>"
         | f <- sortOn (maybe 0 order . fSurface) xs ]
      ++ ["</ul>"]

    effort Light = "light work" // "travail léger"
    effort Medium = "some work" // "travail moyen"
    effort Heavy = "heavy work" // "travail lourd"

    summary xs
      | all ((== NA) . fVerdict) xs = t ("nothing to judge: " // "rien à juger : ") <> maybe "" (t . fSeen) (listToMaybe xs)
      | otherwise = esc (num (length [f | f <- xs, fVerdict f == Pass])) <> t (" of " // " sur ") <> esc (num (length [f | f <- xs, fVerdict f /= NA])) <> t (" pass" // " passent")

    -- The reading: a measure set apart from the verdicts.
    lecture b r =
      [ hd 2 (t ("The reading" // "La lecture"))
      , p (t ("A measure, not a verdict. The page gives its reader " <> things (rEvents r) <> " to take in. Its markup says which of them can be taken independently: a heading opens a section, a list holds items, a table's headers free its cells. What it does not declare independent has to be taken in order."
              // "Une mesure, pas un verdict. La page donne à son lecteur " <> choses (rEvents r) <> " à saisir. Son balisage dit lesquelles se saisissent indépendamment : un titre ouvre une section, une liste porte des éléments, les en-têtes d'un tableau libèrent ses cellules. Ce qu'il ne déclare pas indépendant se prend dans l'ordre."))
      , "<dl>"
      , dt ("Shown and not said" // "Montré et non dit") <> dd (num (rUnsaid r) <> ": what the eye is given and assistive technology is not." // num (rUnsaid r) <> " : ce qui est donné à l'œil et non aux technologies d'assistance.")
      , dt ("Said and not shown" // "Dit et non montré") <> dd (num (rUnshown r) <> ": what is given to assistive technology alone, such as a link past the menu." // num (rUnshown r) <> " : ce qui n'est donné qu'aux technologies d'assistance, tel un lien d'évitement.")
      , dt ("Depth" // "Profondeur") <> dd (num (rDepth r) <> ": the longest run the markup obliges. Without structure it would be " <> num (rEvents r) <> "."
                                           // num (rDepth r) <> " : la plus longue suite que le balisage impose. Sans structure, elle vaudrait " <> num (rEvents r) <> ".")
      , dt ("One at a time, by ear" // "Un à la fois, à l'oreille") <> dd (steps' (rSerial r) <> ": each thing that is said, one after the other." // etapes (rSerial r) <> " : chaque chose dite, l'une après l'autre.")
      , dt ("Up to " <> num ceiling' <> " at a time" // "Jusqu'à " <> num ceiling' <> " à la fois")
          <> dd (steps' (rSteps r) <> " as the page stands; " <> num (rClear r) <> " with nothing failing. A page of this size and depth takes between " <> num (rLower r) <> " and " <> num (rUpper r) <> "."
                 // etapes (rSteps r) <> " en l'état ; " <> num (rClear r) <> " si rien n'échouait. Une page de cette taille et de cette profondeur en demande entre " <> num (rLower r) <> " et " <> num (rUpper r) <> ".")
      , dt ("What the page says" // "Ce que dit la page")
          <> dd (let said = max 1 (round (rBits r / 8)) :: Int; each = transfer (network b) `div` said
                 in num said <> " bytes of text, by an estimate; " <> num each <> " bytes travel for each." // num said <> " octets de texte, par estimation ; " <> num each <> " octets voyagent pour chacun.")
      , "</dl>" ]
      ++ [ p (T.intercalate " " [ t ("Mending “" // "Corriger « ") <> t (title' c) <> t ("” alone gives back " <> steps' k <> "." // " » seul rend " <> etapes k <> ".") | (c, k) <- rReturns r ]) | not (null (rReturns r)) ]
      ++ [ "<p class=\"meta\">" <> t ("The reader who holds up to " <> num ceiling' <> " is a convention, as a reference device is in a test of speed: it takes what comes first on the page, and fewer things at once where the page fails them."
              // "Le lecteur qui en saisit jusqu'à " <> num ceiling' <> " est une convention, comme l'appareil de référence d'un essai de vitesse : il prend ce qui vient en premier dans la page, et moins de choses à la fois là où la page lui fait défaut.") <> "</p>" ]
      where
        things n = num n <> (if n == 1 then " thing" else " things")
        choses n = num n <> (if n == 1 then " chose" else " choses")
        steps' n = num n <> (if n == 1 then " step" else " steps")
        etapes n = num n <> (if n == 1 then " étape" else " étapes")
        title' c = maybe (both c) cTitle (listToMaybe [k | k <- criteria, cId k == c])

    weight b = let Footprint e r kb hs = footprint b in
      [ "<p>" <> esc (num e) <> " " <> t ("elements in the document" // "éléments dans le document") <> " · " <> esc (num r) <> " " <> t ("requests" // "requêtes") <> " · "
          <> esc (num (round kb :: Int)) <> " " <> t ("kB transferred" // "ko transférés") <> " · " <> esc (num (length hs)) <> " " <> t ("third-party hosts" // "hôtes tiers")
          <> (if null hs then "" else " (" <> esc (T.intercalate ", " hs) <> ")") <> "</p>" ]

-- | The criteria, each with what it is for: the same words the report uses,
--   on one page, for whoever wants to know what is read before asking.
guide :: Lang -> Text -> Text
guide l release = T.unlines $
  [ "<!doctype html>", "<html lang=\"" <> (if l == En then "en" else "fr") <> "\">", "<head>", "<meta charset=\"utf-8\">"
  , "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
  , "<title>" <> t ("relevé · the criteria" // "relevé · les critères") <> "</title>", "<style>", style, "</style>", "</head>", "<body>", "<main>"
  , "<h1>" <> t ("The criteria" // "Les critères") <> "</h1>"
  , "<p>" <> t (num (length criteria) <> " rules, each in plain code. For each: what it checks, what that is for, and the text it comes from. They touch "
                <> num (length (touched "RGAA")) <> " of the 106 criteria of the RGAA 4.1.2, " <> num (length (touched "RGESN")) <> " of the 78 of the RGESN 2024, and "
                <> num (length (touched "art.")) <> " paragraphs of article 50 of the AI Act."
                // num (length criteria) <> " règles, chacune en code clair. Pour chacune : ce qu'elle vérifie, à quoi cela sert, et le texte dont elle vient. Elles touchent "
                <> num (length (touched "RGAA")) <> " des 106 critères du RGAA 4.1.2, " <> num (length (touched "RGESN")) <> " des 78 du RGESN 2024, et "
                <> num (length (touched "art.")) <> " paragraphes de l'article 50 du règlement sur l'IA.") <> "</p>" ]
  ++ concat [ [ "<h2 id=\"" <> cId c <> "\">" <> t (cTitle c) <> "</h2>", "<p>" <> t (cWhy c) <> "</p>"
              , "<p class=\"meta\">" <> t (cRef c) <> " · <code>" <> cId c <> "</code></p>" ] | c <- criteria ]
  ++ [ "<p class=\"meta\">relevé " <> esc release <> " · " <> t ("criteria v" // "critères v") <> esc version <> "</p>", "</main>", "</body>", "</html>" ]
  where t = esc . typography l . say l

num :: Int -> Text
num = T.pack . show

-- | The criteria of one reference that the rules touch, from the sources they
--   state: the numbers that follow its name, a span counted whole.
touched :: Text -> [Text]
touched ref = nub (concatMap (spans . drop 1 . dropWhile (/= ref) . T.words . en . cRef) criteria)
  where
    spans = concatMap range . takeWhile numbered . filter (/= "·")
    numbered w = T.any isDigit (T.take 1 w)
    range w = case T.splitOn "–" w of
      [a, b] | [ta, na] <- T.splitOn "." a, [_, nb] <- T.splitOn "." b, Just x <- int' na, Just y <- int' nb -> [ta <> "." <> num k | k <- [x .. y]]
      _ -> [w]
    int' x = case reads (T.unpack x) :: [(Int, String)] of [(k, "")] -> Just k; _ -> Nothing

-- | A day and a time, in words, from an ISO 8601 instant.
date :: Lang -> Text -> Text
date l iso = case (T.splitOn "-" (T.take 10 iso), T.take 5 (T.drop 11 iso)) of
  ([y, m, d], hm) | Just k <- lookup m (zip months [0 :: Int ..]) ->
    T.dropWhile (== '0') d <> (if l == Fr && d == "01" then "er " else " ") <> (if l == En then en' !! k else fr' !! k) <> " " <> y <> ", " <> hm <> " UTC"
  _ -> iso
  where
    months = ["01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12"]
    en' = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    fr' = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]

-- | French sets a thin space before ; ! ? and inside « », a space that does
--   not break before a colon. English is left as written.
typography :: Lang -> Text -> Text
typography En = id
typography Fr = T.replace " :" "\x00a0:" . T.replace "« " "«\x202f" . foldr (.) id [T.replace (" " <> c) ("\x202f" <> c) | c <- [";", "!", "?", "»"]]

esc :: Text -> Text
esc = T.concatMap $ \c -> case c of
  '&' -> "&amp;"; '<' -> "&lt;"; '>' -> "&gt;"; '"' -> "&quot;"; _ -> T.singleton c

-- | Ink on paper, one column, nothing fetched.
style :: Text
style = T.unlines
  [ "html { color: #1a1a1a; background: #fff; }"
  , "body { margin: 0; font: 1rem/1.6 system-ui, sans-serif; }"
  , "main { max-width: 42rem; margin: 0 auto; padding: 1rem 1rem 4rem; }"
  , "h1, h2, h3, h4 { line-height: 1.25; font-weight: 600; }"
  , "h1 { font-size: 1.75rem; overflow-wrap: anywhere; } h2 { font-size: 1.375rem; margin-top: 2.5rem; overflow-wrap: anywhere; } h3 { font-size: 1.125rem; margin-top: 2rem; } h4 { font-size: 1rem; margin-top: 1.5rem; }"
  , "a { color: #1f3a8a; } a:focus-visible { outline: 2px solid #1f3a8a; outline-offset: 2px; }"
  , "li { margin-bottom: .6rem; overflow-wrap: anywhere; }"
  , "code { font: .875rem/1.4 ui-monospace, monospace; color: #5c6066; }"
  , ".meta { color: #5c6066; font-size: .9375rem; }"
  , "dt { font-weight: 600; } dd { margin: 0 0 .5rem; }"
  , "table { border-collapse: collapse; width: 100%; } th, td { text-align: left; padding: .4rem .5rem .4rem 0; border-bottom: 1px solid #c8cacd; overflow-wrap: anywhere; } tbody th { font-weight: normal; }" ]
