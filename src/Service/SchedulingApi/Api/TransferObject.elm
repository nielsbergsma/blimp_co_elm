module Service.SchedulingApi.Api.TransferObject exposing
  ( parseRegisterAirfieldRequest
  , parseAddAirshipToFleetRequest
  , parseScheduleFlightRequest
  , formatRegisterAirfieldResponse
  , formatAddAirshipToFleetResponse
  , formatScheduleFlightResponse
  )

import Time
import Json.Decode as JsonDecode
import Json.Decode.Pipeline as JsonDecode
import Json.Encode as JsonEncode

import Cloudflare.Worker.Fetch as Fetch

import BoundedContext.Scheduling.Aggregate.AirfieldId as AirfieldId
import BoundedContext.Scheduling.Aggregate.AirfieldName as AirfieldName
import BoundedContext.Scheduling.Aggregate.Geohash as Geohash
import BoundedContext.Scheduling.Aggregate.TimeZone as TimeZone
import BoundedContext.Scheduling.Aggregate.AirshipId as AirshipId
import BoundedContext.Scheduling.Aggregate.AirshipName as AirshipName
import BoundedContext.Scheduling.Aggregate.AirshipModel as AirshipModel
import BoundedContext.Scheduling.Aggregate.AirshipNumberOfSeats as AirshipNumberOfSeats
import BoundedContext.Scheduling.Aggregate.FlightId as FlightId

import BoundedContext.Scheduling.Usecase.RegisterAirfield as RegisterAirfieldUseCase
import BoundedContext.Scheduling.Usecase.AddAirshipToFleet as AddAirshipToFleetUseCase
import BoundedContext.Scheduling.Usecase.ScheduleFlight as ScheduleFlightUseCase


-- request / response types
type alias PostAirfieldsRequest =
  { id : String
  , name : String
  , location : String
  , timeZone : String
  }


type alias PostAirfieldsResponse =
  { id : String
  }


type alias PostAirshipsRequest = 
  { id : String
  , name : String
  , model : String
  , numberOfSeats : Int
  }


type alias PostAirshipsResponse = 
  { id : String
  }


type alias PostFlightsRequest = 
  { id : String
  , departureLocation : String
  , departureTime : Int
  , arrivalLocation : String
  , arrivalTime : Int
  , airship : String
  }


type alias PostFlightsResponse = 
  { id : String
  }


--  decoders
postAirfieldsRequestDecoder : JsonDecode.Decoder PostAirfieldsRequest
postAirfieldsRequestDecoder =
  JsonDecode.succeed PostAirfieldsRequest
  |> JsonDecode.required "id" JsonDecode.string
  |> JsonDecode.required "name" JsonDecode.string
  |> JsonDecode.required "location" JsonDecode.string
  |> JsonDecode.required "time_zone" JsonDecode.string


postAirshipsRequestDecoder : JsonDecode.Decoder PostAirshipsRequest
postAirshipsRequestDecoder =
  JsonDecode.succeed PostAirshipsRequest
  |> JsonDecode.required "id" JsonDecode.string
  |> JsonDecode.required "name" JsonDecode.string
  |> JsonDecode.required "model" JsonDecode.string
  |> JsonDecode.required "number_of_seats" JsonDecode.int


postFlightsRequestDecoder : JsonDecode.Decoder PostFlightsRequest
postFlightsRequestDecoder =
  JsonDecode.succeed PostFlightsRequest
  |> JsonDecode.required "id" JsonDecode.string
  |> JsonDecode.required "departure_location" JsonDecode.string
  |> JsonDecode.required "departure_time" JsonDecode.int
  |> JsonDecode.required "arrival_location" JsonDecode.string
  |> JsonDecode.required "arrival_time" JsonDecode.int
  |> JsonDecode.required "airship" JsonDecode.string


-- encoders
encodePostAirfieldsResponse : PostAirfieldsResponse -> JsonEncode.Value
encodePostAirfieldsResponse value =
  JsonEncode.object
  [ ( "id", JsonEncode.string value.id )
  ]


encodePostAirshipsResponse : PostAirshipsResponse -> JsonEncode.Value
encodePostAirshipsResponse value =
  JsonEncode.object
  [ ( "id", JsonEncode.string value.id )
  ]


encodePostFlightsResponse : PostFlightsResponse -> JsonEncode.Value
encodePostFlightsResponse value =
  JsonEncode.object
  [ ( "id", JsonEncode.string value.id )
  ]


-- parsers 
parseRegisterAirfieldRequest : Fetch.Request -> Result Fetch.Response RegisterAirfieldUseCase.Command
parseRegisterAirfieldRequest request =
  JsonDecode.decodeValue postAirfieldsRequestDecoder (Fetch.body request)
  |> Result.mapError (Fetch.unprocessableContent << JsonDecode.errorToString)
  |> Result.andThen (\content ->
      Result.Ok RegisterAirfieldUseCase.Command
      |> mapField (AirfieldId.fromString content.id) AirfieldId.parseProblemToString
      |> mapField (AirfieldName.fromString content.name) AirfieldName.parseProblemToString
      |> mapField (Geohash.fromString content.location) Geohash.parseProblemToString
      |> mapField (TimeZone.fromName content.timeZone) TimeZone.fromNameErrorToString
      |> Result.mapError Fetch.unprocessableContent
     )


