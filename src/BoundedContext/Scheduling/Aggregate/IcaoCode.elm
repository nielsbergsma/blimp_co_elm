module BoundedContext.Scheduling.Aggregate.IcaoCode exposing
  ( IcaoCode
  , ParseProblem(..)
  , parser
  , fromString
  , toString
  , parseProblemToString
  , encode
  , decoder
  )

import Combine exposing (Parser, end, ignore)
import Combine.String exposing (capital, followedBy)
import Json.Decode as JsonDecode
import Json.Encode as JsonEncode


type IcaoCode
  = IcaoCode String


type ParseProblem
  = MalformedValue


parser : Parser s String
parser =
  capital
  |> followedBy capital
  |> followedBy capital
  |> followedBy capital
  |> ignore end


fromString : String -> Result ParseProblem IcaoCode
fromString input =
  case Combine.parse parser input of
    Ok (_, _, value) ->
      Ok (IcaoCode value)

    Err _ ->
      Err MalformedValue


toString : IcaoCode -> String
toString (IcaoCode value) = value


parseProblemToString : ParseProblem -> String
parseProblemToString problem =
  case problem of
    MalformedValue -> "malformed value"


encode : IcaoCode -> JsonEncode.Value
encode (IcaoCode value) = JsonEncode.string value


decoder : JsonDecode.Decoder IcaoCode
decoder = JsonDecode.string
  |> JsonDecode.andThen
    (\input -> case fromString input of
      Err problem -> JsonDecode.fail (parseProblemToString problem)
      Ok value -> JsonDecode.succeed value
    )
