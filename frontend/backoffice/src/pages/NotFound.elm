module Pages.NotFound exposing (Model, Message(..), init, view)

import Html exposing (Html, text)

type alias Model = {}


type Message = NoOperation


init : Model
init = {}


view : Model -> Html Message
view _ = text "Page not found"
