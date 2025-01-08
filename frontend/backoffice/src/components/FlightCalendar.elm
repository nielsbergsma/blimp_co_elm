module Components.FlightCalendar exposing 
  ( Model
  , Message(..)
  , init
  , update
  , view
  )

import Html exposing (Html, node, button, div, text, h2, h3, a)
import Html.Attributes exposing (class, attribute, title, id)
import Html.Events exposing (onClick)
import Components.Icon as Icon
import ISO8601
import Date
import Time
import Task

import List.Extra as List
import Data.Scheduling as SchedulingData


type alias Model = 
  { dashboard: SchedulingData.Dashboard
  , filteredAirships : List SchedulingData.Airship
  , filteredRoutes : List SchedulingData.FlightRoute
  , today : Date.Date
  , month : Month
  , flightDetails : Maybe FlightDetails
  }


type alias Month = Date.Date


type alias FlightDetails = 
  { flight : SchedulingData.Flight
  , date : Date.Date
  , occurred : Bool
  , departureAirfield : SchedulingData.Airfield
  , arrivalAirfield : SchedulingData.Airfield
  , airship : SchedulingData.Airship
  }


type Message
  = AddAirshipFilter SchedulingData.Airship
  | RemoveAirshipFilter SchedulingData.Airship
  | AddRouteFilter SchedulingData.FlightRoute
  | RemoveRouteFilter SchedulingData.FlightRoute
  | SetToday Date.Date
  | SetMonth Month
  | OpenFlightDetails SchedulingData.Flight Date.Date
  | CloseFlightDetails


init : SchedulingData.Dashboard -> (Model, Cmd Message)
init dashboard = 
  let
    -- defaults
    today = Date.fromCalendarDate 1970 Time.Jan 1
    month = Date.fromCalendarDate 1970 Time.Jan 1
  in 
    (Model dashboard [] [] today month Nothing, getToday)


update : Model -> Message -> Model
update model message = case message of
  AddAirshipFilter airship -> 
    { model | filteredAirships = airship :: model.filteredAirships, flightDetails = Nothing }

  RemoveAirshipFilter airship ->
    { model | filteredAirships = List.filter ((/=) airship) model.filteredAirships, flightDetails = Nothing }

  AddRouteFilter route ->
    { model | filteredRoutes = route :: model.filteredRoutes, flightDetails = Nothing }

  RemoveRouteFilter route ->
    { model | filteredRoutes = List.filter ((/=) route) model.filteredRoutes, flightDetails = Nothing }

  SetToday date ->
    { model | month = startOfMonth date, today = date }

  SetMonth month ->
    { model | month = month, flightDetails = Nothing }

  OpenFlightDetails flight date ->
    let 
      occurred = Date.compare model.today date == GT
      departureAirfield = flight.departure.airfield
      arrivalAirfield = flight.arrival.airfield
      airship = flight.airship
      details = FlightDetails flight date occurred departureAirfield arrivalAirfield airship
    in
      { model | flightDetails = Just details }

  CloseFlightDetails ->
    { model | flightDetails = Nothing }


view : Model -> Html Message
view { dashboard, filteredAirships, filteredRoutes, month, today, flightDetails } = 
  div []
  [ viewRouteFilters (routesFromFlights dashboard.flights dashboard.airfields) filteredRoutes
  , viewAirshipFilters (List.sortBy .id dashboard.airships) filteredAirships
  , viewHeader month
  , let
      daysOfMonth = Date.range Date.Day 1 month (nextMonth month)
      flightsOnDay_ = flightsOnDay dashboard.flights filteredRoutes filteredAirships
      occured date = Date.compare today date /= GT
    in
      div [ class "grid grid-cols-7 gap-4 mb-2" ]
      (List.map (\d -> viewDay d (occured d) (flightsOnDay_ d)) daysOfMonth)
  , div [ class "text-sm text-gray-400" ]
    [ Icon.circleInfo [ class "w-4 h-4" ]
    , text " flights are displayed in their local departure and arrival time"
    ]

  -- flight details (popover)
  , case flightDetails of
      Just details -> viewFlightDetails details
      Nothing -> noHtml
  ]


viewHeader : Month -> Html Message
viewHeader month = 
  div [ class "mt-8" ]
  [ h3 [ class "text-xl flex gap-2" ] 
    [ div [ class "w-40 mb-4" ]
      [ text (Date.format "MMMM yyyy" month)
      ]
    , button 
      [ class "flex justify-center items-center w-8 h-8 text-sm rounded-full bg-gray-100 hover:bg-gray-800 hover:text-white" 
      , onClick (SetMonth (previousMonth month))
      ]
      [ Icon.chevronLeft [ class "w-3 h-3 -mt-[0.5em]" ]
      ]
    , button [ class "flex justify-center items-center w-8 h-8 text-sm rounded-full bg-gray-100 hover:bg-gray-800 hover:text-white" 
             , onClick (SetMonth (nextMonth month))
             ]
      [ Icon.chevronRight [ class "w-3 h-3 -mt-[0.5em]" ]
      ]
    ]
  ]


