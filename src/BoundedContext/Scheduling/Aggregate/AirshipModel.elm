module BoundedContext.Scheduling.Aggregate.AirshipModel exposing 
  ( AirshipModel
  , ParseProblem(..)
  , parser
  , fromString
  , toString
  , parseProblemToString
  , encode
  , decoder
  )

import Combine exposing (Parser, end, ignore)
import Combine.String exposing (capital, symbol0, alphaNumeric, limited1, followedBy)
import Json.Decode as JsonDecode
import Json.Encode as JsonEncode


type AirshipModel
  = AirshipId String


type ParseProblem
  = MalformedValue


parser : Parser s String
parser =
  let
    whitespace = symbol0 ' '
    punctuation = symbol0 '-'
  in
    capital
    |> followedBy 
      ( limited1 99 
        ( whitespace
        |> followedBy punctuation
        |> followedBy whitespace
        |> followedBy alphaNumeric 
        )
      )
    |> ignore end


fromString : String -> Result ParseProblem AirshipModel
fromString input =
  case Combine.parse parser input of
    Ok (_, _, value) ->
      Ok (AirshipId value)

    Err _ ->
      Err MalformedValue


toString : AirshipModel -> String
toString (AirshipId value) = value


parseProblemToString : ParseProblem -> String
parseProblemToString problem =
  case problem of
    MalformedValue -> "malformed value"


encode : AirshipModel -> JsonEncode.Value
encode (AirshipId value) = JsonEncode.string value


decoder : JsonDecode.Decoder AirshipModel
decoder = JsonDecode.string
  |> JsonDecode.andThen
    (\input -> case fromString input of
      Err problem -> JsonDecode.fail (parseProblemToString problem)
      Ok value -> JsonDecode.succeed value
    )
