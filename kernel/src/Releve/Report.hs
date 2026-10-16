-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
{-# LANGUAGE OverloadedStrings #-}
-- | The report: the latest reading of each page, as a document for the
--   person whose pages they are. One HTML page, without script, in the
--   language asked for. Method before findings; a finding with its remedy;
--   the lightest work first; and what was not looked at, said plainly.
module Releve.Report (report, guide, typography, reach) where

import Data.Char (isAlphaNum, isAsciiLower)
import Data.List (find, nub, sortOn)
import Data.Maybe (listToMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Releve.Criteria (criteria, version)
import Releve.Declarations
import qualified Data.Map.Strict as M
import Releve.Footprint
import Releve.Frameworks
import Releve.Kernel
import Releve.Reading
import Releve.Types

-- | A report on the latest observation of every page of the corpus. Asking,
--   each point to decide that the rule left to a person comes with its question
--   and the controls to answer it, for a form around the report to send back.
report :: Lang -> Bool -> Text -> State -> Text
report l asking release st = T.unlines $
  [ "<!doctype html>", "<html lang=\"" <> (if l == En then "en" else "fr") <> "\">", "<head>", "<meta charset=\"utf-8\">"
  , "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
  , "<title>" <> esc (heading') <> "</title>", "<style>", style, "</style>", "</head>", "<body>", "<main>"
  , "<h1>" <> esc heading' <> "</h1>"
  , p (t ((if single then "Automated observation of one rendered page" else "Automated observation of " <> num (length pages) <> " rendered pages")
           <> ", by rule. It is not a conformity audit. What no rule can decide is listed as an open question."
          // (if single then "Observation automatisée d'une page rendue" else "Observation automatisée de " <> num (length pages) <> " pages rendues")
           <> ", par des règles. Ce n'est pas un audit de conformité. Ce qu'aucune règle ne peut trancher figure en question ouverte."))
  , "<h2>" <> t ("Method" // "Méthode") <> "</h2>"
  , p (t ("Each page was rendered in a browser at 1280 px and 320 px. Recorded: names given to assistive technology, colors as rendered, bytes transferred. "
          // "Chaque page a été rendue dans un navigateur à 1280 px et 320 px. Relevés : noms donnés aux technologies d'assistance, couleurs rendues, octets transférés. ")
       <> t ("The page was then navigated by keyboard alone. "
          // "La page a ensuite été parcourue au clavier seul. ")
       <> esc (num (length criteria)) <> t (" criteria then read the record. Each is a rule in plain code. No trained model is involved: the same record gives the same report."
          // " critères ont ensuite lu le relevé. Chacun est une règle en code clair. Aucun modèle entraîné n'intervient : le même relevé donne le même rapport."))
  , "<dl>"
  , dt ("Fixes" // "Corrections") <> dd ("A stated rule is broken. The remedy is given." // "Une règle énoncée n'est pas respectée. Le remède est indiqué.")
  , dt ("Open questions" // "Questions ouvertes") <> dd ("Beyond what a rule can decide. Answers are recorded as the reviewer's, beside the rule's reading, and lapse when the element changes."
                                                       // "Au-delà de ce qu'une règle peut trancher. Les réponses sont consignées comme celles du relecteur, à côté de la lecture de la règle, et tombent quand l'élément change.")
  , dt ("Lighter options" // "Allègements") <> dd ("Nothing is broken. Fewer bytes would do the same." // "Rien n'est enfreint. Moins d'octets feraient autant.")
  , "</dl>"
  ]
  ++ (if length pages > 1 then overview else [])
  ++ whole
  ++ concatMap page' (zip [1 ..] pages)
  ++ statement
  ++ [ "<h2>" <> t ("What was not looked at" // "Ce qui n'a pas été regardé") <> "</h2>"
     , p (t ("These rules touch " <> num (length (touched "RGAA")) <> " of the 106 criteria of the RGAA 4.1.2, " <> num (length (touched "RGESN")) <> " of the 78 of the RGESN 2024, and "
              <> num (length (touched "art.")) <> " paragraphs of article 50 of the AI Act. The other " <> num (length [i | i <- items, iRef i == "RGESN"]) <> " RGESN criteria, the "
              <> num (length [i | i <- items, iRef i == "RGAA"]) <> " RGAA criteria on the set of pages and " <> num (length [i | i <- items, iRef i == "AI Act"])
              <> " paragraphs of article 50, for what no page shows, and " <> num (length others) <> " provisions of other laws and standards are declared by the owner; " <> num (M.size (declared st)) <> " are declared so far. " <> unbound En
            // "Ces règles touchent " <> num (length (touched "RGAA")) <> " des 106 critères du RGAA 4.1.2, " <> num (length (touched "RGESN")) <> " des 78 du RGESN 2024, et "
              <> num (length (touched "art.")) <> " paragraphes de l'article 50 du règlement sur l'IA. Les " <> num (length [i | i <- items, iRef i == "RGESN"]) <> " autres critères du RGESN, les "
              <> num (length [i | i <- items, iRef i == "RGAA"]) <> " critères du RGAA portant sur l'ensemble des pages et " <> num (length [i | i <- items, iRef i == "AI Act"])
              <> " paragraphes de l'article 50, pour ce qu'aucune page ne montre, et " <> num (length others) <> " dispositions d'autres lois et normes sont déclarés par le responsable ; " <> num (M.size (declared st)) <> " le sont à ce jour. " <> unbound Fr))
     , p (t ("Each page was observed once, at two widths. Not observed: content shown only after an action, such as an open menu, a sent form or a dialog; content behind a login; frames from other sites."
            // "Chaque page a été observée une fois, à deux largeurs. Non observés : ce qui n'apparaît qu'après une action, comme un menu ouvert, un formulaire envoyé ou une boîte de dialogue ; ce qui est derrière une connexion ; les cadres d'autres sites."))
     , "<p class=\"meta\">relevé " <> esc release <> " · " <> t ("criteria v" // "critères v") <> esc version <> "</p>"
     , "</main>", "</body>", "</html>" ]
  where
    t = codify . typography l . say l
    p x = "<p>" <> x <> "</p>"
    others = [i | i <- items, iRef i `notElem` ["RGESN", "RGAA", "AI Act"]]
    dt x = "<dt>" <> t x <> "</dt>"
    dd x = "<dd>" <> t x <> "</dd>"
    pages = latest st
    single = length pages == 1
    heading' = case pages of
      [o] -> say l ("Report · " // "État des lieux · ") <> url (oBody o)
      _ -> say l ("Report · " <> num (length pages) <> " pages" // "État des lieux · " <> num (length pages) <> " pages")
    hd :: Int -> Text -> Text
    hd n x = let k = num (if single then n else n + 1) in "<h" <> k <> ">" <> x <> "</h" <> k <> ">"

    overview =
      [ "<h2>" <> t ("The pages" // "Les pages") <> "</h2>", "<table>"
      , "<thead><tr><th scope=\"col\">" <> t ("Page" // "Page") <> "</th><th scope=\"col\">" <> t ("Fixes" // "Corrections") <> "</th><th scope=\"col\">"
          <> t ("Questions" // "Questions") <> "</th><th scope=\"col\">" <> t ("Lighter" // "Allègements") <> "</th></tr></thead>", "<tbody>" ]
      ++ [ "<tr><th scope=\"row\"><a href=\"#p" <> num i <> "\">" <> esc (url (oBody o)) <> "</a></th>" <> T.concat ["<td>" <> num (count v fs) <> "</td>" | v <- [Fail, Review, Hint]] <> "</tr>"
         | (i, o) <- zip [1 :: Int ..] pages, let fs = own o (assess st o) ]
      ++ ["</tbody>", "</table>"]
      ++ [ p (t (num (length ps) <> (if length ps == 1 then " question is" else " questions are") <> " asked once for pages that share a template: "
                 // num (length ps) <> (if length ps == 1 then " question est posée" else " questions sont posées") <> " une fois pour les pages qui partagent un gabarit : ")
              <> "<a href=\"#site\">" <> t ("the whole site" // "tout le site") <> "</a>" <> t ("." // ".")) | not (null ps) ]

    -- Questions asked of the page as a whole, once for the pages built on the same template.
    ps = pools st
    pooledHere o = [fId f | q <- ps, (x, f) <- pEntries q, oId x == oId o]
    own o fs = [f | f <- fs, fId f `notElem` pooledHere o]
    pageNo o = maybe "" num (lookup (oId o) (zip (map oId pages) [1 :: Int ..]))
    whole = case nub (map pKey ps) of
      [] -> []
      ks -> [ hd 1 ("<span id=\"site\">" <> t ("The whole site" // "Tout le site") <> "</span>")
            , p (t ("Questions asked of the page as a whole come back word for word on pages built on the same style sheets and scripts. They are asked here once. "
                    <> "An answer holds on the pages counted with it while they keep that template; a page that changes it, or a page first seen later, is asked again."
                    // "Les questions posées sur la page entière reviennent mot pour mot sur les pages bâties sur les mêmes feuilles de styles et scripts. Elles sont posées ici une fois. "
                    <> "Une réponse vaut pour les pages comptées avec elle tant qu'elles gardent ce gabarit ; une page qui en change, ou vue pour la première fois plus tard, est interrogée à nouveau.")) ]
            ++ concatMap (template' (length ks > 1)) ks
            ++ (if asking && any (\q -> poolVerdict q == Review) ps then [p ("<button type=\"submit\">" <> t ("Submit answers" // "Envoyer les réponses") <> "</button>")] else [])
    poolVerdict q = case nub [(fVerdict f, fNote f) | (_, f) <- pEntries q] of
      [(v, _)] -> v
      _ -> Review
    template' several k =
      let mine = [q | q <- ps, pKey q == k]
          os = [o | o <- pages, oId o `elem` [oId x | q <- mine, (x, _) <- pEntries q]]
          open' = [q | q <- mine, poolVerdict q == Review]
          done = [q | q <- mine, poolVerdict q /= Review]
          link' o = "<a href=\"#p" <> pageNo o <> "\">" <> esc (url (oBody o)) <> "</a>"
      in [ hd 2 (esc (maybe "" pHost (listToMaybe mine)) <> " · " <> t (num (length os) <> " pages" // num (length os) <> " pages")
                 <> (if several then " · " <> t ("template " // "gabarit ") <> "<code>" <> esc k <> "</code>" else ""))
         , "<p class=\"meta\">" <> T.intercalate ", " (map link' os) <> "</p>" ]
         ++ (if null open' then [] else [hd 3 (t ("Open questions" // "Questions ouvertes") <> " (" <> num (length open') <> ")"), "<ul>"] ++ map (poolItem os) open' ++ ["</ul>"])
         ++ (if null done then [] else [hd 3 (t ("Answered for these pages" // "Répondu pour ces pages") <> " (" <> num (length done) <> ")"), "<ul>"] ++ map (poolItem os) done ++ ["</ul>"])
    poolItem os q =
      let f = pFinding q
          c = fCrit f
          v = poolVerdict q
          n = case nub [fNote g | (_, g) <- pEntries q] of [x] -> x; _ -> Nothing
          count' = length (pEntries q)
          which = if count' < length os then " (" <> T.intercalate ", " [esc (url (oBody o)) | (o, _) <- pEntries q] <> ")" else ""
      in T.concat
           [ "<li><strong>", t (cTitle c), "</strong> · ", t (T.replace " · this page" "" (en (fSeen f)) // T.replace " · cette page" "" (fr (fSeen f)))
           , " · ", t (num count' <> " pages" // num count' <> " pages"), which
           , if v == Review then "" else "<br><strong>" <> t (verdictWord' v) <> "</strong> · " <> t ("reviewer's answer; rule: open" // "réponse du relecteur ; règle : ouverte")
           , maybe "" (\x -> "<br><em>" <> esc x <> "</em>") n
           , if v /= Review then ""
             else if asking then controls' ("site-" <> pKey q) (each' <> lowerFr (question c f)) f
             else "<br><strong>" <> t ("Question: " // "Question : ") <> "</strong>" <> t (each' <> lowerFr (question c f))
           , "</li>" ]
    each' = "On each of these pages: " // "Sur chacune de ces pages : "
    lowerFr (Phrase e f') = Phrase e (T.toLower (T.take 1 f') <> T.drop 1 f')
    verdictWord' v = case v of
      Pass -> "Yes" // "Oui"
      Fail -> "No" // "Non"
      _ -> verdictWord v

    count v fs = length [() | f <- fs, fVerdict f == v]

    -- What holds first, then what is left: a count said in words where it is none or one.
    tally none one many k
      | k == 0 = t none
      | k == 1 = "1 " <> t one
      | otherwise = esc (num k) <> " " <> t many

    page' :: (Int, Obs) -> [Text]
    page' (i, o) = let b = oBody o; every = assess st o; fs = own o every; k' = length (pooledHere o) in
      [ if single then "" else "<h2 id=\"p" <> num i <> "\">" <> esc (url b) <> "</h2>"
      , "<p class=\"meta\">" <> t ("Observed on " // "Observée le ") <> esc (date l (at b)) <> maybe "" ((" · " <>) . esc) (browser b)
          <> (if truncated (page b) == Just True then t (" · page too large: first surfaces only" // " · page trop grande : premières surfaces seulesses premières surfaces ont été lues") else "") <> "</p>"
      , p ("<strong>" <> T.intercalate " · "
            [ tally ("no check passes" // "aucun contrôle ne passe") ("check passes" // "contrôle passe") ("checks pass" // "contrôles passent") (count Pass fs)
            , tally ("no fixes" // "aucune correction") ("fix" // "correction") ("fixes" // "corrections") (count Fail fs)
            , tally ("no open questions" // "aucune question ouverte") ("open question" // "question ouverte") ("open questions" // "questions ouvertes") (count Review fs)
            , tally ("no lighter options" // "aucun allègement") ("lighter option" // "allègement") ("lighter options" // "allègements") (count Hint fs) ] <> "</strong>"
           <> (case length (decided fs) of
                 0 -> ""
                 k -> "<br>" <> tally ("" // "") ("answer by the reviewer" // "réponse du relecteur") ("answers by the reviewer" // "réponses du relecteur") k)
           <> (if k' == 0 then "" else "<br>" <> "<a href=\"#site\">" <> tally ("" // "") ("question asked once for the whole site" // "question posée une fois pour tout le site")
                                                                        ("questions asked once for the whole site" // "questions posées une fois pour tout le site") k' <> "</a>")
           <> since o every) ]
      ++ concat [ group b n title fs v | (n, title, v) <- [ (2 :: Int, "Fixes" // "Corrections", Fail), (2, "Open questions" // "Questions ouvertes", Review), (2, "Lighter options" // "Allègements", Hint) ] ]
      ++ (if asking && any answerable fs then [p ("<button type=\"submit\">" <> t ("Submit answers" // "Envoyer les réponses") <> "</button>")] else [])
      ++ (case [f | f <- decided fs, fVerdict f == Pass] of
            [] -> []
            xs -> hd 2 (t ("Confirmed by the reviewer" // "Confirmé par le relecteur") <> " (" <> num (length xs) <> ")")
                    : p (t ("Confirmed by the reviewer, not by rule. Each confirmation lapses when the element changes."
                            // "Confirmé par le relecteur, non par une règle. Chaque confirmation tombe quand l'élément change."))
                    : concat [ criterion b 3 c [f | f <- xs, cId (fCrit f) == cId c] | c <- criteria, any ((== cId c) . cId . fCrit) xs ])
      ++ [ hd 2 (t ("Criterion by criterion" // "Critère par critère")), "<ul>" ]
      ++ [ "<li>" <> t (cTitle c) <> " · " <> summary [f | f <- every, cId (fCrit f) == cId c] <> "</li>" | c <- criteria ]
      ++ [ "</ul>", hd 2 (t ("Footprint" // "Empreinte")) ]
      ++ weight b
      ++ maybe [] (lecture b) (readingOf b fs)

    since o fs = case previous st o of
      [] -> ""
      (q : _) ->
        let open f = fVerdict f `elem` [Fail, Review, Hint]
            was = [fId f | f <- assess st q, open f]
            now = [fId f | f <- fs, open f]
        in "<br>" <> t ("Since " // "Depuis le ") <> esc (date l (at (oBody q))) <> t (": " // " : ")
             <> esc (num (length [x | x <- was, x `notElem` now])) <> t (" resolved, " // " résolus, ")
             <> esc (num (length [x | x <- now, x `notElem` was])) <> t (" new, " // " nouveaux, ")
             <> esc (num (length [x | x <- now, x `elem` was])) <> t (" unchanged." // " inchangés.")

    -- Within a verdict: the lightest work first, then the order of the criteria.
    group b n title fs v = case [f | f <- fs, fVerdict f == v] of
      [] -> []
      xs -> hd n (t title <> " (" <> num (length xs) <> ")")
        : concat [ criterion b (n + 1) c [f | f <- xs, cId (fCrit f) == cId c] | c <- sortOn cEffort criteria, any ((== cId c) . cId . fCrit) xs ]

    -- The criteria no rule can see from a page, declared once for the whole record. Asking, each comes with
    -- yes, no, not applicable and a note, the answer in force already chosen; otherwise the answered ones
    -- stand in full and the open ones are named, by family.
    statement =
      let said = declared st
          now = oBody <$> resolve st Nothing
          answer i = maybe "open" dAnswer (M.lookup (cited i) said)
          count' a = length [i | i <- items, answer i == a]
          fams = foldl (\acc x -> if any ((== family x) . family) acc then acc else acc ++ [x]) [] items
          link i = "<a href=\"" <> esc (official i) <> "\">" <> esc (cited i) <> "</a>"
          seen' i = maybe "" (\x -> "<br>" <> t ("Seen: " // "Constaté : ") <> t x) (now >>= iSeen i)
          noted i = maybe "" (\x -> "<br><em>" <> esc x <> "</em>") (M.lookup (cited i) said >>= dNote)
          shown a = case a of
            "yes" -> "Yes" // "Oui"
            "no" -> "No" // "Non"
            "n/a" -> "Not applicable" // "Sans objet"
            _ -> "Open" // "Ouverte"
          k i = "d-" <> slug i
          choice i v w = "<input type=\"radio\" id=\"" <> k i <> "-" <> T.replace "/" "" v <> "\" name=\"" <> k i <> "\" value=\"" <> v <> "\""
                         <> (if answer i == v then " checked" else "") <> "> <label for=\"" <> k i <> "-" <> T.replace "/" "" v <> "\">" <> t w <> "</label>"
          control i = "<fieldset><legend>" <> t (iAsk i) <> "</legend>" <> choice i "yes" ("Yes" // "Oui") <> " " <> choice i "no" ("No" // "Non") <> " "
                      <> choice i "n/a" ("Not applicable" // "Sans objet")
                      <> "<label for=\"dn-" <> T.drop 2 (k i) <> "\">" <> t ("Note" // "Note") <> "</label><input type=\"text\" id=\"dn-" <> T.drop 2 (k i) <> "\" name=\"dn-" <> T.drop 2 (k i)
                      <> "\" maxlength=\"200\" autocomplete=\"off\" value=\"" <> esc (maybe "" id (M.lookup (cited i) said >>= dNote)) <> "\"></fieldset>"
          entry i
            | asking = "<li>" <> link i <> seen' i <> control i <> "</li>"
            | otherwise = "<li>" <> link i <> " · " <> t (iAsk i) <> "<br><strong>" <> t (shown (answer i)) <> "</strong>" <> noted i <> seen' i <> "</li>"
      in [ "<h2 id=\"declarations\">" <> t ("Declarations" // "Déclarations") <> "</h2>"
         , p (t ("Criteria not visible from a page: how the service is decided, built, hosted and run, how its pages fit together, what its AI does beyond the page, and what other laws and standards ask of it. Declared once by the owner for the whole record. The official texts prevail."
                // "Critères invisibles depuis une page : comment le service est décidé, construit, hébergé et exploité, comment ses pages s'articulent, ce que fait son IA au-delà de la page, et ce que d'autres lois et normes lui demandent. Déclarés une fois par le responsable pour tout le relevé. Les textes officiels prévalent."))
         , p ("<strong>" <> T.intercalate " · " [ esc (num (count' a)) <> " " <> t w | (a, w) <- [("yes", "yes" // "oui"), ("no", "no" // "non"), ("n/a", "not applicable" // "sans objet"), ("open", "open" // "ouvertes")] ] <> "</strong>") ]
         ++ concat [ "<h3>" <> t (family f) <> "</h3>" : (if asking then ["<ul>"] ++ map entry xs ++ ["</ul>"]
                                            else ["<ul>" | not (null done)] ++ map entry done ++ ["</ul>" | not (null done)]
                                                 ++ [ p (t ("Open: " // "Ouvertes : ") <> T.intercalate ", " (map link open')) | not (null open') ])
                   | f <- fams, let xs = [i | i <- items, family i == family f], let done = [i | i <- xs, answer i /= "open"], let open' = [i | i <- xs, answer i == "open"] ]
         ++ [ p ("<button type=\"submit\">" <> t ("Submit declarations" // "Envoyer les déclarations") <> "</button>") | asking ]

    -- What a person has read otherwise than the rule.
    decided fs = [f | f <- fs, fVerdict f /= fMachine f]
    -- Only what the rule itself left to a person is put as a question: a failure the rule can show is not argued away.
    answerable f = fVerdict f == Review && fMachine f == Review

    question c f = maybe (("Holds here: “" // "Tenu ici : « ") <> cTitle c <> ("”?" // " » ?")) id (fAsk f)

    -- An image is judged with what stands around it: the file, and the words the page says just before and after it.
    beside b f = case fSurface f of
      Just s | kind s `elem` ["img", "graphic"] ->
        let file' = maybe "" (\u -> if any (`T.isPrefixOf` u) ["https://", "http://"]
                                     then "<br>" <> t ("File: " // "Fichier : ") <> "<a href=\"" <> esc u <> "\">" <> esc (fileName u) <> "</a>" else "") (src s)
            near = [e | e <- concat (events b), eKind e == "text", eShown e, not (T.null (T.strip (eSaid e)))]
            at' = ev s
            before' = listToMaybe (reverse [e | Just n <- [at'], e <- near, eN e < n])
            after' = listToMaybe [e | Just n <- [at'], e <- near, eN e > n]
            said lbl e = "<br>" <> t lbl <> t ("“" // "« ") <> esc (eSaid e) <> t ("”" // " »")
        in file' <> maybe "" (said ("Text before: " // "Texte avant : ")) before' <> maybe "" (said ("Text after: " // "Texte après : ")) after'
      _ -> ""
    fileName u = let path' = T.takeWhile (`notElem` ("?#" :: String)) u
                     last' = last ("" : filter (not . T.null) (T.splitOn "/" path'))
                 in if T.null last' then u else last'

    -- The controls of one question: yes, no, and a note. Unanswered, it stays a point to decide.
    controls o c f = controls' o (question c f) f
    controls' o legend f =
      let k = o <> "-" <> fId f
          choice v w = "<input type=\"radio\" id=\"a-" <> k <> "-" <> v <> "\" name=\"a-" <> k <> "\" value=\"" <> v <> "\"> <label for=\"a-" <> k <> "-" <> v <> "\">" <> t w <> "</label>"
      in "<fieldset><legend>" <> t legend <> "</legend>"
           <> choice "pass" ("Yes" // "Oui") <> " " <> choice "fail" ("No" // "Non")
           <> "<label for=\"n-" <> k <> "\">" <> t ("Note" // "Note") <> "</label>"
           <> "<input type=\"text\" id=\"n-" <> k <> "\" name=\"n-" <> k <> "\" maxlength=\"200\" autocomplete=\"off\"></fieldset>"

    criterion b n c xs =
      [ hd n (t (cTitle c))
      , "<p>" <> t (cWhy c) <> " <span class=\"meta\">" <> t (cRef c) <> " · " <> t (effort (cEffort c)) <> "</span></p>"
      , "<ul>" ]
      ++ [ "<li>" <> t (fSeen f) <> (if fVerdict f == Review && not (null (fAsk f)) then "" else maybe "" (\ch -> "<br><strong>" <> t ("Fix: " // "Correction : ") <> "</strong>" <> t ch) (fChange f))
             <> maybe "" (\s -> "<br><code>" <> esc (sel s) <> "</code>") (fSurface f)
             <> (if fVerdict f == Review then beside b f else "")
             <> (if fVerdict f /= fMachine f then " · " <> t ("reviewer's answer; rule: " // "réponse du relecteur ; règle : ") <> t (verdictWord (fMachine f)) else "")
             <> (if fNew f then " · " <> t ("new" // "nouveau") else "")
             <> (if fAge f > 0 then " · " <> t ("open for " <> num (fAge f) <> (if fAge f == 1 then " observation" else " observations") // "ouvert depuis " <> num (fAge f) <> (if fAge f == 1 then " observation" else " observations")) else "")
             <> maybe "" (\x -> "<br><em>" <> esc x <> "</em>") (fNote f)
             <> (if fVerdict f /= Review then ""
                 else if asking && answerable f then controls (oOf b) c f
                 else "<br><strong>" <> t ("Question: " // "Question : ") <> "</strong>" <> t (question c f))
             <> "</li>"
         | f <- sortOn (maybe 0 order . fSurface) xs ]
      ++ ["</ul>"]

    verdictWord v = case v of
      Fail -> "fix" // "correction"
      Review -> "open" // "ouverte"
      Hint -> "lighter option" // "allègement"
      Pass -> "pass" // "passe"
      NA -> "not applicable" // "sans objet"
    -- The observation a body belongs to, among the latest: the controls name it.
    oOf b = case [o | o <- pages, url (oBody o) == url b, at (oBody o) == at b] of
      o : _ -> oId o
      [] -> ""

    effort Light = "light fix" // "correction légère"
    effort Medium = "moderate fix" // "correction moyenne"
    effort Heavy = "heavy fix" // "correction lourde"

    summary xs
      | all ((== NA) . fVerdict) xs = t ("not applicable: " // "sans objet : ") <> maybe "" (t . fSeen) (listToMaybe xs)
      | otherwise = esc (num (length [f | f <- xs, fVerdict f == Pass])) <> t (" of " // " sur ") <> esc (num (length [f | f <- xs, fVerdict f /= NA])) <> t (" pass" // " passent")

    -- The reading: a measure set apart from the verdicts.
    lecture b r =
      [ hd 2 (t ("The reading" // "La lecture"))
      , p (t ("A measure, not a verdict. The page holds " <> things (rEvents r) <> " to read. Headings, lists and table headers let a reader take them independently. Everything else is read in order."
              // "Une mesure, pas un verdict. La page contient " <> choses (rEvents r) <> " à lire. Titres, listes et en-têtes de tableau permettent de les prendre indépendamment. Le reste se lit dans l'ordre."))
      , "<dl>"
      , dt ("Shown and not said" // "Montré et non dit") <> dd (num (rUnsaid r) <> ": visible, but not given to assistive technology." // num (rUnsaid r) <> " : visible, mais non transmis aux technologies d'assistance.")
      , dt ("Said and not shown" // "Dit et non montré") <> dd (num (rUnshown r) <> ": given to assistive technology only, such as a skip link." // num (rUnshown r) <> " : transmis aux seules technologies d'assistance, tel un lien d'évitement.")
      , dt ("Depth" // "Profondeur") <> dd (num (rDepth r) <> ": longest sequence the markup imposes. Without structure: " <> num (rEvents r) <> "."
                                           // num (rDepth r) <> " : plus longue suite imposée par le balisage. Sans structure : " <> num (rEvents r) <> ".")
      , dt ("Serial, by ear" // "En série, à l'oreille") <> dd (steps' (rSerial r) <> ": everything read in sequence." // etapes (rSerial r) <> " : tout lu à la suite.")
      , dt ("Up to " <> num ceiling' <> " at a time" // "Jusqu'à " <> num ceiling' <> " à la fois")
          <> dd (steps' (rSteps r) <> " as is; " <> num (rClear r) <> " with nothing failing. Range for this size and depth: " <> num (rLower r) <> " to " <> num (rUpper r) <> "."
                 // etapes (rSteps r) <> " en l'état ; " <> num (rClear r) <> " sans échec. Plage pour cette taille et cette profondeur : " <> num (rLower r) <> " à " <> num (rUpper r) <> ".")
      , dt ("What the page says" // "Ce que dit la page")
          <> dd (let said = max 1 (round (rBits r / 8)) :: Int; each = transfer (network b) `div` said
                 in num said <> " bytes of text, estimated; " <> num each <> " bytes transferred per byte of text." // num said <> " octets de texte, estimés ; " <> num each <> " octets transférés par octet de texte.")
      , "</dl>" ]
      ++ (if null (rMending r) then [] else
           [ p (t ("Order of fixes. Each line fixes one criterion, after those above, and gives the steps that remain. Gains add up to the page with nothing failing."
                   // "Ordre des corrections. Chaque ligne corrige un critère, après ceux du dessus, et donne les étapes restantes. Les gains s'additionnent jusqu'à la page sans échec."))
           , "<ol>" ]
           ++ [ "<li>" <> t ("“" // "« ") <> t (title' c) <> t ("”: " // " » : ") <> t (steps' k // etapes k) <> "</li>" | (c, k) <- rMending r ]
           ++ [ "</ol>" ])
      ++ [ "<p class=\"meta\">" <> t ("A reader holding up to " <> num ceiling' <> " at a time is a convention, like a reference device in a speed test. Failures reduce what it holds."
              // "Un lecteur qui en tient jusqu'à " <> num ceiling' <> " à la fois est une convention, comme l'appareil de référence d'un test de vitesse. Les échecs réduisent ce qu'il tient.") <> "</p>" ]
      where
        things n = num n <> (if n == 1 then " thing" else " things")
        choses n = num n <> (if n == 1 then " chose" else " choses")
        steps' n = num n <> (if n == 1 then " step" else " steps")
        etapes n = num n <> (if n == 1 then " étape" else " étapes")
        title' c = maybe (both c) cTitle (listToMaybe [k | k <- criteria, cId k == c])

    weight b = let Footprint e r kb hs ch = footprint b in
      [ "<p>" <> esc (num e) <> " " <> t ("elements in the document" // "éléments dans le document") <> " · " <> esc (num r) <> " " <> t ("requests" // "requêtes") <> " · "
          <> esc (num (round kb :: Int)) <> " " <> t ("kB transferred" // "ko transférés") <> " · " <> esc (num (length hs)) <> " " <> t ("third-party hosts" // "hôtes tiers")
          <> (if null hs then "" else " (" <> esc (T.intercalate ", " hs) <> ")") <> "</p>" ]
      ++ [ "<p>" <> t ("Longest chain: " <> num (length ch) <> " requests, each waiting on the one before. Loading takes at least " <> num (length ch) <> " round trips in a row, whatever the connection."
                      // "Chaîne la plus longue : " <> num (length ch) <> " requêtes, chacune attendant la précédente. Le chargement demande au moins " <> num (length ch) <> " allers-retours successifs, quelle que soit la connexion.")
           <> "<br><code>" <> esc (T.intercalate " → " (map named ch)) <> "</code></p>" | length ch > 2 ]

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
                <> num (length (touched "art.")) <> " paragraphs of article 50 of the AI Act. " <> reach En
                // num (length criteria) <> " règles, chacune en code clair. Pour chacune : ce qu'elle vérifie, à quoi cela sert, et le texte dont elle vient. Elles touchent "
                <> num (length (touched "RGAA")) <> " des 106 critères du RGAA 4.1.2, " <> num (length (touched "RGESN")) <> " des 78 du RGESN 2024, et "
                <> num (length (touched "art.")) <> " paragraphes de l'article 50 du règlement sur l'IA. " <> reach Fr) <> "</p>" ]
  ++ [ "<h2 id=\"frameworks\">" <> t ("Frameworks" // "Cadres") <> "</h2>"
     , "<p>" <> t ("Each text as the provisions it is made of. A provision is addressed when a rule reads it, a question puts it to the reviewer, or the owner declares it. This says what a record covers, not whether a site conforms."
                  // "Chaque texte, selon les dispositions qui le composent. Une disposition est traitée quand une règle la lit, qu'une question la soumet au relecteur, ou que le responsable la déclare. Cela dit ce que couvre un relevé, et non la conformité d'un site.") <> "</p>"
     , "<table><thead><tr><th scope=\"col\">" <> t ("Text" // "Texte") <> "</th><th scope=\"col\">" <> t ("Where it applies" // "Champ") <> "</th><th scope=\"col\">"
       <> t ("What it asks" // "Ce qu'il demande") <> "</th><th scope=\"col\">" <> t ("Addressed" // "Traitées") <> "</th></tr></thead><tbody>" ]
  ++ [ "<tr><th scope=\"row\"><a href=\"" <> esc (fUrl f) <> "\">" <> esc (fName f) <> "</a></th><td>" <> t (fWhere f) <> "</td><td>" <> t (fBasis f) <> "</td><td>"
       <> t (both (num a) <> (" of " // " sur ") <> both (num n)) <> "</td></tr>" | f <- frameworks, let (a, n) = coverage f ]
  ++ [ "</tbody></table>" ]
  ++ concat [ [ "<h2 id=\"" <> cId c <> "\">" <> t (cTitle c) <> "</h2>", "<p>" <> t (cWhy c) <> "</p>"
              , "<p class=\"meta\">" <> t (cRef c) <> "</p>" ] | c <- criteria ]
  ++ [ "<p class=\"meta\">relevé " <> esc release <> " · " <> t ("criteria v" // "critères v") <> esc version <> "</p>", "</main>", "</body>", "</html>" ]
  where t = codify . typography l . say l

num :: Int -> Text
num = T.pack . show

-- | What rules, the reviewer's questions and the owner's declarations address together, out of each text.
reach :: Lang -> Text
reach l =
  let (a, a') = covering "RGAA 4.1.2"; (b, b') = covering "RGESN 2024"; (c, c') = covering "AI Act article 50"; (d, d') = covering "WCAG 2.1 AA"
      n' = T.pack . show
  in if l == En
       then "With the reviewer's questions and the owner's declarations, they address " <> n' a <> " of the " <> n' a' <> " criteria of the RGAA 4.1.2, "
            <> n' b <> " of the " <> n' b' <> " of the RGESN 2024, and " <> n' c <> " of the " <> n' c' <> " paragraphs of article 50 of the AI Act; through the RGAA's own correspondence, "
            <> n' d <> " of the " <> n' d' <> " success criteria of WCAG 2.1 at levels A and AA. " <> unbound En
       else "Avec les questions au relecteur et les déclarations du responsable, elles traitent " <> n' a <> " des " <> n' a' <> " critères du RGAA 4.1.2, "
            <> n' b <> " des " <> n' b' <> " du RGESN 2024, et " <> n' c <> " des " <> n' c' <> " paragraphes de l'article 50 du règlement sur l'IA ; par la correspondance du RGAA lui-même, "
            <> n' d <> " des " <> n' d' <> " critères de succès de WCAG 2.1 aux niveaux A et AA. " <> unbound Fr

-- | A framework's coverage, by name.
covering :: Text -> (Int, Int)
covering n = maybe (0, 0) coverage (find ((== n) . fName) frameworks)

-- | Why the paragraphs of article 50 that bind no site are counted all the same.
unbound :: Lang -> Text
unbound l = T.intercalate " " [ (if l == En then "Paragraph " else "Le paragraphe ") <> p <> " " <> say l w <> "." | (p, w) <- unbinding ]

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

-- | Text made safe for a page, with what HTML itself writes set as code: a
--   tag, an attribute with its value, an ARIA attribute. A reader then tells
--   at a glance the words of the report from the words of the language it
--   reports on.
codify :: Text -> Text
codify = go True
  where
    go _ "" = ""
    go start x
      | Just n <- tag x = code n x
      | start, Just n <- attribute x = code n x
      | otherwise = let (c, rest) = T.splitAt 1 x in esc c <> go (c `elem` [" ", "(", "\x00a0", "\x202f"]) rest
    code n x = let (a, rest) = T.splitAt n x in "<code>" <> esc a <> "</code>" <> go False rest
    -- <label>, <track kind="captions">, <!doctype html>: an opening bracket, a letter or a bang, and its closing bracket near by.
    tag x = case T.uncons x of
      Just ('<', r) | Just (c, _) <- T.uncons r, isAsciiLower c || c == '!'
                    , (inside, close) <- T.breakOn ">" (T.take 60 r), not (T.null close), not (T.any (== '<') inside) -> Just (T.length inside + 2)
      _ -> Nothing
    -- aria-label; alt=""; loading="lazy"; role=presentation: a lower-case name, then a value or nothing.
    attribute x =
      let (name', r) = T.span (\c -> isAsciiLower c || c == '-') x
      in case T.uncons r of
           Just ('=', v) | not (T.null name') -> Just (T.length name' + 1 + value v)
           _ | "aria-" `T.isPrefixOf` name' && T.length name' > 5 -> Just (T.length name')
           _ -> Nothing
    value v = case T.uncons v of
      Just ('"', q) -> let (inside, close) = T.breakOn "\"" q in if T.null close then 1 else T.length inside + 2
      _ -> T.length (T.takeWhile (\c -> isAlphaNum c || c `elem` ("-_." :: String)) v)

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
  , "fieldset { min-width: 0; margin: .5rem 0 0; padding: .5rem .75rem; border: 1px solid #c8cacd; } legend { padding: 0 .25rem; font-weight: 600; }"
  , "fieldset label { margin-right: 1rem; } fieldset input[type=text] { display: block; width: 100%; margin-top: .25rem; padding: .3rem; font: inherit; color: inherit; background: #fff; border: 1px solid #5c6066; }"
  , "button { font: inherit; padding: .5rem 1rem; color: #fff; background: #1a1a1a; border: 1px solid #1a1a1a; }"
  , "input:focus-visible, button:focus-visible { outline: 2px solid #1f3a8a; outline-offset: 2px; }"
  , "table { border-collapse: collapse; width: 100%; } th, td { text-align: left; padding: .4rem .5rem .4rem 0; border-bottom: 1px solid #c8cacd; overflow-wrap: anywhere; } tbody th { font-weight: normal; }" ]
