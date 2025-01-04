module BoundedContext.Scheduling.Usecase.AddAirshipToFleet exposing 
  ( Model(..)
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


type Model 
  = Initialised IO Next Airship
  | TransactionBegan IO Next Airship
  | TransactionCommitted IO Next Airship
  | Failed Error
  | Completed 


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
    airship = Airship.build command.id command.name command.model command.numberOfSeats
  in
    (Initialised io next airship, io.beginTransaction command.id |> Cmd.map BeginTransactionCompleted)


update : Message -> Model -> (Model, Cmd Message)
update message model = 
  case model of 
    -- Initialized state
    Initialised io next airship->
      case message of
        BeginTransactionCompleted (Err error) ->
          fail next (InternalError (BeginTransaction.errorToString error))

        BeginTransactionCompleted (Ok transaction) ->
          case transaction of
            Transaction.Existing _ _ _ -> 
              fail next AlreadyExist

            Transaction.Empty _ ->
              let
                transaction_ = Transaction.withValue airship transaction
              in
                (TransactionBegan io next airship, io.commitTransaction transaction_ |> Cmd.map CommitTransactionCompleted)

        CommitTransactionCompleted _ -> 
          (model, Cmd.none)

        EventPublishCompleted _ ->
          (model, Cmd.none) 

    -- Transaction Began state
    TransactionBegan io next airship ->
      case message of
        BeginTransactionCompleted _ -> 
          (model, Cmd.none)

        CommitTransactionCompleted (Err error) ->
           case error of
            CommitTransaction.VersionConflict _ -> 
              fail next VersionConflict
            
            other -> 
              fail next (InternalError (CommitTransaction.errorToString other))
        
        CommitTransactionCompleted (Ok _) ->
          let 
            event = Event.buildAirshipAddedToFleetV1 <| 
              Event.AirshipAddedToFleetV1
                (Airship.id airship) 
                (Airship.name airship)
                (Airship.model airship)
                (Airship.numberOfSeats airship)
          in
            (TransactionCommitted io next airship, io.publish event |> Cmd.map EventPublishCompleted)

        EventPublishCompleted _ ->
          (model, Cmd.none) 

    -- Transaction Committed state
    TransactionCommitted _ next airship ->
      case message of 
        BeginTransactionCompleted _ -> 
          (model, Cmd.none) 

        CommitTransactionCompleted _ ->
          (model, Cmd.none) 
          
        EventPublishCompleted _ -> 
          (Completed, next (Ok (Airship.id airship)))

    -- Finished states
    Failed _ ->
      (model, Cmd.none)

    Completed ->
      (model, Cmd.none)


fail : Next -> Error -> (Model, Cmd Message)
fail next problem =
  (Failed problem, next (Err problem))
