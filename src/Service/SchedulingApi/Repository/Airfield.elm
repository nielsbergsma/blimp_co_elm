module Service.SchedulingApi.Repository.Airfield exposing
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

import BoundedContext.Scheduling.Aggregate.AirfieldId exposing (AirfieldId)
import BoundedContext.Scheduling.Aggregate.AirfieldId as AirfieldId
import BoundedContext.Scheduling.Aggregate.Airfield exposing (Airfield)
import BoundedContext.Scheduling.Aggregate.Airfield as Airfield


repository : DurableObject.Repository
repository = DurableObject.defineRepository "airfields"


objectType : DurableObject.ObjectType Airfield
objectType = DurableObject.defineObjectType Airfield.encode Airfield.decoder


get : AirfieldId -> Cmd (Get.Result Airfield)
get id = 
  DurableObject.get repository objectType (AirfieldId.toString id)


begin : AirfieldId -> Cmd (BeginTransaction.Result Airfield)
begin id =
  DurableObject.begin repository objectType (AirfieldId.toString id)


commit : Transaction Airfield -> Cmd (CommitTransaction.Result Airfield)
commit transaction =
  case transaction of
    Empty _ ->
      Task.succeed (Err CommitTransaction.NothingToCommit)
      |> Task.perform identity

    Existing key version value ->
      DurableObject.commit repository objectType key (versionToInt version) value
