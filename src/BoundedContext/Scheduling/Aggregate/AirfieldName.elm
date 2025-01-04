module BoundedContext.Scheduling.Aggregate.AirfieldName exposing
  ( AirfieldName
  , ParseProblem(..)
  , parser
  , fromString
  , toString
  , parseProblemToString
  , encode
  , decoder
  )

import Json.Encode as JsonEncode
import Json.Decode as JsonDecode
import Combine exposing (Parser, end, or, ignore)
import Combine.String exposing (alphaNumeric, capital, followedBy, symbol0, limited1)


type AirfieldName
  = AirfieldName String


type ParseProblem
  = MalformedValue


parser : Parser s String
parser =
  let
    whitespace = symbol0 ' '
    punctuation = (symbol0 '.') |> or (symbol0 '-')
  in
    capital
    |> followedBy
        (limited1 63 (
          whitespace
          |> followedBy punctuation
          |> followedBy whitespace
          |> followedBy alphaNumeric
        ))
    |> ignore end


fromString : String -> Result ParseProblem AirfieldName
fromString input =
  case Combine.parse parser input of
    Ok (_, _, value) ->
      Ok (AirfieldName value)

    Err _ ->
      Err MalformedValue


toString : AirfieldName -> String
toString (AirfieldName value) = value


parseProblemToString : ParseProblem -> String
parseProblemToString problem =
  case problem of
    MalformedValue -> "malformed value"


encode : AirfieldName -> JsonEncode.Value
encode (AirfieldName value) = JsonEncode.string value


decoder : JsonDecode.Decoder AirfieldName
decoder = JsonDecode.string
  |> JsonDecode.andThen
     (\input -> case fromString input of
       Err problem -> JsonDecode.fail (parseProblemToString problem)
       Ok value -> JsonDecode.succeed value
     )
