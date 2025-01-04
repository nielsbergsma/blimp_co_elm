module BoundedContext.Scheduling.Usecase.ScheduleFlight exposing
  ( Model(..)
  , Error(..)
  , Message(..)
  , IO
  , Command
  , CommandResult
  , init
  , update
  )

import BoundedContext.Scheduling.Aggregate.Flight exposing (Flight)
import BoundedContext.Scheduling.Aggregate.Flight as Flight
import BoundedContext.Scheduling.Aggregate.FlightId exposing (FlightId)
import BoundedContext.Scheduling.Aggregate.Airfield exposing (Airfield)
import BoundedContext.Scheduling.Aggregate.AirfieldId exposing (AirfieldId)
import BoundedContext.Scheduling.Aggregate.Airship exposing (Airship)
import BoundedContext.Scheduling.Aggregate.AirshipId exposing (AirshipId)
import BoundedContext.Scheduling.Event as Event

import Cloudflare.Worker.DurableObject.Get as Get
import Cloudflare.Worker.DurableObject.BeginTransaction as BeginTransaction
import Cloudflare.Worker.DurableObject.CommitTransaction as CommitTransaction

import Time
import Prelude.Event as Event
import Prelude.Transaction as Transaction
import Cloudflare.Worker.Queue as Queue


type Model 
  = Initialised IO Next Command
  | DepartureAirfieldResolved IO Next Command Airfield
  | ArrivalAirfieldResolved IO Next Command Airfield Airfield
  | AirshipResolved IO Next Flight
  | TransactionBegan IO Next Flight
  | TransactionCommitted IO Next Flight
  | Failed Error
  | Completed 


type Error
  = AlreadyExist
  | VersionConflict
  | UnknownAirfield AirfieldId
  | UnknownAirship AirshipId
  | SameDepartureAndArrivalLocation
  | DepartureIsLaterThenArrival
  | InternalError String


type Message 
  = ResolveDepartureAirfieldCompleted (Get.Result Airfield)
  | ResolveArrivalAirfieldCompleted (Get.Result Airfield)
  | ResolveAirshipCompleted (Get.Result Airship)
  | BeginTransactionCompleted (BeginTransaction.Result Flight)
  | CommitTransactionCompleted (CommitTransaction.Result Flight)
  | EventPublishCompleted Queue.Result


type alias IO =
  { publish : Event.Event Event.FlightScheduledV1 -> Cmd (Queue.Result)
  , resolveAirfield : AirfieldId -> Cmd (Get.Result Airfield)
  , resolveAirship : AirshipId -> Cmd (Get.Result Airship)
  , beginTransaction : FlightId -> Cmd (BeginTransaction.Result Flight)
  , commitTransaction : Transaction.Transaction Flight -> Cmd (CommitTransaction.Result Flight)
  }


type alias Command = 
  { id : FlightId
  , departureLocation : AirfieldId
  , arrivalLocation : AirfieldId
  , departureTime : Time.Posix
  , arrivalTime : Time.Posix
  , airship : AirshipId
  }


type alias CommandResult 
  = Result Error FlightId


type alias Next = CommandResult -> Cmd Message


init : IO -> Next -> Command -> (Model, Cmd Message)
init io next command =
  let
    model = 
      Initialised io next command
    
    resolveDepartureAirfield = 
      io.resolveAirfield command.departureLocation |> Cmd.map ResolveDepartureAirfieldCompleted
  in
    (model, resolveDepartureAirfield)


