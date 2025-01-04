module Prelude.Event exposing 
  ( Type
  , Event
  , defineType
  , build
  , encode
  , decoder
  )

import Json.Encode as JsonEncode
import Json.Decode as JsonDecode


type Type a = Type String (a -> JsonEncode.Value) (JsonDecode.Decoder a)


type Event a = Event (Type a) a


defineType : String -> (a -> JsonEncode.Value) -> (JsonDecode.Decoder a) -> Type a
defineType = Type


build : Type a -> a -> Event a
build type_ instance = Event type_ instance


encode : Event a -> JsonEncode.Value 
encode (Event (Type typeName encoder _) instance) = 
  JsonEncode.object
  [ ( "type", JsonEncode.string typeName )
  , ( "data", encoder instance )
  ]


decoder : (a -> msg) -> Type a -> JsonDecode.Decoder msg
decoder toMsg (Type name _ decode) =
    JsonDecode.field "type" JsonDecode.string
    |> JsonDecode.andThen(\typeName ->
        if typeName /= name
        then JsonDecode.fail "type mismatch"
        else JsonDecode.field "data" decode |> JsonDecode.map toMsg
    )
