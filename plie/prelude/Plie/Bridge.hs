-- SPDX-FileCopyrightText: 2026 Anna Teterkina <anna@bureaudessurfaces.fr>
-- SPDX-License-Identifier: EUPL-1.2
-- | Where plié meets the world, in Haskell: JSON in, a function from Json to Json called
--   by name, its answer out as canonical text (RFC 8785). A number that is not an integer
--   is refused: plié holds none.
module Plie.Bridge (call) where

import qualified Data.Aeson as A
import qualified Data.Aeson.Key as K
import qualified Data.Aeson.KeyMap as KM
import qualified Data.ByteString as B
import Data.Foldable (toList)
import Data.Text (Text)
import Plie.Json (Json (..), canonical)
import Plie.Prelude (Pair (..))

json :: A.Value -> Either String Json
json v = case v of
  A.Null -> Right JNull
  A.Bool b -> Right (JBool b)
  A.Number _ -> case A.fromJSON v :: A.Result Integer of
    A.Success n -> Right (JInt n)
    A.Error _ -> Left "a number that is not an integer"
  A.String t -> Right (JText t)
  A.Array xs -> JList <$> mapM json (toList xs)
  A.Object o -> JObj <$> mapM (\(k, x) -> Pair (K.toText k) <$> json x) (KM.toList o)

-- | The named function on the JSON given, its answer as canonical text.
call :: [(Text, Json -> Json)] -> Text -> B.ByteString -> Either String Text
call table name input = case lookup name table of
  Nothing -> Left "no such function"
  Just f -> either (Left . ("not JSON: " <>)) (fmap (canonical . f) . json) (A.eitherDecodeStrict input)
