{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE LambdaCase #-}

module Obelisk.Command.Build where

import Data.Monoid ((<>))
import System.Process

import Obelisk.Command.Project

buildTool :: FilePath -> IO ()
buildTool fp = do
   findProjectRoot "." >>= \case
     Nothing -> putStrLn "'ob build' must be used inside of an Obelisk project."
     Just pr -> do
       (_, _, _, ph) <- createProcess_ "buildTool" (proc "nix-shell"
         [ "-A"
         , "shells.ghcjs"
         , "--run"
         , "cabal --project-file=cabal-ghcjs.project --builddir=dist-ghcjs new-build exe:" <> fp <> "; mkdir -p frontendJs; (cd frontendJs; ln -sfT ../dist-ghcjs/build/*/ghcjs-*/frontend-*/c/frontend/build/frontend/frontend.jsexe frontend.jsexe)"
         ]){cwd =  Just pr}
       return ()
