{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE DataKinds #-}

module UARTStressTest where

import Data.Char (ord)

import Ivory.Language
import Ivory.Stdlib
import Ivory.Tower

import Platforms
import LEDTower

import Ivory.BSP.STM32F4.Init
import Ivory.BSP.STM32F4.GPIO
import Ivory.BSP.STM32F4.UART
import Ivory.BSP.STM32F4.UART.Tower
import Ivory.BSP.STM32F4.RCC
import Ivory.BSP.STM32F4.Signalable

ready :: Uint8
ready = 0

sent :: Uint8
sent = 1

got :: Uint8
got = 2

failed_timeout :: Uint8
failed_timeout = 3

failed_badval :: Uint8
failed_badval = 3

garbage_vals :: Uint8
garbage_vals = 4


pollingLoopback :: ChannelSource (Stored Uint8)
                -> ChannelSink (Stored Uint8)
                -> GPIOPin
                -> String
                -> Uint8
                -> Tower p ()
pollingLoopback src snk handlepin n correctval = task (named "pollingLoopback") $ do
  timer <- withPeriodicEvent (Milliseconds 1)
  out <- withChannelEmitter  src "out"
  inp <- withChannelReceiver snk "in"

  success <- taskLocalInit (named "success") (ival (0 :: Uint32))
  state   <- taskLocalInit (named "state")   (ival ready)
  time    <- taskLocal     (named "time")

  taskInit $ do
    gpioSetup handlepin

  handleV timer "periodic" $ \t -> do
    s <- deref state
    cond_
      [ s ==? ready ==> do
          -- Flush:
          arrayMap $ \(_v :: Ix 99) -> do
            (_, _) <- receiveV inp
            return ()
          -- Send one byte:
          emitV_ out correctval
          gpioOn handlepin
          store time t
          store state sent

      , s ==? sent ==> do
          sendtime <- deref time
          (rxd, val) <- receiveV inp
          ifte_ rxd
            (do store time t
                gpioOff handlepin
                ifte_ (val ==? correctval)
                  (store state got)
                  (store state failed_badval))
            (when (t >? (sendtime + (fromIMilliseconds (2 :: Sint64)))) $ do
              store time t
              (store state failed_timeout))

      , s ==? got  ==> do
          a <- local (ival false)
          arrayMap $ \(_v :: Ix 99) -> do
            (rxd, _) <- receiveV inp
            when rxd $ store a true
          anythingelse <- deref a
          ifte_ anythingelse
            (store state garbage_vals)
            (do success %= (+1)
                store state ready)

      , true ==> gpioOff handlepin
      ]
  where
  named s = n ++ "_" ++ s

gpioSetup :: GPIOPin -> Ivory eff ()
gpioSetup p = do
  pinEnable        p
  pinSetOutputType p gpio_outputtype_pushpull
  pinSetSpeed      p gpio_speed_50mhz
  pinSetPUPD       p gpio_pupd_none
  gpioOff          p
gpioOff :: GPIOPin -> Ivory eff ()
gpioOff p = do
  pinClear         p
  pinSetMode       p gpio_mode_output
gpioOn :: GPIOPin -> Ivory eff ()
gpioOn p = do
  pinSet           p
  pinSetMode       p gpio_mode_output

app :: forall p . (ColoredLEDs p, BoardHSE p, STM32F4Signal p) => Tower p ()
app = do
  stm32f4InitTower

  -- XXX doesn't uartTower return source, sink in the wrong pairing?

--  uart3streams <- uartTower uart3 57600 (Proxy :: Proxy 256)
--  uart4streams <- uartTower uart4 57600 (Proxy :: Proxy 256)

  (u1snk, u1src) <- uartTowerDebuggable uart1 57600 (Proxy :: Proxy 256) UARTTowerDebugger
                      { debug_init = do
                          gpioSetup pinD3
                          gpioSetup pinD4
                          gpioSetup pinD5
                          gpioSetup pinD6
                          gpioSetup pinD7
                      , debug_isr = do
                          gpioOn  pinD3
                          gpioOff pinD3
                      , debug_evthandler_start = do
                          gpioOn  pinD4
                      , debug_evthandler_end = do
                          gpioOff pinD4
                      , debug_txcheck = do
                          gpioOn  pinD5
                          gpioOff pinD5
                      , debug_txcheck_pend = do
                          gpioOn  pinD6
                          gpioOff pinD6
                      , debug_txeie = \en -> do
                          ifte_ en
                            (gpioOn  pinD7)
                            (gpioOff pinD7)
                      }

  pollingLoopback u1src u1snk pinD12 "uart1" 0x66

  --(u2snk, u2src) <- uartTower uart2 57600 (Proxy :: Proxy 256)
  --pollingLoopback u2src u2snk pinD13 "uart2" 0x77



