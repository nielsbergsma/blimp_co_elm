module BoundedContext.Scheduling.Usecase.RegisterAirfield exposing 
  ( Model(..)
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


type Model 
  = Initialised IO Next Airfield
  | TransactionBegan IO Next Airfield
  | TransactionCommitted IO Next Airfield
  | Failed Error
  | Completed 


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
    airfield = Airfield.build command.id command.name command.location command.timeZone
  in
    (Initialised io next airfield, io.beginTransaction command.id |> Cmd.map BeginTransactionCompleted)


update : Message -> Model -> (Model, Cmd Message)
update message model = 
  case model of 
    -- Initialized state
    Initialised io next airfield ->
      case message of
        BeginTransactionCompleted (Err error) ->
          fail next (InternalError (BeginTransaction.errorToString error))

        BeginTransactionCompleted (Ok transaction) ->
          case transaction of
            Transaction.Existing _ _ _ -> 
              fail next AlreadyExist

            Transaction.Empty _ ->
              let
                transaction_ = Transaction.withValue airfield transaction
              in
                (TransactionBegan io next airfield, io.commitTransaction transaction_ |> Cmd.map CommitTransactionCompleted)

        CommitTransactionCompleted _ -> 
          (model, Cmd.none)

        EventPublishCompleted _ ->
          (model, Cmd.none) 

    -- Transaction Began state
    TransactionBegan io next airfield ->
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
            event = Event.buildAirfieldRegisteredV1 <| 
              Event.AirfieldRegisteredV1
                (Airfield.id airfield) 
                (Airfield.name airfield)
                (Airfield.location airfield)
                (Airfield.timeZone airfield)
          in
            (TransactionCommitted io next airfield, io.publish event |> Cmd.map EventPublishCompleted)

        EventPublishCompleted _ ->
          (model, Cmd.none) 

    -- Transaction Committed state
    TransactionCommitted _ next airfield ->
      case message of 
        BeginTransactionCompleted _ -> 
          (model, Cmd.none) 

        CommitTransactionCompleted _ ->
          (model, Cmd.none) 
          
        EventPublishCompleted _ -> 
          (Completed, next (Ok (Airfield.id airfield)))

    -- Finished states
    Failed _ ->
      (model, Cmd.none)

    Completed ->
      (model, Cmd.none)


fail : Next -> Error -> (Model, Cmd Message)
fail next problem =
  (Failed problem, next (Err problem))
