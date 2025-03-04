module BoundedContext.Scheduling.Usecase.RegisterAirfield exposing 
  ( Model
  , Error(..)
  , Message(..)
  , IO
  , Command
  , CommandResult
  , init
  , update
  )

import BoundedContext.Scheduling.Aggregate.Airfield exposing (Airfield)
import BoundedContext.Scheduling.Aggregate.Airfield as Airfield
import BoundedContext.Scheduling.Aggregate.AirfieldId exposing (AirfieldId)
import BoundedContext.Scheduling.Aggregate.AirfieldName exposing (AirfieldName)
import BoundedContext.Scheduling.Aggregate.Geohash exposing (Geohash)
import BoundedContext.Scheduling.Aggregate.TimeZone exposing (ZoneName)
import BoundedContext.Scheduling.Event as Event

import Cloudflare.Worker.DurableObject.BeginTransaction as BeginTransaction
import Cloudflare.Worker.DurableObject.CommitTransaction as CommitTransaction
import Prelude.Event as Event
import Cloudflare.Worker.Queue as Queue

import Prelude.Transaction as Transaction


type alias Model =
  { io : IO
  , next : Next
  , state : State
  }


type State
  = BeginningTransaction Airfield
  | CommittingTransaction Airfield
  | PublishingEvent Airfield

type alias StateHandler = IO -> Message -> Transition

type alias Transition = State -> (Result Error State, Cmd Message)


type Error
  = AlreadyExist
  | VersionConflict
  | InternalError String


type Message 
  = BeginTransactionCompleted (BeginTransaction.Result Airfield)
  | CommitTransactionCompleted (CommitTransaction.Result Airfield)
  | EventPublishCompleted Queue.Result


type alias IO =
  { publish : Event.Event Event.AirfieldRegisteredV1 -> Cmd (Queue.Result)
  , beginTransaction : AirfieldId -> Cmd (BeginTransaction.Result Airfield)
  , commitTransaction : Transaction.Transaction Airfield -> Cmd (CommitTransaction.Result Airfield)
  }


type alias Command = 
  { id : AirfieldId
  , name : AirfieldName
  , location : Geohash
  , timeZone : ZoneName
  }


type alias CommandResult 
  = Result Error AirfieldId


type alias Next = CommandResult -> Cmd Message


init : IO -> Next -> Command -> (Model, Cmd Message)
init io next command =
  let 
    airfield =
      Airfield.build command.id command.name command.location command.timeZone

    state =
      BeginningTransaction airfield

    beginTransaction =
      io.beginTransaction command.id |> Cmd.map BeginTransactionCompleted
  in
    (Model io next state, beginTransaction)


update : Message -> Model -> (Model, Cmd Message)
update message model =
  handle message model <|
    case model.state of
      BeginningTransaction airfield ->
        beginningTransaction airfield

      CommittingTransaction airfield ->
        committingTransaction airfield

      PublishingEvent _ ->
        publishingEvent


beginningTransaction : Airfield -> StateHandler
beginningTransaction airfield io message =
  case message of
    BeginTransactionCompleted (Err error) ->
      fail (InternalError (BeginTransaction.errorToString error))

    BeginTransactionCompleted (Ok transaction) ->
      case transaction of
        Transaction.Existing _ _ _ ->
          fail AlreadyExist

        Transaction.Empty _ ->
          let
            commit = io.commitTransaction (Transaction.withValue airfield transaction) |> Cmd.map CommitTransactionCompleted
          in
            transition (CommittingTransaction airfield) (commit)

    CommitTransactionCompleted _ ->
      ignore

    EventPublishCompleted _ ->
      ignore


committingTransaction : Airfield -> StateHandler
committingTransaction airfield io message =
  case message of
    BeginTransactionCompleted _ ->
      ignore

    CommitTransactionCompleted (Err error) ->
      case error of
        CommitTransaction.VersionConflict _ ->
          fail VersionConflict

        other ->
          fail (InternalError (CommitTransaction.errorToString other))

    CommitTransactionCompleted (Ok _) ->
      let
        event = Event.buildAirfieldRegisteredV1 <|
          Event.AirfieldRegisteredV1
            (Airfield.id airfield)
            (Airfield.name airfield)
            (Airfield.location airfield)
            (Airfield.timeZone airfield)

        publish = io.publish event |> Cmd.map EventPublishCompleted
      in
        transition (PublishingEvent airfield) (publish)

    EventPublishCompleted _ ->
      ignore


publishingEvent : StateHandler
publishingEvent _ _ =
  ignore


-- helpers
handle : Message -> Model -> StateHandler -> (Model, Cmd Message)
handle message model handler =
  case handler model.io message model.state of
    -- exits
    (Err problem, _) -> (model, model.next (Err problem))
    (Ok (PublishingEvent airfield), _) -> (model, model.next (Ok (Airfield.id airfield)))
    -- progress
    (Ok newState, newCmd) -> ({ model | state = newState }, newCmd)


fail : Error -> Transition
fail problem _ =
  (Err problem, Cmd.none)


ignore : Transition
ignore state =
  (Ok state, Cmd.none)


transition : State -> Cmd Message -> Transition
transition new cmd _ =
  (Ok new, cmd)
