module BoundedContext.Scheduling.Aggregate.FlightDeparture exposing 
  ( FlightDeparture
  , fromTimeAndAirfield
  , time
  , timeMillis
  , location
  , encode
  , decoder
  )

import Json.Decode as JsonDecode
import Json.Decode.Pipeline as JsonDecode
import Json.Encode as JsonEncode
import Time exposing (Posix, posixToMillis, millisToPosix)
import BoundedContext.Scheduling.Aggregate.AirfieldId as AirfieldId
import BoundedContext.Scheduling.Aggregate.AirfieldId exposing (AirfieldId)


type FlightDeparture = FlightDeparture Posix AirfieldId


fromTimeAndAirfield : Posix -> AirfieldId -> FlightDeparture
fromTimeAndAirfield = FlightDeparture


time : FlightDeparture -> Posix
time (FlightDeparture value _) = value


timeMillis : FlightDeparture -> Int
timeMillis = time >> posixToMillis


location : FlightDeparture -> AirfieldId
location (FlightDeparture _ value) = value


encode : FlightDeparture -> JsonEncode.Value
encode (FlightDeparture time_ airfield_) = 
  JsonEncode.object
  [ ( "time", JsonEncode.int (posixToMillis time_) )
  , ( "location", AirfieldId.encode airfield_ )
  ]


decoder : JsonDecode.Decoder FlightDeparture
decoder = 
  JsonDecode.succeed FlightDeparture
  |> JsonDecode.required "time" (JsonDecode.int |> JsonDecode.map millisToPosix)
  |> JsonDecode.required "location" (AirfieldId.decoder)
