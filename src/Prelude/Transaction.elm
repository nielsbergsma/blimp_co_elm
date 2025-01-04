module Prelude.Transaction exposing
  ( Transaction(..)
  , Version
  , versionToString
  , versionToInt
  , Key
  , withValue
  , encodeVersion
  , versionDecoder
  )

import Json.Encode as JsonEncode
import Json.Decode as JsonDecode


type Version = Version Int


type alias Key = String


type Transaction a
  = Empty Key
  | Existing Key Version a


withValue : a -> Transaction a -> Transaction a
withValue value transaction =
  case transaction of
    Empty key -> Existing key (Version 0) value
    Existing key version _ -> Existing key version value


versionToString : Version -> String
versionToString (Version value) = String.fromInt value


versionToInt : Version -> Int
versionToInt (Version value) = value


encodeVersion : Version -> JsonEncode.Value
encodeVersion (Version value) = JsonEncode.int value


versionDecoder : JsonDecode.Decoder Version
versionDecoder = JsonDecode.map Version JsonDecode.int
