port module Cloudflare.Worker.Queue exposing 
  ( Queue
  , fromName
  , Result
  , Error(..)
  , errorToString
  , publish
  , subscribeReceive
  , ack
  , nack
  )

-- import Http
import Task exposing (Task)
import Result as Elm
import Prelude.Event exposing (Event)
import Prelude.Event as Event
import Json.Decode as JsonDecode
import Json.Encode as JsonEncode


-- ports
port receive : (JsonEncode.Value -> msg) -> Sub msg


port ack : () -> Cmd msg


port nack : (String) -> Cmd msg


subscribeReceive : (a -> msg) -> (String -> msg) -> (JsonDecode.Decoder a) -> Sub msg
subscribeReceive succeed fail decoder = 
  receive (\input ->
    case JsonDecode.decodeValue decoder input of
      Ok request -> succeed request
      Err error -> fail (JsonDecode.errorToString error)
  )


type Queue = Queue String


fromName : String -> Queue
fromName name = Queue name


type alias Result = Elm.Result Error ()


type Error
  = IoError String
  | DecodeError JsonDecode.Error


publish : Queue -> Event a -> Cmd Result
publish (Queue name) event = 
  let
    options = JsonEncode.object
      [ ("binding", JsonEncode.string name)
      , ("value", encode event)
      ]

    encode = JsonEncode.string << JsonEncode.encode 0 << Event.encode

    decode = JsonDecode.decodeValue resultDecoder
  in
    Task.attempt 
    (unnestError DecodeError)
    (publishFFI options
      |> Task.mapError IoError
      |> Task.map decode
    )
    

publishFFI : JsonEncode.Value -> Task String JsonDecode.Value
publishFFI _ =  Task.fail "not patched"


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


resultDecoder : JsonDecode.Decoder ()
resultDecoder = 
  JsonDecode.oneOf
  [ JsonDecode.field "published"
    ( JsonDecode.succeed ()
    )
  ]
