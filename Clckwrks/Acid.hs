{-# LANGUAGE FlexibleInstances, MultiParamTypeClasses #-}
module Clckwrks.Acid where

import Clckwrks.Menu.Acid          (MenuState       , initialMenuState)
import Clckwrks.Page.Acid          (PageState       , initialPageState)
import Clckwrks.ProfileData.Acid   (ProfileDataState, initialProfileDataState)
import Clckwrks.URL                (ClckURL)
import Control.Exception           (bracket)
import Control.Concurrent          (killThread, forkIO)
import Data.Acid                   (AcidState)
import Data.Acid.Local             (openLocalStateFrom, createCheckpointAndClose)
import Data.Acid.Remote            (acidServer)
import Data.Maybe                  (fromMaybe)
import Happstack.Auth.Core.Auth    (AuthState       , initialAuthState)
import Happstack.Auth.Core.Profile (ProfileState    , initialProfileState)
import Network                     (PortID(UnixSocket))
import System.Directory            (removeFile)
import System.FilePath             ((</>))

data Acid = Acid
    { acidAuth        :: AcidState AuthState
    , acidProfile     :: AcidState ProfileState
    , acidProfileData :: AcidState ProfileDataState
    , acidPage        :: AcidState PageState
    , acidMenu        :: AcidState (MenuState ClckURL)
    }

class GetAcidState m st where
    getAcidState :: m (AcidState st)

withAcid :: Maybe FilePath -> (Acid -> IO a) -> IO a
withAcid mBasePath f =
    let basePath = fromMaybe "_state" mBasePath in
    bracket (openLocalStateFrom (basePath </> "auth")        initialAuthState)        (createCheckpointAndClose) $ \auth ->
    bracket (openLocalStateFrom (basePath </> "profile")     initialProfileState)     (createCheckpointAndClose) $ \profile ->
    bracket (openLocalStateFrom (basePath </> "profileData") initialProfileDataState) (createCheckpointAndClose) $ \profileData ->
    bracket (openLocalStateFrom (basePath </> "page")        initialPageState)        (createCheckpointAndClose) $ \page ->
    bracket (openLocalStateFrom (basePath </> "menu")        initialMenuState)        (createCheckpointAndClose) $ \menu ->
        bracket (forkIO $ acidServer profileData (UnixSocket $ basePath </> "profileData_socket"))
                (\tid -> killThread tid >> removeFile (basePath </> "profileData_socket"))
                (const $ f (Acid auth profile profileData page menu))

