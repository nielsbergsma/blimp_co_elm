module Components.SignInModal exposing 
  ( Model
  , Message(..)
  , view
  )

import Html exposing (Html, button, div, text, h1, h2)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)

import Components.Icon as Icon

type alias Model = {}


type Message 
  = SignInDemo


view : Html Message
view = 
  div [ class "bg-gray-800 w-[48rem] shadow-2xl rounded-b-lg text-white p-8" ]
  [ h1 [ class "text-2xl mb-4" ] 
    [ text "Welcome to Blimp & Co"
    ]
  , h2 [ class "text-xl mb-4"]
    [ text "Please sign in"
    ]
  , div [ class "flex justify-center m-8" ]
    [ div []
      [ button [ class "rounded-full hover:text-gray-800 hover:bg-white h-32 w-32 p-4", onClick SignInDemo ]
        [ div [ ] 
          [ Icon.key [ class "w-10 h-10" ]
          ]
        , div [ ] [ text "Sign in as administrator" ]
        ]
      ]
    ]
  ]
