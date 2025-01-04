module BoundedContext.Scheduling.Aggregate.FlightId exposing 
  ( FlightId
  , FromStringError(..)
  , fromStringErrorToString
  , fromString
  , toString
  , equals
  , encode
  , decoder
  )

import Json.Encode as JsonEncode
import Json.Decode as JsonDecode

import BoundedContext.Scheduling.Aggregate.Uid as Uid
import BoundedContext.Scheduling.Aggregate.Uid exposing (Uid)


type FlightId = FlightId Uid


type FromStringError
  = MalformedValue


fromStringErrorToString : FromStringError -> String
fromStringErrorToString error = 
  case error of 
    MalformedValue -> "malformed value"


equals : FlightId -> FlightId -> Bool
equals (FlightId lhs) (FlightId rhs) = lhs == rhs


fromString : String -> Result FromStringError FlightId
fromString input = 
  case Uid.fromString input of
    Ok value -> Ok (FlightId value)
    Err Uid.MalformedValue -> Err MalformedValue


toString : FlightId -> String
toString (FlightId value) = Uid.toString value


encode : FlightId -> JsonEncode.Value
encode (FlightId value) = Uid.encode value


decoder : JsonDecode.Decoder FlightId
decoder = JsonDecode.map FlightId Uid.decoder
