module Components.Header exposing 
  ( Model
  , Message(..)
  , init
  , update
  , view
  )

import Html exposing (Html, button, div, text, span, nav, img, a, ul, li)
import Html.Attributes exposing (class, src, href)
import Html.Events exposing (onClick)
import Components.Icon as Icon

import Routes
import Session exposing (Session)


type alias Model = 
  { route: Routes.Route
  , session: Maybe Session
  , profileMenuOpen: Bool
  }


type Message 
  = ToggleProfileMenu
  | SignOut


init : Routes.Route -> Maybe Session -> Model
init route session = 
  { route = route, session = session, profileMenuOpen = False }


update : Model -> Message -> Model
update model message = 
  case message of
    ToggleProfileMenu -> { model | profileMenuOpen = not model.profileMenuOpen }
    _ -> model


view : Model -> Html Message
view model = 
  div [ class "bg-gray-800 pb-64" ]
  [ nav [ class "bg-gray-800" ] 
    [ div [ class "mx-auto lg:px-8" ]
      [ div [ class "border-b border-gray-700"]
        [ div[ class "flex h-16 items-center justify-between px-4 sm:px-0" ]
          [ div [ class "flex items-center" ]
            [ div [ class "flex-shrink-0" ]
              [ a [ href "/" ]
                [ Icon.logo [ class "h-12 w-12 align-[-2.5rem] text-white" ]
                ]
              ]
            ]

          , viewMenu model
  
          , div [ class "relative" ] 
            [ button [ class "flex flex-row items-center text-white rounded-full hover:bg-gray-700 hover:text-white", onClick ToggleProfileMenu ]
              [ div [ class "ml-4 flex items-center text-sm mx-4 relative" ]
                [ case model.session of
                    Just session -> text session.name
                    Nothing -> text "(not signed in)" 
                ]
              , div [ class "w-8 h-8 bg-white text-gray-800 rounded-full flex items-center justify-center" ]
                [ case Maybe.andThen .photoUrl model.session of
                    Just url -> img [ class "mx-4 h-7 w-7 rounded-full", src url ] []
                    Nothing -> Icon.user [ class "h-7 w-7" ]
                ]
              ]
            , if model.profileMenuOpen then 
                viewProfileMenu
              else
                text ""
            ]
          ]
        ]
      ]
    ]
  ]


viewMenu : Model -> Html Message
viewMenu model = 
  div [ class "ml-5 flex-grow flex flex-row" ]
  [ viewMenuItem model Routes.FlightScheduling "Flight scheduling" Icon.compass
  , viewMenuItem model Routes.Reservations "Reservations" Icon.receipt
  ]


viewMenuItem : Model -> Routes.Route -> String -> Icon.Icon Message -> Html Message
viewMenuItem model destination name icon = 
  if selected model.route destination then
    div [ class "mx-2 flex items-baseline space-x-4" ]
    [ span [ class "bg-gray-900 text-white rounded-md px-3 py-2 text-sm font-medium" ]
      [ icon [ class "w-4 h-4 mr-2" ]
      , text name
      ]
    ]
  else
    div [ class "mx-2 flex items-baseline space-x-4" ]
    [ a [ href (Routes.toUrl destination), class "text-gray-300 rounded-md px-3 py-2 text-sm font-medium hover:bg-gray-700 hover:text-white" ]
      [ icon [ class "w-4 h-4 mr-2" ]
      , text name
      ]
    ]


viewProfileMenu: Html Message
viewProfileMenu = 
  ul [ class "absolute bg-white top-9 right-1 w-48 p-2 text-sm rounded-md shadow-xl" ]
  [ li [ ] 
    [ button [ class "text-gray-800 py-1 px-2 rounded w-full hover:bg-gray-300 text-left", onClick SignOut ] 
      [ Icon.key [ class "h-4 w-4 mr-2" ]
      , text "Sign out" 
      ]
    ]
  ]


-- helpers
selected : Routes.Route -> Routes.Route -> Bool
selected current route = 
  current == route
   