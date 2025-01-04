module Cloudflare.Worker.DurableObject.CommitTransaction exposing
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
  = NothingToCommit
  | VersionConflict Version
  | IoError String
  | DecodeError JsonDecode.Error


errorToString : Error -> String
errorToString error = 
  case error of
    NothingToCommit -> "nothing to commit"
    VersionConflict version -> "[version conflict] " ++ (versionToString version)
    IoError reason -> "[i/o error] " ++ reason
    DecodeError reason -> "[decode error] " ++ JsonDecode.errorToString reason


resultDecoder : JsonDecode.Decoder a -> JsonDecode.Decoder (Result a)
resultDecoder decoder =
  JsonDecode.oneOf
  [ JsonDecode.field "committed"
    ( JsonDecode.succeed Existing
      |> JsonDecode.required "key" JsonDecode.string
      |> JsonDecode.required "version" versionDecoder
      |> JsonDecode.required "value" decoder
      |> JsonDecode.map Ok
    )
  , JsonDecode.field "versionConflict"
    ( JsonDecode.succeed VersionConflict
      |> JsonDecode.required "version" versionDecoder
      |> JsonDecode.map Err
    )
  ]
