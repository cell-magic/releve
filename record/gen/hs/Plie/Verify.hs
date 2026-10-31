-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- Written by plie/plie.py from Verify.plie. Do not edit: edit the source.
{-# LANGUAGE NoImplicitPrelude, OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-unused-matches -Wno-name-shadowing -Wno-unused-imports -Wno-incomplete-patterns -Wno-overlapping-patterns #-}
module Plie.Verify (Check(..), checkJson, okOf, pass, unchecked, hex32, quicknet, roundTime, verifyBundle, justs, firstFailure, edgeCheck, selection, inOrder, edgeBls) where

import Plie.Prelude
import Prelude (Show)
import qualified Data.Text as T
import Plie.Json
import Plie.Merkle
import Plie.Chain
import Plie.Roots
import Plie.Seed

data Check = Check Text Json Text deriving (Eq, Show)
checkJson :: Check -> Json
checkJson c = (case c of { (Check name ok detail) -> (object [(entry (T.pack "check") (JText name)), (entry (T.pack "ok") ok), (entry (T.pack "detail") (JText detail))]) })

okOf :: Check -> Json
okOf c = (case c of { (Check name ok detail) -> ok })

pass :: Text -> Bool -> Text -> Text -> Check
pass name ok good bad = (Check name (JBool ok) (if ok then good else bad))

unchecked :: Text -> Text -> Check
unchecked name why = (Check name JNull why)

hex32 :: Text -> Bool
hex32 t = (case (unhex t) of { (Just b) -> ((bytesLength b) == (32 :: Integer)); (Nothing) -> False })

quicknet :: Text
quicknet = (T.pack "52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971")

roundTime :: Integer -> Integer
roundTime r = ((1692803367 :: Integer) + ((r - (1 :: Integer)) * (3 :: Integer)))

verifyBundle :: Json -> Json
verifyBundle input = (let b = (field (T.pack "bundle") input) in (let r = (field (T.pack "record") b) in (let h = (asText (field (T.pack "record_hash") b)) in (let previous = (field (T.pack "previous") input) in (let rootHex = (asText (field (T.pack "root") b)) in (let steps = (map stepOf (asList (field (T.pack "path") b))) in (let edge = (field (T.pack "edge") input) in (let roots = (asList (field (T.pack "entries") (field (T.pack "roots") input))) in (let token = (fromMaybe (utf8 (T.pack "")) (unhex (asText (field (T.pack "token") b)))) in (let checks = ([(pass (T.pack "record-hash") (((recordHash r) == h) && (hex32 h)) (T.pack "the record's canonical bytes hash to the hash it is delivered with") (T.pack "the record does not hash to the hash it is delivered with: it is not the record that was chained")), (if ((isNull previous) && (not (isNull (field (T.pack "prev") r)))) then (unchecked (T.pack "prev-link") (T.pack "the record names a previous record; give it to check the link")) else (pass (T.pack "prev-link") (linked previous r) (T.pack "the record follows from the one before it") (T.pack "the record does not follow from the one before it"))), (pass (T.pack "inclusion-path") ((all (\s -> (s /= Nothing)) steps) && ((hex (rootFrom (fromMaybe (utf8 (T.pack "")) (unhex h)) (justs steps))) == rootHex)) (T.pack "the path leads from the record's hash to the root") (T.pack "the path does not lead from the record's hash to the root")), (pass (T.pack "root") ((hex32 rootHex) && ((asText (field (T.pack "cycle") b)) == (asText (field (T.pack "cycle") r)))) (T.pack "the root is the root of the record's own cycle") (T.pack "the root is not one of the record's cycle")), (pass (T.pack "published") ((chained JNull roots) && ((listed (asText (field (T.pack "cycle") b)) rootHex roots) && (any (\e -> (((asText (field (T.pack "root") e)) == rootHex) && ((asText (field (T.pack "token_hash") e)) == (hex (sha256 token))))) roots))) (T.pack "the root and its token stand in the published list, and the list runs unbroken") (T.pack "the root, or its token, is not in the published list, or the list does not run unbroken")), (edgeCheck (T.pack "tsa-token") (field (T.pack "tsa") edge) rootHex (T.pack "the time-stamp token covers the root, under the authority's signature"))] <> (selection r edge)) in (let oks = (map okOf checks) in (object [(entry (T.pack "ok") (JBool (all (\o -> (o == (JBool True))) oks))), (entry (T.pack "checks") (JList (map checkJson checks))), (entry (T.pack "first_failure") (firstFailure checks))]))))))))))))

justs :: [Maybe Step] -> [Step]
justs ms = (concat (map (\m -> (case m of { (Just s) -> [s]; (Nothing) -> [] })) ms))

firstFailure :: [Check] -> Json
firstFailure cs = (case cs of { [] -> JNull; (c : rest) -> (case c of { (Check name ok detail) -> (if (ok == (JBool False)) then (JText name) else (firstFailure rest)) }) })

edgeCheck :: Text -> Json -> Text -> Text -> Check
edgeCheck name e expected good = (if ((isNull e) || (isNull (field (T.pack "ok") e))) then (unchecked name (if (isNull e) then (T.pack "not checked here") else (asText (field (T.pack "detail") e)))) else (pass name ((asBool (field (T.pack "ok") e)) && ((asText (field (T.pack "imprint") e)) == expected)) good (if (asBool (field (T.pack "ok") e)) then ((T.pack "the token covers something else than ") <> expected) else (asText (field (T.pack "detail") e)))))

selection :: Json -> Json -> [Check]
selection r edge = (let sel = (field (T.pack "selection") r) in (let beacon = (field (T.pack "beacon") r) in (if ((asText (field (T.pack "status") beacon)) == (T.pack "unavailable")) then [(unchecked (T.pack "beacon") (T.pack "selection not beacon-seeded: the record says the beacon could not be reached"))] else (let rnd = (asText (field (T.pack "randomness") beacon)) in (let sig = (fromMaybe (utf8 (T.pack "")) (unhex (asText (field (T.pack "signature") beacon)))) in (let round = (asInt (field (T.pack "round") beacon)) in (let given = (orderOf (object [(entry (T.pack "randomness") (JText rnd)), (entry (T.pack "site") (field (T.pack "site") r)), (entry (T.pack "cycle") (field (T.pack "cycle") r)), (entry (T.pack "candidates") (field (T.pack "candidates") sel))])) in (let order = (map asText (asList (field (T.pack "order") sel))) in (let picks = (map asText (asList (field (T.pack "picks") sel))) in (let read = (map asText (asList (field (T.pack "read") sel))) in (let committed = (field (T.pack "commitment") sel) in [(pass (T.pack "beacon-round") (((asText (field (T.pack "chain") beacon)) == quicknet) && (((hex (sha256 sig)) == rnd) && (round > (0 :: Integer)))) (T.pack "the round is of drand quicknet, and its randomness is the hash of its signature") (T.pack "the round is not of drand quicknet, or its randomness is not the hash of its signature")), (edgeBls (field (T.pack "bls") edge)), (pass (T.pack "order") (((field (T.pack "order") given) == (field (T.pack "order") sel)) && (((field (T.pack "seed") given) == (field (T.pack "seed") sel)) && ((inOrder read order) && (((length picks) > (0 :: Integer)) && (((nth (0 :: Integer) picks) == (nth (0 :: Integer) read)) && ((all (\p -> (elem p read)) picks) && (elem (JText (asText (field (T.pack "url") r))) (asList (field (T.pack "picks") sel))))))))) (T.pack "the order is the one the round gives, the pages read follow it, the first pick heads them, and the page is among the picks") (T.pack "the order, the seed or the picks are not those the round gives")), (edgeCheck (T.pack "committed") (field (T.pack "commitment_tsa") edge) (asText (field (T.pack "hash") committed)) (T.pack "the candidates were committed to, and the commitment dated by the authority")), (pass (T.pack "before-beacon") (((asText (field (T.pack "commitment") given)) == (asText (field (T.pack "hash") committed))) && (((asInt (field (T.pack "time") committed)) < (roundTime round)) && ((round == (firstRoundAfter (asInt (field (T.pack "time") committed)))) && ((isNull (field (T.pack "commitment_tsa") edge)) || ((isNull (field (T.pack "time") (field (T.pack "commitment_tsa") edge))) || ((asInt (field (T.pack "time") (field (T.pack "commitment_tsa") edge))) == (asInt (field (T.pack "time") committed)))))))) (T.pack "the candidates were dated before the round, and the round is the first one after: the round chose, not the Bureau") (T.pack "the candidates were not dated before the round, the round is not the first one after, or the candidates are not those committed to"))])))))))))))

inOrder :: [Text] -> [Text] -> Bool
inOrder xs ys = (case xs of { [] -> True; (x : xr) -> (case ys of { [] -> False; (y : yr) -> (if (x == y) then (inOrder xr yr) else (inOrder xs yr)) }) })

edgeBls :: Json -> Check
edgeBls e = (if ((isNull e) || (isNull (field (T.pack "ok") e))) then (unchecked (T.pack "beacon-signature") (if (isNull e) then (T.pack "the round's BLS signature is not checked here; the command line checks it") else (asText (field (T.pack "detail") e)))) else (pass (T.pack "beacon-signature") (asBool (field (T.pack "ok") e)) (T.pack "the round is signed by the League of Entropy's quicknet key") (asText (field (T.pack "detail") e))))

