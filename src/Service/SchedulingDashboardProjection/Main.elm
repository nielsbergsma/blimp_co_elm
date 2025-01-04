module Service.SchedulingDashboardProjection.Main exposing (..)

import BoundedContext.Scheduling.Event as Event
import BoundedContext.Scheduling.Projection.Dashboard as Dashboard
import Service.SchedulingDashboardProjection.Repository.Dashboard as DashboardRepository

import Platform
import Prelude.Event as Event
import Json.Decode as JsonDecode

import Cloudflare.Worker.Queue as Queue


type Message
  = Failure String
  | EventReceived Dashboard.Event
  | DashboardProjectionMessage Dashboard.Message


type Model
  = Initialised
  | ProjectDashboard Dashboard.Model


main : Program () Model Message
main =
  Platform.worker
  { init = init
  , subscriptions = always (Queue.subscribeReceive EventReceived Failure decodeEvent)
  , update = update
  }


init : () -> (Model, Cmd Message)
init _ = (Initialised, Cmd.none)


update : Message -> Model -> (Model, Cmd Message)
update message model =
  case message of
    EventReceived event ->
      dispatch model event

    DashboardProjectionMessage projectionMessage ->
      case model of
        ProjectDashboard projectionModel ->
          Dashboard.update projectionMessage projectionModel 
          |> mapMM ProjectDashboard DashboardProjectionMessage

        _ ->
          (model, Cmd.none)
      
    Failure reason ->
      (model, Queue.nack reason)
    

dispatch : Model -> Dashboard.Event -> (Model, Cmd Message)
dispatch _ event = 
  let 
    io = Dashboard.IO 
      DashboardRepository.get 
      DashboardRepository.set

    next = \result ->
      case result of 
        Ok _ -> Queue.ack ()
        Err error -> Queue.nack (Dashboard.errorToString error)
  in
    Dashboard.init io next event
    |> mapMM ProjectDashboard DashboardProjectionMessage


decodeEvent : JsonDecode.Decoder Dashboard.Event
decodeEvent =
  JsonDecode.oneOf
  [ Event.decoder Dashboard.AirfieldRegisteredV1 Event.airfieldRegisteredV1Type
  , Event.decoder Dashboard.AirshipAddedToFleetV1 Event.airshipAddedToFleetV1Type
  , Event.decoder Dashboard.FlightScheduledV1 Event.flightScheduledV1Type
  ]


-- helpers
mapMM : (a -> b) -> (c -> msg) -> ( a, Cmd c ) -> ( b, Cmd msg )
mapMM toModel toCmd (model, cmd) = 
  (toModel model, Cmd.map toCmd cmd)
