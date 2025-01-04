module BoundedContext.Scheduling.Aggregate.AirfieldId exposing
  ( AirfieldId
  , ParseProblem
  , parser
  , fromString
  , toString
  , parseProblemToString
  , encode
  , decoder
  )

import Combine exposing (Parser)
import BoundedContext.Scheduling.Aggregate.IcaoCode as IcaoCode
import Json.Decode as JsonDecode
import Json.Encode as JsonEncode

-- re-exports
type alias AirfieldId = IcaoCode.IcaoCode


type alias ParseProblem = IcaoCode.ParseProblem


parser : Parser s String
parser = IcaoCode.parser


fromString : String -> Result IcaoCode.ParseProblem IcaoCode.IcaoCode
fromString = IcaoCode.fromString


toString : IcaoCode.IcaoCode -> String
toString = IcaoCode.toString


parseProblemToString : IcaoCode.ParseProblem -> String
parseProblemToString = IcaoCode.parseProblemToString


encode : IcaoCode.IcaoCode -> JsonEncode.Value
encode = IcaoCode.encode


decoder : JsonDecode.Decoder IcaoCode.IcaoCode
decoder = IcaoCode.decoder