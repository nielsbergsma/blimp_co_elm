module Service.SchedulingApi.Main exposing (..)

import Platform

import Service.SchedulingApi.Api.TransferObject as TransferObject
import Service.SchedulingApi.Repository.Airfield as AirfieldRepository
import Service.SchedulingApi.Repository.Airship as AirshipRepository
import Service.SchedulingApi.Repository.Flight as FlightRepository

import Cloudflare.Worker.Fetch exposing (..)
import Cloudflare.Worker.Fetch as Fetch 
import Cloudflare.Worker.Queue as Queue

import BoundedContext.Scheduling.Usecase.RegisterAirfield as RegisterAirfieldUseCase
import BoundedContext.Scheduling.Usecase.AddAirshipToFleet as AddAirshipToFleetUseCase
import BoundedContext.Scheduling.Usecase.ScheduleFlight as ScheduleFlightUseCase


type Message
  = Failure String
  | HandleRequest Request
  | RegisterAirfieldMessage RegisterAirfieldUseCase.Message
  | AddAirshipToFleetMessage AddAirshipToFleetUseCase.Message
  | ScheduleFlightMessage ScheduleFlightUseCase.Message


type Model
  = Initialising
  | RegisteringAirfield RegisterAirfieldUseCase.Model
  | AddingAirshipToFleet AddAirshipToFleetUseCase.Model
  | SchedulingFlight ScheduleFlightUseCase.Model


main : Program () Model Message
main =
  Platform.worker
  { init = init
  , subscriptions = always (Fetch.subscribeFetch HandleRequest Failure)
  , update = update
  }


init : () -> (Model, Cmd Message)
init _ = 
  (Initialising, Cmd.none)


update : Message -> Model -> (Model, Cmd Message)
update message model =
  case message of
    HandleRequest request ->
      route model request

    RegisterAirfieldMessage usecaseMessage ->
      case model of 
        RegisteringAirfield usecaseModel ->
          RegisterAirfieldUseCase.update usecaseMessage usecaseModel 
          |> mapMM RegisteringAirfield RegisterAirfieldMessage

        _ -> 
          (model, respond (internalError "malformed state"))

    AddAirshipToFleetMessage usecaseMessage ->
      case model of 
        AddingAirshipToFleet usecaseModel ->
          AddAirshipToFleetUseCase.update usecaseMessage usecaseModel 
          |> mapMM AddingAirshipToFleet AddAirshipToFleetMessage

        _ -> 
          (model, respond (internalError "malformed state"))

    ScheduleFlightMessage usecaseMessage ->
      case model of 
        SchedulingFlight usecaseModel ->
          ScheduleFlightUseCase.update usecaseMessage usecaseModel 
          |> mapMM SchedulingFlight ScheduleFlightMessage

        _ -> 
          (model, respond (internalError "malformed state"))
    
    Failure reason ->
      (model, respond (internalError reason))
    

route : Model -> Request -> ( Model, Cmd Message )
route model request =
  case (Fetch.method request, Fetch.path request) of
    (Post, [ "airfields" ]) ->
      authorize Fetch.Agent request
      |> Result.andThen (TransferObject.parseRegisterAirfieldRequest)
      |> Result.map (RegisterAirfieldUseCase.init registerAirfieldUseCaseIO TransferObject.formatRegisterAirfieldResponse)            
      |> Result.map (mapMM RegisteringAirfield RegisterAirfieldMessage)
      |> okOrElse (\error -> (model, respond error))

    (Post, [ "airships" ]) ->
      authorize Fetch.Agent request
      |> Result.andThen (TransferObject.parseAddAirshipToFleetRequest)
      |> Result.map (AddAirshipToFleetUseCase.init addAirshipToFleetUseCaseIO TransferObject.formatAddAirshipToFleetResponse)            
      |> Result.map (mapMM AddingAirshipToFleet AddAirshipToFleetMessage)
      |> okOrElse (\error -> (model, respond error))

    (Post, [ "flights" ]) ->
      authorize Fetch.Agent request
      |> Result.andThen (TransferObject.parseScheduleFlightRequest)
      |> Result.map (ScheduleFlightUseCase.init scheduleFlightUseCaseIO TransferObject.formatScheduleFlightResponse)            
      |> Result.map (mapMM SchedulingFlight ScheduleFlightMessage)
      |> okOrElse (\error -> (model, respond error))
        
    _ -> 
      (model, respond notFound)


-- queues
schedulingQueue : Queue.Queue
schedulingQueue = Queue.fromName "scheduling_queue"


-- i/o
registerAirfieldUseCaseIO : RegisterAirfieldUseCase.IO
registerAirfieldUseCaseIO = 
  RegisterAirfieldUseCase.IO 
    (Queue.publish schedulingQueue) 
    (AirfieldRepository.begin) 
    (AirfieldRepository.commit)


addAirshipToFleetUseCaseIO : AddAirshipToFleetUseCase.IO
addAirshipToFleetUseCaseIO = 
  AddAirshipToFleetUseCase.IO 
    (Queue.publish schedulingQueue) 
    (AirshipRepository.begin) 
    (AirshipRepository.commit)


scheduleFlightUseCaseIO : ScheduleFlightUseCase.IO
scheduleFlightUseCaseIO  = 
  ScheduleFlightUseCase.IO 
    (Queue.publish schedulingQueue) 
    (AirfieldRepository.get)
    (AirshipRepository.get)
    (FlightRepository.begin)
    (FlightRepository.commit)


-- helpers
mapMM : (a -> b) -> (c -> d) -> (a, Cmd c) -> (b, Cmd d)
mapMM toModel toCmd (model, cmd) = 
  (toModel model, Cmd.map toCmd cmd)


okOrElse : (e -> a) -> Result e a -> a
okOrElse mapErr result =
  case result of
    Err error -> mapErr error
    Ok value -> value


authorize : Fetch.Scope -> Fetch.Request -> Result Fetch.Response Fetch.Request
authorize scope request = 
  if Fetch.authorized scope request
  then Ok request
  else Err Fetch.forbidden
