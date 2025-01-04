module Session exposing (Session)


type alias Session = 
  { name: String
  , photoUrl: Maybe String
  , token: String
  }
