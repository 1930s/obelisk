{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE LambdaCase #-}

module Obelisk.Command.Repl where

import Data.Monoid ((<>))
import System.Process
import System.Directory
import GHC.IO.Handle
import GHC.IO.Handle.Types

import Obelisk.Command.Project

--TODO: modify the nix-shell --run to recognize when the common dir's files have changed as well.
runRepl :: FilePath -> IO ()
runRepl dir = do
  findProjectRoot "." >>= \case
     Nothing -> putStrLn "'ob repl' must be used inside of an Obelisk project."
     Just pr -> do
       absPr <- makeAbsolute pr
       (Just hin, Just hout, Just herr, ph) <- createProcess_ "Error: could not create terminal spawn" 
          (shell ghcRepl)
          { cwd = Just absPr, std_out = CreatePipe}
       getProcessExitCode ph >>= \case
          Nothing -> hShow hout
          Just _ -> do
             mapM hClose [hin, hout, herr]  --TODO: figure out if this is necessary
             return $ "Exiting repl..."
       return ()
  where
    ghcRepl = "nix-shell -A shells.ghc --run cd " <> dir <> "; ghcid -W -c\"cabal new-repl exe:" <> dir <> "\"" :: String
