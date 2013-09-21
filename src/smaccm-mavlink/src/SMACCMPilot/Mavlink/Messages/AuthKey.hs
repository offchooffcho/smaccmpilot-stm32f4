{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE MultiParamTypeClasses #-}

-- Autogenerated Mavlink v1.0 implementation: see smavgen_ivory.py

module SMACCMPilot.Mavlink.Messages.AuthKey where

import SMACCMPilot.Mavlink.Pack
import SMACCMPilot.Mavlink.Unpack
import SMACCMPilot.Mavlink.Send

import Ivory.Language
import Ivory.Stdlib

authKeyMsgId :: Uint8
authKeyMsgId = 7

authKeyCrcExtra :: Uint8
authKeyCrcExtra = 119

authKeyModule :: Module
authKeyModule = package "mavlink_auth_key_msg" $ do
  depend packModule
  depend mavlinkSendModule
  incl mkAuthKeySender
  incl authKeyUnpack
  defStruct (Proxy :: Proxy "auth_key_msg")

[ivory|
struct auth_key_msg
  { key :: Array 32 (Stored Uint8)
  }
|]

mkAuthKeySender ::
  Def ('[ ConstRef s0 (Struct "auth_key_msg")
        , Ref s1 (Stored Uint8) -- seqNum
        , Ref s1 MavlinkArray -- tx buffer
        ] :-> ())
mkAuthKeySender =
  proc "mavlink_auth_key_msg_send"
  $ \msg seqNum sendArr -> body
  $ do
  arr <- local (iarray [] :: Init (Array 32 (Stored Uint8)))
  let buf = toCArray arr
  arrayPack buf 0 (msg ~> key)
  -- 6: header len, 2: CRC len
  if arrayLen sendArr < (6 + 32 + 2 :: Integer)
    then error "authKey payload is too large for 32 sender!"
    else do -- Copy, leaving room for the payload
            _ <- arrCopy sendArr arr 6
            call_ mavlinkSendWithWriter
                    authKeyMsgId
                    authKeyCrcExtra
                    32
                    seqNum
                    sendArr
            retVoid

instance MavlinkUnpackableMsg "auth_key_msg" where
    unpackMsg = ( authKeyUnpack , authKeyMsgId )

authKeyUnpack :: Def ('[ Ref s1 (Struct "auth_key_msg")
                             , ConstRef s2 (CArray (Stored Uint8))
                             ] :-> () )
authKeyUnpack = proc "mavlink_auth_key_unpack" $ \ msg buf -> body $ do
  arrayUnpack buf 0 (msg ~> key)

