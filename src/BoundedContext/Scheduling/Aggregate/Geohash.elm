module BoundedContext.Scheduling.Aggregate.Geohash exposing
  ( Geohash
  , ParseProblem(..)
  , parser
  , fromString
  , toString
  , parseProblemToString
  , encode
  , decoder
  )

import Combine exposing (Parser, end, ignore)
import Combine.String exposing (limited1, oneOf)
import Json.Encode as JsonEncode
import Json.Decode as JsonDecode


type Geohash = Geohash String


type ParseProblem
  = MalformedValue


parser : Parser s String
parser =
  limited1 12 (oneOf "0123456789bcdefghjkmnpqrstuvwxyz")
  |> ignore end


fromString : String -> Result ParseProblem Geohash
fromString input =
  case Combine.parse parser input of
    Ok (_, _, value) ->
      Ok (Geohash value)

    Err _ ->
      Err MalformedValue


toString : Geohash -> String
toString (Geohash value) = value


parseProblemToString : ParseProblem -> String
parseProblemToString problem =
  case problem of
    MalformedValue -> "malformed value"


encode : Geohash -> JsonEncode.Value
encode (Geohash value) = JsonEncode.string value


decoder : JsonDecode.Decoder Geohash
decoder = JsonDecode.string
  |> JsonDecode.andThen
    (\input -> case fromString input of
      Err problem -> JsonDecode.fail (parseProblemToString problem)
      Ok value -> JsonDecode.succeed value
    )
