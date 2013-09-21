{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE MultiParamTypeClasses #-}

-- Autogenerated Mavlink v1.0 implementation: see smavgen_ivory.py

module SMACCMPilot.Mavlink.Messages.MissionRequest where

import SMACCMPilot.Mavlink.Pack
import SMACCMPilot.Mavlink.Unpack
import SMACCMPilot.Mavlink.Send

import Ivory.Language
import Ivory.Stdlib

missionRequestMsgId :: Uint8
missionRequestMsgId = 40

missionRequestCrcExtra :: Uint8
missionRequestCrcExtra = 230

missionRequestModule :: Module
missionRequestModule = package "mavlink_mission_request_msg" $ do
  depend packModule
  depend mavlinkSendModule
  incl mkMissionRequestSender
  incl missionRequestUnpack
  defStruct (Proxy :: Proxy "mission_request_msg")

[ivory|
struct mission_request_msg
  { mission_request_seq :: Stored Uint16
  ; target_system :: Stored Uint8
  ; target_component :: Stored Uint8
  }
|]

mkMissionRequestSender ::
  Def ('[ ConstRef s0 (Struct "mission_request_msg")
        , Ref s1 (Stored Uint8) -- seqNum
        , Ref s1 MavlinkArray -- tx buffer
        ] :-> ())
mkMissionRequestSender =
  proc "mavlink_mission_request_msg_send"
  $ \msg seqNum sendArr -> body
  $ do
  arr <- local (iarray [] :: Init (Array 4 (Stored Uint8)))
  let buf = toCArray arr
  call_ pack buf 0 =<< deref (msg ~> mission_request_seq)
  call_ pack buf 2 =<< deref (msg ~> target_system)
  call_ pack buf 3 =<< deref (msg ~> target_component)
  -- 6: header len, 2: CRC len
  if arrayLen sendArr < (6 + 4 + 2 :: Integer)
    then error "missionRequest payload is too large for 4 sender!"
    else do -- Copy, leaving room for the payload
            _ <- arrCopy sendArr arr 6
            call_ mavlinkSendWithWriter
                    missionRequestMsgId
                    missionRequestCrcExtra
                    4
                    seqNum
                    sendArr
            retVoid

instance MavlinkUnpackableMsg "mission_request_msg" where
    unpackMsg = ( missionRequestUnpack , missionRequestMsgId )

missionRequestUnpack :: Def ('[ Ref s1 (Struct "mission_request_msg")
                             , ConstRef s2 (CArray (Stored Uint8))
                             ] :-> () )
missionRequestUnpack = proc "mavlink_mission_request_unpack" $ \ msg buf -> body $ do
  store (msg ~> mission_request_seq) =<< call unpack buf 0
  store (msg ~> target_system) =<< call unpack buf 2
  store (msg ~> target_component) =<< call unpack buf 3

