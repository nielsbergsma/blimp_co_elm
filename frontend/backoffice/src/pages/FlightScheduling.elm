module Pages.FlightScheduling exposing (Model, Message(..), init, update, view)

import Html exposing (Html, div, text, h2, h3, img, a)
import Html.Attributes exposing (class, src, href, target)
import Components.FlightCalendar as FlightCalendar
import Components.Icon as Icon

import Http exposing (Error)
import Session exposing (Session)
import Data.Scheduling as SchedulingData
import Geohash
import Round


type Model 
  = Loading
  | Loaded 
    { dashboard : SchedulingData.Dashboard
    , calendar : FlightCalendar.Model
    }
  | LoadFailed { error : Http.Error }


type Message 
  = LoadedDashboard (Result Error SchedulingData.Dashboard)
  | FlightCalendarMessage FlightCalendar.Message


init : Session -> (Model, Cmd Message)
init session = (Loading, SchedulingData.getDashboard session |> Cmd.map LoadedDashboard)


update : Session -> Model -> Message -> (Model, Cmd Message)
update _ model message = case (model, message) of
  (Loading, LoadedDashboard (Ok data)) ->
    let
      (flightCalendarState, flightCalendarCmd) = FlightCalendar.init data
    in
      (Loaded { dashboard = data, calendar = flightCalendarState }, flightCalendarCmd |> Cmd.map FlightCalendarMessage)

  (Loading, LoadedDashboard (Err error)) ->
    (LoadFailed { error = error }, Cmd.none)

  (Loaded state, FlightCalendarMessage flightCalendarMessage) ->
    (Loaded { state | calendar = FlightCalendar.update state.calendar flightCalendarMessage }, Cmd.none)

  _ -> (model, Cmd.none)


view : Model -> Html Message
view model = case model of
  Loading -> 
    div [ class "flex justify-center items-center" ] 
    [ div [ class "bg-gray-800 text-white w-96 p-4 -mt-6 rounded-b-md text-center" ] 
      [ Icon.spinner [ class "w-4 h-4 mr-2" ]
      , text "Fetching dashboard data"
      ]
    ]

  Loaded { dashboard, calendar } -> 
    div [ class "flex flex-col text-gray-700" ] 
    [ h2 [ class "text-2xl mb-2" ] 
      [ text "Fleet"
      ]
    , div [ class "overflow-x-scroll whitespace-nowrap mb-8" ]
      (List.sortBy .id dashboard.airships |> List.map viewAirship)

    , h2 [ class "text-2xl mb-2" ]
      [ text "Flights"
      ]
    , div [ class "mb-8" ]
      [ FlightCalendar.view calendar |> Html.map FlightCalendarMessage
      ]

    , h2 [ class "text-2xl mb-2" ]
      [ text "Airfields"
      ]
    , div [ class "overflow-x-scroll whitespace-nowrap mb-8" ]
      (List.sortBy .name dashboard.airfields |> List.map viewAirfield)
    ]

  LoadFailed _ -> 
    div [ class "flex justify-center items-center" ] 
    [ div [ class "bg-gray-800 text-gray-600 text-white w-96 p-4 -mt-6 rounded-b-md text-center" ] 
      [ Icon.heartCrack [ class "w-4 h-4 mr-2" ]
      , text "Failed fetching dashboard data"
      ]
    ]


viewAirship : SchedulingData.Airship -> Html Message
viewAirship airship =
  div [ class "bg-gray-50 rounded-md p-4 w-64 inline-block mr-4 mb-4" ]
  [ h3 [ class "text-xl mb-2" ]
    [ text airship.id
    ]
  , img [ class "rounded-md h-32 w-full object-cover", src ("/img/airships/" ++ airship.model ++ ".webp")  ]
    []
  , div [ class "text-xs pt-2 text-gray-400" ]
    [ text "Name"
    ]
  , text airship.name
  , div [ class "text-xs pt-2 text-gray-400" ]
    [ text "Model"
    ]
  , text airship.model
  , div [ class "text-xs pt-2 text-gray-400" ]
    [ text "Registration code"
    ]
  , text airship.id
  , div [ class "text-xs pt-2 text-gray-400" ]
    [ text "Number of seats"
    ]
  , text (String.fromInt airship.numberOfSeats)
  ]


viewAirfield : SchedulingData.Airfield -> Html Message
viewAirfield airfield = 
  div [ class "bg-gray-50 rounded-md p-4 w-64 inline-block mr-4 mb-4" ]
  [ h3 [ class "text-xl mb-2" ]
    [ text airfield.id
    ]
  , a [ target "_blank", href (formatLocationAsGoogleMapsUrl airfield.location) ]
    [ img [ class "rounded-md h-32 w-full object-cover", src ("/img/airfields/" ++ airfield.id ++ ".webp")  ]
      [
      ]
    ]
  , div [ class "text-xs pt-2 text-gray-400" ]
    [ text "Name"
    ]
  , text airfield.name
  , div [ class "text-xs pt-2 text-gray-400" ]
    [ text "ICAO code"
    ]
  , text airfield.id
  , div [ class "text-xs pt-2 text-gray-400" ]
    [ text "Coordinates (DD)"
    ]
  , text (formatLocationCoordinatesDD airfield.location)
  ]


-- helpers
formatLocationAsGoogleMapsUrl : SchedulingData.GeoHash -> String
formatLocationAsGoogleMapsUrl hash = 
  let 
    { lat, lon } = Geohash.decodeCoordinate hash
  in
    "https://www.google.com/maps/search/?api=1&query=" ++ (String.fromFloat lat) ++ "," ++ (String.fromFloat lon)


formatLocationCoordinatesDD : SchedulingData.GeoHash -> String
formatLocationCoordinatesDD hash = 
  let 
    { lat, lon } = Geohash.decodeCoordinate hash

    formattedLatitude = 
      if lat < 0
      then (Round.round 2 -lat) ++ "° S"
      else (Round.round 2 lat) ++ "° N"

    formattedLongitude = 
      if lon < 0
      then (Round.round 2 -lon) ++ "° W"
      else (Round.round 2 lon) ++ "° E"
  in
    formattedLatitude ++ ", " ++ formattedLongitude
