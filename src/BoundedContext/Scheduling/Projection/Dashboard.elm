module BoundedContext.Scheduling.Projection.Dashboard exposing 
  ( Model
  , Message
  , IO
  , Next
  , Event(..)
  , Error(..)
  , errorToString
  , init
  , update
  , Dashboard
  , encodeDashboard
  , dashboardDecoder
  )

import Json.Encode as JsonEncode
import Json.Decode as JsonDecode
import Json.Decode.Pipeline as JsonDecode

import BoundedContext.Scheduling.Aggregate.AirfieldId as AirfieldId
import BoundedContext.Scheduling.Aggregate.AirfieldName as AirfieldName
import BoundedContext.Scheduling.Aggregate.Geohash as Geohash
import BoundedContext.Scheduling.Aggregate.TimeZone as TimeZone
import BoundedContext.Scheduling.Aggregate.AirshipId as AirshipId
import BoundedContext.Scheduling.Aggregate.AirshipName as AirshipName
import BoundedContext.Scheduling.Aggregate.AirshipModel as AirshipModel
import BoundedContext.Scheduling.Aggregate.AirshipNumberOfSeats as AirshipNumberOfSeats
import BoundedContext.Scheduling.Aggregate.FlightId as FlightId
import BoundedContext.Scheduling.Aggregate.FlightDeparture as FlightDeparture
import BoundedContext.Scheduling.Aggregate.FlightArrival as FlightArrival
import BoundedContext.Scheduling.Event exposing (AirfieldRegisteredV1, AirshipAddedToFleetV1, FlightScheduledV1)

import Prelude.Time exposing (Rfc3339Time, formatPosixAsRfc3339)


-- model
type alias Dashboard = 
  { airfields : List Airfield
  , airships : List Airship
  , flights : List Flight
  }


emptyDashboard : Dashboard
emptyDashboard = 
  { airfields = []
  , airships = []
  , flights = []
  }


type alias Airfield = 
  { id : String
  , name : String
  , location : String
  , timeZone : String
  }


type alias Airship = 
  { id : String
  , name : String
  , model : String
  , numberOfSeats: Int
  }


type alias FlightDeparture = 
  { time : Rfc3339Time
  , location : String
  }


type alias FlightArrival = 
  { time : Rfc3339Time
  , location : String
  }


type alias Flight = 
  { id : String
  , departure : FlightDeparture
  , arrival : FlightArrival
  , airship : String
  }


type Event 
  = AirfieldRegisteredV1 AirfieldRegisteredV1
  | AirshipAddedToFleetV1 AirshipAddedToFleetV1
  | FlightScheduledV1 FlightScheduledV1


type Model
  = Initialized IO Next Event
  | ApplyingEvent IO Next Dashboard
  | Failed Error
  | Completed


type Message 
  = StateRetrieved (Result Error (Maybe Dashboard))
  | StateStored (Result Error ())


type alias IO = 
  { retrieveState : Cmd (Result Error (Maybe Dashboard))
  , storeState : Dashboard -> Cmd (Result Error ())
  }


type Error
  = IoError String
  | DecodeError JsonDecode.Error
  | UnknownDepartureAirfield
  | UnknownArrivalAirfield


type alias Next = Result Error () -> Cmd Message


init : IO -> Next -> Event -> ( Model, Cmd Message )
init io next event =
  ( Initialized io next event, retrieveState io)


update : Message -> Model -> (Model, Cmd Message)
update message model =
  case model of 
    -- Initialized state
    Initialized io next event ->
      case message of 
        StateRetrieved (Err error) -> 
          fail next error

        StateRetrieved (Ok state) ->
          case apply event (dashboardOrEmpty state) of
            Ok dashboard_ -> (ApplyingEvent io next dashboard_, storeState io dashboard_)
            Err error -> fail next error

        StateStored _ -> 
          (model, Cmd.none)

    -- Applying Event state 
    ApplyingEvent _ next _ -> 
      case message of 
        StateRetrieved _ ->
          (model, Cmd.none)

        StateStored (Err error) -> 
          fail next error

        StateStored (Ok _) -> 
          (Completed, next (Ok ()))

    -- Final states
    Failed _ ->
      (model, Cmd.none)

    Completed -> 
      (model, Cmd.none)


