module BoundedContext.Scheduling.Aggregate.FlightArrival exposing 
  ( FlightArrival
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


type FlightArrival = FlightArrival Posix AirfieldId


fromTimeAndAirfield : Posix -> AirfieldId -> FlightArrival
fromTimeAndAirfield = FlightArrival


time : FlightArrival -> Posix
time (FlightArrival value _) = value


timeMillis : FlightArrival -> Int
timeMillis = time >> posixToMillis


location : FlightArrival -> AirfieldId
location (FlightArrival _ value) = value


encode : FlightArrival -> JsonEncode.Value
encode (FlightArrival time_ airfield_) = 
  JsonEncode.object
  [ ( "time", JsonEncode.int (posixToMillis time_) )
  , ( "location", AirfieldId.encode airfield_)
  ]


decoder : JsonDecode.Decoder FlightArrival
decoder = 
  JsonDecode.succeed FlightArrival
  |> JsonDecode.required "time" (JsonDecode.int |> JsonDecode.map millisToPosix)
  |> JsonDecode.required "location" (AirfieldId.decoder)
