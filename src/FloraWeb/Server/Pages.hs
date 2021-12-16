module FloraWeb.Server.Pages where

import Control.Monad.Reader
import qualified Data.Map.Strict as Map
import Lucid
import Network.HTTP.Types (forbidden403)
import Optics.Core
import Servant
import Servant.API.Generic
import Servant.HTML.Lucid
import Servant.Server.Generic
import Web.Cookie (SetCookie)

import Flora.Environment
import FloraWeb.Server.Auth
import qualified FloraWeb.Server.Pages.Admin as Admin
import qualified FloraWeb.Server.Pages.Packages as Packages
import FloraWeb.Server.Pages.Sessions
import FloraWeb.Templates
import FloraWeb.Templates.Error
import qualified FloraWeb.Templates.Pages.Home as Home
import FloraWeb.Templates.Types

type Routes
  = AuthProtect "cookie-auth"
  :> ToServantApi Routes'

data Routes' mode = Routes'
  { home     :: mode :- Get '[HTML] (Html ())
  , about    :: mode :- "about" :> Get '[HTML] (Html ())
  , admin    :: mode :- "admin" :> Admin.Routes
  , login    :: mode :- "login" :> Session.Routes
  , packages :: mode :- "packages" :> Packages.Routes
  }
  deriving stock (Generic)

server :: ToServant Routes' (AsServerT FloraPageM)
server = genericServerT Routes'
  { home = homeHandler
  , about = aboutHandler
  , admin = ensureUser adminHandler
  , packages = Packages.server
  }

-- | Yes it is contravariant.
ensureUser :: FloraAdminM a -> FloraPageM a
ensureUser adminM = do
  mUser <- asks (\callInfo -> callInfo ^. #userInfo)
  case mUser of
    Nothing -> renderError forbidden403
    Just user -> withReaderT (\CallInfo{floraEnv} -> AuthedUser {userInfo = user, floraEnv}) adminM

homeHandler :: FloraPageM (Html ())
homeHandler = do
  let assigns = mkAssigns emptyAssigns (Just (UserAssigns $ Map.fromList [("navbar-search", "false")]))
  render assigns Home.show

aboutHandler :: FloraPageM (Html ())
aboutHandler = do
  let assigns = emptyAssigns
  render assigns Home.about

adminHandler :: FloraAdminM (Html ())
adminHandler = undefined