apply : Event -> Dashboard -> Result Error Dashboard
apply event dashboard = 
  case event of
    AirfieldRegisteredV1 airfieldRegisteredV1 ->
      let 
        newAirfield = Airfield 
          (AirfieldId.toString airfieldRegisteredV1.id)
          (AirfieldName.toString airfieldRegisteredV1.name)
          (Geohash.toString airfieldRegisteredV1.location)
          (TimeZone.name airfieldRegisteredV1.timeZone)

        existingAirfields =
          List.filter (\airfield -> airfield.id /= newAirfield.id) dashboard.airfields
      in 
        Ok { dashboard | airfields = newAirfield :: existingAirfields }

    AirshipAddedToFleetV1 airshipAddedToFleetV1 ->
      let 
        newAirship = Airship
          (AirshipId.toString airshipAddedToFleetV1.id)
          (AirshipName.toString airshipAddedToFleetV1.name)
          (AirshipModel.toString airshipAddedToFleetV1.model)
          (AirshipNumberOfSeats.toInt airshipAddedToFleetV1.numberOfSeats)

        existingAirships =
          List.filter (\airship -> airship.id /= newAirship.id) dashboard.airships
      in
        Ok { dashboard | airships = newAirship :: existingAirships }

    FlightScheduledV1 flightScheduledV1 -> 
      case (findDepartureAirfield flightScheduledV1 dashboard.airfields, findArrivalAirfield flightScheduledV1 dashboard.airfields) of
        (Just departureLocation, Just arrivalLocation) ->
          let 
            departureTime = 
              formatPosixAsRfc3339 departureLocation.timeZone (FlightDeparture.time flightScheduledV1.departure)

            arrivalTime =
              formatPosixAsRfc3339 arrivalLocation.timeZone (FlightArrival.time flightScheduledV1.arrival)

            newFlight = Flight 
              (FlightId.toString flightScheduledV1.id)
              (FlightDeparture departureTime departureLocation.id)
              (FlightArrival arrivalTime arrivalLocation.id)
              (AirshipId.toString flightScheduledV1.airship)

            existingFlights =
              List.filter (\flight -> flight.id /= newFlight.id) dashboard.flights
          in
            Ok { dashboard | flights = newFlight :: existingFlights }

        (Nothing, _) ->
          Err UnknownDepartureAirfield

        (_, Nothing) ->
          Err UnknownArrivalAirfield


-- helpers
fail : Next -> Error -> (Model, Cmd Message)
fail next problem =
  (Failed problem, next (Err problem))


retrieveState : IO -> Cmd Message
retrieveState io = 
  io.retrieveState 
  |> Cmd.map StateRetrieved


storeState : IO -> Dashboard -> Cmd Message
storeState io dashboard = 
  io.storeState dashboard 
  |> Cmd.map StateStored


errorToString : Error -> String
errorToString error = 
  case error of
    IoError reason -> "[i/o error] " ++ reason
    DecodeError reason -> "[decode error] " ++ JsonDecode.errorToString reason
    UnknownDepartureAirfield -> "unkown departure airfield"
    UnknownArrivalAirfield -> "unkown arrival airfield"


findDepartureAirfield : FlightScheduledV1 -> List Airfield -> Maybe Airfield
findDepartureAirfield flightScheduledV1 = 
  findAirfield (AirfieldId.toString (FlightDeparture.location flightScheduledV1.departure))


findArrivalAirfield : FlightScheduledV1 -> List Airfield -> Maybe Airfield
findArrivalAirfield flightScheduledV1 = 
  findAirfield (AirfieldId.toString (FlightArrival.location flightScheduledV1.arrival))


findAirfield : String -> List Airfield -> Maybe Airfield
findAirfield search airfields = 
  case List.filter (\airfield -> airfield.id == search) airfields of
    (a :: _) -> Just a
    _ -> Nothing


dashboardOrEmpty : Maybe Dashboard -> Dashboard
dashboardOrEmpty = Maybe.withDefault emptyDashboard


