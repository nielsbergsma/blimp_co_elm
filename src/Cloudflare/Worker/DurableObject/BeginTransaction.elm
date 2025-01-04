module Cloudflare.Worker.DurableObject.BeginTransaction exposing
  ( Result
  , Error(..)
  , errorToString
  , resultDecoder
  )

import Result as Elm
import Json.Decode as JsonDecode
import Json.Decode.Pipeline as JsonDecode
import Prelude.Transaction exposing(..)


type alias Result a = Elm.Result Error (Transaction a)


type Error
  = IoError String
  | DecodeError JsonDecode.Error


errorToString : Error -> String
errorToString error = 
  case error of
    IoError reason -> "[i/o error] " ++ reason
    DecodeError reason -> "[decode error] " ++ JsonDecode.errorToString reason


resultDecoder : JsonDecode.Decoder a -> JsonDecode.Decoder (Transaction a)
resultDecoder valueDecoder =
  JsonDecode.oneOf
  [ JsonDecode.field "empty"
    ( JsonDecode.succeed Empty
      |> JsonDecode.required "key" JsonDecode.string
    )
  , JsonDecode.field "existing"
    ( JsonDecode.succeed Existing
      |> JsonDecode.required "key" JsonDecode.string
      |> JsonDecode.required "version" versionDecoder
      |> JsonDecode.required "value" valueDecoder
    )
  ]
