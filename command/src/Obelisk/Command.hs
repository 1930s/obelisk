{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
module Obelisk.Command where

import Control.Monad
import Data.Monoid
import Options.Applicative
import System.Environment
import System.FilePath
import System.IO
import System.Posix.Process

import Obelisk.Command.Project
import Obelisk.Command.Thunk
import Obelisk.Command.Repl

data Args = Args
  { _args_noHandOffPassed :: Bool
  -- ^ This flag is actually handled outside of the optparse-applicative parser, but we detect whether
  -- it has gotten through in order to notify the user that it should only be passed once and as the very
  -- first argument
  , _args_command :: ObCommand
  }

args :: Parser Args
args = Args <$> noHandoff <*> obCommand

noHandoff :: Parser Bool
noHandoff = flag False True $ mconcat
  [ long "no-handoff"
  , help "Do not hand off execution to project-specific implementation of this command"
  , hidden
  ]

argsInfo :: ParserInfo Args
argsInfo = info (args <**> helper) $ mconcat
  [ fullDesc
  , progDesc "Manage Obelisk projects"
  ]

initSource :: Parser InitSource
initSource = foldl1 (<|>)
  [ pure InitSource_Default
  , InitSource_Branch <$> strOption (long "branch" <> metavar "BRANCH")
  , InitSource_Symlink <$> strOption (long "symlink" <> metavar "PATH")
  ]

data ObCommand
   = ObCommand_Init InitSource
   | ObCommand_Dev
   | ObCommand_Thunk ThunkCommand
   | ObCommand_Repl FilePath
   | ObCommand_Watch FilePath

obCommand :: Parser ObCommand
obCommand = hsubparser $ mconcat
  [ command "init" $ info (ObCommand_Init <$> initSource) $ progDesc "Initialize an Obelisk project"
  , command "dev" $ info (pure ObCommand_Dev) $ progDesc "Run current project in development mode"
  , command "thunk" $ info (ObCommand_Thunk <$> thunkCommand) $ progDesc "Manipulate thunk directories"
  , command "repl" $ info (ObCommand_Repl <$> (strArgument (action "directory"))) $ progDesc "Open an interactive interpreter"
  , command "watch" $ info (ObCommand_Watch <$> (strArgument (action "directory")))$ progDesc "Watch directory for changes and update interactive interpreter"
  ]

--TODO: Result should provide normalised path and also original user input for error reporting.
thunkDirectoryParser :: Parser FilePath
thunkDirectoryParser = fmap (dropTrailingPathSeparator . normalise) . strArgument $ mconcat
  [ action "directory"
  , metavar "THUNKDIR"
  , help "Path to directory containing thunk data"
  ]

data ThunkPackOpts = ThunkPackOpts
  { _thunkPackOpts_directory :: FilePath
  , _thunkPackOpts_upstream :: String
  }

data ThunkCommand
   = ThunkCommand_Update [FilePath]
   | ThunkCommand_Unpack [FilePath]
   | ThunkCommand_Pack [ThunkPackOpts]

thunkPackOpts :: Parser ThunkPackOpts
thunkPackOpts = (ThunkPackOpts <$> thunkDirectoryParser <*>) . strOption $ mconcat
  [ long "upstream"
  , value "origin"
  , metavar "REMOTE"
  , help "Git remote that packed thunk will point to"
  , showDefault
  ]

thunkCommand :: Parser ThunkCommand
thunkCommand = hsubparser $ mconcat
  [ command "update" $ info (ThunkCommand_Update <$> some thunkDirectoryParser) $ progDesc "Update thunk to latest revision available"
  , command "unpack" $ info (ThunkCommand_Unpack <$> some thunkDirectoryParser) $ progDesc "Unpack thunk into git checkout of revision it points to"
  , command "pack" $ info (ThunkCommand_Pack <$> some thunkPackOpts) $ progDesc "Pack git checkout into thunk that points at given upstream"
  ]

parserPrefs :: ParserPrefs
parserPrefs = defaultPrefs
  { prefShowHelpOnEmpty = True
  }

main :: IO ()
main = do
  myArgs <- getArgs
  --TODO: We'd like to actually use the parser to determine whether to hand off,
  --but in the case where this implementation of 'ob' doesn't support all
  --arguments being passed along, this could fail.  For now, we don't bother
  --with optparse-applicative until we've done the handoff.
  let go as = do
        Args noHandoffPassed cmd <- handleParseResult (execParserPure parserPrefs argsInfo as)
        case noHandoffPassed of
          False -> return ()
           --TODO: Use a proper logging system with log levels and whatnot
          True -> hPutStrLn stderr "NOTICE: --no-handoff should only be passed once and as the first argument; ignoring"
        ob cmd
  case myArgs of
    "--no-handoff" : as -> go as -- If we've been told not to hand off, don't hand off
    as -> do
      findProjectObeliskCommand "." >>= \case
        Nothing -> go as -- If we aren't in a project, just run ourselves
        Just impl -> do
          -- Invoke the real implementation, using --no-handoff to prevent infinite recursion
          executeFile impl False ("--no-handoff" : myArgs) Nothing

ob :: ObCommand -> IO ()
ob = \case
  ObCommand_Init source -> initProject source
  ObCommand_Dev -> putStrLn "Dev!"
  ObCommand_Thunk tc -> case tc of
    ThunkCommand_Update thunks -> mapM_ updateThunkToLatest thunks
    ThunkCommand_Unpack thunks -> mapM_ unpackThunk thunks
    ThunkCommand_Pack thunks -> forM_ thunks $ \(ThunkPackOpts dir upstream) -> packThunk dir upstream
  ObCommand_Repl component -> runRepl component
  ObCommand_Watch component -> watch component

--TODO: Clean up all the magic strings throughout this codebase
