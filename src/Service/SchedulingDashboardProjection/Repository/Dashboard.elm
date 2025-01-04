module Service.SchedulingDashboardProjection.Repository.Dashboard exposing 
  ( bucket
  , objectType
  , get
  , set
  )

import Cloudflare.Worker.R2 as R2

import BoundedContext.Scheduling.Projection.Dashboard exposing (Dashboard, Error(..), encodeDashboard, dashboardDecoder)


-- storage methods
bucket : R2.Bucket
bucket = R2.defineBucket "scheduling_bucket"


objectType : R2.ObjectType Dashboard
objectType = R2.defineObjectType encodeDashboard dashboardDecoder


path : R2.Path
path = ["dashboard"]


get : Cmd (Result Error (Maybe Dashboard))
get = 
  R2.get objectType bucket path
  |> Cmd.map (Result.mapError r2ErrorToError)


set : Dashboard -> Cmd (Result Error ())
set dashboard =
  R2.put objectType bucket path dashboard
  |> Cmd.map (Result.mapError r2ErrorToError)


r2ErrorToError : R2.Error -> Error
r2ErrorToError error = 
  case error of
    R2.IoError reason -> IoError reason
    R2.DecodeError reason -> DecodeError reason