viewDay : Date.Date -> Bool -> List SchedulingData.Flight -> Html Message
viewDay date occurred flights =
  let 
    colOffset = 
      if Date.day date == 1 
      then formatDayColStart date
      else ""
  in 
    div [ class ("rounded-md bg-gray-50 min-h-[6rem] p-2 " ++ colOffset) ]
    [ div [ class "mb-2 text-gray-400 text-xs" ]
      [ text (Date.format "EEE d" date)
      ]
    , div []
      (List.map (viewFlight date occurred) (List.sortWith sortByFlightTime flights))
    ]


viewFlight : Date.Date -> Bool -> SchedulingData.Flight -> Html Message
viewFlight date occurred flight = 
  let 
    background = if occurred then "bg-gray-800" else "bg-gray-500"
    elementId = formatFlightDetailsElementId flight date
  in
    button 
    [ class (background ++ " text-white rounded-md px-2 py-1 mb-1 w-full text-left hover:bg-gray-600")
    , id elementId
    , onClick (OpenFlightDetails flight date)
    ]
    [ div [ class "text-sm" ]
      [ text (formatFlightRoute (SchedulingData.route flight))
      ]
    , div [ class "text-xs" ]
      [ text ((formatDepartureTime date flight) ++ " - " ++ (formatArrivalTime date flight))
      ]
    ]


viewAirshipFilters : List SchedulingData.Airship -> List SchedulingData.Airship -> Html Message
viewAirshipFilters airships filters = 
  div [ class "text-sm my-2" ]
  (List.map (\a -> viewAirshipFilter a (List.member a filters)) airships)


viewAirshipFilter : SchedulingData.Airship -> Bool -> Html Message
viewAirshipFilter airship filtered = 
  if not filtered 
  then
    button [ class "rounded-full mr-2 mb-2 w-40 py-1 px-4 bg-gray-100 hover:bg-gray-800 hover:text-white"
           , onClick (AddAirshipFilter airship) 
           , title airship.name
           ]
    [ text airship.id
    ]
  else
    button [ class "rounded-full mr-2  mb-2 w-40 py-1 px-4 bg-gray-800 text-white hover:bg-gray-600"
           , onClick (RemoveAirshipFilter airship) 
           , title airship.name
           ]
    [ Icon.filter [ class "w-4 h-4 mr-2" ]
    , text airship.id
    ]
  

viewRouteFilters : List SchedulingData.FlightRoute -> List SchedulingData.FlightRoute -> Html Message
viewRouteFilters routes filters = 
  div [ class "text-sm my-2" ]
  (List.map (\route -> 
    viewRouteFilter route (List.member route filters)
    ) routes
  )


viewRouteFilter : SchedulingData.FlightRoute -> Bool -> Html Message
viewRouteFilter route filtered = 
  if not filtered 
  then
    button [ class "rounded-full mr-2 mb-2 w-40 py-1 px-4 bg-gray-100 hover:bg-gray-800 hover:text-white"
           , onClick (AddRouteFilter route) 
           , title (formatFlightRouteNames route)
           ]
    [ text (formatFlightRoute route)
    ]
  else
     button [ class "rounded-full mr-2 mb-2 w-40 py-1 px-4 bg-gray-800 text-white hover:bg-gray-600"
           , onClick (RemoveRouteFilter route)
           , title (formatFlightRouteNames route)
           ]
    [ Icon.filter [ class "w-4 h-4 mr-2" ]
    , text (formatFlightRoute route)
    ]


viewFlightDetails : FlightDetails -> Html Message
viewFlightDetails { flight, date, occurred, departureAirfield, arrivalAirfield, airship } = 
  let 
    forElementId = formatFlightDetailsElementId flight date
    orientation = formatFlightDetailsOrientation date
    orientationClass = 
      case orientation of
        "left" -> " -ml-96" 
        _ -> ""
    backgroundClass = 
      if occurred
      then " bg-gray-500"
      else " bg-gray-800"
  in 
    popover forElementId orientation
    [ div [ class ("w-96 h-80 -mt-28 text-white p-4 rounded-md shadow-lg" ++ backgroundClass ++ orientationClass) ]
      [ h2 [ class "text-2xl mb-2 flex justify-between" ]
        [ text (formatFlightRoute (SchedulingData.route flight))
        , button [ class "rounded-full hover:bg-gray-600 w-8 h-8 flex justify-center items-center", onClick CloseFlightDetails ]
          [ Icon.xmark [ class "h-4 w-4 -mt-1" ]
          ]
        ]

      -- departure
      , div [ class "text-xs pt-4 text-gray-400" ]
        [ text "Departure"
        ]
      , div [ ]
        [ text (ISO8601.toString flight.departure.time)
        ]
      , div [ ]
        [ text (departureAirfield.name ++ " (" ++ departureAirfield.id ++ ")")
        ]

      -- arrival
      , div [ class "text-xs pt-4 text-gray-400" ]
        [ text "Arrival"
        ]
      , div [ ]
        [ text (ISO8601.toString flight.arrival.time)
        ]
      , div [ ]
        [ text (arrivalAirfield.name ++ " (" ++ arrivalAirfield.id ++ ")")
        ]

      -- airship
      , div [ class "text-xs pt-4 text-gray-400" ]
        [ text "Airship"
        ]
      , div []
        [ div []
          [ text (airship.name ++ " (" ++ airship.id ++ ")")
          ]
        , div []
          [ text (airship.model)
          ]
        ]
      ]
    ]

    
