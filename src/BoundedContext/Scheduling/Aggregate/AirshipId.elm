module BoundedContext.Scheduling.Aggregate.AirshipId exposing 
  ( AirshipId
  , ParseProblem(..)
  , parser
  , fromString
  , toString
  , parseProblemToString
  , encode
  , decoder
  )

import Combine exposing (Parser, end, or, ignore)
import Combine.String exposing (capital, digit, symbol0, repeat, followedBy)
import Json.Decode as JsonDecode
import Json.Encode as JsonEncode


type AirshipId
  = AirshipId String


type ParseProblem
  = MalformedValue


-- uses aircraft registration id as identity (https://en.wikipedia.org/wiki/List_of_aircraft_registration_prefixes)
parser : Parser s String
parser =
  repeat 1 3 (or capital digit)
  |> followedBy (symbol0 '-')
  |> followedBy (repeat 3 5 (or capital digit))
  |> ignore end



fromString : String -> Result ParseProblem AirshipId
fromString input =
  case Combine.parse parser input of
    Ok (_, _, value) ->
      Ok (AirshipId value)

    Err _ ->
      Err MalformedValue


toString : AirshipId -> String
toString (AirshipId value) = value


parseProblemToString : ParseProblem -> String
parseProblemToString problem =
  case problem of
    MalformedValue -> "malformed value"


encode : AirshipId -> JsonEncode.Value
encode (AirshipId value) = JsonEncode.string value


decoder : JsonDecode.Decoder AirshipId
decoder = JsonDecode.string
  |> JsonDecode.andThen
    (\input -> case fromString input of
      Err problem -> JsonDecode.fail (parseProblemToString problem)
      Ok value -> JsonDecode.succeed value
    )
