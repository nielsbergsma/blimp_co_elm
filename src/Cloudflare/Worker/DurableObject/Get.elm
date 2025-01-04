module Cloudflare.Worker.DurableObject.Get exposing
  ( Result
  , Error(..)
  , errorToString
  , resultDecoder
  )

import Result as Elm
import Json.Decode as JsonDecode


type alias Result a = Elm.Result Error (Maybe a)


type Error
  = IoError String
  | DecodeError JsonDecode.Error


errorToString : Error -> String
errorToString error = 
  case error of
    IoError reason -> "[i/o error] " ++ reason
    DecodeError reason -> "[decode error] " ++ JsonDecode.errorToString reason


resultDecoder : JsonDecode.Decoder a -> JsonDecode.Decoder (Maybe a)
resultDecoder = JsonDecode.nullable
