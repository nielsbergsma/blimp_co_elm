module Main exposing (..)

import Browser exposing (Document, UrlRequest, application)
import Browser.Navigation as Nav
import Url exposing (Url)
import Html exposing (Html, div, text, header, h1)
import Html.Attributes exposing (class, href)
import Routes exposing(fromUrl, toUrl, Route(..))
import Session exposing(Session)
import Ports as Ports

import Pages.NotFound as NotFound
import Pages.FlightScheduling as FlightScheduling
import Pages.Reservations as Reservations

import Components.Icon as Icon
import Components.Header as Header
import Components.SignInModal as SignInModal


type Model 
  = Initializing { navigation: Nav.Key, route: Route, header: Header.Model } 
  | NotSignedIn { navigation: Nav.Key, route: Route, header: Header.Model }
  | SignedIn { navigation: Nav.Key, route: Route, header: Header.Model, page: Page, session: Session }


type Message 
  = HeaderMessage Header.Message
  | SignInModalMessage SignInModal.Message
  | NotFoundMessage NotFound.Message
  | FlightSchedulingMessage FlightScheduling.Message
  | ReservationsMessage Reservations.Message
  | ChangedUrl Url
  | ClickedLink UrlRequest
  | SignInSucceeded Session
  | SignOut
  | SignedOut


type Page 
  = NotFoundPage NotFound.Model
  | FlightSchedulingPage FlightScheduling.Model
  | ReservationsPage Reservations.Model


main : Program () Model Message
main = 
  application
  { init = init
  , onUrlChange = ChangedUrl
  , onUrlRequest = ClickedLink
  , subscriptions = subscriptions
  , update = update
  , view = view
  }


init : () -> Url -> Nav.Key -> (Model, Cmd Message)
init _ url key = 
  (NotSignedIn { navigation = key, route = fromUrl url, header = Header.init Routes.Unknown Nothing }, Cmd.none)


navigate : Model -> Routes.Route -> (Model, Cmd Message)
navigate model destination = case (model, destination) of
  (SignedIn signedInModel, Routes.FlightScheduling) -> 
    let
      (pageModel, pageCmd) = FlightScheduling.init signedInModel.session
    in 
      (SignedIn { signedInModel | page = FlightSchedulingPage pageModel, route = destination, header = Header.init Routes.FlightScheduling (Just signedInModel.session) }, pageCmd |> Cmd.map FlightSchedulingMessage)

  (SignedIn signedInModel, Routes.Reservations) -> 
    let
      (pageModel, pageCmd) = Reservations.init signedInModel.session
    in 
      (SignedIn { signedInModel | page = ReservationsPage pageModel, route = destination, header = Header.init Routes.Reservations (Just signedInModel.session) }, pageCmd |> Cmd.map ReservationsMessage)

  _ -> 
    (model, Cmd.none)


update : Message -> Model -> (Model, Cmd Message)
update message model = case (model, message) of
  -- navigation
  (_, ChangedUrl url) -> 
    navigate model (fromUrl url) 

  (_, ClickedLink urlRequest) ->    
    case urlRequest of
      Browser.Internal url -> case url.path of 
        ""  -> (model, Nav.load (Url.toString url))
        "/" -> (model, Nav.load (Url.toString url))
        _   -> (model, Nav.pushUrl (toNavigation model) (Url.toString url))
      Browser.External href -> (model, Nav.load href)

  -- sign out
  (Initializing { navigation, route, header }, SignedOut) -> 
    (NotSignedIn { navigation = navigation, route = route, header = header }, Cmd.none)

  (SignedIn { navigation, route, header }, SignedOut) -> 
    (NotSignedIn { navigation = navigation, route = route, header = header }, Cmd.none)

  (_, HeaderMessage Header.SignOut) ->
    (model, Ports.signOut () )

  -- sign in
  (_, SignInModalMessage SignInModal.SignInDemo) ->
    (model, Ports.signInDemo ())

  (Initializing { navigation, route, header }, SignInSucceeded session) ->
    let
      signedInModel = SignedIn { navigation = navigation, route = route, session = session, page = NotFoundPage NotFound.init, header = header }
    in case route of
      Routes.Unknown -> (signedInModel, Nav.pushUrl (toNavigation model) (toUrl Routes.FlightScheduling)) -- default start page if route is unknown
      _ -> navigate signedInModel route

  (NotSignedIn { navigation, route, header }, SignInSucceeded session) ->
    let
      signedInModel = SignedIn { navigation = navigation, route = route, session = session, page = NotFoundPage NotFound.init, header = header }
    in case route of
      Routes.Unknown -> (signedInModel, Nav.pushUrl (toNavigation model) (toUrl Routes.FlightScheduling)) -- default start page if route is unknown
      _ -> navigate signedInModel route

  (SignedIn signedInModel, SignInSucceeded session) ->
    (SignedIn { signedInModel | session = session, header = Header.init signedInModel.route (Just session) }, Cmd.none)

  -- header messsages
  (SignedIn signedInModel, HeaderMessage headerMessage) ->
    (SignedIn { signedInModel | header = Header.update signedInModel.header headerMessage }, Cmd.none)

  -- page messages
  (SignedIn signedInModel, _) ->
    let 
      (updatedPage, cmd) = updatePage signedInModel.session message signedInModel.page
    in 
      (SignedIn { signedInModel | page = updatedPage }, cmd)

  -- other
  _ -> (model, Cmd.none)


