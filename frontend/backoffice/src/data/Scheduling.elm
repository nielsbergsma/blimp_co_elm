module Data.Scheduling exposing 
  ( Dashboard
  , AirshipId
  , Airship
  , AirfieldId
  , Airfield
  , Flight
  , FlightRoute
  , route
  , GeoHash
  , getDashboard
  )

import Http
import Time
import ISO8601
import Date
import Session exposing (Session)
import Json.Decode exposing (Decoder, list, int, map, string, andThen, field, succeed, fail)
import Json.Decode.Pipeline exposing (required)


-- model
type alias Dashboard = 
  { airfields: List Airfield
  , airships: List Airship
  , flights: List Flight
  }


type alias AirshipId = String


type alias Airship = 
  { id : AirshipId
  , name : String
  , model : String
  , numberOfSeats : Int 
  }


type alias AirfieldId = String


type alias TimeZone = String


type alias Airfield = 
  { id : AirfieldId
  , name : String
  , location : GeoHash 
  }


type alias GeoHash = String


type alias FlightRoute = (Airfield, Airfield)


type alias Flight = 
  { id : String
  , departure : FlightDeparture
  , arrival : FlightArrival
  , airship : Airship
  }


route : Flight -> FlightRoute
route flight = ( flight.departure.airfield, flight.arrival.airfield )


type alias FlightDeparture = 
  { date : Date.Date
  , time : ISO8601.Time
  , airfield : Airfield
  }


type alias FlightArrival = 
  { date : Date.Date
  , time : ISO8601.Time
  , airfield : Airfield
  }


baseUrl : String
baseUrl = "http://127.0.0.1:5000/buckets/scheduling"


-- requests
getDashboard : Session -> Cmd (Result Http.Error Dashboard)
getDashboard _ = 
  Http.request
  { method = "GET"
  , url = baseUrl ++ "/dashboard"
  , headers = []
  , body = Http.emptyBody
  , expect = Http.expectJson identity dashboardDecoder
  , timeout = Nothing
  , tracker = Nothing
  }


-- decoders
dashboardDecoder : Decoder Dashboard
dashboardDecoder = 
  field "airfields" (list airfieldDecoder)
  |> andThen (\airfields -> field "airships" (list airshipDecoder) 
  |> andThen (\airships -> field "flights" (list (flightDecoder airfields airships))
  |> map (Dashboard airfields airships)))


flightDecoder : List Airfield -> List Airship -> Decoder Flight
flightDecoder airfields airships =
  succeed Flight
  |> required "id" string
  |> required "departure" (flightDepartureDecoder airfields)
  |> required "arrival" (flightArrivalDecoder airfields)
  |> required "airship" (flightAirshipDecoder airships)


flightDepartureDecoder : List Airfield -> Decoder FlightDeparture
flightDepartureDecoder airfields = 
  (field "location" string) 
  |> andThen (justDecoder << find airfields)
  |> andThen (\airfield -> field "time" timeDecoder
  |> map (flightDepartureFromAirfieldAndTime airfield))


flightArrivalDecoder : List Airfield -> Decoder FlightArrival
flightArrivalDecoder airfields = 
  (field "location" string) 
  |> andThen (justDecoder << find airfields)
  |> andThen (\airfield -> field "time" timeDecoder
  |> map (flightArrivalFromAirfieldAndTime airfield))


flightAirshipDecoder : List Airship -> Decoder Airship
flightAirshipDecoder airships = 
  string 
  |> map (find airships) 
  |> andThen justDecoder


airshipDecoder : Decoder Airship
airshipDecoder = succeed Airship
  |> required "id" string
  |> required "name" string
  |> required "model" string
  |> required "number_of_seats" int


airfieldDecoder : Decoder Airfield
airfieldDecoder = succeed Airfield
  |> required "id" string
  |> required "name" string
  |> required "location" string


-- helpers
timeDecoder : Decoder ISO8601.Time
timeDecoder = 
  string 
  |> map ISO8601.fromString
  |> andThen okDecoder


flightDepartureFromAirfieldAndTime : Airfield -> ISO8601.Time -> FlightDeparture
flightDepartureFromAirfieldAndTime airfield time =
  FlightDeparture (dateFromTime time) time airfield


flightArrivalFromAirfieldAndTime : Airfield -> ISO8601.Time -> FlightArrival
flightArrivalFromAirfieldAndTime airfield time =
  FlightArrival (dateFromTime time) time airfield


dateFromTime : ISO8601.Time -> Date.Date
dateFromTime time = 
  Date.fromCalendarDate 
    (ISO8601.year time) 
    (ISO8601.month time |> Date.numberToMonth) 
    (ISO8601.day time)


justDecoder : Maybe a -> Decoder a
justDecoder input = 
  case input of
    Just value -> succeed value
    Nothing -> fail "no value"


okDecoder : Result String a -> Decoder a
okDecoder result =
  case result of
    Ok value -> succeed value
    Err error -> fail error


find : List { a | id: String } -> String -> Maybe { a | id: String }
find items search = 
  case items of
    [] -> Nothing
    (head::tail) -> 
      if head.id == search
      then Just head
      else find tail search
