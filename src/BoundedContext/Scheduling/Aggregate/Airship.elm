module BoundedContext.Scheduling.Aggregate.Airship exposing
  ( Airship
  , build
  , equals
  , id
  , name
  , model
  , numberOfSeats
  , encode
  , decoder
  )

import Json.Encode as JsonEncode
import Json.Decode as JsonDecode
import Json.Decode.Pipeline as JsonDecode
import BoundedContext.Scheduling.Aggregate.AirshipId as AirshipId
import BoundedContext.Scheduling.Aggregate.AirshipId exposing (AirshipId)
import BoundedContext.Scheduling.Aggregate.AirshipName as AirshipName
import BoundedContext.Scheduling.Aggregate.AirshipName exposing (AirshipName)
import BoundedContext.Scheduling.Aggregate.AirshipModel as AirshipModel
import BoundedContext.Scheduling.Aggregate.AirshipModel exposing (AirshipModel)
import BoundedContext.Scheduling.Aggregate.AirshipNumberOfSeats as AirshipNumberOfSeats
import BoundedContext.Scheduling.Aggregate.AirshipNumberOfSeats exposing (AirshipNumberOfSeats)


type Airship = Airfield
  { id : AirshipId
  , name : AirshipName
  , model : AirshipModel
  , numberOfSeats : AirshipNumberOfSeats
  }


id : Airship -> AirshipId
id (Airfield value) = value.id


name : Airship -> AirshipName
name (Airfield value) = value.name


model : Airship -> AirshipModel
model (Airfield value) = value.model


numberOfSeats : Airship -> AirshipNumberOfSeats
numberOfSeats (Airfield value) = value.numberOfSeats


build : AirshipId -> AirshipName -> AirshipModel -> AirshipNumberOfSeats -> Airship
build id_ name_ model_ numberOfPlaces_ = Airfield { id = id_, name = name_, model = model_, numberOfSeats = numberOfPlaces_ }


equals : Airship -> Airship -> Bool
equals (Airfield lhs) (Airfield rhs) = lhs.id == rhs.id


encode : Airship -> JsonEncode.Value
encode (Airfield value) = JsonEncode.object
  [ ( "id", AirshipId.encode value.id )
  , ( "name", AirshipName.encode value.name )
  , ( "model", AirshipModel.encode value.model )
  , ( "number_of_seats", AirshipNumberOfSeats.encode value.numberOfSeats )
  ]


decoder : JsonDecode.Decoder Airship
decoder =
  JsonDecode.succeed build
  |> JsonDecode.required "id" AirshipId.decoder
  |> JsonDecode.required "name" AirshipName.decoder
  |> JsonDecode.required "model" AirshipModel.decoder
  |> JsonDecode.required "number_of_seats" AirshipNumberOfSeats.decoder