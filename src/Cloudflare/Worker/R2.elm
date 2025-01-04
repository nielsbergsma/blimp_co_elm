module Cloudflare.Worker.R2 exposing 
  ( Path
  , Bucket
  , defineBucket
  , ObjectType
  , defineObjectType
  , Error(..)
  , errorToString
  , Result
  , get
  , put
  )

import Task exposing (..)
import Result as Elm
import Json.Encode as JsonEncode
import Json.Decode as JsonDecode


type Bucket = Bucket String


type alias Path = List String


type alias Result a = Elm.Result Error a


type ObjectType a 
  = ObjectType (a -> JsonEncode.Value) (JsonDecode.Decoder a)


defineObjectType : (a -> JsonEncode.Value) -> (JsonDecode.Decoder a) -> (ObjectType a)
defineObjectType = ObjectType


defineBucket : String -> Bucket
defineBucket = Bucket


type Error
  = IoError String
  | DecodeError JsonDecode.Error


get : ObjectType a -> Bucket -> Path -> Cmd (Result (Maybe a))
get (ObjectType _ decoder) (Bucket bucket) path =
  let
    options = JsonEncode.object
      [ ("binding", JsonEncode.string bucket)
      , ("key", JsonEncode.string (String.join "/" path))
      ]

    decode = JsonDecode.decodeValue (JsonDecode.nullable decoder)
  in
    Task.attempt 
      (unnestError DecodeError)
      (getFFI options
        |> Task.mapError IoError
        |> Task.map decode
      )


getFFI : JsonEncode.Value -> Task String JsonDecode.Value
getFFI _ = Task.fail "not patched"

-- put 
put : ObjectType a -> Bucket -> Path -> a -> Cmd (Result ())
put (ObjectType encoder _ ) (Bucket bucket) path value = 
  let
    options = JsonEncode.object
      [ ("binding", JsonEncode.string bucket)
      , ("metadata", JsonEncode.object
         [ ("contentType", JsonEncode.string "application/json")
         ]
        )
      , ("key", JsonEncode.string (String.join "/" path))
      , ("value", encode value)
      ]

    encode = JsonEncode.string << JsonEncode.encode 0 << encoder

    decode = JsonDecode.decodeValue (JsonDecode.succeed ())
  in
    Task.attempt 
      (unnestError DecodeError)
      (putFFI options
        |> Task.mapError IoError
        |> Task.map decode
      )


putFFI : JsonEncode.Value -> Task String JsonDecode.Value
putFFI _ = Task.fail "not patched"


-- helpers
unnestError : (e2 -> e1) -> Elm.Result e1 (Elm.Result e2 a) -> Elm.Result e1 a
unnestError map result =
  case result of
    Ok (Ok a) -> Ok a
    Ok (Err e2) -> Err (map e2)
    Err e1 -> Err e1
  

errorToString : Error -> String
errorToString error = 
  case error of
    IoError reason -> "[i/o error] " ++ reason
    DecodeError reason -> "[decode error] " ++ JsonDecode.errorToString reason