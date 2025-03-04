module BoundedContext.Scheduling.Usecase.ScheduleFlight exposing
  ( Model
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
import Task


type alias Model =
  { io : IO
  , next : Next
  , state : State
  }


type State
  = ResolvingFlight PartialResolvedFlight
  | BeginningTransaction Flight
  | CommittingTransaction Flight
  | PublishingEvent Flight

type alias StateHandler = IO -> Message -> Transition

type alias Transition = State -> (Result Error State, Cmd Message)

type Error
  = AlreadyExist
  | VersionConflict
  | UnknownDepartureAirfield
  | UnknownArrivalAirfield
  | UnknownAirship
  | SameDepartureAndArrivalLocation
  | DepartureIsLaterThenArrival
  | InternalError String


type Message 
  = ResolveDepartureAirfieldCompleted (Get.Result Airfield)
  | ResolveArrivalAirfieldCompleted (Get.Result Airfield)
  | ResolveAirshipCompleted (Get.Result Airship)
  | FlightResolved (Result Flight.BuildError Flight)
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
    resolvers =
      [ io.resolveAirfield command.departureLocation |> Cmd.map ResolveDepartureAirfieldCompleted
      , io.resolveAirfield command.arrivalLocation |> Cmd.map ResolveArrivalAirfieldCompleted
      , io.resolveAirship command.airship |> Cmd.map ResolveAirshipCompleted
      ]

    state =
      ResolvingFlight (flightFromCommand command)
  in
    (Model io next state, Cmd.batch resolvers)


update : Message -> Model -> (Model, Cmd Message)
update message model = 
  handle message model <|
    case model.state of
      ResolvingFlight flight ->
        resolvingFlight flight

      BeginningTransaction flight ->
        beginningTransaction flight

      CommittingTransaction flight ->
        committingTransaction flight

      PublishingEvent flight ->
        publishingEvent flight


resolvingFlight : PartialResolvedFlight -> StateHandler
resolvingFlight flight io message =
  let
    resolve set nothingError result =
      case result of
        Ok (Just value) ->
          transition (ResolvingFlight (set value flight)) (tryResolveFlight (set value flight))

        Ok Nothing ->
          fail nothingError

        Err error ->
          fail (InternalError (Get.errorToString error))
  in
    case message of
      ResolveDepartureAirfieldCompleted result ->
        resolve resolveDepartureAirfield UnknownDepartureAirfield result

      ResolveArrivalAirfieldCompleted result ->
        resolve resolveArrivalAirfield UnknownArrivalAirfield result

      ResolveAirshipCompleted result ->
        resolve resolveAirship UnknownAirship result

      FlightResolved result ->
        case result of
          Err Flight.SameDepartureAndArrivalLocation ->
            fail SameDepartureAndArrivalLocation

          Err Flight.DepartureIsLaterThenArrival ->
            fail DepartureIsLaterThenArrival

          Ok value ->
            let
              beginTransaction =
                io.beginTransaction (Flight.id value) |> Cmd.map BeginTransactionCompleted
            in
              transition (BeginningTransaction value) beginTransaction

      BeginTransactionCompleted _ ->
        ignore

      CommitTransactionCompleted _ ->
        ignore

      EventPublishCompleted _ ->
        ignore


beginningTransaction : Flight -> StateHandler
beginningTransaction flight io message =
  case message of
    ResolveDepartureAirfieldCompleted _ ->
      ignore

    ResolveArrivalAirfieldCompleted _ ->
      ignore

    ResolveAirshipCompleted _ ->
      ignore

    FlightResolved _ ->
      ignore

    BeginTransactionCompleted (Err error) ->
      fail (InternalError (BeginTransaction.errorToString error))

    BeginTransactionCompleted (Ok transaction) ->
      case transaction of
        Transaction.Existing _ _ _ ->
          fail AlreadyExist

        Transaction.Empty _ ->
          let
            transaction_ = Transaction.withValue flight transaction
            commitTransaction = io.commitTransaction transaction_ |> Cmd.map CommitTransactionCompleted
          in
            transition (CommittingTransaction flight) (commitTransaction)

    CommitTransactionCompleted _ ->
      ignore

    EventPublishCompleted _ ->
      ignore


committingTransaction : Flight -> StateHandler
committingTransaction flight io message =
  case message of
    ResolveAirshipCompleted _ ->
      ignore

    ResolveDepartureAirfieldCompleted _ ->
      ignore

    ResolveArrivalAirfieldCompleted _ ->
      ignore

    FlightResolved _ ->
      ignore

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
        event = Event.buildFlightScheduledV1 <|
          Event.FlightScheduledV1
            (Flight.id flight)
            (Flight.departure flight)
            (Flight.arrival flight)
            (Flight.airship flight)

        publishEvent = io.publish event |> Cmd.map EventPublishCompleted
      in
        transition (PublishingEvent flight) (publishEvent)

    EventPublishCompleted _ ->
      ignore


publishingEvent : Flight -> StateHandler
publishingEvent _ _ _ =
  ignore


-- helpers
type alias PartialResolvedFlight =
  { departureAirfield: Maybe Airfield
  , arrivalAirfield: Maybe Airfield
  , airship: Maybe Airship
  , resolve: Airfield -> Airfield -> Airship -> Result Flight.BuildError Flight
  }


flightFromCommand : Command -> PartialResolvedFlight
flightFromCommand command =
  { resolve = \departureAirfield arrivalAirfield airship ->
      Flight.build
        command.id
        command.departureTime
        departureAirfield
        command.arrivalTime
        arrivalAirfield
        airship
  , departureAirfield = Nothing
  , arrivalAirfield = Nothing
  , airship = Nothing
  }


resolveDepartureAirfield : Airfield -> PartialResolvedFlight -> PartialResolvedFlight
resolveDepartureAirfield airfield flight =
  { flight | departureAirfield = Just airfield }


resolveArrivalAirfield : Airfield -> PartialResolvedFlight -> PartialResolvedFlight
resolveArrivalAirfield airfield flight =
  { flight | arrivalAirfield = Just airfield }


resolveAirship : Airship -> PartialResolvedFlight -> PartialResolvedFlight
resolveAirship airship flight =
  { flight | airship = Just airship }


tryResolveFlight : PartialResolvedFlight -> Cmd Message
tryResolveFlight flight =
  case (flight.departureAirfield, flight.arrivalAirfield, flight.airship) of
    (Just departureAirfield, Just arrivalAirfield, Just airship) ->
      Task.perform FlightResolved <| Task.succeed (flight.resolve departureAirfield arrivalAirfield airship)

    _ ->
      Cmd.none


handle : Message -> Model -> StateHandler -> (Model, Cmd Message)
handle message model handler =
  case handler model.io message model.state of
    -- exits
    (Err problem, _) -> (model, model.next (Err problem))
    (Ok (PublishingEvent flight), _) -> (model, model.next (Ok (Flight.id flight)))
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
