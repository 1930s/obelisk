{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE LambdaCase #-}

module Obelisk.Command.Repl where

import Data.Monoid ((<>))
import System.Process
import System.Directory
import GHC.IO.Handle.Types

import Obelisk.Command.Project

--TODO: modify the nix-shell --run to recognize when the common dir's files have changed as well.
runRepl :: FilePath -> IO ()
runRepl dir = do
  findProjectRoot "." >>= \case
     Nothing -> putStrLn "'ob repl' must be used inside of an Obelisk project."
     Just pr -> do
       (_, Just hout, _, _) <- createProcess_ "Error: could not create terminal spawn" (shell ghcRepl){ cwd = Just pr, std_out = CreatePipe}
       return ()
  where
    ghcRepl = "nix-shell -A shells.ghc --run cd " <> dir <> "; ghcid -W -c\"cabal new-repl exe:" <> dir <> "\"" :: String
