module Combine.String exposing
  ( oneOf
  , many1
  , limited1
  , alphaNumeric
  , letterOf
  , letter0
  , symbol
  , symbol0
  , digit
  , capital
  , repeat
  , followedBy
  )


import Combine exposing (Parser, sequence, map, optional, fail, andThen, succeed)
import Combine.Char exposing (satisfy, char)


oneOf : String -> Parser s String
oneOf letters =
  Combine.Char.oneOf (String.toList letters) |> map String.fromChar


many1 : Parser s String -> Parser s String
many1 nested =
  Combine.many1 nested
  |> map String.concat


limited1 : Int -> Parser s String -> Parser s String
limited1 max nested =
  Combine.many1 nested
  |> map String.concat
  |> andThen (\result ->
      if String.length result > max
      then fail "string is longer than maximum allowed"
      else succeed result
    )


alphaNumeric : Parser s String
alphaNumeric =
  letterOf Char.isAlphaNum


letter0 : Char -> Parser s String
letter0 char_ =
  optional "" (letter char_)


letterOf : (Char -> Bool) -> Parser s String
letterOf predicate =
  satisfy predicate
  |> map String.fromChar


symbol0 : Char -> Parser s String
symbol0 = letter0


symbol : Char -> Parser s String
symbol = letter


letter : Char -> Parser s String
letter char_ =
  char char_
  |> map String.fromChar


digit : Parser s String
digit = 
  letterOf Char.isDigit


capital : Parser s String
capital =
  letterOf Char.isUpper


followedBy : Parser s String -> Parser s String -> Parser s String
followedBy b a = 
  sequence [ a, b ]
  |> map String.concat


repeat : Int -> Int -> Parser s String -> Parser s String
repeat min max p =
  let
    accumulate acc state stream =
      case Combine.app p state stream of
        (rstate, rstream, Ok res) ->
          if String.length acc < max - 1
          then accumulate (acc ++ res) rstate rstream
          else ( rstate, rstream, Ok (acc ++ res))

        ( estate, estream, Err ms ) ->
          if String.length acc >= min && String.length acc < max
          then ( state, stream, Ok acc )
          else ( estate, estream, Err ms )
  in
    Combine.primitive (\state stream -> accumulate "" state stream)
