port module Cloudflare.Worker.Fetch exposing
  ( Request
  , Scope(..)
  , authorized
  , method
  , body
  , Method(..)
  , path
  , subscribeFetch
  , Response(..)
  , respond
  , ok
  , notFound
  , badRequest
  , forbidden
  , conflict
  , unprocessableContent
  , internalError
  , emptyBody
  )

import Url exposing (Url)
import Json.Encode as JsonEncode
import Json.Decode as JsonDecode
import Json.Decode.Pipeline as JsonDecode


-- ports
port fetchRequest : (JsonEncode.Value -> msg) -> Sub msg
port fetchResponse : (Int, JsonEncode.Value) -> Cmd msg


-- request
type Method = Get | Post | Put


type alias Status = Int


type alias Body = JsonEncode.Value


type Request = Request Method Url Authorization Body


method : Request -> Method
method (Request value _ _ _) = value


authorization : Request -> Authorization
authorization (Request _ _ value _) = value


body : Request -> Body 
body (Request _ _ _ value) = value


subscribeFetch : (Request -> message) -> (String -> message) -> Sub message
subscribeFetch succeed fail =
  fetchRequest (\input ->
    case JsonDecode.decodeValue requestDecoder input of
      Ok request -> succeed request
      Err error -> fail (JsonDecode.errorToString error)
  )


requestDecoder : JsonDecode.Decoder Request
requestDecoder =
  JsonDecode.succeed Request
  |> JsonDecode.required "method" methodDecoder
  |> JsonDecode.required "url" urlDecoder
  |> JsonDecode.required "authorization" authorizationDecoder
  |> JsonDecode.required "body" JsonDecode.value


methodDecoder : JsonDecode.Decoder Method
methodDecoder = JsonDecode.string
  |> JsonDecode.andThen (\input ->
      case input of
        "GET"  -> JsonDecode.succeed Get
        "POST" -> JsonDecode.succeed Post
        "PUT" -> JsonDecode.succeed Put
        other  -> JsonDecode.fail ("unknown verb" ++ other)
   )


urlDecoder : JsonDecode.Decoder Url
urlDecoder = JsonDecode.string
  |> JsonDecode.andThen (\input ->
      case Url.fromString input of
        Just url -> JsonDecode.succeed url
        Nothing -> JsonDecode.fail "malformed url"
   )


path : Request -> List String
path (Request _ url _ _) =
  String.split "/" url.path
  |> List.filter (\segment -> String.length segment > 0)


-- response
type Response =
  Response Status Body


respond : Response -> Cmd msg
respond (Response code body_) =
  fetchResponse (code, body_)


ok : JsonEncode.Value -> Response
ok body_ =
  Response 200 body_


notFound : Response
notFound =
  Response 404 emptyBody


badRequest : String -> Response
badRequest error =
  Response 400 <| JsonEncode.object
    [ ("error", JsonEncode.string error)
    ]


forbidden : Response
forbidden =
  Response 403 <| JsonEncode.object
    [ ("error", JsonEncode.string "forbidden")
    ]


conflict : String -> Response
conflict error =
  Response 409 <| JsonEncode.object
    [ ("error", JsonEncode.string error)
    ]


unprocessableContent : String -> Response
unprocessableContent error =
  Response 422 <| JsonEncode.object
    [ ("error", JsonEncode.string error)
    ]


internalError : String -> Response
internalError error =
  Response 500 <| JsonEncode.object
    [ ("error", JsonEncode.string error)
    ]


emptyBody : JsonEncode.Value
emptyBody = JsonEncode.object []


-- authorization
type Scope = Agent


type alias Authorization = 
  { scopes : List Scope
  }


authorized : Scope -> Request -> Bool
authorized scope request = 
  let
    { scopes } = authorization request
  in
    List.member scope scopes  


authorizationDecoder : JsonDecode.Decoder Authorization
authorizationDecoder =
  JsonDecode.succeed Authorization
  |> JsonDecode.required "scopes" (JsonDecode.list scopeDecoder)


scopeDecoder : JsonDecode.Decoder Scope
scopeDecoder = JsonDecode.string
  |> JsonDecode.andThen (\input ->
      case input of
        "agent" -> JsonDecode.succeed Agent
        other   -> JsonDecode.fail ("unknown scope: " ++ other)
   )