port module Ports exposing (signInDemo, signOut, signedIn, signedOut)

import Session exposing(Session)


-- outwards
port signInDemo: () -> Cmd msg
port signOut: () -> Cmd msg


-- inwards
port signedIn : (Session -> msg) -> Sub msg
port signedOut : (() -> msg) -> Sub msg