update : Message -> Model -> (Model, Cmd Message)
update message model = 
  case (model, message) of
    -- initialised
    (Initialised _ next _, ResolveDepartureAirfieldCompleted (Err error)) ->
      fail next (InternalError (Get.errorToString error))

    (Initialised _ next command, ResolveDepartureAirfieldCompleted (Ok Nothing)) ->
      fail next (UnknownAirfield command.departureLocation)

    (Initialised io next command, ResolveDepartureAirfieldCompleted (Ok (Just departureAirfield))) ->
      let 
        model_ = 
          DepartureAirfieldResolved io next command departureAirfield

        resolveArrivalAirfield = 
          io.resolveAirfield command.arrivalLocation |> Cmd.map ResolveArrivalAirfieldCompleted
      in
        (model_, resolveArrivalAirfield)

    -- departure resolved
    (DepartureAirfieldResolved _ next command _, ResolveArrivalAirfieldCompleted (Ok Nothing)) ->
      fail next (UnknownAirfield command.arrivalLocation)

    (DepartureAirfieldResolved _ next _ _, ResolveArrivalAirfieldCompleted (Err error)) ->
      fail next (InternalError (Get.errorToString error))

    (DepartureAirfieldResolved io next command departureAirfield, ResolveArrivalAirfieldCompleted (Ok (Just arrivalAirfield))) ->
      let 
        model_ = 
          ArrivalAirfieldResolved io next command departureAirfield arrivalAirfield

        resolveAirship = 
          io.resolveAirship command.airship |> Cmd.map ResolveAirshipCompleted
      in
        (model_, resolveAirship)

    -- arrival resolved
    (ArrivalAirfieldResolved _ next _ _ _, ResolveAirshipCompleted (Err error)) ->
      fail next (InternalError (Get.errorToString error))

    (ArrivalAirfieldResolved _ next command _ _, ResolveAirshipCompleted (Ok Nothing)) ->
      fail next (UnknownAirship command.airship)
  
    (ArrivalAirfieldResolved io next command departureAirfield arrivalAirfield, ResolveAirshipCompleted (Ok (Just airship))) ->
      let
        buildResult = Flight.build 
          command.id 
          command.departureTime 
          departureAirfield 
          command.arrivalTime 
          arrivalAirfield 
          airship

        beginTransaction = 
          io.beginTransaction command.id |> Cmd.map BeginTransactionCompleted
      in
        case buildResult of
          Err Flight.SameDepartureAndArrivalLocation ->
            fail next SameDepartureAndArrivalLocation

          Err Flight.DepartureIsLaterThenArrival ->
            fail next DepartureIsLaterThenArrival

          Ok flight -> 
            (AirshipResolved io next flight, beginTransaction)

    -- airship resolved
    (AirshipResolved _ next _, BeginTransactionCompleted (Err error)) ->
      fail next (InternalError (BeginTransaction.errorToString error))

    (AirshipResolved io next flight, BeginTransactionCompleted (Ok transaction)) ->
      case transaction of
        Transaction.Existing _ _ _ -> 
          fail next AlreadyExist

        Transaction.Empty _ ->
          let
            transaction_ = Transaction.withValue flight transaction

            commitTransaction = io.commitTransaction transaction_ |> Cmd.map CommitTransactionCompleted
          in
            (TransactionBegan io next flight, commitTransaction)
    
    -- transaction began
    (TransactionBegan _ next _, CommitTransactionCompleted (Err error)) ->
      case error of
        CommitTransaction.VersionConflict _ -> 
          fail next VersionConflict
        
        other -> 
          fail next (InternalError (CommitTransaction.errorToString other))
    
    (TransactionBegan io next flight, CommitTransactionCompleted (Ok _)) ->
      let
        event = Event.buildFlightScheduledV1 <| 
          Event.FlightScheduledV1
            (Flight.id flight)
            (Flight.departure flight)
            (Flight.arrival flight)
            (Flight.airship flight)

        publishEvent = io.publish event |> Cmd.map EventPublishCompleted
      in
        (TransactionCommitted io next flight, publishEvent)

    -- transaction commited
    (TransactionCommitted _ next flight, EventPublishCompleted _ ) ->
      (Completed, next (Ok (Flight.id flight)))

    -- otherwise
    _ ->
      (Failed (InternalError "invalid state"), Cmd.none)


fail : Next -> Error -> (Model, Cmd Message)
fail next problem =
  (Failed problem, next (Err problem))
