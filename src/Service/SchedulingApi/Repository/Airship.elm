module Service.SchedulingApi.Repository.Airship exposing
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

import BoundedContext.Scheduling.Aggregate.AirshipId exposing (AirshipId)
import BoundedContext.Scheduling.Aggregate.AirshipId as AirshipId
import BoundedContext.Scheduling.Aggregate.Airship exposing (Airship)
import BoundedContext.Scheduling.Aggregate.Airship as Airship


repository : DurableObject.Repository
repository = DurableObject.defineRepository "airships"


objectType : DurableObject.ObjectType Airship
objectType = DurableObject.defineObjectType Airship.encode Airship.decoder


get : AirshipId -> Cmd (Get.Result Airship)
get id =
  DurableObject.get repository objectType (AirshipId.toString id)
  

begin : AirshipId -> Cmd (BeginTransaction.Result Airship)
begin id =
  DurableObject.begin repository objectType (AirshipId.toString id)


commit : Transaction Airship -> Cmd (CommitTransaction.Result Airship)
commit transaction =
  case transaction of
    Empty _ ->
      Task.succeed (Err CommitTransaction.NothingToCommit)
      |> Task.perform identity

    Existing key version value ->
      DurableObject.commit repository objectType key (versionToInt version) value