updatePage : Session -> Message -> Page -> (Page, Cmd Message)
updatePage session message page = case (page, message) of
  (FlightSchedulingPage flightSchedulingPage, FlightSchedulingMessage flightSchedulingMessage) ->
    (FlightScheduling.update session flightSchedulingPage flightSchedulingMessage) |> mapPage FlightSchedulingPage FlightSchedulingMessage

  (ReservationsPage reservationsPage, ReservationsMessage reservationsMessage) ->
    (Reservations.update session reservationsPage reservationsMessage) |> mapPage ReservationsPage ReservationsMessage

  _ -> (page, Cmd.none)


view : Model -> Document Message
view model = case model of 
  Initializing { header } -> 
    { title = "Blimp & Co | Initializing"
    , body = 
      [ div [ class "min-h-full" ] 
        [ Header.view header |> Html.map HeaderMessage
        , div [ class "flex flex-col justify-center items-center text-gray-300" ] 
          [ div [ class "mt-[25vh] text-[16rem]"] 
            [ Icon.mugHot [ class "w-64 h-64" ]

            ]
          , div [ class "text-4xl mt-2" ] 
            [ text "Taking off, hold tight..."
            ]
          ]
        ]
      ]
    }

  NotSignedIn { header } -> 
    { title = "Blimp & Co | Not Signed In"
    , body = 
      [ div [ class "min-h-full" ] 
        [ Header.view header |> Html.map HeaderMessage
        , div [ class "flex flex-col justify-center items-center text-gray-300" ] 
          [ div [ class "mt-[25vh] text-[16rem]"] 
            [ Icon.userSlash [ class "w-64 h-64" ]
            ]
          , div [ class "text-4xl mt-2" ] 
            [ text "Not Signed In"
            ]
          ]
        ]
      , div [ class "modal-container transition-all transition duration-700 ease-in-out" ]
        [ SignInModal.view |> Html.map SignInModalMessage
        ]
      ]
    }

  SignedIn { page, header } -> 
    { title = "Blimp & Co | " ++ (pageTitle page)
    , body = 
      [ div [ class "min-h-full" ] 
        [ Header.view header |> Html.map HeaderMessage
        , div [ class "p-8 -mt-64" ]
          [ h1 [ class "text-3xl text-white"]
            [ text (pageTitle page)
            ]
          , div [ class "mx-auto pt-8 pb-12" ]
            [ div [ class "rounded-lg bg-white px-5 py-6 shadow min-h-[50vh]" ]
              [ viewPage page
              ]
            ]
          ]
        ]
      ]
    }


viewPage : Page -> Html Message
viewPage page = case page of 
  FlightSchedulingPage model -> 
    FlightScheduling.view model |> Html.map FlightSchedulingMessage

  ReservationsPage model -> 
    Reservations.view model |> Html.map ReservationsMessage
  
  NotFoundPage model -> 
    NotFound.view model |> Html.map NotFoundMessage


-- helpers
subscriptions : Model -> Sub Message
subscriptions _ = Sub.batch
  [ Ports.signedOut (always SignedOut)
  , Ports.signedIn (SignInSucceeded)
  ]


pageTitle : Page -> String
pageTitle page = case page of 
  FlightSchedulingPage _ -> "Flight scheduling"
  ReservationsPage _ -> "Reservations"
  NotFoundPage _ -> "Not Found"


toNavigation : Model -> Nav.Key
toNavigation model = case model of
  Initializing { navigation } -> navigation
  SignedIn { navigation } -> navigation
  NotSignedIn { navigation } -> navigation


mapPage : (pageModel -> Page) -> (pageCmd -> Message) -> (pageModel, Cmd pageCmd) -> (Page, Cmd Message)
mapPage toPage toMessage (pageModel, pageCmd) = (toPage pageModel, Cmd.map toMessage pageCmd)
