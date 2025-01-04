module Routes exposing 
  ( Route(..)
  , fromUrl
  , toUrl
  )

import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), (<?>), Parser, oneOf, s)


type Route 
  = FlightScheduling
  | Reservations
  | Unknown


parser : Parser (Route -> a) a
parser = oneOf
  [ Parser.map FlightScheduling (s"flight-scheduling")
  , Parser.map Reservations (s"reservations")
  ]


fromUrl : Url -> Route
fromUrl url = case Parser.parse parser url of
  Just route -> route
  Nothing -> Unknown


toUrl : Route -> String
toUrl route = case route of 
  FlightScheduling -> "/flight-scheduling"
  Reservations -> "/reservations"
  Unknown -> "/404"
