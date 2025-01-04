module BoundedContext.Scheduling.Aggregate.Airfield exposing
  ( Airfield
  , build
  , equals
  , id
  , name
  , location
  , timeZone
  , encode
  , decoder
  )

import Json.Encode as JsonEncode
import Json.Decode as JsonDecode
import Json.Decode.Pipeline as JsonDecode
import BoundedContext.Scheduling.Aggregate.AirfieldId as AirfieldId
import BoundedContext.Scheduling.Aggregate.AirfieldId exposing (AirfieldId)
import BoundedContext.Scheduling.Aggregate.AirfieldName as AirfieldName
import BoundedContext.Scheduling.Aggregate.AirfieldName exposing (AirfieldName)
import BoundedContext.Scheduling.Aggregate.Geohash as Geohash
import BoundedContext.Scheduling.Aggregate.Geohash exposing (Geohash)
import BoundedContext.Scheduling.Aggregate.TimeZone as TimeZone
import BoundedContext.Scheduling.Aggregate.TimeZone exposing (ZoneName)


type Airfield = Airfield
  { id : AirfieldId
  , name : AirfieldName
  , location : Geohash
  , timeZone: ZoneName
  }


id : Airfield -> AirfieldId
id (Airfield value) = value.id


name : Airfield -> AirfieldName
name (Airfield value) = value.name


location : Airfield -> Geohash
location (Airfield value) = value.location


timeZone : Airfield -> ZoneName
timeZone (Airfield value) = value.timeZone


build : AirfieldId -> AirfieldName -> Geohash -> ZoneName -> Airfield
build id_ name_ location_ timeZone_ = Airfield { id = id_, name = name_, location = location_, timeZone = timeZone_ }


equals : Airfield -> Airfield -> Bool
equals (Airfield lhs) (Airfield rhs) = lhs.id == rhs.id


encode : Airfield -> JsonEncode.Value
encode (Airfield value) = JsonEncode.object
  [ ( "id", AirfieldId.encode value.id )
  , ( "name", AirfieldName.encode value.name )
  , ( "location", Geohash.encode value.location )
  , ( "time_zone", TimeZone.encode value.timeZone )
  ]


decoder : JsonDecode.Decoder Airfield
decoder =
  JsonDecode.succeed build
  |> JsonDecode.required "id" AirfieldId.decoder
  |> JsonDecode.required "name" AirfieldName.decoder
  |> JsonDecode.required "location" Geohash.decoder
  |> JsonDecode.required "time_zone" TimeZone.decoder
