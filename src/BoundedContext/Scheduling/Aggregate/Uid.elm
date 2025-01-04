module BoundedContext.Scheduling.Aggregate.Uid exposing 
  ( Uid
  , Error(..)
  , errorToString
  , fromString
  , toString
  , encode
  , decoder
  )

import Json.Encode as JsonEncode
import Json.Decode as JsonDecode
import Base exposing (b36, fromInt, toInt)


type Uid = Uid Int


type Error 
  = MalformedValue


errorToString : Error -> String
errorToString error =
  case error of
    MalformedValue -> "malformed value"


fromString : String -> Result Error Uid
fromString input = 
  case toInt b36 input of
    Ok value -> Ok (Uid value)
    Err _ -> Err MalformedValue


toString : Uid -> String
toString (Uid value) = 
  fromInt b36 value


encode : Uid -> JsonEncode.Value
encode = JsonEncode.string << toString 


decoder : JsonDecode.Decoder Uid
decoder = JsonDecode.string
  |> JsonDecode.andThen
     (\input -> case fromString input of
       Err problem -> JsonDecode.fail (errorToString problem)
       Ok value -> JsonDecode.succeed value
     )
