module Service.SchedulingApi.Repository.Flight exposing
  ( get
  , begin
  , commit
  )

import Task
import Prelude.Transaction exposing (..)

import Cloudflare.Worker.DurableObject as DurableObject
import Cloudflare.Worker.DurableObject.Get as Get
import Cloudflare.Worker.DurableObject.BeginTransaction as BeginTransaction
import Cloudflare.Worker.DurableObject.CommitTransaction as CommitTransaction

import BoundedContext.Scheduling.Aggregate.FlightId exposing (FlightId)
import BoundedContext.Scheduling.Aggregate.FlightId as FlightId
import BoundedContext.Scheduling.Aggregate.Flight exposing (Flight)
import BoundedContext.Scheduling.Aggregate.Flight as Flight


repository : DurableObject.Repository
repository = DurableObject.defineRepository "flights"


objectType : DurableObject.ObjectType Flight
objectType = DurableObject.defineObjectType Flight.encode Flight.decoder


get : FlightId -> Cmd (Get.Result Flight)
get id =
  DurableObject.get repository objectType (FlightId.toString id)


begin : FlightId -> Cmd (BeginTransaction.Result Flight)
begin id =
  DurableObject.begin repository objectType (FlightId.toString id)


commit : Transaction Flight -> Cmd (CommitTransaction.Result Flight)
commit transaction =
  case transaction of
    Empty _ ->
      Task.succeed (Err CommitTransaction.NothingToCommit)
      |> Task.perform identity

    Existing key version value ->
      DurableObject.commit repository objectType key (versionToInt version) value
