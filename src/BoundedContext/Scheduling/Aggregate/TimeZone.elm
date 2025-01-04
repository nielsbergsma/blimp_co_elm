module BoundedContext.Scheduling.Aggregate.TimeZone exposing 
  ( ZoneName
  , name
  , FromNameError(..)
  , fromNameErrorToString
  , fromName
  , encode
  , decoder
  )

import Json.Encode as JsonEncode
import Json.Decode as JsonDecode
import Json.Decode.Pipeline as JsonDecode
import Prelude.Time exposing (isSupportedZoneName)


type ZoneName = ZoneName String


name : ZoneName -> String
name (ZoneName value) = value


type FromNameError 
  = UnknownZone


fromNameErrorToString : FromNameError -> String
fromNameErrorToString error = 
  case error of
    UnknownZone -> "unknown zone"


fromName : String -> Result FromNameError ZoneName
fromName input =
  if isSupportedZoneName input
  then Ok (ZoneName input)
  else Err UnknownZone


encode : ZoneName -> JsonEncode.Value
encode (ZoneName name_) = JsonEncode.string name_


decoder : JsonDecode.Decoder ZoneName
decoder = JsonDecode.string
  |> JsonDecode.andThen
     (\input -> case fromName input of
       Err problem -> JsonDecode.fail (fromNameErrorToString problem)
       Ok value -> JsonDecode.succeed value
     )
