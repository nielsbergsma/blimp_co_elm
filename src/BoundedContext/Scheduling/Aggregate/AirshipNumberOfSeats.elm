module BoundedContext.Scheduling.Aggregate.AirshipNumberOfSeats exposing 
  ( AirshipNumberOfSeats
  , FromIntError(..)
  , fromIntErrorToString
  , fromInt
  , toInt
  , encode
  , decoder
  )

import Json.Decode as JsonDecode
import Json.Encode as JsonEncode


type AirshipNumberOfSeats 
  = AirshipNumberOfSeats Int


type FromIntError 
  = OutOfRange


fromIntErrorToString : FromIntError -> String
fromIntErrorToString error = 
  case error of
    OutOfRange -> "out or range"


fromInt : Int -> Result FromIntError AirshipNumberOfSeats
fromInt input = 
  if input < 1 || input > 999
  then Err OutOfRange
  else Ok (AirshipNumberOfSeats input)


toInt : AirshipNumberOfSeats -> Int
toInt (AirshipNumberOfSeats value) = value


encode : AirshipNumberOfSeats -> JsonEncode.Value
encode (AirshipNumberOfSeats value) = JsonEncode.int value


decoder : JsonDecode.Decoder AirshipNumberOfSeats
decoder = JsonDecode.int
  |> JsonDecode.andThen
    (\input -> case fromInt input of
      Err problem -> JsonDecode.fail (fromIntErrorToString problem)
      Ok value -> JsonDecode.succeed value
    )
