module Cloudflare.Worker.DurableObject exposing 
  ( Repository
  , defineRepository
  , ObjectType
  , defineObjectType
  , Key 
  , get
  , begin
  , commit
  )


import Json.Encode as JsonEncode
import Json.Decode as JsonDecode
import Cloudflare.Worker.DurableObject.Get as Get
import Cloudflare.Worker.DurableObject.BeginTransaction as BeginTransaction
import Cloudflare.Worker.DurableObject.CommitTransaction as CommitTransaction
import Task exposing (Task)


type Repository = Repository String


defineRepository : String -> Repository
defineRepository = Repository


type ObjectType a 
  = ObjectType (a -> JsonEncode.Value) (JsonDecode.Decoder a)


defineObjectType : (a -> JsonEncode.Value) -> (JsonDecode.Decoder a) -> (ObjectType a)
defineObjectType = ObjectType


type alias Key = String


-- get
get : Repository -> ObjectType a -> Key -> Cmd (Get.Result a)
get (Repository repository) (ObjectType _ decoder) key = 
  let 
    options = JsonEncode.object
      [ ("binding", JsonEncode.string repository)
      , ("partition", JsonEncode.string "default")
      , ("key", JsonEncode.string key)
      ]

    decode = JsonDecode.decodeValue (Get.resultDecoder decoder)
  in
    Task.attempt 
      (unnestError Get.DecodeError) 
      (getFFI options
        |> Task.mapError Get.IoError
        |> Task.map decode
      )


getFFI : JsonEncode.Value -> Task String JsonDecode.Value
getFFI _ = Task.fail "not patched"


-- begin
begin : Repository -> ObjectType a -> Key -> Cmd (BeginTransaction.Result a)
begin (Repository repository) (ObjectType _ decoder) key = 
  let 
    options = JsonEncode.object
      [ ("binding", JsonEncode.string repository)
      , ("partition", JsonEncode.string "default")
      , ("key", JsonEncode.string key)
      ]

    decode = JsonDecode.decodeValue (BeginTransaction.resultDecoder decoder)
  in
    Task.attempt 
      (unnestError BeginTransaction.DecodeError) 
      (beginFFI options
        |> Task.mapError BeginTransaction.IoError
        |> Task.map decode
      )


beginFFI : JsonEncode.Value -> Task String JsonDecode.Value
beginFFI _ = Task.fail "not patched"


-- commit
commit : Repository -> ObjectType a -> Key -> Int -> a -> Cmd (CommitTransaction.Result a)
commit (Repository repository) (ObjectType encode decoder) key version value = 
  let 
    options = JsonEncode.object
      [ ("binding", JsonEncode.string repository)
      , ("partition", JsonEncode.string "default")
      , ("key", JsonEncode.string key)
      , ("version", JsonEncode.int version)
      , ("value", encode value)
      ]

    decode = JsonDecode.decodeValue (CommitTransaction.resultDecoder decoder)
  in
    Task.attempt 
      (unnestError identity << unnestError CommitTransaction.DecodeError)
      (commitFFI options
        |> Task.mapError CommitTransaction.IoError
        |> Task.map decode
      )


commitFFI : JsonEncode.Value -> Task String JsonDecode.Value
commitFFI _ = Task.fail "not patched"


-- helpers
unnestError : (e2 -> e1) -> Result e1 (Result e2 a) -> Result e1 a
unnestError map result =
  case result of
    Ok (Ok a) -> Ok a
    Ok (Err e2) -> Err (map e2)
    Err e1 -> Err e1
  