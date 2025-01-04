module BoundedContext.Scheduling.Aggregate.Flight exposing 
  ( Flight
  , equals
  , id
  , departure
  , arrival
  , airship
  , build
  , BuildError(..)
  , buildErrorToString
  , encode
  , decoder
  )

import Time
import Json.Encode as JsonEncode
import Json.Decode as JsonDecode
import Json.Decode.Pipeline as JsonDecode
import BoundedContext.Scheduling.Aggregate.FlightId exposing (FlightId)
import BoundedContext.Scheduling.Aggregate.FlightId as FlightId
import BoundedContext.Scheduling.Aggregate.FlightDeparture exposing (FlightDeparture)
import BoundedContext.Scheduling.Aggregate.FlightDeparture as FlightDeparture
import BoundedContext.Scheduling.Aggregate.FlightArrival exposing (FlightArrival)
import BoundedContext.Scheduling.Aggregate.FlightArrival as FlightArrival
import BoundedContext.Scheduling.Aggregate.Airship exposing (Airship)
import BoundedContext.Scheduling.Aggregate.Airship as Airship
import BoundedContext.Scheduling.Aggregate.AirshipId exposing (AirshipId)
import BoundedContext.Scheduling.Aggregate.AirshipId as AirshipId
import BoundedContext.Scheduling.Aggregate.Airfield exposing (Airfield)
import BoundedContext.Scheduling.Aggregate.Airfield as Airfield


type Flight = Flight
  { id : FlightId
  , departure : FlightDeparture
  , arrival : FlightArrival
  , airship : AirshipId
  }


equals : Flight -> Flight -> Bool
equals (Flight lhs) (Flight rhs) = lhs.id == rhs.id


id : Flight -> FlightId
id (Flight details) = details.id


departure : Flight -> FlightDeparture
departure (Flight details) = details.departure 


arrival : Flight -> FlightArrival 
arrival (Flight details) = details.arrival


airship : Flight -> AirshipId 
airship (Flight details) = details.airship


type BuildError
  = SameDepartureAndArrivalLocation
  | DepartureIsLaterThenArrival


buildErrorToString : BuildError -> String
buildErrorToString error = 
  case error of 
    SameDepartureAndArrivalLocation -> "same departure and arrival location"
    DepartureIsLaterThenArrival -> "departure is later then arrival"


build : FlightId -> Time.Posix -> Airfield -> Time.Posix -> Airfield -> Airship -> Result BuildError Flight
build id_ departureTime_ departureLocation_ arrivalTime_ arrivalLocation_ airship_ =
  ensure 
    (departureLocation_ /= arrivalLocation_) SameDepartureAndArrivalLocation
  
  |> then_ (ensure 
      (isEarlier departureTime_ arrivalTime_) DepartureIsLaterThenArrival
    )

  |> then_ (Ok <| 
      Flight 
      { id = id_
      , departure = FlightDeparture.fromTimeAndAirfield 
          departureTime_ 
          (Airfield.id departureLocation_)
      , arrival = FlightArrival.fromTimeAndAirfield 
          arrivalTime_ 
          (Airfield.id arrivalLocation_)
      , airship = Airship.id airship_
      }
    )


encode : Flight -> JsonEncode.Value
encode (Flight details) = JsonEncode.object
  [ ( "id", FlightId.encode details.id )
  , ( "departure", FlightDeparture.encode details.departure )
  , ( "arrival", FlightArrival.encode details.arrival )
  , ( "airship", AirshipId.encode details.airship )
  ]


decoder : JsonDecode.Decoder Flight
decoder =
  JsonDecode.succeed 
  (\id_ departure_ arrival_ airship_ -> Flight { id = id_, departure = departure_, arrival = arrival_, airship = airship_ })
  |> JsonDecode.required "id" FlightId.decoder
  |> JsonDecode.required "departure" FlightDeparture.decoder
  |> JsonDecode.required "arrival" FlightArrival.decoder
  |> JsonDecode.required "airship" AirshipId.decoder


-- helpers
isEarlier : Time.Posix -> Time.Posix -> Bool
isEarlier lhs rhs = Time.posixToMillis lhs < Time.posixToMillis rhs


ensure : Bool -> BuildError -> Result BuildError ()
ensure predicate error = 
  if predicate 
  then Ok ()
  else Err error


then_ : Result x b -> Result x a -> Result x b
then_ a = Result.andThen (always a)