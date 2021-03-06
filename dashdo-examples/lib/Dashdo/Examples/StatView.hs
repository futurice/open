{-# LANGUAGE OverloadedStrings, ExtendedDefaultRules, FlexibleContexts, TemplateHaskell #-}
module Dashdo.Examples.StatView where

import System.Statgrab

import Dashdo
import Dashdo.Types
import Dashdo.Serve
import Dashdo.Elements
import Dashdo.FlexibleInput
import Dashdo.Rdash (rdash, charts, controls)
import Control.Arrow ((&&&), second)
import Control.Monad.State.Strict
import Control.Concurrent (forkIO, threadDelay)
import Control.Concurrent.MVar
import Lucid
import qualified Data.List as L (filter)
import Data.Text (Text, unpack, pack)
import Data.Text.Encoding (decodeUtf8)
import Lens.Micro.Platform
import System.Posix.User (UserEntry, userName, userID, getAllUserEntries)
import Lucid.Bootstrap3 (rowEven, Breakpoint( MD ))
import Lucid.Bootstrap (row_)

import Graphics.Plotly (plotly, layout, title, Trace, name, thinMargins, margin)
import Graphics.Plotly.Lucid
import Graphics.Plotly.GoG
import Graphics.Plotly.Simple
import Graphics.Plotly.Histogram (histogram)

-- System Load dashdo

data SysStats = SysStats
 { statsLoad :: Double
 , statsMem :: Integer
 , statsDiskIO :: (Integer, Integer)
 }

data Unused = Unused

statGrab :: MVar [SysStats] -> IO ()
statGrab mvStats = diskStats >>= forever
 where diskStats = ((sum . map fst &&& sum . map snd) . map (diskRead &&& diskWrite))
           <$> runStats snapshots
       grab f = f <$> runStats snapshot
       forever o = do
           n <- update o
           threadDelay 1000000
           forever n
       update (r', w') = do
           cpu <- grab load1
           mem <- grab memUsed
           (r, w) <- diskStats
           modifyMVar_ mvStats (return . take 60 . (SysStats cpu mem (r-r', w-w'):))
           return (r, w)

loadDashdo mvStats = Dashdo Unused (load mvStats)

load :: MVar [SysStats] -> SHtml IO Unused ()
load mvStats = do
  stats <- liftIO $ readMVar mvStats
  let theData = zip [1..] stats
      mkLine f = line (aes & x .~ fst & y .~ (f . snd)) theData
      cpuLoad = mkLine statsLoad
      memUsage = mkLine (fromIntegral . statsMem)
      diskRead = mkLine (fromIntegral . fst . statsDiskIO) & name ?~ "Read"
      diskWrite = mkLine (fromIntegral . snd . statsDiskIO) & name ?~ "Write"

  submitPeriodic 3
  charts
     [ ("CPU Load",     toHtml $ plotly "foo" [cpuLoad] & layout . margin ?~ thinMargins)
     , ("Memory Usage", toHtml $ plotly "bar" [memUsage] & layout . margin ?~ thinMargins)
     , ("Disk IO",      toHtml $ plotly "baz" [diskRead, diskWrite] & layout . margin ?~ thinMargins)]

-- end of System Load dashdo


-- Processes dashdo

data ProcessFilterType = All | Active deriving (Eq, Show)

data PsCtl = PsCtl
 { _processFilterType :: ProcessFilterType
 , _processUsers :: [Text]
 }

makeLenses ''PsCtl

filterProcesses :: ProcessFilterType -> (Process -> Bool)
filterProcesses All    = const True
filterProcesses Active = (>0.1) . procCPUPercent

getStats :: IO ([Process], [UserEntry])
getStats = do
  ps <- runStats snapshots
  us <- getAllUserEntries
  return (ps, us)

psDashdo = Dashdo (PsCtl All []) process

process :: SHtml IO PsCtl ()
process = do
  ctl <- getValue
  (ps, us) <- liftIO $ getStats
  let userFilter = case L.filter ((`elem` ctl ^. processUsers) . pack . userName) us of
        []  -> const True
        lst -> (`elem` ((fromIntegral . userID) <$> lst)) . procUid

      processes = hbarChart
        $ map (decodeUtf8 . procName &&& procCPUPercent)
        $ filter (filterProcesses $ ctl ^. processFilterType)
        $ filter (userFilter) ps

      users = hbarChart
        $ filter ((> 0) . snd)
        $ map (pack . userName &&& userCPU) us where
          userCPU u = sum . map procCPUPercent . filter ((== uid) . procUid) $ ps where
            uid = fromIntegral (userID u)

  controls $
    processFilterType <<~ checkbox "Hide inactive processes" Active All

  charts
     [ ("CPU Usage by Process", toHtml $ plotly "ps" [processes] & layout . margin ?~ thinMargins)
     , ("CPU Usage by User",    plotlySelectMultiple (plotly "us" [users] & layout . margin ?~ thinMargins) processUsers)]

-- end of Processes dashdo

statView = do
  stats <- newMVar ([] :: [SysStats])
  forkIO (statGrab stats)
  let dashdos = [ RDashdo "load" "System Load" $ loadDashdo stats
                , RDashdo "process" "Processes" psDashdo ]
      html = rdash dashdos plotlyCDN
  runRDashdo id html dashdos