parseAddAirshipToFleetRequest : Fetch.Request -> Result Fetch.Response AddAirshipToFleetUseCase.Command
parseAddAirshipToFleetRequest request =
  JsonDecode.decodeValue postAirshipsRequestDecoder (Fetch.body request)
  |> Result.mapError (Fetch.unprocessableContent << JsonDecode.errorToString)
  |> Result.andThen (\content ->
      Result.Ok AddAirshipToFleetUseCase.Command
      |> mapField (AirshipId.fromString content.id) AirshipId.parseProblemToString
      |> mapField (AirshipName.fromString content.name) AirshipName.parseProblemToString
      |> mapField (AirshipModel.fromString content.model) AirshipModel.parseProblemToString
      |> mapField (AirshipNumberOfSeats.fromInt content.numberOfSeats) AirshipNumberOfSeats.fromIntErrorToString
      |> Result.mapError Fetch.unprocessableContent
     )


parseScheduleFlightRequest : Fetch.Request -> Result Fetch.Response ScheduleFlightUseCase.Command
parseScheduleFlightRequest request =
  JsonDecode.decodeValue postFlightsRequestDecoder (Fetch.body request)
  |> Result.mapError (Fetch.unprocessableContent << JsonDecode.errorToString)
  |> Result.andThen (\content ->
      Result.Ok ScheduleFlightUseCase.Command
      |> mapField (FlightId.fromString content.id) FlightId.fromStringErrorToString
      |> mapField (AirfieldId.fromString content.departureLocation) AirfieldId.parseProblemToString
      |> mapField (AirfieldId.fromString content.arrivalLocation) AirfieldId.parseProblemToString
      |> mapFieldOk (Time.millisToPosix content.departureTime) 
      |> mapFieldOk (Time.millisToPosix content.arrivalTime)
      |> mapField (AirshipId.fromString content.airship) AirshipId.parseProblemToString
      |> Result.mapError Fetch.unprocessableContent
     )


-- formatters
formatRegisterAirfieldResponse : RegisterAirfieldUseCase.CommandResult -> Cmd msg 
formatRegisterAirfieldResponse result = 
  case result of
    Err RegisterAirfieldUseCase.AlreadyExist -> 
      Fetch.respond (Fetch.conflict "already exist")

    Err RegisterAirfieldUseCase.VersionConflict -> 
      Fetch.respond (Fetch.conflict "version conflict")

    Err (RegisterAirfieldUseCase.InternalError reason) -> 
      Fetch.respond (Fetch.internalError reason)

    Ok value ->
      Fetch.respond 
      << Fetch.ok 
      << encodePostAirfieldsResponse
      << PostAirfieldsResponse 
      << AirfieldId.toString
      <| value


formatAddAirshipToFleetResponse : AddAirshipToFleetUseCase.CommandResult -> Cmd msg 
formatAddAirshipToFleetResponse result = 
  case result of
    Err AddAirshipToFleetUseCase.AlreadyExist -> 
      Fetch.respond (Fetch.conflict "already exist")

    Err AddAirshipToFleetUseCase.VersionConflict -> 
      Fetch.respond (Fetch.conflict "version conflict")

    Err (AddAirshipToFleetUseCase.InternalError reason) -> 
      Fetch.respond (Fetch.internalError reason)

    Ok value ->
      Fetch.respond 
      << Fetch.ok 
      << encodePostAirshipsResponse
      << PostAirshipsResponse 
      << AirshipId.toString
      <| value


formatScheduleFlightResponse : ScheduleFlightUseCase.CommandResult -> Cmd msg 
formatScheduleFlightResponse result = 
  case result of
    Err ScheduleFlightUseCase.AlreadyExist ->
      Fetch.respond (Fetch.conflict "already exist")

    Err ScheduleFlightUseCase.VersionConflict ->
      Fetch.respond (Fetch.conflict "version conflict")

    Err ScheduleFlightUseCase.UnknownDepartureAirfield ->
      Fetch.respond (Fetch.badRequest "unknown departure airfield")

    Err ScheduleFlightUseCase.UnknownArrivalAirfield ->
      Fetch.respond (Fetch.badRequest "unknown arrival airfield")

    Err ScheduleFlightUseCase.UnknownAirship ->
      Fetch.respond (Fetch.badRequest "unknown airship")

    Err ScheduleFlightUseCase.SameDepartureAndArrivalLocation ->
      Fetch.respond (Fetch.badRequest "same departure and arrival location")

    Err ScheduleFlightUseCase.DepartureIsLaterThenArrival ->
      Fetch.respond (Fetch.badRequest "departure is later then arrival")

    Err (ScheduleFlightUseCase.InternalError reason) ->
      Fetch.respond (Fetch.internalError reason)

    Ok value ->
      Fetch.respond 
      << Fetch.ok 
      << encodePostFlightsResponse
      << PostFlightsResponse
      << FlightId.toString
      <| value


-- helpers
mapField : Result x a -> (x -> error) -> Result error (a -> b) -> Result error b
mapField field toError =
  Result.andThen (\value -> 
    Result.map value (Result.mapError toError field)
  )


mapFieldOk : a -> Result error (a -> b) -> Result error b
mapFieldOk field =
  Result.andThen (\value -> 
    Result.Ok (value field)
  )
