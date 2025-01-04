module Prelude.Time exposing
  ( Rfc3339Time
  , ZoneName
  , isSupportedZoneName
  , formatPosixAsRfc3339
  )

import Time


type alias ZoneName = String


type alias Rfc3339Time = String


isSupportedZoneName : ZoneName -> Bool
isSupportedZoneName = isSupportedZoneNameFFI


isSupportedZoneNameFFI : ZoneName -> Bool
isSupportedZoneNameFFI _ = False


formatPosixAsRfc3339 : ZoneName -> Time.Posix -> Rfc3339Time
formatPosixAsRfc3339 zone time = 
  formatPosixAsRfc3339FFI zone (Time.posixToMillis time)


formatPosixAsRfc3339FFI : ZoneName -> Int -> Rfc3339Time  
formatPosixAsRfc3339FFI _ _ = "not patched"
