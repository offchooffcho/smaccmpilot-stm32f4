{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE MultiParamTypeClasses #-}

-- Autogenerated Mavlink v1.0 implementation: see smavgen_ivory.py

module SMACCMPilot.Mavlink.Messages.BatteryStatus where

import SMACCMPilot.Mavlink.Pack
import SMACCMPilot.Mavlink.Unpack
import SMACCMPilot.Mavlink.Send

import Ivory.Language
import Ivory.Stdlib

batteryStatusMsgId :: Uint8
batteryStatusMsgId = 147

batteryStatusCrcExtra :: Uint8
batteryStatusCrcExtra = 42

batteryStatusModule :: Module
batteryStatusModule = package "mavlink_battery_status_msg" $ do
  depend packModule
  depend mavlinkSendModule
  incl mkBatteryStatusSender
  incl batteryStatusUnpack
  defStruct (Proxy :: Proxy "battery_status_msg")

[ivory|
struct battery_status_msg
  { voltage_cell_1 :: Stored Uint16
  ; voltage_cell_2 :: Stored Uint16
  ; voltage_cell_3 :: Stored Uint16
  ; voltage_cell_4 :: Stored Uint16
  ; voltage_cell_5 :: Stored Uint16
  ; voltage_cell_6 :: Stored Uint16
  ; current_battery :: Stored Sint16
  ; accu_id :: Stored Uint8
  ; battery_remaining :: Stored Sint8
  }
|]

mkBatteryStatusSender ::
  Def ('[ ConstRef s0 (Struct "battery_status_msg")
        , Ref s1 (Stored Uint8) -- seqNum
        , Ref s1 MavlinkArray -- tx buffer
        ] :-> ())
mkBatteryStatusSender =
  proc "mavlink_battery_status_msg_send"
  $ \msg seqNum sendArr -> body
  $ do
  arr <- local (iarray [] :: Init (Array 16 (Stored Uint8)))
  let buf = toCArray arr
  call_ pack buf 0 =<< deref (msg ~> voltage_cell_1)
  call_ pack buf 2 =<< deref (msg ~> voltage_cell_2)
  call_ pack buf 4 =<< deref (msg ~> voltage_cell_3)
  call_ pack buf 6 =<< deref (msg ~> voltage_cell_4)
  call_ pack buf 8 =<< deref (msg ~> voltage_cell_5)
  call_ pack buf 10 =<< deref (msg ~> voltage_cell_6)
  call_ pack buf 12 =<< deref (msg ~> current_battery)
  call_ pack buf 14 =<< deref (msg ~> accu_id)
  call_ pack buf 15 =<< deref (msg ~> battery_remaining)
  -- 6: header len, 2: CRC len
  if arrayLen sendArr < (6 + 16 + 2 :: Integer)
    then error "batteryStatus payload is too large for 16 sender!"
    else do -- Copy, leaving room for the payload
            _ <- arrCopy sendArr arr 6
            call_ mavlinkSendWithWriter
                    batteryStatusMsgId
                    batteryStatusCrcExtra
                    16
                    seqNum
                    sendArr
            retVoid

instance MavlinkUnpackableMsg "battery_status_msg" where
    unpackMsg = ( batteryStatusUnpack , batteryStatusMsgId )

batteryStatusUnpack :: Def ('[ Ref s1 (Struct "battery_status_msg")
                             , ConstRef s2 (CArray (Stored Uint8))
                             ] :-> () )
batteryStatusUnpack = proc "mavlink_battery_status_unpack" $ \ msg buf -> body $ do
  store (msg ~> voltage_cell_1) =<< call unpack buf 0
  store (msg ~> voltage_cell_2) =<< call unpack buf 2
  store (msg ~> voltage_cell_3) =<< call unpack buf 4
  store (msg ~> voltage_cell_4) =<< call unpack buf 6
  store (msg ~> voltage_cell_5) =<< call unpack buf 8
  store (msg ~> voltage_cell_6) =<< call unpack buf 10
  store (msg ~> current_battery) =<< call unpack buf 12
  store (msg ~> accu_id) =<< call unpack buf 14
  store (msg ~> battery_remaining) =<< call unpack buf 15

