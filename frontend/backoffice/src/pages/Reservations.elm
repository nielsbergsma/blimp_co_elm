module Pages.Reservations exposing (Model, Message(..), init, update, view)

import Html exposing (Html, div, text)
import Html.Attributes exposing (class)
import Session exposing (Session)

import Components.Icon as Icon


type Model 
  = Loading


type Message = NoOperation


init : Session -> (Model, Cmd Message)
init _ = (Loading, Cmd.none)


update : Session -> Model -> Message -> (Model, Cmd Message)
update _ model _ = 
  (model, Cmd.none)


view : Model -> Html Message
view model = case model of
  Loading -> 
    div [ class "flex justify-center items-center" ] 
    [ div [ class "bg-gray-800 text-white w-96 p-4 -mt-6 rounded-b-md text-center" ] 
      [ Icon.spinner [ class "w-4 h-4 mr-2" ]
      , text "Fetching reservations"
      ]
    ]