-- encoders / decoders
encodeDashboard : Dashboard -> JsonEncode.Value
encodeDashboard dashboard = 
  JsonEncode.object
  [ ( "airfields", JsonEncode.list encodeAirfield dashboard.airfields )
  , ( "airships", JsonEncode.list encodeAirship dashboard.airships )
  , ( "flights", JsonEncode.list encodeFlight dashboard.flights)
  ]


dashboardDecoder : JsonDecode.Decoder Dashboard
dashboardDecoder = 
  JsonDecode.succeed Dashboard
  |> JsonDecode.required "airfields" (JsonDecode.list airfieldDecoder)
  |> JsonDecode.required "airships" (JsonDecode.list airshipDecoder)
  |> JsonDecode.required "flights" (JsonDecode.list flightDecoder)


encodeAirfield : Airfield -> JsonEncode.Value
encodeAirfield airfield = 
  JsonEncode.object 
  [ ( "id", JsonEncode.string airfield.id )
  , ( "name", JsonEncode.string airfield.name )
  , ( "location", JsonEncode.string airfield.location )
  , ( "time_zone", JsonEncode.string airfield.timeZone )
  ]


encodeAirship : Airship -> JsonEncode.Value
encodeAirship airship = 
  JsonEncode.object 
  [ ( "id", JsonEncode.string airship.id )
  , ( "name", JsonEncode.string airship.name )
  , ( "model", JsonEncode.string airship.model )
  , ( "number_of_seats", JsonEncode.int airship.numberOfSeats )
  ]


encodeFlight : Flight -> JsonEncode.Value
encodeFlight flight =
  JsonEncode.object
  [ ( "id", JsonEncode.string flight.id )
  , ( "departure", encodeFlightDeparture flight.departure )
  , ( "arrival", encodeFlightArrival flight.arrival )
  , ( "airship", JsonEncode.string flight.airship )
  ]


encodeFlightDeparture : FlightDeparture -> JsonEncode.Value
encodeFlightDeparture departure =
  JsonEncode.object
  [  ( "time", JsonEncode.string departure.time )
  , ( "location", JsonEncode.string departure.location )
  ]


encodeFlightArrival : FlightArrival -> JsonEncode.Value
encodeFlightArrival arrival =
  JsonEncode.object
  [ ( "time", JsonEncode.string arrival.time )
  , ( "location", JsonEncode.string arrival.location )
  ]


airfieldDecoder : JsonDecode.Decoder Airfield
airfieldDecoder =
  JsonDecode.succeed Airfield
  |> JsonDecode.required "id" JsonDecode.string
  |> JsonDecode.required "name" JsonDecode.string
  |> JsonDecode.required "location" JsonDecode.string
  |> JsonDecode.required "time_zone" JsonDecode.string


airshipDecoder : JsonDecode.Decoder Airship
airshipDecoder =
  JsonDecode.succeed Airship
  |> JsonDecode.required "id" JsonDecode.string
  |> JsonDecode.required "name" JsonDecode.string
  |> JsonDecode.required "model" JsonDecode.string
  |> JsonDecode.required "number_of_seats" JsonDecode.int


flightDecoder : JsonDecode.Decoder Flight
flightDecoder =
  JsonDecode.succeed Flight
  |> JsonDecode.required "id" JsonDecode.string
  |> JsonDecode.required "departure" flightDepartureDecoder
  |> JsonDecode.required "arrival" flightArrivalDecoder
  |> JsonDecode.required "airship" JsonDecode.string


flightDepartureDecoder : JsonDecode.Decoder FlightDeparture
flightDepartureDecoder =
  JsonDecode.succeed FlightDeparture
  |> JsonDecode.required "time" JsonDecode.string
  |> JsonDecode.required "location" JsonDecode.string


flightArrivalDecoder : JsonDecode.Decoder FlightArrival
flightArrivalDecoder =
  JsonDecode.succeed FlightArrival
  |> JsonDecode.required "time" JsonDecode.string
  |> JsonDecode.required "location" JsonDecode.string

