module BoundedContext.Scheduling.Event exposing
  ( AirfieldRegisteredV1
  , airfieldRegisteredV1Type
  , buildAirfieldRegisteredV1
  , AirshipAddedToFleetV1
  , airshipAddedToFleetV1Type
  , buildAirshipAddedToFleetV1
  , FlightScheduledV1
  , flightScheduledV1Type
  , buildFlightScheduledV1
  )

import Json.Encode as JsonEncode
import Json.Decode as JsonDecode
import Json.Decode.Pipeline as JsonDecode
import Prelude.Event as Event

import BoundedContext.Scheduling.Aggregate.AirfieldId exposing (AirfieldId)
import BoundedContext.Scheduling.Aggregate.AirfieldId as AirfieldId
import BoundedContext.Scheduling.Aggregate.AirfieldName exposing (AirfieldName)
import BoundedContext.Scheduling.Aggregate.AirfieldName as AirfieldName
import BoundedContext.Scheduling.Aggregate.Geohash exposing (Geohash)
import BoundedContext.Scheduling.Aggregate.Geohash as Geohash
import BoundedContext.Scheduling.Aggregate.TimeZone exposing (ZoneName)
import BoundedContext.Scheduling.Aggregate.TimeZone as TimeZone
import BoundedContext.Scheduling.Aggregate.AirshipId exposing (AirshipId)
import BoundedContext.Scheduling.Aggregate.AirshipId as AirshipId
import BoundedContext.Scheduling.Aggregate.AirshipName exposing (AirshipName)
import BoundedContext.Scheduling.Aggregate.AirshipName as AirshipName
import BoundedContext.Scheduling.Aggregate.AirshipModel exposing (AirshipModel)
import BoundedContext.Scheduling.Aggregate.AirshipModel as AirshipModel
import BoundedContext.Scheduling.Aggregate.AirshipNumberOfSeats exposing (AirshipNumberOfSeats)
import BoundedContext.Scheduling.Aggregate.AirshipNumberOfSeats as AirshipNumberOfSeats
import BoundedContext.Scheduling.Aggregate.FlightId exposing (FlightId)
import BoundedContext.Scheduling.Aggregate.FlightId as FlightId
import BoundedContext.Scheduling.Aggregate.FlightDeparture exposing (FlightDeparture)
import BoundedContext.Scheduling.Aggregate.FlightDeparture as FlightDeparture
import BoundedContext.Scheduling.Aggregate.FlightArrival exposing (FlightArrival)
import BoundedContext.Scheduling.Aggregate.FlightArrival as FlightArrival


-- AirfieldRegisteredV1
type alias AirfieldRegisteredV1 =
  { id : AirfieldId
  , name : AirfieldName
  , location : Geohash
  , timeZone : ZoneName
  }


airfieldRegisteredV1Type : Event.Type AirfieldRegisteredV1
airfieldRegisteredV1Type = Event.defineType "AirfieldRegisteredV1" encodeAirfieldRegisteredV1 airfieldRegisteredV1Decoder


buildAirfieldRegisteredV1 : AirfieldRegisteredV1 -> Event.Event AirfieldRegisteredV1
buildAirfieldRegisteredV1 = Event.build airfieldRegisteredV1Type


encodeAirfieldRegisteredV1 : AirfieldRegisteredV1 -> JsonEncode.Value
encodeAirfieldRegisteredV1 event = JsonEncode.object
  [ ( "id", AirfieldId.encode event.id )
  , ( "name", AirfieldName.encode event.name )
  , ( "location", Geohash.encode event.location )
  , ( "time_zone", TimeZone.encode event.timeZone )
  ]


airfieldRegisteredV1Decoder : JsonDecode.Decoder AirfieldRegisteredV1
airfieldRegisteredV1Decoder =
  JsonDecode.succeed AirfieldRegisteredV1
  |> JsonDecode.required "id" AirfieldId.decoder
  |> JsonDecode.required "name" AirfieldName.decoder
  |> JsonDecode.required "location" Geohash.decoder
  |> JsonDecode.required "time_zone" TimeZone.decoder


-- AirshipAddedToFleetV1
airshipAddedToFleetV1Type : Event.Type AirshipAddedToFleetV1
airshipAddedToFleetV1Type = Event.defineType "AirshipAddedToFleetV1" encodeAirshipAddedToFleetV1 airshipAddedToFleetV1Decoder


buildAirshipAddedToFleetV1 : AirshipAddedToFleetV1 -> Event.Event AirshipAddedToFleetV1
buildAirshipAddedToFleetV1 = Event.build airshipAddedToFleetV1Type


type alias AirshipAddedToFleetV1 =
  { id : AirshipId
  , name : AirshipName
  , model : AirshipModel
  , numberOfSeats : AirshipNumberOfSeats
  }


encodeAirshipAddedToFleetV1 : AirshipAddedToFleetV1 -> JsonEncode.Value
encodeAirshipAddedToFleetV1 event = JsonEncode.object
  [ ( "id", AirshipId.encode event.id )
  , ( "name", AirshipName.encode event.name )
  , ( "model", AirshipModel.encode event.model )
  , ( "number_of_seats", AirshipNumberOfSeats.encode event.numberOfSeats )
  ]


airshipAddedToFleetV1Decoder : JsonDecode.Decoder AirshipAddedToFleetV1 
airshipAddedToFleetV1Decoder =
  JsonDecode.succeed AirshipAddedToFleetV1
  |> JsonDecode.required "id" AirshipId.decoder
  |> JsonDecode.required "name" AirshipName.decoder
  |> JsonDecode.required "model" AirshipModel.decoder
  |> JsonDecode.required "number_of_seats" AirshipNumberOfSeats.decoder


-- FlightScheduledV1
flightScheduledV1Type : Event.Type FlightScheduledV1
flightScheduledV1Type = Event.defineType "FlightScheduledV1" encodeFlightScheduledV1 flightScheduledV1Decoder


buildFlightScheduledV1 : FlightScheduledV1 -> Event.Event FlightScheduledV1
buildFlightScheduledV1 = Event.build flightScheduledV1Type


type alias FlightScheduledV1 = 
  { id : FlightId
  , departure : FlightDeparture
  , arrival : FlightArrival
  , airship : AirshipId
  }


encodeFlightScheduledV1 : FlightScheduledV1 -> JsonEncode.Value
encodeFlightScheduledV1 event = JsonEncode.object
  [ ( "id", FlightId.encode event.id )
  , ( "departure", FlightDeparture.encode event.departure )
  , ( "arrival", FlightArrival.encode event.arrival )
  , ( "airship", AirshipId.encode event.airship )
  ]
  

flightScheduledV1Decoder : JsonDecode.Decoder FlightScheduledV1 
flightScheduledV1Decoder =
  JsonDecode.succeed FlightScheduledV1
  |> JsonDecode.required "id" FlightId.decoder
  |> JsonDecode.required "departure" FlightDeparture.decoder
  |> JsonDecode.required "arrival" FlightArrival.decoder
  |> JsonDecode.required "airship" AirshipId.decoder
