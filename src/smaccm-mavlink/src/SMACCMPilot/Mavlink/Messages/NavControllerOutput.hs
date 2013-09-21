{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE MultiParamTypeClasses #-}

-- Autogenerated Mavlink v1.0 implementation: see smavgen_ivory.py

module SMACCMPilot.Mavlink.Messages.NavControllerOutput where

import SMACCMPilot.Mavlink.Pack
import SMACCMPilot.Mavlink.Unpack
import SMACCMPilot.Mavlink.Send

import Ivory.Language
import Ivory.Stdlib

navControllerOutputMsgId :: Uint8
navControllerOutputMsgId = 62

navControllerOutputCrcExtra :: Uint8
navControllerOutputCrcExtra = 183

navControllerOutputModule :: Module
navControllerOutputModule = package "mavlink_nav_controller_output_msg" $ do
  depend packModule
  depend mavlinkSendModule
  incl mkNavControllerOutputSender
  incl navControllerOutputUnpack
  defStruct (Proxy :: Proxy "nav_controller_output_msg")

[ivory|
struct nav_controller_output_msg
  { nav_roll :: Stored IFloat
  ; nav_pitch :: Stored IFloat
  ; alt_error :: Stored IFloat
  ; aspd_error :: Stored IFloat
  ; xtrack_error :: Stored IFloat
  ; nav_bearing :: Stored Sint16
  ; target_bearing :: Stored Sint16
  ; wp_dist :: Stored Uint16
  }
|]

mkNavControllerOutputSender ::
  Def ('[ ConstRef s0 (Struct "nav_controller_output_msg")
        , Ref s1 (Stored Uint8) -- seqNum
        , Ref s1 MavlinkArray -- tx buffer
        ] :-> ())
mkNavControllerOutputSender =
  proc "mavlink_nav_controller_output_msg_send"
  $ \msg seqNum sendArr -> body
  $ do
  arr <- local (iarray [] :: Init (Array 26 (Stored Uint8)))
  let buf = toCArray arr
  call_ pack buf 0 =<< deref (msg ~> nav_roll)
  call_ pack buf 4 =<< deref (msg ~> nav_pitch)
  call_ pack buf 8 =<< deref (msg ~> alt_error)
  call_ pack buf 12 =<< deref (msg ~> aspd_error)
  call_ pack buf 16 =<< deref (msg ~> xtrack_error)
  call_ pack buf 20 =<< deref (msg ~> nav_bearing)
  call_ pack buf 22 =<< deref (msg ~> target_bearing)
  call_ pack buf 24 =<< deref (msg ~> wp_dist)
  -- 6: header len, 2: CRC len
  if arrayLen sendArr < (6 + 26 + 2 :: Integer)
    then error "navControllerOutput payload is too large for 26 sender!"
    else do -- Copy, leaving room for the payload
            _ <- arrCopy sendArr arr 6
            call_ mavlinkSendWithWriter
                    navControllerOutputMsgId
                    navControllerOutputCrcExtra
                    26
                    seqNum
                    sendArr
            retVoid

instance MavlinkUnpackableMsg "nav_controller_output_msg" where
    unpackMsg = ( navControllerOutputUnpack , navControllerOutputMsgId )

navControllerOutputUnpack :: Def ('[ Ref s1 (Struct "nav_controller_output_msg")
                             , ConstRef s2 (CArray (Stored Uint8))
                             ] :-> () )
navControllerOutputUnpack = proc "mavlink_nav_controller_output_unpack" $ \ msg buf -> body $ do
  store (msg ~> nav_roll) =<< call unpack buf 0
  store (msg ~> nav_pitch) =<< call unpack buf 4
  store (msg ~> alt_error) =<< call unpack buf 8
  store (msg ~> aspd_error) =<< call unpack buf 12
  store (msg ~> xtrack_error) =<< call unpack buf 16
  store (msg ~> nav_bearing) =<< call unpack buf 20
  store (msg ~> target_bearing) =<< call unpack buf 22
  store (msg ~> wp_dist) =<< call unpack buf 24

