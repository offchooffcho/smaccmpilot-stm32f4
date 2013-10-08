{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE NoMonoLocalBinds #-}
{-# LANGUAGE RankNTypes #-}

module SMACCMPilot.Flight.GCS.Receive.Task
  ( gcsReceiveTask
  ) where

import           Prelude hiding (last, id)

import           Data.Traversable (traverse)

import           Ivory.Language
import           Ivory.Stdlib
import           Ivory.Tower

import qualified SMACCMPilot.Mavlink.Receive        as R
import qualified SMACCMPilot.Flight.Types.DataRate  as D

import           SMACCMPilot.Param
import           SMACCMPilot.Flight.GCS.Stream (defaultPeriods)
import           SMACCMPilot.Flight.GCS.Receive.Handlers
import           SMACCMPilot.Mavlink.Messages (mavlinkMessageModules)
import           SMACCMPilot.Mavlink.CRC (mavlinkCRCModule)
import qualified SMACCMPilot.Communications         as Comm

--------------------------------------------------------------------------------

gcsReceiveTask :: (SingI n0, SingI n1, SingI n2, SingI n3, SingI n4)
               => ChannelSink   n0 Comm.MAVLinkArray -- from decryptor
               -> ChannelSource n1 (Struct "gcsstream_timing")
               -> ChannelSource n2 (Struct "data_rate_state")
               -> ChannelSource n3 (Struct "hil_state_msg")
               -> ChannelSource n4 (Stored Sint16)  -- param_request
               -> [Param PortPair]
               -> Task p ()
gcsReceiveTask mavStream s_src dr_src hil_src param_req_src params = do
  millis <- withGetTimeMillis
  hil_emitter <- withChannelEmitter hil_src "hil_src"

  -- Get lists of parameter readers and writers.
  write_params      <- traverse paramWriter (map (fmap portPairSource) params)
  read_params       <- traverse paramReader (map (fmap portPairSink)   params)
  param_req_emitter <- withChannelEmitter param_req_src "param_req"

  -- Generate functions from parameter list.
  let getParamIndex  = makeGetParamIndex read_params
  let setParamValue  = makeSetParamValue write_params

  withStackSize 1024
  streamPeriodEmitter <- withChannelEmitter s_src "streamperiods"

  -- drEmitter <- withChannelEmitter dr_src "data_rate_chan"

  s_periods <- taskLocalInit "periods" defaultPeriods
  drInfo    <- taskLocal     "dropInfo"
  state     <- taskLocalInit "state"
                 (istruct [ R.status .= ival R.status_IDLE ])

  let handlerAux :: Def ('[ Ref s0 (Struct "mavlink_receive_state")
                          , Ref s1 (Struct "gcsstream_timing")
                          ] :-> ())
      handlerAux =
        proc "gcsReceiveHandlerAux" $ \s streams -> body $
          runHandlers s
            [ handle (paramRequestList read_params param_req_emitter)
            , handle (paramRequestRead getParamIndex param_req_emitter)
            , handle (paramSet getParamIndex setParamValue param_req_emitter)
            , handle (requestDatastream streams)
            , handle (hilState hil_emitter)
            ]
          where runHandlers s = mapM_ ($ s)

  let parseMav :: Def ('[ConstRef s1 Comm.MAVLinkArray] :-> ())
      parseMav = proc "parseMav" $ \mav -> body $ do
        arrayMap $ \ix -> do b <- deref (mav ! ix)
                             R.mavlinkReceiveByte state b
        s <- deref (state ~> R.status)
        cond_
          [ (s ==? R.status_GOTMSG) ==> do
              -- XXX We need to have a story for messages that are parsed
              -- correctly but are not recognized by the system---one could
              -- launch a DoS with those, too.
              t <- getTimeMillis millis
              store (drInfo ~> D.lastSucc) t
              call_ handlerAux state s_periods
              R.mavlinkReceiveReset state
              -- XXX This should only be called if we got a request_data_stream
              -- msg.  Here it's called regardless of what incoming Mavlink
              -- message there is.
              emit_ streamPeriodEmitter (constRef s_periods)
          , (s ==? R.status_FAIL)   ==> do
              (drInfo ~> D.dropped) += 1
              store (state ~> R.status) R.status_IDLE
          ]

        -- XXX data rate stuff
        -- emit_ drEmitter (constRef drInfo)

  taskInit $ emit_ streamPeriodEmitter (constRef s_periods)

  onChannel mavStream "mavStream" $ \ms -> do
    mav <- local (iarray [])
    refCopy mav ms
    call_ parseMav (constRef mav)

  taskModuleDef $ do
    depend mavlinkCRCModule
    defStruct (Proxy :: Proxy "mavlink_receive_state")
    handlerModuleDefs
    mapM_ depend mavlinkMessageModules
    mapM_ depend stdlibModules
    private $ do
      incl parseMav
      incl handlerAux
      incl getParamIndex
      incl setParamValue

