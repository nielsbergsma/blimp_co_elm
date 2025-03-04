module BoundedContext.Scheduling.Usecase.AddAirshipToFleet exposing 
  ( Model
  , Error(..)
  , Message(..)
  , IO
  , Command
  , CommandResult
  , init
  , update
  )

import BoundedContext.Scheduling.Aggregate.Airship exposing (Airship)
import BoundedContext.Scheduling.Aggregate.Airship as Airship
import BoundedContext.Scheduling.Aggregate.AirshipId exposing (AirshipId)
import BoundedContext.Scheduling.Aggregate.AirshipName exposing (AirshipName)
import BoundedContext.Scheduling.Aggregate.AirshipModel exposing (AirshipModel)
import BoundedContext.Scheduling.Aggregate.AirshipNumberOfSeats exposing (AirshipNumberOfSeats)
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
  = BeginningTransaction Airship
  | CommittingTransaction Airship
  | PublishingEvent Airship

type alias StateHandler = IO -> Message -> Transition

type alias Transition = State -> (Result Error State, Cmd Message)


type Error
  = AlreadyExist
  | VersionConflict
  | InternalError String


type Message 
  = BeginTransactionCompleted (BeginTransaction.Result Airship)
  | CommitTransactionCompleted (CommitTransaction.Result Airship)
  | EventPublishCompleted Queue.Result


type alias IO =
  { publish : Event.Event Event.AirshipAddedToFleetV1 -> Cmd (Queue.Result)
  , beginTransaction : AirshipId -> Cmd (BeginTransaction.Result Airship)
  , commitTransaction : Transaction.Transaction Airship -> Cmd (CommitTransaction.Result Airship)
  }


type alias Command = 
  { id : AirshipId
  , name : AirshipName
  , model : AirshipModel
  , numberOfSeats : AirshipNumberOfSeats
  }


type alias CommandResult 
  = Result Error AirshipId


type alias Next = CommandResult -> Cmd Message


init : IO -> Next -> Command -> (Model, Cmd Message)
init io next command =
  let 
    airship =
      Airship.build command.id command.name command.model command.numberOfSeats

    state =
      BeginningTransaction airship

    beginTransaction =
      io.beginTransaction command.id |> Cmd.map BeginTransactionCompleted
  in
    (Model io next state, beginTransaction)


update : Message -> Model -> (Model, Cmd Message)
update message model =
  handle message model <|
    case model.state of
      BeginningTransaction airship ->
        beginningTransaction airship

      CommittingTransaction airship ->
        committingTransaction airship

      PublishingEvent _ ->
        publishingEvent


beginningTransaction : Airship -> StateHandler
beginningTransaction airship io message =
  case message of
    BeginTransactionCompleted (Err error) ->
      fail (InternalError (BeginTransaction.errorToString error))

    BeginTransactionCompleted (Ok transaction) ->
      case transaction of
        Transaction.Existing _ _ _ ->
          fail AlreadyExist

        Transaction.Empty _ ->
          let
            commit = io.commitTransaction (Transaction.withValue airship transaction) |> Cmd.map CommitTransactionCompleted
          in
            transition (CommittingTransaction airship) (commit)

    CommitTransactionCompleted _ ->
      ignore

    EventPublishCompleted _ ->
      ignore


committingTransaction : Airship -> StateHandler
committingTransaction airship io message =
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
        event = Event.buildAirshipAddedToFleetV1 <|
          Event.AirshipAddedToFleetV1
            (Airship.id airship)
            (Airship.name airship)
            (Airship.model airship)
            (Airship.numberOfSeats airship)

        publish = io.publish event |> Cmd.map EventPublishCompleted
      in
        transition (PublishingEvent airship) (publish)

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
    (Ok (PublishingEvent airship), _) -> (model, model.next (Ok (Airship.id airship)))
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