popover : String -> String -> List (Html Message) -> Html Message
popover for orientation =
  node "x-popover"
  [ attribute "for" for
  , attribute "orientation" orientation
  ]


-- helpers
formatFlightRoute : SchedulingData.FlightRoute -> String
formatFlightRoute (departure, arrival) =
  departure.id ++ "-" ++ arrival.id


formatFlightRouteNames : SchedulingData.FlightRoute -> String
formatFlightRouteNames (departure, arrival) = 
  departure.name ++ " -> " ++ arrival.name


formatDayColStart : Date.Date -> String
formatDayColStart date = case Date.weekday date of 
  Time.Mon -> "col-start-1"
  Time.Tue -> "col-start-2"
  Time.Wed -> "col-start-3"
  Time.Thu -> "col-start-4"
  Time.Fri -> "col-start-5"
  Time.Sat -> "col-start-6"
  Time.Sun -> "col-start-7"


formatFlightDetailsElementId : SchedulingData.Flight -> Date.Date -> String
formatFlightDetailsElementId flight date = 
  "f-" ++ flight.id ++ "-" ++ String.fromInt (Date.toRataDie date)


formatFlightDetailsOrientation : Date.Date -> String
formatFlightDetailsOrientation date = case Date.weekday date of 
  Time.Mon -> "right"
  Time.Tue -> "right"
  Time.Wed -> "right"
  Time.Thu -> "right"
  Time.Fri -> "left"
  Time.Sat -> "left"
  Time.Sun -> "left"


formatDepartureTime : Date.Date -> SchedulingData.Flight -> String
formatDepartureTime date flight = 
  if date /= flight.departure.date
  then "..."
  else formatTime flight.departure.time


formatArrivalTime : Date.Date -> SchedulingData.Flight -> String
formatArrivalTime date flight = 
  if date /= flight.arrival.date
  then "..."
  else formatTime flight.arrival.time


formatTime : ISO8601.Time -> String
formatTime time = 
  let 
    pad2 n = if n < 10 
             then "0" ++ String.fromInt n
             else String.fromInt n
  in
    pad2 (ISO8601.hour time) ++ ":" ++ pad2 (ISO8601.minute time)


routesFromFlights : List SchedulingData.Flight -> List SchedulingData.Airfield -> List SchedulingData.FlightRoute
routesFromFlights flights airfields = 
  List.map SchedulingData.route flights
  |> List.unique
  |> List.sortBy formatFlightRoute


lookupAirship : SchedulingData.AirshipId -> List SchedulingData.Airship -> Maybe SchedulingData.Airship
lookupAirship id airships = List.find (\a -> a.id == id) airships


flightsOnDay : List SchedulingData.Flight -> List SchedulingData.FlightRoute -> List SchedulingData.Airship -> Date.Date -> List SchedulingData.Flight
flightsOnDay flights filteredRoutes filteredAirships date =
  List.filter (\f -> f.departure.date == date || f.arrival.date == date) flights
  |> List.filter (\f -> filteredRoutes == [] || List.member (SchedulingData.route f) filteredRoutes)
  |> List.filter (\f -> filteredAirships == [] || List.member f.airship filteredAirships)


previousMonth : Month -> Month
previousMonth month = Date.add Date.Months -1 month


nextMonth : Month -> Month
nextMonth month = Date.add Date.Months 1 month


startOfMonth : Month -> Month
startOfMonth date = Date.floor Date.Month date


getToday : Cmd Message
getToday = Task.perform SetToday Date.today


sortByFlightTime : SchedulingData.Flight -> SchedulingData.Flight -> Order
sortByFlightTime a b =
  if a.departure.time /= b.departure.time
  then
    compare (ISO8601.toTime a.departure.time) (ISO8601.toTime b.departure.time)
  else
    compare (ISO8601.toTime a.arrival.time) (ISO8601.toTime b.arrival.time)


noHtml : Html Message
noHtml = text ""
